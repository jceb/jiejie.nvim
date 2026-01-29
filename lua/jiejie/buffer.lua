local context = require("jiejie.context")
local parsers = require("jiejie.parsers")
local log_diff = require("jiejie.log_diff")

--- Opeations that manipulate the buffer / window
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
--- @param opts? {err_notify?: boolean, err_continue?: boolean} Options
--- - err_notify Send notification is change is not found
--- - err_continue Continue execution callback execution on error
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
      return fn(vim.tbl_extend("force", largs, { src_change = change }))
    end
  end
end

--- Request a target change ID
--- @param fn fun(args: {ctx: Context, src_change: Change, dst_change?: Change}): boolean Callback that is called with Context
--- and the extracted change information. The function is only called when a change id is found at the cursor position
--- @param opts? {err_notify?: boolean, err_continue?: boolean} Options
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
    vim.ui.input({ prompt = "Target change (@-): " }, function(input)
      if input == nil and not lopts.err_continue then
        if lopts.err_notify or lopts.err_notify == nil then
          vim.notify("Target change ID nil.", vim.log.levels.WARN)
        end
        return
      end
      if input == "" or input == nil then
        return fn(largs)
      else
        -- TODO: verify existence of id before passing it on + generate a proper Change object
        return fn(vim.tbl_extend("force", largs, { dst_change = { id = input, id_short = input } }))
      end
    end)
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
--- @param fn fun(args: {ctx: Context, file?: ModifiedFile, hunk_linenr: number}): boolean Callback that is called with Context
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
    local linenr = (lopts.linenr or vim.api.nvim_win_get_cursor(winid)[1]) + (lopts.linenr_offset or 0)
    local hunk
    if lopts.search_downwards then
      for idx, line in ipairs(vim.fn.getbufline(largs.ctx.buf, linenr, "$")) do
        hunk = parsers.parse_hunk(line) and linenr + idx - 1
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
      while linenr > 0 do
        local line = vim.fn.getbufoneline(largs.ctx.buf, linenr)
        hunk = parsers.parse_hunk(line) and linenr
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

--- Create a header
--- @param key string Header key
--- @param value string Header value
function M.create_header(key, value)
  return key .. ": " .. value
end

