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

## Priority 1

- [ ] Log: use count to select operation log view, e.g. 3gv instead of g3
- [ ] Navigation: implement `(, ), [c, ]c and [m, ]m`
- [ ] Bug: when an empty file is added and the diff `=` is requested, an error
      occurs

## Priority 2

- [ ] Commands: blame / file annotate
- [ ] Bug: make log reload upon `!` commands
- [ ] Log: navigation should open folds
- [ ] Commands: evolog
- [ ] Commands: jj log [FILE] :Jclog/:Jllog for loading the commit history into
      the quickfix/location list see issue #1
- [ ] New feature: operations log support
- [ ] Refactor: make jiejie URLs truly unique so that the index and file paths
      can be distinguished
- [ ] Commands: absorb
- [ ] Commands: parallelize

## Priority 3

- [ ] Docs: make video that show how to use jiejie - which-key for help with key
      bindings
- [ ] Key: Adjust all bindings to vim.ui.select from the currently visible
      change IDs or enter a custom ID, where needed
- [ ] Key: pressing `X` on a hunk should restore it - not natively supported by
      jj
- [ ] Commands: keep open diffs open when reloading the log
- [ ] Commands: add verbose mode for displaying the executed `jj` commands
- [ ] Commands: Jedit for commits and directories
- [ ] Commands: split (current workaround: commit one file instead of the whole
      change, then squash the other files that should be part of the commit)
- [ ] Refactor: follow lua's style of returning errors
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] New Feature: completion for Jj command
- [ ] Statusline: provide status line integration
- [ ] Commands: work tree / workspace - not sure what to support here
- [ ] Commands: :Jgrep for loading the commit history into the quickfix list
- [ ] Commands: :Jcd / Jlcd change directory relative to the repository :cd /
      :lcd
- [ ] Commands: :JBrowse to open file in browser
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Configuration: make mappings configurable
