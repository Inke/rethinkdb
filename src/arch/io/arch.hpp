// Copyright 2010-2012 RethinkDB, all rights reserved.
#ifndef ARCH_IO_ARCH_HPP_
#define ARCH_IO_ARCH_HPP_

#include "arch/io/disk.hpp"
#include "arch/io/network.hpp"
#include "arch/runtime/thread_pool.hpp"

/* Timer functions create (non-)periodic timers, callbacks for which are
 * executed on the same thread that they were created on. Thus, non-thread-safe
 * (but coroutine-safe) concurrency primitives can be used where appropriate.
 */
inline timer_token_t *add_timer(int64_t ms, void (*callback)(void *), void *ctx) {  // NOLINT
    return linux_thread_pool_t::thread->timer_handler.add_timer_internal(ms, callback, ctx, false);
}

inline timer_token_t *fire_timer_once(int64_t ms, void (*callback)(void *), void *ctx) {  // NOLINT
    return linux_thread_pool_t::thread->timer_handler.add_timer_internal(ms, callback, ctx, true);
}

inline void cancel_timer(timer_token_t *timer) {
    linux_thread_pool_t::thread->timer_handler.cancel_timer(timer);
}

#endif /* ARCH_IO_ARCH_HPP_ */
