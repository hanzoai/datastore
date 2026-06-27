# Opt-in proof that the Keeper state machine can be driven by native Lux
# consensus (Quasar) instead of NuRaft. Only built when both example programs
# are enabled and a built libluxconsensus is pointed to via -DLUXCONSENSUS_DIR.
# Never part of a normal server build.
if (ENABLE_EXAMPLES AND LUXCONSENSUS_DIR)
    add_subdirectory(examples)
endif()
