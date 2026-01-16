local context = require("jiejie.context")
local commands = require("jiejie.commands")
local buffer = require("jiejie.buffer")

local DIRTY_CONTENT = 2 ^ 1
local DIRTY_CURSOR = 2 ^ 2

local function is_dirty(buf, key)
  if buffer.is_valid(buf) then
    return bit.band(vim.b.jiejie_dirty or 0, key) > 0
  end
end

local function set_dirty(buf, key)
  if buffer.is_valid(buf) then
    vim.b.jiejie_dirty = bit.bor(vim.b.jiejie_dirty or 0, key)
    return true
  end
end

--- Opeations that help with invalidating buffer data
local M = {}

function M.dirty_check(ev)
  if not vim.b.jiejie_dirty or not vim.b.jiejie_root then
    return
  end
  local bufid = vim.api.nvim_get_current_buf()
  local ctx = context.get_context(vim.b.jiejie_root)
  if M.dirty_check_content(bufid) then
    local curpos_current = vim.api.nvim_win_get_cursor(0)
    local curpos_new = commands.reload_log(ctx).curpos
    if M.dirty_check_cursor(bufid) and curpos_new ~= nil then
      vim.api.nvim_win_set_cursor(0, curpos_new)
    else
      vim.api.nvim_win_set_cursor(0, curpos_current)
    end
    M.dirty_clear(bufid)
  elseif M.dirty_check_cursor(bufid) then
    local curpos = M.get_dirty_cursor(bufid)
    if curpos ~= nil then
      vim.api.nvim_win_set_cursor(0, curpos)
    end
    M.dirty_clear(bufid)
  end
end

function M.dirty_check_content(buf)
  return is_dirty(buf, DIRTY_CONTENT)
end

function M.dirty_check_cursor(buf)
  return is_dirty(buf, DIRTY_CURSOR)
end

function M.get_dirty_cursor(buf)
  if buffer.is_valid(buf) then
    return vim.api.nvim_buf_get_var(buf, "jiejie_dirty_cursor") or { 1, 1 }
  end
  return { 1, 1 }
end

function M.dirty_clear(buf)
  if buffer.is_valid(buf) then
    vim.api.nvim_buf_set_var(buf, "jiejie_dirty", 0)
    vim.api.nvim_buf_set_var(buf, "jiejie_dirty_cursor", nil)
  end
end

--- Mark buffer content as dirty to trigger a reload
--- @param buf number Buffer ID
function M.dirty_mark_content(buf)
  vim.schedule(function()
    if buffer.is_valid(buf) then
      set_dirty(buf, DIRTY_CONTENT)
      vim.cmd.doau("User JiejieDirtyCheck")
    end
  end)
end

--- Mark cursor position as dirty to trigger a reload
--- @param ctx Context context
function M.dirty_mark_cursor(ctx)
  vim.schedule(function()
    if set_dirty(ctx.buf, DIRTY_CURSOR) then
      vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty_cursor", ctx.curpos)
      vim.cmd.doau("User JiejieDirtyCheck")
    end
  end)
end

--- Setup dirty checking for current buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.b.jiejie_dirty = 0
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    buffer = ctx.buf,
    callback = M.dirty_check,
  })
  return ctx
end

--- Setup dirty checking
function M.setup()
  vim.api.nvim_create_autocmd("User", {
    pattern = "JiejieDirtyCheck",
    callback = M.dirty_check,
  })
end

return M
