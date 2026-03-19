#!/usr/bin/env bats

@test "prompt formats default prompt with bracketed default" {
  run grep -F "printf '%s [' \"\${label}\"" lib/ssha_core.sh
  [ "$status" -eq 0 ]
}

@test "main menu uses prompt_required_choice for Choix" {
  run grep -F 'choice="$(ssha::prompt_required_choice "Choix")"' lib/ssha_core.sh
  [ "$status" -eq 0 ]
}
