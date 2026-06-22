set (DATASTORE_DOCKER_INIT_SOURCES docker-init.cpp)

set (DATASTORE_DOCKER_INIT_LINK
    PRIVATE
        datastore_common_io
)

datastore_program_add(docker-init)
