add_library(_sparsehash INTERFACE)
target_include_directories(_sparsehash SYSTEM BEFORE INTERFACE "${Datastore_SOURCE_DIR}/contrib/sparsehash-c11")
add_library(ch_contrib::sparsehash ALIAS _sparsehash)
