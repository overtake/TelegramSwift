#!/bin/sh

DOC_SUBDIR="Documentation"
DOC_DEST="${BUILD_DIR}/${DOC_SUBDIR}"

# Doxygen could be in /usr/local/bin (Homebrew) or /opt/local/bin (MacPorts)
# and those don't seem to be in PATH
export PATH=$PATH:/usr/local/bin:/opt/local/bin

if [ ! -z `which doxygen` ]; then
    # Generate the documentation
    pushd "${SRCROOT}" >/dev/null || exit 1
        doxygen
        if [ $? != 0 ]; then
            echo "ERROR: Documentation generation failed" >/dev/stderr
            exit 1
        fi
    popd >/dev/null

    # Populate the Documentation directory
    rm -rf "${DOC_DEST}"
    mv Documentation/API "${DOC_DEST}"
else
    echo "WARNING: Doxygen not available, skipping documentation generation" >/dev/stderr
fi
