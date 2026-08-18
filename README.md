# vim-trainer

Drills for Vim keys, with scoring. A drill opens in a scratch split, you solve
it, the plugin checks the answer and keeps score across sessions.

![Demo](media/demo.gif)

## Two engines

Both judge the state you end up in, never the keys you happened to press —
`dW` and `4x` solve a `dw` drill just as well as `dw`. Usually that state is the
buffer text; a keys drill can watch the cursor, a register, a mark or the folds
instead. They differ in how they watch you:

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
git clone https://github.com/korotinm/vim-trainer ~/.vim/pack/plugins/start/vim-trainer
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
| `:TrainerHint` | reveal the drill's hint (`<F1>` inside it; free in keys drills) |
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

## Adding drills — and sending them back

**This is the easiest thing to contribute, and the most useful.** A drill is a
JSON object, not code: if you keep forgetting a command, add it to
[`data/drills.json`](data/drills.json) and open a merge request. No Vimscript
involved, no build step, nothing to learn beyond the fields below.

The file is a plain list of objects:

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
text). `hint` works in both and is only shown on `<F1>`. `tags` feed
`:Trainer {tag}`. A broken entry is reported and skipped, the rest still load;
run `:TrainerReload` to pick up edits.

By default a drill is judged by the buffer text. `check` changes what is
compared, so drills can cover keys that leave the text alone:

```json
{
  "id": "find-char",
  "engine": "keys",
  "check": "cursor",
  "desc": "Jump to the x of \"fox\"",
  "start": "the quick brown fox jumps",
  "targets": ["fx"],
  "tags": ["motions"]
}
```

`check` is `text` (default), `cursor`, `register`, `mark` or `fold`; the last
two, plus `register`, name the register or mark in `check_arg`. Anything other
than `text` needs `engine: "keys"` — the goal engine watches events and would
fire the moment the cursor merely passed through the right spot. Registers are
global, so a drill wipes the one it uses between attempts and hands it back
untouched afterwards.

`targets` is not a whitelist: each answer is replayed on the starting text when
the drill opens, and anything you type that reaches the same state counts.
List several only when they lead to genuinely different but equally correct
text — `dw` and `de` differ by a leading space, so both are listed. The shortest
one sets par. A `goal` on a keys drill overrides the derived results.

### Tags

Use these tags, one or two per drill. The right-hand column is the `check` a
drill of that kind needs (see below):

| tag | what it covers | check |
|---|---|---|
| `operators` | `d` `c` `y` `>` `=` `gu` `gU` with a motion or a text object | text |
| `text-objects` | `iw` `aw` `i(` `a"` `ip` `it` | text |
| `editing` | single edits: `x` `r` `J` `>>` `~` `.` `u` `Ctrl-r` | text |
| `modes` | `i` `a` `I` `A` `o` `O` `gi` `R` | text |
| `visual` | `v` `V` `Ctrl-v` plus an edit on the selection | text |
| `replace` | `:s///`, `:g`, `&` | text |
| `macros` | `q` `@`, when the macro edits | text |
| `motions` | `w` `b` `e` `f{c}` `t{c}` `{` `}` `gg` `G` | `cursor` |
| `search` | `/` `?` `n` `N` `*` `#` | `cursor` |
| `marks` | `m{a}`, `` `a ``, `'a` | `mark` |
| `registers` | `"ay` `"ap` `:let @a` | `register` |
| `folds` | `zf` `zo` `zc` `za` | `fold` |

Window and buffer switching has no tag on purpose: a drill is replayed from
its starting text after every keystroke, and a key that moves focus would send
the next replay into somebody else's buffer.

The first tag says what kind of move it is, the second narrows the construct:
`ciw` is `operators` + `text-objects`. Add a new tag only once three drills
would carry it; below that it is just a longer name for the `id`.

### Sending a drill upstream

1. Add your object to [`data/drills.json`](data/drills.json), with a unique
   `id` and a `tags` list that matches the existing ones.
2. `:TrainerReload`, then `:Trainer <your-id>` — solve it once, and for a keys
   drill try a second route to the same text to check `targets` is honest.
3. Open a merge request with just that file changed.

Good drills come from your own misses: the command you look up every time, the
text object you never reach for. `:TrainerStats` shows which ones those are.

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
`getcharstr()`.

## License

MIT — see [LICENSE](LICENSE).
