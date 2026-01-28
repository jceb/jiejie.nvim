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
  if #match == 0 then
    return nil
  end
  local match2 = vim.fn.matchlist(match[10], [[^[^∮]*∮\([^∴]*\)∴\([a-z]\+\)]])
  if #match2 == 0 then
    return nil
  end
  local status = match[2]
  local id_short = match[3]
  local empty = match[4] == "(empty) "
  local description_first_line = match[5] ~= "(no description set)" and match[5] or ""
  local bm = vim.trim(match[6] or "")
  local bookmarks = bm == "" and {} or vim.split(bm, " ")
  local tg = vim.trim(match[7] or "")
  local tags = tg == "" and {} or vim.split(tg, " ")
  local git_head = match[8] == " git_head()"
  local conflict = match[9] == " conflict"
  local immutable = match2[2] == " immutable"
  local id = match2[3]
  if not status or not id_short or not id then
    return nil
  end
  return {
    status = status,
    id = id,
    id_short = id_short,
    empty = empty,
    description_first_line = description_first_line,
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
  local match = vim.fn.matchlist(object_string, [[^\([^:]\+\)\?\%(:\%((\([^)]\+\))\)\?\(.*\)\)\?$]])
  if #match == 0 then
    return nil
  end
  local change_id = match[2]
  local work_tree = match[3]
  local filename = match[4] and vim.fn.expand(match[4]) or match[4]
  return {
    change_id = change_id ~= "" and change_id or "@",
    work_tree = work_tree ~= "" and work_tree or nil,
    filename = filename ~= "" and filename or nil,
  }
end

--- Parse change string into structured data
--- @param line string Line containing a file name string
--- @param linenr number Line number in log buffer that contains filename
--- @return ModifiedFile?
function M.parse_filename(line, linenr)
  local match = vim.fn.matchlist(line, [[^[╮├─╯│ ]\+  \([MADRC]\) \(.\+\)$]])
  if #match == 0 then
    return nil
  end
  local modification = match[2]
  local filename = match[3]
  if not modification or not filename then
    return nil
  end
  if modification == "R" or modification == "C" then
    -- adjust filename that is provided in jj's rname format
    filename = vim.fn.substitute(filename, [[{[^=]* => \([^}]\+\)}]], [[\1]], "g")
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
--- @return JiejieURL?
function M.parse_url(url)
  if not vim.startswith(url, "jiejie://") then
    return nil
  end
  local match = vim.fn.matchlist(url, [[^\(jiejie://\)\(.\+\)/.jj/\([^/]\+\)/\(.\+\)$]])
  if #match == 0 then
    return nil
  end
  local root = jujutsu.get_root(match[3])
  local repo_stats = vim.uv.fs_stat(root)
  if not repo_stats or repo_stats.type ~= "directory" then
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
