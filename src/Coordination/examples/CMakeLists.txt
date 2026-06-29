# keeper_quasar_poc — the historical seam proof: drives the REAL
# KeeperStateMachine<KeeperMemoryStorage> with the original toy `libluxconsensus`
# (pkg/c). Kept as the documented baseline for the seam mechanism. Opt-in;
# requires -DLUXCONSENSUS_DIR (a dir with include/lux_consensus.h + lib/libluxconsensus.a).
# NOTE: that backend is a forgeable counter — superseded by the real consensus2
# path below; this target exists only to document the seam, not for finality.
if (LUXCONSENSUS_DIR)
    clickhouse_add_executable (keeper_quasar_poc keeper_quasar_poc.cpp)
    target_include_directories (keeper_quasar_poc PRIVATE "${LUXCONSENSUS_DIR}/include")
    target_link_libraries (keeper_quasar_poc PRIVATE dbms "${LUXCONSENSUS_DIR}/lib/libluxconsensus.a")
endif()

# keeper_quasar_engine_test — the NuRaft cutover regression test: QuasarKeeperConsensus
# drives the REAL KeeperStateMachine through REAL leaderless Lux consensus (consensus2
# — photon/wave + a >2/3-stake BLS quorum certificate).
#
# QuasarKeeperConsensus and the reused consensus2/BLS sources are now compiled into
# `dbms` (the engine, not just a demo), and `dbms` links `_consensus2_keeper` which
# carries the consensus2 + BLS + blst SYSTEM include dirs and the blst archive
# transitively. So the test only compiles its OWN translation unit and links `dbms`.
if (TARGET _consensus2_keeper)
    clickhouse_add_executable (keeper_quasar_engine_test keeper_quasar_engine_test.cpp)
    target_link_libraries (keeper_quasar_engine_test PRIVATE dbms)

    # keeper_consensus_bench — the engine-overhead benchmark (nuraft-floor / nuraft-wal
    # / quasar over one deterministic ReplicatedMergeTree workload).
    clickhouse_add_executable (keeper_consensus_bench keeper_consensus_bench.cpp)
    target_link_libraries (keeper_consensus_bench PRIVATE dbms)
endif()
