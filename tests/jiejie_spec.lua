-- tests/my_plugin_spec.lua
local eq = assert.are.same

describe("my plugin", function()
  it("When parsing an empty root commit, the parser shall yield the correct status and id", function()
    local result = require("jiejie.internal").parseCommit("◆  z	†(empty) ‡(no description set)⌠⌡∬")
    local expected = { status = "◆", id = "z" }
    eq(expected, result)
  end)

  -- it("handles edge cases", function()
  --   assert.is_true(some_condition)
  -- end)
end)

-- @  nn	‡(no description set)⌠⌡∬
-- │ ×  m	‡conflict⌠⌡∬
-- ├─╯
-- ◆  k	‡conflict arising⌠ bm⌡ ta∬ git_head()
-- ~  (elided revisions)
-- │ ○  t	‡chore: even more⌠⌡∬
-- ├─╯
-- ◆  nw	‡chore: more content⌠⌡∬
-- ~  (elided revisions)
-- ◆  z	†(empty) ‡(no description set)⌠⌡∬
