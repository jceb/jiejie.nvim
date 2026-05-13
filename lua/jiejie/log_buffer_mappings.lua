local api = require("jiejie.api")
local helpers = require("jiejie.log_buffer_helpers")
local jujutsu = require("jiejie.jujutsu")
local log_diff = require("jiejie.log_diff")
local log_view = require("jiejie.log_view")
local buffer = require("jiejie.buffer")

--- Log buffer mappings
local M = {}

--- @type table<string, fun(opts?: {}): fun()>
M.fns = {
  --

  --- @param opts {bang?: boolean}
  --- - bang: Execute a shell command instead of a vim command
  --- @return fun(args?: WithArgs): boolean
  ["."] = function(opts)
    return helpers.search_file(function(args)
      local lopts = opts or {}
      local home = vim.api.nvim_replace_termcodes("<Home>" .. (lopts.bang and "<Right>" or ""), true, false, true)
      vim.api.nvim_feedkeys(":" .. (lopts.bang and "!" or "") .. " ./" .. vim.fn.fnameescape(args.file.filename) .. home, "n", false)
      return true
    end)
  end,

  --- @param opts {key: string, search_downwards?: boolean, to_change?: boolean, to_file?: boolean, to_every_section?: boolean}
  --- - key string Key that is invoking the call - when count is provided, this key is fed into vim for each iteration of count
  --- - search_downwards: Search downwards
  --- - to_change: Jump to next change, ignore other sections
  --- - to_file: Jump to next file, ignore other sections
  --- - to_every_section: Jump to next section
  --- @return fun(args?: WithArgs): boolean
  ["]"] = function(opts)
    local lopts = opts or {}
    -- search_downwards: could be 1, if no next file is discovered, we could skip past the actual heading
    -- else: could be -1, if no next file is discovered, we could skip past the actual heading
    local linenr_offset = lopts.search_downwards and 1 or -1
    local cmp = function(v1, v2, smaller_than)
      if smaller_than then
        return v1 < v2
      else
        return v1 > v2
      end
    end
    return helpers.search_file(
      helpers.search_change(
        helpers.search_file(
          helpers.search_change(function(args)
            local count = vim.v.count
            local _winid = vim.api.nvim_get_current_win()
            local cur_linenr = vim.api.nvim_win_get_cursor(_winid)[1]
            local linenr = 1
            local change_linenr = lopts.search_downwards and (args.src_change and args.src_change.linenr) or (args.cur_change and args.cur_change.linenr) or 1
            if (not lopts.to_file and not args.cur_file and not args.file) or lopts.to_change then
              -- Cursor is on a change, jump to next change
              if (not args.cur_file or lopts.to_change) and args.src_change then
                linenr = args.src_change.linenr
              elseif args.cur_change then
                linenr = args.cur_change.linenr
              end
              if (lopts.search_downwards and linenr < cur_linenr) or (not lopts.search_downwards and linenr > cur_linenr) then
                -- mitigate any logic imperfections
                linenr = cur_linenr
              end
            else
              -- Cursor is on a file
              if args.file then
                if cmp(args.file.linenr, change_linenr, lopts.search_downwards) then
                  -- File is within the current change
                  if lopts.to_file or lopts.to_every_section then
                    linenr = args.file.linenr
                  else
                    linenr = not args.cur_file and args.src_change and args.src_change.linenr or args.file.linenr
                  end
                else
                  if lopts.to_every_section then
                    if
                      (lopts.search_downwards and cur_linenr >= change_linenr and change_linenr < args.file.linenr)
                      or (not lopts.search_downwards and cur_linenr <= change_linenr and change_linenr > args.file.linenr)
                    then
                      linenr = args.file.linenr
                    else
                      -- search_downwards: File is in the next change, jump to the next change
                      -- else: File is in the next change, jump to the current change
                      linenr = change_linenr
                    end
                  else
                    if lopts.to_file then
                      linenr = args.file.linenr
                    else
                      linenr = not args.cur_file and args.src_change and args.src_change.linenr or args.file.linenr
                    end
                  end
                end
              else
                if lopts.to_file then
                  linenr = args.cur_file and args.cur_file.linenr or cur_linenr
                else
                  -- search_downwards: File is in the next change, jump to the next change
                  -- else: File is in the next change, jump to the current change
                  linenr = cmp(cur_linenr, change_linenr, lopts.search_downwards) and change_linenr or cur_linenr
                end
              end
            end
            local pos = { linenr, 0 }
            api.set_cursor(_winid, pos)
            if count > 1 then
              vim.fn.feedkeys((count - 1) .. lopts.key)
            end
            return true
          end, {
            search_downwards = lopts.search_downwards,
            linenr_from_file = not lopts.search_downwards,
            linenr_offset = linenr_offset,
            err_continue = true,
          }),
          { search_downwards = lopts.search_downwards, linenr_offset = linenr_offset, skip_past_change = true, err_continue = true }
        ),
        { args_key = "cur_change", err_continue = true }
      ),
      { args_key = "cur_file", err_continue = true }
    )
  end,

  --- @param opts {backwards?: boolean}
  --- - backwards: Shift backwards
  --- @return fun(args?: WithArgs): boolean
  [">"] = function(opts)
    --- @param args WithArgs
    return helpers.search_change(function(args)
      local lopts = opts or {}
      local src_change
      local dst_change
      local action = function(_dst_change)
        if _dst_change.current_working_copy then
          vim.notify(
            "The working copy change " .. api.get_change_id(_dst_change, true) .. " is already in the position you asked to move it to",
            vim.log.levels.WARN
          )
          return
        end
        local _args = {
          "-r",
          ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
          api.get_change_id(src_change),
          lopts.backwards and "-B" or "-A",
          api.get_change_id(_dst_change),
        }
        local dst_adjacent_changes = api.get_adjacent_changes(args.ctx, _dst_change, { children = not lopts.backwards })
        for _, c in ipairs(dst_adjacent_changes) do
          vim.list_extend(_args, {
            lopts.backwards and "-A" or "-B",
            api.get_change_id(c),
          })
        end
        api.cli(args.ctx, "rebase", {
          args = jujutsu.ignore_immtuable(_args, { force = args.force }),
          on_exit = function()
            ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
            local src_id = api.get_change_id(src_change, true)
            local dst_id = api.get_change_id(_dst_change, true)
            vim.notify("Shifted change " .. src_id .. " " .. (lopts.backwards and "before" or "after") .. " change " .. dst_id, vim.log.levels.INFO)
          end,
        })
      end
      if args.dst_change.current_working_copy then
        src_change = args.dst_change
        local dst_changes = api.get_adjacent_changes(args.ctx, args.dst_change, { children = not lopts.backwards })
        if #dst_changes > 1 then
          vim.ui.select(dst_changes, {
            prompt = "Select " .. (lopts.backwards and "parent" or "child") .. "to swap position with",
            format_item = function(change)
              return api.get_change_id(change, true) .. (change.description_first_line or "")
            end,
          }, function(change, _)
            if not change then
              return vim.notify("Selection failed", vim.log.levels.WARN)
            end
            action(change)
          end)
          return true
        elseif #dst_changes > 0 then
          dst_change = dst_changes[1]
        else
          ---@diagnostic disable-next-line: param-type-mismatch srct_change is always set
          vim.notify("No " .. (lopts.backwards and "parent" or "child") .. " found for change " .. api.get_change_id(src_change, true), vim.log.levels.WARN)
          return false
        end
      else
        src_change = api.construct_dummy_change("@")
        dst_change = args.dst_change
      end
      action(dst_change)
      return true
    end, { args_key = "dst_change" })
  end,

  --- @param opts {with_action?: number, remote?: boolean, tracked?: boolean, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): create, 2: move, 4: forget, 8: delete, 16: rename, 32: move trunk(), 64: move closest bookmark, 128: track bookark, 256: untrack bookmark
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  --- @return fun(args?: WithArgs): boolean
  cb = function(opts)
    local lopts = opts or {}
    local with_bookmarks = function(fn)
      if lopts.with_action ~= 2 ^ 0 then
        --- @param args WithArgs
        --- @return boolean
        return function(args)
          return helpers.with_bookmarks_or_tags(fn, {
            src_change = not lopts.drop_change and args.src_change or nil,
            remote = lopts.remote,
            tracked = lopts.tracked,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
          })(args)
        end
      end
      return fn
    end
    if lopts.with_action == 2 ^ 7 or lopts.with_action == 2 ^ 8 then
      return helpers.search_change(with_bookmarks(helpers.with_bookmark_or_tag(function(args)
        local action = lopts.with_action == 2 ^ 7 and "track" or "untrack"
        local msg = lopts.with_action == 2 ^ 7 and "Started" or "Stopped"
        local cargs = { action, args.bookmark.name }
        if args.remote then
          table.insert(cargs, "--remote")
          table.insert(cargs, args.bookmark.remote)
        end
        api.cli(args.ctx, "bookmark", {
          args = cargs,
          on_exit = function()
            vim.notify(msg .. "tracking " .. args.bookmark.name .. " on change " .. args.bookmark.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end)))
    elseif lopts.with_action == 2 ^ 6 then
      return helpers.search_change(function(args)
        local cargs = { "advance", "-t", api.get_change_id(args.src_change) }
        api.cli(args.ctx, "bookmark", {
          args = cargs,
          on_exit = function()
            vim.notify("Bookmark advanced to change" .. api.get_change_id(args.src_change, true), vim.log.levels.INFO)
          end,
        })
        return true
      end)
    elseif lopts.with_action == 2 ^ 5 then
      return helpers.search_change(function(args)
        api.bookmark_move(args.ctx, args.src_change, "trunk()", { force = args.force, from = true })
        return true
      end)
    end
    --- @param args WithArgs
    return helpers.search_change(with_bookmarks(helpers.with_bookmark_or_tag(function(args)
      if lopts.with_action == 2 ^ 4 then
        helpers.with_bookmark_or_tag(function(__args)
          local cargs = { "rename", args.bookmark.name, __args.bookmark.name }
          if __args.force then
            table.insert(cargs, "--overwrite-existing")
          end
          api.cli(args.ctx, "bookmark", {
            args = cargs,
            on_exit = function()
              vim.notify("Bookmark renamed: " .. args.bookmark.name .. " → " .. __args.bookmark.name, vim.log.levels.INFO)
            end,
          })
          return true
        end, { prompt = "Enter new name for bookmark " .. args.bookmark.name .. ": " })({ ctx = args.ctx, args_key = "bookmark" })
      elseif lopts.with_action == 2 ^ 3 then
        api.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark.name },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark.name, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 2 then
        api.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark.name },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark.name, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 1 then
        api.bookmark_move(args.ctx, args.src_change, args.bookmark.name, { force = args.force })
      else
        api.cli(args.ctx, "bookmark", {
          args = { "create", "-r", api.get_change_id(args.src_change), args.bookmark.name },
          on_exit = function()
            vim.notify("Bookmark created: " .. args.bookmark.name, vim.log.levels.INFO)
          end,
        })
      end
      return true
    end)))
  end,

  --- @param opts {with_action?: number, remote?: boolean, tracked?: boolean, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): simple merge, 2: pick change id, 4: pick bookmark
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  --- @return fun(args?: WithArgs): boolean
  cm = function(opts)
    local lopts = opts or {}
    local with_input = function(fn)
      if lopts.with_action == 2 ^ 2 then
        --- @param args WithArgs
        --- @return boolean
        return function(args)
          return helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(fn), {
            src_change = not lopts.drop_change and args.src_change or nil,
            remote = lopts.remote,
            tracked = lopts.tracked,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
          })(args)
        end
      elseif lopts.with_action == 2 ^ 1 then
        return helpers.with_target_change(fn)
      else
        return fn
      end
    end
    --- @param args WithArgs
    return helpers.search_change(with_input(function(args)
      local changes = { api.construct_dummy_change("@") }
      if lopts.with_action == 2 ^ 2 then
        table.insert(changes, api.construct_dummy_change(args.bookmark.name))
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
  --- @return fun(args?: WithArgs): boolean
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

  --- @param opts {tags?: boolean, with_change?: number, remote?: boolean, tracked?: boolean, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - tags: List tags instead of bookmarks
  --- - with_change: 1 (default): use change under cursor, 2: prompt for change id, 4: prompt for bookmark
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  --- @return fun(args?: WithArgs): boolean
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
            remote = lopts.remote,
            tracked = lopts.tracked,
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
      local dst_change = lopts.with_change == 2 ^ 2 and api.construct_dummy_change(lopts.tags and args.tag.name or args.bookmark.name) or args.dst_change
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

  --- @param opts {with_action?: number, remote?: boolean, tracked?: boolean, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean}
  --- - with_action: 1 (default): create, 2: move, 4: delete
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  --- @return fun(args?: WithArgs): boolean
  ct = function(opts)
    local lopts = opts or {}
    local with_tags = function(fn)
      if lopts.with_action ~= 2 ^ 0 then
        --- @param args WithArgs
        --- @return boolean
        return function(args)
          return helpers.with_bookmarks_or_tags(fn, {
            src_change = not lopts.drop_change and args.src_change or nil,
            remote = lopts.remote,
            tracked = lopts.tracked,
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
          args = { "delete", args.tag.name },
          on_exit = function()
            vim.notify("Tag deleted: " .. args.tag.name, vim.log.levels.INFO)
          end,
        })
      elseif lopts.with_action == 2 ^ 1 then
        api.cli(args.ctx, "tag", {
          args = { "set", "-r", api.get_change_id(args.src_change), "--allow-move", args.tag.name },
          on_exit = function()
            vim.notify("Tag " .. args.tag.name .. " moved to change " .. api.get_change_id(args.src_change), vim.log.levels.INFO)
          end,
        })
      else
        api.cli(args.ctx, "tag", {
          args = { "set", "-r", api.get_change_id(args.src_change), args.tag.name },
          on_exit = function()
            vim.notify("Tag created: " .. args.tag.name, vim.log.levels.INFO)
          end,
        })
      end
      return true
    end, { tags = true })))
  end,

  --- @param opts {negate?: boolean}
  --- - negate: Negate count
  --- @return fun(args?: WithArgs): boolean
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
  --- @return fun(args?: WithArgs): boolean
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
  --- @return fun(args?: WithArgs): boolean
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
  --- @return fun(args?: WithArgs): boolean
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

  --- @param opts {rebase?: number, with_change?: number, remote?: boolean, tracked?: boolean, drop_change?: boolean, limit_to_change?: boolean, limit_to_branch?: boolean, tags?: boolean}
  --- - tags: List tags instead of bookmarks
  --- - rebase: 1 (default): revision, 2: with descendants, 4: branch
  --- - with_change: 1 (default): use change under cursor, 2: prompt for change id, 4: prompt for bookmark or tag, 8: use trunk()
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- - drop_change: Drops change and pass nil instead
  --- - limit_to_change: Limits bookmark / tag search to the current change
  --- - limit_to_branch: Limits bookmark search to the current branch (::@- | @+::) - not applie for tag selection
  --- @return fun(args?: WithArgs): boolean
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
            remote = lopts.remote,
            tracked = lopts.tracked,
            limit_to_change = lopts.limit_to_change,
            limit_to_branch = lopts.limit_to_branch,
            tags = lopts.tags,
          })(args)
        end)
      elseif lopts.with_change == 2 ^ 3 then
        return function(args)
          return fn(vim.tbl_extend("force", args, { dst_change = api.construct_dummy_change("trunk()") }))
        end
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
        local dst_change = lopts.with_change == 2 ^ 2 and api.construct_dummy_change(lopts.tags and args.tag.name or args.bookmark.name) or args.dst_change
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

  --- @type fun(args?: WithArgs): boolean Callback function
  R = function(args)
    local _winid = vim.api.nvim_get_current_win()
    local pos = vim.api.nvim_win_get_cursor(_winid)
    api.reload(args.ctx, function()
      vim.notify("Log reloaded", vim.log.levels.INFO)
      api.set_cursor(_winid, pos)
    end)
    return true
  end,

  --- @param opts? WithOpts | {with_action?: number, args?: string[], tags?: boolean, remote?: boolean, tracked?: boolean}
  --- - with_action: 1 (default): switch, 2: close dynamic view, 4: view bookmark / tag, 8: file view, 16: manually enter revset, 32: description, 64: author, 128: manual input author
  --- - tags Handle tags instead of bookmarks
  --- - args: Additional arguments
  --- - remote: If set to nil, consider local and remote bookmarks, if set to false, only consider local bookmarks, if set to true, only consider remote bookmarks
  --- - tracked: If set to nil, consider untracked and tracked bookmarks, if set to false, only consider untracked bookmarks, if set to true, only consider tracked bookmarks
  --- @return fun(args?: WithArgs): boolean
  s = function(opts)
    local lopts = opts or {}
    --- @param fn fun(args: WithArgs): boolean
    local with_view = function(fn)
      --- @param _args WithArgs
      --- @return boolean
      return function(_args)
        local largs = _args or {}
        --- @type LogView?
        local view
        local current_view = log_view.get_log_view_current(_args.ctx.buf)
        if not current_view then
          error("Unable to determine current view")
        end
        if lopts.with_action == 2 ^ 7 then
          vim.ui.input({ prompt = "Enter author: " }, function(author)
            if not author or author == "" then
              return
            end
            local author_escaped = vim.fn.escape(author, '"')
            view = {
              id = "author-" .. author,
              revset = current_view.revset .. ' & (author(glob:"*' .. author_escaped .. '*") | committer(glob:"*' .. author_escaped .. '*"))',
              description = author,
            }
            log_view.add_dynamic_view(view)
            fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
          end)
          return true
        elseif lopts.with_action == 2 ^ 6 then
          local email = vim.trim(largs.src_change.email)
          view = {
            id = email,
            revset = current_view.revset .. ' & (author_email("' .. email .. '") | committer_email("' .. email .. '"))',
            description = email,
          }
          log_view.add_dynamic_view(view)
        elseif lopts.with_action == 2 ^ 5 then
          vim.ui.input({ prompt = "Enter description: " }, function(description)
            if not description or description == "" then
              return
            end
            local description_escaped = vim.fn.escape(description, '"')
            view = {
              id = "desc-" .. description,
              revset = current_view.revset .. ' & description(glob:"*' .. description_escaped .. '*")',
              description = description,
            }
            log_view.add_dynamic_view(view)
            fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
          end)
          return true
        elseif lopts.with_action == 2 ^ 4 then
          vim.ui.input({ prompt = "Enter revset: " }, function(revset)
            if not revset or revset == "" then
              return
            end
            view = {
              id = revset,
              revset = revset,
              description = revset,
            }
            log_view.add_dynamic_view(view)
            fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
          end)
          return true
        elseif lopts.with_action == 2 ^ 3 then
          return helpers.search_change(helpers.search_file(function(args)
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
              local bm_revset = "::" .. (lopts.tags and args.tag.name or args.bookmark.name)
              local revset = bm_revset .. " | " .. (lopts.tags and args.tag.name or args.bookmark.name) .. (lopts.args and lopts.args or "")
              view = {
                id = revset,
                revset = revset,
                description = bm_revset,
              }
              log_view.add_dynamic_view(view)
              return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
            end, { tags = lopts.tags }),
            { tags = lopts.tags, remote = lopts.remote, tracked = lopts.tracked }
          )(_args)
        elseif lopts.with_action == 2 ^ 1 then
          if vim.v.count > 0 then
            current_view = log_view.get_log_view(_args.ctx.buf, vim.v.count)
          end
          if not current_view or not current_view.id or not log_view.remove_dynamic_view(current_view) then
            vim.notify("View isn't a dynamic and can't be removed", vim.log.levels.WARN)
            return false
          end
          if vim.v.count > 0 then
            view = log_view.get_log_view_current(_args.ctx.buf)
          end
          if not view then
            view = log_view.get_log_view_previous(_args.ctx.buf)
          end
          if not view then
            view = log_view.get_log_view(_args.ctx.buf, 1)
          end
          if not view then
            vim.notify("Previous view does not exist", vim.log.levels.WARN)
            return false
          end
        else
          local view_nr
          if vim.v.count > 0 then
            view_nr = vim.v.count
            view = log_view.get_log_view(_args.ctx.buf, view_nr)
            if not view then
              vim.notify("View " .. view_nr .. " does not exist", vim.log.levels.WARN)
              return false
            end
          else
            -- switch to previous view
            view = log_view.get_log_view_previous(_args.ctx.buf)
            if not view then
              vim.notify("Previous view does not exist, yet", vim.log.levels.WARN)
              return false
            end
          end
        end
        if view then
          return fn(vim.tbl_extend("force", largs, { [lopts.args_key or "view"] = view }))
        end
        return false
      end
    end
    return with_view(
      --- @param args WithArgs
      --- @return boolean
      function(args)
        if args.view then
          log_view.set_log_view(args.ctx.buf, args.view)
          local log_dirty_check = require("jiejie.log_dirty_check")
          log_dirty_check.dirty_mark_content(args.ctx.buf)
          log_dirty_check.do_dirty_check()
        end
        return true
      end
    )
  end,

  --- @param opts? {vertical?: boolean, log?: JiejieBufferType}
  --- - vertical: Split vertically
  --- @return fun(args?: WithArgs): boolean
  so = function(opts)
    --- @param args WithArgs
    --- @return boolean
    return function(args)
      local lopts = opts or {}
      api.show_log(args.ctx, { vertical = lopts.vertical, buffer_type = lopts.log, change = args.src_change })
      return true
    end
  end,

  --- @param opts {commit_id?: boolean, message_or_filename?: boolean}
  --- - commit_id: Copy commit id or else the change id if not message_or_filename
  --- - message_or_filename: Copy commit message or file name
  --- @return fun(args?: WithArgs): boolean
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

  --
}

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
    fn = M.fns.o({ split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Open the file or jiejie-object under the cursor in a new split",
  },
  {
    key = "gO",
    fn = M.fns.o({ split_direction = api.SPLIT_DIRECTION.vertical }),
    desc = "Open the file or jiejie-object under the cursor in a new vertical split",
  },
  {
    key = "O",
    fn = M.fns.o({ split_direction = api.SPLIT_DIRECTION.tab }),
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
                api.set_cursor(_winid, pos)
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
      args.src_change.current_working_copy = false -- force the revision to be displayed
      api.object_edit(args.ctx, nil, args.src_change, { edit_cmd = vim.cmd.pedit })
      return true
    end),
    desc = "Open change under the cursor",
  },
  {
    key = "(",
    fn = M.fns["]"]({ key = "(", search_downwards = false, to_every_section = true }),
    desc = "Jump [count] changes or files backward",
  },
  {
    key = ")",
    fn = M.fns["]"]({ key = ")", search_downwards = true, to_every_section = true }),
    desc = "Jump [count] changes or files forward",
  },
  {
    key = "{",
    fn = M.fns["]"]({ key = "{", search_downwards = false, to_change = true }),
    desc = "Jump [count] changes forward",
  },
  {
    key = "}",
    fn = M.fns["]"]({ key = "}", search_downwards = true, to_change = true }),
    desc = "Jump [count] changes forward",
  },
  {
    key = "[[",
    fn = M.fns["]"]({ key = "[[", search_downwards = false }),
    desc = "Jump [count] sections backward",
  },
  {
    key = "]]",
    fn = M.fns["]"]({ key = "]]", search_downwards = true }),
    desc = "Jump [count] sections forward",
  },
  {
    key = "[m",
    fn = M.fns["]"]({ key = "[m", search_downwards = false, to_file = true }),
    desc = "Jump [count] files backward",
  },
  {
    key = "]m",
    fn = M.fns["]"]({ key = "]m", search_downwards = true, to_file = true }),
    desc = "Jump [count] files forward",
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
    fn = M.fns.d({ diff_commit_under_cursor = true }),
    desc = "Perform a :Jdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dd",
    fn = M.fns.d(),
    desc = "Perform a :Jdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dV",
    fn = M.fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.vertical }),
    desc = "Perform a :Jvdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dv",
    fn = M.fns.d({ split_direction = api.SPLIT_DIRECTION.vertical }),
    desc = "Perform a :Jvdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dH",
    fn = M.fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
  },
  {
    key = "dh",
    fn = M.fns.d({ split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file under the cursor and change @.",
  },
  {
    key = "dS",
    fn = M.fns.d({ diff_commit_under_cursor = true, split_direction = api.SPLIT_DIRECTION.horizontal }),
    desc = "Perform a :Jhdiffsplit on the file and change under the cursor.",
  },
  {
    key = "ds",
    fn = M.fns.d({ split_direction = api.SPLIT_DIRECTION.horizontal }),
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
    key = "cba",
    fn = M.fns.cb({ with_action = 2 ^ 6 }),
    desc = "Advance closest bookmark to change under the cursor",
  },
  {
    key = "cbb",
    fn = M.fns.cb({ with_action = 2 ^ 0 }),
    desc = "Alias of cbc",
  },
  {
    key = "cbc",
    fn = M.fns.cb({ with_action = 2 ^ 0 }),
    desc = "Create new bookmark at change under the cursor",
  },
  {
    key = "cbF",
    fn = M.fns.cb({ with_action = 2 ^ 2, drop_change = true, remote = false }),
    desc = "Forget any one bookmark locally keeping the remote intact",
  },
  {
    key = "cbf",
    fn = M.fns.cb({ with_action = 2 ^ 2, limit_to_change = true, remote = false }),
    desc = "Forget bookmark locally keeping the remote intact at change under the cursor",
  },
  {
    key = "cbM",
    fn = M.fns.cb({ with_action = 2 ^ 1, remote = false }),
    with_force = true,
    desc = "Move any one bookmark to the change under the cursor",
  },
  {
    key = "cbm",
    fn = M.fns.cb({ with_action = 2 ^ 1, limit_to_branch = true, remote = false }),
    with_force = true,
    desc = "Move one bookmark from the current branch to the change under the cursor",
  },
  {
    key = "cbR",
    fn = M.fns.cb({ with_action = 2 ^ 4, drop_change = true, remote = false }),
    desc = "Rename any one bookmark",
    with_force = true,
  },
  {
    key = "cbr",
    fn = M.fns.cb({ with_action = 2 ^ 4, limit_to_change = true, remote = false }),
    desc = "Rename bookmark at change under the cursor",
    with_force = true,
  },
  {
    key = "cbt",
    fn = M.fns.cb({ with_action = 2 ^ 5 }),
    desc = "Move default bookmark (`trunk()`) to the change under the cursor",
  },
  {
    key = "cbT",
    fn = M.fns.cb({ with_action = 2 ^ 7, remote = true, tracked = false, drop_change = true }),
    desc = "Track bookmark",
  },
  {
    key = "cbU",
    fn = M.fns.cb({ with_action = 2 ^ 8, remote = true, tracked = true, drop_change = true }),
    desc = "Untrack bookmark",
  },
  {
    key = "cbX",
    fn = M.fns.cb({ with_action = 2 ^ 3, drop_change = true, remote = false }),
    desc = "Delete any one bookmark including the remote boomark",
  },
  {
    key = "cbx",
    fn = M.fns.cb({ with_action = 2 ^ 3, limit_to_change = true, remote = false }),
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
    fn = M.fns.cp({ with_change = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any one bookmark",
  },
  {
    key = "cpm",
    fn = M.fns.cp({ with_change = 2 ^ 2, limit_to_branch = true, remote = false }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after a bookmark in the current branch",
  },
  {
    key = "cpP",
    fn = M.fns.cp({ with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any change ID",
  },
  {
    key = "cpp",
    fn = M.fns.cp({ with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change after the change under the cursor",
  },
  {
    key = "cpT",
    fn = M.fns.cp({ with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Duplicate / cherry-pick current change `@` after any one tag",
  },
  {
    key = "cpt",
    fn = M.fns.cp({ with_change = 2 ^ 2, tags = true }),
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
    fn = M.fns.y({ commit_id = true }),
    desc = "Copy commit id under the cursor",
  },
  {
    key = "yc",
    fn = M.fns.y({ commit_id = false }),
    desc = "Copy change id under the cursor",
  },
  {
    key = "yy",
    fn = M.fns.y({ message_or_filename = true }),
    desc = "Copy commit message or file name under the cursor",
  },
  {
    key = "cA",
    fn = M.fns.cn({ with_action = 2 ^ 1, args = { "--no-edit" } }),
    with_force = true,
    desc = "No-edit append a new change after the change under the cursor and before all its children",
  },
  {
    key = "A",
    fn = M.fns.cn({ with_action = 2 ^ 1, args = { "--no-edit" } }),
    with_force = true,
    desc = "Alias of cA",
  },
  {
    key = "ca",
    fn = M.fns.cn({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "No-edit append a new change after the change under the cursor and before all its children",
  },
  {
    key = "a",
    fn = M.fns.cn({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "Alias of ca",
  },
  {
    key = "cI",
    fn = M.fns.cn({ with_action = 2 ^ 2, args = { "--no-edit" } }),
    with_force = true,
    desc = "Non-edit insert a new change inbetween the change under the cursor all its ancestors",
  },
  {
    key = "I",
    fn = M.fns.cn({ with_action = 2 ^ 2, args = { "--no-edit" } }),
    with_force = true,
    desc = "Alias of cI",
  },
  {
    key = "ci",
    fn = M.fns.cn({ with_action = 2 ^ 2 }),
    with_force = true,
    desc = "Insert a new change inbetween the change under the cursor and all its ancestors",
  },
  {
    key = "i",
    fn = M.fns.cn({ with_action = 2 ^ 2 }),
    with_force = true,
    desc = "Alias of ci",
  },
  {
    key = "crR",
    fn = M.fns.cm({ with_action = 2 ^ 1 }),
    with_force = true,
    desc = "Merge `@` with any change ID",
  },
  {
    key = "crr",
    fn = M.fns.cm({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Merge `@` with the change under the cursor",
  },
  {
    key = "cm",
    fn = M.fns.cm({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Alias of crr",
  },
  {
    key = "crB",
    fn = M.fns.cm({ with_action = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Merge `@` with any one bookmark",
  },
  {
    key = "crM",
    fn = M.fns.cm({ with_action = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Alias of crB",
  },
  {
    key = "cM",
    fn = M.fns.cm({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Alias of crR",
  },
  {
    key = "cn",
    fn = M.fns.cn({ with_action = 2 ^ 0 }),
    with_force = true,
    desc = "Create a new change branch after the change under the cursor",
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
                return vim.notify("Selection failed", vim.log.levels.WARN)
              end
              action(change)
            end)
          elseif #ancestors > 0 then
            action(ancestors[1])
          else
            vim.notify("No ancestors found", vim.log.levels.ERROR)
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
    fn = M.fns.ct({ with_action = 2 ^ 0 }),
    desc = "Create new tag at change under the cursor",
  },
  {
    key = "ctm",
    fn = M.fns.ct({ with_action = 2 ^ 1 }),
    desc = "Move any one tag to change under the cursor",
  },
  {
    key = "ctt",
    fn = M.fns.ct({ with_action = 2 ^ 0 }),
    desc = "Alias of ctc",
  },
  {
    key = "ctX",
    fn = M.fns.ct({ with_action = 2 ^ 2 }),
    desc = "Delete any one tag",
  },
  {
    key = "ctx",
    fn = M.fns.ct({ with_action = 2 ^ 2, limit_to_change = true }),
    desc = "Delete tag at change under the cursor",
  },
  {
    key = "u",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      api.cli(args.ctx, "op", { args = { "revert" } })
      return true
    end,
    desc = "Undo last operation",
  },
  {
    key = "<C-r>",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      api.cli(args.ctx, "op", {
        args = { "revert" },
      })
      return true
    end,
    desc = "Redo last operation",
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
                  return vim.notify("Selection failed", vim.log.levels.WARN)
                end
                action(change)
              end)
            elseif #ancestors > 0 then
              action(ancestors[1])
            else
              vim.notify("No ancestors found", vim.log.levels.ERROR)
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
    key = "<<",
    fn = M.fns[">"]({ backwards = true }),
    with_force = true,
    desc = "Shift the current change `@` before the change under the cursor",
  },
  {
    key = ">>",
    fn = M.fns[">"](),
    with_force = true,
    desc = "Shift the current change `@` after the change under the cursor",
  },
  {
    key = "rbD",
    fn = M.fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 2 }),
    with_force = true,
    desc = "Rebase the current change `@` on any one bookmark, together with its descendants",
  },
  {
    key = "rbd",
    fn = M.fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 2, limit_to_branch = true }),
    with_force = true,
    desc = "Rebase the current change `@` on a bookmark in the current branch, together with its descendants",
  },
  {
    key = "rbH",
    fn = M.fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 3 }),
    desc = "Rebase only the current change `@` on the default bookmark (`trunk`), with its descendants",
  },
  {
    key = "rbh",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 3 }),
    desc = "Rebase only the current change `@` on the default bookmark (`trunk`), without its descendants",
  },
  {
    key = "rbM",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Rebase the current change `@` on any one bookmark, together with its branch",
  },
  {
    key = "rbm",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Alias of rbM",
  },
  {
    key = "rbO",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, remote = false }),
    with_force = true,
    desc = "Rebase only the current change `@` on any bookmark, without its descendants",
  },
  {
    key = "rbo",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, limit_to_branch = true, remote = false }),
    with_force = true,
    desc = "Rebase only the current change `@` on a bookmark in the current branch, without its descendants",
  },
  {
    key = "rbt",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 3 }),
    desc = "Rebase the current change `@` on the default bookmark (`trunk`), together with its branch",
  },
  {
    key = "rD",
    fn = M.fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase the current change `@` on any change ID, together with its descendants",
  },
  {
    key = "rd",
    fn = M.fns.r({ rebase = 2 ^ 1, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase the current change `@` on the change under the cursor, together with its descendants",
  },
  {
    key = "rO",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase only the current change `@` on any change ID, without its descendants",
  },
  {
    key = "ro",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase only the current change `@` on the change under the cursor, without its descendants",
  },
  {
    key = "rR",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1 }),
    with_force = true,
    desc = "Rebase the current change `@` on any change ID, together with its branch",
  },
  {
    key = "rr",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 0 }),
    with_force = true,
    desc = "Rebase the current change `@` on the change under the cursor, together with its branch",
  },
  {
    key = "rtD",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1, tags = true }),
    with_force = true,
    desc = "Rebase the current change `@` on any one tag, together with its descendants",
  },
  {
    key = "rtd",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 1, tags = true }),
    with_force = true,
    desc = "Alias of rbd",
  },
  {
    key = "rtO",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Rebase only the current change `@` on any tag, without its descendants",
  },
  {
    key = "rto",
    fn = M.fns.r({ rebase = 2 ^ 0, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Alias of rtO",
  },
  {
    key = "rtT",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Rebase the current change `@` on any one tag, together with its branch",
  },
  {
    key = "rtt",
    fn = M.fns.r({ rebase = 2 ^ 2, with_change = 2 ^ 2, tags = true }),
    with_force = true,
    desc = "Alias of rbT",
  },

  -- Git maps {{{1
  {
    key = "gu",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      api.cli(args.ctx, "git", {
        args = { "fetch", "--all-remotes" },
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
        args = { "push", "--tracked", "--deleted" },
      })
      return true
    end,
    desc = "Push changes to remote",
  },
  {
    key = "grA",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = helpers.with_remote(function(args)
      api.cli(args.ctx, "git", {
        args = { "push", "--all", "--deleted", "--remote", args.remote },
        on_exit = function()
          vim.notify("All bookmarks pushed to remote " .. args.remote, vim.log.levels.INFO)
        end,
      })
      return true
    end),
    desc = "Push all bookmarks to a specific git remote",
  },
  {
    key = "gra",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      api.cli(args.ctx, "git", {
        args = { "push", "--all", "--deleted" },
        on_exit = function()
          vim.notify("All bookmarks pushed", vim.log.levels.INFO)
        end,
      })
      return true
    end,
    desc = "Push all bookmarks",
  },
  {
    key = "grB",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = helpers.search_change(function(_args)
      return helpers.with_bookmarks_or_tags(
        helpers.with_bookmark_or_tag(helpers.with_remote(function(args)
          api.cli(args.ctx, "git", {
            args = { "push", "--remote", args.remote, "--bookmark", args.bookmark.name },
            on_exit = function()
              vim.notify("Bookmark " .. args.bookmark.name .. " pushed to remote " .. args.remote, vim.log.levels.INFO)
            end,
          })
          return true
        end)),
        { src_change = _args.src_change, remote = false }
      )(_args)
    end),
    desc = "Push any bookmark to a specific git remote",
  },
  {
    key = "grM",
    fn = function()
      vim.api.nvim_feedkeys("grB", "n", false)
    end,
    desc = "Alias of grB",
  },
  {
    key = "grb",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = helpers.search_change(function(_args)
      return helpers.with_bookmarks_or_tags(
        helpers.with_bookmark_or_tag(helpers.with_remote(function(args)
          api.cli(args.ctx, "git", {
            args = { "push", "--remote", args.remote, "--bookmark", args.bookmark.name },
            on_exit = function()
              vim.notify("Bookmark " .. args.bookmark.name .. " pushed to remote " .. args.remote, vim.log.levels.INFO)
            end,
          })
          return true
        end)),
        { src_change = _args.src_change, limit_to_change = true, remote = false }
      )(_args)
    end),
    desc = "Push the bookmark under the cursor to a specific git remote",
  },
  {
    key = "grm",
    fn = function()
      vim.api.nvim_feedkeys("grb", "n", false)
    end,
    desc = "Alias of grb",
  },
  {
    key = "grT",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = helpers.with_remote(function(args)
      local remote = args.remote or "origin"
      api.exec(args.ctx, "git", {
        args = { "push", "--tags", remote },
        on_exit = function()
          vim.notify("Tags pushed " .. "to remote " .. remote, vim.log.levels.INFO)
        end,
      })
      return true
    end),
    desc = "Push git tags to a specific git remote",
  },
  {
    key = "grt",
    --- @type fun(args?: WithArgs): boolean Callback function
    fn = function(args)
      api.exec(args.ctx, "git", {
        args = { "push", "--tags" },
        on_exit = function()
          vim.notify("Tags pushed", vim.log.levels.INFO)
        end,
      })
      return true
    end,
    desc = "Push git tags",
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
    key = "sA",
    fn = M.fns.s({ with_action = 2 ^ 7 }),
    desc = "Add dynamic view that filters changes for the author of the change under the cursor",
  },
  {
    key = "sa",
    fn = helpers.search_change(M.fns.s({ with_action = 2 ^ 6 })),
    desc = "Add dynamic view that filters changes for the author of the change under the cursor",
  },
  {
    key = "sB",
    fn = M.fns.s({ with_action = 2 ^ 2, args = "::" }),
    desc = "Add dynamic view that displays all changes that belong to the selected bookmark and all its children",
  },
  {
    key = "sb",
    fn = M.fns.s({ with_action = 2 ^ 2, args = "+" }),
    desc = "Add dynamic view that displays all changes that belong to the selected bookmark and its direct children",
  },
  {
    key = "sD",
    fn = M.fns.s({ with_action = 2 ^ 5 }),
    desc = "Add dynamic view that filters changes for a description",
  },
  {
    key = "sd",
    fn = M.fns.s({ with_action = 2 ^ 5 }),
    desc = "Alias of sD",
  },
  {
    key = "sf",
    fn = M.fns.s({ with_action = 2 ^ 3 }),
    desc = "Add dynamic view that lists changes for that belong to the change or modify the file name under the cursor",
  },
  {
    key = "sE",
    fn = helpers.search_change(M.fns.so({ vertical = true, log = buffer.BUFFER_TYPE.EVOLOG })),
    desc = "Show evolog in a vertical spilt",
  },
  {
    key = "se",
    fn = helpers.search_change(M.fns.so({ log = buffer.BUFFER_TYPE.EVOLOG })),
    desc = "Show evolog in a horizontal spilt",
  },
  {
    key = "sO",
    fn = M.fns.so({ vertical = true, log = buffer.BUFFER_TYPE.OPLOG }),
    desc = "Show operation log in a vertical spilt",
  },
  {
    key = "so",
    fn = M.fns.so({ log = buffer.BUFFER_TYPE.OPLOG }),
    desc = "Show operation log in a horizontal spilt",
  },
  {
    key = "sq",
    fn = M.fns.s({ with_action = 2 ^ 1 }),
    desc = "Close dynamic view",
  },
  {
    key = "sr",
    fn = M.fns.s({ with_action = 2 ^ 4 }),
    desc = "Add dynamic view that filters for a revset provided by the user",
  },
  {
    key = "ss",
    fn = M.fns.s({ with_action = 2 ^ 0 }),
    desc = "Set log view or switch to the previous view, if no count is given",
  },
  {
    key = "sT",
    fn = M.fns.s({ with_action = 2 ^ 2, tags = true, args = "::" }),
    desc = "Add dynamic view that displays all changes that belong to the selected tag and all its children",
  },
  {
    key = "st",
    fn = M.fns.s({ with_action = 2 ^ 2, tags = true, args = "+" }),
    desc = "Add dynamic view that displays all changes that belong to the selected tag and its direct children",
  },

  -- Miscellaneous maps {{{1
  {
    key = "gq",
    fn = M.fns.q({ close_current_window = false }),
    desc = "Close the preview window",
  },
  {
    key = "q",
    fn = M.fns.q({ close_current_window = true }),
    desc = "Close the status log window and the preview window, if open",
  },
  {
    key = ".",
    fn = M.fns["."](),
    desc = "Start a : command line with the file under the cursor prepopulated",
  },
  {
    key = "!!",
    fn = M.fns["."]({ bang = true }),
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
    fn = M.fns.R,
    desc = "Reload log",
  },
  {
    key = "<C-a>",
    fn = M.fns.ctrl_a(),
    desc = "Increase the number of displayed revisions in log",
  },
  {
    key = "<C-x>",
    fn = M.fns.ctrl_a({ negate = true }),
    desc = "Decrease the number of displayed revisions in log",
  },
}

return M
