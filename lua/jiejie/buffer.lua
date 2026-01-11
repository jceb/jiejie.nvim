local DIRTY_CONTENT = 2 ^ 1
local DIRTY_CURSOR = 2 ^ 2

local M = {}

local jujutsu = require("jiejie.jujutsu")
local timer = require("jiejie.timer")

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
  local match = vim.fn.matchlist(commit, [[^[─╯│ ]*\([@×◆◇○]\)  \([a-z]\+\)\t.*]])
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
    local file = "jiejie://" .. ctx.root .. "/.jj/repo/index"
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
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = ctx.buf })
  -- vim.api.nvim_set_option_value("buftype", "nowrite", { buf = ctx.buf })
  vim.api.nvim_set_option_value("modeline", false, { buf = ctx.buf })
  vim.api.nvim_set_option_value("readonly", true, { buf = ctx.buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.buf })
  vim.api.nvim_set_option_value("bufhidden", "delete", { buf = ctx.buf })
  vim.api.nvim_set_option_value("filetype", "jiejie", { buf = ctx.buf })
  vim.api.nvim_set_option_value("softtabstop", 4, { buf = ctx.buf })
  vim.api.nvim_set_option_value("tabstop", 4, { buf = ctx.buf })
  vim.api.nvim_set_option_value("undolevels", -1, { buf = ctx.buf })
  vim.api.nvim_set_option_value("swapfile", false, { buf = ctx.buf })
  local winid = vim.api.nvim_get_current_win()
  vim.api.nvim_set_option_value("number", false, { win = winid })
  vim.api.nvim_set_option_value("relativenumber", false, { win = winid })
  vim.api.nvim_set_option_value("conceallevel", 2, { win = winid })
  vim.api.nvim_set_option_value("concealcursor", "nvic", { win = winid })
  vim.api.nvim_set_option_value("listchars", "tab:  ", { win = winid })
  -- Place cursor on the current commit
  if ctx.curpos ~= nil then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "A", "a", "C", "c", "d", "D", "i", "I", "R", "r", "s", "S", "x", "X" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  vim.keymap.set("n", "<CR>", M.withCommit(ctx, M.commitEdit()), { desc = "Edit commit", buffer = true })
  vim.keymap.set("n", "!<CR>", M.withCommit(ctx, M.commitEdit(true)), { desc = "Edit commit, ignore immutable", buffer = true })
  vim.keymap.set("n", "de", M.withCommit(ctx, M.commitDescribe(false)), { desc = "Describe commit", buffer = true })
  vim.keymap.set("n", "!de", M.withCommit(ctx, M.commitDescribe(true)), { desc = "Describe commit, ignore immutable", buffer = true })
  vim.keymap.set("n", "di", M.withCommit(ctx, M.commitDescribe(false, true)), { desc = "Describe commit in one line", buffer = true })
  vim.keymap.set("n", "!di", M.withCommit(ctx, M.commitDescribe(true, true)), { desc = "Describe commit in one line, ignore immutable", buffer = true })
  vim.keymap.set("n", "g?", M.showHelp, { desc = "Show help", buffer = true })
  local dirtyCheck = function(ev)
    if vim.api.nvim_get_current_buf() ~= ctx.buf then
      return
    end
    if M.dirtyCheckContent(ctx) then
      local curpos = M.logLoad(ctx).curpos
      if curpos ~= nil then
        vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), curpos)
      end
      M.dirtyClear(ctx)
    elseif M.dirtyCheckCursor(ctx) then
      local curpos = M.getDirtyCursor(ctx)
      if curpos ~= nil then
        vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), curpos)
      end
      M.dirtyClear(ctx)
    end
  end
  vim.api.nvim_create_autocmd("User", {
    pattern = "JiejieDirtyCheck",
    callback = dirtyCheck,
  })
  vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained" }, {
    buffer = ctx.buf,
    callback = dirtyCheck,
  })
  vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty", 0)
  vim.api.nvim_buf_set_var(ctx.buf, "jiejie_expanded", {})
  return ctx
end

local function isDirty(ctx, key)
  if M.isLogBufferValid(ctx.buf) then
    return bit.band(vim.api.nvim_buf_get_var(ctx.buf, "jiejie_dirty") or 0, key) > 0
  end
end

local function setDirty(ctx, key)
  if M.isLogBufferValid(ctx.buf) then
    vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty", bit.bor(vim.api.nvim_buf_get_var(ctx.buf, "jiejie_dirty") or 0, key))
    return true
  end
end

function M.dirtyCheckContent(ctx)
  return isDirty(ctx, DIRTY_CONTENT)
end

function M.dirtyCheckCursor(ctx)
  return isDirty(ctx, DIRTY_CURSOR)
end

function M.getDirtyCursor(ctx)
  if M.isLogBufferValid(ctx.buf) then
    return vim.api.nvim_buf_get_var(ctx.buf, "jiejie_dirty_cursor") or { 1, 1 }
  end
  return { 1, 1 }
