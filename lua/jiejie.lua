local _config = require("jiejie.config")
local M = {}

--- Configure the plugin
--- @param opts? Configuration User configuration
function M.setup(opts)
  if opts then
    _config.update(opts)
  end
  require("jiejie.log_view").setup()
  require("jiejie.context").setup()
  require("jiejie.commands").setup()
end

return M
