set (SRCS
    AbstractConfigurationComparison.cpp
    ConfigProcessor.cpp
    getClientConfigPath.cpp
    getLocalConfigPath.cpp
    ConfigReloader.cpp
    YAMLParser.cpp
    ConfigHelper.cpp
    parseConnectionCredentials.cpp
)

add_library(datastore_common_config ${SRCS})
target_link_libraries(datastore_common_config
    PUBLIC
        datastore_common_zookeeper_base
        datastore_common_zookeeper
        common
        Poco::XML
)

if (TARGET ch_contrib::yaml_cpp)
    target_link_libraries(datastore_common_config PRIVATE ch_contrib::yaml_cpp)
endif()
