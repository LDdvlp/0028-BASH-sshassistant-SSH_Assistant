#!/usr/bin/env bats

load './test_helper.bash'

@test "ssh_config_resolve lit les infos depuis ssh -G mocké" {
  cat > "$MOCK_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-G" ]]; then
  cat <<OUT
user git
hostname github.com
port 22
identityfile /tmp/fakekey
OUT
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/ssh"

  run ssha::ssh_config_resolve "github-lddvlp"
  [ "$status" -eq 0 ]
  [ "$output" = "git|github.com|22|/tmp/fakekey" ]
}

@test "ssh_test_safe_config retourne OK si ssh -G mocké réussit" {
  cat > "$MOCK_BIN/ssh" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-G" ]]; then
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/ssh"

  run ssha::ssh_test_safe_config "github-lddvlp"
  [ "$status" -eq 0 ]
}

@test "ssh_output_indicates_success reconnait le message GitHub" {
  run ssha::ssh_output_indicates_success "Hi loic! You've successfully authenticated, but GitHub does not provide shell access."
  [ "$status" -eq 0 ]
}

@test "ssh_output_indicates_success reconnait le message GitLab" {
  run ssha::ssh_output_indicates_success "Welcome to GitLab, @loic!"
  [ "$status" -eq 0 ]
}

@test "ssh_output_indicates_success reconnait le message Bitbucket" {
  run ssha::ssh_output_indicates_success "logged in as loicdrouet"
  [ "$status" -eq 0 ]
}

@test "ssh_host_has_key retourne vrai si identityfile existe" {
  touch "$BATS_TEST_TMPDIR/fakekey"

  cat > "$MOCK_BIN/ssh" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "-G" ]]; then
  cat <<OUT
user git
hostname github.com
port 22
identityfile $BATS_TEST_TMPDIR/fakekey
OUT
  exit 0
fi
exit 1
EOF
  chmod +x "$MOCK_BIN/ssh"

  run ssha::ssh_host_has_key "github-lddvlp"
  [ "$status" -eq 0 ]
}