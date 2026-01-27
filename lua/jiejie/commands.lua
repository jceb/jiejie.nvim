local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local log_diff = require("jiejie.log_diff")
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
    local log_dirty_check = require("jiejie.log_dirty_check")
    log_dirty_check.dirty_mark_everything(ctx.buf)
    log_dirty_check.do_dirty_check()
  end
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
        local log_dirty_check = require("jiejie.log_dirty_check")
        log_dirty_check.dirty_mark_content(ctx.buf)
        log_dirty_check.do_dirty_check()
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
          callback = function()
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
M.CHANGE_STATUS = {
  CURRENT = "@",
  IMMUTABLE = "◆",
  CONFLICT = "×",
  MUTUABLE = "◇",
  HEAD = "○",
}

--- Notifu use if change is immutable and no force is applied
--- @param change Change current change
--- @param force? boolean Edit immutable change
--- @return boolean
local function notify_immutable(change, force)
  if change.status ~= M.CHANGE_STATUS.CURRENT and change.immutable and not force then
    vim.notify("Change is immutable, use force to modify it! ID: " .. change.id_short, vim.log.levels.ERROR)
    return true
  end
  return false
end

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
--- @field linenr number Line number in log buffer that contains change

--- @class ModificationType
M.MODIFICATION_TYPE = {
  DELETED = "D",
  MODIFIED = "M",
  ADDED = "A",
}

--- @class ModifiedFile
--- @field modification ModificationType Modification type
--- @field filename string File name
--- @field linenr number Line number in log buffer that contains filename

-- support fast one line edits
--- Show help window
--- @param ctx Context context
function M.show_help(ctx)
  vim.cmd.h("jiejie-maps")
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change data
function M.toggle_diff(ctx, file, change)
  -- TODO: reload diffs when buffer is marked dirty
  local files = {}
  if file then
    files = vim.list_extend(files, { file })
  else
    for linenr, line in ipairs(vim.fn.getbufline(ctx.buf, change.linenr + 1, "$")) do
      local f = parsers.parse_filename(line, change.linenr + linenr)
      if f then
        files = vim.list_extend(files, { f })
      end
      local ch = parsers.parse_change(line, change.linenr + linenr)
      if ch then
        break
      end
      linenr = linenr + 1
    end
  end
  -- walk backwards through the list of files to hide / show them
  local idx = #files
  while idx > 0 do
    local f = files[idx]
    if log_diff.diff_shown(f, change) then
      log_diff.diff_hide(ctx, f, change)
    else
      log_diff.diff_show(ctx, f, change)
    end
    idx = idx - 1
  end
  local winid = vim.api.nvim_get_current_win()
  local pos = vim.api.nvim_win_get_cursor(winid)
  local bufid = vim.api.nvim_win_get_buf(winid)
  if bufid == ctx.buf then
    if file then
      vim.api.nvim_win_set_cursor(winid, { file.linenr, pos[2] })
    else
      vim.api.nvim_win_set_cursor(winid, { change.linenr, pos[2] })
    end
  end
  return
end

--- Open or focus log window
--- @param ctx Context context
--- @param vertical? boolean If a new window needs to be created, split it vertically?
--- @return Context
function M.show_log(ctx, vertical)
  local buffer = require("jiejie.buffer")
  buffer.focus(ctx, vertical or false)
  return ctx
end

--- Abandon change
--- @param ctx Context context
--- @param change Change Change data
--- @param force? boolean Edit immutable change
function M.change_abandon(ctx, change, force)
  local args = { "abandon", change.id }
  jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
end

--- Create new change
--- @param ctx Context context
--- @param change Change Change data
function M.change_new(ctx, change)
  local args = { "new", change.id }
  jujutsu.cli(ctx, args, nil, reload_or_error(ctx, args[1]))
end

--- Commit changes
--- @param ctx Context context
function M.change_commit(ctx)
  start_dummy_editor(ctx, "commit")
end

--- Squash changes
--- @return function
--- @param ctx Context context
--- @param src_change Change Soruce change
--- @param dst_change? Change Destination change
--- @param force? boolean Edit immutable change
function M.change_squash(ctx, src_change, dst_change, force)
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

--- Edit change
--- @param ctx Context context
--- @param change Change current change
--- @param force? boolean Edit immutable change
function M.change_edit(ctx, change, force)
  if change.status == M.CHANGE_STATUS.CURRENT then
    vim.notify("Already editing change! ID: " .. change.id_short, vim.log.levels.INFO)
    return
  end
  if notify_immutable(change, force) then
    return
  end
  local args = { "edit", change.id }
  jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
end

--- Describe change
--- @param ctx Context context
--- @param change Change Change data
--- @param force? boolean Edit immutable change
--- @param firstline? boolean Edit just the first line
function M.change_describe(ctx, change, force, firstline)
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

