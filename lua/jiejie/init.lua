local M = {}

--- @class jiejie.Config

--- Setup the plugin
--- @param opts jiejie.Config: Options to configure the plugin
function M.setup(opts)
  require("jiejie.commands").setup()
end

return M
