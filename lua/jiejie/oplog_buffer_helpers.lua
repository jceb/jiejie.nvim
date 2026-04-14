local parsers = require("jiejie.parsers")

--- Opeations that help with extracting data from the operation log buffer
local M = {}

--- @class WithOpArgs
--- @field ctx Context Context
--- @field src_change? OperationChange Source change
--- @field file? ModifiedFile Modified file

--- Search change at position
--- @param fn fun(args?: WithOpArgs): boolean Callback function
--- @param opts? WithOpts | {search_downwards?: boolean, linenr_from_file?: boolean, linenr_offset?: number} Options
--- - search_downwards Search downwards, instead of upwards
--- - linenr_from_file Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- @return function
function M.search_change(fn, opts)
  --- @param args? WithOpArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= largs.ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return
    end
    -- starting point for search, current lnie + offset
    local linenr = (lopts.linenr_from_file and largs.file and largs.file.linenr or vim.api.nvim_win_get_cursor(winid)[1]) + (lopts.linenr_offset or 0)
    local change
    if lopts.search_downwards then
      ---@diagnostic disable-next-line: param-type-mismatch
      for idx, line in ipairs(vim.fn.getbufline(largs.ctx.buf, linenr, "$")) do
        change = parsers.parse_oplog_change(line, linenr + idx - 1)
        if change then
          break
        end
      end
    else
      while linenr > 0 do
        change = parsers.parse_oplog_change(vim.fn.getbufoneline(largs.ctx.buf, linenr), linenr)
        if change then
          break
        end
        linenr = linenr - 1
      end
    end
    if change == nil and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Change data not found.", vim.log.levels.WARN)
      end
    else
      return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "src_change"] = change }))
    end
  end
end

return M
