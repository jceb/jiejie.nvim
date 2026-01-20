local buffer = require("jiejie.buffer")
local context = require("jiejie.context")
local parsers = require("jiejie.parsers")

--- Jujutsu log related operations
local M = {}

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, callback)
  local template =
    'change_id.shortest() ++ "\t" ++ if(empty, "†(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", truncate_end(50, description.first_line(), "…")) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∬" ++ if(git_head, " git_head()") ++ "∮" ++ if(conflict, " conflict")'
  local command = {
    "jj",
    "log",
    "-n",
    "10", -- FIXME: make this configurable
    "-s",
    "-T",
    template,
    "-r",
    "::", -- FIMXE: make this configurable
  }
  vim.system(
    command,
    { text = true, cwd = ctx.root },
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting log:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      local headers = { buffer.create_header("Help", "g?") }
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end)
  )
end

--- Setup log model
--- @param id number Auto-command group ID
function M.setup(id)
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "jiejie://*",
    group = id,
    callback = function(ev)
      -- Loader function for files of type jiejie
      vim.cmd.doau("BufReadPre")
      local url = parsers.parse_url(ev.file)
      M.load({ root = url.root, buf = ev.buf, curpos = nil }, function(ctx)
        context.set_context(ctx)
        buffer.setup_buffer(ctx)
        vim.cmd.doau("BufReadPost")
      end)
    end,
  })
end

return M
