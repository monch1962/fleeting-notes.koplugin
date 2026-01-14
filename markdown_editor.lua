-- markdown_editor.lua
-- KOReader widget for editing Markdown notes with a toolbar
-- Provides buttons for common Markdown formatting operations

local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local InputContainer = require("ui/widget/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local Button = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local CenterContainer = require("ui/widget/centercontainer")
local FrameContainer = require("ui/widget/framecontainer")
local Geom = require("ui/geom")
local Font = require("ui/font")
local _ = require("gettext")

local markdown_formatter = require("markdown_formatter")
local note_manager = require("note_manager")

-- Markdown Editor Widget
local MarkdownEditor = InputContainer:extend{
  -- Initial content
  content = "",
  -- Callback when note is saved
  on_save = nil,
  -- Callback when editor is closed
  on_close = nil,
  -- Editor dimensions (will be set by KOReader)
  face = Font:getFace("smallinfofont"),
  -- Toolbar button size
  button_size = Geom:new{ w = 60, h = 40 },
}

function MarkdownEditor:init()
  -- Store initial content
  self.initial_content = self.content

  -- Build UI
  self:_buildToolbar()
  self:_buildEditor()
  self:_buildActionButtons()
  self:_buildMainLayout()

  -- Map keyboard shortcuts
  self.key_events.Close = { { "Back" }, doc = "close editor" }
end

-- Build the toolbar with Markdown formatting buttons
function MarkdownEditor:_buildToolbar()
  self.toolbar_buttons = {}

  -- Bold button
  table.insert(self.toolbar_buttons, {
    id = "bold",
    text = "**B**",
    callback = function()
      self:_applyCurrentSelection("bold")
    end,
  })

  -- Italic button
  table.insert(self.toolbar_buttons, {
    id = "italic",
    text = "*I*",
    callback = function()
      self:_applyCurrentSelection("italic")
    end,
  })

  -- Code button
  table.insert(self.toolbar_buttons, {
    id = "code",
    text = "</>",
    callback = function()
      self:_applyCurrentSelection("code")
    end,
  })

  -- Heading buttons
  table.insert(self.toolbar_buttons, {
    id = "h1",
    text = "H1",
    callback = function()
      self:_applyCurrentSelection("heading", 1)
    end,
  })

  table.insert(self.toolbar_buttons, {
    id = "h2",
    text = "H2",
    callback = function()
      self:_applyCurrentSelection("heading", 2)
    end,
  })

  table.insert(self.toolbar_buttons, {
    id = "h3",
    text = "H3",
    callback = function()
      self:_applyCurrentSelection("heading", 3)
    end,
  })

  -- Bullet list button
  table.insert(self.toolbar_buttons, {
    id = "bullet_list",
    text = "•-",
    callback = function()
      self:_applyCurrentSelection("list", false)
    end,
  })

  -- Numbered list button
  table.insert(self.toolbar_buttons, {
    id = "numbered_list",
    text = "1.",
    callback = function()
      self:_applyCurrentSelection("list", true)
    end,
  })

  -- Link button
  table.insert(self.toolbar_buttons, {
    id = "link",
    text = "[L]",
    callback = function()
      self:_insertLink()
    end,
  })

  -- Create button widgets
  self.toolbar_button_widgets = {}
  for _, btn_spec in ipairs(self.toolbar_buttons) do
    local btn = Button:new{
      text = btn_spec.text,
      callback = btn_spec.callback,
      width = self.button_size.w,
      height = self.button_size.h,
      font_face = "smallfont",
      font_size = 16,
      bordersize = 1,
      radius = 3,
    }
    table.insert(self.toolbar_button_widgets, btn)
  end
end

-- Build the text editor area
function MarkdownEditor:_buildEditor()
  self.editor = TextBoxWidget:new{
    text = self.content,
    face = self.face,
    width = math.min(Screen:getWidth() - 40, 600),
    height = math.min(Screen:getHeight() - 200, 400),
    editable = true,
    scroll = true,
    alignment = "left",
    para_direction_rtl = false,
    lang = nil,
  }
end

-- Build save and cancel buttons
function MarkdownEditor:_buildActionButtons()
  self.save_button = Button:new{
    text = _("Save"),
    callback = function()
      self:_saveAndClose()
    end,
    width = 150,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
  }

  self.cancel_button = Button:new{
    text = _("Cancel"),
    callback = function()
      self:_closeWithoutSaving()
    end,
    width = 150,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
  }
end

-- Build the main layout
function MarkdownEditor:_buildMainLayout()
  -- Toolbar row
  local toolbar_group = HorizontalGroup:new{}
  for _, btn in ipairs(self.toolbar_button_widgets) do
    table.insert(toolbar_group, btn)
    table.insert(toolbar_group, HorizontalSpan:new{ width = 5 })
  end

  -- Action buttons row
  local action_group = HorizontalGroup:new{
    HorizontalSpan:new{ width = 20 },
    self.cancel_button,
    HorizontalSpan:new{ width = 20 },
    self.save_button,
  }

  -- Main vertical layout
  self.main_frame = FrameContainer:new{
    radius = 8,
    bordersize = 2,
    padding = 10,
    margin = 5,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new{
      align = "center",
      TextBoxWidget:new{
        text = _("Fleeting Note"),
        face = Font:getFace("tfont", 22),
        width = math.min(Screen:getWidth() - 40, 600),
      },
      VerticalSpan:new{ width = 10 },
      toolbar_group,
      VerticalSpan:new{ width = 10 },
      self.editor,
      VerticalSpan:new{ width = 15 },
      action_group,
    }
  }

  self[1] = CenterContainer:new{
    dimen = Screen:getSize(),
    self.main_frame,
  }
end

-- Apply formatting to current text selection
-- @param format_type string: Type of formatting to apply
-- @param ...: Additional parameters (e.g., heading level)
function MarkdownEditor:_applyCurrentSelection(format_type, ...)
  -- Get current text
  local current_text = self.editor:getText()

  -- Get selection (if any) - TextBoxWidget may not expose this directly
  -- For now, we'll apply to the entire text or insert at cursor position
  -- In a full implementation, you'd need to track cursor/selection state

  -- Simple implementation: apply to entire content
  -- In KOReader, TextBoxWidget doesn't easily expose cursor position
  -- A more complete implementation would need custom cursor tracking

  local formatted = markdown_formatter.apply_formatting(
    current_text,
    format_type,
    1,  -- start_pos (simplified)
    #current_text,  -- end_pos (simplified)
    ...
  )

  self.editor:setText(formatted)
  self.content = formatted

  -- Trigger refresh for E-ink
  UIManager:setDirty(self.main_frame, "ui")
end

-- Insert a link (prompts for text and URL)
function MarkdownEditor:_insertLink()
  -- In a full implementation, this would show input dialogs
  -- For now, insert a template link
  local current_text = self.editor:getText()
  local link_template = "[link text](url)"

  self.editor:setText(current_text .. " " .. link_template)
  self.content = self.editor:getText()

  UIManager:setDirty(self.main_frame, "ui")
end

-- Apply formatting programmatically (for external use)
-- @param format_type string: Type of formatting
-- @param start_pos number: Start position
-- @param end_pos number: End position
-- @param ...: Additional parameters
function MarkdownEditor:apply_formatting(format_type, start_pos, end_pos, ...)
  self:_applyCurrentSelection(format_type, ...)
end

-- Save the note and close
function MarkdownEditor:_saveAndClose()
  local content = self.editor:getText()

  -- Validate content
  if not note_manager.validate_content(content) then
    UIManager:show(InfoMessage:new{
      text = _("Cannot save empty note"),
    })
    return
  end

  -- Save the note
  local note = note_manager.create_note(content)

  if note then
    -- Call save callback if provided
    if self.on_save then
      self.on_save(note)
    end

    -- Close the editor
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(true)
    end

    UIManager:show(InfoMessage:new{
      text = _("Note saved: ") .. note.filename,
    })
  else
    UIManager:show(InfoMessage:new{
      text = _("Failed to save note"),
    })
  end
end

-- Close without saving
function MarkdownEditor:_closeWithoutSaving()
  UIManager:close(self.main_frame)

  if self.on_close then
    self.on_close(false)
  end
end

-- Public method to save note (returns the note object)
-- @return table|nil: Note object or nil on failure
function MarkdownEditor:save_note()
  local content = self.editor:getText()

  if not note_manager.validate_content(content) then
    return nil
  end

  return note_manager.create_note(content)
end

-- Public method to close the editor
-- @param save boolean: Whether to save before closing
-- @return boolean, boolean|nil: Success status, whether note was saved
function MarkdownEditor:close(save)
  if save then
    self:_saveAndClose()
    return true, true
  else
    self:_closeWithoutSaving()
    return true, false
  end
end

-- Called when widget is closed
function MarkdownEditor:onCloseWidget()
  -- Cleanup if needed
end

return MarkdownEditor
