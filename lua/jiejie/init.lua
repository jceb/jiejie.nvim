local M = {}

local buffer = require("jiejie.buffer")
local jujutsu = require("jiejie.jujutsu")
local internal = require("jiejie.internal")

-- Each repository can have its own log buffer - one repository
-- Key: Absolute path to the repository
-- Value:
--   @param {string} bufnr
local repositories = {
  --- @class Context
  --- @field root string repository root
  --- @field buf? number log buffer id
  --- @field curpos? table cursor position on current commit
}

--- Returns jj's root directory
--- @param directory? string Dirtory to start look at. If not present, start looking in the directory of the currently
--- open file
--- @return string
function M.getRoot(directory)
  return jujutsu.getRoot(directory)
end

--- Open or focus log window
--- @param root? string Root directory of repository
--- @param vertical? boolean If a new window needs to be created, split it vertically?
--- @return Context
function M.log(root, vertical)
  local ctx = internal.getContext(root)
  repositories[ctx.root] = repositories[ctx.root] or ctx
  buffer.logFocus(repositories[ctx.root], vertical or false)
  return repositories[ctx.root]
end

--- Command executes jj commands, returns exit code
--- @param fargs string[] List of CLI arguments
--- @param error_on_failure? boolean Throws an error if command fails, default false
--- @param root? string Root directory of repository, determined automatically by the current buffer if not provided
--- @return table
function M.cli(fargs, error_on_failure, root)
  local ctx = internal.getContext(root)
  repositories[ctx.root] = repositories[ctx.root] or ctx
  local command = vim.fn.extend({ "jj" }, fargs)
  local res = vim
    .system(command, {
      text = true,
      cwd = repositories[ctx.root].root,
      -- stdout = print,
      -- stdout = print,
    })
    :wait()
  -- TODO: is there a better way to diplay joined stderr/stdout output? E.g. by spawing a shell? - actually, pass in
  -- the same receiver function for stderr and stdout
  if res.stdout ~= "" then
    vim.notify(res.stdout, vim.log.levels.INFO)
  end
  if res.code ~= 0 then
    vim.notify(res.stderr, vim.log.levels.ERROR)
    if error_on_failure then
      error("Command failed with non-zero exit code: " .. res.code)
    end
  end
  return res
end

--- @class jiejie.Config
--- @field x? string some configuration

--- Setup the plugin
--- @param opts jiejie.Config: Options to configure the plugin
function M.setup(opts)
  local cmd = function(args)
    if vim.fn.len(args.fargs) == 0 then
      M.log(nil, args.smods.vertical)
    else
      M.cli(args.fargs)
    end
  end
  local cmdOpts = { desc = "Jujutsu command wrapper - shows log when no argument is provided", nargs = "*", range = 2 }
  if vim.fn.exists(":J") ~= 2 then
    vim.api.nvim_create_user_command("J", cmd, cmdOpts)
  end
  vim.api.nvim_create_user_command("Jj", cmd, cmdOpts)
  local id = vim.api.nvim_create_augroup("Jiejie", {})
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "jiejie://*",
    group = id,
    callback = function(ev)
      -- Loader function for files of type jiejie
      vim.cmd.doau("BufReadPre")
      local url = buffer.parseUrl(ev.file)
      repositories[url.root] = buffer.logLoad({ root = url.root, buf = ev.buf, curpos = nil })
      buffer.logBufferConfigure(repositories[url.root])
      vim.cmd.doau("BufReadPost")
    end,
  })
end

return M
