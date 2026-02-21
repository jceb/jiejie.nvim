local api = require("jiejie.api")
local jujutsu = require("jiejie.jujutsu")
local log_diff = require("jiejie.log_diff")
local helpers = require("jiejie.log_buffer_helpers")
local log_view = require("jiejie.log_view")

--- @type table<string, fun(opts?: {}): fun()>
local fns = {
  --
  --- @param opts {bang?: boolean}
  --- - bang: Execute a shell command instead of a vim command
  ["."] = function(opts)
    return helpers.search_file(function(args)
      local lopts = opts or {}
      local home = vim.api.nvim_replace_termcodes("<Home>" .. (lopts.bang and "<Right>" or ""), true, false, true)
      vim.api.nvim_feedkeys(":" .. (lopts.bang and "!" or "") .. " ./" .. vim.fn.fnameescape(args.file.filename) .. home, "n", false)
      return true
    end)
  end,

  --- @param opts {with_action?: number, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): create, 2: move, 4: forget, 8: delete, 16: rename
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  cb = function(opts)
    local lopts = opts or {}
    local with_bookmarks = function(fn)
      if lopts.with_action ~= 2 ^ 0 then
        return function(args)
          helpers.with_bookmarks_or_tags(fn, {
            src_change = not lopts.drop_change and args.src_change or nil,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
          })(args)
        end
      end
      return fn
    end
    --- @param args WithArgs
    return helpers.search_change(with_bookmarks(helpers.with_bookmark_or_tag(function(args)
      if lopts.with_action == 2 ^ 4 then
        helpers.with_bookmark_or_tag(function(__args)
          api.cli(args.ctx, "bookmark", {
            args = { "rename", args.bookmark, __args.bookmark },
            on_exit = function()
              vim.notify("Bookmark renamed: " .. args.bookmark, vim.log.levels.INFO)
            end,
          })
          return true
        end, { prompt = "Enter new name: " })({ ctx = args.ctx })
      elseif lopts.with_action == 2 ^ 3 then
        api.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 2 then
        api.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 1 then
        api.bookmark_move(args.ctx, args.src_change, args.bookmark, { force = args.force })
      else
        api.cli(args.ctx, "bookmark", {
          args = { "create", "-r", api.get_change_id(args.src_change), args.bookmark },
          on_exit = function()
            vim.notify("Bookmark created: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
      end
      return true
    end)))
  end,

  --- @param opts {with_action?: number, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): simple merge, 2: pick change id, 4: pick bookmark
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  cm = function(opts)
    local lopts = opts or {}
    local with_input = function(fn)
      if lopts.with_action == 2 ^ 2 then
        return function(args)
          helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(fn), {
            src_change = not lopts.drop_change and args.src_change or nil,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
          })(args)
        end
      elseif lopts.with_action == 2 ^ 1 then
        return function(args)
          helpers.with_target_change(fn)(args)
        end
      else
        return fn
      end
    end
    --- @param args WithArgs
    return helpers.search_change(with_input(function(args)
      local changes = { api.construct_dummy_change("@") }
      if lopts.with_action == 2 ^ 2 then
        table.insert(changes, api.construct_dummy_change(args.bookmark))
      elseif lopts.with_action == 2 ^ 1 then
        table.insert(changes, args.dst_change)
      else
        if args.src_change.current_working_copy then
          vim.notify("Can't merge @ with itself", vim.log.levels.ERROR)
          return
        end
        table.insert(changes, args.src_change)
      end
      api.change_new(args.ctx, {
        force = args.force,
        changes = changes,
        on_exit = function()
          vim.notify("Merged chagnes " .. vim
            .iter(changes)
            :map(function(change)
              return api.get_change_id(change, true)
            end)
            :join(", "), vim.log.levels.INFO)
        end,
      })
      return true
    end))
  end,

  --- @param opts {with_action?: number, args?: string[]}
  --- - with_action: 1 (default): new branch, 2: change before, 4: change inbetween
  --- - args: Additional arguments
  cn = function(opts)
    local lopts = opts or {}
    --- @param args WithArgs
    return helpers.search_change(function(args)
      if lopts.with_action == 2 ^ 2 then
        api.change_new(args.ctx, {
          force = args.force,
          before = { args.src_change },
          args = lopts.args,
          on_exit = function()
            vim.notify("Added new change inbetween " .. api.get_change_id(args.src_change, true) .. " and its children", vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 1 then
        api.change_new(args.ctx, {
          force = args.force,
          before = api.get_adjacent_changes(args.ctx, args.src_change, { children = true }),
          after = { args.src_change },
          args = lopts.args,
          on_exit = function()
            vim.notify("Added new change before " .. api.get_change_id(args.src_change, true), vim.log.levels.INFO)
          end,
        })
      else
        api.change_new(args.ctx, {
          force = args.force,
          changes = { args.src_change },
          args = lopts.args,
          on_exit = function()
            vim.notify("Added new change branch after " .. api.get_change_id(args.src_change, true), vim.log.levels.INFO)
          end,
        })
      end
      return true
    end)
  end,

  --- @param opts {tags?: boolean, with_change?: number, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - tags: List tags instead of bookmarks
  --- - with_change: 1 (default): use change under cursor, 2: prompt for change id, 4: prompt for bookmark
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  cp = function(opts)
    local lopts = opts or {}
    local use_change = function(fn)
      if lopts.with_change == 2 ^ 1 then
        return helpers.with_target_change(fn)
      elseif lopts.with_change == 2 ^ 2 then
        --- @param args WithArgs
        return helpers.search_change(function(args)
          return helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(fn, { tags = lopts.tags }), {
            src_change = not lopts.drop_change and args.src_change or nil,
            tags = lopts.tags,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
          })(args)
        end)
      else
        return helpers.search_change(fn, { args_key = "dst_change" })
      end
    end
    --- @param args WithArgs
    return use_change(function(args)
      local src_change = api.construct_dummy_change("@")
      ---@diagnostic disable-next-line: param-type-mismatch param is defined
      local dst_change = lopts.with_change == 2 ^ 2 and api.construct_dummy_change(lopts.tags and args.tag or args.bookmark) or args.dst_change
      api.cli(args.ctx, "duplicate", {
        args = jujutsu.ignore_immtuable({
          "-d",
          ---@diagnostic disable-next-line: param-type-mismatch param is defined
          api.get_change_id(dst_change),
          api.get_change_id(src_change),
        }, { force = args.force }),
        on_exit = function()
          ---@diagnostic disable-next-line: param-type-mismatch param is defined
          vim.notify("Duplicated change " .. api.get_change_id(src_change, true) .. " onto " .. api.get_change_id(dst_change, true), vim.log.levels.INFO)
        end,
      })
      return true
    end)
  end,

  --- @param opts {with_action?: number, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): create, 2: move, 4: delete
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  ct = function(opts)
    local lopts = opts or {}
    local with_tags = function(fn)
      if lopts.with_action ~= 2 ^ 0 then
        --- @param args WithArgs
        return function(args)
          helpers.with_bookmarks_or_tags(fn, {
            src_change = not lopts.drop_change and args.src_change or nil,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch, -- not yet supported by jj
            tags = true,
          })(args)
        end
      end
      return fn
    end
    --- @param args WithArgs
    return helpers.search_change(with_tags(helpers.with_bookmark_or_tag(function(args)
      if lopts.with_action == 2 ^ 2 then
        api.cli(args.ctx, "tag", {
          args = { "delete", args.tag },
          on_exit = function()
            vim.notify("Tag deleted: " .. args.tag, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 1 then
        api.cli(args.ctx, "tag", {
          args = { "set", "-r", api.get_change_id(args.src_change), "--allow-move", args.tag },
          on_exit = function()
            vim.notify("Tag " .. args.tag .. " moved to change " .. api.get_change_id(args.src_change), vim.log.levels.INFO)
          end,
        })
      else
        api.cli(args.ctx, "tag", {
          args = { "set", "-r", api.get_change_id(args.src_change), args.tag },
          on_exit = function()
            vim.notify("Tag created: " .. args.tag, vim.log.levels.INFO)
          end,
        })
      end
      return true
    end, { tags = true })))
  end,

  --- @param opts {negate?: boolean}
  --- - negate: Negate count
  ctrl_a = function(opts)
    local lopts = opts or {}
    --- @param args WithArgs
    return helpers.with_count(function(args)
      api.log_revisions_adjust(args.ctx, { adjustment = args.count })
      return true
    end, { negate = lopts.negate })
  end,

  --- @param opts {split_direction?: SplitDirection, diff_commit_under_cursor?: boolean}
  --- - split_direction: Split direction
  --- - diff_commit_under_cursor: Diff commit under against its parents instead of diffing against @
  d = function(opts)
    --- @param args WithArgs
    return helpers.search_file(helpers.search_change(function(args)
      local lopts = opts or {}
      --- @type RepositoryPath[]
      local files = {}
      if args.src_change.current_working_copy or lopts.diff_commit_under_cursor then
        table.insert(files, { path = args.file.filename, change = args.src_change })
        local ancestors = api.get_adjacent_changes(args.ctx, args.src_change)
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
    --- @param args WithArgs
    return helpers.search_file(helpers.search_change(function(args)
      local lopts = opts or {}
      log_diff.diff_close(args.ctx)
      api.object_edit(args.ctx, args.file.filename, args.src_change, { edit_cmd = api.SPLIT_DIRECTION_FN[lopts.split_direction] })
      return true
    end))
  end,

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

  --- @param opts? WithOpts | {with_action?: number, args?: string[], tags?: boolean}
  --- - with_action: 1 (default): switch, 2: close dynamic view, 4: view bookmark / tag, 8: file view, 16: manually enter revset
  --- - tags Handle tags instead of bookmarks
  --- - args: Additional arguments
  s = function(opts)
    local lopts = opts or {}
    local with_view = function(fn)
      --- @param _args WithArgs
      return function(_args)
        local largs = _args or {}
        local view
        if lopts.with_action == 2 ^ 4 then
          return vim.ui.input({ prompt = "Enter revset: " }, function(revset)
            if not revset or revset == "" then
              return
            end
            view = {
              id = revset,
              revset = revset,
            }
            log_view.add_dynamic_view(view)
            return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
          end)
        elseif lopts.with_action == 2 ^ 3 then
          return helpers.search_change(helpers.search_file(function(args)
            local current_view = log_view.get_log_view_current()
            local revset = (args.file and current_view and (current_view.revset or "::")) or ("::" .. api.get_change_id(args.src_change))
            local description = (args.file and vim.fs.basename(args.file.filename)) or ("::" .. args.src_change.id_short)
            view = {
              id = args.file and args.file.filename or args.src_change.id,
              revset = revset,
              paths = args.file and { args.file.filename },
              description = description,
            }
            log_view.add_dynamic_view(view)
            return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
          end, { err_continue = true }))(_args)
        elseif lopts.with_action == 2 ^ 2 then
          return helpers.with_bookmarks_or_tags(
            --- @param args WithArgs
            helpers.with_bookmark_or_tag(function(args)
              local revset = "::" .. (lopts.tags and args.tag or args.bookmark)
              view = {
                id = revset,
                revset = revset,
              }
              log_view.add_dynamic_view(view)
              return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
            end, { tags = lopts.tags }),
            { tags = lopts.tags }
          )(_args)
        elseif lopts.with_action == 2 ^ 1 then
          local current_view
          if vim.v.count > 0 then
            current_view = log_view.get_log_view(vim.v.count)
          else
            current_view = log_view.get_log_view_current()
          end
          if not current_view or not current_view.id or not log_view.remove_dynamic_view(current_view) then
            return vim.notify("View isn't a dynamic and can't be removed", vim.log.levels.WARN)
          end
          if vim.v.count > 0 then
            view = log_view.get_log_view_current()
          end
          if not view then
            view = log_view.get_log_view_previous()
          end
          if not view then
            view = log_view.get_log_view(1)
          end
          if not view then
            return vim.notify("Previous view does not exist", vim.log.levels.WARN)
          end
        else
          local view_nr
          if vim.v.count > 0 then
            view_nr = vim.v.count
            view = log_view.get_log_view(view_nr)
            if not view then
              return vim.notify("View " .. view_nr .. " does not exist", vim.log.levels.WARN)
            end
          else
            -- switch to previous view
            view = log_view.get_log_view_previous()
            if not view then
              return vim.notify("Previous view does not exist, yet", vim.log.levels.WARN)
            end
          end
        end
        if view then
          return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
        end
      end
    end
    return with_view(
      --- @param args WithArgs
      --- @return boolean
      function(args)
        if args.view then
          log_view.set_log_view(args.view)
          local log_dirty_check = require("jiejie.log_dirty_check")
          log_dirty_check.dirty_mark_content(args.ctx.buf)
          log_dirty_check.do_dirty_check()
        end
        return true
      end
    )
  end,

  --- @param opts {rebase?: number, with_change?: number, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean, tags?: boolean}
  --- - tags: List tags instead of bookmarks
  --- - rebase: 1 (default): revision, 2: with descendants, 4: branch
  --- - with_change: 1 (default): use change under cursor, 2: prompt for change id, 4: prompt for bookmark or tag
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  r = function(opts)
    local lopts = opts or {}
    local use_change = function(fn)
      if lopts.with_change == 2 ^ 1 then
        return helpers.with_target_change(fn)
      elseif lopts.with_change == 2 ^ 2 then
        --- @param args WithArgs
        return helpers.search_change(function(args)
          return helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(fn, { tags = lopts.tags }), {
            src_change = not lopts.drop_change and args.src_change or nil,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
            tags = lopts.tags,
          })(args)
        end)
      else
        return helpers.search_change(fn, { args_key = "dst_change" })
      end
    end
    return use_change(
      --- @param args WithArgs
      --- @return boolean
      function(args)
        local src_change = api.construct_dummy_change("@")
        ---@diagnostic disable-next-line: param-type-mismatch tag or bookmark are always set
        local dst_change = lopts.with_change == 2 ^ 2 and api.construct_dummy_change(lopts.tags and args.tag or args.bookmark) or args.dst_change
        if lopts.with_change == 2 ^ 2 then
          dst_change.immutable = false
        end
        api.cli(args.ctx, "rebase", {
          args = jujutsu.ignore_immtuable({
            lopts.rebase == 2 ^ 2 and "-b" or lopts.rebase == 2 ^ 1 and "-s" or "-r",
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
  y = function(opts)
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

--- Log buffer mappings
local M = {}

--- @type table<number, {key: string, fn: fun(args?: WithArgs), desc: string, with_force: boolean, with_allow_backwards?: boolean}>
M.nmaps = {
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
    key = "<Tab>",
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
    key = "d?",
    fn = function()
      api.show_help("d")
    end,
    desc = "Show diff maps help",
  },
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
    fn = fns.d({ diff_commit_under_cursor = true }),
    desc = "Perform a :Jdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dd",
    fn = fns.d(),
    desc = "Perform a :Jdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dV",
    fn = fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.vertical }),
    desc = "Perform a :Jvdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dv",
    fn = fns.d({ split_direction = api.SPLIT_DIRECTION.vertical }),
    desc = "Perform a :Jvdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dH",
    fn = fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dh",
    fn = fns.d({ split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dS",
    fn = fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
  },
  {
    key = "ds",
    fn = fns.d({ split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dq",
    fn = function(args)
      log_diff.diff_close(args.ctx)
    end,
    desc = "Close all but the currently focused diff buffer, and invoke :diffoff!",
  },

  -- Commit maps {{{1
  {
    key = "c?",
    fn = function()
      api.show_help("c")
    end,
    desc = "Show help for commit maps",
  },
  {
    key = "c<space>",
    fn = function()
      vim.fn.feedkeys(":Jj commit ", "n")
    end,
    desc = 'Populate command line with ":Jj commit "',
  },
  {
    key = "cbb",
    fn = fns.cb({ with_action = 2 ^ 0 }),
    desc = "Alias of cbc",
  },
  {
    key = "cbc",
    fn = fns.cb({ with_action = 2 ^ 0 }),
    desc = "Create new bookmark at change under the cursor",
  },
  {
    key = "cbF",
    fn = fns.cb({ with_action = 2 ^ 2, drop_change = true }),
    desc = "Forget any one bookmark locally keeping the remote intact",
  },
  {
    key = "cbf",
    fn = fns.cb({ with_action = 2 ^ 2, limit_to_change = true }),
    desc = "Forget bookmark locally keeping the remote intact at change under the cursor",
  },
  {
    key = "cbM",
    fn = fns.cb({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "Move any one bookmark to the change under the cursor",
  },
  {
    key = "cbm",
    fn = fns.cb({ with_action = 2 ^ 1, limit_to_branch = true }),
    with_force = true,
    desc = "Move one bookmark from the current branch to the change under the cursor",
  },
  {
    key = "cbR",
    fn = fns.cb({ with_action = 2 ^ 4, drop_change = true }),
    desc = "Rename any one bookmark",
  },
  {
    key = "cbr",
    fn = fns.cb({ with_action = 2 ^ 4, limit_to_change = true }),
    desc = "Rename bookmark at change under the cursor",
  },
  {
    key = "cbX",
    fn = fns.cb({ with_action = 2 ^ 3, drop_change = true }),
    desc = "Delete any one bookmark including the remote boomark",
  },
  {
    key = "cbx",
    fn = fns.cb({ with_action = 2 ^ 3, limit_to_change = true }),
    desc = "Delete bookmark including remote boomark at change under the cursor",
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
    key = "cpM",
    fn = fns.cp({ with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any one bookmark",
  },
  {
    key = "cpm",
    fn = fns.cp({ with_change = 2 ^ 2, limit_to_branch = true }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after a bookmark in the current branch",
  },
  {
    key = "cpP",
    fn = fns.cp({ with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any change ID",
  },
  {
    key = "cpp",
    fn = fns.cp({ with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change after the change under the cursor",
  },
  {
    key = "cpT",
    fn = fns.cp({ with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any one tag",
  },
  {
    key = "cpt",
    fn = fns.cp({ with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Alias of cpT",
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
    fn = fns.y({ commit_id = true }),
    desc = "Copy commit id under the cursor",
  },
  {
    key = "yc",
    fn = fns.y({ commit_id = false }),
    desc = "Copy change id under the cursor",
  },
  {
    key = "yy",
    fn = fns.y({ message_or_filename = true }),
    desc = "Copy commit message or file name under the cursor",
  },
  {
    key = "cA",
    fn = fns.cn({ with_action = 2 ^ 1, args = { "--no-edit" } }),
    with_force = true,
    desc = "No-edit append a new change after the change under the cursor and before all its children",
  },
  {
    key = "A",
    fn = fns.cn({ with_action = 2 ^ 1, args = { "--no-edit" } }),
    with_force = true,
    desc = "Alias of cA",
  },
  {
    key = "ca",
    fn = fns.cn({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "No-edit append a new change after the change under the cursor and before all its children",
  },
  {
    key = "a",
    fn = fns.cn({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "Alias of ca",
  },
  {
    key = "cI",
    fn = fns.cn({ with_action = 2 ^ 2, args = { "--no-edit" } }),
    with_force = true,
    desc = "Non-edit insert a new change inbetween the change under the cursor all its ancestors",
  },
  {
    key = "I",
    fn = fns.cn({ with_action = 2 ^ 2, args = { "--no-edit" } }),
    with_force = true,
    desc = "Alias of cI",
  },
  {
    key = "ci",
    fn = fns.cn({ with_action = 2 ^ 2 }),
    with_force = true,
    desc = "Insert a new change inbetween the change under the cursor all its ancestors",
  },
  {
    key = "i",
    fn = fns.cn({ with_action = 2 ^ 2 }),
    with_force = true,
    desc = "Alias of ci",
  },
  {
    key = "cn",
    fn = fns.cn({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Create a new change branch after the change under the cursor",
  },
  {
    key = "cB",
    fn = fns.cm({ with_action = 2 ^ 2 }),
    with_force = true,
    desc = "Merge `@` with any one bookmark",
  },
  {
    key = "cm",
    fn = fns.cm({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Merge `@` with the change under the cursor",
  },
  {
    key = "cM",
    fn = fns.cm({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "Merge `@` with any change ID",
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
    key = "cS",
    fn = helpers.search_file(
      helpers.search_change(helpers.with_target_change(function(args)
        api.change_squash(args.ctx, args.src_change, { dst_change = args.dst_change, files = { args.file and args.file.filename or nil }, force = args.force })
        return true
      end, { err_notify = false })),
      { err_notify = false, err_continue = true }
    ),
    with_force = true,
    desc = "Squash current changes into the selecated change",
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
        local action = function(_dst_change)
          api.change_squash(
            args.ctx,
            ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
            src_change,
            { files = { args.file and args.file.filename or nil }, dst_change = _dst_change, force = args.force }
          )
        end
        if not dst_change then
          local ancestors = api.get_adjacent_changes(args.ctx, args.src_change)
          if #ancestors > 1 then
            vim.ui.select(ancestors, {
              prompt = "Select ancestor",
              format_item = function(change)
                return api.get_change_id(change, true) .. (change.description_first_line or "")
              end,
            }, function(change, _)
              if not change then
                return vim.notify("Selection failed.", vim.log.levels.WARN)
              end
              action(change)
            end)
          elseif #ancestors > 0 then
            action(ancestors[1])
          else
            vim.notify("No ancestors found.", vim.log.levels.ERROR)
          end
        else
          action(dst_change)
        end
        return true
      end),
      { err_notify = true, err_continue = true }
    ),
    with_force = true,
    desc = "Squash current change into it's parent or into the change under the cursor if the cursor is not on the currently edited changed",
  },
  {
    key = "ctc",
    fn = fns.ct({ with_action = 2 ^ 0 }),
    desc = "Create new tag at change under the cursor",
  },
  {
    key = "ctm",
    fn = fns.ct({ with_action = 2 ^ 1 }),
    desc = "Move any one tag to change under the cursor",
  },
  {
    key = "ctt",
    fn = fns.ct({ with_action = 2 ^ 0 }),
    desc = "Alias of ctc",
  },
  {
    key = "ctX",
    fn = fns.ct({ with_action = 2 ^ 2 }),
    desc = "Delete any one tag",
  },
  {
    key = "ctx",
    fn = fns.ct({ with_action = 2 ^ 2, limit_to_change = true }),
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
            local ancestors = api.get_adjacent_changes(args.ctx, args.src_change)
            local action = function(change)
              api.file_restore(args.ctx, args.file, change, { force = args.force })
            end
            if #ancestors > 1 then
              vim.ui.select(ancestors, {
                prompt = "Select ancestor",
                format_item = function(change)
                  return api.get_change_id(change, true) .. (change.description_first_line or "")
                end,
              }, function(change, _)
                if not change then
                  return vim.notify("Selection failed.", vim.log.levels.WARN)
                end
                action(change)
              end)
            elseif #ancestors > 0 then
              action(ancestors[1])
            else
              vim.notify("No ancestors found.", vim.log.levels.ERROR)
            end
          else
            vim.schedule(function()
              vim.notify("No file or change found under the cursor", vim.log.levels.WARN)
            end)
          end
          return true
        end),
        { err_continue = true }
      ),
      { err_continue = true, args_key = "pos_change" }
    ),
    with_force = true,
    desc = "Abandon change or restore file to change under the cursor",
  },
  {
    key = "x",
    fn = helpers.search_file(helpers.search_change(function(args)
      if not args.src_change.current_working_copy then
        vim.notify("Untrack only works on the currently edited change", vim.log.levels.ERROR)
        return false
      end
      api.cli(args.ctx, "file", {
        args = {
          args.force and "track" or "untrack",
          args.file.filename,
        },
        on_exit = function()
          vim.notify((args.force and "Tracking" or "Untracked") .. " file " .. args.file.filename, vim.log.levels.INFO)
        end,
      })
      return true
    end)),
    with_force = true,
    desc = "Untrack the file under the cursor. With <bang>, track the file again",
  },

  -- Rebase maps {{{1
  {
    key = "r?",
    fn = function()
      api.show_help("r")
    end,
    desc = "Show help for rebase maps",
  },
  {
    key = "r<space>",
    fn = helpers.search_change(function(args)
      vim.fn.feedkeys(":Jj rebase -s " .. api.get_change_id(args.src_change, true) .. " ", "n")
      return true
    end),
    desc = "Populate command line with `:Jj rebase `",
  },
  {
    key = "rbD",
    fn = fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Rebase the current change `@` on any one bookmark, together with its descendants",
  },
  {
    key = "rbd",
    fn = fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 2, limit_to_branch = true }),
    with_force = true,
    desc = "Rebase the current change `@` on a bookmark in the current branch, together with its descendants",
  },
  {
    key = "rbM",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Rebase the current change `@` on any one bookmark, together with its branch",
  },
  {
    key = "rbm",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Alias of rbM",
  },
  {
    key = "rbO",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Rebase only the current change `@` on any bookmark, without its descendants",
  },
  {
    key = "rbo",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, limit_to_branch = true }),
    with_force = true,
    desc = "Rebase only the current change `@` on a bookmark in the current branch, without its descendants",
  },
  {
    key = "rD",
    fn = fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase the current change `@` on any change ID, together with its descendants",
  },
  {
    key = "rd",
    fn = fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase the current change `@` on the change under the cursor, together with its descendants",
  },
  {
    key = "rO",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase only the current change `@` on any change ID, without its descendants",
  },
  {
    key = "ro",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase only the current change `@` on the change under the cursor, without its descendants",
  },
  {
    key = "rR",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase the current change `@` on any change ID, together with its branch",
  },
  {
    key = "rr",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase the current change `@` on the change under the cursor, together with its branch",
  },
  {
    key = "rtD",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1, tags = true }),
    with_force = true,
    desc = "Rebase the current change `@` on any one tag, together with its descendants",
  },
  {
    key = "rtd",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1, tags = true }),
    with_force = true,
    desc = "Alias of rbd",
  },
  {
    key = "rtO",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Rebase only the current change `@` on any tag, without its descendants",
  },
  {
    key = "rto",
    fn = fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Alias of rtO",
  },
  {
    key = "rtT",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Rebase the current change `@` on any one tag, together with its branch",
  },
  {
    key = "rtt",
    fn = fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Alias of rbT",
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

  -- Status log filter maps {{{1
  {
    key = "s?",
    fn = function()
      api.show_help("s")
    end,
    desc = "Show help for status log filter maps",
  },
  {
    key = "sf",
    fn = fns.s({ with_action = 2 ^ 3 }),
    desc = "Add dynamic view that filters for the chander or file path under the cursor",
  },
  {
    key = "sb",
    fn = fns.s({ with_action = 2 ^ 2 }),
    desc = "Add dynamic view that filters for the selected bookmark",
  },
  {
    key = "sq",
    fn = fns.s({ with_action = 2 ^ 1 }),
    desc = "Close dynamic view",
  },
  {
    key = "sr",
    fn = fns.s({ with_action = 2 ^ 4 }),
    desc = "Add dynamic view that filters for a revset provided by the user",
  },
  {
    key = "ss",
    fn = fns.s({ with_action = 2 ^ 0 }),
    desc = "Set log view or switch to the previous view, if no count is given",
  },
  {
    key = "st",
    fn = fns.s({ with_action = 2 ^ 2, tags = true }),
    desc = "Add dynamic view that filters for the selected tag",
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
    fn = fns["."](),
    desc = "Start a : command line with the file under the cursor prepopulated",
  },
  {
    key = "!!",
    fn = fns["."]({ bang = true }),
    desc = "Start a :! command line with the file under the cursor prepopulated",
  },
  {
    key = "g?",
    fn = function()
      api.show_help()
    end,
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

return M
