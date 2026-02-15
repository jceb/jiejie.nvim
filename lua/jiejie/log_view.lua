--- Opeations that help managing the log view
local M = {}

--- @class LogView
--- @field fileset string File set that is referenced
--- @field description? string Short description, displayed instead of the fileset

--- @type table<LogView>
M.LOG_VIEWS = {
  {
    fileset = "::",
  },
  {
    fileset = "::@",
  },
  {
    fileset = "visible_heads()",
  },
  {
    fileset = "visible_heads() ~ bookmarks() ~ tags()",
    description = "detached_heads()",
  },
  {
    fileset = "bookmarks()",
  },
  {
    fileset = "tags()",
  },
}

--- Get current log view
--- @returns Logview
function M.get_log_view()
  local view = vim.b.jiejie_log_view or 1
  view = view > 0 and view <= #M.LOG_VIEWS and view or 1
  return M.LOG_VIEWS[view]
end

--- Set log view
--- @param view LogView Activate log view
--- @returns Logview?
function M.set_log_view(view)
  local index
  for idx, v in ipairs(M.LOG_VIEWS) do
    if view.fileset == v.fileset then
      index = idx
      break
    end
  end
  if index then
    vim.b.jiejie_log_view = index
    return view
  end
end

--- Setup diff integration  for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.b.jiejie_log_view = 1
  return ctx
end

return M
