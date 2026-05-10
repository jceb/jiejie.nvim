local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local parsers = require("jiejie.parsers")
local api = require("jiejie.api")
local buffer = require("jiejie.buffer")
local log_view = require("jiejie.log_view")
local log_dirty_check = require("jiejie.log_dirty_check")

--- Helper command to retrieve a file object from a parameter
local getFile = function(filename)
  local file = {}
  file.filename = vim.fn.fnamemodify(filename, ":p")
  if vim.startswith(file.filename, "jiejie://") then
    local url = parsers.parse_url(file.filename)
    assert(url, "Unknown URL: " .. file.filename)
    assert(url.path, "Path not specified in URL: " .. file.filename)
    file.path = url.path
    file.change_id = url.revision
    file.root = url.root
  else
    local directory = vim.fn.fnamemodify(file.filename, ":h")
    file.root = jujutsu.get_root(directory)
    assert(file.filename and file.root and vim.startswith(file.filename, file.root), "Unable to determine Jujutsu root directory for. File: " .. file.filename)
    file.path = vim.fn.trim(vim.fn.strpart(file.filename, #file.root), "/", 1)
  end
  return file
end

--- Commands
local M = {}

local commands = {
  --- @param ctx Context context
  --- @param args string[] Arguments for command
  --- @param opts? {force?: boolean, vertical?: boolean} Options
  log = function(ctx, cmd, args, opts)
    local lopts = opts or {}
    if #args >= 1 then
      ---@diagnostic disable-next-line: missing-fields ingore missing fields, because they're not used
      local files = {}
      for _, fname in ipairs(args) do
        local file = getFile(fname)
        if file then
          table.insert(files, file)
        else
          vim.notify("Ignoring unknown file or directory: " .. fname, vim.log.levels.WARN)
        end
      end
      if #files > 0 then
        local current_view = log_view.get_log_view_current(ctx.buf)
        local revset = current_view and (current_view.revset or "::") or "::@"
        local basenames = {}
        for _, f in ipairs(files) do
          table.insert(basenames, vim.fs.basename(f.path))
        end
        local description = table.concat(basenames, "_") or "::@"
        local paths = {}
        for _, f in ipairs(files) do
          table.insert(paths, f.path)
        end
        local view = {
          id = table.concat(paths, "_"),
          revset = revset,
          paths = paths,
          description = description,
        }
        log_view.add_dynamic_view(view)
        local au_id
        -- Setting view indirectly, because we can't pass view as an argument to show_log
        local set_view = function()
          if au_id then
            vim.api.nvim_del_autocmd(au_id)
          end
          if ctx.buf == nil then
            ctx.buf = vim.fn.bufnr()
          end
          log_view.set_log_view(ctx.buf, view)
          log_dirty_check.dirty_mark_content(ctx.buf)
          log_dirty_check.do_dirty_check()
        end
        if ctx.buf ~= nil then
          set_view()
        else
          au_id = vim.api.nvim_create_autocmd("User", {
            pattern = "JiejieLogLoaded",
            callback = set_view,
          })
        end
      else
        vim.notify("Failed to load file's change history: " .. args[1], vim.log.levels.ERROR)
      end
    end
    api.show_log(ctx, { vertical = lopts.vertical, buffer_type = buffer.BUFFER_TYPE.LOG })
  end,

  --- @param ctx Context context
  --- @param args string[] Arguments for command
  --- @param opts? {force?: boolean, vertical?: boolean} Options
  oplog = function(ctx, cmd, args, opts)
    local lopts = opts or {}
    api.show_log(ctx, { vertical = lopts.vertical, buffer_type = buffer.BUFFER_TYPE.OPLOG })
  end,

  --- @param ctx Context context
  --- @param args string[] Arguments for command
  --- @param opts? {force?: boolean, vertical?: boolean} Options
  evolog = function(ctx, cmd, args, opts)
    local lopts = opts or {}
    local largs = args or {}
    local change = #largs > 0 and api.construct_dummy_change(largs[1]) or api.construct_dummy_change("@")
    api.show_log(ctx, { vertical = lopts.vertical, buffer_type = buffer.BUFFER_TYPE.EVOLOG, change = change })
  end,

  --- @param ctx Context context
  --- @param args string[] Arguments for command
  --- @param opts? {force?: boolean, vertical?: boolean} Options
  default = function(ctx, cmd, args, opts)
    local lopts = opts or {}
    api.cli(ctx, cmd, { args = jujutsu.ignore_immtuable(args, { force = lopts.force }) })
  end,
}

--- @param args vim.api.keyset.create_user_command.command_args Command arguments
function M.Jj(args)
  local ctx = context.get_context()
  assert(ctx, "Working directory does not belong to a Jujutsu repository")
  local cmd = #args.fargs > 0 and args.fargs[1] or "log"
  local command = commands[cmd]
  if not command then
    command = commands.default
  end
  command(ctx, cmd, #args.fargs > 1 and vim.list_slice(args.fargs, 2) or {}, {
    vertical = args.smods.vertical,
    force = args.bang,
  })
end

--- @param args vim.api.keyset.create_user_command.command_args Command arguments
function M.Jedit(args)
  local object = {}
  if #args.fargs > 0 then
    object = parsers.parse_object(args.fargs[1]) or {}
  end
  object.filename = vim.fn.fnamemodify(object.filename and object.filename ~= "" and object.filename or vim.fn.expand("%"), ":p")
  local root
  if vim.startswith(object.filename, "jiejie://") then
    -- special handling for calling Jedit on a file name that is a jiejie URL
    local url = parsers.parse_url(object.filename)
    if not url then
      error("Unknown URL: " .. object.filename)
    end
    object.filename = vim.fs.joinpath(url.root, url.path)
  else
    local directory = vim.fn.fnamemodify(object.filename, ":h")
    root = jujutsu.get_root(directory)
  end
  local ctx = context.get_context(root)
  assert(ctx, "Working directory does not belong to a Jujutsu repository. File: " .. object.filename)
  assert(vim.startswith(object.filename, ctx.root), "Unable to determine Jujutsu root directory for. File: " .. object.filename)
  local path = vim.fn.trim(vim.fn.strpart(object.filename, #ctx.root), "/", 1)
  local dummy_change = api.construct_dummy_change(object.change_id or "@")
  api.object_edit(ctx, path, dummy_change)
end

--- @param args vim.api.keyset.create_user_command.command_args Command arguments
function M.Jdiffsplit(args)
  local spilt_direction = args.name == "Jvdiffsplit" and M.SPLIT_DIRECTION.vertical or args.name == "Jhdiffsplit" and M.SPLIT_DIRECTION.horizontal or nil
  local files = {}
  local src = getFile(vim.fn.expand("%"))
  table.insert(files, { path = src.path, M.construct_dummy_change(src.change_id or "@") })
  local ctx = context.get_context(src.root)
  assert(ctx, "Working directory does not belong to a Jujutsu repository. File: " .. src.filename)
  if #args.fargs > 0 then
    local dst_object = parsers.parse_object(args.fargs[1]) or {}
    if vim.startswith(dst_object.change_id, "@") then
      local ancestors = M.get_ancestors(ctx, M.construct_dummy_change(dst_object.change_id))
      for _, change in ipairs(ancestors) do
        table.insert(files, { path = dst_object.filename or src.path, change = change })
      end
    else
      table.insert(files, { path = dst_object.filename or src.path, change = M.construct_dummy_change(dst_object.change_id) })
    end
  end
  api.diff_split(ctx, files, { split_direction = spilt_direction })
end

--- @param args vim.api.keyset.create_user_command.command_args Command arguments
function M.Jlog(args)
  local file = nil
  local src_change = api.construct_dummy_change("@")
  if args.range == 1 and args.count == 0 then
    file = getFile(vim.fn.expand("%"))
  elseif #args.fargs == 1 then
    file = getFile(args.fargs[1])
  end
  if file and file.change_id then
    src_change = api.construct_dummy_change(file.revision)
  end
  local ctx = context.get_context(file and file.root)
  assert(ctx, "Working directory does not belong to a Jujutsu repository. Directory: " .. vim.fn.getcwd())
  api.load_history(ctx, src_change, {
    file = file,
    jump = not args.bang,
    location_list = args.name == "JlLog",
  })
end

--- Configure commands
function M.setup()
  local cmdOpts = { desc = "Jujutsu command wrapper - shows log when no argument is provided", nargs = "*", range = 2, complete = "file" }
  if vim.fn.exists(":J") ~= 2 then
    vim.api.nvim_create_user_command("J", M.Jj, cmdOpts)
  end
  vim.api.nvim_create_user_command("Jj", M.Jj, cmdOpts)
  vim.api.nvim_create_user_command("Jedit", M.Jedit, { desc = ":edit a jiejie-object", nargs = "?" })
  vim.api.nvim_create_user_command("Jdiffsplit", M.Jdiffsplit, { desc = "Perform a vimdiff against the given file", nargs = "?", bang = true })
  vim.api.nvim_create_user_command(
    "Jvdiffsplit",
    M.Jdiffsplit,
    { desc = "Perform a vimdiff against the given file, but always split vertically", nargs = "?", bang = true }
  )
  vim.api.nvim_create_user_command(
    "Jhdiffsplit",
    M.Jdiffsplit,
    { desc = "Perform a vimdiff against the given file, but always split horizontally", nargs = "?", bang = true }
  )
  vim.api.nvim_create_user_command(
    "JcLog",
    M.Jlog,
    { desc = "Load the change history into the quickfix list.", nargs = "?", bang = true, count = 0, complete = "file" }
  )
  vim.api.nvim_create_user_command(
    "JlLog",
    M.Jlog,
    { desc = "Load the change history into the location list.", nargs = "?", bang = true, count = 0, complete = "file" }
  )
  local id = vim.api.nvim_create_augroup("Jiejie", {})
  require("jiejie.log").setup(id)
  require("jiejie.log_dirty_check").setup()
end

return M
