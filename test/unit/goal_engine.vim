source <sfile>:p:h:h/helper.vim

function! Live(buf) abort
  return exists('#TrainerGoal_' . a:buf . '#TextChanged')
endfunction

call UseState()

" a drill opens in a split of its own and leaves a modified buffer alone
set nohidden
enew
call setline(1, 'dirty unsaved buffer')
let s:dirty = bufnr('%')
let s:err = ''
try
  Trainer change-word
catch
  let s:err = v:exception
endtry
call assert_equal('', s:err, 'no E37 over a modified buffer')
call assert_notequal(s:dirty, bufnr('%'), 'the drill got its own buffer')
call assert_true(bufexists(s:dirty), 'the modified buffer is still there')
let s:g1 = bufnr('%')

" two drills at once: one augroup each, so they do not cancel one another
Trainer delete-in-quotes
let s:g2 = bufnr('%')
call assert_true(Live(s:g1) && Live(s:g2), 'both drills are armed')
call SolveGoal()
call assert_true(Live(s:g1), 'solving one leaves the other armed')
call assert_false(Live(s:g2), 'the solved one is disarmed')
call assert_equal('✓ CORRECT — say "" now', getbufline(s:g2, 1)[0], 'the solved drill is marked')
call assert_false(exists('#TrainerGoal_' . s:g2), 'its augroup is gone')
call assert_equal(0, getbufvar(s:g2, '&modifiable'), 'the solved buffer is locked')

" q closes a locked drill and brings us back
let s:before = winnr('$')
call CloseDrill()
call assert_false(bufexists(s:g2), 'q wiped the drill buffer')
call assert_equal(s:before - 1, winnr('$'), 'and closed its window')

" solving, then walking away before the announce timer fires
call win_gotoid(bufwinid(s:g1))
call setline(1, 'the red fox')
doautocmd TextChanged
enew!
call setline(1, 'INNOCENT LINE')
let s:victim = bufnr('%')
sleep 200m
call assert_equal('INNOCENT LINE', getline(1), 'the timer wrote into the drill, not into this buffer')
call assert_false(exists('#TrainerGoal_' . s:g1), 'the augroup is cleaned up')

" closing an unsolved drill cleans up after itself
Trainer change-word
let s:g3 = bufnr('%')
execute 'bwipeout! ' . s:g3
sleep 100m
call assert_false(exists('#TrainerGoal_' . s:g3), 'no augroup left behind')

" hints stay hidden until asked for
Trainer change-word
call assert_equal('ciw', b:trainer_hint, 'the hint is kept out of the prompt')
call assert_equal(':TrainerHint<CR>', maparg('<F1>', 'n', 0, 1).rhs, '<F1> is mapped in the drill')
redir => s:out | silent TrainerHint | redir END
call assert_equal('hint: ciw', trim(s:out), 'the hint is revealed on request')
call CloseDrill()

redir => s:out | silent TrainerHint | redir END
call assert_equal('No hint for this drill', trim(s:out), 'outside a drill the command is harmless')

" a session runs the requested number of drills and stops on its own
call UseState()
let s:base = winnr('$')
TrainerSession 3 text-objects
let s:seen = 0
for s:i in range(3)
  let s:seen += empty(getline(1)) ? 0 : 1
  call SolveGoal()
  call CloseDrill()
endfor
call assert_equal(3, s:seen, 'three drills ran')
call assert_equal(3, ReadState().total_ok, 'all three were scored')
call assert_equal(s:base, winnr('$'), 'the session left no windows open')

call Finish('goal_engine')
