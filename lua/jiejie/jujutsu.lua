local M = {}

--- Add --ignore-immutable flag to the list of arguments when force is true.
--- @param args string[] List of arguments
--- @param opts? {force?: boolean} Options
--- - force If true, --ignore-immutable flag is added
--- @return string[]
function M.ignore_immtuable(args, opts)
  local lopts = opts or {}
  if lopts.force then
    table.insert(args, "--ignore-immutable")
  end
  return args
end

--- Execute jj CLI with arguments
--- @param ctx Context Context
--- @param cmd string Command
--- @param opts? {args?: string[], sys_opts?: vim.SystemOpts, on_exit?: fun(out: vim.SystemCompleted), error_on_failure?: boolean, notify_on_failure?: boolean} Options
--- - args? string[] List of CLI arguments
--- - sys_opts? vim.SystemOpts Options to the CLI
--- - on_exit? fun(out: vim.SystemCompleted) Options to the CLI
--- - error_on_failure? boolean Throws an error if command fails, default true
--- - notify_on_failure? boolean Display an error message when a failure occurs, default false
--- @return table
function M.cli(ctx, cmd, opts)
  local lopts = opts or {}
  local command = vim.list_extend(vim.list_extend({ "jj", cmd }, lopts.args or {}), {
    "--no-pager",
    "--color",
    "never",
  })
  local exec = vim.system(
    command,
    vim.tbl_extend("keep", {
      text = true,
      cwd = ctx.root,
    }, lopts.sys_opts or {}),
    lopts.on_exit
  )
  if lopts.on_exit then
    return exec
  end
  local out = exec:wait()
  if out and out.code ~= 0 then
    if lopts.notify_on_failure then
      vim.notify((out.stdout or "") .. "\n" .. (out.stderr or ""), vim.log.levels.ERROR)
    end
    if not lopts.error_on_failure or lopts.error_on_failure then
      error("Command failed with non-zero exit code: " .. out.code)
    end
  end
  vim.schedule(function()
    vim.cmd.checktime() -- align vim's buffer status with the file system
  end)
  return out
end

--- @class Editor
--- @field script string Path to dummy editor script
--- @field delete function Delete editor script and all other related files
--- @field exit function Terminate editor
--- @field get_edited_file function File that contains the name of the file that shall be edited

--- Create a dummy editor that will be executed by jj
--- @return Editor
function M.create_dummy_editor()
  local fd, editorScript, err_msgx = vim.uv.fs_mkstemp((vim.env.TMPDIR or "/tmp") .. "/jj_editor_XXXXXX")
  if fd == nil or err_msgx then
    error(err_msgx)
  end
  assert(vim.uv.fs_close(fd))
  local exitFile = editorScript .. ".exit"
  local editedFile = editorScript .. ".edit"
  assert(vim.uv.fs_chmod(editorScript, tonumber("700", 8)))
  fd = assert(vim.uv.fs_open(editorScript, "w", tonumber("700", 8)))
  local editorScriptContent = string.gsub(
    string.gsub(
      [[
#!/bin/sh
[ -f "$JIEJIE_EXIT" ] && cat "$JIEJIE_EXIT" >&2 && exit 1
echo "$1" > "$JIEJIE_EDIT"
while [ -f "$JIEJIE_EDIT" -a ! -f "$JIEJIE_EXIT" ]; do sleep 0.05 2>/dev/null || sleep 1; done
rm -f "$JIEJIE_EDIT" "$JIEJIE_EXIT"
exit 0
      ]],
      "$JIEJIE_EXIT",
      exitFile
    ),
    "$JIEJIE_EDIT",
    editedFile
  )
  assert(vim.uv.fs_write(fd, editorScriptContent))
  assert(vim.uv.fs_close(fd))
  return {
    script = editorScript,
    delete = function()
      vim.uv.fs_unlink(exitFile)
      vim.uv.fs_unlink(editedFile)
      vim.uv.fs_unlink(editorScript)
    end,
    -- Exit editor
    exit = function()
      assert(vim.uv.fs_open(exitFile, "w", tonumber("600", 8)))
    end,
    --- Returns the edited file name or nil if the file doesn't exist, yet
    --- @return string?
    get_edited_file = function()
      local stat, err_name = vim.uv.fs_stat(editedFile)
      if not stat or err_name then
        return
      end
      local fd, err_name = vim.uv.fs_open(editedFile, "r", tonumber("600", 8))
      if not fd or err_name then
        return
      end
      local data, err_name = vim.uv.fs_read(fd, stat.size)
      if not data or err_name then
        return
      end
      return vim.trim(vim.split(data, "\n")[1])
    end,
  }
end

--- Returns jj's root directory
--- @param directory? string Dirtory to start look at. If not present, start looking in the directory of the currently
--- open file
--- @return string
function M.get_root(directory)
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

return M
