if exists('g:loaded_trainer') | finish | endif
let g:loaded_trainer = 1

let s:root = expand('<sfile>:p:h:h')

" оба пути переопределяемы: можно подсунуть свой каталог дриллов и свою шпаргалку
if !exists('g:trainer_cheatsheet')
  let g:trainer_cheatsheet = s:root . '/data/cheatsheet_en.md'
endif
if !exists('g:trainer_drills')
  let g:trainer_drills = s:root . '/data/drills.json'
endif

" :Trainer                 — случайный дрилл
" :Trainer delete-word     — конкретный, по id
" :Trainer text-objects    — случайный из тега
" -bar: без него всё после | утекает в аргумент команды
command! -bar -nargs=? -complete=customlist,trainer#complete Trainer call trainer#run(<q-args>)
command! -bar TrainerList   call trainer#list()
command! -bar TrainerReload call trainer#reload()
command! -bar TrainerCheat  call trainer#cheatsheet()

nnoremap <silent> <leader>tt :Trainer<CR>
nnoremap <silent> <leader>tl :TrainerList<CR>
nnoremap <silent> <leader>th :TrainerCheat<CR>
