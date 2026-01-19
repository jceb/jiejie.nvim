local context = require("jiejie.context")
local jujutsu = require("jiejie.jujutsu")
local parsers = require("jiejie.parsers")
local timer = require("jiejie.timer")

--- @param ctx Context context
--- @param cmd string JJ command
--- @param args? string[] List of additional arguments
--- @param force? boolean Modify immutable change
local function start_dummy_editor(ctx, cmd, args, force)
  -- Start dummy editor in the background
  local buffer_dirty_check = require("jiejie.buffer_dirty_check")
  local editor = jujutsu.create_dummy_editor()
  local exec = jujutsu.cli(
    ctx,
    jujutsu.ignore_immtuable(
      vim.list_extend(
        vim.list_extend({ cmd }, {
          "--edit",
          "--no-pager",
          "--color",
          "never",
          "--quiet",
          -- "--debug",
          -- "-r",
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
        -- trigger reload
        buffer_dirty_check.dirty_mark_content(ctx.buf)
      else
        vim.schedule(function()
          vim.notify("Modifying change failed, maybe it's immutable!", vim.log.levels.ERROR)
        end)
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

--- @class Change
--- @field status string Change status, one of @ (current change), × (conflict), ◆ (root), ○ (regular change)
--- @field id string change ID

local CHANGE = {
  CURRENT = "@",
  IMMUTABLE = "◆",
  CONFLICT = "×",
  MUTUABLE = "◇",
  HEAD = "○",
}

--- Retrieve data about the change that the cursor is on
--- @param ctx Context context
--- @param fn fun(ctx: Context, change: Change) Callback that is called with Context and the extracted change information. The function is only
---                    called when a change id is found at the cursor position
--- @return function
function M.with_change_at_position(ctx, fn)
  return function()
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
      vim.notify("No change data found.", vim.log.levels.WARN)
    else
      fn(ctx, change)
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

--- Create new change
--- @param ctx Context context
--- @return function
function M.change_new()
  return function(ctx, change)
    local args = { "new", change.id }
    -- TODO mark tree as dirty
    jujutsu.cli(ctx, args)
  end
end

--- Commit change
--- @param ctx Context context
--- @return function
function M.change_commit(ctx)
  return function()
    start_dummy_editor(ctx, "commit")
  end
end

--- Squash chcanges
--- @return function
function M.change_squash(force)
  --- @param ctx Context context
  --- @param change Change current change
  return function(ctx, change)
    -- TODO: do I need a target change ID?
    local args = { "squash", "-r", change.id }
    jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force))
  end
end

--- Edit change
--- @param force? boolean Edit immutable change
--- @return function
function M.change_edit(force)
  --- @param ctx Context context
  --- @param change Change current change
  return function(ctx, change)
    if change.status == CHANGE.CURRENT then
      vim.notify("Already editing change! ID: " .. change.id, vim.log.levels.INFO)
      return
    end
    if change.status == CHANGE.IMMUTABLE and not force then
      vim.notify("Change is immutable, use force to modify it! ID: " .. change.id, vim.log.levels.ERROR)
      return
    end
    local args = { "edit", change.id }
    jujutsu.cli(ctx, jujutsu.ignore_immtuable(args, force))
    local buffer_dirty_check = require("jiejie.buffer_dirty_check")
    buffer_dirty_check.dirty_mark_everything(ctx.buf)
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
    local buffer_dirty_check = require("jiejie.buffer_dirty_check")
    if change.status == CHANGE.IMMUTABLE and not force then
      vim.notify("Change is immutable, use force to modify it! ID: " .. change.id, vim.log.levels.ERROR)
      return
    end
    -- get current description
    local res = jujutsu.cli(ctx, {
      "log",
      "--no-graph",
      "--no-pager",
      "--color",
      "never",
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
        vim.ui.input({ prompt = "Describe change (" .. change.id .. "): ", default = current_description[1] }, function(input)
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
              "--no-pager",
              "--quiet",
            }, force),
            {
              stdin = new_description,
            }
          )
          buffer_dirty_check.dirty_mark_content(ctx.buf)
        end)
      end)
    end
    start_dummy_editor(ctx, "describe", { change.id }, force)
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

--- Command executes jj commands, returns exit code
--- @param fargs string[] List of CLI arguments
--- @param error_on_failure? boolean Throws an error if command fails, default false
--- @param root? string Root directory of repository, determined automatically by the current buffer if not provided
--- @return table
function M.cli(fargs, error_on_failure, root)
  local ctx = context.get_context(root)
  local command = vim.fn.extend({ "jj" }, fargs)
  local out = vim
    .system(command, {
      text = true,
      cwd = ctx.root,
      -- stdout = print,
      -- stdout = print,
    })
    :wait()
  -- TODO: is there a better way to diplay joined stderr/stdout output? E.g. by spawing a shell? - actually, pass in
  -- the same receiver function for stderr and stdout
  if out.stdout ~= "" then
    vim.notify(out.stdout, vim.log.levels.INFO)
  end
  if out.code ~= 0 then
    vim.notify(out.stderr, vim.log.levels.ERROR)
    if error_on_failure then
      error("Command failed with non-zero exit code: " .. out.code)
    end
  end
  return out
end

--- Configure commands
function M.setup()
  local cmd = function(args)
    if vim.fn.len(args.fargs) == 0 then
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
