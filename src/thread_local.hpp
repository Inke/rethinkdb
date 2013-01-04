// Copyright 2010-2012 RethinkDB, all rights reserved.
#ifndef THREAD_LOCAL_HPP_
#define THREAD_LOCAL_HPP_

#include "errors.hpp"

#ifdef __ICC
#define TLS_with_init(type, name, initial)                              \
    static pthread_key_t TLS_ ## name ## _key;                          \
    static pthread_once_t TLS_ ## name ## _key_once;                    \
                                                                        \
    static void TLS_ ## name ## _destructor(void *ptr) {                \
        delete static_cast<type *>(ptr);                                \
    }                                                                   \
                                                                        \
    static void TLS_make_ ## name ## _key() {                           \
        int res = pthread_key_create(& TLS_ ## name ## _key,            \
                                     TLS_ ## name ## _destructor);      \
        guarantee_xerr(res == 0, res, "could not pthread_key_create");  \
    }                                                                   \
                                                                        \
    static void TLS_intialize_ ## name () {                             \
        int res = pthread_once(& TLS_ ## name ## _key_once,             \
                               TLS_make_ ## name ## _key);              \
        guarantee_xerr(res == 0, res, "could not pthread_once");        \
                                                                        \
        if (pthread_getspecific(TLS_ ## name ## _key) == NULL) {        \
            type *ptr = new type;                                       \
            *ptr = initial;                                             \
            res = pthread_setspecific(TLS_ ## name ## _key, ptr);       \
            guarantee_xerr(res == 0, res,                               \
                           "pthread_setspecific failed");               \
        }                                                               \
    }                                                                   \
                                                                        \
    type TLS_get_ ## name () {                                          \
        TLS_intialize_ ## name();                                       \
            return *static_cast<type *>(pthread_getspecific(TLS_ ## name ## _key)); \
    }                                                                   \
                                                                        \
    void TLS_set_ ## name (type val) {                                  \
        TLS_intialize_ ## name();                                       \
            *static_cast<type *>(pthread_getspecific(TLS_ ## name ## _key)) = val; \
    }

#else  //  __ICC

#define TLS_with_init(type, name, initial)              \
    static __thread type TLS_ ## name = initial;        \
                                                        \
    type TLS_get_ ## name () {                          \
        return TLS_ ## name;                            \
    }                                                   \
                                                        \
    void TLS_set_ ## name(type val) {                   \
        TLS_ ## name = val;                             \
    }                                                   \

#endif  //  __ICC

#ifdef __ICC
#define TLS(type, name)                                                 \
    static pthread_key_t TLS_ ## name ## _key;                          \
    static pthread_once_t TLS_ ## name ## _key_once;                    \
                                                                        \
    static void TLS_ ## name ## _destructor(void *ptr) {                \
        delete static_cast<type *>(ptr);                                \
    }                                                                   \
                                                                        \
    static void TLS_make_ ## name ## _key() {                           \
        int res = pthread_key_create(& TLS_ ## name ## _key,            \
                                     TLS_ ## name ## _destructor);      \
        guarantee_xerr(res == 0, res, "pthread_key_create failed");     \
    }                                                                   \
                                                                        \
    static void TLS_intialize_ ## name () {                             \
        int res = pthread_once(& TLS_ ## name ## _key_once,             \
                               TLS_make_ ## name ## _key);              \
        guarantee_xerr(res == 0, res, "pthread_once failed");           \
                                                                        \
        if (pthread_getspecific(TLS_ ## name ## _key) == NULL) {        \
            type *ptr = new type;                                       \
            pthread_setspecific(TLS_ ## name ## _key, ptr);             \
        }                                                               \
    }                                                                   \
                                                                        \
    type TLS_get_ ## name () {                                          \
        TLS_intialize_ ## name();                                       \
            return *static_cast<type *>(pthread_getspecific(TLS_ ## name ## _key)); \
    }                                                                   \
                                                                        \
    void TLS_set_ ## name (type val) {                                  \
        TLS_intialize_ ## name();                                       \
            *static_cast<type *>(pthread_getspecific(TLS_ ## name ## _key)) = val; \
    }

#else

#define TLS(type, name)                         \
    static __thread type TLS_ ## name;          \
                                                \
    type TLS_get_ ## name () {                  \
        return TLS_ ## name;                    \
    }                                           \
                                                \
    void TLS_set_ ## name(type val) {           \
        TLS_ ## name = val;                     \
    }                                           \

#endif  // __ICC

#endif /* THREAD_LOCAL_HPP_ */
