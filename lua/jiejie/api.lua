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
  assert(ctx, "Context not provided: ctx")
  assert(cmd, "Command not provided: cmd")
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

--- Get the correct change ID if case the commit diverges
--- @param change Change Change
--- @param short? boolean Whether to return the short ID
function M.get_change_id(change, short)
  assert(change, "Change not provided: change")
  return change.divergent and change.commit_id or (short and change.id_short or change.id)
end

--- Constructs a change based on a id. Attention: the change is incomplete and you might run into issues using it!
--- Know what you're doing!
--- @param change_id string Change ID, e.g. "@"
--- @return Change
function M.construct_dummy_change(change_id)
  assert(change_id and change_id ~= "", "Change ID empty")
  return {
    id = change_id,
    id_short = change_id,
    commit_id = change_id,
    current_working_copy = change_id == "@",
    empty = false,
    description_first_line = "",
    bookmarks = {},
    tags = {},
    git_head = false,
    conflict = false,
    immutable = change_id ~= "@" and false or true,
    email = "",
    linenr = 0,
    divergent = false,
    parents = 1,
  }
end

--- Get the list of ancestors for a change
--- @param ctx Context context
--- @param change Change Change
--- @return Change[]
function M.get_ancestors(ctx, change)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local log = require("jiejie.log")
  local cmd = "log"
  local args = { "-r", M.get_change_id(change) .. "-", "-T", log.template }
  local res = jujutsu.cli(ctx, cmd, { args = args })
  local ancestors = {}
  local log_lines = vim.split(vim.trim(res.stdout), "\n")
  for _, line in ipairs(log_lines) do
    local parent = parsers.parse_change(line, 0)
    if parent then
      table.insert(ancestors, parent)
    end
  end
  return ancestors
end

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
    assert(ctx, "Context not provided: ctx")
    assert(cmd, "Command not provided: cmd")
    local lopts = opts or {}
    if out.code ~= 0 and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.schedule(function()
          vim.notify("Command failed with non-zero exit code: " .. out.code .. "\n\tjj " .. cmd, vim.log.levels.ERROR)
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

--- @enum ChangeStatus
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
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  if not change.current_working_copy and change.immutable and not lopts.force then
    vim.notify("Change `" .. M.get_change_id(change, true) .. "` is immutable, use force to modify it!", vim.log.levels.ERROR)
    return false
  end
  return false
end

--- @class Change
--- @field status ChangeStatus Change status, one of @ (current change), × (conflict), ◆ (root), ○ (regular change)
--- @field id string Change ID
--- @field id_short string Short change ID
--- @field empty boolean It's an empty change
--- @field description_first_line string First line of description
--- @field bookmarks string[] Bookmarks
--- @field tags string[] Tags
--- @field git_head boolean Git head is on this change
--- @field conflict boolean Change is in a state of conflict
--- @field immutable boolean Change is immutable
--- @field email string Author's email address
--- @field linenr number Line number in log buffer that contains change
--- @field divergent boolean Change ID corresponds to multiple commits
--- @field commit_id string Commit ID
--- @field current_working_copy boolean True for the working-copy commit that matches the current commit
--- @field parents number Number of parent commits

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
--- @param topic string Jiejie help topic
function M.show_help(topic)
  vim.cmd.h("jiejie-" .. (topic or "maps"))
end

--- Adjust the displayed number of revisions
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {file?: ModifiedFile} Options
--- - file File name
function M.toggle_diff(ctx, change, opts)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
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
  assert(ctx, "Context not provided: ctx")
  local lopts = opts or {}
  local buffer = require("jiejie.log_buffer")
  buffer.focus(ctx, lopts.vertical or false)
  return ctx
end

--- Abandon change
--- @param ctx Context context
--- @param change Change Change data
--- @param bookmark string Name of bookmark
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
function M.bookmark_move(ctx, change, bookmark, opts)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  assert(bookmark and bookmark ~= "", "Bookmark not provided: bookmark")
  local lopts = opts or {}
  local cmd = "bookmark"
  local args = { "move", bookmark, "-t", M.get_change_id(change) }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.allow_backwards(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Bookmark " .. bookmark .. " moved to change " .. M.get_change_id(change, true), vim.log.levels.INFO)
        end,
      })
    ),
  })
