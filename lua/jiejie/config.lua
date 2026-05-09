--- @class Configuration
--- @field excluded_revset? string Excluded revset expression that is applied to the log view and bookmark / tag selection

--- @type Configuration
local DEFAULT_CONFIG = {
  excluded_revset = nil,
}

--- @type Configuration
local CONFIG = vim.deepcopy(DEFAULT_CONFIG)

--- User configuration options
local M = {}

--- Update the configuration
--- @param config Configuration User configuration
M.update = function(config)
  CONFIG = vim.tbl_deep_extend("force", CONFIG, config)
end

--- Retrieve configuration
--- @return Configuration
M.get = function()
  return CONFIG
end

return M
