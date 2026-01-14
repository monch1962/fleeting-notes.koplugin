# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a KOReader plugin for creating and managing "fleeting notes" - quick temporary notes while reading. KOReader is a document reader application for E-ink devices.

### Core Features

1. **Fleeting Notes Capture**: Create quick text notes while reading in KOReader
2. **Markdown Support**: Full Markdown syntax support with a toolbar at the top of the editor
3. **Obsidian Compatibility**: Notes stored as individual Markdown files for easy syncing with Obsidian
4. **Timestamp-based Filenames**: Each note uses format `YYYY-MM-DD-HH-MM-SS.md` (e.g., `2026-01-14-16-56-00.md`)

### Project Goals

- Seamless integration with KOReader's reading experience
- Fast note capture for readers who want to jot down thoughts without leaving their book
- Compatibility with Obsidian's vault system for later organization and review

## KOReader Plugin Architecture

KOReader plugins are Lua-based with the following key characteristics:

### Required Files

- `main.lua` - Entry point that returns a plugin table with required methods
- `_meta.lua` - Plugin metadata (name, version, description)

### Plugin Table Structure

The main.lua must return a table with these methods:
```lua
local Plugin = {
    -- Disables the plugin menu item (optional)
    disabled = false,

    -- Menu item text
    menu_text = _("Plugin Name"),

    -- Path to submenu (if any)
    submenu_text = _("Submenu Name"),

    -- Check if plugin should be shown in menu
    is_always_enabled = true, -- or false/conditional function
}

function Plugin:init()
    -- Called when plugin is loaded
end

function Plugin:start()
    -- Called when plugin is activated from menu
end

return Plugin
```

### KOReader UI Framework

- **UI Elements**: Use `UIElement` subclasses like `Widget`, `InputContainer`, `TextWidget`, `Button`, `MovableContainer`
- **Widget System**: All UI components inherit from `widget/uimanager.lua`
- **Event Handling**: Use `onCloseWidget`, `onShowKeyboard` hooks
- **Screens**: Create full-screen interfaces with `CenterContainer`

### Common KOReader APIs

- `ui.menu:registerToMenu()` - Add plugin to main menu
- ` UIManager:show()` - Display a widget
- ` UIManager:close()` - Close a widget
- ` UIManager:nextTick()` - Schedule callbacks
- `_("text")` - Translation wrapper (use for user-facing strings)
- `G_reader_settings` - Persistent settings storage
- `DataStorage` - Cross-platform data directory access

### Data Storage Paths

```lua
local DataStorage = require("datastorage")
local plugin_path = DataStorage:getDataDir() .. "/plugins/fleeting-notes.koplugin"
```

## Fleeting Notes Plugin Architecture

### Core Modules

```
fleeting-notes.koplugin/
├── main.lua                 # Plugin entry point
├── _meta.lua               # Plugin metadata
├── note_manager.lua        # Note CRUD operations
├── file_storage.lua        # File I/O and naming logic
├── markdown_editor.lua     # Editor UI with toolbar
├── markdown_formatter.lua  # Markdown syntax helpers
└── spec/                   # Test directory
    ├── note_manager_spec.lua
    ├── file_storage_spec.lua
    └── markdown_editor_spec.lua
```

### Module Responsibilities

1. **note_manager.lua**
   - Create, read, update, delete notes
   - Manage note metadata (creation time, modified time)
   - Interface between UI and storage

2. **file_storage.lua**
   - Generate timestamp-based filenames (`YYYY-MM-DD-HH-MM-SS.md`)
   - Read/write Markdown files to disk
   - Manage notes directory structure
   - Handle file system errors

3. **markdown_editor.lua**
   - Main editor UI widget
   - Markdown toolbar with buttons for: **bold**, *italic*, `code`, headers, lists, links
   - Text input area
   - Save/close actions

4. **markdown_formatter.lua**
   - Helper functions for Markdown syntax insertion
   - Text selection handling
   - Syntax wrapping/unwrapping

### Data Flow

```
User triggers plugin
    → main.lua:start()
    → markdown_editor.lua displays UI
    → User types note + uses toolbar
    → User clicks save
    → note_manager.lua creates note
    → file_storage.lua generates filename and writes .md file
```

### Obsidian Integration

Notes are stored in a format compatible with Obsidian:
- Standard Markdown files
- Frontmatter optional (can be added later)
- File naming convention prevents conflicts
- Place notes in a configurable directory for easy vault syncing

## File Naming Conventions

- Use underscores for multi-word files: `note_manager.lua`, `ui_widget.lua`
- Keep file names lowercase

## Quick Reference

### Git Commands
```bash
# Start new feature
git checkout -b feature/feature-name

# Commit with tests
git add .
git commit -m "feat: feature description

- Add feature X
- Tests pass"

# Merge to main
git checkout main
git merge feature/feature-name
```

### Test Commands
```bash
# Run all tests
busted

# Run specific test file
busted spec/note_manager_spec.lua

# Run with verbose output
busted --verbose

# Watch mode for TDD
busted --auto-watch
```

### Lua Dependencies
```bash
# Install busted
luarocks install busted

# Install other dependencies
luarocks install luafilesystem
```

## Testing - TDD Approach

This project uses Test-Driven Development with the **busted** testing framework for Lua.

### Test Framework

- **busted**: Lua testing framework - https://olivinelabs.com/busted/
- Install: `luarocks install busted`
- Run tests: `busted`
- Run single test file: `busted path/to/test_file_spec.lua`
- Watch mode: `busted --auto-watch`

### TDD Workflow

For each new feature:

1. **Create a feature branch**: `git checkout -b feature/feature-name`
2. **Write failing tests**: Create tests that describe the desired behavior
3. **Confirm tests fail**: Run `busted` to verify red state
4. **Implement the feature**: Write minimal code to pass tests
5. **Confirm tests pass**: Run `busted` to verify green state
6. **Refactor**: Clean up code while keeping tests green
7. **Commit**: Commit with passing tests

### Branch Naming

- `feature/feature-name` - New features
- `fix/bug-name` - Bug fixes
- `test/test-name` - When adding tests to existing code
- `refactor/refactor-name` - Code refactoring

### Test File Structure

Tests should mirror the source structure:
```
spec/
  note_manager_spec.lua      -> tests for note_manager.lua
  file_storage_spec.lua      -> tests for file_storage.lua
  markdown_editor_spec.lua   -> tests for markdown_editor.lua
```

### What to Test

- **Unit tests**: Test individual functions in isolation
  - Filename generation with timestamps
  - Markdown parsing/formatting
  - File I/O operations
  - Data validation

- **Integration tests**: Test component interactions
  - Note creation and storage
  - Toolbar button actions
  - Settings persistence

### Manual Testing

After automated tests pass, manually test on KOReader:
1. Symlink plugin directory to KOReader's plugins folder
2. Restart KOReader
3. Navigate to Plugin menu to test functionality
4. Verify on actual E-ink device when possible

## KOReader Device Considerations

- E-ink devices have slow refresh rates - minimize unnecessary redraws
- Touch targets should be large enough for finger input
- Avoid animations that cause ghosting on E-ink screens
- Test on various screen sizes (6", 7.8", 10.3")
