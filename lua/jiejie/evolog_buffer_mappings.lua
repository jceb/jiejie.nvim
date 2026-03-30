local api = require("jiejie.api")
local log_buffer_mappings = require("jiejie.log_buffer_mappings")
local helpers = require("jiejie.evolog_buffer_helpers")
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
  {
    key = "K",
    fn = helpers.search_change(function(args)
      args.src_change.current_working_copy = false -- force the revision to be displayed
      api.object_edit(args.ctx, nil, args.src_change, { edit_cmd = vim.cmd.pedit })
      return true
    end),
    desc = "Open change under the cursor",
  },

  -- Operation log filter maps {{{1
  {
    key = "sE",
    fn = log_buffer_mappings.fns.so({ vertical = true, log = buffer.BUFFER_TYPE.LOG }),
    desc = "Show log in a vertical spilt",
  },
  {
    key = "se",
    fn = log_buffer_mappings.fns.so({ log = buffer.BUFFER_TYPE.LOG }),
    desc = "Show log in a horizontal spilt",
  },

  -- Miscellaneous maps {{{1
  {
    key = "g?",
    fn = function()
      api.show_help(nil, { buffer_type = buffer.BUFFER_TYPE.EVOLOG })
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
    fn = log_buffer_mappings.fns.R,
    desc = "Reload log",
  },
}

return M
