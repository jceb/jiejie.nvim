local jujutsu = require("jiejie.jujutsu")

--- Parser functions
local M = {}

--- Parse change string into structured data
--- @param line string Line containing a change string
--- @return Change?
function M.parse_change(line)
  local match = vim.fn.matchlist(
    line,
    [[^[─╯│ ]*\([@×◆◇○]\)  \([a-z]\+\)\t†\([^‡]*\)‡\([^⌠]*\)⌠\([^⌡]*\)⌡\([^∫]*\)∫\([^∬]*\)∬\([^∮]*\)\(∮.*\)]]
  )
  local match2 = vim.fn.matchlist(match[10], [[^[^∮]*∮\([^∴]*\)∴\(.\+\)]])
  local status = match[2]
  local id_short = match[3]
  local empty = match[4] == "(empty) "
  local description_shortened = match[5] ~= "(no description set)" and match[5] or ""
  local bookmarks = match[6]
  local tags = match[7]
  local git_head = match[8] == " git_head()"
  local conflict = match[9] == " conflict"
  local immutable = match2[2] == " immutable"
  local id = match2[3]
  if match == nil or match2 == nil or status == nil or id_short == nil or id == nil then
    return nil
  end
  return {
    status = status,
    id = id,
    id_short = id_short,
    empty = empty,
    description_shortened = description_shortened,
    bookmarks = bookmarks,
    tags = tags,
    git_head = git_head,
    conflict = conflict,
    immutable = immutable,
  }
end

--- Parse change string into structured data
--- @param line string Line containing a file name string
--- @return ModifiedFile?
function M.parse_filename(line)
  local match = vim.fn.matchlist(line, [[^[╮─╯│├ ]\+  \([MAD]\) \(.\+\)$]])
  local modification = match[2]
  local filename = match[3]
  if match == nil or modification == nil or filename == nil then
    return nil
  end
  return {
    modification = modification,
    filename = filename,
  }
end

--- @class JiejieURL
--- @field scheme string URL scheme
--- @field root string Path to the repository
--- @field version string Version string
--- @field path string Path in the repository

--- Parse jiejie:// URL into its componentens
--- @param url string URL
--- @return JiejieURL
function M.parse_url(url)
  if not vim.startswith(url, "jiejie://") then
    error("Error: unknown URL scheme: " .. url)
  end
  local match = vim.fn.matchlist(url, [[^\(jiejie://\)\(.\+\)/.jj/\([^/]\+\)/\(.\+\)$]])
  if match == nil then
    error("Error: unable to determine repository from filename: " .. url)
  end
  local root = jujutsu.get_root(match[3])
  local repo_stats = vim.uv.fs_stat(root)
  if repo_stats == nil or repo_stats.type ~= "directory" then
    error("Error: path does not point to a directory: " .. root)
  end
  return {
    scheme = match[2],
    root = root,
    version = match[4],
    path = match[5],
  }
end

return M
