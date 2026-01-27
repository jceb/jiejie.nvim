local jujutsu = require("jiejie.jujutsu")

--- Parser functions
local M = {}

--- Parse change string into structured data
--- @param line string Line containing a change string
--- @param linenr number Line number in log buffer that contains filename
--- @return Change?
function M.parse_change(line, linenr)
  local match = vim.fn.matchlist(
    line,
    [[^[╮├─╯│ ]*\([@×◆◇○]\)[╮├─╯│ ]*  \([a-z]\+\)\t†\([^‡]*\)‡\([^⌠]*\)⌠\([^⌡]*\)⌡\([^∫]*\)∫\([^∬]*\)∬\([^∮]*\)\(∮.*\)]]
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
    linenr = linenr,
  }
end

--- @class JiejieObject
--- @field change_id? string ChangeID
--- @field work_tree? string Work tree
--- @field filename? string File name

--- Parse jiejie object definition
--- @param object_string string Object string
--- @return JiejieObject?
function M.parse_object(object_string)
  local match = vim.fn.matchlist(object_string, [[^\([^:]\+\)\?\%(:\(([^)]\+)\)\?\(.*\)\)\?$]])
  if not match then
    return nil
  end
  local change_id = match[2]
  local work_tree = match[3]
  local filename = match[4] and vim.fn.expand(match[4]) or match[4]
  return {
    change_id = change_id ~= "" and change_id or "@",
    work_tree = work_tree,
    filename = filename,
  }
end

--- Parse change string into structured data
--- @param line string Line containing a file name string
--- @param linenr number Line number in log buffer that contains filename
--- @return ModifiedFile?
function M.parse_filename(line, linenr)
  local match = vim.fn.matchlist(line, [[^[╮├─╯│ ]\+  \([MADR]\) \(.\+\)$]])
  if match == nil then
    return nil
  end
  local modification = match[2]
  local filename = match[3]
  if not modification or not filename then
    return nil
  end
  if modification == "R" then
    -- adjust filename that is provided in jj's rname format
    filename = vim.fn.substitute(vim.fn.substitute(filename, "{[^=]\\+ => ", "", ""), "}$", "", "")
  end
  return {
    modification = modification,
    filename = filename,
    linenr = linenr,
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
