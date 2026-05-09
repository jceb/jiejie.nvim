# Roadmap

- [x] Basic feature: Display log in window
- [x] Basic feature: Make J / Jj a simple wrapper for jj CLI
- [x] Commands: describe
- [x] Commands: edit
- [x] Commands: squash
- [x] Commands: commit
- [x] Commands: new
- [x] Log: Display changed files in log view
- [x] Log: Jump to file from log window
- [x] Commands: abandon / restore
- [x] Commands: revert
- [x] Log: Increase / decrease the number of displayed revisions
- [x] Commands: git push & pull
- [x] Basic feature: Display file changes as diff inside the log window
- [x] Commands: op revert (undo) last operation
- [x] Commands: Jedit
- [x] Configuration: expose all key bindings as <Plug>
- [x] Commands: provide convenience mappings for editing the current file in a
      new split (o) or tab (O)
- [x] Commands: squash and commit for individual files
- [x] Navigation: movement mappings for commits, files and hunks
- [x] Commands: rebase
- [x] Commands: bookmark
- [x] Commands: tag
- [x] Commands: duplicate / cherry-pick
- [x] Key: display full summary of a change via K
- [x] Log: support toggling between different log views
- [x] New Feature: Automatically detect changes in files/buffers and reload logs
- [x] Commands: diff
- [x] Commands: add keybindings for rebasing a tree or an individual commit
- [x] Commands: make command keybingings follow jj's aliases; also use uppercase
      keys for deletion or operations on arbitrary change IDs
- [x] Commands: `yy`, `yc` and `yC` for copying the commit description / current
      file name, change ID or commit ID
- [x] Log: add detached_heads() view
- [x] Fix: restore currently doesn't work for commits with multiple ancestors #2
- [x] Commands: track and untrack
- [x] Fix: squash currently doesn't work for commits with multiple ancestors
- [x] Commands: new with multiple ancestors, `ci`, `ca`
- [x] Commands: merge `cm`
- [x] Log: use count to select operation log view, e.g. 3gv instead of g3
- [x] Log: support dynamic views
- [x] Log: `!!` should work like `.` with a leading `!`
- [x] Move view filters into a custom section in the docs
- [x] Log: Add support for shifting / reordering commits back and forth (rebase)
      `<<`, `>>`,
- [x] Log: add more status filters for authors and descriptions
- [x] Bug: highlight mappings in header differently than other data, e.g.
      operation or view data
- [x] Refactor: make jiejie URLs truly unique so that the index and file paths
      can be distinguished
- [x] New feature: operations log support
- [x] Commands: evolog
- [x] Commands: Add jj advance
- [x] Configuration: make default view configurable
- [x] Configuration: make default dynamic views configurable
- [x] Configuration: the number of log entries configurable
- [x] Commands: jj log [FILE] :JcLog/:JlLog for loading the commit history into
      the quickfix/location list see issue #1

## Priority 1

## Priority 2

- [ ] Commands: add convencience diffput and diffget mappings, d2p, d2o, ... in
      diff mode
- [ ] Bug: make log reload when `!` commands are executed
- [ ] Navigation: implement `(, ), [c, ]c, [], ][ and [m, ]m`
- [ ] Navigation: unify navigation across log types: oplog, evolog and status
      log
- [ ] Log: improve cursor positioning by computing an expected new position,
      e.g. via `search()`
- [ ] Commands: sign, unsign and sign-off commit
- [ ] Evolog: make evolog work like the status log with `=`, file editing, etc.
- [ ] Commands: split via a terminal and the interactive jj UI (current
      workaround: commit one file instead of the whole change, then squash the
      other files that should be part of the commit)
- [ ] Key: pressing `X` on a hunk should restore it - not natively supported by
      jj
- [ ] Support file names without leading pipe sign and with a `~` sign:

```
@  oy	†‡commit message⌠⌡∫∬∮∴xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx∵ user@example.com∶∷bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb∼ current working copy∾1
│  M file1.txt
~  M file2.txt
   M file3.txt
```

## Priority 3

- [ ] Log: Add `cT` mapping to create a merge commit with a tag
- [ ] Log: display conflict status of files (`log --types` .. however this is
      currently incompatible with `--summary`)
- [ ] Log: display signature status
- [ ] Commands: command for making a pull request, see
      <https://github.com/NicolasGB/jj.nvim#open-a-prmr-from-the-log-buffer>
- [ ] Commands: fix
- [ ] Commands: simplify-parents
- [ ] Commands: sparse
- [ ] Commands: granular squash via a terminal and the interactive jj UI
- [ ] Feature: add support for handling PRs
- [ ] Statusline: provide status line integration, e.g. file name, diff id,
      change id
- [ ] Commands: blame / file annotate
- [ ] Refactor: remove notification from api.lua into log_buffer_mappings
- [ ] Commands: absorb
- [ ] Commands: parallelize
- [ ] Docs: make video that show how to use jiejie - which-key for help with key
      bindings
- [ ] Feature: add support for hiding certain branches from the log view, e.g.
      renovate/
- [ ] Commands: prev and next `<p`, `>n`
- [ ] Log: navigation should open folds
- [ ] Commands: something like `Jj toggle` to toggle the visibility of the log
      status window
- [ ] Commands: support pushing / pulling from different origins
- [ ] Show conflicts in file names, see https://github.com/jj-vcs/jj/issues/1111
- [ ] Commands: keep open diffs open when reloading the log
- [ ] Commands: add verbose mode for displaying the executed `jj` commands
- [ ] Commands: Jedit directories
- [ ] Refactor: follow lua's style of returning errors
- [ ] Commands: interdiff
- [ ] New Feature: completion for Jj command
- [ ] Commands: work tree / workspace - not sure what to support here
- [ ] Commands: :Jgrep for loading the commit history into the quickfix list
- [ ] Commands: :Jcd / Jlcd change directory relative to the repository :cd /
      :lcd
- [ ] Commands: :JBrowse to open file in browser see
      <https://github.com/NicolasGB/jj.nvim#browse-current-file-on-remote>
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Configuration: make mappings configurable
