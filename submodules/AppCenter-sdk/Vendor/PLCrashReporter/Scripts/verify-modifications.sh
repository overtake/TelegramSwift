#!/bin/sh

# Attempt to verify that the code we're building matches the source archive we're generating
# We only check for local modifications; in theory, we could assert the existence of a (local, not yet pushed) release tag.
if [ "${PL_ALLOW_LOCAL_MODS}" != 1 ] && [ "${CONFIGURATION}" = "Release" ]; then
    if [ "$(git status --porcelain | grep -v '??' | wc -l | awk '{print $1}')" != "0" ]; then
        echo "" >/dev/stderr
        echo "=== RELEASE BUILD ERROR ===" >/dev/stderr
        echo "Local modifications are not permitted when generating a Release build." >/dev/stderr
        echo "Modifications:" >/dev/stderr
        git status --porcelain | grep -v '??' >/dev/stderr

        echo "" >/dev/stderr
        echo "Set the PL_ALLOW_LOCAL_MODS=1 to bypass this check, or use a non-release build configuration:" >/dev/stderr
        echo "  env PL_ALLOW_LOCAL_MODS=1 xcodebuild ..." >/dev/stderr
        echo "=== RELEASE BUILD ERROR ===" >/dev/stderr
        echo "" >/dev/stderr

        exit 1
    fi
fi
