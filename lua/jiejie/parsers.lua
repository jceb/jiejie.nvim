local jujutsu = require("jiejie.jujutsu")

--- Parser functions
local M = {}

--- Parse change string into structured data
--- @param change string Line containing a change string
--- @return Change?
function M.parse_change(change)
  local match = vim.fn.matchlist(change, [[^[─╯│ ]*\([@×◆◇○]\)  \([a-z]\+\)\t.*]])
  local status = match[2]
  local id = match[3]
  if match == nil or status == nil or id == nil then
    return nil
  end
  return { status = status, id = id }
end

--- @class JiejieURL
--- @field scheme string URL scheme
--- @field root string Path to the repository
--- @field path string Path in the repository

--- Parse jiejie:// URL into its componentens
--- @param url string URL
--- @return JiejieURL
function M.parse_url(url)
  if not vim.startswith(url, "jiejie://") then
    error("Error: unknown URL scheme: " .. url)
  end
  local match = vim.regex("/.jj/repo/index$"):match_str(url)
  if match == nil then
    error("Error: unable to determine repository from filename: " .. url)
  end
  local root = jujutsu.get_root(string.sub(url, 10, match))
  local repo_stats = vim.uv.fs_stat(root)
  if repo_stats == nil or repo_stats.type ~= "directory" then
    error("Error: path does not point to a directory: " .. root)
  end
  return {
    scheme = string.sub(url, 0, 10),
    root = root,
    path = string.sub(url, match),
  }
end

return M
