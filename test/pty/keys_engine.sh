#!/usr/bin/env bash
# The keys engine judges the resulting text, not the sequence you typed.
. "$(dirname "$0")/lib.sh"

printf 'keys engine\n'

run_drill delete-word 'dw'
assert_ret 1 'the reference answer is accepted'
assert_msg 'Correct: dw (2 keys)' 'and reported with its length'

run_drill delete-word 'dW'
assert_ret 1 'dW reaches the same text and counts'

run_drill delete-word '4x'
assert_ret 1 '4x reaches the same text and counts'

run_drill delete-word 'de'
assert_ret 1 'de is a second reference answer with its own result'

run_drill delete-word 'daw'
assert_ret 1 'a longer answer still counts'
assert_msg 'par 2' 'but the shorter way is shown'

run_drill delete-word 'zzzzzzzz'
assert_ret 0 'grinding it out is refused'
assert_msg 'Out of keys' 'and says why'

run_drill delete-word "$(printf '\033')"
assert_ret 0 'Esc skips'
assert_msg 'Skipped' 'and says so'

run_drill delete-to-eol 'd$'
assert_ret 1 'd$ solves the end-of-line drill'
assert_msg 'par 1' 'D is offered as the shorter one'

run_drill join-lines 'J'
assert_ret 1 'J joins the lines'
assert_msg '1 key' 'a single keystroke is not "1 keys"'

# <F1> asks for the hint and must not be charged as a keystroke
run_drill find-char "$(printf '\033OPfx')"
assert_ret 1 'a drill is still solvable after asking for a hint'
assert_screen 'hint: f{char}' 'the hint is shown on <F1>'
assert_msg 'Correct: fx (2 keys)' '<F1> costs no keystrokes'

finish 'keys engine'
