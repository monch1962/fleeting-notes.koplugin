-- markdown_editor.lua
-- KOReader widget for editing Markdown notes with a toolbar
-- Provides buttons for common Markdown formatting operations
-- Auto-saves content to disk as user types

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
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local _ = require("gettext")

local markdown_formatter = require("markdown_formatter")
local note_manager = require("note_manager")
local file_storage = require("file_storage")

-- Markdown Editor Widget with Auto-Save
local MarkdownEditor = InputContainer:extend{
  -- Initial content
  content = "",
  -- Callback when note is saved
  on_save = nil,
  -- Callback when editor is closed
  on_close = nil,
  -- Callback to create a new note (for "Save & New" functionality)
  on_new_note = nil,
  -- Editor dimensions (will be set by KOReader)
  face = Font:getFace("smallinfofont"),
  -- Toolbar button size
  button_size = Geom:new{ w = 60, h = 40 },
}

function MarkdownEditor:init()
  -- Store initial content
  self.initial_content = self.content

  -- Auto-save state
  self.auto_save_enabled = true
  self.auto_save_filename = nil  -- Set on first keystroke
  self.auto_save_created = false  -- Becomes true after first save
  self.last_saved_content = ""    -- Track last saved content for comparison
  self.auto_save_pending = false  -- Flag for pending save operation

  -- Build UI
  self:_buildToolbar()
  self:_buildEditor()
  self:_buildActionButtons()
  self:_buildMainLayout()

  -- Map keyboard shortcuts
  self.key_events.Close = { { "Back" }, doc = "close editor" }
  self.key_events.AutoSave = {
    { "any" },
    event = "KeyScroll",
    handler = function(key_event)
      return self:_onAnyKey(key_event)
    end
  }
end

-- Called on any key press - triggers auto-save
function MarkdownEditor:_onAnyKey(key_event)
  -- Schedule auto-save for next tick (don't block input)
  if not self.auto_save_pending then
    self.auto_save_pending = true
    UIManager:nextTick(function()
      self:_doAutoSave()
    end)
  end

  -- Return false to let the key event propagate to the TextBoxWidget
  return false
end

-- Perform the auto-save operation
function MarkdownEditor:_doAutoSave()
  self.auto_save_pending = false

  -- Get current content
  local current_content = self.editor:getText()

  -- Don't save if empty
  if not note_manager.validate_content(current_content) then
    return
  end

  -- Don't save if content hasn't changed
  if current_content == self.last_saved_content then
    return
  end

  -- Create file on first meaningful content
  if not self.auto_save_created then
    -- Create the note file with current timestamp
    local note = note_manager.create_note(current_content)
    if note then
      self.auto_save_filename = note.filename
      self.auto_save_created = true
      self.last_saved_content = current_content

      -- Update the title to show we're auto-saving
      self:_updateTitle(true)

      -- Show brief indicator
      self:_showAutoSaveIndicator(true)
    end
  else
    -- Update existing file
    if self.auto_save_filename then
      file_storage.save_note(self.auto_save_filename, current_content)
      self.last_saved_content = current_content
      self:_showAutoSaveIndicator(false)
    end
  end
end

-- Update the title to show auto-save status
function MarkdownEditor:_updateTitle(has_file)
  if has_file then
    self.title_widget:setText(_("Fleeting Note (auto-saving)"))
  else
    self.title_widget:setText(_("Fleeting Note"))
  end
  UIManager:setDirty(self.main_frame, "ui")
end

-- Show a subtle auto-save indicator
function MarkdownEditor:_showAutoSaveIndicator(is_new)
  -- Brief indicator that auto-save happened
  -- Don't show on E-ink devices to avoid unnecessary refreshes
  -- Could add a small icon or status text if desired
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
    text = _("Done"),
    callback = function()
      self:_doneAndClose()
    end,
    width = 110,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
  }

  self.new_note_button = Button:new{
    text = _("Save & New"),
    callback = function()
      self:_saveAndNewNote()
    end,
    width = 130,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
  }

  self.cancel_button = Button:new{
    text = _("Delete"),
    callback = function()
      self:_deleteAndClose()
    end,
    width = 110,
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
    HorizontalSpan:new{ width = 15 },
    self.cancel_button,
    HorizontalSpan:new{ width = 15 },
    self.new_note_button,
    HorizontalSpan:new{ width = 15 },
    self.save_button,
  }

  -- Title widget
  self.title_widget = TextBoxWidget:new{
    text = _("Fleeting Note"),
    face = Font:getFace("tfont", 22),
    width = math.min(Screen:getWidth() - 40, 600),
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
      self.title_widget,
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

  -- Trigger auto-save after formatting
  self:_doAutoSave()

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

  -- Trigger auto-save after inserting link
  self:_doAutoSave()

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

-- Done: save final state and close (file already auto-saved)
function MarkdownEditor:_doneAndClose()
  local content = self.editor:getText()

  -- If file was created, it's already saved
  if self.auto_save_created and self.auto_save_filename then
    -- Do one final save to ensure latest content is there
    self:_doAutoSave()

    -- Call save callback if provided
    if self.on_save then
      self.on_save({
        filename = self.auto_save_filename,
        content = content,
        created_at = os.time(),
      })
    end

    -- Close the editor
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(true)
    end

    UIManager:show(InfoMessage:new{
      text = _("Note saved: ") .. self.auto_save_filename,
    })
  elseif note_manager.validate_content(content) then
    -- Edge case: content exists but file wasn't created (shouldn't happen)
    local note = note_manager.create_note(content)
    if note then
      if self.on_save then
        self.on_save(note)
      end

      UIManager:close(self.main_frame)

      if self.on_close then
        self.on_close(true)
      end

      UIManager:show(InfoMessage:new{
        text = _("Note saved: ") .. note.filename,
      })
    end
  else
    -- Empty content, just close
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(false)
    end
  end
