datastore_add_executable (string_pool string_pool.cpp)
target_link_libraries (string_pool PRIVATE dbms datastore_common_io datastore_common_config ch_contrib::sparsehash)

datastore_add_executable (field field.cpp)
target_link_libraries (field PRIVATE dbms)

datastore_add_executable (string_ref_hash string_ref_hash.cpp)
target_link_libraries (string_ref_hash PRIVATE datastore_common_io datastore_common_config)

if (TARGET ch_contrib::google_cloud_cpp)
    datastore_add_executable (gcloud_storage gcloud_storage.cpp)
    target_link_libraries (gcloud_storage PRIVATE datastore_common_io datastore_common_config dbms)
endif()

if (ENABLE_GOOGLE_CLOUD_CPP_KMS)
    datastore_add_executable (gcloud_kms gcloud_kms.cpp)
    target_link_libraries (gcloud_kms PRIVATE datastore_common_io datastore_common_config dbms)
endif()
