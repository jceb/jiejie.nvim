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
  local match2 = vim.fn.matchlist(match[10], [[^[^∮]*∮\([^∴]*\)∴\([^∵]\+\)∵\(.\+\)]])
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
  local email = match2[4]
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
    email = email,
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
--- @field scheme? string URL scheme
--- @field root string Path to the repository
--- @field revision string Revision string
--- @field path? string Path in the repository

--- Parse jiejie:// URL into its componentens
--- @param url string URL
--- @return JiejieURL?
function M.parse_url(url)
  if not vim.startswith(url, "jiejie://") then
    return nil
  end
  local match = vim.fn.matchlist(url, [[^\(jiejie://\)\(.\{-1,}\)/\.jj/\([^/]\+\)\%(/\(.\+\)$\|$\)\?]])
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
    revision = match[4],
    path = match[5] ~= "" and match[5] or nil,
  }
end

--- @class Hunk
--- @field start_line number Start line of hunk
--- @field start_lines number Number of lines before the modification
--- @field end_line number End line of hunk
--- @field end_lines number Number of lines after the modification
--- @field linenr number Line number in log buffer that contains the hunk
--- @field cursor_offset number Cursor offset within the hunk - should always 0 for downward search since the cursor is not within the next hunk

--- Parse a line to containing a diff hunk
--- @param line string Line
--- @param linenr number Line number in log buffer that contains the hunk
--- @param cursor_offset number Line number in log buffer that contains the hunk
--- @return Hunk?
function M.parse_hunk(line, linenr, cursor_offset)
  local match = vim.fn.matchlist(line, [[^@@ -\([0-9]\+\),\([0-9]\+\) +\([0-9]\+\),\([0-9]\+\) @@$]])
  if #match == 0 then
    return nil
  end
  local start_line = tonumber(match[2])
  local start_lines = tonumber(match[3])
  local end_line = tonumber(match[4])
  local end_lines = tonumber(match[5])
  return {
    start_line = start_line,
    start_lines = start_lines,
    end_line = end_line,
    end_lines = end_lines,
    linenr = linenr,
    cursor_offset = cursor_offset,
  }
end

--- @class BookmarkTag
--- @field name string Bookmark name
--- @field tracked boolean Bookmark is tracking a remote bookmark
--- @field present boolean Bookmark is active or has been deleted
--- @field remote string? Name of remote
--- @field id string change ID
--- @field id_short string Short change ID
--- @field description_first_line string First line of description

--- Parse a line to containing a bookmark or tag
--- @param line string Line
--- @return BookmarkTag?
function M.parse_bookmark_or_tag(line)
  local match = vim.fn.matchlist(line, [[^\([^†]\+\)†\([^‡]\+\)‡\([^⌠]\+\)⌠\([^⌡]*\)⌡\([^∫]*\)∫\([^∬]*\)∬\(.*\)$]])
  if #match == 0 then
    return nil
  end
  local name = match[2]
  local tracked = match[3] == "true"
  local present = match[4] == "true"
  local remote = match[5] ~= "" and match[5] or nil
  local id = match[6] ~= "" and match[6] or nil
  local id_short = match[7] ~= "" and match[7] or nil
  local description_first_line = match[8] ~= "" and match[8] or nil
  return {
    name = name,
    tracked = tracked,
    present = present,
    remote = remote,
    id = id,
    id_short = id_short,
    description_first_line = description_first_line,
  }
end

--- Join URL into a string
--- @param url JiejieURL
--- @return string
function M.join_url(url)
  return "jiejie://" .. url.root .. "/.jj/" .. url.revision .. "/" .. (url.path or "")
end

return M
