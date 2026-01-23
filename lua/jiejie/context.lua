local jujutsu = require("jiejie.jujutsu")

local M = {}

-- Each repository can have its own log buffer - one repository
-- Key: Absolute path to the repository
-- Value:
--- @class Context
--- @field root string Repository root
--- @field buf? number Log buffer id
--- @field curpos? table Cursor position on current change
--- @field log_revisions? number Number of log revisions to display

--- Get an existing repository context, or create a empty one one
--- @param root string Root directory of repository
--- @return Context
function M.get_context(root)
  local root_local = root or jujutsu.get_root(root)
  if root_local and vim.g.jiejie_contexts[root_local] then
    return vim.g.jiejie_contexts[root_local]
  end
  -- local root_local = jujutsu.get_root(root_local)
  vim.g.jiejie_contexts = vim.tbl_extend("force", vim.g.jiejie_contexts, { [root_local] = {
    root = root_local,
    buf = nil,
    curpos = nil,
  } })
  return vim.g.jiejie_contexts[root_local]
end

--- Get an existing repository context, or create a empty one one
--- @param ctx Context Context do update
--- @return Context
function M.set_context(ctx)
  vim.g.jiejie_contexts = vim.tbl_extend("force", vim.g.jiejie_contexts, { [ctx.root] = ctx })
  return vim.g.jiejie_contexts[ctx.root]
end

--- Configure context for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.b.jiejie_root = ctx.root
  return ctx
end

--- Configure context
function M.setup()
  vim.g.jiejie_contexts = {}
end

return M
