local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local parsers = require("jiejie.parsers")
local timer = require("jiejie.timer")

--- Reload buffer or error
--- @param ctx Context context
--- @param cmd string Command name that failed
--- @return fun(out: vim.SystemCompleted)
local function reload_or_error(ctx, cmd)
  --- @param out vim.SystemCompleted
  return function(out)
    if out and out.code ~= 0 then
      error("jj " .. cmd .. " failed with non-zero exit code: " .. out.code)
    end
    local buffer_dirty_check = require("jiejie.buffer_dirty_check")
    buffer_dirty_check.dirty_mark_everything(ctx.buf)
    buffer_dirty_check.do_dirty_check()
  end
end

--- Notifu use if change is immutable and no force is applied
--- @param change Change current change
--- @param force? boolean Edit immutable change
--- @return boolean
local function notify_immutable(change, force)
  if change.immutable and not force then
    vim.notify("Change is immutable, use force to modify it! ID: " .. change.id_short, vim.log.levels.ERROR)
    return true
  end
  return false
end

--- @param ctx Context context
--- @param cmd string JJ command
--- @param args? string[] List of additional arguments
--- @param force? boolean Modify immutable change
--- @param callback? fun(out: vim.SystemCompleted) Modify immutable change
local function start_dummy_editor(ctx, cmd, args, force, callback)
  -- Start dummy editor in the background
  local editor = jujutsu.create_dummy_editor()
  local exec = jujutsu.cli(
    ctx,
    jujutsu.ignore_immtuable(
      vim.list_extend(
        vim.list_extend({ cmd }, {
          "--quiet",
          -- "--debug",
        }),
        args or {}
      ),
      force
    ),
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
      if out.code == 0 then
        local buffer_dirty_check = require("jiejie.buffer_dirty_check")
        buffer_dirty_check.dirty_mark_content(ctx.buf)
        buffer_dirty_check.do_dirty_check()
      elseif not callback then
        vim.schedule(function()
          vim.notify("Modifying change failed, maybe it's immutable!", vim.log.levels.ERROR)
        end)
      end
      if callback then
        callback(out)
      end
    end
  )
  -- wait for a maximum of 50msec * 100 = 5 sec for the editor to start
  local i = 1
  timer.set_interval(50, function(t)
    if i > 100 and vim.uv.os_getpriority(exec.pid) == nil then
      timer.clear_interval(t)
      return
    end
    i = i + 1
    local file = editor.get_edited_file()
    if file then
      timer.clear_interval(t)
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
          end,
        })
      end)
    end
  end)
end

--- Commands that manipulate the log
local M = {}

--- @class ChangeStatus
local CHANGE_STATUS = {
  CURRENT = "@",
  IMMUTABLE = "◆",
  CONFLICT = "×",
  MUTUABLE = "◇",
  HEAD = "○",
}

--- @class Change
--- @field status ChangeStatus Change status, one of @ (current change), × (conflict), ◆ (root), ○ (regular change)
--- @field id string change ID
--- @field id_short string Short change ID
--- @field empty boolean It's an empty change
--- @field description_shortened string Description, truncated first line
--- @field bookmarks string[] Bookmarks
--- @field tags string[] Tags
--- @field git_head boolean Git head is on this change
--- @field conflict boolean Change is in a state of conflict
--- @field immutable boolean Change is immutable

--- @class ModificationType
M.MODIFICATION_TYPE = {
  DELETED = "D",
  MODIFIED = "M",
  ADDED = "A",
}

--- @class ModifiedFile
--- @field modification ModificationType Modification type
--- @field filename string File name

--- Provide repository context
--- @param root string Root directory of repository
--- @param fn fun(ctx: Context) Callback that is called with Context
--- @return function
function M.with_context(root, fn)
  return function(x)
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
--- @param ctx Context context
--- @param fn fun(ctx: Context, file: ModifiedFile) Callback that is called with Context and the extracted file name
--- @param err_notify? boolean Send notification is change is not found
--- @return function
function M.with_filename_at_position(ctx, fn, err_notify)
  return function()
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return nil
    end
    local pos = vim.api.nvim_win_get_cursor(winid)
    local filename = parsers.parse_filename(vim.fn.getbufoneline(ctx.buf, pos[1]))
    if filename == nil then
      if err_notify then
        vim.notify("No file name found.", vim.log.levels.WARN)
      end
    else
      fn(ctx, filename)
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
    local lnr = vim.api.nvim_win_get_cursor(winid)[1] - 1 -- start search above the current line
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

