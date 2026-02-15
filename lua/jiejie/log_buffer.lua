local parsers = require("jiejie.parsers")
local log_diff = require("jiejie.log_diff")
local helpers = require("jiejie.log_buffer_helpers")
local log_view = require("jiejie.log_view")
local jujutsu = require("jiejie.jujutsu")

--- Opeations that manipulate the buffer / window
local M = {}

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
--- @param start? number jj log output to display
--- @param end_? number jj log output to display
function M.buf_set_lines(ctx, data, start, end_)
  assert(ctx, "Context not provided: ctx")
  assert(data, "Data not provided: data")
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
--- @param opts? {filetype?: string} Options
function M.render_file(ctx, data, opts)
  assert(ctx, "Context not provided: ctx")
  assert(data, "Data not provided: data")
  local lopts = opts or {}
  vim.bo[ctx.buf].modifiable = true
  vim.bo[ctx.buf].readonly = false
  if data[#data] == "" then
    data[#data] = nil
  end
  vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, data)
  vim.bo[ctx.buf].readonly = true
  vim.bo[ctx.buf].modifiable = false
  if lopts.filetype then
    vim.bo[ctx.buf].filetype = lopts.filetype
  end
end

--- Focus buffer in current tab
--- @param ctx Context context
--- @param vertical boolean Split window vertically, instead of horizontally
--- @return Context
function M.focus(ctx, vertical)
  ctx.buf = helpers.is_valid(ctx.buf)
  local filename = parsers.join_url({
    root = ctx.root,
    revision = "repo",
    path = "index",
  })
  if ctx.buf == nil then
    -- If buffer doesn't exist, open a new one
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
  local wins = vim.api.nvim_tabpage_list_wins(0)
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(0, winid)
      return ctx
    end
  end
  if vertical then
    vim.cmd.vs(filename)
  else
    vim.cmd.sp(filename)
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
  local api = require("jiejie.api")
  --- @type table<string, fun(opts?: {}): fun()>
  local fns = {
    --- @param opts {close_current_window?: boolean}
    --- - close_current_window: Close the current window in addition to the preview window
    q = function(opts)
      local lopts = opts or {}
      return helpers.with_count(function(_)
        for _, _winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.wo[_winid].previewwindow then
            local bufid = vim.api.nvim_win_get_buf(_winid)
            -- close preview window if it has filetype jiejie_change
            if vim.bo[bufid].filetype == "jiejie_change" then
              vim.api.nvim_win_close(_winid, true)
            end
          end
        end
        if lopts.close_current_window then
          vim.api.nvim_win_close(0, true)
        end
        return true
      end)
    end,
    --- @param opts {negate?: boolean}
    --- - negate: Negate count
    ctrl_a = function(opts)
      local lopts = opts or {}
      return helpers.with_count(function(args)
        api.log_revisions_adjust(args.ctx, { adjustment = args.count })
        return true
      end, { negate = lopts.negate })
    end,
    --- @param opts {split_direction?: SplitDirection, diff_commit_under_cursor?: boolean}
    --- - split_direction: Split direction
    --- - diff_commit_under_cursor: Diff commit under against its parents instead of diffing against @
    dd = function(opts)
      return helpers.search_file(helpers.search_change(function(args)
        local lopts = opts or {}
        --- @type RepositoryPath[]
        local files = {}
        if args.src_change.current_working_copy or lopts.diff_commit_under_cursor then
          table.insert(files, { path = args.file.filename, change = args.src_change })
          local ancestors = api.get_ancestors(ctx, args.src_change)
          for _, change in ipairs(ancestors) do
            table.insert(files, { path = args.file.filename, change = change })
          end
        else
          --- @type Change
          ---@diagnostic disable-next-line: missing-fields
          local working_copy_change = api.construct_dummy_change("@")
          table.insert(files, { path = args.file.filename, change = working_copy_change })
          table.insert(files, { path = args.file.filename, change = args.src_change })
        end
        api.diff_split(args.ctx, files, { split_direction = lopts.split_direction, previous_win = true, open_first_file = true })
        return true
      end))
    end,
    --- @param opts {split_direction?: SplitDirection}
    --- - split_direction: Split direction
    o = function(opts)
      return helpers.search_file(helpers.search_change(function(args)
        local lopts = opts or {}
        log_diff.diff_close(args.ctx)
        api.object_edit(args.ctx, args.file.filename, args.src_change, { edit_cmd = api.SPLIT_DIRECTION_FN[lopts.split_direction] })
        return true
      end))
    end,
    --- @param opts {rebase_tree?: boolean, revisions?: string, with_change?: number}
    --- - rebase_tree: Rebase tree, if false rebase just the commit
    --- - revisions Get bookmarks that correspond to these local revisions, default all (::)
    --- - with_change 0 (default): use change under cursor, 1: prompt for change id, 3: prompt for bookmark
    rr = function(opts)
      local lopts = opts or {}
      local use_change = function(fn)
        if lopts.with_change == 2 ^ 1 then
          return helpers.with_target_change(fn)
        elseif lopts.with_change == 2 ^ 2 then
          return helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(fn), { revisions = lopts.revisions or "::" })
        else
          return helpers.search_change(fn, { args_key = "dst_change" })
        end
      end
      return use_change(
        --- @param args? WithArgs Callback function
        --- @return boolean
        function(args)
          local src_change = api.construct_dummy_change("@")
          local dst_change = lopts.with_change == 2 ^ 2 and api.construct_dummy_change(args.bookmark) or args.dst_change
          if lopts.with_change == 2 ^ 2 then
            dst_change.immutable = false
          end
          api.cli(args.ctx, "rebase", {
            args = jujutsu.ignore_immtuable({
              lopts.rebase_tree and "-s" or "-r",
              api.get_change_id(src_change),
              "-d",
              ---@diagnostic disable-next-line: param-type-mismatch dst_change is always set
              api.get_change_id(dst_change),
            }, { force = args.force }),
            on_exit = function()
              ---@diagnostic disable-next-line: param-type-mismatch dst_change is always set
              vim.notify("Rebased change " .. api.get_change_id(src_change, true) .. " onto " .. api.get_change_id(dst_change, true), vim.log.levels.INFO)
            end,
          })
          return true
        end
      )
    end,
    --- @param opts {commit_id?: boolean, message_or_filename?: boolean}
    --- - commit_id: Copy commit id or else the change id if not message_or_filename
    --- - message_or_filename: Copy commit message or file name
    yy = function(opts)
      local lopts = opts or {}
      local locate = function(fn)
        if lopts.message_or_filename then
          return helpers.with_file_at_position(helpers.with_change_at_position(fn, { err_continue = true }), { err_continue = true })
        else
          return helpers.search_change(fn)
        end
      end
      return locate(function(args)
        local copy
        local copied = ""
        if lopts.message_or_filename then
          if args.file then
            copy = args.file.filename
            copied = "filename"
          else
            if args.src_change then
              copy = args.src_change.description_first_line
              copied = "description"
            end
          end
        else
          if lopts.commit_id then
            copy = args.src_change.commit_id
            copied = "commit id"
          else
            copy = api.get_change_id(args.src_change, true)
            copied = "change id"
          end
        end
        if copy then
          vim.cmd("let @" .. vim.v.register .. '="' .. vim.fn.fnameescape(copy) .. '"')
          vim.notify("Yanked " .. copied .. " " .. copy .. (vim.v.register ~= '"' and ' into "' .. vim.v.register or ""), vim.log.levels.INFO)
        else
          vim.fn.feedkeys(vim.v.count1 .. '"' .. vim.v.register .. "yy", "n")
        end
        return true
      end)
    end,
  }
  --- @type table<number, {key: string, fn: fun(args?: WithArgs), desc: string, with_force: boolean, with_allow_backwards?: boolean}>
  local nmaps = {
    --

    -- Navigation maps {{{1
    {
      key = "<CR>",
      fn = helpers.with_change_at_position(
        helpers.search_hunk(
          helpers.search_file(
            helpers.search_change(function(args)
              if args.pos_change then
                api.change_edit(args.ctx, args.pos_change, { force = args.force })
              elseif args.file then
                log_diff.diff_close(args.ctx)
                api.object_edit(args.ctx, args.file.filename, args.src_change, { previous_win = true, hunk = args.hunk })
              else
                vim.schedule(function()
                  vim.notify("No file or change found under the curor", vim.log.levels.WARN)
                end)
              end
              return true
            end),
            { err_continue = true }
          ),
          { err_continue = true }
        ),
        { err_continue = true, args_key = "pos_change" }
      ),
      with_force = true,
      desc = "Edit change or file under the cursor",
    },
    {
      key = "o",
      fn = fns.o({ split_direction = api.SPLIT_DIRECTION.horizontal }),
      desc = "Open the file or jiejie-object under the cursor in a new split",
    },
    {
      key = "gO",
      fn = fns.o({ split_direction = api.SPLIT_DIRECTION.vertical }),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "O",
      fn = fns.o({ split_direction = api.SPLIT_DIRECTION.tab }),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "i",
      fn = helpers.search_file(
        helpers.search_change(
          helpers.search_hunk(
            helpers.search_file(
              helpers.search_change(function(args)
                local count = vim.v.count
                local _winid = vim.api.nvim_get_current_win()
                local linenr
                if args.cur_file and args.cur_change then
                  if not log_diff.diff_shown(args.cur_file, args.cur_change) then
                    log_diff.diff_show(args.ctx, args.cur_file, args.cur_change)
                    linenr = args.cur_file.linenr + 1
                  elseif args.hunk and args.hunk.linenr > args.cur_file.linenr then
                    if args.file and args.hunk.linenr < args.file.linenr then
                      if args.src_change and args.hunk.linenr < args.src_change.linenr then
                        linenr = args.hunk.linenr
                      end
                    end
                  end
                end
                if not linenr then
                  linenr = math.min(args.file and args.file.linenr or math.huge, args.src_change and args.src_change.linenr or math.huge)
                end
                local pos = { linenr, 0 }
                if pos[1] ~= math.huge then
                  vim.api.nvim_win_set_cursor(_winid, pos)
                  if count > 1 then
                    vim.fn.feedkeys((count - 1) .. "i")
                  end
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
      ),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "K",
      fn = helpers.search_change(function(args)
        api.object_edit(args.ctx, nil, args.src_change, { edit_cmd = vim.cmd.pedit })
        return true
      end),
      desc = "Open change under the cursor",
    },
    {
      key = "[[",
      fn = helpers.search_file(
        helpers.search_change(
          helpers.search_file(
            helpers.search_change(function(args)
              local count = vim.v.count
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
              if count > 1 then
                vim.fn.feedkeys((count - 1) .. "[[")
              end
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
      ),
      desc = "Jump [count] sections backward",
    },
    {
      key = "]]",
      fn = helpers.search_file(
        helpers.search_change(
          helpers.search_file(
            helpers.search_change(function(args)
              local count = vim.v.count
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
              if count > 1 then
                vim.fn.feedkeys((count - 1) .. "]]")
              end
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
      ),
      desc = "Jump [count] sections forward",
    },

    -- Diff maps {{{1
    {
      key = "=",
      fn = helpers.search_file(
        helpers.search_change(function(args)
          api.toggle_diff(args.ctx, args.src_change, { file = args.file })
          return true
        end),
        { err_continue = true }
      ),
      desc = "Toggle an inline diff of the change or file under the cursor",
    },
    {
      key = "dD",
      fn = fns.dd({ diff_commit_under_cursor = true }),
      desc = "Perform a :Jdiffsplit on the file and change under the cursor.",
    },
    {
      key = "dd",
      fn = fns.dd(),
      desc = "Perform a :Jdiffsplit on the file under the cursor and change @.",
    },
    {
      key = "dV",
      fn = fns.dd({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.vertical }),
      desc = "Perform a :Jvdiffsplit on the file and change under the cursor.",
    },
    {
      key = "dv",
      fn = fns.dd({ split_direction = api.SPLIT_DIRECTION.vertical }),
      desc = "Perform a :Jvdiffsplit on the file under the cursor and change @.",
    },
    {
      key = "dH",
      fn = fns.dd({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
      desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
    },
    {
      key = "dh",
      fn = fns.dd({ split_direction = api.SPLIT_DIRECTION.horizontal }),
      desc = "Perform a :Jhdiffsplit on the file under the cursor and change @.",
    },
    {
      key = "dS",
      fn = fns.dd({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
      desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
    },
    {
      key = "ds",
      fn = fns.dd({ split_direction = api.SPLIT_DIRECTION.horizontal }),
      desc = "Perform a :Jhdiffsplit on the file under the cursor and change @.",
    },
    {
      key = "dq",
      fn = function(args)
        log_diff.diff_close(args.ctx)
      end,
      desc = "Close all but the currently focused diff buffer, and invoke :diffoff!",
    },
    {
      key = "d?",
      fn = function()
        api.show_help("d")
      end,
      desc = "Show diff maps help",
    },

    -- Commit maps {{{1
    {
      key = "c<space>",
      fn = function()
        vim.fn.feedkeys(":Jj commit ", "n")
      end,
      desc = 'Populate command line with ":Jj commit "',
    },
    {
      key = "cbc",
      fn = helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "bookmark", {
          args = { "create", "-r", api.get_change_id(args.src_change), args.bookmark },
          on_exit = function()
            vim.notify("Bookmark created: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end)),
      desc = "Create new bookmark at change under the cursor",
    },
    {
      key = "cbX",
      fn = helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end))),
      desc = "Delete bookmark including remote boomark",
    },
    {
      key = "cbx",
      fn = helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end))),
      desc = "Delete bookmark including remote boomark at change under the cursor",
    },
    {
      key = "cbF",
      fn = helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end))),
      desc = "Forget bookmark locally keeping the remote intact",
    },
    {
      key = "cbf",
      fn = helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end))),
      desc = "Forget bookmark locally keeping the remote intact at change under the cursor",
    },
    {
      key = "cbM",
      fn = helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        api.bookmark_move(args.ctx, args.src_change, args.bookmark, { force = args.force })
        return true
      end))),
      with_force = true,
      desc = "Move bookmark one of all the available bookmarks to change under the cursor",
    },
    {
      key = "cbm",
      fn = helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          api.bookmark_move(args.ctx, args.src_change, args.bookmark, { force = args.force })
          return true
        end)),
        { revisions = "::@" }
      ),
      with_force = true,
      desc = "Move bookmark from the current branch to change under the cursor",
    },
    {
      key = "cbr",
      fn = helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        helpers.with_bookmark_or_tag(function(_args)
          api.cli(args.ctx, "bookmark", {
            args = { "rename", args.bookmark, _args.bookmark },
            on_exit = function()
              vim.notify("Bookmark renamed: " .. args.bookmark, vim.log.levels.INFO)
            end,
          })
          return true
        end, { prompt = "Enter new name: " })({ ctx = args.ctx })
        return true
      end))),
      desc = "Rename bookmark at change under the cursor",
    },
    {
      key = "cc",
      fn = helpers.search_file(
        helpers.search_change(function(args)
          if not args.src_change.current_working_copy then
            vim.notify("Commit not possible, curser is not on the currently edited change", vim.log.levels.ERROR)
            return false
          end
          api.change_commit(args.ctx, { files = { args.file and args.file.filename or nil } })
          return true
        end),
        { err_continue = true }
      ),
      desc = "Commit currently edited change and create a new change",
    },
    {
      key = "cD",
      fn = helpers.search_change(helpers.with_target_change(function(args)
        api.cli(args.ctx, "duplicate", {
          args = jujutsu.ignore_immtuable({ "-d", api.get_change_id(args.dst_change), api.get_change_id(args.src_change) }, { force = args.force }),
          on_exit = function()
            vim.notify(
              "Duplicated change " .. api.get_change_id(args.src_change, true) .. " onto " .. api.get_change_id(args.dst_change, true),
              vim.log.levels.INFO
            )
          end,
        })
        return true
      end, { err_notify = false, defualt_target = "@" })),
      with_force = true,
      desc = "Duplicate change under the cursor",
    },
    {
      key = "ce",
      fn = helpers.search_change(function(args)
        api.change_describe(args.ctx, args.src_change, { force = args.force })
        return true
      end),
      with_force = true,
      desc = "Edit change description",
    },
    {
      key = "cd",
      fn = helpers.search_change(function(args)
        api.change_describe(args.ctx, args.src_change, { firstline = true, force = args.force })
        return true
      end),
      with_force = true,
      desc = "Edit first line of change description",
    },
    {
      key = "yC",
      fn = fns.yy({ commit_id = true }),
      desc = "Copy commit id under the cursor",
    },
    {
      key = "yc",
      fn = fns.yy({ commit_id = false }),
      desc = "Copy change id under the cursor",
    },
    {
      key = "yy",
      fn = fns.yy({ message_or_filename = true }),
      desc = "Copy commit message or file name under the cursor",
    },
    {
      key = "cn",
      fn = helpers.search_change(function(args)
        api.change_new(args.ctx, args.src_change, { force = args.force })
        return true
      end),
      with_force = true,
      desc = "Create a new change after the change under the cursor",
    },
    {
      key = "s<space>",
      fn = helpers.search_change(function(args)
        vim.fn.feedkeys(":Jj squash -f " .. api.get_change_id(args.src_change, true) .. " ", "n")
        return true
      end),
      desc = 'Populate command line with ":Jj squash "',
    },
    {
      key = "cR",
      fn = helpers.search_change(function(args)
        api.change_revert(args.ctx, args.src_change)
        vim.notify("Change reverted: " .. args.src_change.id_short, vim.log.levels.INFO)
        return true
      end),
      desc = "Revert the change under the cursor",
    },
    {
      key = "cs",
      fn = helpers.search_file(
        helpers.search_change(function(args)
          local src_change, dst_change
          if not args.src_change.current_working_copy then
            src_change = api.construct_dummy_change("@")
            dst_change = args.src_change
          else
            src_change = args.src_change
          end
          api.change_squash(
            args.ctx,
            ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
            src_change,
            { files = { args.src_change.current_working_copy and args.file and args.file.filename or nil }, dst_change = dst_change, force = args.force }
          )
          return true
        end),
        { err_notify = true, err_continue = true }
      ),
      with_force = true,
      desc = "Squash current changes into it's parent or into the change under the cursor if the cursor is not on the currently edited changed",
    },
    {
      key = "cS",
      fn = helpers.search_file(
        helpers.search_change(helpers.with_target_change(function(args)
          api.change_squash(
            args.ctx,
            args.src_change,
            { dst_change = args.dst_change, files = { args.file and args.file.filename or nil }, force = args.force }
          )
          return true
        end, { err_notify = false })),
        { err_notify = false, err_continue = true }
      ),
      with_force = true,
      desc = "Squash current changes into the selecated change",
    },
    {
      key = "ctc",
      fn = helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        api.cli(args.ctx, "tag", {
          args = { "set", "-r", api.get_change_id(args.src_change), args.tag },
          on_exit = function()
            vim.notify("Tag created: " .. args.tag, vim.log.levels.INFO)
          end,
        })
        return true
      end, { tags = true })),
      desc = "Create new tag at change under the cursor",
    },
    {
      key = "ctm",
      fn = helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          api.cli(args.ctx, "tag", {
            args = { "set", "-r", api.get_change_id(args.src_change), "--allow-move", args.tag },
            on_exit = function()
              vim.notify("Tag " .. args.tag .. " moved to change " .. api.get_change_id(args.src_change), vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      ),
      desc = "Delete tag",
    },
    {
      key = "ctX",
      fn = helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          api.cli(args.ctx, "tag", {
            args = { "delete", args.tag },
            on_exit = function()
              vim.notify("Tag deleted: " .. args.tag, vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      ),
      desc = "Delete tag",
    },
    {
      key = "ctx",
      fn = helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          api.cli(args.ctx, "tag", {
            args = { "delete", args.tag },
            on_exit = function()
              vim.notify("Tag deleted: " .. args.tag, vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      ),
      desc = "Delete tag at change under the cursor",
    },
    {
      key = "cU",
      --- @type fun(args?: WithArgs): boolean Callback function
      fn = function(args)
        api.cli(args.ctx, "op", {
          args = { "revert" },
          on_exit = function()
            vim.notify("Operation reverted.", vim.log.levels.INFO)
          end,
        })
        return true
      end,
      desc = "Revert last operation",
    },
    {
      key = "X",
      fn = helpers.with_change_at_position(
        helpers.search_file(
          helpers.search_change(function(args)
            if args.pos_change then
              api.change_abandon(args.ctx, args.pos_change, { force = args.force })
            elseif args.file then
              api.file_restore(args.ctx, args.file, args.src_change, { force = args.force })
            else
              vim.schedule(function()
                vim.notify("No file or change found under the curor", vim.log.levels.WARN)
              end)
            end
            return true
          end),
          { err_continue = true }
        ),
        { err_continue = true, args_key = "pos_change" }
      ),
      with_force = true,
      desc = "Abandon change or restore file from parent change",
    },

    -- Rebase maps {{{1
    {
      key = "r<space>",
      fn = helpers.search_change(function(args)
        vim.fn.feedkeys(":Jj rebase -s " .. api.get_change_id(args.src_change, true) .. " ", "n")
        return true
      end),
      desc = "Populate command line with `:Jj rebase `",
    },
    {
      key = "rbM",
      fn = fns.rr({ rebase_tree = true, revisions = "::", with_change = 2 ^ 2 }),
      with_force = true,
      desc = "Rebase the current change `@` on an arbitrary bookmark that is requested from the user, together with its descendants",
    },
    {
      key = "rbm",
      fn = fns.rr({ rebase_tree = true, revisions = "::@", with_change = 2 ^ 2 }),
      with_force = true,
      desc = "Rebase the current change `@` on a bookmark in the current line of changes, together with its descendants",
    },
    {
      key = "rbO",
      fn = fns.rr({ rebase_tree = false, revisions = "::", with_change = 2 ^ 2 }),
      with_force = true,
      desc = "Rebase only the current change `@` on an arbitrary bookmark that is requested from the user, without its descendants",
    },
    {
      key = "rbo",
      fn = fns.rr({ rebase_tree = false, revisions = "::@", with_change = 2 ^ 2 }),
      with_force = true,
      desc = "Rebase only the current change `@` on a bookmark in the current line of changes, without its descendants",
    },
    {
      key = "rO",
      fn = fns.rr({ rebase_tree = false, with_change = 2 ^ 1 }),
      with_force = true,
      desc = "Rebase only the current change `@` on an arbitrary change ID that is requested from the user, without its descendants",
    },
    {
      key = "ro",
      fn = fns.rr({ rebase_tree = false, with_change = 2 ^ 0 }),
      with_force = true,
      desc = "Rebase only the current change `@` on the change under the cursor, without its descendants",
    },
    {
      key = "rR",
      fn = fns.rr({ rebase_tree = true, with_change = 2 ^ 1 }),
      with_force = true,
      desc = "Rebase the current change `@` on an arbitrary change ID that is requested from the user",
    },
    {
      key = "rr",
      fn = fns.rr({ rebase_tree = true, with_change = 2 ^ 0 }),
      with_force = true,
      desc = "Rebase the current change `@` on the change undercursor, together with its descendants",
    },

    -- Git maps {{{1
    {
      key = "gu",
      --- @type fun(args?: WithArgs): boolean Callback function
      fn = function(args)
        api.cli(args.ctx, "git", {
          args = { "fetch" },
          on_exit = function()
            vim.notify("Changes fetched.", vim.log.levels.INFO)
          end,
        })
        return true
      end,
      desc = "Fetch changes from remote",
    },
    {
      key = "gp",
      --- @type fun(args?: WithArgs): boolean Callback function
      fn = function(args)
        api.cli(args.ctx, "git", {
          args = { "push" },
          on_exit = function()
            vim.notify("Changes pushed.", vim.log.levels.INFO)
          end,
        })
        return true
      end,
      desc = "Push changes to remote",
    },

    -- Miscellaneous maps {{{1
    {
      key = "gq",
      fn = fns.q({ close_current_window = false }),
      desc = "Close the preview window",
    },
    {
      key = "q",
      fn = fns.q({ close_current_window = true }),
      desc = "Close the summary window and the preview window, if open",
    },
    {
      key = ".",
      fn = helpers.search_file(function(args)
        local home = vim.api.nvim_replace_termcodes("<Home>", true, false, true)
        vim.api.nvim_feedkeys(": ./" .. vim.fn.fnameescape(args.file.filename) .. home, "n", false)
        return true
      end),
      desc = "Start a : command line with the file under the cursor prepopulated",
    },
    {
      key = "g?",
      fn = api.show_help,
      desc = "Show help",
    },
    {
      key = "R",
      --- @type fun(args?: WithArgs): boolean Callback function
      fn = function(args)
        local _winid = vim.api.nvim_get_current_win()
        local bufid = vim.api.nvim_win_get_buf(_winid)
        local pos = vim.api.nvim_win_get_cursor(_winid)
        api.reload_log(args.ctx, function()
          vim.notify("Log reloaded", vim.log.levels.INFO)
          local buf_lines = vim.api.nvim_buf_line_count(bufid)
          if pos[1] > buf_lines then
            pos[1] = buf_lines
          end
          vim.api.nvim_win_set_cursor(_winid, pos)
        end)
        return true
      end,
      desc = "Reload log",
    },
    {
      key = "<C-a>",
      fn = fns.ctrl_a(),
      desc = "Increase the number of displayed revisions in log",
    },
    {
      key = "<C-x>",
      fn = fns.ctrl_a({ negate = true }),
      desc = "Decrease the number of displayed revisions in log",
    },
  }
  local log_dirty_check = require("jiejie.log_dirty_check")
  local set_log_view = {
    fn = function(view_id)
      return function(args)
        log_view.set_log_view(log_view.LOG_VIEWS[view_id])
        log_dirty_check.dirty_mark_content(args.ctx.buf)
        log_dirty_check.do_dirty_check()
        return true
      end
    end,
    desc = "Set log view",
  }
  for i = 1, #log_view.LOG_VIEWS, 1 do
    table.insert(nmaps, vim.tbl_extend("force", set_log_view, { key = "g" .. i, fn = set_log_view.fn(i) }))
  end
  --- @param fn fun(args?: WithArgs): boolean Callback function
  --- @param opts? WithOpts Options
  local with_root_context = function(fn, opts)
    return helpers.with_context(ctx.root, fn, opts)
  end
  for _, value in ipairs(nmaps) do
    local plug = "<Plug>(jiejie-" .. value.key .. ")"
    local fn = with_root_context(value.fn)
    vim.keymap.set("n", value.key, plug, { desc = value.desc, nowait = true, buffer = true })
    vim.keymap.set("n", plug, fn, { desc = value.desc, buffer = true })
    if value.with_force then
      vim.keymap.set("n", "!" .. value.key, plug, { desc = value.desc, nowait = true, buffer = true })
      vim.keymap.set("n", plug, helpers.with_force(fn), { desc = "Ignoring immutuability. " .. value.desc, buffer = true })
    end
  end
  require("jiejie.log_diff").setup_buffer(ctx)
  require("jiejie.log_dirty_check").setup_buffer(ctx)
  require("jiejie.log_view").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