--- Revert change
--- @param ctx Context context
--- @param change Change current change
--- @param force? boolean Edit immutable change
function M.change_revert(ctx, change, force)
  local args = { "revert", "-r", change.id, "-d", "@" }
  jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
end

--- Edit file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change to edit file at
--- @param force? boolean Edit immutable change
--- @return function
function M.file_edit(ctx, file, change, force)
  local filename = vim.fs.joinpath(ctx.root, file.filename)
  if change.status ~= M.CHANGE_STATUS.CURRENT then
    filename = "jiejie://" .. ctx.root .. "/.jj/" .. change.id .. "/" .. file.filename
  end
  local winid = vim.api.nvim_get_current_win()
  local winid_new
  local bufid = vim.api.nvim_get_current_buf()
  if vim.bo[bufid].filetype == "jiejie" then
    vim.cmd.wincmd("p")
    winid_new = vim.api.nvim_get_current_win()
  end
  if winid_new == winid then
    vim.cmd.sp(filename)
  else
    vim.cmd.e(filename)
  end
end

--- Restore file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change to edit file at
--- @param force? boolean Change immutable
function M.file_restore(ctx, file, change, force)
  if change.status ~= M.CHANGE_STATUS.CURRENT then
    vim.notify("Restore is only implemented for the currently edited change", vim.log.levels.ERROR)
  end
  local args = { "restore", "-f", "@-", file.filename }
  jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force), nil, reload_or_error(ctx, args[1]))
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
--- @param ctx Context context
--- @param adjustment? integer Adjust the number of displayed log revisions by this amount
function M.log_revisions_adjust(ctx, adjustment)
  local log_revisions = (ctx.log_revisions or 10) + adjustment
  ctx.log_revisions = log_revisions > 0 and log_revisions or 1
  context.set_context(ctx)
  local log_dirty_check = require("jiejie.log_dirty_check")
  log_dirty_check.dirty_mark_content(ctx.buf)
  log_dirty_check.do_dirty_check()
end

--- Command executes jj commands, returns exit code
--- @param ctx Context context
--- @param fargs string[] List of CLI arguments
--- @return table
function M.cli(ctx, fargs)
  local printer = function(err, data)
    if data then
      if err then
        vim.notify(data, vim.log.levels.ERROR)
      else
        -- vim.notify(data, vim.log.levels.INFO)
        print(data)
      end
    end
  end
  return jujutsu.cli(ctx, fargs, {
    stdout = vim.schedule_wrap(printer),
    stderr = vim.schedule_wrap(printer),
  }, reload_or_error(ctx, fargs[1]))
end

--- Configure commands
function M.setup()
  local cmd_jj = function(args)
    if #args.fargs == 0 then
      M.show_log(context.get_context(), args.smods.vertical)
    else
      M.cli(context.get_context(), args.fargs)
    end
  end
  local cmd_jedit = function(args)
    local object = {}
    if #args.fargs > 0 then
      object = parsers.parse_object(args.fargs[1]) or {}
    end
    object.filename = vim.fn.fnamemodify(object and object.filename and object.filename ~= "" and object.filename or vim.fn.expand("%"), ":p")
    local root
    local path
    if vim.startswith(object.filename, "jiejie://") then
      -- special handling for calling Jedit on a file name that is a jiejie URL
      local res = parsers.parse_url(object.filename)
      root = res.root
      path = res.path
      object.filename = vim.fs.joinpath(root, path)
    else
      local directory = vim.fn.fnamemodify(object.filename, ":h")
      root = jujutsu.get_root(directory)
    end
    local ctx = context.get_context(root)
    if not vim.startswith(object.filename, ctx.root) then
      error("Unable to determine jj root directory")
    end
    if not path then
      path = vim.fn.trim(vim.fn.strpart(object.filename, #ctx.root), "/", 1)
    end
    -- hacky construction of the exact data that's required for file_edit
    M.file_edit(ctx, { filename = path }, {
      id = object.change_id and object.change_id or "@",
      status = object.change_id and object.change_id ~= "@" and M.CHANGE_STATUS.IMMUTABLE or M.CHANGE_STATUS.CURRENT,
    })
  end
  local cmdOpts = { desc = "Jujutsu command wrapper - shows log when no argument is provided", nargs = "*", range = 2 }
  -- TODO: define command only for buffers that are related to a repository
  if vim.fn.exists(":J") ~= 2 then
    vim.api.nvim_create_user_command("J", cmd_jj, cmdOpts)
  end
  vim.api.nvim_create_user_command("Jj", cmd_jj, cmdOpts)
  vim.api.nvim_create_user_command("Jedit", cmd_jedit, { desc = ":edit a jiejie-object", nargs = "?" })
  local id = vim.api.nvim_create_augroup("Jiejie", {})
  require("jiejie.log").setup(id)
  require("jiejie.log_dirty_check").setup()
end

return M