-- support fast one line edits
--- Show help window
--- @param ctx Context context
function M.show_help(ctx)
  vim.cmd.h("jiejie-maps")
end

--- Open or focus log window
--- @param root? string Root directory of repository
--- @param vertical? boolean If a new window needs to be created, split it vertically?
--- @return Context
function M.show_log(root, vertical)
  local buffer = require("jiejie.buffer")
  local ctx = context.get_context(root)
  buffer.focus(ctx, vertical or false)
  return ctx
end

--- Abandon change
--- @return function
function M.change_abandon()
  --- @param ctx Context context
  --- @param change Change Change data
  return function(ctx, change)
    local args = { "abandon", change.id }
    jujutsu.cli(ctx, args, nil, reload_or_error(ctx, args[1]))
  end
end

--- Create new change
--- @return function
function M.change_new()
  --- @param ctx Context context
  --- @param change Change Change data
  return function(ctx, change)
    local args = { "new", change.id }
    jujutsu.cli(ctx, args, nil, reload_or_error(ctx, args[1]))
  end
end

--- Commit changes
--- @return function
function M.change_commit()
  --- @param ctx Context context
  return function(ctx)
    start_dummy_editor(ctx, "commit")
  end
end

--- Squash changes
--- @return function
function M.change_squash(force)
  --- @param ctx Context context
  --- @param src_change Change Soruce change
  --- @param dst_change? Change Destination change
  return function(ctx, src_change, dst_change)
    local args = { dst_change and "-f" or "-r", src_change.id }
    local dst = "it's parent"
    if dst_change then
      args = vim.list_extend(args, { "-t", dst_change.id })
      dst = dst_change.id_short
    end
    start_dummy_editor(
      ctx,
      "squash",
      args,
      force,
      vim.schedule_wrap(function(out)
        vim.notify("Squashed change " .. src_change.id_short .. " into " .. dst, vim.log.levels.INFO)
      end)
    )
  end
end

--- Edit change
--- @param force? boolean Edit immutable change
--- @return function
function M.change_edit(force)
  --- @param ctx Context context
  --- @param change Change current change
  return function(ctx, change)
    if change.status == CHANGE_STATUS.CURRENT then
      vim.notify("Already editing change! ID: " .. change.id_short, vim.log.levels.INFO)
      return
    end
    if notify_immutable(change, force) then
      return
    end
    local args = { "edit", change.id }
    jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
  end
end

