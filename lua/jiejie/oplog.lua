local buffer = require("jiejie.buffer")
local oplog_buffer = require("jiejie.oplog_buffer")
-- local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
-- local log_view = require("jiejie.log_view")
-- local parsers = require("jiejie.parsers")

--- Jujutsu log related operations
local M = {}

--- Template to retrieve log entries
M.template =
  [[change_id.shortest() ++ if(divergent, "??") ++ "\t" ++ "†" ++ if(empty, "(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", description.first_line()) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∫" ++ if(git_head, " git_head()") ++ "∬" ++ if(conflict, " conflict") ++ "∮" ++ if(immutable, " immutable") ++ "∴" ++ change_id ++ "∵ " ++ author.email() ++ "∶" ++ if(divergent, " divergent") ++ "∷" ++ commit_id ++ "∼" ++ if(current_working_copy, " current working copy") ++ "∾" ++ parents.len() ++ "\n"]]

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, callback)
  -- local log_diff = require("jiejie.log_diff")
  -- log_diff.setup_buffer(ctx) -- clear diffs as a workaround until reloading of diffs is implemented
  local cmd = "operation"
  -- local current_log_view = log_view.get_log_view_current()
  -- assert(current_log_view, "Current log view is undefined")
  -- local idx = 1
  -- local build_log_view = function(views)
  --   local sepaator = "·"
  --   return table.concat(
  --     vim.iter(views):fold({}, function(acc, v)
  --       local view = idx .. sepaator .. (v.description or v.revset)
  --       if v.id == current_log_view.id and v.revset == current_log_view.revset then
  --         table.insert(acc, "†" .. view .. "‡")
  --       else
  --         table.insert(acc, view)
  --       end
  --       idx = idx + 1
  --       return acc
  --     end),
  --     " "
  --   )
  -- end
  -- local header_log_view = build_log_view(log_view.LOG_VIEWS)
  -- local header_log_view_dynamic = build_log_view(log_view.LOG_VIEWS_DYNAMIC)
  local args = {
    "log",
    "-n",
    tostring(ctx.log_revisions or 10), -- TODO: make default number of revisions configurable
    "-s",
  }
  -- args = vim.list_extend(args, current_log_view.paths or {})
  jujutsu.cli(ctx, cmd, {
    args = args,
    on_exit = vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting oplog:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      local headers = {
        buffer.create_header("Help", "g?"),
        buffer.create_header("Reload", "R"),
        buffer.create_header("Log", "so"),
        -- buffer.create_header("View", "[C]ss " .. header_log_view),
      }
      -- if header_log_view_dynamic ~= "" then
      --   table.insert(headers, "Dynamic View: Xss " .. header_log_view_dynamic)
      -- end
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end),
  })
end

return M
