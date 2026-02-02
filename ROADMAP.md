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
- [x] Commands: duplicate
- [x] Key: display full summary of a change via K
- [x] Log: support toggling between different log views
- [x] New Feature: Automatically detect changes in files/buffers and reload logs
- [x] Commands: diff

## Priority 1

- [ ] Commands: merge / new with multiple ancestors
- [ ] Fix: restore and squash currently don't work for commits with multiple
      ancestors
- [ ] API: extract commands from buffer.lua and put them in commands.lua
- [ ] Bug: issues with empty bookmark lists, e.g. tags
- [ ] Bug: when an empty file is added and the diff `=` is requested, an error
      occurs
- [ ] Bug: make log reload upon `!` commands
- [ ] Bug: various cursor outside of buffer issues
- [ ] Bug: diff breaks ftdetect

## Priority 2

- [ ] Navigation: implement `(, ), [c, ]c and [m, ]m`
- [ ] Navigation: navigation should open folds
- [ ] Key: Adjust all bindings to vim.ui.select from the currently visible
      change IDs or enter a custom ID, where needed
- [ ] Docs: Describe mindset for approaching jiejie and its key bindings; key
      bindings should mainly deal with the @ change
- [ ] Commands: add keybindings for rebasing a tree or an individual commit
- [ ] Commands: add support for rebase on a bookmark
- [ ] Commands: use count to select operation log view, e.g. 3gv instead of g3
- [ ] Commands: absorb
- [ ] Commands: parallelize
- [ ] Commands: evolog
- [ ] Commands: track / untrack
- [ ] Commands: make command keybingings follow jj's aliases; also use uppercase
      keys for deletion or operations on arbitrary change IDs
- [ ] Commands: `yy`, `yc` and `yC` for copying the commit description / current
      file name, change ID or commit ID
- [ ] New feature: operations log support
- [ ] Commands: cherry-pick - that is jujutsu's equivalent?
- [ ] Refactor: make jiejie URLs truly unique so that the index and file paths
      can be distinguished

## Priority 3

- [ ] Key: pressing `X` on a hunk should restore it - not natively supported by
      jj
- [ ] Commands: keep diff expansion when reloading the log
- [ ] Commands: add verbose mode for displaying the executed `jj` commands
- [ ] Commands: Jedit for commits and directories
- [ ] Commands: split (current workaround: commit one file instead of the whole
      change, then squash the other files that should be part of the commit)
- [ ] Docs: make video that show how to use jiejie - which-key for help with key
      bindings
- [ ] Refactor: follow lua's style of returning errors
- [ ] Commands: blame
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] New Feature: completion for Jj command
- [ ] Statusline: provide status line integration
- [ ] Commands: work tree / workspace - not sure what to support here
- [ ] Commands: :Jclog/:Jllog for loading the commit history into the
      quickfix/location list
- [ ] Commands: :Jgrep for loading the commit history into the quickfix list
- [ ] Commands: :Jcd / Jlcd change directory relative to the repository :cd /
      :lcd
- [ ] Commands: :JBrowse to open file in browser
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Configuration: make mappings configurable
