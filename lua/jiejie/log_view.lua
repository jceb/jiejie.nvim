--- Opeations that help managing the log view
local M = {}

--- @class LogView
--- @field id? string Unique id
--- @field revset string Revset that is referenced, see https://docs.jj-vcs.dev/latest/revsets/
--- @field paths? string[] Paths that the view is limited to
--- @field description? string Short description, displayed instead of the revset

--- @type table<LogView>
M.LOG_VIEWS = {
  {
    revset = "::",
  },
  {
    revset = "::@",
  },
  {
    revset = "visible_heads() | @",
    description = "visible_heads()",
  },
  {
    -- all heads that don't have a bookmark or tag attached
    revset = "visible_heads() ~ bookmarks() ~ tags() | @",
    description = "detached_heads()",
  },
  {
    revset = "bookmarks() | @",
    description = "bookmarks()",
  },
  {
    revset = "tags() | @",
    description = "tags()",
  },
}

--- @type table<LogView>
M.LOG_VIEWS_DYNAMIC = {}

--- Get previous log view
--- @return LogView?
function M.get_log_view_previous()
  if vim.b.jiejie_log_view_previous then
    return M.get_log_view(vim.b.jiejie_log_view_previous)
  end
end

--- Get previous log view
--- @return LogView?
function M.get_log_view_current()
  return M.get_log_view(vim.b.jiejie_log_view or 1)
end

--- Get current or specific log view
--- @param nr? number View number
--- @return LogView?
function M.get_log_view(nr)
  local view_nr = nr or vim.b.jiejie_log_view
  if view_nr and view_nr > 0 and view_nr <= (#M.LOG_VIEWS + #M.LOG_VIEWS_DYNAMIC) and view_nr then
    if view_nr <= #M.LOG_VIEWS then
      return M.LOG_VIEWS[view_nr]
    else
      return M.LOG_VIEWS_DYNAMIC[view_nr - #M.LOG_VIEWS]
    end
  end
end

--- Get log view by id
--- @param id string View id
--- @return LogView?
function M.get_log_view_by_id(id)
  assert(id, "id is nil")
  for _, view in ipairs(M.LOG_VIEWS_DYNAMIC) do
    if view.id == id then
      return view
    end
  end
end

--- Set log view
--- @param view LogView Activate log view
--- @return LogView?
function M.set_log_view(view)
  assert(view, "View is nil")
  local index
  for idx, v in ipairs(vim.list_extend(vim.list_extend({}, M.LOG_VIEWS), M.LOG_VIEWS_DYNAMIC)) do
    if v.id == view.id and v.revset == view.revset then
      index = idx
      break
    end
  end
  if index then
    if vim.b.jiejie_log_view ~= index then
      vim.b.jiejie_log_view_previous = vim.b.jiejie_log_view
    end
    vim.b.jiejie_log_view = index
    return view
  end
end

--- Add a dynamic view
--- @param view LogView New view
--- @return number
function M.add_dynamic_view(view)
  assert(view, "view is nil")
  assert(view.id, "id is nil")
  assert(view.revset, "revset is nil")
  local existing_view_idx
  -- update existing view with the same id
  for index, v in ipairs(M.LOG_VIEWS_DYNAMIC) do
    if v.id == view.id then
      M.LOG_VIEWS_DYNAMIC[index] = view
      existing_view_idx = index
      break
    end
  end
  if not existing_view_idx then
    table.insert(M.LOG_VIEWS_DYNAMIC, view)
  end
  return existing_view_idx or #M.LOG_VIEWS_DYNAMIC
end

--- Remove a dynamic view
--- @param view LogView
function M.remove_dynamic_view(view)
  assert(view, "view is nil")
  assert(view.id, "view.id is nil")
  assert(view.revset, "view.revset is nil")
  local found
  M.LOG_VIEWS_DYNAMIC = vim
    .iter(M.LOG_VIEWS_DYNAMIC)
    :filter(function(v)
      -- print("view", vim.inspect(view), vim.inspect(v))
      local res = v.id == view.id and v.revset == view.revset
      if not found and res then
        found = res
      end
      return not res
    end)
    :totable()
  return found
end

--- Setup diff integration  for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.b.jiejie_log_view = 1
  return ctx
end

return M