end

-- Save & New: close current note and immediately create a new one
function MarkdownEditor:_saveAndNewNote()
  local content = self.editor:getText()

  -- If file was created, it's already saved
  if self.auto_save_created and self.auto_save_filename then
    -- Do one final save to ensure latest content is there
    self:_doAutoSave()

    -- Call save callback if provided
    if self.on_save then
      self.on_save({
        filename = self.auto_save_filename,
        content = content,
        created_at = os.time(),
      })
    end

    -- Close the current editor
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(true)
    end

    -- Show brief notification then create new note
    UIManager:show(InfoMessage:new{
      text = _("Note saved: ") .. self.auto_save_filename,
      timeout = 1,
    })

    -- Schedule new note creation (after notification closes)
    UIManager:nextTick(function()
      if self.on_new_note then
        self.on_new_note()
      end
    end)
  elseif note_manager.validate_content(content) then
    -- Edge case: content exists but file wasn't created
    local note = note_manager.create_note(content)
    if note then
      if self.on_save then
        self.on_save(note)
      end

      UIManager:close(self.main_frame)

      if self.on_close then
        self.on_close(true)
      end

      UIManager:show(InfoMessage:new{
        text = _("Note saved: ") .. note.filename,
        timeout = 1,
      })

      UIManager:nextTick(function()
        if self.on_new_note then
          self.on_new_note()
        end
      end)
    end
  else
    -- Empty content, just create new note
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(false)
    end

    if self.on_new_note then
      self.on_new_note()
    end
  end
end

-- Delete: remove the auto-saved file and close
function MarkdownEditor:_deleteAndClose()
  if self.auto_save_created and self.auto_save_filename then
    -- Confirm deletion
    UIManager:show(ConfirmBox:new{
      text = _("Delete this note?"),
      ok_text = _("Delete"),
      cancel_text = _("Keep"),
      ok_callback = function()
        -- Delete the file
        file_storage.delete_note(self.auto_save_filename)

        UIManager:close(self.main_frame)

        if self.on_close then
          self.on_close(false)
        end

        UIManager:show(InfoMessage:new{
          text = _("Note deleted"),
        })
      end,
    })
  else
    -- No file was created, just close
    UIManager:close(self.main_frame)

    if self.on_close then
      self.on_close(false)
    end
  end
end

-- Public method to get current note info
-- @return table|nil: Note object or nil if no content
function MarkdownEditor:get_note()
  local content = self.editor:getText()

  if not note_manager.validate_content(content) then
    return nil
  end

  return {
    filename = self.auto_save_filename,
    content = content,
    created_at = os.time(),
  }
end

-- Public method to close the editor
-- @param delete boolean: Whether to delete the note (default: false)
function MarkdownEditor:close(delete)
  if delete then
    self:_deleteAndClose()
  else
    self:_doneAndClose()
  end
end

-- Called when widget is closed
function MarkdownEditor:onCloseWidget()
  -- Final auto-save before closing (if not already handled)
  if self.auto_save_created and self.auto_save_filename then
    local content = self.editor:getText()
    if note_manager.validate_content(content) then
      file_storage.save_note(self.auto_save_filename, content)
    end
  end
end

return MarkdownEditor
