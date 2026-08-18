#!/usr/bin/env bash
# Every keys drill in the shipped catalog has to be solvable by its own first
# reference answer.  This catches a target that does not do what its author
# thought — a typo, a character missing from "start", a wrong "check".
. "$(dirname "$0")/lib.sh"

printf 'shipped drills\n'

# let Vim itself read the catalog: no python, no jq
cat > "$TMP/list.vim" <<EOF
let s:d = json_decode(join(readfile('$ROOT/data/drills.json'), "\n"))
call filter(s:d, {_, x -> get(x, 'engine', '') ==# 'keys'})
call writefile(map(s:d, {_, x -> x.id . "\t" . x.targets[0]}), '$TMP/list.txt')
qall!
EOF
vim -es -u NONE -N -S "$TMP/list.vim"

if [ ! -s "$TMP/list.txt" ]; then
  fail 'read the catalog' 'no keys drills found'
  finish 'shipped drills'
fi

while IFS=$'\t' read -r id keys; do
  [ -n "$id" ] || continue
  run_drill "$id" "$keys"
  assert_ret 1 "$id is solved by its own answer ($keys)"
done < "$TMP/list.txt"

finish 'shipped drills'
