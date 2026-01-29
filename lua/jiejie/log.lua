local buffer = require("jiejie.buffer")
local context = require("jiejie.context")
local parsers = require("jiejie.parsers")
local jujutsu = require("jiejie.jujutsu")

--- Jujutsu log related operations
local M = {}

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, callback)
  local log_diff = require("jiejie.log_diff")
  log_diff.setup_buffer(ctx) -- clear diffs as a workaround until reloading of diffs is implemented
  local template =
    'change_id.shortest() ++ "\t" ++ "†" ++ if(empty, "(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", description.first_line()) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∫" ++ if(git_head, " git_head()") ++ "∬" ++ if(conflict, " conflict") ++ "∮" ++ if(immutable, " immutable") ++ "∴" ++ change_id'
  local args = {
    "log",
    "-n",
    tostring(ctx.log_revisions or 10), -- TODO: make default number of revisions configurable
    "-s",
    "-T",
    template,
    "-r",
    "::", -- FIMXE: make this configurable
  }
  jujutsu.cli(
    ctx,
    args,
    nil,
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting log:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      local headers = { buffer.create_header("Help", "g?"), buffer.create_header("Reload", "r") }
      local oplog = jujutsu.cli(ctx, { "op", "log", "-n", "1", "--no-graph", "-T", 'id.short(4) ++ " " ++ user ++ " " ++ description' })
      if oplog.code == 0 then
        headers = vim.list_extend(headers, { buffer.create_header("Last operation", vim.trim(oplog.stdout)) })
      end
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end)
  )
end

--- Load/reload file contents
--- @param ctx Context context
--- @param url JiejieURL File url
--- @param callback fun(ctx: Context) Asynchronous callback
M.load_file = function(ctx, url, callback)
  if not url.path then
    error("Path missing in URL", url)
  end
  local args = {
    "file",
    "show",
    "-r",
    url.revision,
    url.path,
  }
  jujutsu.cli(
    ctx,
    args,
    nil,
    vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting file contents:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      buffer.render_file(ctx, data)
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
      if not url then
        error("Error: unknown URL: " .. ev.file)
      end
      if url.revision == "repo" and url.path == "index" then
        local ctx = context.get_context(url.root)
        ctx.buf = ctx.buf or ev.buf
        M.load(ctx, function(ctx)
          context.set_context(ctx)
          buffer.setup_buffer(ctx)
          vim.cmd.doau("BufReadPost")
        end)
      else
        vim.bo[ev.buf].buftype = "nofile"
        M.load_file({ root = url.root, buf = ev.buf, curpos = nil }, url, function(ctx)
          vim.cmd.doau("BufReadPost")
        end)
      end
    end,
  })
end

return M
