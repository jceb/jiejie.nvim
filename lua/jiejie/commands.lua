local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local log_diff = require("jiejie.log_diff")
local parsers = require("jiejie.parsers")
local timer = require("jiejie.timer")

--- Start dummy editor in the background
--- @param ctx Context context
--- @param cmd string JJ command
--- @param args? string[] List of additional arguments
--- @param opts? {force?: boolean, on_exit?: fun(out: vim.SystemCompleted)} Options
--- - force Modify immutable change
--- - on_exit Modify immutable change
local function start_dummy_editor(ctx, cmd, args, opts)
  local lopts = opts or {}
  local editor = jujutsu.create_dummy_editor()
  local exec = jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(
      vim.list_extend({
        "--quiet",
        -- "--debug",
      }, args or {}),
      { force = lopts.force }
    ),
    sys_opts = {
      stdout = false,
      stderr = false,
      env = {
        EDITOR = editor.script,
      },
    },
    --- @param out vim.SystemCompleted
    on_exit = function(out)
      -- cleanup remaining files
      editor.delete()
      if out.code == 0 then
        local log_dirty_check = require("jiejie.log_dirty_check")
        log_dirty_check.dirty_mark_content(ctx.buf)
        log_dirty_check.do_dirty_check()
      elseif not lopts.on_exit then
        vim.schedule(function()
          vim.notify("Modifying change failed, maybe it's immutable!", vim.log.levels.ERROR)
        end)
      end
      if lopts.on_exit then
        lopts.on_exit(out)
      end
    end,
  })
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
        vim.api.nvim_create_autocmd({ "BufWipeout", "VimLeave" }, { buffer = bufId, callback = editor.exit })
      end)
    end
  end)
end

--- Commands that manipulate the log
local M = {}

--- Reload buffer or error
--- @param ctx Context context
--- @param cmd string Command name that failed
--- @param opts? {err_notify?: boolean, err_continue?: boolean, on_exit?: fun(out: vim.SystemCompleted)} Options
--- - on_exit Callback function is executed in a scheduled context
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- @return fun(out: vim.SystemCompleted)
function M.reload_or_error(ctx, cmd, opts)
  --- @param out vim.SystemCompleted
  return function(out)
    local lopts = opts or {}
    if out.code ~= 0 and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.schedule(function()
          vim.notify("Command failed with non-zero exit code: " .. out.code .. "\n\t jj" .. cmd, vim.log.levels.ERROR)
        end)
        return
      end
    end
    local log_dirty_check = require("jiejie.log_dirty_check")
    log_dirty_check.dirty_mark_everything(ctx.buf)
    log_dirty_check.do_dirty_check()
    vim.schedule(function()
      vim.cmd.checktime() -- align vim's buffer status with the file system
      if lopts.on_exit then
        lopts.on_exit(out)
      end
    end)
  end
end

--- @class ChangeStatus
M.CHANGE_STATUS = {
  CURRENT = "@",
  IMMUTABLE = "◆",
  CONFLICT = "×",
  MUTUABLE = "◇",
  HEAD = "○",
}

--- Notify if change is immutable and no force is applied
--- @param change Change current change
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
--- @return boolean
local function notify_immutable(change, opts)
  local lopts = opts or {}
  if change.status ~= M.CHANGE_STATUS.CURRENT and change.immutable and not lopts.force then
    vim.notify("Change `" .. change.id_short .. "` is immutable, use force to modify it!", vim.log.levels.ERROR)
    return true
  end
  return false
end

--- @class Change
--- @field status ChangeStatus Change status, one of @ (current change), × (conflict), ◆ (root), ○ (regular change)
--- @field id string change ID
--- @field id_short string Short change ID
--- @field empty boolean It's an empty change
--- @field description_first_line string First line of description
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

--- Show help window
function M.show_help()
  vim.cmd.h("jiejie-maps")
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {file?: ModifiedFile} Options
--- - file File name
function M.toggle_diff(ctx, change, opts)
  local lopts = opts or {}
  local files = {}
  if lopts.file then
    files = vim.list_extend(files, { lopts.file })
  else
    ---@diagnostic disable-next-line: param-type-mismatch
    for idx, line in ipairs(vim.fn.getbufline(ctx.buf, change.linenr + 1, "$")) do
      local f = parsers.parse_filename(line, change.linenr + idx)
      if f then
        files = vim.list_extend(files, { f })
      end
      local ch = parsers.parse_change(line, change.linenr + idx)
      if ch then
        break
      end
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
    if lopts.file then
      vim.api.nvim_win_set_cursor(winid, { lopts.file.linenr, pos[2] })
    else
      vim.api.nvim_win_set_cursor(winid, { change.linenr, pos[2] })
    end
  end
  return true
end

