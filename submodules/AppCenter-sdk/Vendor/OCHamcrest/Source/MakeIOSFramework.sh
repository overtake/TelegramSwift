#!/bin/bash

# First build the OS X framework to get its folder structure.
xcodebuild -configuration Release -target OCHamcrest -sdk macosx

# We'll copy the OS X framework to a new location, then modify it in place.
OSX_FRAMEWORK="build/Release/OCHamcrest.framework/"
IOS_FRAMEWORK="build/Release/OCHamcrestIOS.framework/"

# Trigger builds of the static library for both the simulator and the device.
xcodebuild -configuration Release -target libochamcrest -sdk iphoneos
OUT=$?
if [ "${OUT}" -ne "0" ]; then
    echo Device build failed
    exit ${OUT}
fi
xcodebuild -configuration Release -target libochamcrest -sdk iphonesimulator
OUT=$?
if [ "${OUT}" -ne "0" ]; then
    echo Simulator build failed
    exit ${OUT}
fi

# Copy the OS X framework to the new location.
mkdir -p "${IOS_FRAMEWORK}"
rsync -q -a --delete "${OSX_FRAMEWORK}" "${IOS_FRAMEWORK}"

# Rename the main header.
mv "${IOS_FRAMEWORK}/Headers/OCHamcrest.h" "${IOS_FRAMEWORK}/Headers/OCHamcrestIOS.h"

# Update all imports to use the new framework name.
IMPORT_EXPRESSION="s/#import <OCHamcrest/#import <OCHamcrestIOS/g;"
find "${IOS_FRAMEWORK}" -name '*.h' -print0 | xargs -0 perl -pi -e "${IMPORT_EXPRESSION}"

# Delete the existing (OS X) library and the link to it.
rm "${IOS_FRAMEWORK}/OCHamcrest" "${IOS_FRAMEWORK}/Versions/Current/OCHamcrest"

# Create a new library that is a fat library containing both static libraries.
DEVICE_LIB="build/Release-iphoneos/libochamcrest.a"
SIMULATOR_LIB="build/Release-iphonesimulator/libochamcrest.a"
OUTPUT_LIB="${IOS_FRAMEWORK}/Versions/Current/OCHamcrestIOS"

lipo -create "${DEVICE_LIB}" "${SIMULATOR_LIB}" -o "${OUTPUT_LIB}"

# Add a symlink, as required by the framework.
ln -s Versions/Current/OCHamcrestIOS "${IOS_FRAMEWORK}/OCHamcrestIOS"

# Update the name in the plist file.
NAME_EXPRESSION="s/OCHamcrest/OCHamcrestIOS/g;"
perl -pi -e "${NAME_EXPRESSION}" "${IOS_FRAMEWORK}/Resources/Info.plist"

# Update the module variables.
perl -pi -e "s/OCHamcrestVersionNumber/OCHamcrestIOSVersionNumber/" "${IOS_FRAMEWORK}/Headers/OCHamcrestIOS.h"
perl -pi -e "s/OCHamcrestVersionString/OCHamcrestIOSVersionString/" "${IOS_FRAMEWORK}/Headers/OCHamcrestIOS.h"
perl -pi -e "s/OCHamcrest/OCHamcrestIOS/" "${IOS_FRAMEWORK}/Modules/module.modulemap"
