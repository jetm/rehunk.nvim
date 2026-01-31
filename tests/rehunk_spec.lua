-- Integration tests using plenary.nvim
-- Run with: nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/rehunk_spec.lua"

local core = require("rehunk.core")
local rehunk = require("rehunk")

describe("rehunk.core", function()
  describe("parse_header", function()
    it("parses standard header", function()
      local h = core.parse_header("@@ -1,3 +1,5 @@")
      assert.are.equal(1, h.x)
      assert.are.equal(3, h.y)
      assert.are.equal(1, h.a)
      assert.are.equal(5, h.b)
    end)

    it("handles omitted counts", function()
      local h = core.parse_header("@@ -5 +5 @@")
      assert.are.equal(1, h.y)
      assert.are.equal(1, h.b)
    end)

    it("returns nil for non-headers", function()
      assert.is_nil(core.parse_header("+added"))
      assert.is_nil(core.parse_header("-removed"))
      assert.is_nil(core.parse_header(" context"))
    end)
  end)

  describe("count_lines", function()
    it("counts additions", function()
      local c = core.count_lines({"+a", "+b"})
      assert.are.equal(2, c.additions)
      assert.are.equal(0, c.deletions)
      assert.are.equal(0, c.context)
    end)

    it("counts deletions", function()
      local c = core.count_lines({"-a", "-b", "-c"})
      assert.are.equal(0, c.additions)
      assert.are.equal(3, c.deletions)
    end)

    it("counts context", function()
      local c = core.count_lines({" a", " b"})
      assert.are.equal(2, c.context)
    end)

    it("ignores comments", function()
      local c = core.count_lines({"# comment", "+a"})
      assert.are.equal(1, c.additions)
    end)

    it("fails on empty lines", function()
      local c, err = core.count_lines({"+a", ""})
      assert.is_nil(c)
      assert.is_not_nil(err)
    end)
  end)

  describe("recalculate", function()
    it("fixes incorrect header counts", function()
      local lines = {
        "@@ -1,3 +1,3 @@",
        "-foo",
        "-bar",
        "-zoo",
        "+1",
        "+3",
      }
      local result = core.recalculate(lines)
      assert.are.equal("@@ -1,3 +1,2 @@", result.lines[1])
    end)

    it("handles context lines", function()
      local lines = {
        "@@ -1,5 +1,5 @@",
        " before",
        "-old",
        "+new1",
        "+new2",
        " after",
      }
      local result = core.recalculate(lines)
      -- Y = 2 context + 1 del = 3
      -- B = 2 context + 2 add = 4
      assert.are.equal("@@ -1,3 +1,4 @@", result.lines[1])
    end)

    it("preserves file headers", function()
      local lines = {
        "diff --git a/f.txt b/f.txt",
        "--- a/f.txt",
        "+++ b/f.txt",
        "@@ -1,1 +1,1 @@",
        "-old",
        "+new",
      }
      local result = core.recalculate(lines)
      assert.are.equal("diff --git a/f.txt b/f.txt", result.lines[1])
      assert.are.equal("@@ -1 +1 @@", result.lines[4])
    end)
  end)
end)

describe("rehunk (integration)", function()
  it("recalculates buffer content", function()
    -- Create a test buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      "@@ -1,3 +1,3 @@",
      "-foo",
      "+bar",
    })

    -- Recalculate
    local ok = rehunk.recalculate(buf)
    assert.is_true(ok)

    -- Check result
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    assert.are.equal("@@ -1 +1 @@", lines[1])

    -- Cleanup
    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  it("attaches command to buffer", function()
    local buf = vim.api.nvim_create_buf(false, true)
    rehunk.attach(buf)

    -- Check command exists
    local cmds = vim.api.nvim_buf_get_commands(buf, {})
    assert.is_not_nil(cmds.RehunkRecalculate)

    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
