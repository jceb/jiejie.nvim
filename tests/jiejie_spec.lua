-- tests/my_plugin_spec.lua
local eq = assert.are.same

describe("jiejie parse_change", function()
  --

  it("When parsing an the data that doesn't have a change id, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_change("│ ○  tw	†(empty) ‡an empty commit⌠⌡∫∬∮∴", 23)
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing an the data that has an empty string have a change id, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_change("│ ○  tw	†(empty) ‡an empty commit⌠⌡∫∬∮∴ ", 23)
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing an empty change, the parser shall yield the correct status and id", function()
    local result = require("jiejie.parsers").parse_change("│ ○  tw	†(empty) ‡an empty commit⌠⌡∫∬∮∴twqqkoqtxpxvypunpwqvyyrxnyxyzqtw", 23)
    local expected = {
      status = "○",
      id = "twqqkoqtxpxvypunpwqvyyrxnyxyzqtw",
      id_short = "tw",
      empty = true,
      description_first_line = "an empty commit",
      bookmarks = {},
      tags = {},
      git_head = false,
      conflict = false,
      immutable = false,
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a change with no description, the parser shall yield the correct status and id", function()
    local result = require("jiejie.parsers").parse_change("│ ○  tp	†‡(no description set)⌠⌡∫∬∮∴tpxnqwvtqmstolzlosssvrvspxlqnxwx", 23)
    local expected = {
      status = "○",
      id = "tpxnqwvtqmstolzlosssvrvspxlqnxwx",
      id_short = "tp",
      empty = false,
      description_first_line = "",
      bookmarks = {},
      tags = {},
      git_head = false,
      conflict = false,
      immutable = false,
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing an empty change with no description, the parser shall yield the correct status and id", function()
    local result = require("jiejie.parsers").parse_change("@  x	†(empty) ‡(no description set)⌠⌡∫∬∮∴xozstosssuwtrousmqqtqvlvyvrwzvot", 23)
    local expected = {
      status = "@",
      id = "xozstosssuwtrousmqqtqvlvyvrwzvot",
      id_short = "x",
      empty = true,
      description_first_line = "",
      bookmarks = {},
      tags = {},
      git_head = false,
      conflict = false,
      immutable = false,
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing an empty root change, the parser shall yield the correct status and id", function()
    local result = require("jiejie.parsers").parse_change(
      "◆  p	†‡docs: add priorities to roadmap⌠ main⌡∫ git_head()∬∮ immutable∴pynyrqkzpllmxlmpvvvwttzosvktvvkx",
      23
    )
    local expected = {
      status = "◆",
      id = "pynyrqkzpllmxlmpvvvwttzosvktvvkx",
      id_short = "p",
      empty = false,
      description_first_line = "docs: add priorities to roadmap",
      bookmarks = { "main" },
      tags = {},
      git_head = true,
      conflict = false,
      immutable = true,
      linenr = 23,
    }
    eq(expected, result)
  end)

  --
end)

describe("jiejie parse_object", function()
  --

  it("When parsing an empty string, the parser shall yield an object with @ as change_id", function()
    local result = require("jiejie.parsers").parse_object("")
    local expected = {
      change_id = "@",
      work_tree = nil,
      filename = nil,
    }
    eq(expected, result)
  end)

  it("When parsing the filename separator, the parser shall yield an object with @ as change_id", function()
    local result = require("jiejie.parsers").parse_object(":")
    local expected = {
      change_id = "@",
      work_tree = nil,
      filename = nil,
    }
    eq(expected, result)
  end)

  it("When parsing a change id, the parser shall yield an object with the change_id", function()
    local result = require("jiejie.parsers").parse_object("main")
    local expected = {
      change_id = "main",
      work_tree = nil,
      filename = nil,
    }
    eq(expected, result)
  end)

  it("When parsing a change id that has a trailing filename separator, the parser shall yield an object with the change_id", function()
    local result = require("jiejie.parsers").parse_object("main:")
    local expected = {
      change_id = "main",
      work_tree = nil,
      filename = nil,
    }
    eq(expected, result)
  end)

  it("When parsing a filename without a change id, the parser shall yield an object with @ as change_id", function()
    local result = require("jiejie.parsers").parse_object(":file")
    local expected = {
      change_id = "@",
      work_tree = nil,
      filename = "file",
    }
    eq(expected, result)
  end)

  it("When parsing a filename with a change id, the parser shall yield with the change_id", function()
    local result = require("jiejie.parsers").parse_object("main:file")
    local expected = {
      change_id = "main",
      work_tree = nil,
      filename = "file",
    }
    eq(expected, result)
  end)

  it("When parsing a work tree without a change id, the parser shall yield an object with @ as change_id", function()
    local result = require("jiejie.parsers").parse_object(":(tree)")
    local expected = {
      change_id = "@",
      work_tree = "tree",
      filename = nil,
    }
    eq(expected, result)
  end)

  it("When parsing a work tree with a change id and a file name, the parser shall yield an object with the change_id and filename", function()
    local result = require("jiejie.parsers").parse_object("main:(tree)my/file123.txt")
    local expected = {
      change_id = "main",
      work_tree = "tree",
      filename = "my/file123.txt",
    }
    eq(expected, result)
  end)

  --
end)

describe("jiejie parse_filename", function()
  --

  it("When parsing an empty string, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_filename("", 23)
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing an unknown modification, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_filename("│  X lua/jiejie/buffer.lua", 23)
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a modified filename, the parser shall yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  M lua/jiejie/buffer.lua", 23)
    local expected = {
      modification = "M",
      filename = "lua/jiejie/buffer.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  -- TODO: continue here

  it("When parsing an added filename, the parser shall yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  A lua/jiejie/log_diff.lua", 23)
    local expected = {
      modification = "A",
      filename = "lua/jiejie/log_diff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a deleted filename, the parser shall yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  D lua/jiejie/log_diff.lua", 23)
    local expected = {
      modification = "D",
      filename = "lua/jiejie/log_diff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a renamed filename, the parser shall adjust and yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  R lua/jiejie/{log_diff => log_duff}.lua", 23)
    local expected = {
      modification = "R",
      filename = "lua/jiejie/log_duff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a copied filename, the parser shall adjust and yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  C lua/{jiejie => test}/log_diff.lua", 23)
    local expected = {
      modification = "C",
      filename = "lua/test/log_diff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a copied filename that has an empty source, the parser shall adjust and yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  C lua/{ => test}/log_diff.lua", 23)
    local expected = {
      modification = "C",
      filename = "lua/test/log_diff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  it("When parsing a filename that has multiple replacement section, the parser shall adjust and yield the filename", function()
    local result = require("jiejie.parsers").parse_filename("│  C lua/{x => test}/{log_diff => log_duff}.lua", 23)
    local expected = {
      modification = "C",
      filename = "lua/test/log_duff.lua",
      linenr = 23,
    }
    eq(expected, result)
  end)

  --
end)

describe("jiejie parse_url", function()
  --

  it("When parsing an empty string, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_url("")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a URL that doesn't have a root directory, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_url("jiejie://")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a URL that doesn't contain a .jj directory, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_url("jiejie://.")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a URL that doesn't contain a .jj directory, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_url("jiejie://./")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a URL that doesn't contain a revision, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_url("jiejie://./.jj/")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a URL that doesn't contain a file path, the parser shall yield  the url, expand the root path but avoid path", function()
    local result = require("jiejie.parsers").parse_url("jiejie://./.jj/revision")
    local expected = {
      scheme = "jiejie://",
      root = vim.fn.getcwd(),
      revision = "revision",
    }
    eq(expected, result)
  end)

  it("When parsing a URL that contains all required elements, the parser shall yield the url and expand the root path", function()
    local result = require("jiejie.parsers").parse_url("jiejie://./.jj/revision/path/xy")
    local expected = {
      scheme = "jiejie://",
      root = vim.fn.getcwd(),
      revision = "revision",
      path = "path/xy",
    }
    eq(expected, result)
  end)

  it("When parsing a URL that contains a .jj directory in the path, the parser shall yield the url and expand the root path", function()
    local result = require("jiejie.parsers").parse_url("jiejie://./.jj/revision/path/.jj/xy")
    local expected = {
      scheme = "jiejie://",
      root = vim.fn.getcwd(),
      revision = "revision",
      path = "path/.jj/xy",
    }
    eq(expected, result)
  end)

  --
end)

describe("jiejie parse_url", function()
  --

  it("When parsing an empty string, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_hunk("")
    local expected = false
    eq(expected, result)
  end)

  it("When parsing a line that looks like a hunk but isn't, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_hunk("@@ ")
    local expected = false
    eq(expected, result)
  end)

  it("When parsing a line that looks like a hunk but isn't, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_hunk("@@ xx @")
    local expected = false
    eq(expected, result)
  end)

  it("When parsing a line that looks like a hunk but isn't, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_hunk("@ xx @@")
    local expected = false
    eq(expected, result)
  end)

  it("When parsing a hunk, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_hunk("@@ xyz @@")
    local expected = true
    eq(expected, result)
  end)

  --
end)

describe("jiejie parse_bookmark", function()
  --

  it("When parsing an empty string, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_bookmark("")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a bookmark without all separators, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_bookmark("main†false‡true")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a bookmark without a name, the parser shall yield nil", function()
    local result = require("jiejie.parsers").parse_bookmark("†false‡true⌠")
    local expected = nil
    eq(expected, result)
  end)

  it("When parsing a bookmark without a remote, the parser shall yield the object", function()
    local result = require("jiejie.parsers").parse_bookmark("main†false‡true⌠⌡∫∬")
    local expected = {
      name = "main",
      tracked = false,
      present = true,
    }
    eq(expected, result)
  end)

  it("When parsing a bookmark with a remote, the parser shall yield the object", function()
    local result = require("jiejie.parsers").parse_bookmark("main†false‡true⌠origin⌡id∫short_id∬description")
    local expected = {
      name = "main",
      tracked = false,
      present = true,
      remote = "origin",
      id = "id",
      id_short = "short_id",
      description_first_line = "description",
    }
    eq(expected, result)
  end)

  --
end)
