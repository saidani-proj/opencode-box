#!/usr/bin/env bash
set -u

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$TESTS_DIR")"
SCRIPT="$ROOT/src/opencode-box"
MOCK_DIR="$TESTS_DIR/bin"

PASS=0
FAIL=0

note() { printf '%s\n' "$*"; }
ok() { PASS=$((PASS + 1)); }
ko() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$*"; }

setup() {
    TEST_HOME="$(mktemp -d)"
    TEST_CWD="$(mktemp -d)"
    DOCKER_LOG="$(mktemp)"
    OUT_FILE="$(mktemp)"
    ERR_FILE="$(mktemp)"
    export HOME="$TEST_HOME"
    export MOCK_DOCKER_LOG="$DOCKER_LOG"
    export PATH="$MOCK_DIR:$PATH"
}

teardown() {
    rm -rf "$TEST_HOME" "$TEST_CWD" "$DOCKER_LOG" "$OUT_FILE" "$ERR_FILE"
}

run_script() {   # <dir> <args...> ; sets RC
    local dir="$1"
    shift
    : > "$DOCKER_LOG"
    ( cd "$dir" && "$SCRIPT" "$@" ) > "$OUT_FILE" 2> "$ERR_FILE"
    RC=$?
}

expect_exit() {  # <label> <expected>
    if [ "$RC" -eq "$2" ]; then ok; else ko "$1: expected exit $2, got $RC"; fi
}

expect_out() {   # <label> <substring>
    if grep -q -- "$2" "$OUT_FILE"; then ok; else ko "$1: stdout lacks '$2'"; fi
}

expect_err() {   # <label> <substring>
    if grep -q -- "$2" "$ERR_FILE"; then ok; else ko "$1: stderr lacks '$2'"; fi
}

expect_log() {   # <label> <substring>
    if grep -q -- "$2" "$DOCKER_LOG"; then ok; else ko "$1: docker log lacks '$2'"; fi
}

expect_not_log() {   # <label> <substring>
    if grep -q -- "$2" "$DOCKER_LOG"; then ko "$1: docker log should NOT contain '$2'"; else ok; fi
}

expect_call_count() {   # <label> <expected-count>
    local n
    n="$(wc -l < "$DOCKER_LOG")"
    if [ "$n" -eq "$2" ]; then ok; else ko "$1: expected $2 docker calls, got $n"; fi
}

expect_first_log() {   # <label> <substring>
    local first
    first="$(head -n1 "$DOCKER_LOG")"
    if [ "$first" = "$2" ]; then ok; else ko "$1: expected first call '$2', got '$first'"; fi
}

expect_last_log() {   # <label> <substring>
    local last
    last="$(tail -n1 "$DOCKER_LOG")"
    if [ "$last" = "$2" ]; then ok; else ko "$1: expected last call '$2', got '$last'"; fi
}

# ---------------------------------------------------------------- help / usage

test_help() {
    note "test: help"
    run_script "$TEST_CWD" help
    expect_exit help 0
    for c in install uninstall up down exe root; do
        expect_out "help lists $c" "$c"
    done
}

test_help_short() {
    note "test: -h"
    run_script "$TEST_CWD" -h
    expect_exit "-h" 0
    expect_out "-h usage" "Usage:"
}

test_help_long() {
    note "test: --help"
    run_script "$TEST_CWD" --help
    expect_exit "--help" 0
    expect_out "--help usage" "Usage:"
}

test_no_args() {
    note "test: no arguments"
    run_script "$TEST_CWD"
    expect_exit "no args" 1
    expect_err "no args -> unknown" "Unknown command"
}

test_unknown_command() {
    note "test: unknown command"
    run_script "$TEST_CWD" bogus
    expect_exit "bogus" 1
    expect_err "bogus -> unknown" "Unknown command: bogus"
    expect_out "bogus -> usage" "Usage:"
}

# ---------------------------------------------------------------- subcommands

test_install() {
    note "test: install"
    run_script "$TEST_CWD" install
    expect_exit install 0
    expect_call_count install 1
    expect_log install "<run>"
    expect_log install "<-it>"
    expect_log install "<-v>"
    expect_log install "<$TEST_HOME/opencode-work:/work>"
    expect_log install "<--name>"
    expect_log install "<opencode>"
    expect_log install "<ubuntu:24.04>"
}

test_uninstall() {
    note "test: uninstall"
    run_script "$TEST_CWD" uninstall
    expect_exit uninstall 0
    expect_call_count uninstall 2
    expect_first_log uninstall "docker <stop> <opencode>"
    expect_last_log uninstall "docker <rm> <opencode>"
}

test_down() {
    note "test: down"
    run_script "$TEST_CWD" down
    expect_exit down 0
    expect_call_count down 1
    expect_log down "docker <stop> <opencode>"
    expect_not_log down "<rm>"
    expect_not_log down "<start>"
}

test_exe() {
    note "test: exe"
    run_script "$TEST_CWD" exe
    expect_exit exe 0
    expect_call_count exe 1
    expect_log exe "<exec>"
    expect_log exe "<-it>"
    expect_log exe "<-u>"
    expect_log exe "<$(id -u):$(id -g)>"
    expect_log exe "docker <exec> <-it> <-u> <$(id -u):$(id -g)> <opencode> <bash>"
}

test_root() {
    note "test: root"
    run_script "$TEST_CWD" root
    expect_exit root 0
    expect_call_count root 1
    expect_log root "docker <exec> <-it> <opencode> <bash>"
    expect_not_log root "<-u>"
}

test_up() {
    note "test: up"
    local old_target
    old_target="$(mktemp -d)"
    ln -s "$old_target" "$HOME/opencode-work"

    run_script "$TEST_CWD" up
    expect_exit up 0
    expect_call_count up 3
    expect_first_log up "docker <stop> <opencode>"
    expect_log up "docker <start> <opencode>"
    expect_last_log up "docker <exec> <-it> <-u> <$(id -u):$(id -g)> <opencode> <bash>"

    if [ "$(readlink "$HOME/opencode-work")" = "$TEST_CWD" ]; then
        ok
    else
        ko "up: ~/opencode-work must point to the running dir"
    fi
    rm -rf "$old_target"
}

# ---------------------------------------------------------------- run all

main() {
    test_help
    test_help_short
    test_help_long
    test_no_args
    test_unknown_command
    test_install
    test_uninstall
    test_down
    test_exe
    test_root
    test_up

    note ""
    note "Results: $PASS passed, $FAIL failed"
    [ "$FAIL" -eq 0 ]
}

setup
main
RC=$?
teardown
exit "$RC"