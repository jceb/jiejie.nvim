local M = {}

--- Setup the plugin
function M.setup()
  require("jiejie.context").setup()
  require("jiejie.commands").setup()
end

return M
