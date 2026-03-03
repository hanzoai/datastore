# ZAP binary protocol handler for hanzo/datastore
add_library(datastore_server_zap
    ZAPHandler.cpp
)

target_include_directories(datastore_server_zap
    PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(datastore_server_zap
    PRIVATE
        datastore_common_io
        datastore_server
)
