# vim-trainer

Drills for Vim keys, with scoring. A drill opens in a scratch split, you solve
it, the plugin checks the answer and keeps score across sessions.

![Demo](media/demo.gif)

## Two engines

Both judge the text you end up with, never the keys you happened to press —
`dW` and `4x` solve a `dw` drill just as well as `dw`. They differ in how they
watch you:

- **`keys`** — keystrokes are read with `getcharstr()` and the whole sequence is
  replayed on the buffer after every key, so the effect is visible as you type
  and keystrokes can be counted. For commands that stay in Normal mode: `dw`,
  `D`, `J`, `>>`. `<Esc>` skips.
- **`goal`** — you edit the buffer freely and the result is compared once you
  stop. For everything whose keystrokes cannot be captured, because you end up
  in Insert mode or on the command line: `ciw`, `di"`, `:s/…`.

A keys drill also grades economy: `par` is the shortest listed answer, and
solving it the long way still counts but says so.

```
Correct: daw (3 keys, par 2: dw, daw, de)
```

Grinding the answer out one `x` at a time will not work — after `par * 4`
keystrokes the drill gives up and records a miss.

Every drill opens in a split; `q` closes it, and that is also what advances a
session.

## Install

With [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'korotinm/vim-trainer'
```

As a native package:

```bash
git clone <repo> ~/.vim/pack/plugins/start/vim-trainer
vim -u NONE -c 'helptags ~/.vim/pack/plugins/start/vim-trainer/doc' -c q
```

## Usage

| Command | |
|---|---|
| `:Trainer` | random drill |
| `:Trainer delete-word` | one specific drill, by id |
| `:Trainer text-objects` | random drill with that tag |
| `:Trainer weak` | random drill among those you keep missing |
| `:TrainerSession [n] [id\|tag\|weak]` | `n` drills in a row (default 5) with a score |
| `:TrainerHint` | reveal the hint of the current goal drill (`<F1>` inside it) |
| `:TrainerStop` | abandon the session |
| `:TrainerStats` | totals, streak, per-drill table, weakest first |
| `:TrainerResetStats[!]` | erase progress |
| `:TrainerList` | show the catalog |
| `:TrainerReload` | re-read the drills file after editing it |
| `:TrainerCheat` | keymap cheatsheet in a split |

No keys are taken by default. If you want some, hang them on the `<Plug>` names
yourself — note `nmap`, not `nnoremap`:

```vim
nmap <leader>d <Plug>(TrainerRun)
nmap <leader>w <Plug>(TrainerWeak)
nmap <leader>s <Plug>(TrainerSession)
```

Also available: `<Plug>(TrainerStats)`, `<Plug>(TrainerList)`,
`<Plug>(TrainerCheat)`.

```
vim-trainer — 11/14 correct (78%)   streak 2, best 5

id                       solved  attempts   rate   last
delete-in-quotes              1         5    20%   3d ago
change-word                   2         3    66%   today
delete-word                   4         4   100%   today
```

## Adding drills

Drills are data. [`data/drills.json`](data/drills.json) is a list of objects;
adding an exercise never means touching the code.

```json
{
  "id": "uppercase-word",
  "engine": "goal",
  "desc": "Uppercase the word under the cursor",
  "start": "make this loud",
  "goal": "make THIS loud",
  "hint": "gUiw",
  "tags": ["operators", "text-objects"]
}
```

`engine` is `keys` (needs `targets`) or `goal` (needs `goal`, the expected
text; `hint` is optional). `tags` feed `:Trainer {tag}`. A broken entry is
reported and skipped, the rest still load; run `:TrainerReload` to pick up
edits.

`targets` is not a whitelist: each answer is replayed on the starting text when
the drill opens, and anything you type that reaches one of those results counts.
List several only when they lead to genuinely different but equally correct
text — `dw` and `de` differ by a leading space, so both are listed. The shortest
one sets par. A `goal` on a keys drill overrides the derived results.

## Progress

Results are written to `$XDG_STATE_HOME/vim-trainer/progress.json`
(`~/.local/state/…` when that variable is empty) as a drill buffer is closed:

```json
{"drills": {"delete-word": {"attempts": 3, "solved": 2, "last": 1786982867}},
 "streak": 2, "best": 5, "total_ok": 11, "total_try": 14}
```

A correct answer extends the streak, a wrong one resets it, and a skip counts
for nothing at all — pressing `<Esc>` should not spoil your statistics.

## Configuration

```vim
let g:trainer_drills     = expand('~/dotfiles/my-drills.json')
let g:trainer_cheatsheet = expand('~/dotfiles/vim-keys.md')
let g:trainer_state      = expand('~/dotfiles/vim-trainer.json')
```

Set them in your vimrc, before the plugin loads. `:help vim-trainer` documents
the rest, including the autoload API.

## Requirements

Vim 8.2+ with `+timers` and `json_decode()`; the keys engine needs
`getcharstr()`. Neovim is untested.
