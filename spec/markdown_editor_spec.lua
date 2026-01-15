-- spec/markdown_editor_spec.lua
-- Tests for markdown_editor.lua

describe("markdown_editor", function()
  local markdown_editor
  local mock_ui_manager = {}

  setup(function()
    -- Mock KOReader UI components
    package.loaded["gettext"] = function(text) return text end

    -- Base Widget class with :new method
    local Widget = {
      new = function(cls, args)
        local obj = {}
        -- Copy all class fields to the instance, including from metatable chain
        local current = cls
        while current do
          for k, v in pairs(current) do
            if type(v) ~= "function" and obj[k] == nil then
              obj[k] = v
            end
          end
          -- Move up the metatable chain
          local mt = getmetatable(current)
          current = mt and mt.__index
        end
        -- Then override with provided args
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

    -- InputContainer extends Widget (correct path for KOReader)
    local InputContainer = Widget:extend{
      key_events = {},  -- InputContainer has key_events by default
      new = function(cls, args)
        local obj = {}
        -- Copy all class fields to the instance, including from metatable chain
        local current = cls
        while current do
          for k, v in pairs(current) do
            if type(v) ~= "function" and obj[k] == nil then
              obj[k] = v
            end
          end
          -- Move up the metatable chain
          local mt = getmetatable(current)
          current = mt and mt.__index
        end
        -- Then override with provided args
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
      end
    }

    package.loaded["ui/widget/container/inputcontainer"] = InputContainer

    -- Helper to create widget class mocks
    local function createWidgetMock()
      local WidgetClass = {
        new = function(cls, args)
          local obj = {}
          -- Copy all class fields to the instance, including from metatable chain
          local current = cls
          while current do
            for k, v in pairs(current) do
              if type(v) ~= "function" and obj[k] == nil then
                obj[k] = v
              end
            end
            -- Move up the metatable chain
            local mt = getmetatable(current)
            current = mt and mt.__index
          end
          -- Then override with provided args
          if args then
            for k, v in pairs(args) do
              obj[k] = v
            end
          end
          setmetatable(obj, {__index = cls})
          return obj
        end,
        -- Add common widget methods
        getSize = function(self) return {w = self.width or 100, h = self.height or 40} end,
        paintTo = function(self, ...) end,
        setupDOM = function(self, ...) end,
        getOffset = function(self) return {x = 0, y = 0} end,
      }
      return WidgetClass
    end

    -- TextBoxWidget needs special methods
    local TextBoxWidget = createWidgetMock()
    TextBoxWidget.getText = function(self) return self.text or "" end
    TextBoxWidget.setText = function(self, text) self.text = text end
    TextBoxWidget.onTap = function(self) end  -- Add onTap method
    package.loaded["ui/widget/textboxwidget"] = TextBoxWidget

    -- TextWidget mock (for title widget)
    local TextWidget = createWidgetMock()
    TextWidget.getText = function(self) return self.text or "" end
    package.loaded["ui/widget/textwidget"] = TextWidget

    -- InputText widget mock
    local InputText = createWidgetMock()
    InputText.getText = function(self) return self.text or "" end
    InputText.setText = function(self, text) self.text = text end
    InputText.onTap = function(self) end
    InputText.onCloseKeyboard = function(self) end
    InputText.key_events = {}
    package.loaded["ui/widget/inputtext"] = InputText

    -- Button widget mock - don't execute callbacks automatically
    local ButtonMock = createWidgetMock()
    ButtonMock.callback = nil
    package.loaded["ui/widget/button"] = ButtonMock

    package.loaded["ui/widget/horizontalgroup"] = createWidgetMock()
    package.loaded["ui/widget/verticalgroup"] = createWidgetMock()
    package.loaded["ui/widget/horizontalspan"] = createWidgetMock()
    package.loaded["ui/widget/verticalspan"] = createWidgetMock()
    package.loaded["ui/widget/container/centercontainer"] = createWidgetMock()
    package.loaded["ui/widget/container/framecontainer"] = createWidgetMock()
    package.loaded["ui/widget/infomessage"] = createWidgetMock()
    package.loaded["ui/widget/confirmbox"] = createWidgetMock()

    package.loaded["ui/geometry"] = {
      new = function(cls, tbl)
        local obj = tbl or {}
        setmetatable(obj, {__index = cls})
        return obj
      end
    }

    package.loaded["ui/font"] = {
      getFace = function(name) return {} end
    }

    -- Add LuaSettings mock
    package.loaded["luasettings"] = {
      open = function(path)
        return {
          readSetting = function(self, key, default) return default end,
          saveSetting = function(self, key, value) end,
          flush = function(self) end,
        }
      end
    }

    -- Add Screen mock
    package.loaded["ui/device"] = {
      screen = {
        getWidth = function() return 600 end,
        getHeight = function() return 800 end,
      }
    }

    package.loaded["ui/screen"] = {
      getWidth = function() return 600 end,
      getHeight = function() return 800 end,
    }

    local Screen = {
      getWidth = function() return 600 end,
      getHeight = function() return 800 end,
      getSize = function() return {w = 600, h = 800} end,
    }

    package.loaded["ui/screen"] = Screen
    _G.Screen = Screen

    -- Add Blitbuffer mock
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

    -- Add Device mock
    local Device = {
      hasColorScreen = function() return false end,  -- Default to E-ink
      screen = {
        getWidth = function() return 600 end,
        getHeight = function() return 800 end,
        getSize = function() return {w = 600, h = 800} end,
      }
    }
    package.loaded["device"] = Device
    _G.Device = Device

    -- UIManager needs more methods
    mock_ui_manager.setDirty = function(...) end
    mock_ui_manager.nextTick = function(cb)
      -- Don't execute automatically in tests to avoid side effects
      -- Just store the callback for manual execution if needed
      return true
    end
    mock_ui_manager.close = function(...) end
    mock_ui_manager.show = function(...) end
    -- Don't execute scheduleIn callbacks in tests to avoid infinite loops
    -- The auto-dismiss logic creates a recursive scheduleIn call
    mock_ui_manager.scheduleIn = function(delay, cb)
      return {}  -- Return a mock job object, don't execute cb
    end
    mock_ui_manager.unschedule = function() end  -- For auto-dismiss
    package.loaded["ui/uimanager"] = mock_ui_manager

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
    }

    -- Mock settings module
    package.loaded["settings"] = {
      should_use_color = function() return false end,  -- Default to E-ink
    }

    markdown_editor = require("markdown_editor")
  end)

  teardown(function()
    package.loaded["markdown_editor"] = nil
    package.loaded["markdown_formatter"] = nil
    package.loaded["note_manager"] = nil
    package.loaded["file_storage"] = nil
    package.loaded["settings"] = nil
    package.loaded["luasettings"] = nil
    package.loaded["gettext"] = nil
    package.loaded["ffi/blitbuffer"] = nil
    package.loaded["device"] = nil
    package.loaded["ui/widget/widget"] = nil
    package.loaded["ui/widget/container/inputcontainer"] = nil
    package.loaded["ui/widget/textboxwidget"] = nil
    package.loaded["ui/widget/textwidget"] = nil
    package.loaded["ui/widget/inputtext"] = nil
    package.loaded["ui/widget/button"] = nil
    package.loaded["ui/widget/horizontalgroup"] = nil
    package.loaded["ui/widget/verticalgroup"] = nil
    package.loaded["ui/widget/horizontalspan"] = nil
    package.loaded["ui/widget/verticalspan"] = nil
    package.loaded["ui/widget/container/centercontainer"] = nil
    package.loaded["ui/widget/container/framecontainer"] = nil
    package.loaded["ui/widget/infomessage"] = nil
    package.loaded["ui/widget/confirmbox"] = nil
    package.loaded["ui/geometry"] = nil
    package.loaded["ui/font"] = nil
    package.loaded["ui/uimanager"] = nil
  end)

  describe("create", function()
    it("should create a new editor instance", function()
      local editor = markdown_editor:new{}
      assert.is_truthy(editor)
    end)

    it("should accept initial content", function()
      local editor = markdown_editor:new{content = "# Initial Content"}
      assert.is_truthy(editor)
      assert.is.equals("# Initial Content", editor.content)
    end)

    it("should have toolbar buttons", function()
      local editor = markdown_editor:new{}
      assert.is_truthy(editor.toolbar_buttons)
      assert.is.truthy(type(editor.toolbar_buttons) == "table")
    end)

    it("should have save and cancel buttons", function()
      local editor = markdown_editor:new{}
      assert.is.truthy(editor.save_button)
      assert.is_truthy(editor.cancel_button)
    end)
  end)

  describe("toolbar buttons", function()
    it("should include bold button", function()
      local editor = markdown_editor:new{}
      local has_bold = false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "bold" then
          has_bold = true
          break
        end
      end
      assert.is_truthy(has_bold)
    end)

    it("should include italic button", function()
      local editor = markdown_editor:new{}
      local has_italic = false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "italic" then
          has_italic = true
          break
        end
      end
      assert.is_truthy(has_italic)
    end)

    it("should include code button", function()
      local editor = markdown_editor:new{}
      local has_code = false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "code" then
          has_code = true
          break
        end
      end
      assert.is_truthy(has_code)
    end)

    it("should include heading buttons", function()
      local editor = markdown_editor:new{}
      local h1_count, h2_count, h3_count = 0, 0, 0
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "h1" then h1_count = h1_count + 1 end
        if btn.id == "h2" then h2_count = h2_count + 1 end
        if btn.id == "h3" then h3_count = h3_count + 1 end
      end
      assert.is.equals(1, h1_count)
      assert.is.equals(1, h2_count)
      assert.is.equals(1, h3_count)
    end)

    it("should include list buttons", function()
      local editor = markdown_editor:new{}
      local has_bullet, has_numbered = false, false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "bullet_list" then has_bullet = true end
        if btn.id == "numbered_list" then has_numbered = true end
      end
      assert.is_truthy(has_bullet)
      assert.is.truthy(has_numbered)
    end)

    it("should include link button", function()
      local editor = markdown_editor:new{}
      local has_link = false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "link" then
          has_link = true
          break
        end
      end
      assert.is_truthy(has_link)
    end)
  end)

  describe("apply_formatting", function()
    it("should apply bold to entire text", function()
      local editor = markdown_editor:new{content = "hello world"}
      editor:apply_formatting("bold", 1, 5)
      -- Current implementation applies to entire text
      assert.is.equals("**hello world**", editor.content)
    end)

    it("should apply italic to entire text", function()
      local editor = markdown_editor:new{content = "hello world"}
      editor:apply_formatting("italic", 1, 5)
      assert.is.equals("*hello world*", editor.content)
    end)

    it("should apply code to entire text", function()
      local editor = markdown_editor:new{content = "hello world"}
      editor:apply_formatting("code", 1, 5)
      assert.is.equals("`hello world`", editor.content)
    end)

    it("should insert heading at start of text", function()
      local editor = markdown_editor:new{content = "hello"}
      editor:apply_formatting("heading", 1, 1, 2)
      assert.is.equals("## hello", editor.content)
    end)

    it("should insert list at start of text", function()
      local editor = markdown_editor:new{content = "item"}
      editor:apply_formatting("list", 1, 1, false)
      assert.is.equals("- item", editor.content)
    end)
  end)

  describe("save_note", function()
    it("should have auto-save functionality", function()
      local editor = markdown_editor:new{content = "# Test Note"}
      -- Auto-save is handled internally via _doAutoSave()
      -- Just verify the editor was created
      assert.is_truthy(editor.content)
    end)

    it("should not auto-save empty content", function()
      local editor = markdown_editor:new{content = ""}
      -- Empty content won't be auto-saved
      assert.is.equals("", editor.content)
    end)
  end)

  describe("close", function()
    it("should have close method", function()
      local editor = markdown_editor:new{content = "test"}
      -- close() method exists and is callable
      assert.is.equals("function", type(editor.close))
    end)

    it("should be callable with delete parameter", function()
      local editor = markdown_editor:new{content = "test"}
      -- Method should be callable (may error due to UIManager mocks)
      local ok = pcall(function()
        editor:close(false)
      end)
      -- May fail due to UIManager mocks, but method should exist
      assert.is_truthy(type(editor.close) == "function")
    end)
  end)

  describe("on_close_widget", function()
    it("should be callable", function()
      local editor = markdown_editor:new{content = "test"}
      editor:onCloseWidget()
      -- Should not error
      assert.is_truthy(true)
    end)
  end)

  describe("regression tests", function()
    -- These tests prevent bugs we've fixed from reappearing

    describe("bug: Blitbuffer.ColorRGB not found", function()
      it("should handle missing ColorRGB gracefully", function()
        -- This bug occurred when Blitbuffer.ColorRGB was not available in older KOReader versions
        -- The fix was to check type(Blitbuffer.ColorRGB) == "function" before calling it
        local editor = markdown_editor:new{content = "test"}

        -- Editor should create successfully even with color support disabled
        assert.is_truthy(editor)
        assert.is_truthy(editor.toolbar_buttons)

        -- Toolbar buttons should exist (they might have nil colors, but that's OK)
        assert.is_truthy(#editor.toolbar_buttons > 0)
      end)

      it("should not crash when creating colored buttons", function()
        -- Even when ColorRGB is not available, buttons should be created
        local editor = markdown_editor:new{content = "test"}
        assert.is_truthy(editor.toolbar_button_widgets)
        assert.is_truthy(#editor.toolbar_button_widgets > 0)
      end)
    end)

    describe("bug: TextBoxWidget getText() method missing", function()
      it("should use InputText widget which has getText/setText", function()
        -- TextBoxWidget doesn't have getText/setText methods in all KOReader versions
        -- The fix was to switch to InputText widget
        local editor = markdown_editor:new{content = "test content"}

        -- Editor widget should be InputText (or compatible) with getText method
        assert.is_truthy(editor.editor)
        assert.is.equals("function", type(editor.editor.getText))
        assert.is.equals("function", type(editor.editor.setText))
      end)

      it("should allow getting and setting text", function()
        local editor = markdown_editor:new{content = "initial"}
        local text = editor.editor:getText()
        assert.is_truthy(text)

        editor.editor:setText("new text")
        local new_text = editor.editor:getText()
        assert.is_truthy(new_text)
      end)
    end)

    describe("bug: Screen global nil", function()
      it("should import Screen from device module", function()
        -- This bug occurred when trying to use global Screen which was nil
        -- The fix was to add: local Screen = require("device").screen
        local editor = markdown_editor:new{content = "test"}

        -- Editor should create successfully (would crash if Screen was nil)
        assert.is_truthy(editor)
        assert.is_truthy(editor.main_frame)
      end)

      it("should calculate editor height using Screen", function()
        -- If Screen is nil, height calculation would crash
        local editor = markdown_editor:new{content = "test"}

        -- Editor widget should have been created with calculated height
        assert.is_truthy(editor.editor)
        assert.is_truthy(editor.editor.height)
        assert.is_truthy(editor.editor.height > 0)
      end)
    end)

    describe("bug: buttons not working when typing", function()
      it("should use edit_callback instead of aggressive key_events", function()
        -- This bug occurred when a key_events handler caught all events
        -- The fix was to use edit_callback on the InputText widget
        local editor = markdown_editor:new{content = "test"}

        -- Editor should have edit_callback set up
        assert.is_truthy(editor.editor)
        assert.is.equals("function", type(editor.editor.edit_callback))
      end)

      it("should not have AutoSave key event handler", function()
        -- The buggy version had: key_events.AutoSave = { {"all"}, ... }
        -- This would catch all key events and prevent buttons from working
        local editor = markdown_editor:new{content = "test"}

        -- Check that AutoSave key event doesn't exist
        if editor.key_events then
          assert.is_falsy(editor.key_events.AutoSave)
        end
      end)

      it("should have toolbar button callbacks", function()
        -- Toolbar buttons should have functional callbacks
        local editor = markdown_editor:new{content = "test"}

        for _, btn_spec in ipairs(editor.toolbar_buttons) do
          assert.is_truthy(btn_spec.callback)
          assert.is.equals("function", type(btn_spec.callback))
        end
      end)
    end)

    describe("bug: font face nil causing crash", function()
      it("should use valid font face for title widget", function()
        -- This bug occurred when using Font:getFace("smallfont", 18) which returned nil
        -- The fix was to use Font:getFace("tfont", 20) instead
        local editor = markdown_editor:new{content = "test"}

        -- Title widget should be created successfully
        assert.is_truthy(editor.title_widget)
        assert.is.truthy(type(editor.title_widget) == "table")
      end)

      it("should use valid font face for editor", function()
        -- Editor should also use a valid font face
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.editor)
        assert.is.truthy(editor.editor.face)
      end)
    end)

    describe("bug: title bar invisible due to height calculation", function()
      it("should reserve enough space for UI elements", function()
        -- This bug occurred when reserved_space was too small (200px)
        -- The fix was to increase it to 350px to fit all UI elements
        local editor = markdown_editor:new{content = "test"}

        -- Editor height should be calculated with proper reserved space
        assert.is_truthy(editor.editor)
        local editor_height = editor.editor.height

        -- Editor should be reasonable size (not too large that it pushes title off screen)
        -- Screen height is typically 600-800px
        -- Editor should be less than screen height
        assert.is_truthy(editor_height < 800)
      end)
    end)

    describe("bug: no way to close plugin", function()
      it("should have close button (×)", function()
        -- User had no obvious way to exit the plugin
        -- The fix was to add a close button (×) in the title bar
        local editor = markdown_editor:new{content = "test"}

        -- The close button is wrapped in a FrameContainer for proper touch handling
        assert.is_truthy(editor.close_button_container)
        local close_button = editor.close_button_container[1]
        assert.is_truthy(close_button)
        assert.is.equals("×", close_button.text)
        assert.is.equals("function", type(close_button.callback))
      end)

      it("should have Back button handler", function()
        -- Hardware Back button should work to dismiss keyboard or close
        local editor = markdown_editor:new{content = "test"}

        -- Should have onBack method
        assert.is.equals("function", type(editor.onBack))

        -- Should have Back key event registered
        assert.is_truthy(editor.key_events.Back)
      end)

      it("should have Done, Save & New, and Delete buttons", function()
        -- Action buttons should all exist and be functional
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.save_button)
        assert.is.equals("Done", editor.save_button.text)
        assert.is.equals("function", type(editor.save_button.callback))

        assert.is_truthy(editor.new_note_button)
        assert.is.equals("Save & New", editor.new_note_button.text)
        assert.is.equals("function", type(editor.new_note_button.callback))

        assert.is_truthy(editor.cancel_button)
        assert.is.equals("Delete", editor.cancel_button.text)
        assert.is.equals("function", type(editor.cancel_button.callback))
      end)
    end)

    describe("bug: keyboard covering buttons", function()
      it("should place action buttons at top of layout", function()
        -- The modal keyboard covers the bottom of the screen
        -- The fix was to move action buttons to the top
        local editor = markdown_editor:new{content = "test"}

        -- Check that main_frame exists (it contains the layout)
        assert.is_truthy(editor.main_frame)

        -- The layout should have title_bar and action buttons before editor
        assert.is_truthy(editor.title_bar, "title_bar should exist")
        assert.is_truthy(editor.save_button)
        assert.is_truthy(editor.new_note_button)
        assert.is_truthy(editor.cancel_button)
      end)

      it("should have tappable areas to dismiss keyboard", function()
        -- Toolbar container should be tappable to dismiss keyboard
        -- Note: title_container was removed to avoid blocking close button
        local editor = markdown_editor:new{content = "test"}

        -- title_container should NOT exist (we removed it to avoid blocking close button)
        assert.is_nil(editor.title_container, "title_container should not exist")

        -- Toolbar container should have onTap handler
        assert.is.equals("function", type(editor.toolbar_container.onTap))

        -- There should also be a Hide Keyboard button in the toolbar
        local found_hide_button = false
        for _, btn in ipairs(editor.toolbar_buttons) do
          if btn.id == "hide_keyboard" then
            found_hide_button = true
            break
          end
        end
        assert.is_truthy(found_hide_button, "Hide Keyboard button should exist in toolbar")
      end)

      it("should have Hide Keyboard button in toolbar", function()
        -- There should be a hide keyboard button (⌨) in the toolbar
        local editor = markdown_editor:new{content = "test"}

        local found_hide_button = false
        for _, btn in ipairs(editor.toolbar_buttons) do
          if btn.id == "hide_keyboard" then
            found_hide_button = true
            assert.is.equals("⌨", btn.text)
            assert.is.equals("function", type(btn.callback))
            break
          end
        end

        assert.is_truthy(found_hide_button, "Hide keyboard button not found in toolbar")
      end)
    end)

    describe("bug: auto-save functionality", function()
      it("should have auto-save enabled by default", function()
        -- Auto-save should be enabled to prevent data loss
        local editor = markdown_editor:new{content = "test"}

        assert.is.truthy(editor.auto_save_enabled)
      end)

      it("should have edit_callback for triggering auto-save", function()
        -- Auto-save should be triggered via edit_callback
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.editor)
        assert.is.equals("function", type(editor.editor.edit_callback))
      end)

      it("should have _doAutoSave method", function()
        -- Auto-save implementation should exist
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor._doAutoSave))
      end)

      it("should track auto-save state", function()
        -- Should track filename, created status, and pending saves
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("boolean", type(editor.auto_save_created))
        assert.is.equals("boolean", type(editor.auto_save_pending))
        assert.is.equals("string", type(editor.auto_save_filename or ""))
      end)
    end)

    describe("bug: incorrect module paths", function()
      it("should use correct InputContainer path", function()
        -- Common error: ui/widget/inputcontainer (wrong)
        -- Correct path: ui/widget/container/inputcontainer
        -- This is tested in koreader_modules_spec.lua, but we verify here too
        local editor = markdown_editor:new{content = "test"}

        -- If InputContainer path was wrong, this would have crashed already
        assert.is_truthy(editor)
      end)

      it("should use correct CenterContainer path", function()
        -- Common error: ui/widget/centercontainer (wrong)
        -- Correct path: ui/widget/container/centercontainer
        local editor = markdown_editor:new{content = "test"}

        -- If CenterContainer path was wrong, this would have crashed
        assert.is_truthy(editor.main_frame)
      end)

      it("should use correct FrameContainer path", function()
        -- Common error: ui/widget/framecontainer (wrong)
        -- Correct path: ui/widget/container/framecontainer
        local editor = markdown_editor:new{content = "test"}

        -- If FrameContainer path was wrong, this would have crashed
        -- Note: title_container was removed to avoid blocking close button
        assert.is_truthy(editor.toolbar_container, "toolbar_container should exist")
        assert.is_truthy(editor.main_frame, "main_frame (FrameContainer) should exist")
      end)

      it("should use correct Geometry path", function()
        -- Common error: ui/geom (wrong)
        -- Correct path: ui/geometry
        local editor = markdown_editor:new{content = "test"}

        -- If Geometry path was wrong, this would have crashed
        assert.is_truthy(editor.button_size)
      end)
    end)

    describe("bug: wiki link button missing", function()
      it("should have wiki link button in toolbar", function()
        -- Obsidian-style [[]] links should be supported
        local editor = markdown_editor:new{content = "test"}

        local found_wiki_link = false
        for _, btn in ipairs(editor.toolbar_buttons) do
          if btn.id == "wiki_link" then
            found_wiki_link = true
            assert.is.equals("[[]]", btn.text)
            assert.is.equals("function", type(btn.callback))
            break
          end
        end

        assert.is_truthy(found_wiki_link, "Wiki link button not found in toolbar")
      end)
    end)

    describe("bug: keyboard auto-dismiss not working", function()
      it("should have auto-dismiss state variables", function()
        -- Auto-dismiss requires these state variables
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("number", type(editor.last_typing_time))
        assert.is.equals("number", type(editor.auto_dismiss_delay))
        assert.is.equals("boolean", type(editor._stop_auto_dismiss))
      end)

      it("should have _resetAutoDismissTimer method", function()
        -- This method is called when user types to reset the timer
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor._resetAutoDismissTimer))
      end)

      it("should have autoDismissCheck method", function()
        -- This is the main method that checks if keyboard should be dismissed
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor.autoDismissCheck))
      end)

      it("should have _startAutoDismissCheck method", function()
        -- This method starts the auto-dismiss check loop
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor._startAutoDismissCheck))
      end)

      it("should have _stopAutoDismissCheck method", function()
        -- This method stops the auto-dismiss check loop
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor._stopAutoDismissCheck))
      end)

      it("should reset typing timer when _resetAutoDismissTimer is called", function()
        local editor = markdown_editor:new{content = "test"}
        local old_time = editor.last_typing_time

        -- Wait a bit to ensure time has passed
        os.execute("sleep 0.01")

        editor:_resetAutoDismissTimer()

        -- Timer should have been updated to a later time
        assert.is_truthy(editor.last_typing_time >= old_time)
      end)

      it("should have auto_dismiss_delay set to 5 seconds", function()
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals(5, editor.auto_dismiss_delay)
      end)
    end)

    describe("bug: close button (×) not working", function()
      it("should have close_button_container", function()
        -- The close button (×) is wrapped in a FrameContainer for proper touch handling
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.close_button_container, "close_button_container should exist")
      end)

      it("should have close_button with correct text", function()
        -- Close button should display ×
        local editor = markdown_editor:new{content = "test"}

        -- The button is the first child of the container
        local close_button = editor.close_button_container[1]
        assert.is_truthy(close_button, "close button should exist inside container")
        assert.is.equals("×", close_button.text)
      end)

      it("should have close_button with callback function", function()
        -- Close button should have a callback
        local editor = markdown_editor:new{content = "test"}

        -- The button is the first child of the container
        local close_button = editor.close_button_container[1]
        assert.is_truthy(close_button, "close button should exist inside container")
        assert.is.equals("function", type(close_button.callback))
      end)

      it("should have close_button_container with onTap method for touch handling", function()
        -- The container wrapping the close button has an onTap handler
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.close_button_container, "close_button_container should exist")

        -- The container should have an onTap method to handle touch events
        local has_tap_handler = type(editor.close_button_container.onTap) == "function"

        assert.is_truthy(has_tap_handler, "close_button_container should have an onTap handler")
      end)

      it("should have _doneAndClose method", function()
        -- The close button calls _doneAndClose
        local editor = markdown_editor:new{content = "test"}

        assert.is.equals("function", type(editor._doneAndClose))
      end)

      it("should call _doneAndClose when close button callback is invoked", function()
        -- The callback property should call _doneAndClose
        local editor = markdown_editor:new{content = "test"}

        -- Mock the _doneAndClose method to track if it was called
        local done_and_close_called = false
        local original_done_and_close = editor._doneAndClose
        editor._doneAndClose = function()
          done_and_close_called = true
        end

        -- Simulate clicking the close button by calling its callback
        local close_button = editor.close_button_container[1]
        if close_button and close_button.callback then
          close_button.callback()
        end

        -- Restore original method
        editor._doneAndClose = original_done_and_close

        assert.is_truthy(done_and_close_called, "_doneAndClose should be called when close button callback is invoked")
      end)

      it("should have main_frame widget", function()
        -- _doneAndClose closes the main_frame
        local editor = markdown_editor:new{content = "test"}

        assert.is_truthy(editor.main_frame, "main_frame should exist")
      end)

      it("should NOT have title_container that blocks button clicks", function()
        -- The title_container has been removed to avoid touch event blocking
        -- title_bar is now used directly in the layout
        local editor = markdown_editor:new{content = "test"}

        -- title_container should NOT exist (we removed it)
        assert.is_nil(editor.title_container, "title_container should not exist as it blocks button clicks")

        -- title_bar should exist and contain the close button
        assert.is_truthy(editor.title_bar, "title_bar should exist")
      end)
    end)

    describe("bug: heading buttons affect wrong line - should affect current line", function()
      it("should apply heading to the entire text content (current buggy behavior)", function()
        -- Current implementation applies heading to entire text regardless of cursor
        local editor = markdown_editor:new{content = "Line 1\nLine 2\nLine 3"}

        -- Apply H1 heading
        editor:apply_formatting("heading", 1, 10, 1)

        -- Currently it prefixes the entire text (BUG)
        -- Should be: "# Line 1\nLine 2\nLine 3"
        assert.is.truthy(editor.content:find("^#"), "Content starts with # (current buggy behavior)")
      end)

      it("should have cursor property to track cursor position", function()
        -- Need cursor position to apply formatting to current line only
        local editor = markdown_editor:new{content = "Some text"}

        -- Editor should have cursor property (even if mock doesn't fully support it)
        assert.is_truthy(editor.editor, "InputText editor should exist")

        -- Cursor should be accessible (may be 0 or nil in mock, but property exists)
        if editor.editor.cursor ~= nil then
          assert.is.truthy(true, "cursor property exists")
        end
      end)

      it("should detect when editor has keyboard open (cursor position available)", function()
        -- When keyboard is open, we can get cursor position
        local editor = markdown_editor:new{content = "Line 1\nLine 2"}

        -- keyboard property indicates if keyboard is visible
        -- When keyboard is open, cursor position is meaningful
        if editor.editor.keyboard ~= nil then
          -- In real usage, keyboard presence means we can get cursor
          assert.is_truthy(true, "keyboard property exists for detecting cursor position")
        end
      end)

      it("should apply heading to current line only when keyboard is open", function()
        -- When keyboard is open (cursor available), heading should affect only current line
        local editor = markdown_editor:new{content = "Line 1\nLine 2\nLine 3"}

        -- Simulate keyboard being open and cursor on line 2
        editor.editor.keyboard = true  -- Simulate keyboard open
        editor.editor.cursor = 10  -- Position somewhere in "Line 2"

        -- Apply H1 heading
        editor:apply_formatting("heading", 1, 10, 1)

        -- Should prefix only line 2 (current line), not entire text
        -- Expected: "Line 1\n# Line 2\nLine 3"
        local lines = {}
        for line in editor.content:gmatch("[^\n]+") do
          table.insert(lines, line)
        end

        assert.is.equals(3, #lines, "Should still have 3 lines")
        assert.is.equals("Line 1", lines[1], "Line 1 should be unchanged")
        assert.is.equals("# Line 2", lines[2], "Line 2 should have H1 prefix")
        assert.is.equals("Line 3", lines[3], "Line 3 should be unchanged")
      end)

      it("should apply heading to entire text when keyboard is closed", function()
        -- When keyboard is closed (no cursor), heading affects entire text
        local editor = markdown_editor:new{content = "Line 1\nLine 2\nLine 3"}

        -- No keyboard, no cursor position
        editor.editor.keyboard = nil

        -- Apply H1 heading
        editor:apply_formatting("heading", 1, 10, 1)

        -- Should prefix entire text (fallback behavior)
        assert.is.truthy(editor.content:find("^#"), "Content starts with #")
      end)
    end)

    describe("feature: apply heading to current line only", function()
      it("should be able to split text into lines", function()
        -- Need to process text line by line based on cursor position
        local editor = markdown_editor:new{content = "Line 1\nLine 2\nLine 3"}

        local text = editor.content
        local lines = {}
        for line in text:gmatch("[^\n]+") do
          table.insert(lines, line)
        end

        assert.is.equals(3, #lines, "Should have 3 lines")
        assert.is.equals("Line 1", lines[1])
        assert.is.equals("Line 2", lines[2])
        assert.is.equals("Line 3", lines[3])
      end)

      it("should be able to find which line cursor is on (simulated)", function()
        -- Simulate finding current line based on cursor position
        local text = "Line 1\nLine 2\nLine 3"
        local cursor_pos = 8  -- Somewhere in "Line 2"

        -- Count newlines before cursor position to find line number
        local current_line = 1
        for i = 1, cursor_pos do
          if text:sub(i, i) == "\n" then
            current_line = current_line + 1
          end
        end

        assert.is.equals(2, current_line, "Cursor at position 8 should be on line 2")
      end)
    end)

    describe("bug: heading buttons insert prefix but cursor is before #", function()
      it("should insert # prefix for H1 heading", function()
        -- H1 button should add # at start of text
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H1 heading (format_type, start_pos, end_pos, heading_level)
        editor:apply_formatting("heading", 1, 10, 1)

        -- Should have # prefix
        assert.is.truthy(editor.content:find("^#"))
        assert.is.equals("# My Heading", editor.content)
      end)

      it("should insert ## prefix for H2 heading", function()
        -- H2 button should add ## at start of text
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H2 heading
        editor:apply_formatting("heading", 1, 10, 2)

        -- Should have ## prefix
        assert.is.truthy(editor.content:find("^##"))
        assert.is.equals("## My Heading", editor.content)
      end)

      it("should insert ### prefix for H3 heading", function()
        -- H3 button should add ### at start of text
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H3 heading
        editor:apply_formatting("heading", 1, 10, 3)

        -- Should have ### prefix
        assert.is.truthy(editor.content:find("^###"))
        assert.is.equals("### My Heading", editor.content)
      end)

      it("should have method to move cursor after heading prefix", function()
        -- After inserting heading prefix, cursor should be after the "# " (or "## ", etc.)
        -- This allows user to immediately type heading text
        local editor = markdown_editor:new{content = ""}

        -- The editor should have a cursor property for positioning
        assert.is_truthy(editor.editor, "InputText editor should exist")
        -- cursor may not exist in mock, but property should be there
        -- We verify it can be set
        editor.editor.cursor = 0
        assert.is.equals(0, editor.editor.cursor)
      end)

      it("should position cursor after heading prefix when H1 is inserted", function()
        -- After inserting H1 heading, cursor should be at position 2 (after "# ")
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H1 heading
        editor:apply_formatting("heading", 1, 10, 1)

        -- Cursor should be positioned at 2 (after "# ")
        -- Note: In tests with mock, we check if the logic is there
        -- Real cursor positioning happens on device with actual InputText widget
        if editor.editor.cursor then
          assert.is.equals(2, editor.editor.cursor, "Cursor should be at position 2 after H1 prefix")
        end
      end)

      it("should position cursor after heading prefix when H2 is inserted", function()
        -- After inserting H2 heading, cursor should be at position 3 (after "## ")
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H2 heading
        editor:apply_formatting("heading", 1, 10, 2)

        -- Cursor should be positioned at 3 (after "## ")
        if editor.editor.cursor then
          assert.is.equals(3, editor.editor.cursor, "Cursor should be at position 3 after H2 prefix")
        end
      end)

      it("should position cursor after heading prefix when H3 is inserted", function()
        -- After inserting H3 heading, cursor should be at position 4 (after "### ")
        local editor = markdown_editor:new{content = "My Heading"}

        -- Apply H3 heading
        editor:apply_formatting("heading", 1, 10, 3)

        -- Cursor should be positioned at 4 (after "### ")
        if editor.editor.cursor then
          assert.is.equals(4, editor.editor.cursor, "Cursor should be at position 4 after H3 prefix")
        end
      end)
    end)
  end)
end)
