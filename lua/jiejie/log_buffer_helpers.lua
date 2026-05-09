local context = require("jiejie.context")
local parsers = require("jiejie.parsers")
local api = require("jiejie.api")
local jujutsu = require("jiejie.jujutsu")
local config = require("jiejie.config")

--- Opeations that help with extracting data from the status log buffer
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
--- @field remote? string Git remote
--- @field tag? string Tag
--- @field tags? BookmarkTag[] Selection of tags to choose from - opts.tags must be set for tags to be used
--- @field force? boolean Sets force
--- @field view? LogView Log view

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

--- Request a specific git remote
--- @param fn fun(args?: WithArgs): boolean Callback function
--- @param opts? WithOpts | {prompt?: string} Options
--- - prompt Prompt string
--- - tags Handle tags instead of bookmarks
--- @return function
function M.with_remote(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
    local prompt = lopts.prompt or "Select remote: "
    jujutsu.cli(largs.ctx, "git", {
      args = { "remote", "list" },
      on_exit = vim.schedule_wrap(function(out)
        local remotes = {}
        for _, line in ipairs(vim.split(out.stdout or "", "\n")) do
          local elems = vim.split(line, " ")
          if #elems == 2 then
            remotes = vim.list_extend(remotes, { { name = elems[1], url = elems[2] } })
          end
        end
        if #remotes == 1 then
          fn(vim.tbl_extend("force", largs, { [lopts.args_key or "remote"] = remotes[1].name }))
        else
          vim.ui.select(remotes, {
            prompt = prompt,
            format_item = function(item)
              return item.name .. " " .. item.url
            end,
          }, function(remote, _)
            if not remote and not lopts.err_continue then
              if lopts.err_notify or lopts.err_notify == nil then
                vim.notify("Selection failed.", vim.log.levels.WARN)
              end
              return
            end
            if not remote then
              fn(largs)
            else
              fn(vim.tbl_extend("force", largs, { [lopts.args_key or "remote"] = remote.name }))
            end
          end)
        end
      end),
    })
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
    local ctx = context.get_context(root)
    assert(ctx, "Couldn't establish context")
    ctx.buf = vim.api.nvim_get_current_buf()
    return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "ctx"] = ctx }))
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
        fn(largs)
      else
        -- TODO: verify existence of id before passing it on + generate a proper Change object
        fn(vim.tbl_extend("force", largs, { [lopts.args_key or "dst_change"] = { id = target, id_short = target } }))
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
      if #bts == 1 then
        fn(vim.tbl_extend("force", largs, { [lopts.args_key or (lopts.tags and "tag" or "bookmark")] = bts[1].name }))
      else
        vim.ui.select(bts, {
          prompt = prompt,
          format_item = function(item)
            return item.name
              .. (item.remote and item.remote ~= "" and ("@" .. item.remote) or "")
              .. (item.id_short ~= "" and (" (" .. item.id_short .. ")") or item.id and (" (" .. item.id .. ")") or "")
              .. (not item.tracked and item.remote and item.remote ~= "" and " untracked!" or "")
              .. (item.description_first_line and (" " .. item.description_first_line) or "")
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
      end
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
--- @param opts? WithOpts | {remote?: boolean, tracked?: boolean, tags?: boolean, src_change?: Change, limit_to_change?: boolean, limit_to_branch?: boolean} Options
--- - tags: List tags instead of bookmarks
--- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
--- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
--- - src_change: Anchor point for bookmark selection, if missing, consider bookmarks on all (::) commits
--- - limit_to_change: Limits bookmark search to the current change
--- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::)
--- @return function
function M.with_bookmarks_or_tags(fn, opts)
  --- @param args? WithArgs Arguments
  --- @return boolean?
  return function(args)
    local largs = args or {}
    local lopts = opts or {}
    assert(largs.ctx, "Context not provided: ctx")
    local cmd = lopts.tags and "tag" or "bookmark"
    local _args = { "list" }
    local excluded_revset = config.get().excluded_revset
    if not lopts.tags then
      _args = vim.list_extend(_args, {
        "-r",
        "("
          .. ((lopts.src_change and lopts.limit_to_change and api.get_change_id(lopts.src_change)) or (lopts.src_change and lopts.limit_to_branch and ("::" .. api.get_change_id(
            lopts.src_change
          ) .. "- | " .. api.get_change_id(lopts.src_change) .. "+::")) or (lopts.src_change and (":: ~" .. api.get_change_id(lopts.src_change))) or "::")
          .. ")"
          .. (excluded_revset ~= "" and (" ~ (" .. excluded_revset .. ")") or ""),
        "--all-remotes",
        "--sort",
        "committer-date-,name",
      })
    elseif lopts.tags and lopts.limit_to_change then
      return fn(vim.tbl_extend("force", largs, {
        [lopts.args_key or (lopts.tags and "tags" or "bookmarks")] = vim.tbl_map(function(t)
          return {
            name = t,
            id = largs.src_change and largs.src_change.id,
            id_short = largs.src_change and largs.src_change.id_short,
            commit_id = largs.src_change and largs.src_change.commit_id,
          }
        end, largs.src_change and largs.src_change.tags or {}),
      }))
    end
    _args = vim.list_extend(_args, {
      "-T",
      [[name ++ "†" ++ tracked ++ "‡" ++ present ++ "⌠" ++ remote ++ "⌡" ++ if(normal_target, normal_target.change_id()) ++ "∫" ++ if(normal_target, normal_target.change_id().short()) ++ "∬" ++ if(normal_target, normal_target.description().first_line()) ++ "∮" ++ if(normal_target, normal_target.commit_id()) ++ "\n"]],
    })
    jujutsu.cli(largs.ctx, cmd, {
      args = _args,
      on_exit = vim.schedule_wrap(function(out)
        local bts = {}
        for _, line in ipairs(vim.split(out.stdout, "\n")) do
          local bt = parsers.parse_bookmark_or_tag(line)
          if bt and bt.present and bt.remote ~= "git" then
            if
              (lopts.remote == false and bt.remote and bt.remote ~= "")
              or (lopts.remote == true and not bt.remote and bt.remote == "")
              or (lopts.tracked == false and bt.tracked)
              or (lopts.tracked == true and not bt.tracked)
            then
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

--- Search change at position
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
--- @param buf number? Buffer ID
--- @return number?
function M.is_valid(buf)
  if buf and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
    return buf
  end
end

return M
