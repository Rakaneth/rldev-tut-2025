#!/usr/bin/env bash
EXE=rltut
DEBUGFLD=./bin/Debug
RLSFLD=./bin/Release

if [ ! -d $DEBUGFLD ]; then
    mkdir -p $DEBUGFLD
fi

if [ ! -d $RLSFLD ]; then
    mkdir -p $RLSFLD
fi

case $1 in
    debug)
        odin build src -out:$DEBUGFLD/$EXE -debug
        ;;
    release)
        odin build src -out:$RLSFLD/$EXE
        ;;
    clean)
        rm -rf bin
        ;;
    *)
        echo "Use: build.sh (debug|release)"
        ;;
esac