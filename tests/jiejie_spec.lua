-- tests/my_plugin_spec.lua
local eq = assert.are.same

describe("my plugin", function()
  it("does something", function()
    local result = require("jiejie.internal").parse("")
    local expected = {}
    eq(expected, result)
  end)

  -- it("handles edge cases", function()
  --   assert.is_true(some_condition)
  -- end)
end)

-- ×  mm   conflict
-- @  k    conflict arising
-- ○  mx   other change
-- │ ○  t  chore: even more
-- ├─╯
-- ○  n    chore: more content
-- ○  my   chore: initial content
-- ◆  z

-- @  m
-- ◆  t    chore: update dependencies
-- │
-- ~

-- ×  mm jan-christoph.ebersbach@identinet.io 2026-01-01 10:42:19 185cff13 conflict
-- │  conflict
-- @  k jan-christoph.ebersbach@identinet.io 2026-01-01 10:42:19 086b9083
-- │  conflict arising
-- ○  mx jan-christoph.ebersbach@identinet.io 2026-01-01 10:41:07 git_head() a5c3c7d1
-- │  other change
-- │ ○  t jan-christoph.ebersbach@identinet.io 2026-01-01 08:33:53 4a997aae
-- ├─╯  chore: even more
-- ○  n jan-christoph.ebersbach@identinet.io 2026-01-01 08:33:40 1c485f70
-- │  chore: more content
-- ○  my jan-christoph.ebersbach@identinet.io 2026-01-01 08:33:21 fe908377
-- │  chore: initial content
-- ◆  z root() 00000000
