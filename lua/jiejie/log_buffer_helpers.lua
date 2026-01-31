local context = require("jiejie.context")
local parsers = require("jiejie.parsers")

--- Opeations that help with extracting data from the log buffer
local M = {}

--- Adjust the displayed number of revisions
--- @param fn fun(args: {ctx: Context, count: number}): boolean Callback function
--- @param negate? boolean Negate count or pass it on as received
function M.with_count(fn, negate)
  --- @param args? {} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local count = vim.v.count ~= 0 and vim.v.count or 1
    return fn(vim.tbl_extend("force", largs, { count = (negate and -1 or 1) * count }))
  end
end

--- Add force to arguments
--- @param fn fun(args: {force: boolean}): boolean Callback function
--- - force Add force = true to argument list
--- @return function
function M.with_force(fn)
  --- @param args? {} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    return fn(vim.tbl_extend("force", largs, { force = true }))
  end
end

--- Add force to arguments
--- @param args? {} Arguments
--- @return {}
function M.with_direct_force(args)
  local largs = args or {}
  return vim.tbl_extend("force", largs, { force = true })
end

--- Provide repository context
--- @param root string Root directory of repository
--- @param fn fun(args: {ctx: Context}): boolean Callback function
--- @return function
function M.with_context(root, fn)
  --- @param args? {} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    return fn(vim.tbl_extend("force", largs, { ctx = context.get_context(root) }))
  end
end

--- Retrieve data about the change that the cursor is on
--- @param fn fun(args: {ctx: Context, src_change?: Change}): boolean Callback that is called with Context and the extracted change
---           information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, args_key?: string} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - args_key Argument key that the change is stored at
--- @return function
function M.with_change_at_position(fn, opts)
  --- @param args? {ctx: Context} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= largs.ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return
    end
    local linenr = vim.api.nvim_win_get_cursor(winid)[1]
    local line = vim.fn.getbufoneline(largs.ctx.buf, linenr)
    local change = parsers.parse_change(line, linenr)
    if change == nil and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("No change data found.", vim.log.levels.WARN)
      end
    else
      return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "src_change"] = change }))
    end
  end
end

--- Request a target change ID
--- @param fn fun(args: {ctx: Context, src_change: Change, dst_change?: Change}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, defualt_target?: string} Options
--- - defualt_target Default target change
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- @return function
function M.with_target_change(fn, opts)
  --- @param args? {ctx: Context, src_change: Change} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local change_prompt = lopts.defualt_target and lopts.defualt_target ~= "" and (" (" .. lopts.defualt_target .. ")")
      or (not lopts.defualt_target and " (@-)")
      or ""
    vim.ui.input({ prompt = "Target change" .. change_prompt .. ": " }, function(target)
      if not target and not lopts.err_continue then
        if lopts.err_notify or lopts.err_notify == nil then
          vim.notify("Target change ID nil.", vim.log.levels.WARN)
        end
        return
      end
      if lopts.defualt_target and (not target or target == "") then
        target = lopts.defualt_target
      end
      if not target or target == "" then
        return fn(largs)
      else
        -- TODO: verify existence of id before passing it on + generate a proper Change object
        return fn(vim.tbl_extend("force", largs, { dst_change = { id = target, id_short = target } }))
      end
    end)
  end
end

--- Request a bookmark
--- @param fn fun(args: {ctx: Context, src_change: Change, bookmark?: string, tag?: string}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean,  prompt?: string, args_key?: string, tags?: boolean} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - prompt Prompt string
--- - tags Handle tags instead of bookmarks
--- - args_key Argument key that the change is stored at
--- @return function
function M.with_bookmark_or_tag(fn, opts)
  --- @param args? {ctx: Context, src_change?: Change, bookmarks?: BookmarkTag[], tags?: BookmarkTag[]} Arguments
  --- - bookmarks Selection of bookmarks to choose from
  --- - tags Selection of tags to choose from - opts.tags must be set for tags to be used
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local title = lopts.tags and "tag" or "bookmark"
    local bts = lopts.tags and largs.tags or largs.bookmarks
    local prompt = lopts.prompt or (bts and ("Select " .. title .. ": ") or ("Enter " .. title .. " name: "))
    if bts then
      vim.ui.select(bts, {
        prompt = prompt,
        format_item = function(item)
          return item.name
            .. (item.remote and ("@" .. item.remote .. " ") or "")
            .. " ("
            .. (item.id_short or "")
            .. ") "
            .. (item.description_first_line or "")
        end,
      }, function(bt, _)
        if not bt and not lopts.err_continue then
          if lopts.err_notify or lopts.err_notify == nil then
            vim.notify("Selection failed.", vim.log.levels.WARN)
          end
          return
        end
        if not bt then
          fn(largs)
        else
          fn(vim.tbl_extend("force", largs, { [lopts.args_key or (lopts.tags and "tag" or "bookmark")] = bt.name }))
        end
      end)
    else
      vim.ui.input({ prompt = prompt }, function(bt)
        if not bt and not lopts.err_continue then
          if lopts.err_notify or lopts.err_notify == nil then
            vim.notify("Input canceled.", vim.log.levels.WARN)
          end
          return
        end
        if bt == "" then
          fn(largs)
        else
          fn(vim.tbl_extend("force", largs, { [lopts.args_key or (lopts.tags and "tag" or "bookmark")] = bt }))
        end
      end)
    end
  end
