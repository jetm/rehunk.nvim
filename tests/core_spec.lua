#!/usr/bin/env lua
-- Core module tests - can run with plain Lua (no Neovim required)
-- Usage: lua tests/core_spec.lua

-- Setup path to find the module
package.path = package.path .. ";./lua/?.lua;./lua/?/init.lua"

local core = require("rehunk.core")

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
  local ok, err = pcall(fn)
  if ok then
    tests_passed = tests_passed + 1
    print("✓ " .. name)
  else
    tests_failed = tests_failed + 1
    print("✗ " .. name)
    print("  " .. tostring(err))
  end
end

local function assert_eq(expected, actual, msg)
  if expected ~= actual then
    error(string.format("%s: expected %s, got %s", msg or "assertion failed", tostring(expected), tostring(actual)))
  end
end

local function assert_nil(value, msg)
  if value ~= nil then
    error(string.format("%s: expected nil, got %s", msg or "assertion failed", tostring(value)))
  end
end

local function assert_not_nil(value, msg)
  if value == nil then
    error(string.format("%s: expected non-nil value", msg or "assertion failed"))
  end
end

print("\n=== parse_header tests ===\n")

test("parses standard header with all counts", function()
  local h = core.parse_header("@@ -1,3 +1,5 @@")
  assert_eq(1, h.x, "x")
  assert_eq(3, h.y, "y")
  assert_eq(1, h.a, "a")
  assert_eq(5, h.b, "b")
  assert_eq("", h.suffix, "suffix")
end)

test("parses header with function suffix", function()
  local h = core.parse_header("@@ -10,20 +10,25 @@ function foo()")
  assert_eq(10, h.x, "x")
  assert_eq(20, h.y, "y")
  assert_eq(10, h.a, "a")
  assert_eq(25, h.b, "b")
  assert_eq(" function foo()", h.suffix, "suffix")
end)

test("parses header with omitted counts (single line)", function()
  local h = core.parse_header("@@ -5 +5 @@")
  assert_eq(5, h.x, "x")
  assert_eq(1, h.y, "y defaults to 1")
  assert_eq(5, h.a, "a")
  assert_eq(1, h.b, "b defaults to 1")
end)

test("parses header with mixed counts", function()
  local h = core.parse_header("@@ -1,3 +1 @@")
  assert_eq(1, h.x, "x")
  assert_eq(3, h.y, "y")
  assert_eq(1, h.a, "a")
  assert_eq(1, h.b, "b defaults to 1")
end)

test("returns nil for non-header lines", function()
  assert_nil(core.parse_header(" context line"))
  assert_nil(core.parse_header("+added line"))
  assert_nil(core.parse_header("-removed line"))
  assert_nil(core.parse_header("random text"))
end)

print("\n=== count_lines tests ===\n")

test("counts additions only", function()
  local counts = core.count_lines({"+line1", "+line2", "+line3"})
  assert_eq(0, counts.context, "context")
  assert_eq(3, counts.additions, "additions")
  assert_eq(0, counts.deletions, "deletions")
end)

test("counts deletions only", function()
  local counts = core.count_lines({"-line1", "-line2"})
  assert_eq(0, counts.context, "context")
  assert_eq(0, counts.additions, "additions")
  assert_eq(2, counts.deletions, "deletions")
end)

test("counts context only", function()
  local counts = core.count_lines({" line1", " line2", " line3", " line4"})
  assert_eq(4, counts.context, "context")
  assert_eq(0, counts.additions, "additions")
  assert_eq(0, counts.deletions, "deletions")
end)

test("counts mixed lines", function()
  local counts = core.count_lines({" context", "-deleted", "+added", " more context"})
  assert_eq(2, counts.context, "context")
  assert_eq(1, counts.additions, "additions")
  assert_eq(1, counts.deletions, "deletions")
end)

test("ignores comment lines", function()
  local counts = core.count_lines({"# This is a comment", "+added"})
  assert_eq(0, counts.context, "context")
  assert_eq(1, counts.additions, "additions")
  assert_eq(0, counts.deletions, "deletions")
end)

test("ignores no-newline marker", function()
  local counts = core.count_lines({"+added", "\\ No newline at end of file"})
  assert_eq(0, counts.context, "context")
  assert_eq(1, counts.additions, "additions")
  assert_eq(0, counts.deletions, "deletions")
end)

test("returns error for empty lines", function()
  local counts, err = core.count_lines({"+added", ""})
  assert_nil(counts, "should return nil")
  assert_not_nil(err, "should return error")
end)

