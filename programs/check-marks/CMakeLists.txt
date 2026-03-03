set (DATASTORE_CHECK_MARKS_SOURCES CheckMarks.cpp)

set (DATASTORE_CHECK_MARKS_LINK
    PRIVATE
        boost::program_options
        datastore_aggregate_functions
        datastore_common_config
        dbms
)

datastore_program_add(check-marks)