end

--- Retrieve bookmarks or tags
--- @param fn fun(args: {ctx: Context, src_change: Change, bookmarks?: string[], tags?: string[]}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, args_key?: string, _local?: boolean, remote?: boolean, tags?: boolean} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - args_key Argument key that the change is stored at
--- - tags List tags instead of bookmarks
--- - _local List local bookmarks - if nil, list local bookmarks
--- - remote List remote bookmarks - if nil, don't list remote bookmarks
--- @return function
function M.with_bookmarks_or_tags(fn, opts)
  --- @param args? {ctx: Context, src_change: Change} Arguments
  --- - src_change If change is provided, return only the bookmars relevant for this change
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local jujutsu = require("jiejie.jujutsu")
    local cmd = lopts.tags and "tag" or "bookmark"
    local _args = {
      "list",
      "-T",
      [[name ++ "†" ++ tracked ++ "‡" ++ present ++ "⌠" ++ remote ++ "⌡" ++ if(normal_target, normal_target.commit_id().short()) ++ "∫" ++ if(normal_target, normal_target.commit_id().short()) ++ "∬" ++ if(normal_target, normal_target.description().first_line()) ++ "\n"]],
    }
    if largs.src_change then
      _args = vim.list_extend(_args, { "-r", largs.src_change.id })
    end
    jujutsu.cli(largs.ctx, cmd, {
      args = _args,
      on_exit = vim.schedule_wrap(function(out)
        local bts = {}
        for _, line in ipairs(vim.split(out.stdout, "\n")) do
          local bt = parsers.parse_bookmark_or_tag(line)
          if bt and bt.present then
            if lopts._local == false and not bt.remote or not lopts.remote and bt.remote then
              -- noop
            else
              bts = vim.list_extend(bts, { bt })
            end
          end
        end
        if #bts == 0 and not lopts.err_continue then
          if lopts.err_notify or lopts.err_notify == nil then
            vim.notify("No " .. (lopts.tags and "tags" or "bookmarks") .. " found.", vim.log.levels.WARN)
          end
          return
        end
        if #bts == 0 then
          fn(largs)
        else
          fn(vim.tbl_extend("force", largs, {
            [lopts.args_key or (lopts.tags and "tags" or "bookmarks")] = bts,
          }))
        end
      end),
    })
  end
end

--- Retrieve data about the file name that the cursor is on
--- @param fn fun(args: {ctx: Context, file?: ModifiedFile}): boolean Callback that is called with Context and the extracted file name
--- @param opts? {err_notify?: boolean, err_continue?: boolean} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- @return function
function M.with_file_at_position(fn, opts)
  --- @param args? {ctx: Context} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= largs.ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return
    end
    local pos = vim.api.nvim_win_get_cursor(winid)
    local line = vim.fn.getbufoneline(largs.ctx.buf, pos[1])
    local file = parsers.parse_filename(line, pos[1])
    if file == nil and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("No file name found.", vim.log.levels.WARN)
      end
    else
      return fn(vim.tbl_extend("force", largs, { file = file }))
    end
  end
end

--- Search change that position
--- @param fn fun(args: {ctx: Context, file?: ModifiedFile, src_change?: Change}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, search_downwards?: boolean, linenr_from_file?: boolean, linenr_offset?: number, args_key?: string} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - search_downwards Search downwards, instead of upwards
--- - linenr_from_file Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- - args_key Argument key that the change is stored at
--- @return function
function M.search_change(fn, opts)
  --- @param args? {ctx: Context, file?: ModifiedFile} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
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
        change = parsers.parse_change(line, linenr + idx - 1)
        if change then
          break
        end
      end
    else
      while linenr > 0 do
        change = parsers.parse_change(vim.fn.getbufoneline(largs.ctx.buf, linenr), linenr)
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

