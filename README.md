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
| `g?`                  | Show help for supported mappings                     |

## Roadmap

- [x] Display log in window
- [x] Make J / Jj a simple wrapper for jj CLI
- [x] Add help header and help key binding
- [x] Add keybinding to edit commits
- [x] Describe commits
- [ ] Basic feature:Display changed files in log commit view
- [ ] Basic feature: Display file changes as diff inside the log window
- [ ] Add more convenience keybindings to perform jj operations
- [ ] Basic feature: Make `Jj describe` open the commit editor
- [ ] New feature: Operations log support
- [ ] Feature: Completion for Jj command
- [ ] New feature: Worktree support
- [ ] Configuration: Make mappings configurable

## References

Other jujutsu related plugins:

- https://github.com/yannvanhalewyn/jujutsu.nvim
- https://github.com/sivansh11/jj
- https://github.com/NicolasGB/jj.nvim
