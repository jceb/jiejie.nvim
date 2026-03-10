local parsers = require("jiejie.parsers")

--- Opeations that manipulate the buffer / window
local M = {}

--- Create a header
--- @param key string Header key
--- @param value string Header value
function M.create_header(key, value)
  return key .. ": " .. value
end

--- Render log output in buffer and return the suggested cursor position after applying the change
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

--- @enum JiejieBufferType
M.BUFFER_TYPE = {
  LOG = 2 ^ 0,
  OPLOG = 2 ^ 1,
  EVOLOG = 2 ^ 2,
}

--- Focus buffer in current tab
--- @param ctx Context context
--- @param opts? {vertical?: boolean, buffer_type?: JiejieBufferType, change?: Change}
--- - vertical: Split window vertically, instead of horizontally
--- - buffer_type: Jiejie buffer type to focus
--- @return Context
function M.focus(ctx, opts)
  local helpers = require("jiejie.log_buffer_helpers")
  local lopts = opts or {}
  if lopts.buffer_type == M.BUFFER_TYPE.OPLOG then
    ctx.buf = ctx.bufs and ctx.bufs.oplog and ctx.bufs.oplog
  elseif lopts.buffer_type == M.BUFFER_TYPE.EVOLOG then
    ctx.buf = ctx.bufs and ctx.bufs.evolog and ctx.bufs.evolog
  else
    ctx.buf = ctx.bufs and ctx.bufs.log and ctx.bufs.log
  end
  ctx.buf = helpers.is_valid(ctx.buf)
  local filename = parsers.join_url({
    root = ctx.root,
    is_log = lopts.buffer_type == M.BUFFER_TYPE.LOG,
    is_oplog = lopts.buffer_type == M.BUFFER_TYPE.OPLOG,
    is_evolog = lopts.buffer_type == M.BUFFER_TYPE.EVOLOG,
    revision = lopts.change and lopts.change.id,
    workspace = "default", -- TODO: workspace is not yet supported
  })
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
    if lopts.vertical then
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
      if lopts.buffer_type == M.BUFFER_TYPE.EVOLOG and vim.fn.expand("%") ~= filename then
        vim.cmd.e(filename)
      end
      return ctx
    end
  end
  if lopts.vertical then
    vim.cmd.vs(filename)
  else
    vim.cmd.sp(filename)
  end
  if lopts.buffer_type == M.BUFFER_TYPE.OPLOG then
    local oplog_buffer = require("jiejie.oplog_buffer")
    oplog_buffer.setup_buffer(ctx)
  elseif lopts.buffer_type == M.BUFFER_TYPE.EVOLOG then
    local evolog_buffer = require("jiejie.evolog_buffer")
    evolog_buffer.setup_buffer(ctx)
  else
    local log_buffer = require("jiejie.log_buffer")
    log_buffer.setup_buffer(ctx)
  end
  return ctx
end

return M
