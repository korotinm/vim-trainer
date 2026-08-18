#!/usr/bin/env bash
# Helpers for the terminal suites.  The keys engine reads with getcharstr(),
# which needs a real tty, so these drive Vim inside a pseudo terminal and read
# what it painted on the screen.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
FAILED=0
trap 'rm -rf "$TMP"' EXIT

# script(1) takes its arguments the other way round on util-linux than on BSD
pty_run() {  # $1 command, $2 typescript file
  if script --version 2>&1 | grep -qi util-linux; then
    script -qec "$1" "$2" >/dev/null 2>&1
  else
    script -q "$2" /bin/sh -c "$1" >/dev/null 2>&1
  fi
}

# strip the escape sequences so the assertions can look at plain text
screen_text() {
  tr -d '\000' < "$1" | sed $'s/\033\\[[0-9;?]*[a-zA-Z]//g; s/\033[()][A-B0-9]//g; s/\033[>=]//g'
}

# run one drill, type KEYS into it, leave the outcome in RET, MSG and SCREEN
run_drill() {  # $1 drill id, $2 keys, $3 catalog (optional)
  local id="$1" keys="$2" catalog="${3:-$ROOT/data/drills.json}"
  local script_file="$TMP/drive.vim" result="$TMP/result" log="$TMP/typescript"
  rm -f "$result" "$log"
  cat > "$script_file" <<EOF
set encoding=utf-8
set runtimepath^=$ROOT
let g:trainer_state = '$TMP/state.json'
let g:trainer_drills = '$catalog'
runtime plugin/trainer.vim
" a drill that never matches would sit there waiting for more keys
call timer_start(9000, {-> [writefile(['ret=timeout', 'reg_a=' . getreg('a')], '$result'),
      \ execute('qall!')]})
enew
call setreg('a', 'USER REGISTER')
let g:r = trainer#run('$id')
call writefile(['ret=' . g:r, 'reg_a=' . getreg('a')], '$result')
sleep 300m
qall!
EOF
  { sleep 0.6; printf "%s" "$keys"; sleep 1.6; } |
    TERM=xterm-256color pty_run "vim -u NONE -N -S $script_file" "$log"
  RET="$(sed -n 's/^ret=//p' "$result" 2>/dev/null || echo 'no result')"
  REG_A="$(sed -n 's/^reg_a=//p' "$result" 2>/dev/null || true)"
  SCREEN="$(screen_text "$log")"
  MSG="$(printf '%s' "$SCREEN" | grep -oE '(Correct|Out of keys|Skipped)[^^]*' | tail -1 || true)"
}

ok() {      # $1 description
  printf '  ok    %s\n' "$1"
}

fail() {    # $1 description, $2 detail
  printf '  FAIL  %s\n        %s\n' "$1" "$2"
  FAILED=$((FAILED + 1))
}

assert_ret() {  # $1 expected, $2 description
  if [ "$RET" = "$1" ]; then ok "$2"; else fail "$2" "ret=$RET (expected $1), msg=$MSG"; fi
}

assert_msg() {  # $1 substring, $2 description
  case "$MSG" in
    *"$1"*) ok "$2" ;;
    *)      fail "$2" "message was: $MSG" ;;
  esac
}

assert_screen() {  # $1 substring, $2 description
  case "$SCREEN" in
    *"$1"*) ok "$2" ;;
    *)      fail "$2" "\"$1\" never appeared on screen" ;;
  esac
}

finish() {  # $1 suite name
  if [ "$FAILED" -eq 0 ]; then
    printf 'ok    %s\n' "$1"
    exit 0
  fi
  printf 'FAIL  %s (%d)\n' "$1" "$FAILED"
  exit 1
}
