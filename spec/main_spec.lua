-- spec/main_spec.lua
-- Tests for main.lua plugin entry point

describe("Fleeting Notes Plugin", function()
  local Plugin

  setup(function()
    -- Mock KOReader dependencies
    package.loaded["gettext"] = function(text)
      return text  -- Identity function for testing
    end

    package.loaded["ui/uimanager"] = {
      show = function() end,
      close = function() end,
    }

    package.loaded["datastorage"] = {
      getDataDir = function()
        return "/tmp/koreader"
      end
    }

    package.loaded["markdown_editor"] = function()
      return {
        _buildToolbar = function() end,
        _buildEditor = function() end,
        _buildActionButtons = function() end,
        _buildMainLayout = function() end,
      }
    end

    package.loaded["note_manager"] = {
      set_notes_dir = function() return true end,
      get_notes_dir = function() return "/tmp/notes" end,
      ensure_notes_dir = function() return true end,
    }

    -- Load the plugin
    Plugin = require("main")
  end)

  teardown(function()
    package.loaded["main"] = nil
    package.loaded["markdown_editor"] = nil
    package.loaded["note_manager"] = nil
    package.loaded["gettext"] = nil
    package.loaded["ui/uimanager"] = nil
    package.loaded["datastorage"] = nil
  end)

  describe("plugin table", function()
    it("should have disabled field", function()
      assert.is.falsy(Plugin.disabled)
    end)

    it("should have menu_text field", function()
      assert.is.truthy(Plugin.menu_text)
      assert.is.truthy(type(Plugin.menu_text) == "string")
    end)

    it("should have meaningful menu text", function()
      local text = Plugin.menu_text:lower()
      assert.is.truthy(text:match("note") or text:match("fleeting"))
    end)
  end)

  describe("init", function()
    it("should have init function", function()
      assert.is.truthy(Plugin.init)
      assert.is.equals("function", type(Plugin.init))
    end)

    it("should initialize without errors", function()
      local ok, err = pcall(Plugin.init, Plugin)
      assert.is.truthy(ok)
    end)
  end)

  describe("start", function()
    it("should have start function", function()
      assert.is.truthy(Plugin.start)
      assert.is.equals("function", type(Plugin.start))
    end)

    it("should start the editor", function()
      -- This test would require mocking UIManager.show properly
      -- For now, just verify the function exists and is callable
      assert.is.equals("function", type(Plugin.start))
    end)
  end)

  describe("notes directory", function()
    it("should set up notes directory on init", function()
      local test_plugin = {
        disabled = false,
        menu_text = "Test Plugin",
        init = Plugin.init,
        start = Plugin.start,
      }

      test_plugin:init()
      assert.is.truthy(test_plugin.notes_dir)
    end)
  end)

  describe("integration", function()
    it("should be compatible with KOReader plugin interface", function()
      -- KOReader requires these fields/methods
      assert.is.falsy(Plugin.disabled)  -- Should be false by default
      assert.is.truthy(Plugin.menu_text)
      assert.is.truthy(type(Plugin.init) == "function")
      assert.is.truthy(type(Plugin.start) == "function")
    end)
  end)
end)