--- Search diff hunk that position
--- @param fn fun(args: {ctx: Context, file?: ModifiedFile, hunk: Hunk}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a filename is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, search_downwards?: boolean, linenr?: number, linenr_offset?: number, skip_past_change?: boolean, args_key?: string} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - search_downwards Search downwards, instead of upwards
--- - linenr Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- - args_key Argument key that the change is stored at
--- @return function
function M.search_hunk(fn, opts)
  --- @param args? {ctx: Context} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= largs.ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return
    end
    -- starting point for search, current lnie + offset
    local cursor_line = vim.api.nvim_win_get_cursor(winid)[1]
    local linenr = (lopts.linenr or cursor_line) + (lopts.linenr_offset or 0)
    local hunk
    if lopts.search_downwards then
      ---@diagnostic disable-next-line: param-type-mismatch
      for idx, line in ipairs(vim.fn.getbufline(largs.ctx.buf, linenr, "$")) do
        hunk = parsers.parse_hunk(line, linenr + idx - 1, 0)
        if hunk then
          break
        end
        local file = parsers.parse_filename(line, linenr + idx - 1)
        if file then
          break
        end
        local change = parsers.parse_change(line, linenr + idx - 1)
        if change then
          break
        end
      end
    else
      local uncount_removed_lines = 0
      while linenr > 0 do
        local line = vim.fn.getbufoneline(largs.ctx.buf, linenr)
        if vim.startswith(line, "-") then
          uncount_removed_lines = uncount_removed_lines + 1
        end
        hunk = parsers.parse_hunk(line, linenr, cursor_line - linenr - 1 - uncount_removed_lines)
        if hunk then
          break
        end
        local file = parsers.parse_filename(line, linenr)
        if file then
          break
        end
        local change = parsers.parse_change(line, linenr)
        if change and not lopts.skip_past_change then
          break
        end
        linenr = linenr - 1
      end
    end
    if hunk == nil and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("File data not found.", vim.log.levels.WARN)
      end
    else
      return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "hunk"] = hunk }))
    end
  end
end

--- Search filename that position
--- @param fn fun(args: {ctx: Context, file?: ModifiedFile, src_change?: Change}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a filename is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean, search_downwards?: boolean, linenr?: number, linenr_offset?: number, skip_past_change?: boolean, args_key?: string} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- - search_downwards Search downwards, instead of upwards
--- - linenr Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- - skip_past_change Skip search past the next change
--- - args_key Argument key that the change is stored at
--- @return function
function M.search_file(fn, opts)
  --- @param args? {ctx: Context} Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    if not largs.ctx then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("Context missing.", vim.log.levels.WARN)
      end
      return
    end
    local winid = vim.api.nvim_get_current_win()
    local bufid = vim.api.nvim_win_get_buf(winid)
    if bufid ~= largs.ctx.buf then
      -- somehow the incorrect window/buffer is being edited
      return
    end
    -- starting point for search, current lnie + offset
    local linenr = (lopts.linenr or vim.api.nvim_win_get_cursor(winid)[1]) + (lopts.linenr_offset or 0)
    local file
    if lopts.search_downwards then
      ---@diagnostic disable-next-line: param-type-mismatch
      for idx, line in ipairs(vim.fn.getbufline(largs.ctx.buf, linenr, "$")) do
        file = parsers.parse_filename(line, linenr + idx - 1)
        if file then
          break
        end
        local change = parsers.parse_change(line, linenr + idx - 1)
        if change and not lopts.skip_past_change then
          break
        end
      end
    else
      while linenr > 0 do
        local line = vim.fn.getbufoneline(largs.ctx.buf, linenr)
        file = parsers.parse_filename(line, linenr)
        if file then
          break
        end
        local change = parsers.parse_change(line, linenr)
        if change and not lopts.skip_past_change then
          break
        end
        linenr = linenr - 1
      end
    end
    if file == nil and not lopts.err_continue then
      if lopts.err_notify or lopts.err_notify == nil then
        vim.notify("File data not found.", vim.log.levels.WARN)
      end
    else
      return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "file"] = file }))
    end
  end
end

--- Tests validity of buffer, returns nil if buffer is not valid, otherwise the passed in buffer id
--- @param buf number Buffer ID
--- @return number?
function M.is_valid(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
end

return M
