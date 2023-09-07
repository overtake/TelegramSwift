find_package(Protobuf REQUIRED)

add_library(proto OBJECT)
init_target(proto)
add_library(tg_owt::proto ALIAS proto)

target_compile_definitions(proto
PRIVATE
    HAVE_CONFIG_H
)

set(proto_files
    ${webrtc_loc}/logging/rtc_event_log/rtc_event_log.proto
    ${webrtc_loc}/logging/rtc_event_log/rtc_event_log2.proto
)

protobuf_generate_cpp(proto_sources proto_headers ${proto_files})
set_source_files_properties(${proto_sources} ${proto_headers} PROPERTIES GENERATED TRUE)

target_sources(proto
PRIVATE
    ${proto_headers}
    ${proto_sources}
)

# CMAKE_CURRENT_BINARY_DIR is always used by protobuf_generate_cpp
# to place the generated files. It cannot be changed or overridden.
# We have to push it to the main project because the generated sources
# and headers will be used as include files.
target_include_directories(proto
INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}>
PRIVATE
    ${Protobuf_INCLUDE_DIRS}
)

target_link_libraries(proto
PRIVATE
    ${Protobuf_LIBRARIES}
)
