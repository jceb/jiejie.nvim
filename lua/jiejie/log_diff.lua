local jujutsu = require("jiejie.jujutsu")
local parsers = require("jiejie.parsers")

--- Set file as unexpanded
--- @param change_id string ChangeID
--- @param filename string File name
local function unset_expanded(change_id, filename)
  vim.b.jiejie_diff_expansion = vim.tbl_filter(function(e)
    if e and e.change_id == change_id and e.filename == filename then
      return false
    end
    return true
  end, vim.b.jiejie_diff_expansion)
end

--- Set file as expanded
--- @param diff_expansion DiffExpansion
local function set_expanded(diff_expansion)
  unset_expanded(diff_expansion.change_id, diff_expansion.filename)
  local diffs = vim.list_extend(vim.b.jiejie_diff_expansion, { diff_expansion })
  vim.b.jiejie_diff_expansion = diffs
end

--- Get DiffExpansion status
--- @param change_id string ChangeID
--- @param filename string File name
--- @return table?
local function get_expanded(change_id, filename)
  local res = vim.tbl_filter(function(e)
    if e and e.change_id == change_id and e.filename == filename then
      return true
    end
    return false
  end, vim.b.jiejie_diff_expansion)
  if #res > 0 then
    return res[1]
  end
end

--- Opeations that help with diff integration into the log view
local M = {}

--- Test if diff is shown for this filename
--- @param file ModifiedFile File name
--- @param change Change Change data
--- @return boolean
function M.diff_shown(file, change)
  local res = get_expanded(change.id, file.filename)
  return res and true or false
end

--- Show diff for file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change data
function M.diff_show(ctx, file, change)
  local expanded = get_expanded(change.id, file.filename)
  if expanded then
    return
  end
  local cmd = "diff"
  local args = { "--git", "-r", change.id, file.filename }
  local res = jujutsu.cli(ctx, cmd, { args = args, notify_on_failure = false, error_on_failure = false })
  if res.code ~= 0 then
    vim.notify("Diff failed for " .. file.filename, vim.log.levels.WARN)
    return
  end
  local diff = vim.split(vim.trim(res.stdout), "\n")
  local offset = 0
  local dummy_linenr = 23
  for index, line in ipairs(diff) do
    if parsers.parse_hunk(line, dummy_linenr) or vim.startswith(line, "Binary files") then
      offset = index
      break
    end
  end
  local buffer = require("jiejie.buffer")
  local data = { unpack(diff, offset) }
  buffer.buf_set_lines(ctx, data, file.linenr, file.linenr)
  set_expanded({ change_id = change.id, filename = file.filename, length = #data })
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change data
function M.diff_hide(ctx, file, change)
  local expanded = get_expanded(change.id, file.filename)
  if not expanded then
    return
  end
  local buffer = require("jiejie.buffer")
  buffer.buf_set_lines(ctx, {}, file.linenr, file.linenr + expanded.length)
  unset_expanded(change.id, file.filename)
  return true
end

--- Setup diff integration  for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  --- @class DiffExpansion
  --- @field change_id string ChangeID
  --- @field filename string File name
  --- @field length number Number of lines in diff
  --- @type table<DiffExpansion>
  vim.b.jiejie_diff_expansion = {}
  return ctx
end

return M
