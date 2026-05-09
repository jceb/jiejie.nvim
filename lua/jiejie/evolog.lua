local buffer = require("jiejie.buffer")
local jujutsu = require("jiejie.jujutsu")
local config = require("jiejie.config")

--- Jujutsu evolog related operations
local M = {}

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param revision string Revision
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, revision, callback)
  assert(ctx, "Context is missing")
  assert(revision, "Revision is missing")
  local cmd = "evolog"
  local args = {
    "-n",
    tostring(ctx.log_revisions or config.get().log_revisions),
    "-s",
    "-r",
    revision,
  }
  jujutsu.cli(ctx, cmd, {
    args = args,
    on_exit = vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting evolog:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      local headers = {
        buffer.create_header("Help", "g?"),
        buffer.create_header("Reload", "R"),
        buffer.create_header("Log", "se"),
      }
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end),
  })
end

return M
