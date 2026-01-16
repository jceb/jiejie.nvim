local jujutsu = require("jiejie.jujutsu")

local M = {}

-- Each repository can have its own log buffer - one repository
-- Key: Absolute path to the repository
-- Value:
--   @param {string} bufnr
local contexts = {
  --- @class Context
  --- @field root string repository root
  --- @field buf? number log buffer id
  --- @field curpos? table cursor position on current commit
}

--- Get an existing repository context, or create a empty one one
--- @param root string Root directory of repository
--- @return Context
function M.get_context(root)
  if root and contexts[root] then
    return contexts[root]
  end
  local root_updated = jujutsu.get_root(root)
  contexts[root_updated] = {
    root = root_updated,
    buf = nil,
    curpos = nil,
  }
  return contexts[root_updated]
end

--- Get an existing repository context, or create a empty one one
--- @param ctx Context Context do update
--- @return Context
function M.set_context(ctx)
  contexts[ctx.root] = ctx
  return ctx
end

--- Configure context for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.b.jiejie_root = ctx.root
  return ctx
end

return M
