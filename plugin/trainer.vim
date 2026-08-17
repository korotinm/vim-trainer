if exists('g:loaded_trainer') | finish | endif
let g:loaded_trainer = 1

let s:root = expand('<sfile>:p:h:h')
let g:trainer_cheatsheet = s:root . '/data/cheatsheet_en.md'

" движок 1 — дриллы на хоткеи, тексты английские
command! TrainerT1 call trainer#challenge(
  \ 'Delete the word under the cursor',
  \ 'the quick brown fox', ['dw','daw','de'])
command! TrainerT2 call trainer#challenge(
  \ 'Delete from the cursor to end of line',
  \ 'keep this cut the rest', ['D','d$'])
command! TrainerT3 call trainer#challenge(
  \ 'Join this line with the next one',
  \ "line one\nline two", ['J'])
command! TrainerT4 call trainer#challenge(
  \ 'Indent the current line',
  \ 'shift me right', ['>>'])

" движок 2 — дриллы на результат
command! TrainerG1 call trainer#goal(
  \ 'Change "brown" to "red"',
  \ 'the brown fox', 'the red fox', 'ciw')
command! TrainerG2 call trainer#goal(
  \ 'Delete everything inside the quotes',
  \ 'say "hello world" now', 'say "" now', 'di"')

command! TrainerCheat call trainer#cheatsheet()

nnoremap <silent> <leader>t1 :TrainerT1<CR>
nnoremap <silent> <leader>t2 :TrainerT2<CR>
nnoremap <silent> <leader>tg :TrainerG1<CR>
nnoremap <silent> <leader>th :call trainer#cheatsheet()<CR>