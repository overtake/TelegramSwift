#!/bin/bash
set -x
set -e


BUILD_TELEGRAM_VERSION="1"

MACOS_VERSION="10.15"
XCODE_VERSION="10.3"
GUEST_SHELL="bash"

VM_BASE_NAME="macos$(echo $MACOS_VERSION | sed -e 's/\.'/_/g)_Xcode$(echo $XCODE_VERSION | sed -e 's/\.'/_/g)"

BUILD_MACHINE="macOS";


BUILDBOX_DIR="buildbox"
BUILD_CONFIGURATION="$1"

rm -rf "$HOME/build-$BUILD_CONFIGURATION"
mkdir -p "$HOME/build-$BUILD_CONFIGURATION"

PROCESS_ID="$$"
VM_NAME="$VM_BASE_NAME-$(openssl rand -hex 10)-build-telegram-$PROCESS_ID"

prlctl clone "$VM_BASE_NAME" --linked --name "$VM_NAME"
prlctl start "$VM_NAME"


SOURCE_DIR=$(basename "$BASE_DIR")
rm -f "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar"
tar cf "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar" --exclude "$BUILDBOX_DIR" --exclude ".git" --exclude "./submodules/telegram-ios/.git" --exclude "./submodules/rlottie/.git" --exclude "./submodules/Sparkle/.git" --exclude "./submodules/ton/.git" --exclude "./submodules/Zip/.git"  --exclude "./submodules/libtgvoip/.git" --exclude "build" "."



while [ 1 ]; do
    TEST_IP=$(prlctl exec "$VM_NAME" "ifconfig | grep inet | grep broadcast | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1 | tr '\n' '\0'" || echo "")
    if [ ! -z "$TEST_IP" ]; then
        RESPONSE=$(ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$TEST_IP" -o ServerAliveInterval=60 -t "echo -n 1")
        if [ "$RESPONSE" == "1" ]; then
            VM_IP="$TEST_IP"
            break
        fi
    fi
sleep 1
done
#
ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "rm -rf build/"
ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "mkdir -p build;"
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar" telegram@"$VM_IP":build

ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "tar -xf build/Telegram.tar -C ./build"
ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "mkdir -p build/buildbox"
scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr "$BUILDBOX_DIR/build-vm.sh" telegram@"$VM_IP":build/buildbox
ssh -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null telegram@"$VM_IP" -o ServerAliveInterval=60 -t "$GUEST_SHELL -l build/buildbox/build-vm.sh $BUILD_CONFIGURATION" || true

scp -o LogLevel=ERROR -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -pr telegram@"$VM_IP":build/output/Telegram.tar "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar"


tar -xf "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar" -C "$HOME/build-$BUILD_CONFIGURATION"
rm -f "$HOME/build-$BUILD_CONFIGURATION/Telegram.tar"

prlctl stop "$VM_NAME" --kill
prlctl delete "$VM_NAME"

