local jujutsu = require("jiejie.jujutsu")

--- Parser functions
local M = {}

--- Parse evo log change string into structured data
--- @param line string Line containing a change string
--- @param linenr number Line number in log buffer that contains filename
--- @return Change?
function M.parse_evolog_change(line, linenr)
  local match = vim.fn.matchlist(
    line,
    [[^\%( \?[╭╮├┤╰─╯│] \?\)*\([@×◆○]\)\%( \?[╭╮├┤╰─╯│] \?\)*  \+\([a-z0-9]\+\%(\/[0-9]\+\)\?\) \([^ ]\+\) .*$]]
  )
  if #match == 0 then
    return nil
  end
  local status = match[2]
  local id = match[3]
  local email = match[4]
  if status == "" or id == "" or email == "" then
    return nil
  end
  return {
    status = status,
    id = id,
    id_short = id,
    -- empty = empty,
    -- description_first_line = description_first_line,
    -- bookmarks = bookmarks,
    -- tags = tags,
    -- git_head = git_head,
    -- conflict = conflict,
    -- immutable = immutable,
    email = email,
    linenr = linenr,
    -- divergent = divergent,
    -- commit_id = commit_id,
    -- current_working_copy = current_working_copy,
    -- parents = parents,
  }
end

--- Parse operation log change string into structured data
--- @param line string Line containing a change string
--- @param linenr number Line number in log buffer that contains filename
--- @return OperationChange?
function M.parse_oplog_change(line, linenr)
  local match =
    vim.fn.matchlist(line, [[^\%( \?[╭╮├┤╰─╯│] \?\)*\([@×◆○]\)\%( \?[╭╮├┤╰─╯│] \?\)*  \+\([a-z0-9]\+\) \([^ ]\+\) .*$]])
  if #match == 0 then
    return nil
  end
  local status = match[2]
  local id = match[3]
  local email = match[4]
  if status == "" or id == "" or email == "" then
    return nil
  end
  return {
    status = status,
    id = id,
    email = email,
    linenr = linenr,
  }
end

--- Parse change string into structured data
--- @param line string Line containing a change string
--- @param linenr number Line number in log buffer that contains filename
--- @return Change?
function M.parse_change(line, linenr)
  local match = vim.fn.matchlist(
    line,
    [[^\%( \?[╭╮├┤╰─╯│] \?\)*\([@×◆○]\)\%( \?[╭╮├┤╰─╯│] \?\)*  \+\([a-z]\+\)\%(??\)\?\t†\([^‡]*\)‡\([^⌠]*\)⌠\([^⌡]*\)⌡\([^∫]*\)∫\([^∬]*\)∬\([^∮]*\)\(∮.*\)$]]
  )
  if #match == 0 then
    return nil
  end
  local match2 =
    vim.fn.matchlist(match[10], [[^[^∮]*∮\([^∴]*\)∴\([^∵]\+\)∵\([^∶]*\)∶\([^∷]*\)∷\([a-z0-9]\+\)∼\([^∾]*\)∾\([0-9]\+\)$]])
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
  local email = vim.trim(match2[4])
  local divergent = match2[5] == " divergent"
  local commit_id = match2[6]
  local current_working_copy = match2[7] == " current working copy"
  local parents = tonumber(match2[8])
  if status == "" or id_short == "" or id == "" or commit_id == "" then
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
    divergent = divergent,
    commit_id = commit_id,
    current_working_copy = current_working_copy,
    parents = parents,
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
  local match = vim.fn.matchlist(line, [[^[╭╮├┤╰─╯│]\%( \?[╭╮├┤╰─╯│] \?\)*  \+\([MADRC]\) \(.\+\)$]])
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
    filename = vim.fn.substitute(filename, [[{[^=]* => \([^}]*\)}]], [[\1]], "g")
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
--- @field revision? string Revision string - is nil for log URLs
--- @field path? string Path in the repository
--- @field workspace string Repository workspace
--- @field is_log? boolean Whether the URL is pointing to the log
--- @field is_evolog? boolean Whether the URL is pointing to an evolog
--- @field is_oplog? boolean Whether the URL is pointing to the oplog
--- @field is_oprev? boolean Whether the URL is pointing an oplog revision
--- @field current_working_copy? boolean Whether the URL is pointing a revision that is the current working copy

