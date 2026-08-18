" Shared setup for the unit suites.  Every test file sources this first, gets
" the plugin loaded with a throwaway progress file, and ends with Finish().
set encoding=utf-8
set nocompatible
let g:test_root = expand('<sfile>:p:h:h')
execute 'set runtimepath^=' . fnameescape(g:test_root)

" never touch the real progress of whoever runs the suite
let g:trainer_state = tempname()
let g:trainer_drills = g:test_root . '/data/drills.json'
runtime plugin/trainer.vim

" write a catalog for a single test and make the plugin read it
function! UseDrills(list) abort
  let g:trainer_drills = tempname()
  call writefile([json_encode(a:list)], g:trainer_drills)
  silent! call trainer#reload()
endfunction

function! UseState() abort
  let g:trainer_state = tempname()
  silent! call trainer#reset(1)
endfunction

function! ReadState() abort
  return filereadable(g:trainer_state)
        \ ? json_decode(join(readfile(g:trainer_state), "\n"))
        \ : {}
endfunction

" solve the goal drill in the current buffer the way its author intended
function! SolveGoal() abort
  call setline(1, split(b:goal, "\n"))
  doautocmd TextChanged
  sleep 150m
endfunction

function! CloseDrill() abort
  call feedkeys('q', 'xt')
  sleep 150m
endfunction

" engines block on getcharstr() or on autocommands; when a test only cares
" about which drill was picked, replace them with recorders
function! StubEngines() abort
  let g:started = []
  function! trainer#challenge(desc, start, targets, ...) abort
    call add(g:started, a:desc)
    return 1
  endfunction
  function! trainer#goal(desc, start, goal, hint) abort
    call add(g:started, a:desc)
    return 1
  endfunction
endfunction

" :echo is swallowed in silent ex mode, so results go straight to stderr
function! Say(line) abort
  call writefile([a:line], '/dev/stderr')
endfunction

function! Finish(name) abort
  if empty(v:errors)
    call Say('ok    ' . a:name)
    qall!
  endif
  call Say('FAIL  ' . a:name)
  for l:e in v:errors
    call Say('      ' . substitute(l:e, '^.\{-}line \d\+: ', '', ''))
  endfor
  cquit
endfunction
