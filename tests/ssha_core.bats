#!/usr/bin/env bats

setup() {
  export TMPDIR_ROOT
  TMPDIR_ROOT="$(mktemp -d)"

  export SSHA_SSH_DIR="${TMPDIR_ROOT}/.ssh"
  mkdir -p "${SSHA_SSH_DIR}"

  chmod +x "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen.stub"
  export PATH="${BATS_TEST_DIRNAME}/fixtures:${PATH}"
  ln -sf "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen.stub" "${BATS_TEST_DIRNAME}/fixtures/ssh-keygen"

  source "${BATS_TEST_DIRNAME}/../lib/ssha_colors.sh"
  source "${BATS_TEST_DIRNAME}/../lib/ssha_core.sh"
}

teardown() {
  rm -rf "${TMPDIR_ROOT}"
}

@test "key_paths returns expected filenames without encoding prefix" {
  run bash -c 'source lib/ssha_colors.sh; source lib/ssha_core.sh; SSHA_SSH_DIR="/x"; ssha::key_paths planethoster_loic'
  [ "$status" -eq 0 ]
  [[ "$output" == $'/x/planethoster_loic\n/x/planethoster_loic.pub' ]]
}

@test "normalize_keyname returns alias_user in lowercase with underscores" {
  run bash -c 'source lib/ssha_colors.sh; source lib/ssha_core.sh; ssha::normalize_keyname "GitHub-LDDVLP" "Git"'
  [ "$status" -eq 0 ]
  [ "$output" = "github_lddvlp_git" ]
}

@test "append_host_block writes a host block" {
  cfg="${SSHA_SSH_DIR}/config"
  touch "${cfg}"

  run bash -c "source lib/ssha_colors.sh; source lib/ssha_core.sh; SSHA_SSH_DIR='${SSHA_SSH_DIR}'; ssha::append_host_block '${cfg}' 'planethoster' 'node266-eu.n0c.com' 'dwmkyvke' '5022' '${SSHA_SSH_DIR}/planethoster_loic'"
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
  cat > "${cfg}" <<'CFG'
Host a
  HostName aa
Host planethoster
  HostName node266-eu.n0c.com
  User u
Host b
  HostName bb
CFG

  run bash -c "source lib/ssha_colors.sh; source lib/ssha_core.sh; ssha::remove_host_block '${cfg}' 'planethoster'"
  [ "$status" -eq 0 ]

  run grep -n "Host planethoster" "${cfg}"
  [ "$status" -ne 0 ]
  run grep -n "Host a" "${cfg}"
  [ "$status" -eq 0 ]
  run grep -n "Host b" "${cfg}"
  [ "$status" -eq 0 ]
}

@test "ssh_userhost_for_provider forces git user for github" {
  run bash -c 'source lib/ssha_colors.sh; source lib/ssha_core.sh; ssha::ssh_userhost_for_provider "loic" "github.com"'
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com" ]
}
