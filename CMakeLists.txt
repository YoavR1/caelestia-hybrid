cmake_minimum_required(VERSION 3.19)

set(REMOTE_REPO_URL "https://github.com/caelestia-dots/shell.git")

if(NOT DEFINED VERSION)
    # Fetch the latest annotated or lightweight tag from the remote repo
    execute_process(
        COMMAND git ls-remote --tags --sort=-v:refname "${REMOTE_REPO_URL}"
        OUTPUT_VARIABLE REMOTE_TAGS_RAW
        RESULT_VARIABLE GIT_TAG_RESULT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(NOT GIT_TAG_RESULT EQUAL 0 OR "${REMOTE_TAGS_RAW}" STREQUAL "")
        message(FATAL_ERROR "Failed to query tags from ${REMOTE_REPO_URL}")
    endif()

    # Extract the first ref tag name (strips commit hash and peels ^{})
    string(REGEX MATCH "refs/tags/([^\n\^\t ]+)" _MATCH "${REMOTE_TAGS_RAW}")
    set(VERSION "${CMAKE_MATCH_1}")

    if("${VERSION}" STREQUAL "")
        message(FATAL_ERROR "VERSION is not set and failed to parse from remote tags")
    endif()
endif()

if(NOT DEFINED GIT_REVISION)
    # Fetch HEAD commit hash from the remote repo
    execute_process(
        COMMAND git ls-remote "${REMOTE_REPO_URL}" HEAD
        OUTPUT_VARIABLE REMOTE_HEAD_RAW
        RESULT_VARIABLE GIT_REV_RESULT
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(NOT GIT_REV_RESULT EQUAL 0 OR "${REMOTE_HEAD_RAW}" STREQUAL "")
        message(FATAL_ERROR "GIT_REVISION is not set and failed to get from remote repo")
    endif()

    # Extract the 40-character commit SHA
    string(REGEX MATCH "^([0-9a-fA-F]+)" GIT_REVISION "${REMOTE_HEAD_RAW}")
endif()

string(REGEX REPLACE "^v" "" VERSION "${VERSION}")

project(caelestia-shell VERSION ${VERSION} LANGUAGES CXX)

if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "/" CACHE PATH "Installation prefix" FORCE)
endif()

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")

set(DISTRIBUTOR "Unset" CACHE STRING "Distributor")
set(ENABLE_MODULES "extras;plugin;shell" CACHE STRING "Modules to build/install")
set(INSTALL_LIBDIR "${CMAKE_INSTALL_LIBDIR}/caelestia" CACHE STRING "Library install dir")
set(INSTALL_QMLDIR "${CMAKE_INSTALL_LIBDIR}/qt6/qml" CACHE STRING "QML install dir")
set(INSTALL_QSCONFDIR "${CMAKE_INSTALL_SYSCONFDIR}/xdg/quickshell/caelestia" CACHE STRING "Quickshell config install dir")

add_compile_definitions(
    QT_NO_CAST_FROM_ASCII
    QT_NO_CAST_TO_ASCII
    QT_NO_CAST_FROM_BYTEARRAY
)

add_compile_options(
    -Wall -Wextra -Wpedantic -Wshadow -Wconversion
    -Wold-style-cast -Wnull-dereference -Wdouble-promotion
    -Wformat=2 -Wfloat-equal -Woverloaded-virtual
    -Wsign-conversion -Wredundant-decls -Wswitch
    -Wunreachable-code
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wunused-lambda-capture -Wno-nonportable-include-path)
endif()

if("extras" IN_LIST ENABLE_MODULES)
    add_subdirectory(extras)
endif()

if("plugin" IN_LIST ENABLE_MODULES)
    add_subdirectory(plugin)
endif()

if("shell" IN_LIST ENABLE_MODULES)
    foreach(dir assets components modules services utils)
        install(DIRECTORY ${dir} DESTINATION "${INSTALL_QSCONFDIR}")
    endforeach()

    install(PROGRAMS assets/wrap_term_launch.sh DESTINATION "${INSTALL_QSCONFDIR}/assets")

    file(READ shell.qml SHELL_QML)
    string(REPLACE "settings.watchFiles: true" "settings.watchFiles: false" SHELL_QML "${SHELL_QML}")
    file(WRITE "${CMAKE_BINARY_DIR}/qml/shell.qml" "${SHELL_QML}")
    install(FILES "${CMAKE_BINARY_DIR}/qml/shell.qml" DESTINATION "${INSTALL_QSCONFDIR}")

    install(FILES LICENSE DESTINATION "${INSTALL_QSCONFDIR}")
endif()
