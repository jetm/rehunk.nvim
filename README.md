# rehunk.nvim

Automatic diff header recalculation for `git add -p` hunk editing.

When you edit a hunk during interactive staging (`git add -p` → `e`), git requires the `@@ -X,Y +A,B @@` header to match the actual line counts. Manual counting is error-prone and leads to "Your edited hunk does not apply" errors. This plugin automatically recalculates the header on save.

## Installation

### lazy.nvim

```lua
{
  "jetm/rehunk.nvim",
  ft = "diff",  -- Load when opening diff files
}
```

### packer.nvim

```lua
use {
  "jetm/rehunk.nvim",
  ft = "diff",
}
```

## Usage

1. Run `git add -p` and select a hunk
2. Press `e` to edit the hunk
3. Make your changes (add/remove lines)
4. Save the file - the header is automatically recalculated
5. Close the editor - git applies the corrected hunk

### Manual Recalculation

The `:RehunkRecalculate` command is available in hunk edit buffers if you need to recalculate without saving.

## Configuration

The plugin works out of the box with zero configuration. Optional settings:

```lua
{
  "jetm/rehunk.nvim",
  ft = "diff",
  opts = {
    auto_recalculate = true,  -- Recalculate on save (default: true)
  },
}
```

## Requirements

- Neovim 0.8+
- No external dependencies

## How It Works

The plugin detects when Neovim opens git's hunk edit temp file (`*addp-hunk-edit.diff`). It parses the diff, counts lines by prefix (`+` additions, `-` deletions, ` ` context), and updates the header counts:

- `Y` (original count) = context lines + deletion lines
- `B` (new count) = context lines + addition lines

## Local Development

### Setup

Clone the repository and add it to your Neovim config:

```lua
-- lazy.nvim local development
{
  dir = "~/path/to/rehunk.nvim",
  ft = "diff",
}
```

### Testing

Run tests with:

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Or test core functions in isolation (no Neovim needed):

```bash
lua tests/core_spec.lua
```

### Manual Testing

```bash
# Create a test file with changes
echo -e "foo\nbar\nbaz" > /tmp/test.txt
git init /tmp/test-repo && cd /tmp/test-repo
echo -e "foo\nbar\nbaz" > test.txt && git add test.txt && git commit -m "init"
echo -e "1\n2\n3" > test.txt

# Test interactive staging
git add -p
# Select 'e' to edit, modify the hunk, save
```

## License

MIT
