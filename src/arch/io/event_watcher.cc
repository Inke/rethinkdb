// Copyright 2010-2012 RethinkDB, all rights reserved.
#include "arch/io/event_watcher.hpp"
#include "arch/runtime/thread_pool.hpp"

linux_event_watcher_t::linux_event_watcher_t(fd_t f, linux_event_callback_t *eh) :
    fd(f), error_handler(eh),
    in_watcher(NULL), out_watcher(NULL),
#ifdef __linux
    rdhup_watcher(NULL),
#endif
    old_mask(0)
{
    /* At first, only register for error events */
    linux_thread_pool_t::thread->queue.watch_resource(fd, 0, this);
}

linux_event_watcher_t::~linux_event_watcher_t() {
    linux_thread_pool_t::thread->queue.forget_resource(fd, this);
}

linux_event_watcher_t::watch_t::watch_t(linux_event_watcher_t *p, int e) :
    parent(p), event(e)
{
    rassert(!*parent->get_watch_slot(event), "something's already watching that event.");
    *parent->get_watch_slot(event) = this;
    parent->remask();
}

linux_event_watcher_t::watch_t::~watch_t() {
    rassert(*parent->get_watch_slot(event) == this);
    *parent->get_watch_slot(event) = NULL;
    parent->remask();
}

bool linux_event_watcher_t::is_watching(int event) {
    assert_thread();
    return *get_watch_slot(event) == NULL;
}

linux_event_watcher_t::watch_t **linux_event_watcher_t::get_watch_slot(int event) {
    switch (event) {
    case poll_event_in:    return &in_watcher;
    case poll_event_out:   return &out_watcher;
#ifdef __linux
    case poll_event_rdhup: return &rdhup_watcher;
#endif
    default: crash("bad event");
    }
}

void linux_event_watcher_t::remask() {
    int new_mask = 0;
    if (in_watcher)    new_mask |= poll_event_in;
    if (out_watcher)   new_mask |= poll_event_out;
#ifdef __linux
    if (rdhup_watcher) new_mask |= poll_event_rdhup;
#endif
    if (new_mask != old_mask) {
        linux_thread_pool_t::thread->queue.adjust_resource(fd, new_mask, this);
    }
    old_mask = new_mask;
}

void linux_event_watcher_t::on_event(int event) {

    int error_mask = poll_event_err | poll_event_hup;
#ifdef __linux
    error_mask |= poll_event_rdhup;
#endif
    guarantee((event & (error_mask | old_mask)) == event, "Unexpected event received (from operating system?).");

    if (event & error_mask) {
#ifdef __linux
        if (event & ~poll_event_rdhup) {
            error_handler->on_event(event & error_mask);
        } else {
            rassert(event & poll_event_rdhup);
            if (!rdhup_watcher->is_pulsed()) rdhup_watcher->pulse();
        }
#else
        error_handler->on_event(event & error_mask);
#endif  // __linux

        /* The error handler might have cancelled some watches, which would
        cause `remask()` to be run. We filter again to maintain the
        invariant that `event` only contains events that we are watching
        for. */
        event &= old_mask;
    }

    if (event & poll_event_in) {
        rassert(in_watcher);
        if (!in_watcher->is_pulsed()) in_watcher->pulse();
    }

    if (event & poll_event_out) {
        rassert(out_watcher);
        if (!out_watcher->is_pulsed()) out_watcher->pulse();
    }
}

