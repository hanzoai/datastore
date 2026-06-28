# keeper_quasar_poc — the historical seam proof: drives the REAL
# KeeperStateMachine<KeeperMemoryStorage> with the original toy `libluxconsensus`
# (pkg/c). Kept as the documented baseline for the seam mechanism. Opt-in;
# requires -DLUXCONSENSUS_DIR (a dir with include/lux_consensus.h + lib/libluxconsensus.a).
# NOTE: that backend is a forgeable counter — superseded by the real consensus2
# path below; this target exists only to document the seam, not for finality.
if (LUXCONSENSUS_DIR)
    datastore_add_executable (keeper_quasar_poc keeper_quasar_poc.cpp)
    target_include_directories (keeper_quasar_poc PRIVATE "${LUXCONSENSUS_DIR}/include")
    target_link_libraries (keeper_quasar_poc PRIVATE dbms "${LUXCONSENSUS_DIR}/lib/libluxconsensus.a")
endif()

# keeper_quasar_engine_test — the NuRaft cutover: QuasarKeeperConsensus drives the
# REAL KeeperStateMachine through REAL leaderless Lux consensus (consensus2 —
# photon/wave + a >2/3-stake BLS quorum certificate). Requires a consensus2
# checkout (-DCONSENSUS2_DIR), its build dir with the prebuilt static libs
# (-DCONSENSUS2_BUILD, containing libconsensus2.a / libbls_signature.a /
# libblst.a), and the luxcpp root (-DLUXCPP_ROOT for the BLS + blst headers).
#
# The reused libraries are LINKED prebuilt (compiled with their own flags) and
# their headers are included SYSTEM — ClickHouse's -Werror must not police
# third-party headers (e.g. blst.h). Only our code is compiled into the target.
if (CONSENSUS2_DIR AND BLST_LIB AND LUXCPP_ROOT)
    # The reused C++ sources are compiled INTO the target so they share
    # ClickHouse's libc++ ABI (a prebuilt libstdc++ archive would not link). They
    # build clean in their own project, so -w keeps ClickHouse's -Werror from
    # policing third-party code; blst (C, ABI-neutral) is linked prebuilt.
    set(_reused
        "${CONSENSUS2_DIR}/src/quorum_cert_engine.cpp"
        "${CONSENSUS2_DIR}/src/wave.cpp"
        "${LUXCPP_ROOT}/crypto/bls/cpp/bls_signature.cpp")
    datastore_add_executable (keeper_quasar_engine_test
        keeper_quasar_engine_test.cpp
        QuasarKeeperConsensus.cpp
        ${_reused})
    set_source_files_properties (${_reused} PROPERTIES COMPILE_FLAGS "-w")
    target_include_directories (keeper_quasar_engine_test SYSTEM PRIVATE
        "${CONSENSUS2_DIR}/include" "${LUXCPP_ROOT}/crypto/bls/cpp" "${LUXCPP_ROOT}/blst/bindings")
    target_link_libraries (keeper_quasar_engine_test PRIVATE dbms "${BLST_LIB}")
endif()
