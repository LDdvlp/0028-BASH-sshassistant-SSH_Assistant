#!/usr/bin/env bats

load './test_helper.bash'

@test "append_host_block ajoute un bloc Host dans config" {
  cfg="$SSHA_SSH_DIR/config"

  ssha::append_host_block "$cfg" "github-lddvlp" "github.com" "git" "22" "$SSHA_SSH_DIR/github_lddvlp_git"

  run grep -F "Host github-lddvlp" "$cfg"
  [ "$status" -eq 0 ]

  run grep -F "HostName github.com" "$cfg"
  [ "$status" -eq 0 ]

  run grep -F "User git" "$cfg"
  [ "$status" -eq 0 ]
}

@test "remove_host_block supprime le bloc Host demandé" {
  cfg="$SSHA_SSH_DIR/config"

  ssha::append_host_block "$cfg" "github-lddvlp" "github.com" "git" "22" "$SSHA_SSH_DIR/github_lddvlp_git"
  ssha::append_host_block "$cfg" "gitlab-lddvlp" "gitlab.com" "git" "22" "$SSHA_SSH_DIR/gitlab_lddvlp_git"

  ssha::remove_host_block "$cfg" "github-lddvlp"

  run grep -F "Host github-lddvlp" "$cfg"
  [ "$status" -ne 0 ]

  run grep -F "Host gitlab-lddvlp" "$cfg"
  [ "$status" -eq 0 ]
}

@test "ssh_config_list_hosts retourne les alias du config" {
  cfg="$SSHA_SSH_DIR/config"

  ssha::append_host_block "$cfg" "github-lddvlp" "github.com" "git" "22" "$SSHA_SSH_DIR/github_lddvlp_git"
  ssha::append_host_block "$cfg" "gitlab-lddvlp" "gitlab.com" "git" "22" "$SSHA_SSH_DIR/gitlab_lddvlp_git"

  run ssha::ssh_config_list_hosts
  [ "$status" -eq 0 ]
  [[ "$output" == *"github-lddvlp"* ]]
  [[ "$output" == *"gitlab-lddvlp"* ]]
}