end

--- Abandon change
--- @param ctx Context context
--- @param change Change Change data
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
function M.change_abandon(ctx, change, opts)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  local cmd = "abandon"
  local args = { M.get_change_id(change) }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Change `" .. M.get_change_id(change, true) .. "` abandoned", vim.log.levels.INFO)
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
  local args = { M.get_change_id(change) }
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
  assert(ctx, "Context not provided: ctx")
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
  assert(ctx, "Context not provided: ctx")
  assert(src_change, "Change not provided: src_change")
  local lopts = opts or {}
  local args = vim.list_extend({ lopts.dst_change and "-f" or "-r", M.get_change_id(src_change) }, lopts.files or {})
  if notify_immutable(src_change, { force = lopts.force }) then
    return
  end
  local dst = "it's parent"
  if lopts.dst_change then
    args = vim.list_extend(args, { "-t", M.get_change_id(lopts.dst_change) })
    dst = M.get_change_id(lopts.dst_change, true)
  end
  local cmd = "squash"
  start_dummy_editor(ctx, cmd, args, {
    force = lopts.force,
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Squashed change " .. M.get_change_id(src_change) .. " into " .. dst, vim.log.levels.INFO)
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
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  if change.current_working_copy then
    vim.notify("Already editing change `" .. M.get_change_id(change, true) .. "`", vim.log.levels.INFO)
    return
  end
  if notify_immutable(change, { force = lopts.force }) then
    return
  end
  local cmd = "edit"
  local args = { M.get_change_id(change) }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Editing change " .. M.get_change_id(change, true), vim.log.levels.INFO)
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
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  if notify_immutable(change, { force = lopts.force }) then
    return
  end
  -- get current description
  local cmd_log = "log"
  local args = { "--no-graph", "-r", M.get_change_id(change), "-T", "description" }
  local res = jujutsu.cli(ctx, cmd_log, { args = args })
  local data = vim.trim(res.stdout)
  local current_description = vim.split(data, "\n")
  -- edit description
  if lopts.firstline then
    vim.schedule(function()
      vim.ui.input({ prompt = "Describe change (" .. M.get_change_id(change, true) .. "): ", default = current_description[1] }, function(input)
        if input == nil then
          return
        end
        local new_description = vim.list_extend({ vim.trim(input) }, vim.list_slice(current_description, 2, #current_description))
        local cmd = "describe"
        jujutsu.cli(ctx, cmd, {
          args = jujutsu.ignore_immtuable({
            "-r",
            M.get_change_id(change),
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
                vim.notify("Described change " .. M.get_change_id(change, true), vim.log.levels.INFO)
              end,
            })
          ),
        })
      end)
    end)
    return true
  end
  start_dummy_editor(ctx, "describe", { "--edit", M.get_change_id(change) }, { force = lopts.force })
  return true
end

--- Revert change
--- @param ctx Context context
--- @param change Change current change
--- @param opts? {force?: boolean} Options
--- - force Edit immutable change
--- @return boolean?
function M.change_revert(ctx, change, opts)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  local cmd = "revert"
  local args = { "-r", M.get_change_id(change), "-d", "@" }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Reverted change " .. M.get_change_id(change, true), vim.log.levels.INFO)
        end,
      })
    ),
  })
  return true
end

