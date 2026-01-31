--- rehunk.nvim core module
--- Pure Lua functions for diff parsing and recalculation
--- No Neovim APIs - can be tested with plain Lua
local M = {}

--- Parse a hunk header line into components
--- @param line string The line to parse
--- @return table|nil {x=number, y=number, a=number, b=number, suffix=string} or nil if not a header
function M.parse_header(line)
  -- Pattern: @@ -X,Y +A,B @@ [suffix]
  -- Y and B are optional (omitted when count = 1)
  local x, y, a, b, suffix = line:match('^@@%s+%-(%d+),?(%d*)%s+%+(%d+),?(%d*)%s+@@(.*)$')

  if not x then
    return nil
  end

  -- Convert to numbers; default to 1 when count is omitted (single-line hunk)
  return {
    x = tonumber(x),
    y = y ~= '' and tonumber(y) or 1,
    a = tonumber(a),
    b = b ~= '' and tonumber(b) or 1,
    suffix = suffix or '',
  }
end

--- Count lines in a hunk body by prefix type
--- @param lines string[] Array of hunk body lines (between headers)
--- @return table|nil {context=number, additions=number, deletions=number}
--- @return string|nil Error message if invalid prefix found
function M.count_lines(lines)
  local counts = {
    context = 0,
    additions = 0,
    deletions = 0,
  }

  for i, line in ipairs(lines) do
    local prefix = line:sub(1, 1)

    if prefix == ' ' then
      -- Context line (unchanged, counts toward both Y and B)
      counts.context = counts.context + 1
    elseif prefix == '+' then
      -- Addition (counts toward B only)
      counts.additions = counts.additions + 1
    elseif prefix == '-' then
      -- Deletion (counts toward Y only)
      counts.deletions = counts.deletions + 1
    elseif prefix == '#' then
      -- Comment line (git's edit mode instructions) - ignore
    elseif prefix == '\\' then
      -- No-newline marker ("\ No newline at end of file") - ignore
    elseif prefix == '' then
      -- Empty line - this is an error per D6 (fail fast)
      return nil, string.format("Empty line at line %d", i)
    else
      -- Invalid prefix - fail fast per D5
      return nil, string.format("Invalid line prefix '%s' at line %d", prefix, i)
    end
  end

  return counts
end

--- Build a header string from components
--- Handles single-line omission rule (count=1 means omit count)
--- @param x number Original file start line
--- @param y number Original file line count
--- @param a number New file start line
--- @param b number New file line count
--- @param suffix string Optional function context after @@
--- @return string The formatted header line
function M.build_header(x, y, a, b, suffix)
  -- Build the -X,Y part (omit count if Y == 1)
  local old_part
  if y == 1 then
    old_part = string.format('-%d', x)
  else
    old_part = string.format('-%d,%d', x, y)
  end

  -- Build the +A,B part (omit count if B == 1)
  local new_part
  if b == 1 then
    new_part = string.format('+%d', a)
  else
    new_part = string.format('+%d,%d', a, b)
  end

  -- Combine with suffix (suffix includes leading space if present)
  return string.format('@@ %s %s @@%s', old_part, new_part, suffix)
end

--- Format header range for feedback display
--- @param x number Original file start line
--- @param y number Original file line count
--- @param a number New file start line
--- @param b number New file line count
--- @return string The range portion "-X,Y +A,B"
local function format_range(x, y, a, b)
  return string.format('-%d,%d +%d,%d', x, y, a, b)
end

--- Process entire buffer, recalculating all hunk headers
--- @param lines string[] All buffer lines
--- @return table|nil {lines=string[], changes={{hunk=n, old=str, new=str},...}}
--- @return string|nil Error message on failure
function M.recalculate(lines)
  local result_lines = {}
  local changes = {}
  local hunk_number = 0

  local i = 1
  while i <= #lines do
    local line = lines[i]
    local header = M.parse_header(line)

    if header then
      -- Found a hunk header
      hunk_number = hunk_number + 1
      local header_line_idx = i

      -- Collect body lines until next header or end
      local body_lines = {}
      i = i + 1
      while i <= #lines do
        local next_header = M.parse_header(lines[i])
        if next_header then
          break
        end
        table.insert(body_lines, lines[i])
        i = i + 1
      end

      -- Count lines in the body
      local counts, err = M.count_lines(body_lines)
      if not counts then
        return nil, err
      end

      -- Calculate new Y and B values
      -- Y = context + deletions (lines from original file)
      -- B = context + additions (lines in new file)
      local new_y = counts.context + counts.deletions
      local new_b = counts.context + counts.additions

      -- Build new header
      local new_header = M.build_header(header.x, new_y, header.a, new_b, header.suffix)

      -- Track changes
      local old_range = format_range(header.x, header.y, header.a, header.b)
      local new_range = format_range(header.x, new_y, header.a, new_b)

      table.insert(changes, {
        hunk = hunk_number,
        old = old_range,
        new = new_range,
      })

      -- Add new header to result
      table.insert(result_lines, new_header)

      -- Add body lines to result
      for _, body_line in ipairs(body_lines) do
        table.insert(result_lines, body_line)
      end
    else
      -- Not a header line, copy as-is
      table.insert(result_lines, line)
      i = i + 1
    end
  end

  return {
    lines = result_lines,
    changes = changes,
  }
end

return M
