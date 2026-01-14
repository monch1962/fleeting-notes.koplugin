-- file_storage.lua
-- Handles file I/O operations for fleeting notes
-- Generates timestamp-based filenames and manages note storage

local file_storage = {}

-- Module state
local notes_dir = "/tmp/fleeting-notes"
local filename_counter = 0  -- For handling rapid creation

-- Helper: Try to load lfs (LuaFileSystem)
-- In KOReader, use libs/libkoreader-lfs.lua
local ok, lfs_module = pcall(require, "lfs")
local lfs
if ok then
  lfs = lfs_module
else
  -- Try KOReader's lfs location
  local ok2, koreader_lfs = pcall(require, "libs/libkoreader-lfs")
  if ok2 then
    lfs = koreader_lfs
  else
    error("Required library 'lfs' not found. Please install LuaFileSystem.")
  end
end

-- Set the notes directory
-- @param dir string: Path to notes directory
-- @return boolean: Success status
function file_storage.set_notes_dir(dir)
  if type(dir) ~= "string" or dir == "" then
    return false
  end

  notes_dir = dir
  return file_storage.ensure_notes_dir(dir)
end

-- Get the current notes directory
-- @return string: Path to notes directory
function file_storage.get_notes_dir()
  return notes_dir
end

-- Ensure notes directory exists, create if not
-- @param dir string: Optional directory path (uses notes_dir if not provided)
-- @return boolean: Success status
function file_storage.ensure_notes_dir(dir)
  local target_dir = dir or notes_dir

  -- Check if directory exists
  local attrs = lfs.attributes(target_dir)
  if attrs and attrs.mode == "directory" then
    return true
  end

  -- Try to create directory
  -- Note: lfs.mkdir doesn't create parents recursively
  local result, err = lfs.mkdir(target_dir)
  if result then
    return true
  end

  -- If failed, try to create parent directories first
  -- This is a simple implementation - for production, you might want
  -- a more robust path handling
  return false, err
end

-- Generate timestamp-based filename
-- Format: YYYY-MM-DD-HH-MM-SS.md
-- @param timestamp number: Optional Unix timestamp (uses current time if not provided)
-- @return string: Generated filename
function file_storage.generate_filename(timestamp)
  local ts = timestamp or os.time()

  -- Format: YYYY-MM-DD-HH-MM-SS (24-hour clock, local time)
  local date_str = os.date("%Y-%m-%d-%H-%M-%S", ts)

  -- Handle rapid creation in the same second
  -- Add a counter suffix if multiple files in same second
  local filename = date_str .. ".md"

  -- Check if file exists and add counter if needed
  local counter = 0
  local full_path = notes_dir .. "/" .. filename

  -- Try to read the file to see if it exists
  local f = io.open(full_path, "r")
  while f do
    f:close()
    counter = counter + 1
    -- Add counter suffix: -1, -2, etc.
    filename = date_str .. "-" .. counter .. ".md"
    full_path = notes_dir .. "/" .. filename
    f = io.open(full_path, "r")
  end

  return filename
end

-- Save note content to file
-- @param filename string: Name of the file
-- @param content string: Content to save
-- @return boolean: Success status
function file_storage.save_note(filename, content)
  if not filename or filename == "" then
    return false
  end

  -- Ensure directory exists
  file_storage.ensure_notes_dir()

  local full_path = notes_dir .. "/" .. filename

  local file, err = io.open(full_path, "w")
  if not file then
    return false, err
  end

  file:write(content)
  file:close()

  return true
end

-- Load note content from file
-- @param filename string: Name of the file
-- @return string|nil: File content or nil if not found
function file_storage.load_note(filename)
  if not filename or filename == "" then
    return nil
  end

  local full_path = notes_dir .. "/" .. filename

  local file, err = io.open(full_path, "r")
  if not file then
    return nil
  end

  local content = file:read("*all")
  file:close()

  return content
end

-- List all notes in the notes directory
-- @return table: Array of note filenames (sorted)
function file_storage.list_notes()
  local notes = {}

  -- Ensure directory exists
  local attrs = lfs.attributes(notes_dir)
  if not attrs or attrs.mode ~= "directory" then
    return notes
  end

  -- Iterate through directory
  for filename in lfs.dir(notes_dir) do
    -- Skip dot files
    if filename:sub(1, 1) ~= "." then
      -- Only include .md files
      if filename:match("%.md$") then
        table.insert(notes, filename)
      end
    end
  end

  -- Sort filenames
  table.sort(notes)

  return notes
end

-- Delete a note file
-- @param filename string: Name of the file to delete
-- @return boolean: Success status
function file_storage.delete_note(filename)
  if not filename or filename == "" then
    return false
  end

  local full_path = notes_dir .. "/" .. filename

  -- Check if file exists
  local file = io.open(full_path, "r")
  if not file then
    return false
  end
  file:close()

  -- Delete file
  local result = os.remove(full_path)

  return result ~= nil
end

return file_storage
