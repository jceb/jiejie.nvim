local buffer = require("jiejie.buffer")
local jujutsu = require("jiejie.jujutsu")
local config = require("jiejie.config")

--- Jujutsu operation log related operations
local M = {}

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, callback)
  local cmd = "operation"
  local args = {
    "log",
    "-n",
    tostring(ctx.log_revisions or config.get().log_revisions),
    "-s",
  }
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
      }
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end),
  })
end

return M
