--- @class Configuration
--- @field excluded_revset? string Excluded revset expression that is applied to the log view and bookmark / tag selection, see https://docs.jj-vcs.dev/latest/revsets/
--- @field default_view? integer Default view
--- @field dynamic_views? table<LogView> Custom views, see https://docs.jj-vcs.dev/latest/revsets/
--- @field log_revisions? integer The number revisions shown by default in the log

--- @type Configuration
local DEFAULT_CONFIG = {
  excluded_revset = "",
  -- default_view = 1,
  dynamic_views = {},
  log_revisions = 10,
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
