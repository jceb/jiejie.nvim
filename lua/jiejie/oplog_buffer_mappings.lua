local api = require("jiejie.api")
local log_buffer_mappings = require("jiejie.log_buffer_mappings")
local helpers = require("jiejie.oplog_buffer_helpers")
local buffer = require("jiejie.buffer")

--- Log buffer mappings
local M = {}

--- @type table<string, fun(opts?: {}): fun()>
M.fns = {
  --
}

--- @type table<number, {key: string, fn: fun(args?: WithArgs), desc: string, with_force: boolean, with_allow_backwards?: boolean}>
M.nmaps = {
  --

  -- Navigation maps {{{1
  {
    key = "<CR>",
    --- @param args WithOpArgs
    fn = helpers.search_change(function(args)
      if args.src_change.status == "@" then
        vim.notify("Repository is at the current operation, no need to revert it", vim.log.levels.WARN)
        return false
      end
      api.operation_restore(args.ctx, args.src_change)
      return true
    end),
    desc = "Restore repository at the change under the cursor",
  },

  -- Operation log filter maps {{{1
  {
    key = "so",
    fn = log_buffer_mappings.fns.so({ oplog = false }),
    desc = "Show operation log in a horizontal spilt",
  },
  {
    key = "sO",
    fn = log_buffer_mappings.fns.so({ vertical = true, oplog = false }),
    desc = "Show operation log in a vertical spilt",
  },

  -- Miscellaneous maps {{{1
  {
    key = "g?",
    fn = function()
      api.show_help(nil, { buffer_type = buffer.BUFFER_TYPE.OPLOG })
    end,
    desc = "Show help",
  },

  -- Miscellaneous maps {{{1
  {
    key = "q",
    fn = log_buffer_mappings.fns.q({ close_current_window = true }),
    desc = "Close the operation log window",
  },
  {
    key = "R",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      local _winid = vim.api.nvim_get_current_win()
      local pos = vim.api.nvim_win_get_cursor(_winid)
      api.reload_oplog(args.ctx, function()
        vim.notify("Log reloaded", vim.log.levels.INFO)
        api.set_cursor(_winid, pos)
      end)
      return true
    end,
    desc = "Reload log",
  },
}

return M
