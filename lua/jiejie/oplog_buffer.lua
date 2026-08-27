local helpers = require("jiejie.log_buffer_helpers")
local api = require("jiejie.api")

--- Opeations that manipulate the buffer / window
local M = {}

--- Setup log buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  local winid = nil
  local tmp_winid = vim.api.nvim_get_current_win()
  local bufid = vim.api.nvim_win_get_buf(tmp_winid)
  -- For some reason, the current window does not contain the exepected jiejie buffer. Hunt for it.
  if bufid ~= ctx.buf then
    local wins = vim.api.nvim_list_wins()
    for index, _winid in ipairs(wins) do
      if vim.api.nvim_win_get_buf(_winid) == ctx.buf then
        winid = _winid
        break
      end
    end
  else
    winid = tmp_winid
  end
  if not winid then
    vim.notify("Failed to find jiejie buffer window", vim.log.levels.ERROR)
    return ctx
  end
  vim.bo[ctx.buf].buftype = "nofile"
  -- vim.bo[ctx.buf].buftype = "nowrite"
  vim.bo[ctx.buf].modeline = false
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  vim.bo[ctx.buf].bufhidden = "delete"
  vim.bo[ctx.buf].filetype = "jiejie_oplog"
  vim.bo[ctx.buf].softtabstop = 4
  vim.bo[ctx.buf].tabstop = 4
  vim.bo[ctx.buf].undolevels = -1
  vim.bo[ctx.buf].swapfile = false
  vim.wo[winid][0].number = false
  vim.wo[winid][0].foldmethod = "syntax"
  vim.wo[winid][0].foldtext = "v:folddashes.substitute(substitute(getline(v:foldstart),'⌠.*','','g'), '[†‡]', '', 'g')"
  vim.wo[winid][0].relativenumber = false
  vim.wo[winid][0].conceallevel = 2
  vim.wo[winid][0].concealcursor = "nvic"
  vim.wo[winid][0].listchars = "tab:  "
  -- Place cursor on the current change
  if ctx.curpos then
    api.set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "a", "A", "c", "C", "d", "D", "i", "I", "r", "R", "s", "S", "x", "X", "p", "P" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  local mappings = require("jiejie.oplog_buffer_mappings")
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
  -- require("jiejie.log_diff").setup_buffer(ctx)
  -- require("jiejie.log_dirty_check").setup_buffer(ctx)
  -- require("jiejie.log_view").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
