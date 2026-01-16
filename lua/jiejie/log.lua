local context = require("jiejie.context")

--- Jujutsu log related operations
local M = {}

local buffer = require("jiejie.buffer")
local parsers = require("jiejie.parsers")

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @return Context
function M.load(ctx)
  local template =
    'change_id.shortest() ++ "\t" ++ if(empty, "†(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", truncate_end(50, description.first_line(), "…")) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∬" ++ if(git_head, " git_head()")'
  local command = {
    "jj",
    "log",
    "--no-pager",
    "--color",
    "never",
    "-n",
    "10", -- FIXME: make this dynamic
    "-T",
    template,
  }
  local res = vim.system(command, { text = true, cwd = ctx.root }):wait()
  if res.code ~= 0 then
    error("Error getting log:\n" .. res.stderr)
  end
  local data = vim.split(res.stdout, "\n")
  local headers = { buffer.create_header("Help", "g?") }
  ctx.curpos = buffer.render(ctx, data, headers)
  return ctx
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
      local url = parsers.parseUrl(ev.file)
      local ctx = context.set_context(M.load({ root = url.root, buf = ev.buf, curpos = nil }))
      buffer.setup_buffer(ctx)
      vim.cmd.doau("BufReadPost")
    end,
  })
end

return M
