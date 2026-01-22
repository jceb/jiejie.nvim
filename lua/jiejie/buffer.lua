--- Opeations that manipulate the buffer / window
local M = {}

--- Tests validity of buffer, returns nil if buffer is not valid, otherwise the passed in buffer id
--- @param buf number Buffer ID
--- @return number?
function M.is_valid(buf)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
end

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
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  if headers ~= nil and #headers > 0 then
    vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, vim.list_extend(headers, { "" }))
  end
  local headers_offset = headers and #headers or 0
  vim.api.nvim_buf_set_lines(ctx.buf, -1, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
  return ctx.curpos
end

--- Render file contents
--- @param ctx Context context
--- @param data string[] jj log output to display
function M.render_file(ctx, data)
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.focus(ctx, vertical)
  ctx.buf = M.is_valid(ctx.buf)
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
    local file = "jiejie://" .. ctx.root .. "/.jj/repo/index"
    if vertical then
      vim.cmd.vs(file)
    else
      vim.cmd.sp(file)
    end
    return ctx
  end
  local bufid = vim.api.nvim_get_current_buf()
  if bufid == ctx.buf then
    return ctx
  end
  local tabid = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  for _i, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(tabid, winid)
      return ctx
    end
  end
  if vertical then
    vim.cmd.vs(ctx.buf)
  else
    vim.cmd.sp(ctx.buf)
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
  vim.wo[winid][0].relativenumber = false
  vim.wo[winid][0].conceallevel = 2
  vim.wo[winid][0].concealcursor = "nvic"
  vim.wo[winid][0].listchars = "tab:  "
  -- Place cursor on the current change
  if ctx.curpos ~= nil then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "a", "A", "c", "C", "d", "D", "i", "I", "r", "R", "s", "S", "x", "X", "p", "P" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  local commands = require("jiejie.commands")
  vim.keymap.set("n", "cc", commands.change_commit(ctx), { desc = "Commit currently edited change and create a new change", buffer = true })
  vim.keymap.set(
    "n",
    "cn",
    commands.with_change_at_position(ctx, commands.change_new()),
    { desc = "Create a new change after the change at cursor position", buffer = true }
  )
  vim.keymap.set(
    "n",
    "ss",
    commands.with_change_at_position(ctx, commands.change_squash()),
    { desc = "Squash current changes into it's parent", buffer = true }
  )
  vim.keymap.set(
    "n",
    "!ss",
    commands.with_change_at_position(ctx, commands.change_squash(true)),
    { desc = "Squash current changes into it's immutable parent", buffer = true }
  )
  vim.keymap.set(
    "n",
    "st",
    commands.with_change_at_position(ctx, commands.with_target_change_id(commands.change_squash())),
    { desc = "Squash current changes into the selecated change", buffer = true }
  )
  vim.keymap.set(
    "n",
    "!st",
    commands.with_change_at_position(ctx, commands.with_target_change_id(commands.change_squash(true))),
    { desc = "Squash current changes into the immutuable selecated change", buffer = true }
  )
  vim.keymap.set("n", "<CR>", function()
    if not commands.with_filename_at_position(ctx, commands.search_change_upwards(ctx, commands.file_edit()), false)() then
      commands.with_change_at_position(ctx, commands.change_edit())()
    end
  end, { desc = "Edit change or file at cursor position", buffer = true })
  vim.keymap.set("n", "!<CR>", function()
    if not commands.with_filename_at_position(ctx, commands.search_change_upwards(nil, commands.file_edit()), false)() then
      commands.with_change_at_position(ctx, commands.change_edit(true))()
    end
  end, { desc = "Edit immutable change or file at cursor position", buffer = true })
  vim.keymap.set("n", "de", commands.with_change_at_position(ctx, commands.change_describe(false)), { desc = "Edit change description", buffer = true })
  vim.keymap.set(
    "n",
    "!de",
    commands.with_change_at_position(ctx, commands.change_describe(true)),
    { desc = "Edit immutable change description", buffer = true }
  )
  vim.keymap.set(
    "n",
    "dd",
    commands.with_change_at_position(ctx, commands.change_describe(false, true)),
    { desc = "Edit first line of change description", buffer = true }
  )
  vim.keymap.set(
    "n",
    "!dd",
    commands.with_change_at_position(ctx, commands.change_describe(true, true)),
    { desc = "Edit first line of an immutable change description", buffer = true }
  )
  vim.keymap.set("n", "g?", commands.show_help, { desc = "Show help", buffer = true })
  require("jiejie.buffer_dirty_check").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
