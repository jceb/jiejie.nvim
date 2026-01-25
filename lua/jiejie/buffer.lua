local context = require("jiejie.context")
local parsers = require("jiejie.parsers")

--- Opeations that manipulate the buffer / window
local M = {}

--- Adjust the displayed number of revisions
--- @param fn fun(ctx: Context, count: number) Callback function
--- @param negate? boolean Negate count or pass it on as received
function M.with_count(fn, negate)
  --- @param ctx Context context
  return function(ctx)
    local count = vim.v.count ~= 0 and vim.v.count or 1
    fn(ctx, (negate and -1 or 1) * count)
  end
end

--- Provide repository context
--- @param root string Root directory of repository
--- @param fn fun(ctx: Context) Callback that is called with Context
--- @return function
function M.with_context(root, fn)
  return function()
    fn(context.get_context(root))
  end
end

--- Retrieve data about the change that the cursor is on
--- @param fn fun(ctx: Context, change: Change) Callback that is called with Context and the extracted change information. The function is only
---                    called when a change id is found at the cursor position
--- @param err_notify? boolean Send notification is change is not found
--- @return function
function M.with_change_at_position(fn, err_notify)
  --- @param ctx Context context
  return function(ctx)
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return nil
    end
    local pos = vim.api.nvim_win_get_cursor(winid)
    local line = vim.fn.getbufoneline(ctx.buf, pos[1])
    local change = parsers.parse_change(line)
    if change == nil then
      if err_notify then
        vim.notify("No change data found.", vim.log.levels.WARN)
      end
    else
      fn(ctx, change)
      return true
    end
  end
end

--- Retrieve data about the file name that the cursor is on
--- @param fn fun(ctx: Context, file?: ModifiedFile) Callback that is called with Context and the extracted file name
--- @param err_notify? boolean Send notification is change is not found
--- @param err_continue? boolean Continue execution callback execution on error
--- @return function
function M.with_filename_at_position(fn, err_notify, err_continue)
  --- @param ctx Context context
  return function(ctx)
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return nil
    end
    local pos = vim.api.nvim_win_get_cursor(winid)
    local line = vim.fn.getbufoneline(ctx.buf, pos[1])
    local file = parsers.parse_filename(line, pos[1])
    if file == nil and not err_continue then
      if err_notify then
        vim.notify("No file name found.", vim.log.levels.WARN)
      end
    else
      fn(ctx, file)
      return true
    end
  end
end

--- Request a target change ID
--- @param fn fun(ctx: Context, src_change: Change, dst_change?: Change) Callback that is called with Context and the extracted change information. The function is only
---                    called when a change id is found at the cursor position
--- @return function
function M.with_target_change_id(fn)
  --- @param ctx Context context
  --- @param src_change Change context
  return function(ctx, src_change)
    vim.ui.input({ prompt = "Target change (@-): " }, function(input)
      if input == nil then
        return
      end
      if input == "" then
        fn(ctx, src_change)
      else
        -- TODO: verify existence of id before passing it on + generate a proper Change object
        fn(ctx, src_change, { id = input, id_short = input })
      end
    end)
  end
end

--- Retrieve data about the change that the cursor is on
--- @param fn fun(ctx: Context, filname: string, change: Change) Callback that is called with Context and the extracted change information. The function is only
---                    called when a change id is found at the cursor position
--- @param err_notify? boolean Send notification is change is not found
--- @return function
function M.search_change_upwards(fn, err_notify)
  return function(ctx, filename)
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return nil
    end
    local lnr = vim.api.nvim_win_get_cursor(winid)[1] -- start search at the current line
    while lnr > 0 do
      local change = parsers.parse_change(vim.fn.getbufoneline(ctx.buf, lnr))
      if change then
        fn(ctx, filename, change)
        return true
      else
        lnr = lnr - 1
      end
    end
    if err_notify then
      vim.notify("No change data found.", vim.log.levels.WARN)
    end
  end
end

--- Tests validity of buffer, returns nil if buffer is not valid, otherwise the passed in buffer id
--- @param buf number Buffer ID
--- @return number?
function M.is_valid(buf)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
end

--- Create a header
--- @param key string Header key
--- @param value string Header value
function M.create_header(key, value)
  return key .. ": " .. value
end

