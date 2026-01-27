# jiejie

Neovim plugin that adds support for the Jujutsu source control management
system. The design is heavily inspired by
[fugitive.vim](https://github.com/tpope/vim-fugitive).

## Installation

With Lazy, add this configuration to nvim:

```lua
return {
  -- https://github.com/jceb/jiejie.nvim.git
  "jceb/jiejie.nvim",
  config = function()
    require("jiejie").setup({})
  end,
}
```

## Usage

| Command / Key binding | Description                                          |
| --------------------- | ---------------------------------------------------- |
| `:J` or `:Jj`         | Open or focus log window, when no argument is passed |
| `:Jj <command>`       | Execute `jj <command>`                               |
| `:Jedit [object]`     | :edit a jiejie-object                                |
| `g?`                  | Show help for supported mappings                     |

## Roadmap

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

Priority 1

- [ ] Commands: squash and commit for individual files
- [ ] Commands: tag
- [ ] Commands: keep diff expansion when reloading the log
- [ ] Commands: split
- [ ] Commands: bookmark
- [ ] New Feature: Detect all files/buffers in a jj repository and trigger log
      reloads when they change
- [ ] Navigation: movement mappings for commits, files and hunks

Priority 2

- [ ] Commands: worktree
- [ ] Commands: rebase
- [ ] Commands: diff
- [ ] Configuration: Make mappings configurable

Priority 3

- [ ] Commands: absorb
- [ ] Commands: duplicate
- [ ] Commands: diffedit
- [ ] Commands: show full change
- [ ] Commands: undo / redo
- [ ] Commands: parallelize
- [ ] Commands: metaedit
- [ ] Commands: interdiff
- [ ] Commands: evolog
- [ ] New feature: Operations log support
- [ ] New Feature: Completion for Jj command

## References

Other jujutsu related plugins:

- [https://github.com/NicolasGB/jj.nvim](https://github.com/NicolasGB/jj.nvim)
- [https://github.com/sivansh11/jj](https://github.com/sivansh11/jj)
- [https://github.com/yannvanhalewyn/jujutsu.nvim](https://github.com/yannvanhalewyn/jujutsu.nvim)
