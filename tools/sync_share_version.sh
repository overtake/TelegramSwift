#!/bin/sh

if [ $# -ne 2 ]; then
    echo usage: $0 app-plist-file share-plist-file
    exit 1
fi

plist="$1"
shareplist="$2"
dir="$(dirname "$plist")"

version=$(/usr/libexec/Plistbuddy -c "Print CFBundleShortVersionString" "$plist")

if [ -z "$version" ]; then
    echo "No version number in $plist"
    exit 2
fi

buildnum=$(/usr/libexec/Plistbuddy -c "Print CFBundleVersion" "$plist")

if [ -z "$buildnum" ]; then
    echo "No build number in $plist"
    exit 2
fi

/usr/libexec/Plistbuddy -c "Set CFBundleShortVersionString $version" "$shareplist"
/usr/libexec/Plistbuddy -c "Set CFBundleVersion $buildnum" "$shareplist"
