#!/bin/bash

case "$(uname -s)" in
Linux*)     BUILD_MACHINE=linux;;
Darwin*)    BUILD_MACHINE=macOS;;
*)          BUILD_MACHINE=""
esac

function list_include_item {
local list="$1"
local item="$2"
if [[ $list =~ (^|[[:space:]])"$item"($|[[:space:]]) ]] ; then
result=0
else
result=1
fi
return $result
}

function clean_once {
RUNNING_PIDS=$(pgrep -f buildbox/build-telegram.sh)

if [ "$BUILD_MACHINE" == "linux" ]; then
virsh list --all --name | grep build-telegram | while read vm ; do
VM_PID=$(echo $vm | egrep -o 'build-telegram-[0-9]+' | egrep -o '[0-9]+')
if [ ! -z "$VM_PID" ] && [ ! -z "$vm" ]; then
if `list_include_item "$RUNNING_PIDS" "$VM_PID"` ; then
echo "$vm:$VM_PID is still valid"
else
virsh destroy "$vm" || true
virsh undefine "$vm" --remove-all-storage --nvram || true
fi
else
echo "Can't parse VM string $vm"
fi
done
elif [ "$BUILD_MACHINE" == "macOS" ]; then
prlctl list -a | grep build-telegram | while read vm ; do
VM_PID=$(echo $vm | grep -Eo 'build-telegram-\d+' | grep -Eo '\d+')
VM_UUID=$(echo $vm | grep -Eo '\{(\d|[a-f]|-)*\}')
if [ ! -z "$VM_PID" ] && [ ! -z "$VM_UUID" ]; then
if `list_include_item "$RUNNING_PIDS" "$VM_PID"` ; then
echo "$VM_UUID:$VM_PID is still valid"
else
prlctl stop "$VM_UUID" --kill || true
prlctl delete "$VM_UUID" || true
fi
else
echo "Can't parse VM string $vm"
fi
done
else
echo "Unknown build machine $(uname -s)"
fi
}

if [ "$1" == "loop" ]; then
while [ 1 ]; do
clean_once
sleep 10
done
else
clean_once
fi
