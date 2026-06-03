#!/bin/bash

function fail() {
    echo "FAILED: $*." >&2
    exit 1
}

function expect_log() {
    local pattern=$1
    local message=${2:-"Expected regexp '$pattern' not found"}
    grep -sq -- "$pattern" $TEST_log && return 0

    fail "$message"
    return 1
}

function expect_not_log() {
    local pattern=$1
    local message=${2:-"Unexpected regexp '$pattern' found"}
    grep -sq -- "$pattern" $TEST_log || return 0

    fail "$message"
    return 1
}