--- Describe change
--- @param force? boolean Edit immutable change
--- @param firstline? boolean Edit just the first line
--- @return function
function M.change_describe(force, firstline)
  --- @param ctx Context context
  --- @param change Change Change data
  return function(ctx, change)
    if notify_immutable(change, force) then
      return
    end
    -- get current description
    local res = jujutsu.cli(ctx, {
      "log",
      "--no-graph",
      "-r",
      change.id,
      "-T",
      "description",
    })
    local data = vim.trim(res.stdout)
    local current_description = vim.split(data, "\n")
    -- edit description
    if firstline then
      return vim.schedule(function()
        vim.ui.input({ prompt = "Describe change (" .. change.id_short .. "): ", default = current_description[1] }, function(input)
          if input == nil then
            return
          end
          local new_description = vim.list_extend({ vim.trim(input) }, vim.list_slice(current_description, 2, #current_description))
          jujutsu.cli(
            ctx,
            jujutsu.ignore_immtuable({
              "describe",
              "-r",
              change.id,
              "--stdin",
              "--no-edit",
              "--quiet",
            }, force),
            {
              stdin = new_description,
            },
            reload_or_error(ctx, "describe")
          )
        end)
      end)
    end
    start_dummy_editor(ctx, "describe", { "--edit", change.id }, force)
  end
end

--- Revert change
--- @param force? boolean Edit immutable change
--- @return function
function M.change_revert(force)
  --- @param ctx Context context
  --- @param change Change current change
  return function(ctx, change)
    local args = { "revert", "-r", change.id, "-d", "@" }
    jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
  end
end

--- Edit file
--- @param force? boolean Edit immutable change
--- @return function
function M.file_edit(force)
  --- @param ctx Context context
  --- @param file ModifiedFile File name
  --- @param change Change Change to edit file at
  return function(ctx, file, change)
    local filename = vim.fs.joinpath(ctx.root, file.filename)
    if change.status ~= CHANGE_STATUS.CURRENT then
      filename = "jiejie://" .. ctx.root .. "/.jj/" .. change.id .. "/" .. file.filename
    end
    local winid = vim.api.nvim_get_current_win()
    vim.cmd.wincmd("p")
    local winid_new = vim.api.nvim_get_current_win()
    if winid_new == winid then
      vim.cmd.sp(filename)
    else
      vim.cmd.e(filename)
    end
  end
end

--- Restore file
--- @param force? boolean Change immutable
--- @return function
function M.file_restore(force)
  --- @param ctx Context context
  --- @param file ModifiedFile File name
  --- @param change Change Change to edit file at
  return function(ctx, file, change)
    local filename = vim.fs.joinpath(ctx.root, file.filename)
    if change.status ~= CHANGE_STATUS.CURRENT then
      vim.notify("Restore is only implemented for the currently edited change", vim.log.levels.ERROR)
    end
    local args = { "restore", "-f", "@-", file.filename }
    jujutsu.cli(ctx, args, nil, reload_or_error(ctx, args[1]))
  end
end

--- Open or focus log window
--- @param ctx Context context
--- @param callback fun(ctx: Context?) Asynchronous callback
function M.reload_log(ctx, callback)
  if vim.api.nvim_get_current_buf() ~= ctx.buf then
    callback(nil)
  end
  require("jiejie.log").load(ctx, callback)
end

--- Adjust the displayed number of revisions
--- @param fn fun(ctx: Context, count: number) Callback function
--- @param negate boolean Negate count or pass it on as received
function M.with_count(fn, negate)
  --- @param ctx Context context
  return function(ctx)
    local count = vim.v.count ~= 0 and vim.v.count or 1
    fn(ctx, (negate and -1 or 1) * count)
  end
end

--- Adjust the displayed number of revisions
function M.log_revisions_adjust()
  --- @param ctx Context context
  --- @param adjustment? integer Adjust the number of displayed log revisions by this amount
  return function(ctx, adjustment)
    local log_revisions = (ctx.log_revisions or 10) + adjustment
    ctx.log_revisions = log_revisions > 0 and log_revisions or 1
    context.set_context(ctx)
    local buffer_dirty_check = require("jiejie.buffer_dirty_check")
    buffer_dirty_check.dirty_mark_everything(ctx.buf)
    buffer_dirty_check.do_dirty_check()
  end
end

--- Command executes jj commands, returns exit code
--- @param fargs string[] List of CLI arguments
--- @param error_on_failure? boolean Throws an error if command fails, default false
--- @param root? string Root directory of repository, determined automatically by the current buffer if not provided
--- @return table
function M.cli(fargs, error_on_failure, root)
  local ctx = context.get_context(root)
  local printer = function(err, data)
    if data then
      if err then
        vim.notify(data, vim.log.levels.ERROR)
      else
        vim.notify(data, vim.log.levels.INFO)
      end
    end
  end
  jujutsu.cli(ctx, fargs, {
    stdout = vim.schedule_wrap(printer),
    stderr = vim.schedule_wrap(printer),
  }, reload_or_error(ctx, fargs[1]))
end

--- Configure commands
function M.setup()
  local cmd = function(args)
    if #args.fargs == 0 then
      M.show_log(nil, args.smods.vertical)
    else
      M.cli(args.fargs)
    end
  end
  local cmdOpts = { desc = "Jujutsu command wrapper - shows log when no argument is provided", nargs = "*", range = 2 }
  if vim.fn.exists(":J") ~= 2 then
    vim.api.nvim_create_user_command("J", cmd, cmdOpts)
  end
  vim.api.nvim_create_user_command("Jj", cmd, cmdOpts)
  local id = vim.api.nvim_create_augroup("Jiejie", {})
  require("jiejie.log").setup(id)
  require("jiejie.buffer_dirty_check").setup()
end

return M
