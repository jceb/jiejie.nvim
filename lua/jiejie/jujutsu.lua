local M = {}

--- Add --ignore-immutable flag to the list of arguments when force is true.
--- @param args table List of arguments
--- @param force boolean If true, --ignore-immutable flag is added
--- @return table
function M.ignoreImmtuable(args, force)
  if force then
    table.insert(args, "--ignore-immutable")
  end
  return args
end

function M.cli(ctx, fargs)
  local command = vim.fn.extend({ "jj" }, fargs)
  local res = vim
    .system(command, {
      text = true,
      cwd = ctx.root,
    })
    :wait()
  -- TODO: is there a better way to diplay joined stderr/stdout output? E.g. by spawing a shell? - actually, pass in
  -- the same receiver function for stderr and stdout
  if res.code ~= 0 then
    error("Command failed with non-zero exit code: " .. res.code)
  end
  return res.code
end

--- Returns jj's root directory
--- @param directory? string Dirtory to start look at. If not present, start looking in the directory of the currently
--- open file
--- @return string
function M.getRoot(directory)
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
