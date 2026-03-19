#!/usr/bin/env bats

load './test_helper.bash'

@test "normalize_keyname produit alias_user en minuscules" {
  run ssha::normalize_keyname "GitHub-LDDVLP" "Git"
  [ "$status" -eq 0 ]
  [ "$output" = "github_lddvlp_git" ]
}

@test "normalize_keyname remplace les caractères spéciaux par underscore" {
  run ssha::normalize_keyname "PlanetHoster-ldbug.com" "dwmkyvke"
  [ "$status" -eq 0 ]
  [ "$output" = "planethoster_ldbug_com_dwmkyvke" ]
}

@test "key_paths retourne private key et public key" {
  run ssha::key_paths "github_lddvlp_git"
  [ "$status" -eq 0 ]
  [ "$output" = "$SSHA_SSH_DIR/github_lddvlp_git"$'\n'"$SSHA_SSH_DIR/github_lddvlp_git.pub" ]
}

@test "config_path retourne le chemin du config ssh" {
  run ssha::config_path
  [ "$status" -eq 0 ]
  [ "$output" = "$SSHA_SSH_DIR/config" ]
}

@test "is_git_provider_host detecte github.com" {
  run ssha::is_git_provider_host "github.com"
  [ "$status" -eq 0 ]
}

@test "is_git_provider_host detecte gitlab.com" {
  run ssha::is_git_provider_host "gitlab.com"
  [ "$status" -eq 0 ]
}

@test "is_git_provider_host detecte bitbucket.org" {
  run ssha::is_git_provider_host "bitbucket.org"
  [ "$status" -eq 0 ]
}

@test "is_git_provider_host refuse un host classique" {
  run ssha::is_git_provider_host "node266-eu.n0c.com"
  [ "$status" -ne 0 ]
}

@test "ssh_userhost_for_provider force git@github.com" {
  run ssha::ssh_userhost_for_provider "loic" "github.com"
  [ "$status" -eq 0 ]
  [ "$output" = "git@github.com" ]
}

@test "ssh_userhost_for_provider garde user@host pour un serveur classique" {
  run ssha::ssh_userhost_for_provider "dwmkyvke" "node266-eu.n0c.com"
  [ "$status" -eq 0 ]
  [ "$output" = "dwmkyvke@node266-eu.n0c.com" ]
}