--- Render log output in buffer and return cursor position of current change
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param headers? string[] headers added before the data
--- @return table
function M.render(ctx, data, headers)
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  if headers ~= nil and #headers > 0 then
    vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, vim.list_extend(headers, { "" }))
  end
  local headers_offset = headers and #headers or 0
  vim.api.nvim_buf_set_lines(ctx.buf, -1, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
  return ctx.curpos
end

--- Render file contents
--- @param ctx Context context
--- @param data string[] jj log output to display
function M.render_file(ctx, data)
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.focus(ctx, vertical)
  ctx.buf = M.is_valid(ctx.buf)
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
  M.setup_buffer(ctx)
  return ctx
end

--- Setup log buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.bo[ctx.buf].buftype = "nofile"
  -- vim.bo[ctx.buf].buftype = "nowrite"
  vim.bo[ctx.buf].modeline = false
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  vim.bo[ctx.buf].bufhidden = "delete"
  vim.bo[ctx.buf].filetype = "jiejie"
  vim.bo[ctx.buf].softtabstop = 4
  vim.bo[ctx.buf].tabstop = 4
  vim.bo[ctx.buf].undolevels = -1
  vim.bo[ctx.buf].swapfile = false
  local winid = vim.api.nvim_get_current_win()
  vim.wo[winid][0].number = false
  vim.wo[winid][0].relativenumber = false
  vim.wo[winid][0].conceallevel = 2
  vim.wo[winid][0].concealcursor = "nvic"
  vim.wo[winid][0].listchars = "tab:  "
  -- Place cursor on the current change
  if ctx.curpos ~= nil then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "a", "A", "c", "C", "d", "D", "i", "I", "r", "R", "s", "S", "x", "X", "p", "P" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  local commands = require("jiejie.commands")
  local with_root_context = function(fn)
    return M.with_context(ctx.root, fn)
  end
  --- @type table<number, {key: string, fn: fun(), desc: string}>
  local mappings = {
    {
      key = "<C-a>",
      fn = with_root_context(M.with_count(commands.log_revisions_adjust)),
      desc = "Increase the number of displayed log revisions",
    },
    {
      key = "<C-x>",
      fn = with_root_context(M.with_count(commands.log_revisions_adjust, true)),
      desc = "Decrease the number of displayed log revisions",
    },
    {
      key = "cc",
      fn = with_root_context(commands.show_diff),
      desc = "Commit currently edited change and create a new change",
    },
    {
      key = "cn",
      fn = with_root_context(M.with_change_at_position(commands.change_new)),
      desc = "Create a new change after the change under the cursor",
    },
    {
      key = "crc",
      fn = with_root_context(M.with_change_at_position(commands.change_revert)),
      desc = "Revert the commit under the cursor",
    },
    {
      key = "cs",
      fn = with_root_context(M.with_change_at_position(commands.change_squash)),
      desc = "Squash current changes into it's parent",
    },
    {
      key = "!cs",
      fn = with_root_context(M.with_change_at_position(function(ctx, change)
        commands.change_squash(ctx, change, nil, true)
      end)),
      desc = "Squash current changes into it's immutable parent",
    },
    {
      key = "cS",
      fn = with_root_context(M.with_change_at_position(M.with_target_change_id(commands.change_squash))),
      desc = "Squash current changes into the selecated change",
    },
    {
      key = "!cS",
      fn = with_root_context(M.with_change_at_position(M.with_target_change_id(function(ctx, src_change, dst_change)
        commands.change_squash(ctx, src_change, dst_change, true)
      end))),
      desc = "Squash current changes into the immutuable selecated change",
    },
    {
      key = "<CR>",
      fn = with_root_context(function(ctx)
        if not M.with_filename_at_position(M.search_change_upwards(commands.file_edit), false)(ctx) then
          M.with_change_at_position(commands.change_edit)(ctx)
        end
      end),
      desc = "Edit change or file under the cursor",
    },
    {
      key = "!<CR>",
      fn = with_root_context(function(ctx)
        if
          not M.with_filename_at_position(
            M.search_change_upwards(function(ctx, filename, change)
              commands.file_edit(ctx, filename, change, true)
            end),
            false
          )(ctx)
        then
          M.with_change_at_position(function(ctx, change)
            commands.change_edit(ctx, change, true)
          end)(ctx)
        end
      end),
      desc = "Edit immutable change or file under the cursor",
    },
    {
      key = "de",
      fn = with_root_context(M.with_change_at_position(function(ctx, change)
        commands.change_describe(ctx, change, false)
      end)),
      desc = "Edit change description",
    },
    {
      key = "!de",
      fn = with_root_context(M.with_change_at_position(function(ctx, change)
        commands.change_describe(ctx, change, true)
      end)),
      desc = "Edit immutable change description",
    },
    {
      key = "dd",
      fn = with_root_context(M.with_change_at_position(function(ctx, change)
        commands.change_describe(ctx, change, false, true)
      end)),
      desc = "Edit first line of change description",
    },
    {
      key = "!dd",
      fn = with_root_context(M.with_change_at_position(function(ctx, change)
        commands.change_describe(ctx, change, true, true)
      end)),
      desc = "Edit first line of an immutable change description",
    },
    {
      key = "p",
      fn = with_root_context(function(ctx)
        commands.cli(ctx, { "git", "fetch" })
      end),
      desc = "Fetch changes from remote",
    },
    {
      key = "P",
      fn = with_root_context(function(ctx)
        commands.cli(ctx, { "git", "push" })
      end),
      desc = "Push changes to remote",
    },
    {
      key = "X",
      fn = with_root_context(function(ctx)
        if not M.with_filename_at_position(M.search_change_upwards(commands.file_restore), false)(ctx) then
          M.with_change_at_position(commands.change_abandon)(ctx)
        end
      end),
      desc = "Abandon change or restore file from parent change",
    },
    {
      key = "!X",
      fn = with_root_context(function(ctx)
        if
          not M.with_filename_at_position(
            M.search_change_upwards(function(ctx, file, change)
              commands.file_restore(ctx, file, change, true)
            end),
            false
          )(ctx)
        then
          M.with_change_at_position(function(ctx, change)
            commands.change_abandon(ctx, change, true)
          end)(ctx)
        end
      end),
      desc = "Abandon immutuable change or restore file from parent change",
    },
    {
      key = "g?",
      fn = commands.show_help,
      desc = "Show help",
    },
  }
  for index, value in ipairs(mappings) do
    vim.keymap.set("n", value.key, value.fn, { desc = value.desc, buffer = true })
  end
  require("jiejie.buffer_dirty_check").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
