#!/usr/bin/env bats

setup() {
  export TMPDIR_ROOT
  TMPDIR_ROOT="$(mktemp -d)"

  # put stubs first in PATH
  chmod +x "${BATS_TEST_DIRNAME}/fixtures/ssh-agent.stub"
  chmod +x "${BATS_TEST_DIRNAME}/fixtures/ssh-add.stub"
  ln -sf "${BATS_TEST_DIRNAME}/fixtures/ssh-agent.stub" "${BATS_TEST_DIRNAME}/fixtures/ssh-agent"
  ln -sf "${BATS_TEST_DIRNAME}/fixtures/ssh-add.stub" "${BATS_TEST_DIRNAME}/fixtures/ssh-add"
  export PATH="${BATS_TEST_DIRNAME}/fixtures:${PATH}"

  source "${BATS_TEST_DIRNAME}/../lib/ssha_agent.sh"
}

teardown() {
  rm -rf "${TMPDIR_ROOT}"
}

@test "agent_status warns when SSH_AUTH_SOCK is missing" {
  unset SSH_AUTH_SOCK || true
  run ssha::agent_status
  [ "$status" -ne 0 ]
  [[ "$output" == *"NOT running"* ]]
}

@test "agent_start sets SSH_AUTH_SOCK (via stub)" {
  unset SSH_AUTH_SOCK || true

  # call directly (NOT via `run`) so eval/export happens in this shell
  ssha::agent_start >/dev/null
  [ "$?" -eq 0 ]

  [[ -n "${SSH_AUTH_SOCK:-}" ]]
}


@test "agent_add_key fails if key does not exist" {
  run ssha::agent_add_key "/nope/key"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Key not found"* ]]
}

@test "agent_add_key works if key exists (ssh-add stub)" {
  key="${TMPDIR_ROOT}/id_ed25519_test"
  echo "X" > "${key}"
  run ssha::agent_add_key "${key}"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Key added"* ]]
}
