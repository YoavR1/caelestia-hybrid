set(PROTO_SRCS)
set(PROTO_HDRS)
protobuf_generate_cpp(PROTO_SRCS PROTO_HDRS
    QuickShare/proto/device_to_device_messages.proto
    QuickShare/proto/offline_wire_formats.proto
    QuickShare/proto/securegcm.proto
    QuickShare/proto/securemessage.proto
    QuickShare/proto/ukey.proto
    QuickShare/proto/wire_format.proto
)

# protoc's output is not ours to lint. CI builds with -Werror, and generated code trips
# warnings that vary with the protoc and compiler version -- clang's -Wnullability-extension
# broke the clazy leg on code no one here wrote. Silencing warnings for exactly these files
# keeps -Werror meaningful for every file that is ours.
set_source_files_properties(${PROTO_SRCS} PROPERTIES COMPILE_OPTIONS "-w")

qml_module(caelestia-services
    URI Caelestia.Services
    SOURCES
        service.cpp
        serviceref.cpp
        beattracker.cpp
        audiocollector.cpp
        audioprovider.cpp
        cavaprovider.cpp
        tickingservice.cpp
        sensorslib.cpp
        usagefmt.cpp
        cpu.cpp
        gpu.cpp
        memory.cpp
        diskinfo.cpp
        storage.cpp
        lyriccandidate.cpp
        lyrics.cpp
        sessionmanager.cpp
        discordipc.cpp
        QuickShare/QuickShareDiscovery.cpp
        QuickShare/QuickShareCrypto.cpp
        QuickShare/QuickShareConnection.cpp
        QuickShare/quickshare_service.cpp
        QuickShare/QuickShareBle.cpp
        networkusage.cpp
        hyprdevices.cpp
        hyprextras.cpp
        ${PROTO_SRCS}
    LIBRARIES
        Qt::DBus
        Qt::Network
        PkgConfig::Pipewire
        PkgConfig::Aubio
        PkgConfig::Cava
        Sensors::Sensors
        protobuf::libprotobuf
        OpenSSL::Crypto
        OpenSSL::SSL
        caelestia-core
        caelestia-config
    DEPENDENCIES
        Caelestia
        Caelestia.Config
)

target_include_directories(caelestia-services PRIVATE QuickShare ${CMAKE_CURRENT_BINARY_DIR})
