// Copyright 2010-2012 RethinkDB, all rights reserved.
#ifndef __STRESS_CLIENT_UTILS_HPP__
#define __STRESS_CLIENT_UTILS_HPP__

#include <assert.h>
#include <pthread.h>
#include <algorithm>

#define UNUSED __attribute__((unused))
#define DISABLE_COPYING(name) name(const name&);        \
    void operator=(const name&)

// For global startup, initializes the clock_monotonic function (which is relevant on OS X).
void initialize_clock_monotonic();

/* Returns random number between [min, max] using various distributions */
enum rnd_distr_t {
    rnd_uniform_t,
    rnd_normal_t
};

struct rnd_gen_t
{
    void *gsl_rnd;
    rnd_distr_t rnd_distr;
    int mu;
};
rnd_distr_t distr_with_name(const char *name);
rnd_gen_t xrandom_create(rnd_distr_t rnd_distr, int mu);
size_t xrandom(size_t min, size_t max);
size_t xrandom(rnd_gen_t rnd, size_t min, size_t max);
size_t seeded_xrandom(size_t min, size_t max, unsigned long seed);
size_t seeded_xrandom(rnd_gen_t rnd, size_t min, size_t max, unsigned long seed);

/* Timing related functions */
typedef unsigned long long ticks_t;
ticks_t secs_to_ticks(float secs);
ticks_t get_ticks();
float ticks_to_secs(ticks_t ticks);
float ticks_to_ms(ticks_t ticks);
float ticks_to_us(ticks_t ticks);

void sleep_ticks(ticks_t ticks);

/* Spinlock wrapper class */
#if __MACH__
#define PTHREAD_HAS_SPINLOCK 0
#else
#define PTHREAD_HAS_SPINLOCK 1
#endif

// TODO: we should use regular mutexes on single core CPU
// instead of spinlocks

class spinlock_t {
public:
    friend class spinlock_acq_t;

    spinlock_t() {
#if PTHREAD_HAS_SPINLOCK
        pthread_spin_init(&l, PTHREAD_PROCESS_PRIVATE);
#else
        pthread_mutex_init(&l, NULL);
#endif
    }
    ~spinlock_t() {
#if PTHREAD_HAS_SPINLOCK
        pthread_spin_destroy(&l);
#else
        pthread_mutex_destroy(&l);
#endif
    }

    void lock() {
#if PTHREAD_HAS_SPINLOCK
        pthread_spin_lock(&l);
#else
        pthread_mutex_lock(&l);
#endif
    }
    void unlock() {
#if PTHREAD_HAS_SPINLOCK
        pthread_spin_unlock(&l);
#else
        pthread_mutex_unlock(&l);
#endif
    }

private:
#if PTHREAD_HAS_SPINLOCK
    pthread_spinlock_t l;
#else
    pthread_mutex_t l;
#endif

    DISABLE_COPYING(spinlock_t);
};

class spinlock_acq_t {
public:
    explicit spinlock_acq_t(spinlock_t *the_lock) : the_lock_(the_lock) {
        the_lock_->lock();
    }
    ~spinlock_acq_t() {
        the_lock_->unlock();
    }

private:
    spinlock_t *the_lock_;

    DISABLE_COPYING(spinlock_acq_t);
};


/* Return the number of digits in the number */
int count_decimal_digits(int);

/* We want to collect a fixed number of latency samples over each second, but we don't know how
many there are going to be. This type magically solves that problem using reservoir sampling. */
template<class sample_t, int goal = 100>
struct reservoir_sample_t {

    /* Note that we do sampling-without-replacement, not sampling-with-replacement. */

    int n;
    sample_t samples[goal];

    reservoir_sample_t() : n(0) { }

    /* push() puts a new object into the sample. */
    void push(sample_t s) {

        /* We have room to store the object directly */
        if (n < goal) {
            samples[n] = s;

        /* We don't have room; we may have to kick something out */
        } else {
            int slot = xrandom(0, n);
            if (slot < goal) samples[slot] = s;
        }

        n++;
    }

    /* The "+=" operator combines two samples. If you have two empty samples "a" and "b", then
    call push() several times on each, then say "a += b", then that is equivalent to having
    push()ed all the values into "a" originally. */
    reservoir_sample_t &operator+=(const reservoir_sample_t &s) {

        /* If each element of the incoming sample literally represents one object, then we can
        just use push(). */
        if (s.n < goal) {
            for (int i = 0; i < s.n; i++) push(s.samples[i]);

        /* If each element of us just represents one object, we reduce it to the above case by
        switching the operands. */
        } else if (n < goal) {
            reservoir_sample_t temp(*this);
            *this = s;
            *this += temp;

        /* Both samples are full, so we "zipper" them, choosing randomly between the two samples
        at each point with the appropriate probability. */
        } else {
            assert(n >= goal && s.n >= goal);
            for (int i = 0; i < goal; i++) {
                if (static_cast<int>(xrandom(0, n + s.n - 1)) < s.n) {
                    samples[i] = s.samples[i];
                }
            }
            n += s.n;
        }

        return *this;
    }

    /* Returns the actual number of things in the reservoir */
    size_t size() {
        return std::min(n, goal);
    }

    void clear() {
        n = 0;
    }
};

#endif // __STRESS_CLIENT_UTILS_HPP__

