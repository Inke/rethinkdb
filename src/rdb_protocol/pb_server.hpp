// Copyright 2010-2012 RethinkDB, all rights reserved.
#ifndef RDB_PROTOCOL_PB_SERVER_HPP_
#define RDB_PROTOCOL_PB_SERVER_HPP_

#include <map>
#include <set>
#include <string>

#include "clustering/administration/metadata.hpp"
#include "clustering/administration/namespace_interface_repository.hpp"
#include "clustering/administration/namespace_metadata.hpp"
#include "extproc/pool.hpp"
#include "protob/protob.hpp"
#include "protocol_api.hpp"
#include "rdb_protocol/protocol.hpp"
#include "rdb_protocol/query_language.hpp"

class query_server_t {
public:
    query_server_t(const std::set<ip_address_t> &local_addresses, int port, rdb_protocol_t::context_t *_ctx);

    http_app_t *get_http_app();

    int get_port() const;

    struct context_t {
        context_t() : interruptor(0) { }
        stream_cache_t stream_cache;
        signal_t *interruptor;
    };
private:
    Response handle(Query *q, context_t *query_context);
    protob_server_t<Query, Response, context_t> server;
    rdb_protocol_t::context_t *ctx;
    uuid_u parser_id;
    one_per_thread_t<int> thread_counters;

    DISABLE_COPYING(query_server_t);
};

Response on_unparsable_query(Query *q, std::string msg);

#endif /* RDB_PROTOCOL_PB_SERVER_HPP_ */
