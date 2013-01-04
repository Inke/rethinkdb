// Copyright 2010-2012 RethinkDB, all rights reserved.
#ifndef ARCH_IO_TIMER_TIMER_SIGNAL_PROVIDER_HPP_
#define ARCH_IO_TIMER_TIMER_SIGNAL_PROVIDER_HPP_

#include "arch/runtime/event_queue.hpp"

struct timer_provider_callback_t;

#define TIMER_NOTIFY_SIGNAL    (SIGRTMIN + 3)

/* Kernel timer provider based on signals */
struct timer_signal_provider_t {
public:
    timer_signal_provider_t(linux_event_queue_t *_queue,
                            timer_provider_callback_t *_callback,
                            time_t secs, int32_t nsecs);
    ~timer_signal_provider_t();

private:
    timer_t timerid;

    DISABLE_COPYING(timer_signal_provider_t);
};

#endif  // ARCH_IO_TIMER_TIMER_SIGNAL_PROVIDER_HPP_
