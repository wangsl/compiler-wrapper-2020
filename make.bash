#!/bin/bash

# $Id$

args=
if [ "$N_MAKE_THREADS" != "" ]; then
    args="-j $N_MAKE_THREADS"
fi

make=/usr/bin/make
if [ "$MAKE_BIN_PATH" != "" ]; then
    make=$MAKE_BIN_PATH/make
fi

$make "$@" $args

