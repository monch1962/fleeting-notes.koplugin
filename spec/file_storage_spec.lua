-- spec/file_storage_spec.lua
-- Tests for file_storage.lua

describe("file_storage", function()
  local file_storage
  private = {}
  local test_notes_dir = "/tmp/fleeting-notes-test"

  -- Setup and teardown
  setup(function()
    -- For file I/O tests, we need to use real lfs and create actual test files
    -- First unload any mock
    package.loaded["lfs"] = nil

    -- Import real lfs
    local real_lfs = require("lfs")

    -- Create test directory
    if real_lfs.attributes(test_notes_dir) then
      -- Directory exists, remove it first
      os.execute("rm -rf " .. test_notes_dir)
    end
    real_lfs.mkdir(test_notes_dir)

    -- Set up test environment
    file_storage = require("file_storage")
    file_storage.set_notes_dir(test_notes_dir)
  end)

  teardown(function()
    -- Clean up mocks
    package.loaded["lfs"] = nil
    package.loaded["file_storage"] = nil
  end)

  before_each(function()
    -- Reset mock state before each test
  end)

  describe("generate_filename", function()
    it("should generate filename with format YYYY-MM-DD-HH-MM-SS.md", function()
      local timestamp = os.time({
        year = 2026,
        month = 1,
        day = 14,
        hour = 16,
        min = 56,
        sec = 30
      })

      local filename = file_storage.generate_filename(timestamp)
      assert.is.equals("2026-01-14-16-56-30.md", filename)
    end)

    it("should use current time when no timestamp provided", function()
      -- Get current time components
      local now = os.date("!*t")
      local filename = file_storage.generate_filename()

      -- Check format matches pattern
      assert.is.truthy(filename:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d%.md$"))
    end)

    it("should handle leap seconds gracefully", function()
      local timestamp = os.time({
        year = 2026,
        month = 1,
        day = 14,
        hour = 16,
        min = 56,
        sec = 60  -- Leap second (will be normalized by os)
      })

      local filename = file_storage.generate_filename(timestamp)
      -- Should produce a valid filename
      assert.is.truthy(filename:match("^%d%d%d%d%-%d%d%-%d%d%-%d%d%-%d%d%-%d%d%.md$"))
    end)

    it("should ensure unique filenames when called rapidly", function()
      -- This test creates actual files to test the counter mechanism
      local base_time = os.time({
        year = 2026,
        month = 1,
        day = 14,
        hour = 16,
        min = 56,
        sec = 0
      })

      -- Create a few files with the same timestamp
      local filenames = {}
      for i = 1, 5 do
        local filename = file_storage.generate_filename(base_time)
        filenames[filename] = true
        -- Create the file so next call gets a different name
        file_storage.save_note(filename, "# Test note " .. i)
      end

      -- Should have 5 unique filenames
      local count = 0
      for _ in pairs(filenames) do
        count = count + 1
      end
      assert.is.equals(5, count)
    end)
  end)

  describe("save_note", function()
    it("should save note content to file", function()
      local filename = "2026-01-14-16-56-00.md"
      local content = "# Test Note\n\nThis is a test note."

      local result = file_storage.save_note(filename, content)
      assert.is.truthy(result)
    end)

    it("should return error for invalid filename", function()
      local result = file_storage.save_note("", "content")
      assert.is.falsy(result)
    end)

    it("should handle empty content", function()
      local filename = "2026-01-14-16-56-00.md"
      local result = file_storage.save_note(filename, "")
      assert.is.truthy(result)
    end)
  end)

  describe("load_note", function()
    it("should load note content from file", function()
      local filename = "2026-01-14-16-56-00.md"
      local content = "# Test Note\n\nThis is a test note."

      -- First save it
      file_storage.save_note(filename, content)

      -- Then load it
      local loaded = file_storage.load_note(filename)
      assert.is.equals(content, loaded)
    end)

    it("should return nil for non-existent file", function()
      local loaded = file_storage.load_note("nonexistent.md")
      assert.is_nil(loaded)
    end)

    it("should return nil for invalid filename", function()
      local loaded = file_storage.load_note("")
      assert.is_nil(loaded)
    end)
  end)

  describe("list_notes", function()
    it("should return array of note filenames", function()
      -- Create some test files first
      file_storage.save_note("2026-01-14-10-30-00.md", "# Test 1")
      file_storage.save_note("2026-01-14-11-45-30.md", "# Test 2")

      local notes = file_storage.list_notes()

      assert.is_truthy(type(notes) == "table")
      assert.is_truthy(#notes >= 2)  -- At least our 2 test files
    end)

    it("should return empty array when no notes exist", function()
      file_storage.set_notes_dir("/tmp/empty-dir")
      local notes = file_storage.list_notes()
      assert.is.same({}, notes)
      file_storage.set_notes_dir(test_notes_dir)  -- Reset
    end)

    it("should only return .md files", function()
      local notes = file_storage.list_notes()

      for _, filename in ipairs(notes) do
        assert.is_truthy(filename:match("%.md$"))
      end
    end)

    it("should return filenames in sorted order", function()
      local notes = file_storage.list_notes()

      -- Check if sorted
      local sorted = {}
      for i, v in ipairs(notes) do
        sorted[i] = v
      end
      table.sort(sorted)

      assert.is.same(sorted, notes)
    end)
  end)

  describe("delete_note", function()
    it("should delete note file", function()
      local filename = "2026-01-14-16-56-00.md"
      local content = "# Test Note"

      -- Save first
      file_storage.save_note(filename, content)

      -- Then delete
      local result = file_storage.delete_note(filename)
      assert.is.truthy(result)

      -- Verify it's gone
      local loaded = file_storage.load_note(filename)
      assert.is_nil(loaded)
    end)

    it("should return false for non-existent file", function()
      local result = file_storage.delete_note("nonexistent.md")
      assert.is_falsy(result)
    end)

    it("should return false for invalid filename", function()
      local result = file_storage.delete_note("")
      assert.is_falsy(result)
    end)
  end)

  describe("notes directory management", function()
    it("should set notes directory path", function()
      local new_dir = "/tmp/custom-notes"
      local result = file_storage.set_notes_dir(new_dir)
      assert.is_truthy(result)
    end)

    it("should create notes directory if it doesn't exist", function()
      local new_dir = "/tmp/new-notes-dir"
      local result = file_storage.ensure_notes_dir(new_dir)
      assert.is_truthy(result)
    end)
  end)
end)
