local parsers = require("jiejie.parsers")
local helpers = require("jiejie.log_buffer_helpers")

--- Opeations that manipulate the buffer / window
local M = {}

--- Create a header
--- @param key string Header key
--- @param value string Header value
function M.create_header(key, value)
  return key .. ": " .. value
end

--- Render log output in buffer and return cursor position of current change
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param headers? string[] headers added before the data
--- @return table
function M.render(ctx, data, headers)
  if headers and #headers > 0 then
    M.buf_set_lines(ctx, vim.list_extend(headers, { "" }), 0, -1)
  end
  local headers_offset = headers and #headers or 0
  if data[#data] == "" then
    data[#data] = nil
  end
  M.buf_set_lines(ctx, data, -1, -1)
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
  return ctx.curpos
end

--- Set lines in current buffer
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param start? number jj log output to display
--- @param end_? number jj log output to display
function M.buf_set_lines(ctx, data, start, end_)
  assert(ctx, "Context not provided: ctx")
  assert(data, "Data not provided: data")
  local modifiable = vim.bo[ctx.buf].modifiable
  local readonly = vim.bo[ctx.buf].readonly
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  vim.api.nvim_buf_set_lines(ctx.buf, start and start or 0, end_ and end_ or -1, false, data)
  vim.bo[ctx.buf].readonly = modifiable
  vim.bo[ctx.buf].modifiable = readonly
end

--- Render file contents
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param opts? {filetype?: string} Options
function M.render_file(ctx, data, opts)
  assert(ctx, "Context not provided: ctx")
  assert(data, "Data not provided: data")
  local lopts = opts or {}
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  if lopts.filetype then
    vim.bo[ctx.buf].filetype = lopts.filetype
  end
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.focus(ctx, vertical)
  ctx.buf = helpers.is_valid(ctx.buf)
  local filename = parsers.join_url({
    root = ctx.root,
    is_index = true,
    workspace = "default", -- TODO: workspace is not yet supported
  })
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
    if vertical then
      vim.cmd.vs(filename)
    else
      vim.cmd.sp(filename)
    end
    return ctx
  end
  local bufid = vim.api.nvim_get_current_buf()
  if bufid == ctx.buf then
    return ctx
  end
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(0, winid)
      return ctx
    end
  end
  if vertical then
    vim.cmd.vs(filename)
  else
    vim.cmd.sp(filename)
  end
  M.setup_buffer(ctx)
  return ctx
end

--- Setup log buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.bo[ctx.buf].buftype = "nofile"
  -- vim.bo[ctx.buf].buftype = "nowrite"
  vim.bo[ctx.buf].modeline = false
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  vim.bo[ctx.buf].bufhidden = "delete"
  vim.bo[ctx.buf].filetype = "jiejie"
  vim.bo[ctx.buf].softtabstop = 4
  vim.bo[ctx.buf].tabstop = 4
  vim.bo[ctx.buf].undolevels = -1
  vim.bo[ctx.buf].swapfile = false
  local winid = vim.api.nvim_get_current_win()
  vim.wo[winid][0].number = false
  vim.wo[winid][0].foldmethod = "syntax"
  vim.wo[winid][0].foldtext = "v:folddashes.substitute(substitute(getline(v:foldstart),'⌠.*','','g'), '[†‡]', '', 'g')"
  vim.wo[winid][0].relativenumber = false
  vim.wo[winid][0].conceallevel = 2
  vim.wo[winid][0].concealcursor = "nvic"
  vim.wo[winid][0].listchars = "tab:  "
  -- Place cursor on the current change
  if ctx.curpos then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "a", "A", "c", "C", "d", "D", "i", "I", "r", "R", "s", "S", "x", "X", "p", "P" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  local mappings = require("jiejie.log_buffer_mappings")
  --- @param fn fun(args?: WithArgs): boolean Callback function
  --- @param opts? WithOpts Options
  local with_root_context = function(fn, opts)
    return helpers.with_context(ctx.root, fn, opts)
  end
  for _, value in ipairs(mappings.nmaps) do
    local plug = "<Plug>(jiejie-" .. value.key .. ")"
    local fn = with_root_context(value.fn)
    vim.keymap.set("n", value.key, plug, { desc = value.desc, nowait = true, buffer = true })
    vim.keymap.set("n", plug, fn, { desc = value.desc, buffer = true })
    if value.with_force then
      local force_plug = "<Plug>(jiejie-!" .. value.key .. ")"
      vim.keymap.set("n", "!" .. value.key, force_plug, { desc = value.desc, nowait = true, buffer = true })
      vim.keymap.set("n", force_plug, helpers.with_force(fn), { desc = "Ignoring immutuability. " .. value.desc, buffer = true })
    end
  end
  require("jiejie.log_diff").setup_buffer(ctx)
  require("jiejie.log_dirty_check").setup_buffer(ctx)
  require("jiejie.log_view").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
