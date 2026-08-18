#!/usr/bin/env bash
# Runs the whole suite:
#   test/run.sh          everything
#   test/run.sh unit     only the tests that need no terminal
#   test/run.sh pty      only the ones driving Vim through a pseudo terminal
set -u

cd "$(dirname "$0")/.."
VIM="${VIM_BIN:-vim}"
what="${1:-all}"
failed=0

if [ "$what" = all ] || [ "$what" = unit ]; then
  for t in test/unit/*.vim; do
    # -es keeps Vim silent and headless; the test file ends in qall! or cquit
    if ! "$VIM" -es -u NONE -N -S "$t"; then
      failed=$((failed + 1))
    fi
  done
fi

if [ "$what" = all ] || [ "$what" = pty ]; then
  for t in test/pty/*.sh; do
    case "$t" in */lib.sh) continue ;; esac
    if ! bash "$t"; then
      failed=$((failed + 1))
    fi
  done
fi

if [ "$failed" -eq 0 ]; then
  printf '\nall suites passed\n'
  exit 0
fi
printf '\n%d suite(s) failed\n' "$failed"
exit 1
