# Fleeting Notes KOReader Plugin

Capture quick notes while reading with Markdown support and Obsidian compatibility.

## Features

- **Quick Note Capture**: Create notes without leaving your book
- **Markdown Support**: Full Markdown syntax with toolbar buttons
- **Obsidian Compatible**: Notes saved as timestamped `.md` files
- **E-ink Optimized**: Designed for E-ink displays

## Deployment / Installation

### Method 1: Direct Copy (Simple)

1. **Find your KOReader plugins directory** on your device:

   | Device | Plugins Directory |
   |--------|-------------------|
   | Kobo | `.adds/koreader/plugins/` |
   | Kindle | `koreader/plugins/` |
   | Android | `<storage>/koreader/plugins/` |
   | Windows | `C:\Users\<User>\App\Local\koreader\plugins\` |
   | macOS | `~/.config/koreader/plugins/` |
   | Linux | `~/.config/koreader/plugins/` |

2. **Copy the plugin folder** to the plugins directory:

   ```bash
   # Make sure the folder name ends with .koplugin
   cp -r fleeting-notes.koplugin /path/to/koreader/plugins/
   ```

3. **Restart KOReader** (fully close and reopen the app)

4. **Access the plugin**: Go to ☰ → Plugins → Fleeting Notes

---

### Method 2: Symbolic Link (Development)

For development or easy updates, create a symbolic link:

```bash
# On Kobo/Kindle (over SSH)
cd /mnt/onboard/.adds/koreader/plugins/
ln -s /path/to/development/fleeting-notes.koplugin

# On macOS/Linux
cd ~/.config/koreader/plugins/
ln -s ~/Projects/fleeting-notes.koplugin
```

---

### Method 3: Git Clone (Latest Version)

Clone directly into the plugins directory:

```bash
cd /path/to/koreader/plugins/
git clone https://github.com/yourusername/fleeting-notes.koplugin.git
```

---

### Device-Specific Notes

#### Kobo (via SSH)

1. Enable SSH on your Kobo (search for "Kobo SSH enable")
2. Connect to your Kobo: `ssh root@192.168.2.2` (or similar IP)
3. Copy the plugin:
   ```bash
   scp -r fleeting-notes.koplugin root@192.168.2.2:/mnt/onboard/.adds/koreader/plugins/
   ```
4. Restart KOReader

#### Kindle (via USB over SSH or KUAL)

1. Install KOReader if not already installed
2. Copy `fleeting-notes.koplugin` to `koreader/plugins/` via USB
3. Eject and restart KOReader

#### Android

1. Using a file manager, navigate to your internal storage
2. Go to `koreader/plugins/`
3. Copy `fleeting-notes.koplugin` there
4. Restart KOReader

#### Desktop (Windows/macOS/Linux)

1. Navigate to your KOReader configuration directory (see table above)
2. Copy `fleeting-notes.koplugin` to the `plugins/` subdirectory
3. Restart KOReader

---

### Verifying Installation

After restarting KOReader:

1. Tap the ☰ menu
2. Select "Plugins"
3. Look for "Fleeting Notes" in the list
4. Tap it to open the editor

### Finding Your Notes

Notes are stored in:
```
<KOReader data directory>/fleeting-notes/
```

Default data directory locations:
- **Kobo**: `/mnt/onboard/.adds/koreader/data/`
- **Kindle**: `/mnt/us/koreader/data/`
- **Android**: `<storage>/koreader/data/`
- **Desktop**: `~/.config/koreader/data/` (Linux/macOS) or `%APPDATA%\koreader\data\` (Windows)

---

## Usage

### Creating a Note

1. Open "Fleeting Notes" from the plugins menu
2. Type your note in the text area
3. Use toolbar buttons for Markdown formatting
4. Tap "Save" to save or "Cancel" to discard

### Markdown Toolbar

| Button | Action | Example |
|--------|--------|---------|
| **B** | Bold | `**text**` |
| *I* | Italic | `*text*` |
| </> | Code | `` `code` `` |
| H1, H2, H3 | Headings | `# Text`, `## Text`, `### Text` |
| •- | Bullet list | `- item` |
| 1. | Numbered list | `1. item` |
| [L] | Link | `[text](url)` |

### Note Storage Format

Notes are saved with timestamp-based filenames:
```
2026-01-14-16-56-30.md
2026-01-14-17-45-00.md
```

Each file contains standard Markdown content.

---

## Obsidian Integration

### Option A: Symbolic Link

Link the KOReader notes folder into your Obsidian vault:

```bash
# On macOS/Linux
ln -s ~/.config/koreader/data/fleeting-notes ~/Documents/ObsidianVault/FleetingNotes

# On Windows (mklink requires admin prompt)
mklink /D "C:\Path\To\ObsidianVault\FleetingNotes" "C:\Users\YourName\AppData\Local\koreader\data\fleeting-notes"
```

### Option B: Copy/Sync Script

Use rsync, git, or a cloud sync tool:

```bash
# Sync via rsync
rsync -av ~/.config/koreader/data/fleeting-notes/ ~/Documents/ObsidianVault/FleetingNotes/

# Or use a git repo
cd ~/.config/koreader/data/fleeting-notes
git init
git remote add origin https://github.com/yourusername/notes.git
```

### Option C: Obsidian Attachment Folder

In Obsidian Settings → Files & Links → Attachment Folder Path:
- Set path to your KOReader `fleeting-notes` directory

---

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

# Or use the convenience script
./run-tests.sh
```

### Code Linting

```bash
# Install luacheck
luarocks install luacheck

# Run linting
luacheck *.lua
```

### Project Structure

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
├── .busted                   # Test configuration
├── .luacheckrc              # Linting configuration
├── run-tests.sh             # Test runner script
├── CLAUDE.md                # Development guidelines
└── README.md                # This file
```

## Troubleshooting

**Plugin doesn't appear in menu:**
- Verify the folder name ends with `.koplugin`
- Check that `main.lua` and `_meta.lua` exist in the folder
- Restart KOReader completely (close fully, not just suspend)

**Notes not saving:**
- Check that the data directory is writable
- Look for error messages in KOReader's crash.log

**Toolbar buttons don't work:**
- Make sure you've selected text before clicking (for formatting)
- Some buttons insert at cursor position if no text is selected

## License

MIT License

## Contributing

Contributions welcome! Please read `CLAUDE.md` for development guidelines and TDD workflow.
