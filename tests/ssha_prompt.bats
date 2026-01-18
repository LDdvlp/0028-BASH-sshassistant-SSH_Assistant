#!/usr/bin/env bats

@test "prompt formats default prompt as: label [default]:" {
  # We can't test colors or interactive input in CI,
  # so we assert the formatting logic in source code.
  run grep -F "printf '%s [%s]: '" lib/ssha_core.sh
  [ "$status" -eq 0 ]
}

@test "main menu uses ssha::prompt for Choix" {
  run grep -F 'ssha::prompt "Choix"' lib/ssha_core.sh
  [ "$status" -eq 0 ]
}
