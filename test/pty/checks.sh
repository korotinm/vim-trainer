#!/usr/bin/env bash
# A drill can be judged by the cursor, a register, a mark or the folds instead
# of the buffer text.
. "$(dirname "$0")/lib.sh"

printf 'state checks\n'

# cursor
run_drill find-char 'fx'
assert_ret 1 'the reference motion lands on the right spot'
run_drill find-char 'wwwll'
assert_ret 1 'a longer route to the same spot counts'
assert_msg 'par 2' 'and the short one is shown'
run_drill find-char '$'
assert_ret timeout '$ lands elsewhere and is not accepted'

# register, including handing the borrowed one back
run_drill yank-to-register '"ayw'
assert_ret 1 'yanking into the named register counts'
run_drill yank-to-register '"aye'
assert_ret 1 'the second reference answer counts too'
run_drill yank-to-register 'yw'
assert_ret timeout 'the unnamed register does not solve it'

# the drill borrows register a; once it is over the user's own text is back
run_drill yank-to-register '"ayw'
if [ "$REG_A" = 'USER REGISTER' ]; then
  ok 'the register is handed back untouched'
else
  fail 'the register is handed back untouched' "register a holds: $REG_A"
fi

# mark
run_drill mark-third-line '3Gma'
assert_ret 1 'the mark lands on the right line'
run_drill mark-third-line 'jjma'
assert_ret 1 'another route to the same line counts'
run_drill mark-third-line 'ma'
assert_ret timeout 'a mark on the wrong line is not accepted'

# check_arg names a mark here, so the register of the same name is off limits
run_drill mark-third-line '3Gma'
if [ "$REG_A" = 'USER REGISTER' ]; then
  ok 'a mark drill leaves register a alone'
else
  fail 'a mark drill leaves register a alone' "register a holds: $REG_A"
fi

# folds
run_drill fold-two-lines 'zfj'
assert_ret 1 'the fold covers the right lines'
run_drill fold-two-lines 'Vjzf'
assert_ret 1 'folding through Visual mode counts'
run_drill fold-to-end 'zfj'
assert_ret timeout 'a fold of the wrong size is not accepted'
run_drill fold-to-end 'zfG'
assert_ret 1 'folding to the end of the file counts'

finish 'state checks'
