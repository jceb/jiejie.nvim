--- System API
local M = {}

--- Execute command with arguments
--- @param ctx Context Context
--- @param cmd string Command
--- @param opts? {args?: string[], sys_opts?: vim.SystemOpts, on_exit?: fun(out: vim.SystemCompleted), error_on_failure?: boolean, notify_on_failure?: boolean} Options
--- - args? string[] List of CLI arguments
--- - sys_opts? vim.SystemOpts Options to the CLI
--- - on_exit? fun(out: vim.SystemCompleted) Options to the CLI
--- - error_on_failure? boolean Throws an error if command fails, default true
--- - notify_on_failure? boolean Display an error message when a failure occurs, default false
--- @return table
function M.exec(ctx, cmd, opts)
  local lopts = opts or {}
  local command = vim.list_extend({ cmd }, lopts.args or {})
  local exec = vim.system(
    command,
    vim.tbl_extend("keep", {
      text = true,
      cwd = ctx.root,
      env = vim.tbl_extend("keep", { LANG = "C" }, lopts.sys_opts and lopts.sys_opts.env or {}),
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
      error("Command failed with non-zero exit code: " .. out.code .. "\n\t" .. table.concat(command, " "))
    end
  end
  vim.schedule(function()
    vim.cmd.checktime() -- align vim's buffer status with the file system
  end)
  return out
end

return M
