local M = {}

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
  ctx.curpos = M.logRender(ctx, data)
  return ctx
end

--- Tests validity of buffer, returns nil if buffer is not valid, otherwise the passed in buffer id
--- @param buf number Buffer ID
--- @return number?
function M.isLogBufferValid(buf)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
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
  -- TODO: vim.api.nvim_buf_set_keymap(
  return ctx
end

--- Render log output in buffer and return cursor position for current commit
--- @param ctx Context context
--- @param data table jj log output to display
--- @return table
function M.logRender(ctx, data)
  vim.api.nvim_set_option_value("modifiable", true, { buf = ctx.buf })
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.buf })
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i, match }
      break
    end
  end
  -- TODO: reload upon local file changes
  return ctx.curpos
end

--- @class JiejieURL
--- @field scheme
--- @field root
--- @field path

--- Returns jj's root directory
--- @param directory? string Dirtory to start look at. If not present, start looking in the directory of the currently
--- open file
--- @return string
function M.getRoot(directory)
  local cwd = directory or vim.fn.expand("%:p:h")
  local repo_stats = vim.uv.fs_stat(cwd)
  if repo_stats == nil or repo_stats.type ~= "directory" then
    cwd = vim.fn.getcwd()
  end
  local res = vim
    .system({ "jj", "workspace", "root" }, {
      text = true,
      cwd = cwd,
    })
    :wait()
  if res.code ~= 0 then
    error("Error finding workspace:\n" .. res.stderr)
  end
  return vim.trim(res.stdout)
end

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
  local root = M.getRoot(string.sub(url, 10, match))
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

--- Print command output
--- @param stdr string Input stream type
function M.stdprint(stdx)
  return function(err, data)
    if err ~= nil then
      vim.print("error", err)
    end
    if data ~= nil then
      vim.print(data)
    end
  end
end

return M
