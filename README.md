# Fleeting Notes KOReader Plugin

Capture quick notes while reading with Markdown support and Obsidian compatibility.

## Features

- **Quick Note Capture**: Create notes without leaving your book
- **Markdown Support**: Full Markdown syntax with toolbar buttons
- **Obsidian Compatible**: Notes saved as timestamped `.md` files
- **E-ink Optimized**: Designed for E-ink displays

## Installation

1. Copy `fleeting-notes.koplugin` to KOReader's plugins directory:
   - On Kobo: `.adds/koreader/plugins/`
   - On Kindle: `koreader/plugins/`
   - On Android: `<storage>/koreader/plugins/`

2. Restart KOReader

3. Find "Fleeting Notes" in the plugin menu (☰ → Plugins)

## Usage

### Creating a Note

1. Open "Fleeting Notes" from the plugins menu
2. Type your note in the text area
3. Use toolbar buttons for Markdown formatting
4. Tap "Save" to save or "Cancel" to discard

### Markdown Toolbar

| Button | Action |
|--------|--------|
| **B** | Bold: `**text**` |
| *I* | Italic: `*text*` |
| </> | Code: `` `code` `` |
| H1, H2, H3 | Headings: `# `, `## `, `### ` |
| •- | Bullet list: `- item` |
| 1. | Numbered list: `1. item` |
| [L] | Link: `[text](url)` |

### Note Storage

Notes are saved with timestamp-based filenames:
```
2026-01-14-16-56-30.md
```

Location: `<KOReader data directory>/fleeting-notes/`

### Obsidian Integration

To sync with Obsidian:

1. **Option A: Symbolic Link**
   ```bash
   ln -s /path/to/koreader/fleeting-notes ~/ObsidianVault/FleetingNotes
   ```

2. **Option B: Copy/Sync**
   Use rsync, git, or a sync tool to copy notes to your Obsidian vault.

3. **Option C: Configure Obsidian**
   Add the notes folder as an additional attachment folder in Obsidian settings.

## Development

### Running Tests

```bash
# Install dependencies
luarocks install busted

# Run all tests
busted

# Run specific test file
busted spec/file_storage_spec.lua

# Watch mode
busted --auto-watch
```

### Code Linting

```bash
# Install luacheck
luarocks install luacheck

# Run linting
luacheck *.lua
```

## Project Structure

```
fleeting-notes.koplugin/
├── main.lua                  # Plugin entry point
├── _meta.lua                 # Plugin metadata
├── file_storage.lua          # File I/O operations
├── note_manager.lua          # Note CRUD operations
├── markdown_formatter.lua    # Markdown syntax helpers
├── markdown_editor.lua       # Editor UI widget
├── spec/                     # Test directory
│   ├── file_storage_spec.lua
│   ├── note_manager_spec.lua
│   ├── markdown_formatter_spec.lua
│   ├── markdown_editor_spec.lua
│   └── main_spec.lua
└── data/                     # Runtime notes directory (gitignored)
    └── notes/
```

## License

MIT License - See LICENSE file for details.

## Contributing

Contributions welcome! Please read CLAUDE.md for development guidelines.