--- Open or focus log window
--- @param ctx Context context
--- @param opts? {vertical?: boolean} Options
--- - vertical If a new window needs to be created, split it vertically?
--- @return Context
function M.show_log(ctx, opts)
  local lopts = opts or {}
  local buffer = require("jiejie.buffer")
  buffer.focus(ctx, lopts.vertical or false)
  return ctx
end

--- Abandon change
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
function M.change_abandon(ctx, change, opts)
  local lopts = opts or {}
  local cmd = "abandon"
  local args = { change.id }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Change `" .. change.id_short .. "` abandoned", vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Create new change
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
function M.change_new(ctx, change, opts)
  local lopts = opts or {}
  local cmd = "new"
  local args = { change.id }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("New change created", vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Commit changes
--- @param ctx Context context
--- @param opts? {files?: string[]} Options
--- - files List of file names relative to the root of the repository
function M.change_commit(ctx, opts)
  local lopts = opts or {}
  local cmd = "commit"
  local args = lopts.files or {}
  start_dummy_editor(ctx, cmd, args, {
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Change commited", vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Squash changes
--- @param ctx Context context
--- @param src_change Change Soruce change
--- @param opts? {dst_change?: Change, files?: string[], force?: boolean} Options
--- - dst_change Destination change
--- - files List of file names relative to the root of the repository
--- - force Edit immutable change
function M.change_squash(ctx, src_change, opts)
  local lopts = opts or {}
  local args = vim.list_extend({ lopts.dst_change and "-f" or "-r", src_change.id }, lopts.files or {})
  if notify_immutable(src_change, { force = lopts.force }) then
    return
  end
  local dst = "it's parent"
  if lopts.dst_change then
    args = vim.list_extend(args, { "-t", lopts.dst_change.id })
    dst = lopts.dst_change.id_short
  end
  local cmd = "squash"
  start_dummy_editor(ctx, cmd, args, {
    force = lopts.force,
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Squashed change " .. src_change.id_short .. " into " .. dst, vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Edit change
--- @param ctx Context context
--- @param change Change current change
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
function M.change_edit(ctx, change, opts)
  local lopts = opts or {}
  if change.status == M.CHANGE_STATUS.CURRENT then
    vim.notify("Already editing change `" .. change.id_short .. "`", vim.log.levels.INFO)
    return
  end
  if notify_immutable(change, { force = lopts.force }) then
    return
  end
  local cmd = "edit"
  local args = { change.id }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Editing change " .. change.id_short, vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Describe change
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {force?: boolean, firstline?: boolean} Options
--- - force: Edit immutable change
--- - firstline: Edit just the first line
--- @return boolean?
function M.change_describe(ctx, change, opts)
  local lopts = opts or {}
  if notify_immutable(change, { force = lopts.force }) then
    return
  end
  -- get current description
  local cmd_log = "log"
  local args = { "--no-graph", "-r", change.id, "-T", "description" }
  local res = jujutsu.cli(ctx, cmd_log, { args = args })
  local data = vim.trim(res.stdout)
  local current_description = vim.split(data, "\n")
  -- edit description
  if lopts.firstline then
    vim.schedule(function()
      vim.ui.input({ prompt = "Describe change (" .. change.id_short .. "): ", default = current_description[1] }, function(input)
        if input == nil then
          return
        end
        local new_description = vim.list_extend({ vim.trim(input) }, vim.list_slice(current_description, 2, #current_description))
        local cmd = "describe"
        jujutsu.cli(ctx, cmd, {
          args = jujutsu.ignore_immtuable({
            "-r",
            change.id,
            "--stdin",
            "--no-edit",
            "--quiet",
          }, { force = lopts.force }),
          sys_opts = {
            stdin = new_description,
          },
          on_exit = M.reload_or_error(
            ctx,
            table.concat(vim.list_extend({ cmd }, args), " "),
            vim.tbl_extend("force", lopts, {
              on_exit = function()
                vim.notify("Described change " .. change.id_short, vim.log.levels.INFO)
              end,
            })
          ),
        })
      end)
    end)
    return true
  end
  start_dummy_editor(ctx, "describe", { "--edit", change.id }, { force = lopts.force })
  return true
end

--- Revert change
--- @param ctx Context context
--- @param change Change current change
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
--- @return boolean?
function M.change_revert(ctx, change, opts)
  local lopts = opts or {}
  local cmd = "revert"
  local args = { "-r", change.id, "-d", "@" }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Reverted change " .. change.id_short, vim.log.levels.INFO)
        end,
      })
    ),
  })
  return true
end

--- Edit file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change to edit file at
--- @param opts? {previous_win?: boolean, edit_cmd?: fun(filename: string), hunk?: Hunk}
--- - previous_win: Navigate to previous window or split a new window before edting file, when current buffer is the log buffer
--- - edit_cmd: Function that's called for editing file
--- @return boolean?
function M.file_edit(ctx, file, change, opts)
  local lopts = opts or {}
  lopts.edit_cmd = lopts.edit_cmd or vim.cmd.e
  local filename = vim.fs.joinpath(ctx.root, file.filename)
  if change.status ~= M.CHANGE_STATUS.CURRENT then
    filename = parsers.join_url({
      root = ctx.root,
      revision = change.id,
      path = file.filename,
    })
  end
  local winid = vim.api.nvim_get_current_win()
  local winid_new
  local bufid = vim.api.nvim_get_current_buf()
  if lopts.previous_win and bufid == ctx.buf then
    vim.cmd.wincmd("p")
    winid_new = vim.api.nvim_get_current_win()
  end
  if winid_new == winid then
    vim.cmd.new()
  end
  lopts.edit_cmd(filename)
  if lopts.hunk then
    -- When hunk is set, the cursor needs to be positioned relatively on the exact line from the hunk
    -- Due to the use of BufReadCmd for Jiejie file, we're not able to set the cursor position here - the file just
    -- hasn't loaded yet. Therefore, create a temporary autocommand that will do the job
    local _bufid = vim.api.nvim_get_current_buf()
    ---@diagnostic disable-next-line: param-type-mismatch
    local cursor_line = lopts.hunk.start_line + lopts.hunk.cursor_offset
    -- local lines = #(vim.fn.getbufline(_bufid, 1, "$"))
    -- if lines >= cursor_line then
    if not vim.startswith(filename, "jiejie://") then
      vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { cursor_line, 0 })
    else
      local id
      id = vim.api.nvim_create_autocmd("BufReadPost", {
        buffer = _bufid,
        callback = function(ev)
          vim.api.nvim_del_autocmd(id)
          vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { cursor_line, 0 })
        end,
      })
    end
  end
  return true
