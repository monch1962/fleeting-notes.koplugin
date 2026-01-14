-- spec/note_manager_spec.lua
-- Tests for note_manager.lua

describe("note_manager", function()
  local note_manager
  local file_storage
  local test_notes_dir = "/tmp/fleeting-notes-test"

  setup(function()
    -- Mock file_storage
    file_storage = {
      set_notes_dir = function() return true end,
      get_notes_dir = function() return test_notes_dir end,
      ensure_notes_dir = function() return true end,
      generate_filename = function(ts)
        if ts then
          return os.date("%Y-%m-%d-%H-%M-%S", ts) .. ".md"
        end
        return os.date("%Y-%m-%d-%H-%M-%S") .. ".md"
      end,
      save_note = function(filename, content) return true end,
      load_note = function(filename)
        -- Return nil for non-existent files
        if filename == "nonexistent.md" or filename == "" then
          return nil
        end
        return "# Loaded\nContent"
      end,
      list_notes = function()
        return {"2026-01-14-10-30-00.md", "2026-01-14-11-45-30.md"}
      end,
      delete_note = function(filename)
        -- Return false for non-existent files
        if filename == "nonexistent.md" or filename == "" then
          return false
        end
        return true
      end,
    }

    package.loaded["file_storage"] = file_storage

    note_manager = require("note_manager")
    note_manager.set_notes_dir(test_notes_dir)
  end)

  before_each(function()
    -- Reset module cache to reload file_storage mock
    package.loaded["file_storage"] = nil
    package.loaded["file_storage"] = file_storage
    note_manager = require("note_manager")
    note_manager.set_notes_dir(test_notes_dir)
  end)

  teardown(function()
    package.loaded["note_manager"] = nil
    package.loaded["file_storage"] = nil
  end)

  describe("create_note", function()
    it("should create a note with current timestamp", function()
      local content = "# Test Note\n\nThis is a test."
      local note = note_manager.create_note(content)

      assert.is.truthy(note)
      assert.is.truthy(note.filename)
      assert.is_truthy(note.content)
      assert.is.truthy(note.created_at)
      assert.is.equals(content, note.content)
    end)

    it("should create a note with custom timestamp", function()
      local content = "# Custom Timestamp Note"
      local timestamp = os.time({
        year = 2026,
        month = 1,
        day = 14,
        hour = 16,
        min = 56,
        sec = 0
      })

      local note = note_manager.create_note(content, timestamp)

      assert.is.truthy(note)
      assert.is.truthy(note.filename)
      assert.is.equals("2026-01-14-16-56-00.md", note.filename)
    end)

    it("should reject empty content", function()
      local note = note_manager.create_note("")
      assert.is_nil(note)
    end)

    it("should reject nil content", function()
      local note = note_manager.create_note(nil)
      assert.is_nil(note)
    end)

    it("should reject whitespace-only content", function()
      local note = note_manager.create_note("   \n\t  \n  ")
      assert.is_nil(note)
    end)

    it("should store note metadata", function()
      local content = "# Metadata Test"
      local note = note_manager.create_note(content)

      assert.is.truthy(note.created_at)
      assert.is.number(note.created_at)
      assert.is.truthy(note.updated_at)
      assert.is.number(note.updated_at)
    end)
  end)

  describe("update_note", function()
    it("should update existing note", function()
      local filename = "2026-01-14-16-56-00.md"
      local new_content = "# Updated\n\nNew content here."

      local result = note_manager.update_note(filename, new_content)

      assert.is.truthy(result)
    end)

    it("should reject empty content", function()
      local filename = "2026-01-14-16-56-00.md"
      local result = note_manager.update_note(filename, "")
      assert.is_falsy(result)
    end)

    it("should reject invalid filename", function()
      local result = note_manager.update_note("", "content")
      assert.is_falsy(result)
    end)

    it("should reject nil filename", function()
      local result = note_manager.update_note(nil, "content")
      assert.is_falsy(result)
    end)
  end)

  describe("delete_note", function()
    it("should delete existing note", function()
      local filename = "2026-01-14-16-56-00.md"
      local result = note_manager.delete_note(filename)
      assert.is.truthy(result)
    end)

    it("should return false for non-existent note", function()
      local result = note_manager.delete_note("nonexistent.md")
      assert.is_falsy(result)
    end)

    it("should reject invalid filename", function()
      local result = note_manager.delete_note("")
      assert.is_falsy(result)
    end)
  end)

  describe("get_all_notes", function()
    it("should return array of note objects", function()
      local notes = note_manager.get_all_notes()

      assert.is_truthy(type(notes) == "table")
      assert.is_truthy(#notes >= 2)
    end)

    it("should include note metadata", function()
      local notes = note_manager.get_all_notes()

      for _, note in ipairs(notes) do
        assert.is.truthy(note.filename)
        assert.is.truthy(note.content)
        assert.is.truthy(note.created_at)
      end
    end)

    it("should return empty array when no notes exist", function()
      -- Mock empty list
      local original_list = file_storage.list_notes
      file_storage.list_notes = function() return {} end

      local notes = note_manager.get_all_notes()
      assert.is.same({}, notes)

      -- Restore
      file_storage.list_notes = original_list
    end)
  end)

  describe("get_note", function()
    it("should return single note by filename", function()
      local filename = "2026-01-14-16-56-00.md"
      local note = note_manager.get_note(filename)

      assert.is_truthy(note)
      assert.is.equals(filename, note.filename)
      assert.is.truthy(note.content)
    end)

    it("should return nil for non-existent note", function()
      local note = note_manager.get_note("nonexistent.md")
      assert.is_nil(note)
    end)

    it("should return nil for invalid filename", function()
      local note = note_manager.get_note("")
      assert.is_nil(note)
    end)
  end)

  describe("validate_content", function()
    it("should accept valid content", function()
      local valid = note_manager.validate_content("# Valid note content")
      assert.is_truthy(valid)
    end)

    it("should reject empty strings", function()
      local valid = note_manager.validate_content("")
      assert.is_falsy(valid)
    end)

    it("should reject nil", function()
      local valid = note_manager.validate_content(nil)
      assert.is_falsy(valid)
    end)

    it("should reject whitespace-only content", function()
      local valid = note_manager.validate_content("   \n\t  ")
      assert.is_falsy(valid)
    end)

    it("should accept content with special characters", function()
      local valid = note_manager.validate_content("# Note with **bold** and `code`")
      assert.is_truthy(valid)
    end)

    it("should accept multi-line content", function()
      local valid = note_manager.validate_content("# Title\n\nParagraph\n\n- List item")
      assert.is_truthy(valid)
    end)
  end)

  describe("notes directory management", function()
    it("should set notes directory path", function()
      local new_dir = "/tmp/custom-notes"
      local result = note_manager.set_notes_dir(new_dir)
      assert.is_truthy(result)
    end)

    it("should get notes directory path", function()
      local dir = note_manager.get_notes_dir()
      assert.is_truthy(type(dir) == "string")
    end)
  end)
end)