--- Edit file or jiejie object
--- @param ctx Context context
--- @param file? string File name
--- @param change Change Change to edit file at
--- @param opts? {previous_win?: boolean, edit_cmd?: fun(filename: string), hunk?: Hunk, callback?: fun(winid: number)}
--- - previous_win: Navigate to previous window or split a new window before edting file, when current buffer is the log buffer
--- - edit_cmd: Function that's called for editing file
--- - callback: Callback function that's executed once the object has been opened in a buffer
--- @return boolean?
function M.object_edit(ctx, file, change, opts)
  assert(ctx, "Context not provided: ctx")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  local edit_cmd = lopts.edit_cmd or vim.cmd.e
  local filename = parsers.join_url({
    root = ctx.root,
    revision = change.current_working_copy and "@" or M.get_change_id(change),
    path = file,
  })
  local winid = vim.api.nvim_get_current_win()
  local bufid = vim.api.nvim_get_current_buf()
  local winid_new
  if lopts.previous_win and bufid == ctx.buf then
    -- try to navigate to the last accessed window. If it is the preview window, try to find the first other window. If
    -- it it does'nt exist, cause a new window to be created
    vim.cmd.wincmd("p")
    winid_new = vim.api.nvim_get_current_win()
    if vim.wo[winid_new][0].previewwindow then
      local winids = vim.api.nvim_tabpage_list_wins(0)
      local found
      for _, _winid in ipairs(winids) do
        if _winid ~= winid_new and _winid ~= winid then
          vim.api.nvim_tabpage_set_win(0, _winid)
          winid_new = _winid
          found = true
          break
        end
      end
      if not found then
        winid_new = winid
      end
    end
    if winid_new == winid then
      vim.cmd.new()
    end
  end
  -- It would be great if +cmd could be passed to the edit command to make vim position the cursor. However, it seems
  -- like this isn't implemented by vim.cmd
  -- local args = {}
  -- if lopts.hunk then
  --   local cursor_line = lopts.hunk.end_line + lopts.hunk.cursor_offset
  --   args = vim.list_extend(args, { "+" .. cursor_line })
  -- end
  -- args = vim.list_extend(args, { filename })
  -- edit_cmd({ args = args })
  edit_cmd(filename)
  winid_new = vim.api.nvim_get_current_win()
  if lopts.hunk then
    -- When hunk is set, the cursor needs to be positioned relatively on the exact line from the hunk
    -- Due to the use of BufReadCmd for Jiejie file, we're not able to set the cursor position here - the file just
    -- hasn't loaded yet. Therefore, create a temporary autocommand that will do the job
    local _bufid = vim.api.nvim_get_current_buf()
    ---@diagnostic disable-next-line: param-type-mismatch
    local cursor_line = lopts.hunk.end_line + lopts.hunk.cursor_offset
    -- local lines = #(vim.fn.getbufline(_bufid, 1, "$"))
    -- if lines >= cursor_line then
    if not vim.startswith(filename, "jiejie://") then
      vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { cursor_line, 0 })
      if lopts.callback then
        lopts.callback(winid_new)
      end
    else
      local id
      id = vim.api.nvim_create_autocmd("BufReadPost", {
        buffer = _bufid,
        callback = function()
          vim.api.nvim_del_autocmd(id)
          vim.api.nvim_win_set_cursor(vim.api.nvim_get_current_win(), { cursor_line, 0 })
          if lopts.callback then
            lopts.callback(winid_new)
          end
        end,
      })
    end
  else
    if lopts.callback then
      lopts.callback(winid_new)
    end
  end
  return true
end

