local M = {}

local internal = require("jiejie.internal")

-- Each repository can have its own log buffer - one repository
-- Key: Absolute path to the repository
-- Value:
--   @param {string} bufnr
local repositories = {
  --- @class Context
  --- @field root string repository root
  --- @field buf number log buffer id
  --- @field curpos table cursor position on current commit
}

--- Returns jj's root directory
--- @param directory? string Dirtory to start look at. If not present, start looking in the directory of the currently
--- open file
--- @return string
function M.getRoot(directory)
  return internal.getRoot(directory)
end

--- Get repository configuration
--- @param root? string Root directory of repository
--- @return Context
function M.config(root)
  return {
    root = M.getRoot(root),
    buf = nil,
    curpos = nil,
  }
end

--- Open or focus log window
--- @param root? string Root directory of repository
--- @param vertical? boolean If a new window needs to be created, split it vertically?
--- @return Context
function M.log(root, vertical)
  local config = M.config(root)
  repositories[config.root] = repositories[config.root] or config
  internal.logFocus(repositories[config.root], vertical or false)
  return repositories[config.root]
end

--- Command executes jj commands, returns exit code
--- @param root? string Root directory of repository
--- @param fargs table List of CLI arguments
--- @return number
function M.cli(root, fargs)
  local config = M.config(root)
  repositories[config.root] = repositories[config.root] or config
  local command = vim.fn.extend({ "jj" }, fargs)
  local res = vim
    .system(command, {
      text = true,
      cwd = repositories[config.root].root,
      -- stdout = print,
      -- stdout = print,
    })
    :wait()
  -- TODO: is there a better way to diplay joined stderr/stdout output? E.g. by spawing a shell? - actually, pass in
  -- the same receiver function for stderr and stdout
  print(res.stdout)
  print(res.stderr)
  if res.code ~= 0 then
    error("Command failed with non-zero exit code: " .. res.code)
  end
  return res.code
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
      M.cli(nil, args.fargs)
    end
  end
  local cmdOpts = { desc = "Jujutsu command wrapper - shows log when no argument is provided", nargs = "*" }
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
      local url = internal.parseUrl(ev.file)
      repositories[url.root] = internal.logLoad({ root = url.root, buf = ev.buf, curpos = nil })
      internal.logBufferConfigure(repositories[url.root])
    end,
  })
end

return M
