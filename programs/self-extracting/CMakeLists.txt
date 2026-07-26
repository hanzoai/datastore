
if (NOT(
        CMAKE_HOST_SYSTEM_NAME STREQUAL CMAKE_SYSTEM_NAME
        AND CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL CMAKE_SYSTEM_PROCESSOR
        AND NOT USE_MUSL
    )
)
    set (COMPRESSOR "${PROJECT_BINARY_DIR}/native/utils/self-extracting-executable/pre_compressor")
    set (DECOMPRESSOR "--decompressor=${PROJECT_BINARY_DIR}/utils/self-extracting-executable/decompressor")
else ()
    set (COMPRESSOR "${PROJECT_BINARY_DIR}/utils/self-extracting-executable/compressor")
endif ()

set(self_extracting_deps)

add_custom_target (datastore-self-extracting ALL
    ${CMAKE_COMMAND} -E remove datastore
    COMMAND ${COMPRESSOR} ${DECOMPRESSOR} datastore ../datastore
    DEPENDS datastore compressor
)
list(APPEND self_extracting_deps datastore-self-extracting)

if (BUILD_STRIPPED_BINARY)
    add_custom_target (datastore-self-extracting-stripped ALL
        ${CMAKE_COMMAND} -E remove datastore-stripped
        COMMAND ${COMPRESSOR} ${DECOMPRESSOR} datastore-stripped ../datastore-stripped
        DEPENDS datastore-stripped compressor
    )
    list(APPEND self_extracting_deps datastore-self-extracting-stripped)
endif()

if (BUILD_STANDALONE_KEEPER)
    add_custom_target (self-extracting-keeper ALL
        ${CMAKE_COMMAND} -E remove datastore-keeper
        COMMAND ${COMPRESSOR} ${DECOMPRESSOR} datastore-keeper ../datastore-keeper
        DEPENDS compressor datastore-keeper
    )
    list(APPEND self_extracting_deps self-extracting-keeper)
endif()

add_custom_target (self-extracting ALL
    DEPENDS ${self_extracting_deps}
)
