local M = {}

local jujutsu = require("jiejie.jujutsu")

--- Get repository configuration
--- @param root? string Root directory of repository
--- @return Context
function M.getContext(root)
  return {
    root = jujutsu.getRoot(root),
    buf = nil,
    curpos = nil,
  }
end

return M