--- Render log output in buffer and return cursor position of current change
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param headers? string[] headers added before the data
--- @return table
function M.render(ctx, data, headers)
  if headers and #headers > 0 then
    M.buf_set_lines(ctx, vim.list_extend(headers, { "" }), 0, -1)
  end
  local headers_offset = headers and #headers or 0
  if data[#data] == "" then
    data[#data] = nil
  end
  M.buf_set_lines(ctx, data, -1, -1)
  for i = 1, #data do
    local match = vim.regex("^[─╯│ ]*@  \\zs"):match_str(data[i])
    if match then
      ctx.curpos = { i + headers_offset, match }
      break
    end
  end
  return ctx.curpos
end

--- Set lines in current buffer
--- @param ctx Context context
--- @param data string[] jj log output to display
--- @param start number jj log output to display
--- @param end_ number jj log output to display
function M.buf_set_lines(ctx, data, start, end_)
  local modifiable = vim.bo[ctx.buf].modifiable
  local readonly = vim.bo[ctx.buf].readonly
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  vim.api.nvim_buf_set_lines(ctx.buf, start and start or 0, end_ and end_ or -1, false, data)
  vim.bo[ctx.buf].readonly = modifiable
  vim.bo[ctx.buf].modifiable = readonly
end

--- Render file contents
--- @param ctx Context context
--- @param data string[] jj log output to display
function M.render_file(ctx, data)
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.focus(ctx, vertical)
  ctx.buf = M.is_valid(ctx.buf)
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
    local filename = parsers.join_url({
      root = ctx.root,
      revision = "repo",
      path = "index",
    })
    if vertical then
      vim.cmd.vs(filename)
    else
      vim.cmd.sp(filename)
    end
    return ctx
  end
  local bufid = vim.api.nvim_get_current_buf()
  if bufid == ctx.buf then
    return ctx
  end
  local tabid = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  for _i, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(tabid, winid)
      return ctx
    end
  end
  if vertical then
    vim.cmd.vs(ctx.buf)
  else
    vim.cmd.sp(ctx.buf)
  end
  M.setup_buffer(ctx)
  return ctx
end

--- Setup log buffer
--- @param ctx Context context
--- @return Context
function M.setup_buffer(ctx)
  vim.bo[ctx.buf].buftype = "nofile"
  -- vim.bo[ctx.buf].buftype = "nowrite"
  vim.bo[ctx.buf].modeline = false
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  vim.bo[ctx.buf].bufhidden = "delete"
  vim.bo[ctx.buf].filetype = "jiejie"
  vim.bo[ctx.buf].softtabstop = 4
  vim.bo[ctx.buf].tabstop = 4
  vim.bo[ctx.buf].undolevels = -1
  vim.bo[ctx.buf].swapfile = false
  local winid = vim.api.nvim_get_current_win()
  vim.wo[winid][0].number = false
  vim.wo[winid][0].foldmethod = "syntax"
  vim.wo[winid][0].foldtext = "v:folddashes.substitute(substitute(getline(v:foldstart),'⌠.*','','g'), '[†‡]', '', 'g')"
  vim.wo[winid][0].relativenumber = false
  vim.wo[winid][0].conceallevel = 2
  vim.wo[winid][0].concealcursor = "nvic"
  vim.wo[winid][0].listchars = "tab:  "
  -- Place cursor on the current change
  if ctx.curpos then
    vim.api.nvim_win_set_cursor(winid, ctx.curpos)
  end
  for _, key in ipairs({ "a", "A", "c", "C", "d", "D", "i", "I", "r", "R", "s", "S", "x", "X", "p", "P" }) do
    -- disable keys that would cause a modification of the buffer
    vim.keymap.set("", key, "<Nop>", { buffer = true })
  end
  local commands = require("jiejie.commands")
  local with_root_context = function(fn)
    return M.with_context(ctx.root, fn)
  end
  --- @type table<number, {key: string, fn: fun(), plug: string, desc: string}>
  local nmaps = {
    --

    -- Navigation maps {{{1
    {
      key = "<CR>",
      plug = "<Plug>(jiejie-<CR>)",
      fn = with_root_context(function(_args)
        if
          not M.with_change_at_position(function(args)
            commands.change_edit(args.ctx, args.src_change)
            return true
          end)({ ctx = _args.ctx })
        then
          M.search_file(M.search_change(function(args)
            commands.file_edit(args.ctx, args.file, args.src_change, { previous_win = true })
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Edit change or file under the cursor",
    },
    {
      key = "!<CR>",
      plug = "<Plug>(jiejie-!<CR>)",
      fn = with_root_context(function(_args)
        if
          not M.with_change_at_position(function(args)
            commands.change_edit(args.ctx, args.src_change, M.with_direct_force())
            return true
          end)({ ctx = _args.ctx })
        then
          M.search_file(M.search_change(function(args)
            commands.file_edit(args.ctx, args.file, args.src_change, { previous_win = true })
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Edit immutable change or file under the cursor",
    },
    {
      key = "o",
      plug = "<Plug>(jiejie-o)",
      fn = with_root_context(M.search_file(M.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.sp })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new split",
    },
    {
      key = "gO",
      plug = "<Plug>(jiejie-gO)",
      fn = with_root_context(M.search_file(M.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.vnew })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "O",
      plug = "<Plug>(jiejie-O)",
      fn = with_root_context(M.search_file(M.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.tabnew })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "i",
      plug = "<Plug>(jiejie-i)",
      fn = with_root_context(
        M.search_file(
          M.search_change(
            M.search_hunk(
              M.search_file(
                M.search_change(function(args)
                  local _winid = vim.api.nvim_get_current_win()
                  if args.cur_file and args.cur_change then
                    if not log_diff.diff_shown(args.cur_file, args.cur_change) then
                      log_diff.diff_show(args.ctx, args.cur_file, args.cur_change)
                      vim.api.nvim_win_set_cursor(_winid, { args.cur_file.linenr + 1, 0 })
                      return true
                    elseif args.hunk and args.hunk > args.cur_file.linenr then
                      if args.file and args.hunk < args.file.linenr then
                        if args.src_change and args.hunk < args.src_change.linenr then
                          vim.api.nvim_win_set_cursor(_winid, { args.hunk, 0 })
                          return true
                        end
                      end
                    end
                  end
                  local pos = { math.min(args.file and args.file.linenr or math.huge, args.src_change and args.src_change.linenr or math.huge), 0 }
                  if pos[1] ~= math.huge then
                    vim.api.nvim_win_set_cursor(_winid, pos)
                  end
                  return true
                end, { search_downwards = true, err_continue = true, linenr_offset = 1 }),
                { search_downwards = true, err_continue = true, linenr_offset = 1, skip_past_change = true }
              ),
              { search_downwards = true, err_continue = true, linenr_offset = 1 }
            ),
            { args_key = "cur_change", err_continue = true }
          ),
          { args_key = "cur_file", err_continue = true }
        )
      ),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "[[",
      plug = "<Plug>(jiejie-[[)",
      fn = with_root_context(
        M.search_file(
          M.search_change(
            M.search_file(
              M.search_change(function(args)
                local _winid = vim.api.nvim_get_current_win()
                local cur_change_linenr = args.cur_change and args.cur_change.linenr or 1
                local linenr = 1
                if not args.cur_file then
                  -- Cursor is on a change, jump to next change
                  linenr = args.src_change and args.src_change.linenr or args.cur_change and args.cur_change.linenr or 1
                else
                  -- Cursor is on a file
                  if args.file then
                    if args.file.linenr > cur_change_linenr then
                      -- File is within the current change
                      linenr = args.file.linenr
                    else
                      -- File is in the next change, jump to the current change
                      linenr = cur_change_linenr
                    end
                  else
                    -- File is in the next change, jump to the current change
                    linenr = cur_change_linenr
                  end
                end
                local pos = { linenr, 0 }
                vim.api.nvim_win_set_cursor(_winid, pos)
                return true
              end, {
                linenr_from_file = true,
                -- could be -1, if no next file is discovered, we could skip past the actual heading
                linenr_offset = -1,
                err_continue = true,
              }),
              { linenr_offset = -1, skip_past_change = true, err_continue = true }
            ),
            { args_key = "cur_change", err_continue = true }
          ),
          { args_key = "cur_file", err_continue = true }
        )
      ),
      desc = "Jump [count] sections backward",
    },
    {
      key = "]]",
      plug = "<Plug>(jiejie-]])",
      fn = with_root_context(
        M.search_file(
          M.search_change(
            M.search_file(
              M.search_change(function(args)
                local _winid = vim.api.nvim_get_current_win()
                local linenr = 1
                local src_change_linenr = args.src_change and args.src_change.linenr or 1
                if not args.cur_file then
                  -- Cursor is on a change, jump to next change
                  linenr = args.src_change and args.src_change.linenr or args.cur_change and args.cur_change.linenr or 1
                else
                  -- Cursor is on a file
                  if args.file then
                    if args.file.linenr < src_change_linenr then
                      -- File is within the current change
                      linenr = args.file.linenr
                    else
                      -- File is in the next change, jump to the next change
                      linenr = src_change_linenr
                    end
                  else
                    -- File is in the next change, jump to the next change
                    linenr = src_change_linenr
                  end
                end
                local pos = { linenr, 0 }
                vim.api.nvim_win_set_cursor(_winid, pos)
                return true
              end, {
                search_downwards = true,
                linenr_from_file = false,
                -- could be 1, if no next file is discovered, we could skip past the actual heading
                linenr_offset = 1,
                err_continue = true,
              }),
              { search_downwards = true, linenr_offset = 1, skip_past_change = true, err_continue = true }
            ),
            { args_key = "cur_change", err_continue = true }
          ),
          { args_key = "cur_file", err_continue = true }
        )
      ),
      desc = "Jump [count] sections forward",
    },

    -- Diff maps {{{1
    {
      key = "=",
      plug = "<Plug>(jiejie-=)",
      fn = with_root_context(M.search_file(
        M.search_change(function(args)
          commands.toggle_diff(args.ctx, args.src_change, { file = args.file })
          return true
        end),
        { err_continue = true }
      )),
      desc = "Toggle an inline diff of the change or file under the cursor",
    },

    -- Commit maps {{{1
    {
      key = "cc",
      plug = "<Plug>(jiejie-cc)",
      fn = with_root_context(M.search_file(
        M.search_change(function(args)
          if args.src_change.status ~= commands.CHANGE_STATUS.CURRENT then
            vim.notify("Commit not possible, curser is not on the currently edited change", vim.log.levels.ERROR)
            return false
          end
          commands.change_commit(args.ctx, { files = { args.file and args.file.filename or nil } })
          return true
        end),
        { err_continue = true }
      )),
      desc = "Commit currently edited change and create a new change",
    },
    {
      key = "cn",
      plug = "<Plug>(jiejie-cn)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_new(args.ctx, args.src_change)
        return true
      end)),
      desc = "Create a new change after the change under the cursor",
    },
    {
      key = "crc",
      plug = "<Plug>(jiejie-crc)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_revert(args.ctx, args.src_change)
        return true
      end)),
      desc = "Revert the commit under the cursor",
    },
    {
      key = "cs",
      plug = "<Plug>(jiejie-cs)",
      fn = with_root_context(M.search_file(
        M.search_change(function(args)
          commands.change_squash(args.ctx, args.src_change, { files = { args.file and args.file.filename or nil } })
          return true
        end),
        { err_notify = true, err_continue = true }
      )),
      desc = "Squash current changes into it's parent",
    },
    {
      key = "!cs",
      plug = "<Plug>(jiejie-!cs)",
      fn = with_root_context(M.search_file(
        M.search_change(function(args)
          commands.change_squash(args.ctx, args.src_change, M.with_direct_force({ files = { args.file and args.file.filename or nil } }))
          return true
        end),
        { err_notify = false, err_continue = true }
      )),
      desc = "Squash current changes into it's immutable parent",
    },
    {
      key = "cS",
      plug = "<Plug>(jiejie-cS)",
      fn = with_root_context(M.search_file(
        M.search_change(M.with_target_change(function(args)
          commands.change_squash(args.ctx, args.src_change, { dst_change = args.dst_change, files = { args.file and args.file.filename or nil } })
          return true
        end, { err_notify = false })),
        { err_notify = false, err_continue = true }
      )),
      desc = "Squash current changes into the selecated change",
    },
    {
      key = "!cS",
      plug = "<Plug>(jiejie-!cS)",
      fn = with_root_context(M.search_file(
        M.search_change(M.with_target_change(function(args)
          commands.change_squash(
            args.ctx,
            args.src_change,
            M.with_direct_force({ dst_change = args.dst_change, files = { args.file and args.file.filename or nil } })
          )
          return true
        end, { err_notify = false, err_continue = true })),
        { err_notify = false, err_continue = true }
      )),
      desc = "Squash current changes into the immutuable selecated change",
    },
    {
      key = "de",
      plug = "<Plug>(jiejie-de)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change)
        return true
      end)),
      desc = "Edit change description",
    },
    {
      key = "!de",
      plug = "<Plug>(jiejie-!de)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, M.with_direct_force())
        return true
      end)),
      desc = "Edit immutable change description",
    },
    {
      key = "dd",
      plug = "<Plug>(jiejie-dd)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, { firstline = true })
        return true
      end)),
      desc = "Edit first line of change description",
    },
    {
      key = "!dd",
      plug = "<Plug>(jiejie-!dd)",
      fn = with_root_context(M.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, M.with_direct_force({ firstline = true }))
        return true
      end)),
      desc = "Edit first line of an immutable change description",
    },
    {
      key = "cU",
      plug = "<Plug>(jiejie-cU)",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, { "op", "revert" })
        return true
      end),
      desc = "Revert last operation",
    },
    {
      key = "X",
      plug = "<Plug>(jiejie-X)",
      fn = with_root_context(function(_args)
        if
          not M.with_change_at_position(function(args)
            commands.change_abandon(args.ctx, args.src_change)
            return true
          end, { err_notify = false })({ ctx = _args.ctx })
        then
          M.search_file(M.search_change(function(args)
            commands.file_restore(args.ctx, args.file, args.src_change)
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Abandon change or restore file from parent change",
    },
    {
      key = "!X",
      plug = "<Plug>(jiejie-!X)",
      fn = with_root_context(function(_args)
        if
          not M.with_change_at_position(function(args)
            commands.change_abandon(args.ctx, args.src_change, M.with_direct_force())
            return true
          end, { err_notify = false })({ ctx = _args.ctx })
        then
          M.search_file(M.search_change(function(args)
            commands.file_restore(args.ctx, args.file, args.src_change, M.with_direct_force())
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Abandon immutuable change or restore file from parent change",
    },

    -- Git maps {{{1
    {
      key = "gp",
      plug = "<Plug>(jiejie-gp)",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, { "git", "fetch" })
        return true
      end),
      desc = "Fetch changes from remote",
    },
    {
      key = "gP",
      plug = "<Plug>(jiejie-gP)",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, { "git", "push" })
        return true
      end),
      desc = "Push changes to remote",
    },

    -- Miscellaneous maps {{{1
    {
      key = "g?",
      plug = "<Plug>(jiejie-g?)",
      fn = commands.show_help,
      desc = "Show help",
    },
    {
      key = "r",
      plug = "<Plug>(jiejie-r)",
      fn = with_root_context(function(args)
        local _winid = vim.api.nvim_get_current_win()
        local pos = vim.api.nvim_win_get_cursor(_winid)
        commands.reload_log(args.ctx, function()
          vim.notify("Log reloaded", vim.log.levels.INFO)
          vim.api.nvim_win_set_cursor(_winid, pos)
        end)
      end),
      desc = "Reload log",
    },
    {
      key = "<C-a>",
      plug = "<Plug>(jiejie-<c-a>)",
      fn = with_root_context(M.with_count(function(args)
        commands.log_revisions_adjust(args.ctx, { adjustment = args.count })
        return true
      end)),
      desc = "Increase the number of displayed revisions in log",
    },
    {
      key = "<C-x>",
      plug = "<Plug>(jiejie-<c-x>)",
      fn = with_root_context(M.with_count(function(args)
        commands.log_revisions_adjust(args.ctx, { adjustment = args.count })
        return true
      end, true)),
      desc = "Decrease the number of displayed revisions in log",
    },
  }
  for _i, value in ipairs(nmaps) do
    vim.keymap.set("n", value.key, value.plug, { desc = value.desc, nowait = true, buffer = true })
    vim.keymap.set("n", value.plug, value.fn, { desc = value.desc, buffer = true })
  end
  require("jiejie.log_diff").setup_buffer(ctx)
  require("jiejie.log_dirty_check").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