end

--- Restore file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change to edit file at
--- @param opts? {force?: boolean} Options
--- - force Change immutable
--- @return boolean?
function M.file_restore(ctx, file, change, opts)
  local lopts = opts or {}
  if change.status ~= M.CHANGE_STATUS.CURRENT then
    vim.notify("Restore is only implemented for the currently edited change", vim.log.levels.ERROR)
  end
  local cmd = "restore"
  local args = { "-f", "@-", file.filename }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Restored file " .. file.filename, vim.log.levels.INFO)
        end,
      })
    ),
  })
  return true
end

--- Open or focus log window
--- @param ctx Context context
--- @param callback fun(ctx: Context?) Asynchronous callback
--- @return boolean?
function M.reload_log(ctx, callback)
  if vim.api.nvim_get_current_buf() ~= ctx.buf then
    callback(nil)
  end
  require("jiejie.log").load(ctx, callback)
  return true
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param opts? {adjustment?: number} Options
--- - adjustment Adjust the number of displayed log revisions by this amount
function M.log_revisions_adjust(ctx, opts)
  local lopts = opts or {}
  local log_revisions = (ctx.log_revisions or 10) + lopts.adjustment
  ctx.log_revisions = log_revisions > 0 and log_revisions or 1
  context.set_context(ctx)
  local log_dirty_check = require("jiejie.log_dirty_check")
  log_dirty_check.dirty_mark_content(ctx.buf)
  log_dirty_check.do_dirty_check()
end

--- Command executes jj commands, returns exit code
--- @param ctx Context context
--- @param cmd string List of CLI arguments
--- @param opts? {on_exit?: fun(out: vim.SystemCompleted), args: string[]} Options
--- - on_exit Callback function is executed in a scheduled context
--- - args string[] List of CLI arguments
--- @return table
function M.cli(ctx, cmd, opts)
  local lopts = opts or {}
  local output = ""
  local output_collector = function(_, data)
    if data then
      output = output .. "\n" .. data
    end
  end
  return jujutsu.cli(ctx, cmd, {
    args = lopts.args,
    sys_opts = {
      stdout = output_collector,
      stderr = output_collector,
    },
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, lopts.args), " "),
      vim.tbl_extend("keep", lopts, {
        on_exit = vim.schedule_wrap(function()
          vim.notify(output, vim.log.levels.INFO)
        end),
      })
    ),
  })
end

--- Configure commands
function M.setup()
  local cmd_jj = function(args)
    if #args.fargs == 0 then
      M.show_log(context.get_context(), args.smods.vertical)
    else
      M.cli(context.get_context(), args.fargs[1], { args = vim.list_slice(args.fargs, 2) })
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
      local url = parsers.parse_url(object.filename)
      if not url then
        error("Unknown URL: " .. object.filename)
      end
      if not url.path then
        error("Path not specified in URL: " .. object.filename)
      end
      object.filename = vim.fs.joinpath(url.root, url.path)
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
    ---@diagnostic disable-next-line: missing-fields
    M.file_edit(ctx, { filename = path }, {
      id = object.change_id and object.change_id or "@",
      ---@diagnostic disable-next-line: assign-type-mismatch
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