--- Restore file
--- @param ctx Context context
--- @param file ModifiedFile File name
--- @param change Change Change to restore file to
--- @param opts? {force?: boolean} Options
--- - force Change immutable
--- @return boolean?
function M.file_restore(ctx, file, change, opts)
  assert(ctx, "Context not provided: ctx")
  assert(file, "File not provided: file")
  assert(change, "Change not provided: change")
  local lopts = opts or {}
  local cmd = "restore"
  local args = { "-f", M.get_change_id(change), file.filename }
  jujutsu.cli(ctx, cmd, {
    args = jujutsu.ignore_immtuable(args, { force = lopts.force }),
    on_exit = M.reload_or_error(
      ctx,
      table.concat(vim.list_extend({ cmd }, args), " "),
      vim.tbl_extend("force", lopts, {
        on_exit = function()
          vim.notify("Restored file " .. file.filename .. " to change " .. M.get_change_id(change, true), vim.log.levels.INFO)
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
  assert(ctx, "Context not provided: ctx")
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
  assert(ctx, "Context not provided: ctx")
  local lopts = opts or {}
  local log_revisions = (ctx.log_revisions or 10) + lopts.adjustment
  ctx.log_revisions = log_revisions > 0 and log_revisions or 1
  context.set_context(ctx)
  local log_dirty_check = require("jiejie.log_dirty_check")
  log_dirty_check.dirty_mark_content(ctx.buf)
  log_dirty_check.do_dirty_check()
end

--- @class RepositoryPath
--- @field path string File name relative to the repository root
--- @field change Change Revision that represents this file

--- @enum SplitDirection Determine the split direction
M.SPLIT_DIRECTION = {
  default = 2 ^ 0,
  horizontal = 2 ^ 1,
  vertical = 2 ^ 2,
  tab = 2 ^ 3,
}

M.SPLIT_DIRECTION_FN = {
  [2 ^ 0] = vim.cmd.e,
  [2 ^ 1] = vim.cmd.sp,
  [2 ^ 2] = vim.cmd.vs,
  [2 ^ 3] = vim.cmd.tabe,
}

--- Diff split opens the repository paths for comparison
--- @param ctx Context context
--- @param files RepositoryPath[] File to diff
--- @param opts? {split_direction?: SplitDirection, previous_win?: boolean, open_first_file?: boolean} Options
--- - split_direction: Split direction
--- - previous_win: Navigate to previous window or split a new window before edting file, when current buffer is the log buffer
--- - open_first_file: If true, also open the first provided file. If false, the currently edited file is used assumed to be the first file in the list
function M.diff_split(ctx, files, opts)
  assert(ctx, "Context not provided: ctx")
  assert(files, "File not provided: file")
  local lopts = opts or {}
  -- disable all diffs for all windows in the current tab since a new diff is going to be opened
  vim.cmd.diffoff({ bang = true })
  local diffthis = function(winid)
    if not winid then
      return
    end
    local winnr = vim.api.nvim_win_get_number(winid)
    vim.cmd.windo({ range = { winnr }, args = { "diffthis" } })
    log_diff.diff_mark(ctx, { winid = winid })
  end
  if not lopts.open_first_file then
    -- we're not a opening file, therefore put the current file in diff mode
    diffthis(vim.api.nvim_get_current_win())
  end
  local first_file_winid
  for idx, file in ipairs(files) do
    if idx > 1 or lopts.open_first_file then
      -- Default split method is:
      -- - the first file is opened in the previous window or in a horizontal split
      -- - the second file is opened in a horizontal split
      -- - the following files arge opened in vertical splits from to the second file
      local edit_cmd = idx == 1 and lopts.previous_win and (vim.cmd.e or vim.cmd.sp) or idx == 2 and vim.cmd.sp or vim.cmd.vs
      if idx > 1 or not lopts.previous_win then
        edit_cmd = lopts.split_direction and M.SPLIT_DIRECTION_FN[lopts.split_direction] or edit_cmd
      end
      M.object_edit(ctx, file.path, file.change, { callback = diffthis, edit_cmd = edit_cmd, previous_win = idx == 1 and lopts.previous_win })
      if idx == 1 then
        first_file_winid = vim.api.nvim_get_current_win()
      end
    else
      first_file_winid = vim.api.nvim_get_current_win()
    end
  end
  if first_file_winid then
    vim.api.nvim_set_current_win(first_file_winid)
  end
end

--- Command executes jj commands, returns exit code
--- @param ctx Context context
--- @param cmd string List of CLI arguments
--- @param opts? {on_exit?: fun(out: vim.SystemCompleted), args: string[]} Options
--- - on_exit Callback function is executed in a scheduled context
--- - args string[] List of CLI arguments
--- @return table
function M.cli(ctx, cmd, opts)
  assert(ctx, "Context not provided: ctx")
  assert(cmd, "Command not provided: cmd")
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

return M
