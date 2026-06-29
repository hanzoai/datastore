# ── Single-node Quasar coordination engine (consensus2 + BLS) ────────────────────
# The NuRaft raft ENGINE has been removed from the build; ordering and finality are
# now the leaderless Lux consensus (consensus2). KeeperServer + QuasarKeeperConsensus
# (compiled into `dbms` from this directory) call into these reused, prebuilt-clean
# C++ sources. They build warning-clean in their own project, so -w keeps ClickHouse's
# -Werror from policing third-party code; their headers are included SYSTEM. blst
# (C, ABI-neutral) is linked prebuilt.
#
# Configure with:
#   -DCONSENSUS2_DIR=<consensus2 checkout>   (include/ + src/)
#   -DLUXCPP_ROOT=<luxcpp root>              (crypto/bls/cpp + blst/bindings)
#   -DBLST_LIB=<path to libblst.a>
set(CONSENSUS2_DIR "" CACHE PATH "consensus2 checkout providing include/ and src/")
set(LUXCPP_ROOT "" CACHE PATH "luxcpp root providing crypto/bls/cpp and blst/bindings")
set(BLST_LIB "" CACHE FILEPATH "prebuilt libblst.a")

if (NOT CONSENSUS2_DIR OR NOT LUXCPP_ROOT OR NOT BLST_LIB)
    message(FATAL_ERROR
        "The single-node Quasar keeper requires CONSENSUS2_DIR, LUXCPP_ROOT and BLST_LIB "
        "(the NuRaft raft engine has been removed and no longer provides ordering). "
        "Configure with -DCONSENSUS2_DIR=<consensus2> -DLUXCPP_ROOT=<luxcpp> -DBLST_LIB=<libblst.a>.")
endif()

add_library(_consensus2_keeper STATIC
    "${CONSENSUS2_DIR}/src/quorum_cert_engine.cpp"
    "${CONSENSUS2_DIR}/src/wave.cpp"
    "${LUXCPP_ROOT}/crypto/bls/cpp/bls_signature.cpp")
target_compile_options(_consensus2_keeper PRIVATE -w)
target_include_directories(_consensus2_keeper SYSTEM PUBLIC
    "${CONSENSUS2_DIR}/include"
    "${LUXCPP_ROOT}/crypto/bls/cpp"
    "${LUXCPP_ROOT}/blst/bindings")
target_link_libraries(_consensus2_keeper PUBLIC "${BLST_LIB}")

if (ENABLE_EXAMPLES)
    add_subdirectory(examples)
endif()

if (ENABLE_TESTS)
    # Focused coordination unit suite (the rip/nuraft-quasar smoke gate). Compiles only
    # the Coordination gtest sources + the shared gtest main + dbms, so the keeper
    # coordination tests can be exercised without building all of unit_tests_dbms.
    # The raw nuraft::raft_server fixture (TestSummingRaft1) is #if-0'd in
    # gtest_coordination.cpp — it tested the removed consensus ENGINE.
    file(GLOB keeper_coordination_gtest_sources CONFIGURE_DEPENDS "tests/gtest*.cpp")
    clickhouse_add_executable(keeper_coordination_gtest
        ${keeper_coordination_gtest_sources}
        "${ClickHouse_SOURCE_DIR}/src/Common/tests/gtest_main.cpp"
        "${ClickHouse_SOURCE_DIR}/src/Common/tests/gtest_global_context.cpp")
    target_compile_options(keeper_coordination_gtest PRIVATE -Wno-sign-compare)
    target_link_libraries(keeper_coordination_gtest PRIVATE
        ch_contrib::gmock_all
        ch_contrib::gtest
        clickhouse_functions
        clickhouse_aggregate_functions
        clickhouse_parsers
        clickhouse_storages_system
        dbms
        clickhouse_common_zookeeper_base
        clickhouse_common_config
        clickhouse_common_zookeeper)
    if (TARGET ch_contrib::krb5)
        target_link_libraries(keeper_coordination_gtest PRIVATE ch_contrib::krb5)
    endif()
endif()
