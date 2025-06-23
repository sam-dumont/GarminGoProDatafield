#!/bin/bash

set -e

usage() {
    echo "Usage: $0 [build|release|dev] <developer_key_path>"
    exit 1
}

if [ $# -ne 2 ]; then
    usage
fi

MODE=$1
DEV_KEY=$2

# Find the latest monkeybrains.jar from the current SDK
SDK_CFG="$HOME/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"
if [ ! -f "$SDK_CFG" ]; then
    echo "SDK config not found: $SDK_CFG"
    exit 1
fi
SDK_PATH=$(cat "$SDK_CFG" | tr -d '\n')
JAR="$SDK_PATH/bin/monkeybrains.jar"
if [ ! -f "$JAR" ]; then
    echo "monkeybrains.jar not found at $JAR"
    exit 1
fi

JUNGLES="$(pwd)/monkey.jungle;$(pwd)/barrels.jungle"

# Helper: switch store (beta/prod)
switch_store() {
    if [ "$1" = "beta" ]; then
        sed -i'' -e 's/74ca4a55-9bac-4658-9713-8ed6ca74ac00/ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d/g' manifest.xml && rm -f manifest.xml-e
        sed -i'' -e 's/GoPro Remote/BETA GPR/g' resources/strings/strings.xml && rm -f resources/strings/strings.xml-e
    else
        sed -i'' -e 's/ca32b7ec-0523-4ac7-a53f-eedcf12bfb3d/74ca4a55-9bac-4658-9713-8ed6ca74ac00/g' manifest.xml && rm -f manifest.xml-e
        sed -i'' -e 's/BETA GPR/GoPro Remote/g' resources/strings/strings.xml && rm -f resources/strings/strings.xml-e
    fi
    rm -f manifest.xml-e resources/strings/strings.xml-e
}

# Helper: set simulation mode in GoPro.mc
set_simulation_mode() {
    if [ "$1" = "on" ]; then
        sed -i'' -e 's/const SIMULATION_MODE = false;/const SIMULATION_MODE = true;/g' source/GoPro.mc && rm -f source/GoPro.mc-e
    else
        sed -i'' -e 's/const SIMULATION_MODE = true;/const SIMULATION_MODE = false;/g' source/GoPro.mc && rm -f source/GoPro.mc-e
    fi
}

# Helper: set debug log mode in GoPro.mc
set_debug_log() {
    if [ "$1" = "on" ]; then
        sed -i'' -e 's/const DEBUG_LOG = false;/const DEBUG_LOG = true;/g' source/GoPro.mc && rm -f source/GoPro.mc-e
    else
        sed -i'' -e 's/const DEBUG_LOG = true;/const DEBUG_LOG = false;/g' source/GoPro.mc && rm -f source/GoPro.mc-e
    fi
}

case "$MODE" in
    build)
        switch_store beta
        set_simulation_mode off
        set_debug_log on
        java -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true \
            -jar "$JAR" \
            -o bin/GarminGoProWidget.prg \
            -f "$JUNGLES" \
            -y "$DEV_KEY" \
            -d edge1050_sim -w -l 0 -O 3
        ;;
    release)
        switch_store prod
        set_simulation_mode off
        set_debug_log off
        java -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true \
            -jar "$JAR" \
            -o bin/GarminGoProWidget.iq \
            -f "$JUNGLES" \
            -y "$DEV_KEY" \
            -d edge1050_sim -w -l 0 -O 3
        ;;
    dev)
        switch_store beta
        set_simulation_mode on
        set_debug_log on
        java -Xms1g -Dfile.encoding=UTF-8 -Dapple.awt.UIElement=true \
            -jar "$JAR" \
            -o bin/GarminGoProWidget.prg \
            -f "$JUNGLES" \
            -y "$DEV_KEY" \
            -d edge1050_sim -w -l 0 -O 3
        ;;
    *)
        usage
        ;;
esac