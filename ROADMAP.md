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

## Priority 1

- [ ] Commands: diff
- [ ] Commands: merge / new with multiple ancestors
- [ ] Fix: restore and squash currently don't work for commits with multiple
      ancestors
- [ ] API: extract commands from buffer.lua and put them in commands.lua

## Priority 2

- [ ] Commands: keep diff expansion when reloading the log
- [ ] Key: Adjust all bindings to vim.ui.select from the currently visible
      change IDs or enter a custom ID, where needed
- [ ] Key: pressing `X` on a hunk should restore it
- [ ] Navigation: implement `(, ), [c, ]c and [m, ]m`

## Priority 3

- [ ] Commands: Jedit for commits and directories
- [ ] Commands: split (current workaround: commit one file instead of the whole
      change, then squash the other files that should be part of the commit)
- [ ] Docs: make screen recordings of jiejie's usage
- [ ] Refactor: follow lua's style of returning errors
- [ ] Commands: blame
- [ ] Commands: absorb
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: parallelize
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] Commands: evolog
- [ ] New feature: operations log support
- [ ] New Feature: completion for Jj command
- [ ] Statusline: provide status line integration
- [ ] Commands: work tree / workspace - not sure what to support here
- [ ] Commands: :Jclog/:Jllog for loading the commit history into the
      quickfix/location list
- [ ] Commands: :Jgrep for loading the commit history into the quickfix list
- [ ] Commands: :Jcd / Jlcd change directory relative to the repository :cd /
      :lcd
- [ ] Commands: :JBrowse open file in browser
- [ ] Commands: support visual mode for squash, commit, split and restore key
      bindings
- [ ] Configuration: make mappings configurable
