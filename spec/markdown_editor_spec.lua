-- spec/markdown_editor_spec.lua
-- Tests for markdown_editor.lua

describe("markdown_editor", function()
  local markdown_editor
  local mock_ui_manager = {}

  setup(function()
    -- Mock KOReader UI components
    package.loaded["ui/widget/widget"] = {
      extend = function(cls, methods)
        return setmetatable(methods, {__index = cls})
      end
    }

    package.loaded["ui/widget/inputcontainer"] = {
      extend = function(cls, methods)
        return setmetatable(methods, {__index = cls})
      end
    }

    package.loaded["ui/widget/textboxwidget"] = function()
      return {}
    end

    package.loaded["ui/widget/button"] = function()
      return {}
    end

    package.loaded["ui/widget/horizontalgroup"] = function()
      return {}
    end

    package.loaded["ui/widget/verticalgroup"] = function()
      return {}
    end

    package.loaded["ui/uimanager"] = mock_ui_manager

    package.loaded["markdown_formatter"] = {
      wrap_bold = function(t) return "**" .. t .. "**" end,
      wrap_italic = function(t) return "*" .. t .. "*" end,
      wrap_code = function(t) return "`" .. t .. "`" end,
      insert_heading = function(l) return string.rep("#", l) .. " " end,
      insert_list = function(o) return o and "1. " or "- " end,
      insert_link = function(t, u) return "[" .. t .. "](" .. u .. ")" end,
    }

    package.loaded["note_manager"] = {
      create_note = function(content)
        return {filename = "test.md", content = content, created_at = os.time()}
      end,
    }

    markdown_editor = require("markdown_editor")
  end)

  teardown(function()
    package.loaded["markdown_editor"] = nil
    package.loaded["markdown_formatter"] = nil
    package.loaded["note_manager"] = nil
    package.loaded["ui/widget/widget"] = nil
    package.loaded["ui/widget/inputcontainer"] = nil
    package.loaded["ui/widget/textboxwidget"] = nil
    package.loaded["ui/widget/button"] = nil
    package.loaded["ui/widget/horizontalgroup"] = nil
    package.loaded["ui/widget/verticalgroup"] = nil
    package.loaded["ui/uimanager"] = nil
  end)

  describe("create", function()
    it("should create a new editor instance", function()
      local editor = markdown_editor:create()
      assert.is_truthy(editor)
    end)

    it("should accept initial content", function()
      local editor = markdown_editor:create("# Initial Content")
      assert.is_truthy(editor)
      assert.is.equals("# Initial Content", editor.content)
    end)

    it("should have toolbar buttons", function()
      local editor = markdown_editor:create()
      assert.is_truthy(editor.toolbar_buttons)
      assert.is.truthy(type(editor.toolbar_buttons) == "table")
    end)

    it("should have save and cancel buttons", function()
      local editor = markdown_editor:create()
      assert.is.truthy(editor.save_button)
      assert.is_truthy(editor.cancel_button)
    end)
  end)

  describe("toolbar buttons", function()
    it("should include bold button", function()
      local editor = markdown_editor:create()
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
      local editor = markdown_editor:create()
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
      local editor = markdown_editor:create()
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
      local editor = markdown_editor:create()
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
      local editor = markdown_editor:create()
      local has_bullet, has_numbered = false, false
      for _, btn in ipairs(editor.toolbar_buttons) do
        if btn.id == "bullet_list" then has_bullet = true end
        if btn.id == "numbered_list" then has_numbered = true end
      end
      assert.is_truthy(has_bullet)
      assert.is.truthy(has_numbered)
    end)

    it("should include link button", function()
      local editor = markdown_editor:create()
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
    it("should apply bold to selected text", function()
      local editor = markdown_editor:create("hello world")
      editor:apply_formatting("bold", 1, 5)
      assert.is.equals("**hello** world", editor.content)
    end)

    it("should apply italic to selected text", function()
      local editor = markdown_editor:create("hello world")
      editor:apply_formatting("italic", 1, 5)
      assert.is.equals("*hello* world", editor.content)
    end)

    it("should apply code to selected text", function()
      local editor = markdown_editor:create("hello world")
      editor:apply_formatting("code", 1, 5)
      assert.is.equals("`hello` world", editor.content)
    end)

    it("should insert heading at cursor", function()
      local editor = markdown_editor:create("hello")
      editor:apply_formatting("heading", 1, 1, 2)
      assert.is.equals("## hello", editor.content)
    end)

    it("should insert list at cursor", function()
      local editor = markdown_editor:create("item")
      editor:apply_formatting("list", 1, 1, false)
      assert.is.equals("- item", editor.content)
    end)
  end)

  describe("save_note", function()
    it("should save the current content", function()
      local editor = markdown_editor:create("# Test Note")
      local result = editor:save_note()
      assert.is.truthy(result)
      assert.is_truthy(result.filename)
    end)

    it("should not save empty content", function()
      local editor = markdown_editor:create("")
      local result = editor:save_note()
      assert.is_nil(result)
    end)
  end)

  describe("close", function()
    it("should close without saving when cancelled", function()
      local editor = markdown_editor:create("test")
      local closed = editor:close(false)
      assert.is.truthy(closed)
    end)

    it("should save and close when confirmed", function()
      local editor = markdown_editor:create("test")
      local closed, saved = editor:close(true)
      assert.is.truthy(closed)
      assert.is_truthy(saved)
    end)
  end)

  describe("on_close_widget", function()
    it("should be callable", function()
      local editor = markdown_editor:create("test")
      editor:onCloseWidget()
      -- Should not error
      assert.is_truthy(true)
    end)
  end)
end)
