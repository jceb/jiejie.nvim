local api = require("jiejie.api")
local log_buffer_mappings = require("jiejie.log_buffer_mappings")
-- local log_diff = require("jiejie.log_diff")
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
  -- {
  --   key = "<CR>",
  --   fn = helpers.with_change_at_position(
  --     helpers.search_hunk(
  --       helpers.search_file(
  --         helpers.search_change(function(args)
  --           if args.pos_change then
  --             api.change_edit(args.ctx, args.pos_change, { force = args.force })
  --           elseif args.file then
  --             log_diff.diff_close(args.ctx)
  --             api.object_edit(args.ctx, args.file.filename, args.src_change, { previous_win = true, hunk = args.hunk })
  --           else
  --             vim.schedule(function()
  --               vim.notify("No file or change found under the curor", vim.log.levels.WARN)
  --             end)
  --           end
  --           return true
  --         end),
  --         { err_continue = true }
  --       ),
  --       { err_continue = true }
  --     ),
  --     { err_continue = true, args_key = "pos_change" }
  --   ),
  --   with_force = true,
  --   desc = "Edit change or file under the cursor",
  -- },
  {
    key = "<CR>",
    fn = helpers.search_change(function(args)
      if args.pos_change then
        api.change_edit(args.ctx, args.pos_change, { force = args.force })
      elseif args.file then
        log_diff.diff_close(args.ctx)
        api.object_edit(args.ctx, args.file.filename, args.src_change, { previous_win = true, hunk = args.hunk })
      else
        vim.schedule(function()
          vim.notify("No file or change found under the curor", vim.log.levels.WARN)
        end)
      end
      return true
    end, { args_key = "pos_change" }),
    with_force = true,
    desc = "Edit change under the cursor",
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
  {
    key = "<C-a>",
    fn = log_buffer_mappings.fns.ctrl_a(),
    desc = "Increase the number of displayed revisions in log",
  },
  {
    key = "<C-x>",
    fn = log_buffer_mappings.fns.ctrl_a({ negate = true }),
    desc = "Decrease the number of displayed revisions in log",
  },
}

return M
