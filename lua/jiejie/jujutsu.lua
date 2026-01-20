local M = {}

--- Add --ignore-immutable flag to the list of arguments when force is true.
--- @param args string[] List of arguments
--- @param force boolean If true, --ignore-immutable flag is added
--- @return string[]
function M.ignore_immtuable(args, force)
  if force then
    table.insert(args, "--ignore-immutable")
  end
  return args
end

--- @class ErrOpts
--- @field error_on_failure? boolean Throws an error if command fails, default true
--- @field notify_on_failure? boolean Display an error message when a failure occurs, default false

--- Execute jj CLI with arguments
--- @param ctx Context context
--- @param fargs? string[] List of CLI arguments
--- @param opts? vim.SystemOpts Options to the CLI
--- @param on_exit? fun(out: vim.SystemCompleted) Options to the CLI
--- @param errOpts? ErrOpts Error options
--- @return table
function M.cli(ctx, fargs, opts, on_exit, errOpts)
  local command = vim.list_extend(vim.list_extend({ "jj" }, fargs or {}), {
    "--no-pager",
    "--color",
    "never",
  })
  local exec = vim.system(
    command,
    vim.tbl_extend("keep", {
      text = true,
      cwd = ctx.root,
    }, opts or {}),
    on_exit
  )
  if on_exit ~= nil then
    return exec
  end
  local res = exec:wait()
  -- TODO: is there a better way to diplay joined stderr/stdout output? E.g. by spawing a shell? - actually, pass in
  -- the same receiver function for stderr and stdout
  if res and res.code ~= 0 then
    if errOpts and errOpts.notify_on_failure then
      vim.notify((res.stdout or "") .. "\n" .. (res.stderr or ""), vim.log.levels.ERROR)
    end
    if not errOpts or errOpts.error_on_failure == nil or errOpts.error_on_failure then
      error("Command failed with non-zero exit code: " .. res.code)
    end
  end
  return res
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
  if fd == nil or err_msgx ~= nil then
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
