#!/usr/bin/env bash

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/project"
  export HOME="$BATS_TEST_TMPDIR/home"
  export SSHA_SSH_DIR="$HOME/.ssh"
  export MOCK_BIN="$BATS_TEST_TMPDIR/mockbin"
  export PATH="$MOCK_BIN:$PATH"

  mkdir -p "$TEST_ROOT" "$HOME" "$SSHA_SSH_DIR" "$MOCK_BIN"

  # Charger le core après avoir fixé HOME et SSHA_SSH_DIR
  source "$BATS_TEST_DIRNAME/../lib/ssha_core.sh"
}