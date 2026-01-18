#!/usr/bin/env bats

setup() {
  export TMPDIR_ROOT
  TMPDIR_ROOT="$(mktemp -d)"

  export SSHA_SSH_DIR="${TMPDIR_ROOT}/.ssh"
  mkdir -p "${SSHA_SSH_DIR}"

  # Put stub ssh-keygen first in PATH
  chmod +x "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen.stub"
  export PATH="${BATS_TEST_DIRNAME}/fixtures:${PATH}"
  ln -sf "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen.stub" "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen"

  source "${BATS_TEST_DIRNAME}/../lib/ssha_core.sh"
}

teardown() {
  rm -rf "${TMPDIR_ROOT}"
}

@test "key_paths returns expected filenames" {
  run bash -c 'source lib/ssha_core.sh; SSHA_SSH_DIR="/x"; ssha::key_paths ed25519 planethoster'
  [ "$status" -eq 0 ]
  [[ "${output}" == *"/x/ed25519_planethoster"* ]]
  [[ "${output}" == *"/x/ed25519_planethoster.pub"* ]]
}

@test "append_host_block writes a host block" {
  cfg="${SSHA_SSH_DIR}/config"
  touch "${cfg}"

  run bash -c "source lib/ssha_core.sh; SSHA_SSH_DIR='${SSHA_SSH_DIR}'; ssha::append_host_block '${cfg}' 'planethoster' 'node266-eu.n0c.com' 'dwmkyvke' '5022' '${SSHA_SSH_DIR}/ed25519_planethoster'"
  [ "$status" -eq 0 ]

  run grep -n "Host planethoster" "${cfg}"
  [ "$status" -eq 0 ]
  run grep -n "HostName node266-eu.n0c.com" "${cfg}"
  [ "$status" -eq 0 ]
  run grep -n "Port 5022" "${cfg}"
  [ "$status" -eq 0 ]
}

@test "remove_host_block removes only the target host" {
  cfg="${SSHA_SSH_DIR}/config"
  cat > "${cfg}" <<'EOF'
Host a
  HostName aa
Host planethoster
  HostName node266-eu.n0c.com
  User u
Host b
  HostName bb
EOF

  run bash -c "source lib/ssha_core.sh; ssha::remove_host_block '${cfg}' 'planethoster'"
  [ "$status" -eq 0 ]

  run grep -n "Host planethoster" "${cfg}"
  [ "$status" -ne 0 ]
  run grep -n "Host a" "${cfg}"
  [ "$status" -eq 0 ]
  run grep -n "Host b" "${cfg}"
  [ "$status" -eq 0 ]
}
