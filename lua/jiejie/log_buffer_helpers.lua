local context = require("jiejie.context")
local parsers = require("jiejie.parsers")
local commands = require("jiejie.commands")

--- Opeations that help with extracting data from the log buffer
local M = {}

--- @class WithArgs
--- @field ctx Context Context
--- @field count? number Count if supplied to key press
--- @field cur_change? Change Current change
--- @field pos_change? Change Change at position
--- @field src_change? Change Source change
--- @field dst_change? Change Destination change
--- @field file? ModifiedFile Modified file
--- @field cur_file? ModifiedFile Modified file
--- @field hunk? Hunk Hunk that has been found
--- @field bookmark? string Bookmark
--- @field bookmarks? BookmarkTag[] Selection of bookmarks to choose from
--- @field tag? string Tag
--- @field tags? BookmarkTag[] Selection of tags to choose from - opts.tags must be set for tags to be used
--- @field force? boolean Sets force

--- @class WithOpts
--- @field err_notify? boolean Send notification is change is not found
--- @field err_continue? boolean Continue execution callback execution on error
--- @field args_key? string Argument key that the change is stored at

--- Adjust the displayed number of revisions
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {negate?: boolean} Options
--- - negate Negate count or pass it on as received
function M.with_count(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    local count = vim.v.count ~= 0 and vim.v.count or 1
    return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "count"] = (lopts.negate and -1 or 1) * count }))
  end
end

--- Add force to arguments
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts Options
--- @return function
function M.with_force(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "force"] = true }))
  end
end

--- Provide repository context
--- @param root string Root directory of repository
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts Options
--- @return function
function M.with_context(root, fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "ctx"] = context.get_context(root) }))
  end
end

--- Retrieve data about the change that the cursor is on
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts Options
--- @return function
function M.with_change_at_position(fn, opts)
  --- @param args? WithArgs Arguments
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {defualt_target?: string} Options
--- - defualt_target Default target change
--- @return function
function M.with_target_change(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {prompt?: string, tags?: boolean} Options
--- - prompt Prompt string
--- - tags Handle tags instead of bookmarks
--- @return function
function M.with_bookmark_or_tag(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {_local?: boolean, remote?: boolean, tags?: boolean, revisions?: string} Options
--- - tags List tags instead of bookmarks
--- - _local List local bookmarks - if nil, list local bookmarks
--- - remote List remote bookmarks - if nil, don't list remote bookmarks
--- - revision Get bookmarks that correspond to these local revisions, default all (::)
--- @return function
function M.with_bookmarks_or_tags(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
    local jujutsu = require("jiejie.jujutsu")
    local cmd = lopts.tags and "tag" or "bookmark"
    local _args = {
      "list",
      "-r",
      lopts.revisions or "::",
      "--sort",
      "committer-date-,author-date-,name",
      "-T",
      [[name ++ "†" ++ tracked ++ "‡" ++ present ++ "⌠" ++ remote ++ "⌡" ++ if(normal_target, normal_target.commit_id().short()) ++ "∫" ++ if(normal_target, normal_target.commit_id().short()) ++ "∬" ++ if(normal_target, normal_target.description().first_line()) ++ "\n"]],
    }
    if largs.src_change then
      _args = vim.list_extend(_args, { "-r", commands.get_change_id(largs.src_change) })
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
--- @return function
function M.with_file_at_position(fn, opts)
  --- @param args? WithArgs Arguments
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {search_downwards?: boolean, linenr_from_file?: boolean, linenr_offset?: number} Options
--- - search_downwards Search downwards, instead of upwards
--- - linenr_from_file Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- @return function
function M.search_change(fn, opts)
  --- @param args? WithArgs Arguments
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {search_downwards?: boolean, linenr?: number, linenr_offset?: number, skip_past_change?: boolean} Options
--- - search_downwards Search downwards, instead of upwards
--- - linenr Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- @return function
function M.search_hunk(fn, opts)
  --- @param args? WithArgs Arguments
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
--- @param fn fun(args?: WithArgs): boolean Callback function
--- and the extracted change information. The function is only called when a filename is found at the cursor position
--- @param opts? WithOpts | {search_downwards?: boolean, linenr?: number, linenr_offset?: number, skip_past_change?: boolean} Options
--- - search_downwards Search downwards, instead of upwards
--- - linenr Line number the search should start from, if not provided, the cursor position is used
--- - linenr_offset Offset that is added to line numer, e.g. 1 to start search in the next / previous line
--- - skip_past_change Skip search past the next change
--- @return function
function M.search_file(fn, opts)
  --- @param args? WithArgs Arguments
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