--- Parse jiejie:// URL into its componentens
--- @param url string URL
--- @return JiejieURL?
function M.parse_url(url)
  if not vim.startswith(url, "jiejie://") then
    return nil
  end
  local match =
    vim.fn.matchlist(url, [[^\(jiejie://\)\(.\{-1,}\)/\.jj/\([^/]\+\)/\(log\|evolog\|oplog\|oprev\|rev\)/\%(index$\|\([^/]\+\)\%(/\(.\+\)$\|$\)\?\)]])
  if #match == 0 then
    return nil
  end
  local root = jujutsu.get_root(match[3])
  local repo_stats = root and vim.uv.fs_stat(root)
  if not repo_stats or repo_stats.type ~= "directory" then
    error("Error: path does not point to a directory: " .. root)
  end
  local is_log = false
  local is_evolog = false
  local is_oplog = false
  local is_oprev = false
  if match[5] == "log" then
    is_log = true
  elseif match[5] == "evolog" then
    is_evolog = true
  elseif match[5] == "oplog" then
    is_oplog = true
  elseif match[5] == "rev" or match[5] == "oprev" then
    if match[5] == "oprev" then
      is_oprev = true
    end
  else
    error("Unknown path in URL: " .. url)
  end
  return {
    scheme = match[2],
    root = root,
    workspace = match[4],
    revision = match[6] ~= "" and string.gsub(match[6], "%%2F", "/") or nil,
    path = match[7] ~= "" and match[7] or nil,
    is_log = is_log,
    is_evolog = is_evolog,
    is_oplog = is_oplog,
    is_oprev = is_oprev,
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
--- @field id string Change ID
--- @field id_short string Short change ID
--- @field commit_id string Commit ID
--- @field description_first_line string First line of description

--- Parse a line to containing a bookmark or tag
--- @param line string Line
--- @return BookmarkTag?
function M.parse_bookmark_or_tag(line)
  local match = vim.fn.matchlist(line, [[^\([^†]\+\)†\([^‡]\+\)‡\([^⌠]\+\)⌠\([^⌡]*\)⌡\([^∫]*\)∫\([^∬]*\)∬\([^∮]*\)∮\(.*\)$]])
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
  local commit_id = match[9] ~= "" and match[9] or nil
  return {
    name = name,
    tracked = tracked,
    present = present,
    remote = remote,
    id = id,
    id_short = id_short,
    description_first_line = description_first_line,
    commit_id = commit_id,
  }
end

--- Join URL into a string
--- @param url JiejieURL
--- @return string
function M.join_url(url)
  local jiejie_url
  local revision = url.revision and string.gsub(url.revision, "/", "%%2F") or ""
  if url.is_log then
    jiejie_url = "jiejie://" .. url.root .. "/.jj/" .. url.workspace .. "/log/index"
  elseif url.is_oplog then
    jiejie_url = "jiejie://" .. url.root .. "/.jj/" .. url.workspace .. "/oplog/index"
  elseif url.is_evolog then
    jiejie_url = "jiejie://" .. url.root .. "/.jj/" .. url.workspace .. "/evolog/" .. revision
  elseif url.is_oprev then
    jiejie_url = "jiejie://" .. url.root .. "/.jj/" .. url.workspace .. "/oprev/" .. revision .. "/" .. (url.path or "")
  elseif url.revision == "@" or url.current_working_copy then
    jiejie_url = vim.fs.joinpath(url.root, url.path or "")
  else
    jiejie_url = "jiejie://" .. url.root .. "/.jj/" .. url.workspace .. "/rev/" .. revision .. "/" .. (url.path or "")
  end
  return vim.fn.fnameescape(jiejie_url)
end

return M
