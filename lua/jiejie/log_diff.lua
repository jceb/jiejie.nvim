local jujutsu = require("jiejie.jujutsu")

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

--- Closes open windows and buffers associated with a diff
--- @param ctx Context context
--- @param opts? {tabnr?: number} Options
--- - tabnr: Closes windows on this tab, if not provided, the current tab is used
function M.diff_close(ctx, opts)
  assert(ctx, "Context not provided: ctx")
  local lopts = opts or {}
  local buffer_helpers = require("jiejie.log_buffer_helpers")
  if not buffer_helpers.is_valid(ctx.buf) then
    return
  end
  -- FIXME: tabnr isn't stable, it changes when the order of tabs is modified. This causes the diffed windows to not be found anymore
  local tabnr = lopts.tabnr or vim.api.nvim_get_current_tabpage()
  local windows = vim.b[ctx.buf].jiejie_diff_windows
  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    for idx, win in ipairs(windows[tabnr] or {}) do
      if idx > 1 then
        if win.winid == winid then
          vim.api.nvim_win_close(win.winid, false)
        end
      else
        if win.winid == winid then
          -- disable diff in the first window
          local winnr = vim.api.nvim_win_get_number(winid)
          vim.cmd.windo({ range = { winnr }, args = { "diffoff" } })
        end
      end
    end
  end
  table.remove(windows, tabnr)
  vim.b[ctx.buf].jiejie_diff_windows = windows
  return ctx
end

--- Mark a window and buffer as associated with a diff
--- @param ctx Context context
--- @param opts? {winid?: number} Options
--- - winid: If not provided, the current window is used
--- @return Context?
function M.diff_mark(ctx, opts)
  assert(ctx, "Context not provided: ctx")
  local lopts = opts or {}
  local buffer_helpers = require("jiejie.log_buffer_helpers")
  if not buffer_helpers.is_valid(ctx.buf) then
    return
  end
  local winid = lopts.winid or vim.api.nvim_get_current_win()
  -- FIXME: tabnr isn't stable, it changes when the order of tabs is modified. This causes the diffed windows to not be found anymore
  local tabnr = vim.api.nvim_win_get_tabpage(winid)
  local windows = (vim.b[ctx.buf].jiejie_diff_windows or {})
  local tabwindows = windows[tabnr] or {}
  if #(vim.tbl_filter(function(win)
    return win.winid == winid
  end, tabwindows)) > 0 then
    -- Window is already registered
    return
  end
  table.insert(tabwindows, { winid = winid })
  table.remove(windows, tabnr)
  table.insert(windows, tabnr, tabwindows)
  vim.b[ctx.buf].jiejie_diff_windows = windows
  return ctx
end

--- Test if diff is shown for this filename
--- @param file ModifiedFile File name
--- @param change Change Change data
--- @return boolean
function M.diff_shown(file, change)
  local api = require("jiejie.api")
  local res = get_expanded(api.get_change_id(change), file.filename)
  return res and true or false
end

--- Show diff for file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change data
function M.diff_show(ctx, file, change)
  local api = require("jiejie.api")
  local expanded = get_expanded(api.get_change_id(change), file.filename)
  if expanded then
    return
  end
  local cmd = "diff"
  local args = { "--git", "-r", api.get_change_id(change), file.filename }
  local res = jujutsu.cli(ctx, cmd, { args = args, notify_on_failure = false, error_on_failure = false })
  if res.code ~= 0 then
    vim.notify("Diff failed for " .. file.filename, vim.log.levels.WARN)
    return
  end
  local diff = vim.split(vim.trim(res.stdout), "\n")
  local offset = 0
  for index, line in ipairs(diff) do
    if
      not (
        vim.startswith(line, "diff --git")
        or vim.startswith(line, "--- ")
        or vim.startswith(line, "+++ ")
        or vim.startswith(line, "index ")
        or vim.startswith(line, "new file mode")
        or vim.startswith(line, "deleted ")
      )
    then
      offset = index
      break
    end
  end
  if offset == 0 then
    offset = #diff + 1
  end
  local buffer = require("jiejie.log_buffer")
  local data = { unpack(diff, offset) }
  buffer.buf_set_lines(ctx, data, file.linenr, file.linenr)
  set_expanded({ change_id = api.get_change_id(change), filename = file.filename, length = #data })
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change data
function M.diff_hide(ctx, file, change)
  local api = require("jiejie.api")
  local expanded = get_expanded(api.get_change_id(change), file.filename)
  if not expanded then
    return
  end
  local buffer = require("jiejie.log_buffer")
  buffer.buf_set_lines(ctx, {}, file.linenr, file.linenr + expanded.length)
  unset_expanded(api.get_change_id(change), file.filename)
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
  --- @class DiffWindow
  --- @field winid number Window number
  --- @type table<number, DiffWindow[]>
  vim.b.jiejie_diff_windows = {}
  return ctx
end

return M
