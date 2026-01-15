-- spec/koreader_modules_spec.lua
-- Tests to verify KOReader module paths are correct
-- These tests prevent regressions where incorrect module paths break the plugin

describe("KOReader module imports", function()
  -- Track which modules fail to load
  local failed_modules = {}
  local loaded_modules = {}

  setup(function()
    -- Mock KOReader dependencies that aren't available in test environment
    -- This allows us to test if the module PATHS are correct, even if we can't
    -- fully instantiate the widgets

    package.loaded["gettext"] = function(text) return text end

    -- Mock Device and Screen
    local Device = {
      hasColorScreen = function() return false end,
      screen = {
        getWidth = function() return 600 end,
        getHeight = function() return 800 end,
        getSize = function() return {w = 600, h = 800} end,
      }
    }
    package.loaded["device"] = Device
    _G.Device = Device

    local Screen = {
      getWidth = function() return 600 end,
      getHeight = function() return 800 end,
      getSize = function() return {w = 600, h = 800} end,
    }
    package.loaded["ui/screen"] = Screen
    _G.Screen = Screen

    -- Mock Blitbuffer
    local Blitbuffer = {
      colorW = function() return {} end,
      ColorRGB = function(r, g, b)
        return {r = r, g = g, b = b, type = "color"}
      end,
      COLOR_WHITE = 0xFFFFFF,
      COLOR_BLACK = 0x000000,
      COLOR_LIGHT_GRAY = 0xC0C0C0,
      COLOR_DARK_GRAY = 0x404040,
    }
    package.loaded["ffi/blitbuffer"] = Blitbuffer
    _G.Blitbuffer = Blitbuffer

    -- Mock Font module
    package.loaded["ui/font"] = {
      getFace = function(name, size)
        return {name = name, size = size}
      end
    }

    -- Mock Geometry module
    package.loaded["ui/geometry"] = {
      new = function(cls, tbl)
        local obj = tbl or {}
        setmetatable(obj, {__index = cls})
        return obj
      end
    }

    -- Base Widget mock
    local Widget = {
      new = function(cls, args)
        local obj = {}
        local current = cls
        while current do
          for k, v in pairs(current) do
            if type(v) ~= "function" and obj[k] == nil then
              obj[k] = v
            end
          end
          local mt = getmetatable(current)
          current = mt and mt.__index
        end
        if args then
          for k, v in pairs(args) do
            obj[k] = v
          end
        end
        setmetatable(obj, {__index = cls})
        if obj.init then
          obj:init()
        end
        return obj
      end,
      extend = function(cls, methods)
        local new_cls = methods or {}
        new_cls.__index = new_cls
        setmetatable(new_cls, {__index = cls})
        return new_cls
      end
    }
    package.loaded["ui/widget/widget"] = Widget

    -- Mock container widgets
    package.loaded["ui/widget/container/inputcontainer"] = Widget:extend{
      key_events = {},
    }

    package.loaded["ui/widget/container/centercontainer"] = Widget:extend()

    package.loaded["ui/widget/container/framecontainer"] = Widget:extend()

    package.loaded["ui/widget/container/widgetcontainer"] = Widget:extend()

    -- Mock UI widgets
    local function createWidgetMock()
      local WidgetClass = Widget:extend()
      WidgetClass.getSize = function(self) return {w = self.width or 100, h = self.height or 40} end
      WidgetClass.paintTo = function(self, ...) end
      WidgetClass.setupDOM = function(self, ...) end
      WidgetClass.getOffset = function(self) return {x = 0, y = 0} end
      return WidgetClass
    end

    local TextBoxWidget = createWidgetMock()
    TextBoxWidget.getText = function(self) return self.text or "" end
    TextBoxWidget.setText = function(self, text) self.text = text end
    package.loaded["ui/widget/textboxwidget"] = TextBoxWidget

    local InputText = createWidgetMock()
    InputText.getText = function(self) return self.text or "" end
    InputText.setText = function(self, text) self.text = text end
    package.loaded["ui/widget/inputtext"] = InputText

    package.loaded["ui/widget/button"] = createWidgetMock()
    package.loaded["ui/widget/horizontalgroup"] = createWidgetMock()
    package.loaded["ui/widget/verticalgroup"] = createWidgetMock()
    package.loaded["ui/widget/horizontalspan"] = createWidgetMock()
    package.loaded["ui/widget/verticalspan"] = createWidgetMock()

    package.loaded["ui/widget/infomessage"] = createWidgetMock()
    package.loaded["ui/widget/confirmbox"] = createWidgetMock()

    -- Mock UIManager
    package.loaded["ui/uimanager"] = {
      show = function() end,
      close = function() end,
      nextTick = function(cb) cb() end,
      setDirty = function() end,
      scheduleIn = function() return {} end,  -- Mock for auto-dismiss
      unschedule = function() end,  -- Mock for auto-dismiss
    }

    -- Mock other dependencies
    package.loaded["luasettings"] = {
      open = function(path)
        return {
          readSetting = function(self, key, default) return default end,
          saveSetting = function(self, key, value) end,
          flush = function(self) end,
        }
      end
    }

    package.loaded["markdown_formatter"] = {
      wrap_bold = function(t) return "**" .. t .. "**" end,
      wrap_italic = function(t) return "*" .. t .. "*" end,
      wrap_code = function(t) return "`" .. t .. "`" end,
      insert_heading = function(l) return string.rep("#", l) .. " " end,
      insert_list = function(o) return o and "1. " or "- " end,
      insert_link = function(t, u) return "[" .. t .. "](" .. u .. ")" end,
      apply_formatting = function(text, format_type, start_pos, end_pos, ...)
        if format_type == "bold" then return "**" .. text .. "**" end
        if format_type == "italic" then return "*" .. text .. "*" end
        if format_type == "code" then return "`" .. text .. "`" end
        if format_type == "heading" then
          local level = select(1, ...) or 1
          return string.rep("#", level) .. " " .. text
        end
        if format_type == "list" then
          local numbered = select(1, ...)
          return numbered and "1. " or "- " .. text
        end
        return text
      end,
    }

    package.loaded["note_manager"] = {
      create_note = function(content)
        return {filename = "test.md", content = content, created_at = os.time()}
      end,
      validate_content = function(content)
        return content and content ~= "" and content:match("%S")
      end,
    }

    package.loaded["file_storage"] = {
      set_notes_dir = function() return true end,
      get_notes_dir = function() return "/tmp/notes" end,
      ensure_notes_dir = function() return true end,
      save_note = function() return true end,
      delete_note = function() return true end,
    }

    package.loaded["settings"] = {
      init = function() end,
      should_use_color = function() return false end,
      get_use_color_ui = function() return nil end,
      set_use_color_ui = function(value) end,
    }

    package.loaded["datastorage"] = {
      getDataDir = function() return "/tmp/koreader" end
    }
  end)

  teardown(function()
    -- Clean up loaded modules
    for name, _ in pairs(package.loaded) do
      if name:match("ui/widget") or name:match("ui/geometry") or
         name:match("ffi/blitbuffer") or name:match("device") or
         name:match("markdown_") or name:match("note_manager") or
         name:match("file_storage") or name:match("settings") then
        package.loaded[name] = nil
      end
    end
  end)

  describe("markdown_editor.lua imports", function()
    -- These are the critical KOReader modules that markdown_editor.lua requires
    local required_modules = {
      "ui/widget/widget",
      "ui/widget/container/inputcontainer",
      "ui/widget/textboxwidget",
      "ui/widget/inputtext",
      "ui/widget/button",
      "ui/widget/horizontalgroup",
      "ui/widget/horizontalspan",
      "ui/widget/verticalgroup",
      "ui/widget/verticalspan",
      "ui/widget/container/centercontainer",
      "ui/widget/container/framecontainer",
      "ui/geometry",
      "ui/font",
      "ui/widget/infomessage",
      "ui/widget/confirmbox",
      "ffi/blitbuffer",
      "device",
      "ui/uimanager",
      "gettext",
    }

    it("should be able to load all required KOReader modules", function()
      for _, module_path in ipairs(required_modules) do
        local ok, err = pcall(require, module_path)
        if not ok then
          table.insert(failed_modules, module_path .. ": " .. tostring(err))
        else
          table.insert(loaded_modules, module_path)
        end
      end

      -- If any modules failed to load, fail the test with a helpful message
      if #failed_modules > 0 then
        error("Failed to load KOReader modules:\n  " .. table.concat(failed_modules, "\n  "))
      end
    end)

    it("should successfully load markdown_editor module", function()
      local ok, err = pcall(require, "markdown_editor")
      assert.is_truthy(ok, "markdown_editor module failed to load: " .. tostring(err))
    end)

    it("should create a markdown_editor instance without errors", function()
      local markdown_editor = require("markdown_editor")
      local ok, err = pcall(function()
        return markdown_editor:new{}
      end)

      assert.is_truthy(ok, "Failed to create markdown_editor instance: " .. tostring(err))
    end)
  end)

  describe("main.lua imports", function()
    it("should successfully load main module", function()
      local ok, err = pcall(require, "main")
      assert.is_truthy(ok, "main module failed to load: " .. tostring(err))
    end)

    it("should have required plugin interface methods", function()
      local Plugin = require("main")
      assert.is.truthy(type(Plugin.init) == "function")
      assert.is.truthy(type(Plugin.start) == "function")
      assert.is.truthy(type(Plugin.addToMainMenu) == "function")
    end)
  end)

  describe("regression tests for common module path errors", function()
    it("should use correct path for InputContainer", function()
      -- Common error: using ui/widget/inputcontainer instead of ui/widget/container/inputcontainer
      local markdown_editor = require("markdown_editor")
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)  -- If this fails, it's likely due to wrong InputContainer path
    end)

    it("should use correct path for CenterContainer", function()
      -- Common error: using ui/widget/centercontainer instead of ui/widget/container/centercontainer
      local markdown_editor = require("markdown_editor")
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)  -- If this fails, it's likely due to wrong CenterContainer path
    end)

    it("should use correct path for FrameContainer", function()
      -- Common error: using ui/widget/framecontainer instead of ui/widget/container/framecontainer
      local markdown_editor = require("markdown_editor")
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)  -- If this fails, it's likely due to wrong FrameContainer path
    end)

    it("should use correct path for Geometry", function()
      -- Common error: using ui/geom instead of ui/geometry
      local markdown_editor = require("markdown_editor")
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)  -- If this fails, it's likely due to wrong Geometry path
    end)

    it("should properly import Screen from device", function()
      -- Common error: not importing Screen correctly from device module
      local markdown_editor = require("markdown_editor")
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)  -- If this fails, it's likely due to Screen import issue
    end)
  end)
end)
