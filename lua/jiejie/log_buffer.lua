local parsers = require("jiejie.parsers")
local log_diff = require("jiejie.log_diff")
local helpers = require("jiejie.log_buffer_helpers")

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
  local tabid = vim.api.nvim_get_current_tabpage()
  local wins = vim.api.nvim_tabpage_list_wins(tabid)
  for _, winid in ipairs(wins) do
    if vim.api.nvim_win_get_buf(winid) == ctx.buf then
      vim.api.nvim_tabpage_set_win(tabid, winid)
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
  local commands = require("jiejie.commands")
  local with_root_context = function(fn)
    return helpers.with_context(ctx.root, fn)
  end
  --- @type table<number, {key: string, fn: fun(), desc: string}>
  local nmaps = {
    --

    -- Navigation maps {{{1
    {
      key = "<CR>",
      fn = with_root_context(helpers.with_change_at_position(
        helpers.search_hunk(
          helpers.search_file(
            helpers.search_change(function(args)
              ---@diagnostic disable-next-line: undefined-field
              if args.pos_change then
                commands.change_edit(args.ctx, args.src_change)
              elseif args.file then
                -- if no change is at the current position of the cursor, then a file name must have been found
                ---@diagnostic disable-next-line: undefined-field
                commands.file_edit(args.ctx, args.file, args.src_change, { previous_win = true, hunk = args.hunk })
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
      )),
      desc = "Edit change or file under the cursor",
    },
    {
      key = "!<CR>",
      fn = with_root_context(helpers.with_change_at_position(
        helpers.search_hunk(
          helpers.search_file(
            helpers.search_change(function(args)
              ---@diagnostic disable-next-line: undefined-field
              if args.pos_change then
                commands.change_edit(args.ctx, args.src_change, helpers.with_direct_force())
              elseif args.file then
                -- if no change is at the current position of the cursor, then a file name must have been found
                ---@diagnostic disable-next-line: undefined-field
                commands.file_edit(args.ctx, args.file, args.src_change, { previous_win = true, hunk = args.hunk })
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
      )),
      desc = "Edit immutable change or file under the cursor",
    },
    {
      key = "o",
      fn = with_root_context(helpers.search_file(helpers.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.sp })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new split",
    },
    {
      key = "gO",
      fn = with_root_context(helpers.search_file(helpers.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.vnew })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "O",
      fn = with_root_context(helpers.search_file(helpers.search_change(function(args)
        commands.file_edit(args.ctx, args.file, args.src_change, { edit_cmd = vim.cmd.tabnew })
        return true
      end))),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "i",
      fn = with_root_context(
        helpers.search_file(
          helpers.search_change(
            helpers.search_hunk(
              helpers.search_file(
                helpers.search_change(function(args)
                  local count = vim.v.count
                  local _winid = vim.api.nvim_get_current_win()
                  local linenr
                  ---@diagnostic disable-next-line: undefined-field
                  if args.cur_file and args.cur_change then
                    ---@diagnostic disable-next-line: undefined-field
                    if not log_diff.diff_shown(args.cur_file, args.cur_change) then
                      ---@diagnostic disable-next-line: undefined-field
                      log_diff.diff_show(args.ctx, args.cur_file, args.cur_change)
                      ---@diagnostic disable-next-line: undefined-field
                      linenr = args.cur_file.linenr + 1
                    ---@diagnostic disable-next-line: undefined-field
                    elseif args.hunk and args.hunk.linenr > args.cur_file.linenr then
                      ---@diagnostic disable-next-line: undefined-field
                      if args.file and args.hunk.linenr < args.file.linenr then
                        ---@diagnostic disable-next-line: undefined-field
                        if args.src_change and args.hunk.linenr < args.src_change.linenr then
                          ---@diagnostic disable-next-line: undefined-field
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
        )
      ),
      desc = "Open the file or jiejie-object under the cursor in a new vertical split",
    },
    {
      key = "[[",
      fn = with_root_context(
        helpers.search_file(
          helpers.search_change(
            helpers.search_file(
              helpers.search_change(function(args)
                local count = vim.v.count
                local _winid = vim.api.nvim_get_current_win()
                ---@diagnostic disable-next-line: undefined-field
                local cur_change_linenr = args.cur_change and args.cur_change.linenr or 1
                local linenr = 1
                ---@diagnostic disable-next-line: undefined-field
                if not args.cur_file then
                  -- Cursor is on a change, jump to next change
                  ---@diagnostic disable-next-line: undefined-field
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
        )
      ),
      desc = "Jump [count] sections backward",
    },
    {
      key = "]]",
      fn = with_root_context(
        helpers.search_file(
          helpers.search_change(
            helpers.search_file(
              helpers.search_change(function(args)
                local count = vim.v.count
                local _winid = vim.api.nvim_get_current_win()
                local linenr = 1
                local src_change_linenr = args.src_change and args.src_change.linenr or 1
                ---@diagnostic disable-next-line: undefined-field
                if not args.cur_file then
                  -- Cursor is on a change, jump to next change
                  ---@diagnostic disable-next-line: undefined-field
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
        )
      ),
      desc = "Jump [count] sections forward",
    },

    -- Diff maps {{{1
    {
      key = "=",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(function(args)
          commands.toggle_diff(args.ctx, args.src_change, { file = args.file })
          return true
        end),
        { err_continue = true }
      )),
      desc = "Toggle an inline diff of the change or file under the cursor",
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
      fn = with_root_context(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "create", "-r", args.src_change.id, args.bookmark },
          on_exit = function()
            vim.notify("Bookmark created: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end))),
      desc = "Create new bookmark at change under the cursor",
    },
    {
      key = "cbX",
      fn = with_root_context(helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end)))),
      desc = "Delete bookmark including remote boomark",
    },
    {
      key = "cbx",
      fn = with_root_context(helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "delete", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark deleted: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end)))),
      desc = "Delete bookmark including remote boomark at change under the cursor",
    },
    {
      key = "cbF",
      fn = with_root_context(helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end)))),
      desc = "Forget bookmark locally keeping the remote intact",
    },
    {
      key = "cbf",
      fn = with_root_context(helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "forget", args.bookmark },
          on_exit = function()
            vim.notify("Bookmark forgotten: " .. args.bookmark, vim.log.levels.INFO)
          end,
        })
        return true
      end)))),
      desc = "Forget bookmark locally keeping the remote intact at change under the cursor",
    },
    {
      key = "cbm",
      fn = with_root_context(helpers.with_bookmarks_or_tags(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "bookmark", {
          args = { "move", args.bookmark, "-t", args.src_change.id },
          on_exit = function()
            vim.notify("Bookmark " .. args.bookmark .. " moved to change " .. args.src_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end)))),
      desc = "Move bookmark to change under the cursor",
    },
    {
      key = "cbr",
      fn = with_root_context(helpers.search_change(helpers.with_bookmarks_or_tags(helpers.with_bookmark_or_tag(function(args)
        helpers.with_bookmark_or_tag(function(_args)
          commands.cli(args.ctx, "bookmark", {
            args = { "rename", args.bookmark, _args.bookmark },
            on_exit = function()
              vim.notify("Bookmark renamed: " .. args.bookmark, vim.log.levels.INFO)
            end,
          })
          return true
        end, { prompt = "Enter new name: " })({ ctx = args.ctx })
        return true
      end)))),
      desc = "Rename bookmark at change under the cursor",
    },
    {
      key = "cc",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(function(args)
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
      key = "cd",
      fn = with_root_context(helpers.search_change(helpers.with_target_change(function(args)
        commands.cli(args.ctx, "duplicate", {
          args = { "-d", args.dst_change.id, args.src_change.id },
          on_exit = function()
            vim.notify("Duplicated change " .. args.src_change.id_short .. " onto " .. args.dst_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end, { err_notify = false, defualt_target = "@" }))),
      desc = "Squash current changes into the selecated change",
    },
    {
      key = "cn",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_new(args.ctx, args.src_change)
        return true
      end)),
      desc = "Create a new change after the change under the cursor",
    },
    {
      key = "!cn",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_new(args.ctx, args.src_change, helpers.with_direct_force())
        return true
      end)),
      desc = "Create a new change after the change under the cursor",
    },
    {
      key = "crc",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_revert(args.ctx, args.src_change)
        return true
      end)),
      desc = "Revert the commit under the cursor",
    },
    {
      key = "s<space>",
      fn = with_root_context(helpers.search_change(function(args)
        vim.fn.feedkeys(":Jj squash -f " .. args.src_change.id_short .. " ", "n")
        return true
      end)),
      desc = 'Populate command line with ":Jj squash "',
    },
    {
      key = "cs",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(function(args)
          local src_change, dst_change
          local src_is_current_change = args.src_change.status == commands.CHANGE_STATUS.CURRENT
          if not src_is_current_change then
            src_change = { id = "@", id_short = "@" }
            dst_change = args.src_change
          else
            src_change = args.src_change
          end
          commands.change_squash(
            args.ctx,
            ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
            src_change,
            { files = { src_is_current_change and args.file and args.file.filename or nil }, dst_change = dst_change }
          )
          return true
        end),
        { err_notify = true, err_continue = true }
      )),
      desc = "Squash current changes into it's parent or into the change under the cursor if the cursor is not on the currently edited changed",
    },
    {
      key = "!cs",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(function(args)
          local src_change, dst_change
          local src_is_current_change = args.src_change.status == commands.CHANGE_STATUS.CURRENT
          if not src_is_current_change then
            src_change = { id = "@", id_short = "@" }
            dst_change = args.src_change
          else
            src_change = args.src_change
          end
          commands.change_squash(
            args.ctx,
            ---@diagnostic disable-next-line: param-type-mismatch src_change is always set
            src_change,
            helpers.with_direct_force({ files = { src_is_current_change and args.file and args.file.filename or nil }, dst_change = dst_change })
          )
          return true
        end),
        { err_notify = true, err_continue = true }
      )),
      desc = "Squash current changes into it's immutable parent or into the change under the cursor if the cursor is not on the currently edited changed",
    },
    {
      key = "cS",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(helpers.with_target_change(function(args)
          ---@diagnostic disable-next-line: undefined-field
          commands.change_squash(args.ctx, args.src_change, { dst_change = args.dst_change, files = { args.file and args.file.filename or nil } })
          return true
        end, { err_notify = false })),
        { err_notify = false, err_continue = true }
      )),
      desc = "Squash current changes into the selecated change",
    },
    {
      key = "!cS",
      fn = with_root_context(helpers.search_file(
        helpers.search_change(helpers.with_target_change(function(args)
          commands.change_squash(
            args.ctx,
            args.src_change,
            ---@diagnostic disable-next-line: undefined-field
            helpers.with_direct_force({ dst_change = args.dst_change, files = { args.file and args.file.filename or nil } })
          )
          return true
        end, { err_notify = false, err_continue = true })),
        { err_notify = false, err_continue = true }
      )),
      desc = "Squash current changes into the immutuable selecated change",
    },
    {
      key = "ctc",
      fn = with_root_context(helpers.search_change(helpers.with_bookmark_or_tag(function(args)
        commands.cli(args.ctx, "tag", {
          args = { "set", "-r", args.src_change.id, args.tag },
          on_exit = function()
            vim.notify("Tag created: " .. args.tag, vim.log.levels.INFO)
          end,
        })
        return true
      end, { tags = true }))),
      desc = "Create new tag at change under the cursor",
    },
    {
      key = "ctm",
      fn = with_root_context(helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          commands.cli(args.ctx, "tag", {
            args = { "set", "-r", args.src_change.id, "--allow-move", args.tag },
            on_exit = function()
              vim.notify("Tag " .. args.tag .. " moved to change " .. args.src_change.id_short, vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      )),
      desc = "Delete tag",
    },
    {
      key = "ctX",
      fn = with_root_context(helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          commands.cli(args.ctx, "tag", {
            args = { "delete", args.tag },
            on_exit = function()
              vim.notify("Tag deleted: " .. args.tag, vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      )),
      desc = "Delete tag",
    },
    {
      key = "ctx",
      fn = with_root_context(helpers.with_bookmarks_or_tags(
        helpers.search_change(helpers.with_bookmark_or_tag(function(args)
          commands.cli(args.ctx, "tag", {
            args = { "delete", args.tag },
            on_exit = function()
              vim.notify("Tag deleted: " .. args.tag, vim.log.levels.INFO)
            end,
          })
          return true
        end, { tags = true })),
        { tags = true }
      )),
      desc = "Delete tag at change under the cursor",
    },
    {
      key = "de",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change)
        return true
      end)),
      desc = "Edit change description",
    },
    {
      key = "!de",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, helpers.with_direct_force())
        return true
      end)),
      desc = "Edit immutable change description",
    },
    {
      key = "dd",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, { firstline = true })
        return true
      end)),
      desc = "Edit first line of change description",
    },
    {
      key = "!dd",
      fn = with_root_context(helpers.search_change(function(args)
        commands.change_describe(args.ctx, args.src_change, helpers.with_direct_force({ firstline = true }))
        return true
      end)),
      desc = "Edit first line of an immutable change description",
    },
    {
      key = "cU",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, "op", {
          args = { "revert" },
          on_exit = function()
            vim.notify("Operation reverted.", vim.log.levels.INFO)
          end,
        })
        return true
      end),
      desc = "Revert last operation",
    },
    {
      key = "X",
      fn = with_root_context(function(_args)
        if
          not helpers.with_change_at_position(function(args)
            commands.change_abandon(args.ctx, args.src_change)
            return true
          end, { err_notify = false })({ ctx = _args.ctx })
        then
          helpers.search_file(helpers.search_change(function(args)
            commands.file_restore(args.ctx, args.file, args.src_change)
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Abandon change or restore file from parent change",
    },
    {
      key = "!X",
      fn = with_root_context(function(_args)
        if
          not helpers.with_change_at_position(function(args)
            commands.change_abandon(args.ctx, args.src_change, helpers.with_direct_force())
            return true
          end, { err_notify = false })({ ctx = _args.ctx })
        then
          helpers.search_file(helpers.search_change(function(args)
            commands.file_restore(args.ctx, args.file, args.src_change, helpers.with_direct_force())
            return true
          end))({ ctx = _args.ctx })
        end
      end),
      desc = "Abandon immutuable change or restore file from parent change",
    },

    -- Rebase maps {{{1
    {
      key = "r<space>",
      fn = with_root_context(helpers.search_change(function(args)
        vim.fn.feedkeys(":Jj rebase -s " .. args.src_change.id_short .. " ", "n")
        return true
      end)),
      desc = 'Populate command line with ":Jj rebase "',
    },
    {
      key = "rr",
      fn = with_root_context(helpers.search_change(helpers.with_target_change(function(args)
        commands.cli(args.ctx, "rebase", {
          args = { "-s", args.src_change.id, "-d", args.dst_change.id },
          on_exit = function()
            vim.notify("Rebased change tree " .. args.src_change.id_short .. " onto " .. args.dst_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end, { defualt_target = "" }))),
      desc = "Rebase the change under the cursor, together with its descendants",
    },
    {
      key = "!rr",
      fn = with_root_context(helpers.search_change(helpers.with_target_change(function(args)
        commands.cli(args.ctx, "rebase", {
          args = helpers.with_direct_force({ "-s", args.src_change.id, "-d", args.dst_change.id }),
          on_exit = function()
            vim.notify("Rebased change tree " .. args.src_change.id_short .. " onto " .. args.dst_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end, { defualt_target = "" }))),
      desc = "Rebase the change under the cursor, together with its descendants",
    },
    {
      key = "ro",
      fn = with_root_context(helpers.search_change(helpers.with_target_change(function(args)
        commands.cli(args.ctx, "rebase", {
          args = { "-r", args.src_change.id, "-d", args.dst_change.id },
          on_exit = function()
            vim.notify("Rebased change " .. args.src_change.id_short .. " onto " .. args.dst_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end, { defualt_target = "" }))),
      desc = "Rebase only change under the cursor, without its descendants",
    },
    {
      key = "!ro",
      fn = with_root_context(helpers.search_change(helpers.with_target_change(function(args)
        commands.cli(args.ctx, "rebase", {
          args = helpers.with_direct_force({ "-r", args.src_change.id, "-d", args.dst_change.id }),
          on_exit = function()
            vim.notify("Rebased change " .. args.src_change.id_short .. " onto " .. args.dst_change.id_short, vim.log.levels.INFO)
          end,
        })
        return true
      end, { defualt_target = "" }))),
      desc = "Rebase only change under the cursor, without its descendants",
    },

    -- Git maps {{{1
    {
      key = "gp",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, "git", {
          args = { "fetch" },
          on_exit = function()
            vim.notify("Changes fetched.", vim.log.levels.INFO)
          end,
        })
        return true
      end),
      desc = "Fetch changes from remote",
    },
    {
      key = "gP",
      fn = with_root_context(function(args)
        commands.cli(args.ctx, "git", {
          args = { "push" },
          on_exit = function()
            vim.notify("Changes pushed.", vim.log.levels.INFO)
          end,
        })
        return true
      end),
      desc = "Push changes to remote",
    },

    -- Miscellaneous maps {{{1
    {
      key = "gq",
      fn = function()
        vim.api.nvim_win_close(0, true)
      end,
      desc = "Close the summary window",
    },
    {
      key = "q",
      fn = function()
        vim.api.nvim_win_close(0, true)
      end,
      desc = "Close the summary window",
    },
    {
      key = ".",
      fn = with_root_context(helpers.search_file(function(args)
        local home = vim.api.nvim_replace_termcodes("<Home>", true, false, true)
        vim.api.nvim_feedkeys(": ./" .. vim.fn.fnameescape(args.file.filename) .. home, "n", false)
      end)),
      desc = "Start a : command line with the file under the cursor prepopulated",
    },
    {
      key = "g?",
      fn = commands.show_help,
      desc = "Show help",
    },
    {
      key = "R",
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
      fn = with_root_context(helpers.with_count(function(args)
        commands.log_revisions_adjust(args.ctx, { adjustment = args.count })
        return true
      end)),
      desc = "Increase the number of displayed revisions in log",
    },
    {
      key = "<C-x>",
      fn = with_root_context(helpers.with_count(function(args)
        commands.log_revisions_adjust(args.ctx, { adjustment = args.count })
        return true
      end, true)),
      desc = "Decrease the number of displayed revisions in log",
    },
  }
  for _, value in ipairs(nmaps) do
    local plug = "<Plug>(jiejie-" .. value.key .. ")"
    vim.keymap.set("n", value.key, plug, { desc = value.desc, nowait = true, buffer = true })
    vim.keymap.set("n", plug, value.fn, { desc = value.desc, buffer = true })
  end
  require("jiejie.log_diff").setup_buffer(ctx)
  require("jiejie.log_dirty_check").setup_buffer(ctx)
  require("jiejie.context").setup_buffer(ctx)
  return ctx
end

return M
