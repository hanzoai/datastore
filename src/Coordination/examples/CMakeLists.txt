# keeper_quasar_poc — drives the REAL KeeperStateMachine<KeeperMemoryStorage>
# (the class ReplicatedMergeTree coordinates through) with native Lux consensus
# (Quasar / libluxconsensus) in place of NuRaft. Opt-in; requires a built
# pkg/c checkout of luxfi/consensus pointed to by -DLUXCONSENSUS_DIR (a directory
# containing include/lux_consensus.h and lib/libluxconsensus.a).
datastore_add_executable (keeper_quasar_poc keeper_quasar_poc.cpp)
target_include_directories (keeper_quasar_poc PRIVATE "${LUXCONSENSUS_DIR}/include")
target_link_libraries (keeper_quasar_poc PRIVATE dbms "${LUXCONSENSUS_DIR}/lib/libluxconsensus.a")

# keeper_quasar_engine_test — exercises the reusable QuasarKeeperConsensus engine
# (src/Coordination/QuasarKeeperConsensus.h) against the real KeeperStateMachine,
# asserting the full commit contract the dispatcher relies on: ordered commit,
# per-entry commit callback, advancing committed index, real KeeperStorage state.
# The engine .cpp is compiled here (not yet into dbms — that contrib wiring is the
# next stage); the header lives under src/Coordination/ as the stable interface.
datastore_add_executable (keeper_quasar_engine_test keeper_quasar_engine_test.cpp QuasarKeeperConsensus.cpp)
target_include_directories (keeper_quasar_engine_test PRIVATE "${LUXCONSENSUS_DIR}/include")
target_link_libraries (keeper_quasar_engine_test PRIVATE dbms "${LUXCONSENSUS_DIR}/lib/libluxconsensus.a")
