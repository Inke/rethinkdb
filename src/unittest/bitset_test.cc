// Copyright 2010-2012 RethinkDB, all rights reserved.
#include "unittest/gtest.hpp"

#include "containers/bitset.hpp"

namespace unittest {

TEST(BitsetTest, ClearedAtStart) {
    bitset_t b(100);
    ASSERT_EQ(100u, b.size());
    ASSERT_EQ(0u, b.count());
    for (int i = 0; i < 100; i++) {
        ASSERT_FALSE(b.test(i));
    }
    b.verify();
}

TEST(BitsetTest, SetsGets) {
    bitset_t b(100);

    b.set(20, true);
    b.set(0, true);
    b.set(99, true);

    ASSERT_TRUE(b.test(20));
    ASSERT_TRUE(b.test(0));
    ASSERT_TRUE(b.test(99));
    ASSERT_TRUE(b[99]);
    ASSERT_FALSE(b.test(50));

    ASSERT_EQ(3u, b.count());

    b.set();

    ASSERT_EQ(100u, b.count());
    ASSERT_TRUE(b[80]);

    b.verify();
}

TEST(BitsetTest, Resize) {
    bitset_t b(100);
    b.set(98, true);
    b.set(99, true);
    ASSERT_EQ(2u, b.count());
    b.resize(99);
    b.verify();
    ASSERT_EQ(1u, b.count());
    b.resize(100);
    b.verify();
    ASSERT_EQ(1u, b.count());
    b.set(99, true);
    ASSERT_EQ(2u, b.count());
    b.verify();
}

TEST(BitsetTest, BoundsChecking) {
    bitset_t b(100);
    ASSERT_DEATH(b.test(400), "");
    ASSERT_DEATH(b.set(static_cast<unsigned int>(-5)), "");
    ASSERT_DEATH(b.test(100), "");
    ASSERT_DEATH(b.test(static_cast<unsigned int>(-1)), "");
    b.set(99, true);
    ASSERT_TRUE(b.test(99));
    b.verify();
}

}  // namespace unittest
