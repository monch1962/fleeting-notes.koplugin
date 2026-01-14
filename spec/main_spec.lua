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

    -- Mock WidgetContainer
    local WidgetContainer = {}
    function WidgetContainer:extend(props)
      local new_class = props or {}
      new_class.__index = new_class
      setmetatable(new_class, {
        __index = function(t, k)
          -- Don't return functions for undefined fields
          return nil
        end
      })
      return new_class
    end
    package.loaded["ui/widget/container/widgetcontainer"] = WidgetContainer

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

    package.loaded["file_storage"] = {
      set_notes_dir = function() return true end,
      ensure_notes_dir = function() return true end,
    }

    package.loaded["luasettings"] = {
      open = function(path)
        return {
          readSetting = function(self, key, default) return default end,
          saveSetting = function(self, key, value) end,
          flush = function(self) end,
        }
      end
    }

    package.loaded["settings"] = {
      should_use_color = function() return false end,
      get_use_color_ui = function() return nil end,
      set_use_color_ui = function(value) end,
    }

    -- Load the plugin
    Plugin = require("main")
  end)

  teardown(function()
    package.loaded["main"] = nil
    package.loaded["markdown_editor"] = nil
    package.loaded["note_manager"] = nil
    package.loaded["file_storage"] = nil
    package.loaded["settings"] = nil
    package.loaded["luasettings"] = nil
    package.loaded["gettext"] = nil
    package.loaded["ui/uimanager"] = nil
    package.loaded["datastorage"] = nil
    package.loaded["ui/widget/container/widgetcontainer"] = nil
  end)

  describe("plugin table", function()
    it("should have disabled field", function()
      assert.is.falsy(Plugin.disabled)
    end)

    it("should have name field", function()
      assert.is.truthy(Plugin.name)
      assert.is.truthy(type(Plugin.name) == "string")
    end)

    it("should have meaningful name", function()
      local name = Plugin.name:lower()
      assert.is.truthy(name:match("note") or name:match("fleeting"))
    end)
  end)

  describe("init", function()
    it("should have init function", function()
      assert.is.truthy(Plugin.init)
      assert.is.equals("function", type(Plugin.init))
    end)

    it("should initialize without errors", function()
      -- Create a plugin instance with required ui field (like KOReader does)
      local test_plugin = {
        name = "fleeting_notes",
        is_doc_only = false,
        disabled = false,
        ui = {
          menu = {
            registerToMainMenu = function() end
          }
        },
        init = Plugin.init,
      }
      setmetatable(test_plugin, {__index = Plugin})

      local ok, err = pcall(test_plugin.init, test_plugin)
      assert.is_truthy(ok)
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
        name = "fleeting_notes",
        is_doc_only = false,
        disabled = false,
        ui = {
          menu = {
            registerToMainMenu = function() end
          }
        },
        init = Plugin.init,
      }
      setmetatable(test_plugin, {__index = Plugin})

      test_plugin:init()
      assert.is.truthy(test_plugin.notes_dir)
    end)
  end)

  describe("integration", function()
    it("should be compatible with KOReader plugin interface", function()
      -- KOReader requires these fields/methods
      assert.is.falsy(Plugin.disabled)  -- Should be false by default
      assert.is.truthy(Plugin.name)
      assert.is.truthy(type(Plugin.init) == "function")
      assert.is.truthy(type(Plugin.start) == "function")
      assert.is.truthy(type(Plugin.addToMainMenu) == "function")
    end)
  end)
end)
