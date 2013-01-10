#include "clustering/administration/metadata.hpp"
#include "rdb_protocol/env.hpp"
#include "rdb_protocol/term.hpp"
#include "rdb_protocol/val.hpp"

namespace ql {

// DATUM_STREAM_T
datum_stream_t::datum_stream_t(env_t *_env) : env(_env) { guarantee(env); }
datum_stream_t *datum_stream_t::map(func_t *f) {
    return env->add_ptr(new map_datum_stream_t(env, f, this));
}
datum_stream_t *datum_stream_t::filter(func_t *f) {
    return env->add_ptr(new filter_datum_stream_t(env, f, this));
}
datum_stream_t *datum_stream_t::slice(size_t l, size_t r) {
    return env->add_ptr(new slice_datum_stream_t(env, l, r, this));
}

// LAZY_DATUM_STREAM_T
lazy_datum_stream_t::lazy_datum_stream_t(env_t *env, bool use_outdated,
                               namespace_repo_t<rdb_protocol_t>::access_t *ns_access)
    : datum_stream_t(env),
      json_stream(new query_language::batched_rget_stream_t(
                      *ns_access, env->interruptor, key_range_t::universe(),
                      100, use_outdated))
{ }
lazy_datum_stream_t::lazy_datum_stream_t(lazy_datum_stream_t *src)
    :datum_stream_t(src->env) {
    *this = *src;
}
datum_stream_t *lazy_datum_stream_t::map(func_t *f) {
    lazy_datum_stream_t *out = env->add_ptr(new lazy_datum_stream_t(this));
    out->trans = rdb_protocol_details::transform_variant_t(map_wire_func_t(env, f));
    out->json_stream = json_stream->add_transformation(out->trans, 0, env, _s, _b);
    return out;
}
datum_stream_t *lazy_datum_stream_t::filter(func_t *f) {
    lazy_datum_stream_t *out = env->add_ptr(new lazy_datum_stream_t(this));
    out->trans = rdb_protocol_details::transform_variant_t(filter_wire_func_t(env, f));
    out->json_stream = json_stream->add_transformation(out->trans, 0, env, _s, _b);
    return out;
}
const datum_t *lazy_datum_stream_t::next() {
    boost::shared_ptr<scoped_cJSON_t> json = json_stream->next();
    if (!json.get()) return 0;
    return env->add_ptr(new datum_t(json, env));
}

// ARRAY_DATUM_STREAM_T
array_datum_stream_t::array_datum_stream_t(env_t *env, const datum_t *_arr) :
    datum_stream_t(env), index(0), arr(_arr) { }

const datum_t *array_datum_stream_t::next() {
    return arr->el(index++, false);
    //                      ^^^^^ return 0 instead of throwing on error
}

// MAP_DATUM_STREAM_T
map_datum_stream_t::map_datum_stream_t(env_t *env, func_t *_f, datum_stream_t *_src)
    : datum_stream_t(env), f(_f), src(_src) { guarantee(f && src); }
const datum_t *map_datum_stream_t::next() {
    try {
        const datum_t *arg = src->next();
        if (!arg) return 0;
        std::vector<const datum_t *> args;
        args.push_back(arg);
        return f->call(args)->as_datum();
    } catch (exc_t &e) {
        e.backtrace.frames.push_front(map_bt_frame);
        throw;
    }
}

// FILTER_DATUM_STREAM_T
filter_datum_stream_t::filter_datum_stream_t(
    env_t *env, func_t *_f, datum_stream_t *_src)
    : datum_stream_t(env), f(_f), src(_src) { guarantee(f && src); }
const datum_t *filter_datum_stream_t::next() {
    try {
        const datum_t *arg = 0;
        for (;;) {
            env_checkpointer_t outer_checkpoint(env, &env_t::discard_checkpoint);
            if (!(arg = src->next())) return 0;
            std::vector<const datum_t *> args;
            args.push_back(arg);
            env_checkpointer_t inner_checkpoint(env, &env_t::discard_checkpoint);
            if (f->call(args)->as_datum()->as_bool()) {
                outer_checkpoint.reset(&env_t::merge_checkpoint);
                break;
            }
        }
        return arg;
    } catch (exc_t &e) {
        e.backtrace.frames.push_front(filter_bt_frame);
        throw;
    }
}

// SLICE_DATUM_STREAM_T
slice_datum_stream_t::slice_datum_stream_t(
    env_t *_env, size_t _l, size_t _r, datum_stream_t *_src)
    : datum_stream_t(_env), env(_env), ind(0), l(_l), r(_r), src(_src) { }
const datum_t *slice_datum_stream_t::next() {
    if (ind > r) return 0;
    while (ind++ < l) {
        env_checkpointer_t(env, &env_t::discard_checkpoint);
        src->next();
    }
    return src->next();
}

} // namespace ql