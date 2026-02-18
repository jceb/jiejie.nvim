local buffer = require("jiejie.log_buffer")
local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local log_view = require("jiejie.log_view")
local parsers = require("jiejie.parsers")

--- Jujutsu log related operations
local M = {}

--- Template to retrieve log entries
M.template =
  [[change_id.shortest() ++ if(divergent, "??") ++ "\t" ++ "†" ++ if(empty, "(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", description.first_line()) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∫" ++ if(git_head, " git_head()") ++ "∬" ++ if(conflict, " conflict") ++ "∮" ++ if(immutable, " immutable") ++ "∴" ++ change_id ++ "∵ " ++ author.email() ++ "∶" ++ if(divergent, " divergent") ++ "∷" ++ commit_id ++ "∼" ++ if(current_working_copy, " current working copy") ++ "∾" ++ parents.len()]]

--- Load/reload log contents into the jujutsu buffer
--- @param ctx Context context
--- @param callback fun(ctx: Context) Asynchronous callback
M.load = function(ctx, callback)
  local log_diff = require("jiejie.log_diff")
  log_diff.setup_buffer(ctx) -- clear diffs as a workaround until reloading of diffs is implemented
  local cmd = "log"
  local current_log_view = log_view.get_log_view()
  local idx = 1
  local sepaator = "·"
  local header_log_view = table.concat(
    vim.iter(log_view.LOG_VIEWS):fold({}, function(acc, v)
      local view = idx .. "ss" .. sepaator .. (v.description or v.fileset)
      if v.fileset == current_log_view.fileset then
        table.insert(acc, "†" .. view .. "‡")
      else
        table.insert(acc, view)
      end
      idx = idx + 1
      return acc
    end),
    " "
  )
  local args = {
    "-n",
    tostring(ctx.log_revisions or 10), -- TODO: make default number of revisions configurable
    "-s",
    "-T",
    M.template,
    "-r",
    current_log_view.fileset,
  }
  jujutsu.cli(ctx, cmd, {
    args = args,
    on_exit = vim.schedule_wrap(function(res)
      if res.code ~= 0 then
        error("Error getting log:\n" .. res.stderr)
      end
      local data = vim.split(res.stdout, "\n")
      local headers = {
        buffer.create_header("Help", "g?"),
        buffer.create_header("Reload", "R"),
        buffer.create_header("View", header_log_view),
      }
      local cmd_op = "op"
      local oplog = jujutsu.cli(ctx, cmd_op, {
        args = { "log", "-n", "1", "--no-graph", "-T", 'id.short(4) ++ " " ++ user ++ " " ++ description' },
      })
      if oplog.code == 0 then
        headers = vim.list_extend(headers, { buffer.create_header("Last operation", vim.trim(oplog.stdout)) })
      end
      ctx.curpos = buffer.render(ctx, data, headers)
      if callback then
        callback(ctx)
      end
    end),
  })
end

--- Load/reload object contents
--- @param ctx Context context
--- @param url JiejieURL File url
--- @param callback fun(ctx: Context) Asynchronous callback
M.load_object = function(ctx, url, callback)
  local cmd, args, filetype
  if not url.path then
    cmd = "show"
    args = {
      "-r",
      url.revision,
      "-s",
      "--git",
    }
    filetype = "jiejie_change"
  else
    cmd = "file"
    args = {
      "show",
      "-r",
      url.revision,
      url.path,
    }
  end
  jujutsu.cli(ctx, cmd, {
    args = args,
    on_exit = vim.schedule_wrap(function(res)
      local data
      if res.code ~= 0 then
        -- error("Error getting object contents:\n" .. res.stderr)
        data = {}
      else
        data = vim.split(res.stdout, "\n")
      end
      buffer.render_file(ctx, data, { filetype = filetype })
      if callback then
        callback(ctx)
      end
    end),
  })
end

--- Setup log model
--- @param id number Auto-command group ID
function M.setup(id)
  vim.api.nvim_create_autocmd("ShellCmdPost", {
    pattern = "*",
    group = id,
    callback = function()
      vim.cmd.checktime()
      local ctx = context.get_context()
      if ctx and ctx.buf then
        local log_dirty_check = require("jiejie.log_dirty_check")
        log_dirty_check.dirty_mark_content(ctx.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    pattern = "*",
    group = id,
    callback = function(ev)
      if vim.b.jiejie_check == false then
        return
      end
      local file_stats = vim.uv.fs_stat(ev.file)
      if file_stats then
        vim.cmd.checktime()
        if not vim.b.jiejie_check then
          vim.b.jiejie_check = true
          vim.b.jiejie_root = jujutsu.get_root(vim.fn.fnamemodify(ev.file, ":h"))
          if not vim.b.jiejie_root then
            vim.b.jiejie_check = false
          end
        end
        local ctx = context.get_context(vim.b.jiejie_root)
        if ctx and ctx.buf then
          local log_dirty_check = require("jiejie.log_dirty_check")
          log_dirty_check.dirty_mark_content(ctx.buf)
        end
      else
        vim.b.jiejie_check = false
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufReadCmd", {
    pattern = "jiejie://*",
    group = id,
    callback = function(ev)
      -- Loader function for objects of type jiejie
      vim.cmd.doau("BufReadPre")
      local url = parsers.parse_url(ev.file)
      if not url then
        error("Error: unknown URL: " .. ev.file)
      end
      if url.revision == "repo" and url.path == "index" then
        local ctx = context.get_context(url.root)
        if not ctx then
          return
        end
        ctx.buf = ctx.buf or ev.buf
        M.load(ctx, function(_ctx)
          context.set_context(_ctx)
          buffer.setup_buffer(_ctx)
          vim.cmd.doau("BufReadPost")
        end)
      else
        vim.bo[ev.buf].buftype = "nofile"
        M.load_object({ root = url.root, buf = ev.buf, curpos = nil }, url, function()
          local bufid = vim.api.nvim_get_current_buf()
          if bufid == ev.buf then
            -- dectect file type
            vim.cmd.filetype({ "detect" })
            vim.cmd.doau("BufReadPost")
          else
            -- special handling for when the file is loaded in a window that is not the current one
            local current_winid = vim.api.nvim_get_current_win()
            for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
              local win_bufid = vim.api.nvim_win_get_buf(winid)
              if win_bufid == ev.buf then
                local winnr = vim.api.nvim_win_get_number(winid)
                vim.cmd.windo({ range = { winnr }, args = { "filetype", "detect" } })
                vim.cmd.windo({ range = { winnr }, args = { "doau", "BufReadPost" } })
                break
              end
            end
            vim.api.nvim_tabpage_set_win(0, current_winid)
          end
        end)
      end
    end,
  })
end

return M
