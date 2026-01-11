local M = {}

local jujutsu = require("jiejie.jujutsu")

--- Tests validity of buffer, returns nil if buffer is not valid, otherwise the passed in buffer id
--- @param buf number Buffer ID
--- @return number?
function M.isLogBufferValid(buf)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
end

--- @class Commit
--- @field status string Commit status, one of @ (current commit), × (conflict), ◆ (root), ○ (regular commit)
--- @field id string Commit ID

--- Retrieve data about the commit that the cursor is on
--- @param ctx Context context
--- @param fn function Callback that is called with Context and the extracted commit information. The function is only
---                    called when a commit id is found at the cursor position
--- @return function
function M.withCommit(ctx, fn)
  return function()
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return nil
    end
    local pos = vim.api.nvim_win_get_cursor(winid)
    local line = vim.fn.getbufoneline(ctx.buf, pos[1])
    local commit = M.parseCommit(line)
    if commit == nil then
      vim.notify("No commit data found.", vim.log.levels.WARN)
    else
      fn(ctx, commit)
    end
  end
end

--- Parse commit string into structured data
--- @param commit string Line containing a commit string
--- @return Commit?
function M.parseCommit(commit)
  local match = vim.fn.matchlist(commit, [[^[─╯│ ]*\([@×◆○]\)  \([a-z]\+\)\t.*]])
  local status = match[2]
  local id = match[3]
  if match == nil or status == nil or id == nil then
    return nil
  end
  return { status = status, id = id }
end

--- Create a header
--- @param key string Header key
--- @param value string Header value
function M.createHeader(key, value)
  return key .. ": " .. value
end

--- Load buffer contents into an existing buffer
--- @param ctx Context context
--- @return Context
function M.logLoad(ctx)
  local command = {
    "jj",
    "log",
    "--color",
    "never",
    "-n",
    "10",
    "-T",
    'change_id.shortest() ++ "\t" ++ if(empty, "†(empty) ") ++ "‡" ++ if(description.first_line().len() == 0, "(no description set)", truncate_end(50, description.first_line(), "…")) ++ "⌠" ++ if(bookmarks.len() > 0, " " ++ bookmarks) ++ "⌡" ++ if(tags.len() > 0, " " ++ tags) ++ "∬" ++ if(git_head, " git_head()")',
  }
  local res = vim.system(command, { text = true, cwd = ctx.root }):wait()
  if res.code ~= 0 then
    error("Error getting log:\n" .. res.stderr)
  end
  local data = vim.split(res.stdout, "\n")
  local headers = {}
  headers[#headers + 1] = M.createHeader("Help", "g?")
  headers[#headers + 1] = ""
  ctx.curpos = M.logRender(ctx, data, headers)
  return ctx
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.logFocus(ctx, vertical)
  ctx.buf = M.isLogBufferValid(ctx.buf)
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
    local file = "jiejie://" .. ctx.root .. "/.jj/index"
    if vertical then
      vim.cmd.vs(file)
    else
      vim.cmd.sp(file)
    end
    return ctx
  end
  local bufid = vim.api.nvim_get_current_buf()
  if bufid == ctx.buf then
    return ctx
  end
  local tabid = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  for _i, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(tabid, winid)
      return ctx
    end
  end
  if vertical then
    vim.cmd.vs(ctx.buf)
  else
    vim.cmd.sp(ctx.buf)
  end
  M.logBufferConfigure(ctx)
  return ctx
end

--- Configure log buffer
--- @param ctx Context context
--- @return Context
function M.logBufferConfigure(ctx)
  vim.api.nvim_set_option_value("bufhidden", "delete", { buf = ctx.buf })
  vim.api.nvim_set_option_value("filetype", "jiejie", { buf = ctx.buf })
  vim.api.nvim_set_option_value("softtabstop", 4, { buf = ctx.buf })
  vim.api.nvim_set_option_value("tabstop", 4, { buf = ctx.buf })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = ctx.buf })
  local tabid = vim.api.nvim_get_current_tabpage()
  local winid = vim.api.nvim_tabpage_get_win(tabid)
  vim.api.nvim_set_option_value("number", false, { win = winid })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
  vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
  vim.api.nvim_set_option_value("concealcursor", "nvic", { win = winid })
  vim.api.nvim_set_option_value("listchars", "tab:  ", { win = winid })
  -- Place cursor on the current commit
  if ctx.curpos ~= nil then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  vim.keymap.set("n", "<CR>", M.withCommit(ctx, M.commitEdit()), { desc = "Edit commit", buffer = true })
  vim.keymap.set("n", "!<CR>", M.withCommit(ctx, M.commitEdit(true)), { desc = "Edit commit, ignore immutable", buffer = true })
  vim.keymap.set("n", "g?", M.showHelp, { desc = "Show help", buffer = true })
  vim.api.nvim_buf_set_var(ctx.buf, "jiejie_expanded", {})
  return ctx
end

--- Render log output in buffer and return cursor position for current commit
--- @param ctx Context context
--- @param data table jj log output to display
--- @param headers? table headers added before the data
--- @return table
function M.logRender(ctx, data, headers)
  vim.api.nvim_set_option_value("modifiable", true, { buf = ctx.buf })
  if data[#data] == "" then
    data[#data] = nil
  end
  if headers ~= nil and #headers > 0 then
    vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, headers)
  end
  local headers_offset = headers and #headers or 0
  vim.api.nvim_buf_set_lines(ctx.buf, -1, -1, false, data)
  vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.buf })
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
  -- TODO: reload upon local file system changes
  return ctx.curpos
end

--- @class JiejieURL
--- @field scheme string URL scheme
--- @field root string Path to the repository
--- @field path string Path in the repository

--- Parse jiejie:// URL into its componentens
--- @param url string URL
--- @return JiejieURL
function M.parseUrl(url)
  if not vim.startswith(url, "jiejie://") then
    error("Error: unknown URL scheme: " .. url)
  end
  local match = vim.regex("/.jj/index$"):match_str(url)
  if match == nil then
    error("Error: unable to determine repository from filename: " .. url)
  end
  local root = jujutsu.getRoot(string.sub(url, 10, match))
  local repo_stats = vim.uv.fs_stat(root)
  if repo_stats == nil or repo_stats.type ~= "directory" then
    error("Error: path does not point to a directory: " .. root)
  end
  return {
    scheme = string.sub(url, 0, 10),
    root = root,
    path = string.sub(url, match),
  }
end

--- Edit commit
--- @param force? boolean Edit immutable commits
--- @return function
function M.commitEdit(force)
  --- @param ctx Context context
  return function(ctx, commit)
    if commit.status == "@" then
      vim.notify("Already editing commit: " .. commit.id, vim.log.levels.INFO)
      return
    end
    local args = { "edit", commit.id }
    args = jujutsu.ignoreImmtuable(args, force)
    jujutsu.cli(ctx, args)
    vim.cmd.e() -- reload buffer
  end
end

--- Show help window
--- @param ctx Context context
function M.showHelp(ctx)
  vim.cmd.h("jiejie-maps")
end

return M
