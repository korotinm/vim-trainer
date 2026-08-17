if exists('g:loaded_trainer') | finish | endif
let g:loaded_trainer = 1

let s:root = expand('<sfile>:p:h:h')

" все три пути переопределяемы: свой каталог дриллов, своя шпаргалка, своё
" место под прогресс
if !exists('g:trainer_cheatsheet')
  let g:trainer_cheatsheet = s:root . '/data/cheatsheet_en.md'
endif
if !exists('g:trainer_drills')
  let g:trainer_drills = s:root . '/data/drills.json'
endif
if !exists('g:trainer_state')
  let s:state_dir = empty($XDG_STATE_HOME) ? expand('~/.local/state') : $XDG_STATE_HOME
  let g:trainer_state = s:state_dir . '/vim-trainer/progress.json'
endif

" :Trainer                 — случайный дрилл
" :Trainer delete-word     — конкретный, по id
" :Trainer text-objects    — случайный из тега
" :Trainer weak            — случайный из тех, что даются хуже всего
" -bar: без него всё после | утекает в аргумент команды
command! -bar -nargs=? -complete=customlist,trainer#complete Trainer
      \ call trainer#run(<q-args>)
" :TrainerSession [n] [id|tag|weak] — n дриллов подряд со счётом, по умолчанию 5
command! -bar -nargs=* -complete=customlist,trainer#complete TrainerSession
      \ call trainer#session(<q-args>)
command! -bar TrainerStop   call trainer#stop()
command! -bar TrainerStats  call trainer#stats()
command! -bar TrainerList   call trainer#list()
command! -bar TrainerReload call trainer#reload()
command! -bar TrainerCheat  call trainer#cheatsheet()
command! -bar -bang TrainerResetStats call trainer#reset(<bang>0)

nnoremap <silent> <leader>tt :Trainer<CR>
nnoremap <silent> <leader>tw :Trainer weak<CR>
nnoremap <silent> <leader>ts :TrainerSession<CR>
nnoremap <silent> <leader>tp :TrainerStats<CR>
nnoremap <silent> <leader>tl :TrainerList<CR>
nnoremap <silent> <leader>th :TrainerCheat<CR>