end

function M.dirtyClear(ctx)
  if M.isLogBufferValid(ctx.buf) then
    vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty", 0)
    vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty_cursor", nil)
  end
end

--- Mark buffer content as dirty to trigger a reload
--- @param ctx Context context
function M.dirtyMarkContent(ctx)
  if M.isLogBufferValid(ctx.buf) then
    setDirty(ctx, DIRTY_CONTENT)
  end
end

--- Mark cursor position as dirty to trigger a reload
--- @param ctx Context context
function M.dirtyMarkCursor(ctx)
  if setDirty(ctx, DIRTY_CURSOR) then
    vim.api.nvim_buf_set_var(ctx.buf, "jiejie_dirty_cursor", ctx.curpos)
  end
end

--- Render log output in buffer and return cursor position for current commit
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param headers? string[] headers added before the data
--- @return table
function M.logRender(ctx, data, headers)
  vim.api.nvim_set_option_value("modifiable", true, { buf = ctx.buf })
  vim.api.nvim_set_option_value("readonly", false, { buf = ctx.buf })
  if data[#data] == "" then
    data[#data] = nil
  end
  if headers ~= nil and #headers > 0 then
    vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, headers)
  end
  local headers_offset = headers and #headers or 0
  vim.api.nvim_buf_set_lines(ctx.buf, -1, -1, false, data)
  vim.api.nvim_set_option_value("readonly", true, { buf = ctx.buf })
  vim.api.nvim_set_option_value("modifiable", false, { buf = ctx.buf })
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
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
  local match = vim.regex("/.jj/repo/index$"):match_str(url)
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

--- Describe commit
--- @param force? boolean Edit immutable commits
--- @param firstline? boolean Edit just the first line
--- @return function
function M.commitDescribe(force, firstline)
  --- @param ctx Context context
  --- @param commit Commit Commit data
  return function(ctx, commit)
    -- get current description
    local res = jujutsu.cli(ctx, {
      "log",
      "--no-graph",
      "--no-pager",
      "--color",
      "never",
      "-r",
      commit.id,
      "-T",
      "description",
    })
    local data = vim.trim(res.stdout)
    local current_description = vim.split(data, "\n")
    -- edit description
    if firstline then
      return vim.schedule(function()
        vim.ui.input({ prompt = "Describe change (" .. commit.id .. "): ", default = current_description[1] }, function(input)
          if input == nil then
            return
          end
          local new_description = vim.list_extend({ vim.trim(input) }, vim.list_slice(current_description, 2, #current_description))
          jujutsu.cli(
            ctx,
            jujutsu.ignoreImmtuable({
              "describe",
              "-r",
              commit.id,
              "--stdin",
              "--no-edit",
              "--no-pager",
              "--quiet",
            }, force),
            {
              stdin = new_description,
            }
          )
          vim.cmd.e() -- reload buffer
        end)
      end)
    end
    -- Start dummy editor in the background
    local editor = jujutsu.createDummyEditor()
    local exec = jujutsu.cli(
      ctx,
      jujutsu.ignoreImmtuable({
        "describe",
        "--edit",
        "--no-pager",
        "--color",
        "never",
        "--quiet",
        -- "--debug",
        -- "-r",
        commit.id,
      }, force),
      {
        stdin = false,
        stdout = false,
        stderr = false,
        env = {
          EDITOR = editor.script,
        },
      },
      --- @param out vim.SystemCompleted
      function(out)
        -- cleanup remaining files
        editor.delete()
        -- trigger reload
        if out.code == 0 then
          vim.schedule(function()
            M.dirtyMarkCursor(M.logLoad(ctx))
            vim.cmd.doau("User JiejieDirtyCheck")
          end)
        else
          vim.schedule(function()
            vim.notify("Editing commit failed, maybe it's immutable!", vim.log.levels.ERROR)
          end)
        end
      end
    )
    -- wait for a maximum of 50msec * 100 = 5 sec for the editor to start
    local i = 1
    timer.setInterval(50, function(t)
      if i > 100 and vim.uv.os_getpriority(exec.pid) == nil then
        timer.clearInterval(timer)
        return
      end
      i = i + 1
      local file = editor.getEditedFile()
      if file then
        vim.print(vim.inspect(t))
        timer.clearInterval(t)
        vim.schedule(function()
          -- Open the file locally
          vim.cmd.sp(file)
          -- Clejnup dummy editor
          local bufId = vim.api.nvim_win_get_buf(0)
          vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufId })
          vim.api.nvim_create_autocmd({ "BufWipeout", "VimLeave" }, {
            buffer = bufId,
            callback = function(ev)
              editor.exit()
              -- exec:wait()
            end,
          })
        end)
      end
    end)
  end
end

-- support fast one line edits
--- Show help window
--- @param ctx Context context
function M.showHelp(ctx)
  vim.cmd.h("jiejie-maps")
end

return M
