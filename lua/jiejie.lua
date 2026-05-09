local _config = require("jiejie.config")
local M = {}

--- Configure the plugin
--- @param opts? Configuration User configuration
function M.setup(opts)
  require("jiejie.context").setup()
  require("jiejie.commands").setup()
  if opts then
    _config.update(opts)
  end
end

return M