test("returns error for invalid prefix", function()
  local counts, err = core.count_lines({"+added", "invalid line"})
  assert_nil(counts, "should return nil")
  assert_not_nil(err, "should return error")
end)

print("\n=== build_header tests ===\n")

test("builds standard header", function()
  local header = core.build_header(1, 3, 1, 5, "")
  assert_eq("@@ -1,3 +1,5 @@", header)
end)

test("builds header with suffix", function()
  local header = core.build_header(10, 20, 10, 25, " function foo()")
  assert_eq("@@ -10,20 +10,25 @@ function foo()", header)
end)

test("omits count when Y is 1", function()
  local header = core.build_header(5, 1, 5, 3, "")
  assert_eq("@@ -5 +5,3 @@", header)
end)

test("omits count when B is 1", function()
  local header = core.build_header(5, 3, 5, 1, "")
  assert_eq("@@ -5,3 +5 @@", header)
end)

test("omits both counts when both are 1", function()
  local header = core.build_header(5, 1, 5, 1, "")
  assert_eq("@@ -5 +5 @@", header)
end)

print("\n=== recalculate tests ===\n")

test("recalculates simple hunk - deletions to additions", function()
  local lines = {
    "@@ -1,3 +1,3 @@",
    "-foo",
    "-bar",
    "-zoo",
    "+1",
    "+2",
    "+3",
  }
  local result = core.recalculate(lines)
  assert_not_nil(result, "should return result")
  -- Original: 3 deletions, 3 additions, 0 context
  -- Y = 0 + 3 = 3, B = 0 + 3 = 3 (unchanged)
  assert_eq("@@ -1,3 +1,3 @@", result.lines[1])
end)

test("recalculates hunk after removing addition", function()
  local lines = {
    "@@ -1,3 +1,3 @@",  -- Header claims 3 additions, but we have 2
    "-foo",
    "-bar",
    "-zoo",
    "+1",
    "+3",  -- Removed +2
  }
  local result = core.recalculate(lines)
  assert_not_nil(result, "should return result")
  -- Y = 0 context + 3 deletions = 3
  -- B = 0 context + 2 additions = 2
  assert_eq("@@ -1,3 +1,2 @@", result.lines[1])
end)

test("recalculates hunk with context lines", function()
  local lines = {
    "@@ -1,5 +1,5 @@",
    " context before",
    "-deleted",
    "+added1",
    "+added2",
    " context after",
  }
  local result = core.recalculate(lines)
  assert_not_nil(result, "should return result")
  -- Y = 2 context + 1 deletion = 3
  -- B = 2 context + 2 additions = 4
  assert_eq("@@ -1,3 +1,4 @@", result.lines[1])
end)

test("handles multiple hunks", function()
  local lines = {
    "@@ -1,2 +1,2 @@",
    "-old1",
    "+new1",
    "@@ -10,2 +10,2 @@",
    "-old2",
    "+new2a",
    "+new2b",
  }
  local result = core.recalculate(lines)
  assert_not_nil(result, "should return result")
  assert_eq("@@ -1 +1 @@", result.lines[1])  -- Y=1, B=1
  assert_eq("@@ -10 +10,2 @@", result.lines[4])  -- Y=1, B=2 (index 4: after header + 2 body lines)
  assert_eq(2, #result.changes, "should report 2 hunks")
end)

test("preserves non-header lines before first hunk", function()
  local lines = {
    "diff --git a/file.txt b/file.txt",
    "index abc123..def456 100644",
    "--- a/file.txt",
    "+++ b/file.txt",
    "@@ -1,1 +1,1 @@",
    "-old",
    "+new",
  }
  local result = core.recalculate(lines)
  assert_not_nil(result, "should return result")
  assert_eq("diff --git a/file.txt b/file.txt", result.lines[1])
  assert_eq("@@ -1 +1 @@", result.lines[5])
end)

test("tracks changes correctly", function()
  local lines = {
    "@@ -1,3 +1,3 @@",
    "-foo",
    "+bar",
  }
  local result = core.recalculate(lines)
  assert_eq(1, #result.changes, "should have 1 change")
  assert_eq("-1,3 +1,3", result.changes[1].old, "old range")
  assert_eq("-1,1 +1,1", result.changes[1].new, "new range")
end)

print("\n=== Summary ===\n")
print(string.format("Passed: %d, Failed: %d", tests_passed, tests_failed))

if tests_failed > 0 then
  os.exit(1)
end
