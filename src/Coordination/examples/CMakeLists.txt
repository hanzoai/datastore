# keeper_quasar_poc — drives the REAL KeeperStateMachine<KeeperMemoryStorage>
# (the class ReplicatedMergeTree coordinates through) with native Lux consensus
# (Quasar / libluxconsensus) in place of NuRaft. Opt-in; requires a built
# pkg/c checkout of luxfi/consensus pointed to by -DLUXCONSENSUS_DIR (a directory
# containing include/lux_consensus.h and lib/libluxconsensus.a).
datastore_add_executable (keeper_quasar_poc keeper_quasar_poc.cpp)
target_include_directories (keeper_quasar_poc PRIVATE "${LUXCONSENSUS_DIR}/include")
target_link_libraries (keeper_quasar_poc PRIVATE dbms "${LUXCONSENSUS_DIR}/lib/libluxconsensus.a")
