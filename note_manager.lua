-- note_manager.lua
-- High-level note CRUD operations
-- Manages note metadata and interfaces with file_storage

local note_manager = {}

-- Load file_storage dependency
local file_storage = require("file_storage")

-- Module state
local notes_dir = file_storage.get_notes_dir()

--- Set the notes directory path
-- @param dir string: Path to notes directory
-- @return boolean: Success status
function note_manager.set_notes_dir(dir)
  local result = file_storage.set_notes_dir(dir)
  if result then
    notes_dir = dir
  end
  return result
end

--- Get the current notes directory path
-- @return string: Path to notes directory
function note_manager.get_notes_dir()
  return notes_dir
end

--- Validate note content
-- @param content string: Content to validate
-- @return boolean: True if valid, false otherwise
function note_manager.validate_content(content)
  -- Check for nil or empty
  if not content or content == "" then
    return false
  end

  -- Check for whitespace-only content
  local trimmed = content:match("^%s*(.-)%s*$")
  if trimmed == "" then
    return false
  end

  return true
end

--- Create a new note
-- @param content string: Note content
-- @param timestamp number: Optional custom timestamp (defaults to current time)
-- @return table|nil: Note object with filename, content, created_at, updated_at or nil on failure
function note_manager.create_note(content, timestamp)
  -- Validate content
  if not note_manager.validate_content(content) then
    return nil
  end

  -- Generate timestamp
  local created_at = timestamp or os.time()

  -- Generate filename
  local filename = file_storage.generate_filename(created_at)

  -- Save note
  local success = file_storage.save_note(filename, content)
  if not success then
    return nil
  end

  -- Return note object
  return {
    filename = filename,
    content = content,
    created_at = created_at,
    updated_at = created_at,
  }
end

--- Update an existing note
-- @param filename string: Name of the note file
-- @param content string: New content
-- @return boolean: Success status
function note_manager.update_note(filename, content)
  -- Validate inputs
  if not filename or filename == "" then
    return false
  end

  if not note_manager.validate_content(content) then
    return false
  end

  -- Check if note exists
  local existing = file_storage.load_note(filename)
  if not existing then
    return false
  end

  -- Save updated content
  local success = file_storage.save_note(filename, content)
  return success
end

--- Delete a note
-- @param filename string: Name of the note file
-- @return boolean: Success status
function note_manager.delete_note(filename)
  -- Validate input
  if not filename or filename == "" then
    return false
  end

  -- Check if note exists
  local existing = file_storage.load_note(filename)
  if not existing then
    return false
  end

  -- Delete the file
  local success = file_storage.delete_note(filename)
  return success
end

--- Get all notes
-- @return table: Array of note objects with metadata
function note_manager.get_all_notes()
  local filenames = file_storage.list_notes()
  local notes = {}

  for _, filename in ipairs(filenames) do
    local content = file_storage.load_note(filename)
    if content then
      -- Extract timestamp from filename
      -- Format: YYYY-MM-DD-HH-MM-SS.md
      local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)-(%d%d)-(%d%d)-(%d%d)-(%d%d)-(%d%d)")

      local created_at = nil
      if year and month and day and hour and min and sec then
        created_at = os.time({
          year = tonumber(year),
          month = tonumber(month),
          day = tonumber(day),
          hour = tonumber(hour),
          min = tonumber(min),
          sec = tonumber(sec),
        })
      end

      table.insert(notes, {
        filename = filename,
        content = content,
        created_at = created_at,
        updated_at = created_at,  -- Same as created_at for now
      })
    end
  end

  return notes
end

--- Get a single note by filename
-- @param filename string: Name of the note file
-- @return table|nil: Note object or nil if not found
function note_manager.get_note(filename)
  -- Validate input
  if not filename or filename == "" then
    return nil
  end

  -- Load content
  local content = file_storage.load_note(filename)
  if not content then
    return nil
  end

  -- Extract timestamp from filename
  local year, month, day, hour, min, sec = filename:match("^(%d%d%d%d)-(%d%d)-(%d%d)-(%d%d)-(%d%d)-(%d%d)")

  local created_at = nil
  if year and month and day and hour and min and sec then
    created_at = os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec),
    })
  end

  return {
    filename = filename,
    content = content,
    created_at = created_at,
    updated_at = created_at,
  }
end

return note_manager
