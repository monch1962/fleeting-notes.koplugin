-- markdown_editor.lua
-- KOReader widget for editing Markdown notes with a toolbar
-- Provides buttons for common Markdown formatting operations
-- Auto-saves content to disk as user types

local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local InputText = require("ui/widget/inputtext")
local Button = require("ui/widget/button")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local Font = require("ui/font")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Screen = require("device").screen
local _ = require("gettext")

local markdown_formatter = require("markdown_formatter")
local note_manager = require("note_manager")
local file_storage = require("file_storage")
local plugin_settings = require("settings")

-- Color support detection (respects user settings)
-- Check if Blitbuffer.ColorRGB is available (not available in all KOReader versions)
local has_color_support = plugin_settings.should_use_color() and type(Blitbuffer.ColorRGB) == "function"

-- Helper function to create color if available
local function make_color(r, g, b)
  if has_color_support then
    return Blitbuffer.ColorRGB(r, g, b)
  end
  return nil
end

-- Color palette for UI elements (only used when enabled and available)
local colors = {
  -- Toolbar button colors
  bold = make_color(0, 100, 230),      -- Blue
  italic = make_color(0, 150, 50),     -- Green
  code = make_color(200, 140, 0),      -- Amber/Yellow
  heading = make_color(140, 50, 180),  -- Purple
  list = make_color(220, 100, 0),      -- Orange
  link = make_color(0, 160, 180),      -- Teal
  wiki_link = make_color(0, 180, 200), -- Cyan

  -- Action button colors
  save = make_color(50, 180, 80),      -- Green (primary)
  save_new = make_color(0, 120, 215),  -- Blue (secondary)
  delete = make_color(200, 50, 50),    -- Red (destructive)
}

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

  -- Edit mode state
  self.is_editing = false  -- Start in read-only mode (no keyboard)

  -- Auto-dismiss keyboard state
  self.last_typing_time = 0  -- Last time user typed something
  self.auto_dismiss_delay = 5  -- Seconds of inactivity before dismissing keyboard
  self.auto_dismiss_check_job = nil  -- Job for checking auto-dismiss
  self._stop_auto_dismiss = false  -- Flag to stop auto-dismiss check

  -- Build UI
  self:_buildToolbar()
  self:_buildActionButtons()
  self:_buildEditor()  -- Build editor (will be read-only initially)
  self:_buildMainLayout()

  -- Map keyboard shortcuts
  self.key_events.Back = { { "Back" }, doc = "dismiss keyboard or close" }
end

-- Toggle between read-only and edit modes
function MarkdownEditor:_toggleEditMode()
  self.is_editing = not self.is_editing

  if self.is_editing then
    -- Switch to edit mode (show InputText with keyboard)
    self:_rebuildEditorForEditing()
    -- Start auto-dismiss check when entering edit mode
    self:_startAutoDismissCheck()
  else
    -- Switch to read-only mode (show TextBoxWidget, hide keyboard)
    self:_rebuildEditorForReading()
    -- Stop auto-dismiss check when leaving edit mode
    self:_stopAutoDismissCheck()
  end
end

-- Start checking for keyboard auto-dismiss
function MarkdownEditor:_startAutoDismissCheck()
  -- Stop any existing check first
  self:_stopAutoDismissCheck()

  self._stop_auto_dismiss = false
  self.last_typing_time = os.time()

  -- Schedule recurring check
  self:autoDismissCheck()
end

-- Check if keyboard should be auto-dismissed (called every second)
function MarkdownEditor:autoDismissCheck()
  if self._stop_auto_dismiss then
    return
  end

  -- Only check if we're in edit mode and keyboard is visible
  if self.is_editing and self.editor and self.editor.keyboard then
    local current_time = os.time()
    local idle_time = current_time - self.last_typing_time

    -- If idle for longer than the delay, dismiss keyboard
    if idle_time >= self.auto_dismiss_delay then
      self.editor:onCloseKeyboard()
      return  -- Don't reschedule after dismissing
    end
  end

  -- Reschedule check in 1 second
  UIManager:scheduleIn(1, function()
    self:autoDismissCheck()
  end)
end

-- Stop auto-dismiss check
function MarkdownEditor:_stopAutoDismissCheck()
  self._stop_auto_dismiss = true
  if self.auto_dismiss_check_job then
    UIManager:unschedule(self.auto_dismiss_check_job)
    self.auto_dismiss_check_job = nil
  end
end

-- Reset the auto-dismiss timer (call when user types)
function MarkdownEditor:_resetAutoDismissTimer()
  self.last_typing_time = os.time()
end

-- Handle Back button to dismiss keyboard or close editor
function MarkdownEditor:onBack()
  -- If editor has a keyboard, try to close it
  if self.editor and self.editor.keyboard then
    self.editor:onCloseKeyboard()
    return true  -- Stop propagation, user can press Back again to close
  end

  -- No keyboard to close, so close the editor
  self:_doneAndClose()
  return true
end

-- Perform the auto-save operation
function MarkdownEditor:_doAutoSave()
  self.auto_save_pending = false

  -- Use self.content (kept up to date by edit_callback)
  local current_content = self.content

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

  -- Hide Keyboard button (always accessible, even when keyboard is open)
  table.insert(self.toolbar_buttons, {
    id = "hide_keyboard",
    text = "⌨",
    color = Blitbuffer.COLOR_DARK_GRAY,
    callback = function()
      if self.editor and self.editor.keyboard then
        self.editor:onCloseKeyboard()
      end
    end,
  })

  -- Bold button
  table.insert(self.toolbar_buttons, {
    id = "bold",
    text = "**B**",
    color = colors.bold,
    callback = function()
      self:_applyCurrentSelection("bold")
    end,
  })

  -- Italic button
  table.insert(self.toolbar_buttons, {
    id = "italic",
    text = "*I*",
    color = colors.italic,
    callback = function()
      self:_applyCurrentSelection("italic")
    end,
  })

  -- Code button
  table.insert(self.toolbar_buttons, {
    id = "code",
    text = "</>",
    color = colors.code,
    callback = function()
      self:_applyCurrentSelection("code")
    end,
  })

  -- Heading buttons
  table.insert(self.toolbar_buttons, {
    id = "h1",
    text = "H1",
    color = colors.heading,
    callback = function()
      self:_applyCurrentSelection("heading", 1)
    end,
  })

  table.insert(self.toolbar_buttons, {
    id = "h2",
    text = "H2",
    color = colors.heading,
    callback = function()
      self:_applyCurrentSelection("heading", 2)
    end,
  })

  table.insert(self.toolbar_buttons, {
    id = "h3",
    text = "H3",
    color = colors.heading,
    callback = function()
      self:_applyCurrentSelection("heading", 3)
    end,
  })

  -- Bullet list button
  table.insert(self.toolbar_buttons, {
    id = "bullet_list",
    text = "•-",
    color = colors.list,
    callback = function()
      self:_applyCurrentSelection("list", false)
    end,
  })

  -- Numbered list button
  table.insert(self.toolbar_buttons, {
    id = "numbered_list",
    text = "1.",
    color = colors.list,
    callback = function()
      self:_applyCurrentSelection("list", true)
    end,
  })

  -- Link button
  table.insert(self.toolbar_buttons, {
    id = "link",
    text = "[L]",
    color = colors.link,
    callback = function()
      self:_insertLink()
    end,
  })

  -- Wiki link button (for Obsidian [[links]])
  table.insert(self.toolbar_buttons, {
    id = "wiki_link",
    text = "[[]]",
    color = colors.wiki_link,
    callback = function()
      self:_applyCurrentSelection("wiki_link")
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
      background = btn_spec.color,
    }
    table.insert(self.toolbar_button_widgets, btn)
  end
end

-- Build the text editor area (read-only mode by default)
function MarkdownEditor:_buildEditor()
  -- Calculate available height for editor more conservatively
  local reserved_space = 350
  local available_height = Screen:getHeight() - reserved_space

  -- Ensure minimum and maximum height
  if available_height < 100 then
    available_height = 100
  elseif available_height > 600 then
    available_height = 600
  end

  -- Start with read-only TextBoxWidget (no keyboard)
  self:_rebuildEditorForReading()
end

-- Build read-only editor (TextBoxWidget, no keyboard)
function MarkdownEditor:_rebuildEditorForReading()
  local available_height = Screen:getHeight() - 350
  if available_height < 100 then available_height = 100
  elseif available_height > 600 then available_height = 600 end

  -- Use self.content as the source of truth
  local current_text = self.content or ""

  self.editor = TextBoxWidget:new{
    text = current_text,
    face = self.face,
    width = math.min(Screen:getWidth() - 40, 800),
    height = available_height,
    alignment = "left",
  }

  self:_updateMainLayout()
end

-- Build editable editor (InputText with keyboard)
function MarkdownEditor:_rebuildEditorForEditing()
  local available_height = Screen:getHeight() - 350
  if available_height < 100 then available_height = 100
  elseif available_height > 600 then available_height = 600 end

  -- Use self.content as the source of truth
  local current_text = self.content or ""

  -- Create InputText widget first
  local new_editor = InputText:new{
    text = current_text,
    face = self.face,
    width = math.min(Screen:getWidth() - 40, 800),
    height = available_height,
    scroll = true,
    alignment = "left",
    parent = self,
    edit_callback = function()
      -- Reset auto-dismiss timer when user types
      self:_resetAutoDismissTimer()

      -- Trigger auto-save when text is modified
      if not self.auto_save_pending then
        self.auto_save_pending = true
        UIManager:nextTick(function()
          self:_doAutoSave()
        end)
      end
    end,
  }

  -- Remove InputText's default Back button handling
  new_editor.key_events = {}

  -- When keyboard is dismissed, switch back to read-only mode
  local editor_instance = self  -- Capture MarkdownEditor instance
  local original_close_keyboard = new_editor.onCloseKeyboard
  function new_editor:onCloseKeyboard()
    -- Update content one last time before closing
    if type(new_editor.getText) == "function" then
      editor_instance.content = new_editor:getText()
    end

    if original_close_keyboard then
      original_close_keyboard(new_editor)
    end
    -- Switch back to read-only mode after keyboard is dismissed
    UIManager:nextTick(function()
      if editor_instance._toggleEditMode then
        editor_instance:_toggleEditMode()
      end
    end)
  end

  -- Now assign to self.editor
  self.editor = new_editor

  self:_updateMainLayout()

  -- Automatically show keyboard when entering edit mode
  UIManager:nextTick(function()
    self.editor:onTap()
  end)
end

-- Build save and cancel buttons
function MarkdownEditor:_buildActionButtons()
  self.save_button = Button:new{
    text = _("Done"),
    callback = function()
      -- Only dismiss keyboard if we're in edit mode and keyboard exists
      if self.is_editing and self.editor and self.editor.keyboard then
        self.editor:onCloseKeyboard()
      end
      UIManager:nextTick(function()
        self:_doneAndClose()
      end)
    end,
    width = 110,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
    background = colors.save,
  }

  self.new_note_button = Button:new{
    text = _("Save & New"),
    callback = function()
      -- Only dismiss keyboard if we're in edit mode and keyboard exists
      if self.is_editing and self.editor and self.editor.keyboard then
        self.editor:onCloseKeyboard()
      end
      UIManager:nextTick(function()
        self:_saveAndNewNote()
      end)
    end,
    width = 130,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
    background = colors.save_new,
  }

  self.cancel_button = Button:new{
    text = _("Delete"),
    callback = function()
      -- Only dismiss keyboard if we're in edit mode and keyboard exists
      if self.is_editing and self.editor and self.editor.keyboard then
        self.editor:onCloseKeyboard()
      end
      UIManager:nextTick(function()
        self:_deleteAndClose()
      end)
    end,
    width = 110,
    height = 40,
    font_face = "smallfont",
    font_size = 18,
    bordersize = 2,
    radius = 5,
    background = colors.delete,
  }
end

-- Build the main layout
function MarkdownEditor:_buildMainLayout()
  -- Edit Text button (to toggle keyboard on/off)
  self.edit_button = Button:new{
    text = _("Edit Text"),
    callback = function()
      self:_toggleEditMode()
    end,
    width = 110,
    height = 40,
    font_face = "smallfont",
    font_size = 16,
    bordersize = 2,
    radius = 5,
    background = Blitbuffer.COLOR_DARK_GRAY,
  }

  -- Close button (×)
  self.close_button = Button:new{
    text = "×",
    callback = function()
      self:_doneAndClose()
    end,
    width = 50,
    height = 40,
    font_face = "smallfont",
    font_size = 22,
    bordersize = 1,
    radius = 3,
    background = Blitbuffer.COLOR_DARK_GRAY,
  }

  -- Title widget
  self.title_widget = TextBoxWidget:new{
    text = _("Fleeting Note (auto-hides keyboard after 5s)"),
    face = Font:getFace("tfont", 18),  -- Smaller font for longer text
    width = math.min(Screen:getWidth() - 200, 500),
  }

  -- Title bar with edit button, close button, and title
  self.title_bar = HorizontalGroup:new{
    self.edit_button,
    HorizontalSpan:new{ width = 10 },
    self.close_button,
    HorizontalSpan:new{ width = 10 },
    self.title_widget,
  }

  -- Make title container tappable to dismiss keyboard
  self.title_container = FrameContainer:new{
    margin = 0,
    bordersize = 0,
    background = Blitbuffer.COLOR_WHITE,
    self.title_bar,
  }

  -- Add tap handler to title container
  function self.title_container:onTap()
    -- Dismiss keyboard if open
    if self.editor and self.editor.keyboard then
      self.editor:onCloseKeyboard()
    end
    return true
  end

  -- Action buttons row (at top, won't be covered by keyboard)
  local action_group = HorizontalGroup:new{
    HorizontalSpan:new{ width = 15 },
    self.save_button,
    HorizontalSpan:new{ width = 15 },
    self.new_note_button,
    HorizontalSpan:new{ width = 15 },
    self.cancel_button,
  }

  -- Toolbar row
  local toolbar_group = HorizontalGroup:new{}
  for _, btn in ipairs(self.toolbar_button_widgets) do
    table.insert(toolbar_group, btn)
    table.insert(toolbar_group, HorizontalSpan:new{ width = 5 })
  end

  -- Make toolbar container tappable to dismiss keyboard
  self.toolbar_container = FrameContainer:new{
    margin = 0,
    bordersize = 0,
    background = Blitbuffer.COLOR_WHITE,
    toolbar_group,
  }

  function self.toolbar_container:onTap()
    -- Dismiss keyboard if open so buttons can be clicked
    if self.editor and self.editor.keyboard then
      self.editor:onCloseKeyboard()
    end
    return true
  end

  -- Main vertical layout with buttons at top
  self.main_frame = FrameContainer:new{
    radius = 8,
    bordersize = 2,
    padding = 10,
    margin = 5,
    background = Blitbuffer.COLOR_WHITE,
    VerticalGroup:new{
      align = "center",
      self.title_container,
      VerticalSpan:new{ width = 10 },
      action_group,
      VerticalSpan:new{ width = 10 },
      self.toolbar_container,
      VerticalSpan:new{ width = 10 },
      self.editor,
    }
  }

  self[1] = CenterContainer:new{
    dimen = Screen:getSize(),
    self.main_frame,
  }
end

-- Update main layout after switching editor modes
function MarkdownEditor:_updateMainLayout()
  -- Rebuild the main layout with the updated editor
  self:_buildMainLayout()

  -- Trigger UI refresh
  UIManager:setDirty(self.main_frame, "ui")
end

-- Apply formatting to current text selection
-- @param format_type string: Type of formatting to apply
-- @param ...: Additional parameters (e.g., heading level)
function MarkdownEditor:_applyCurrentSelection(format_type, ...)
  -- If in read-only mode, switch to edit mode first
  if not self.is_editing then
    self:_toggleEditMode()
    -- Don't apply formatting yet, wait for user to enter edit mode
    return
  end

  -- Get current text from self.content
  local current_text = self.content

  -- Apply formatting
  local formatted = markdown_formatter.apply_formatting(
    current_text,
    format_type,
    1,
    #current_text,
    ...
  )

  -- Update both editor and content
  self.content = formatted
  if self.editor and type(self.editor.setText) == "function" then
    self.editor:setText(formatted)
  end

  -- Trigger auto-save after formatting
  self:_doAutoSave()

  -- Trigger refresh for E-ink
  UIManager:setDirty(self.main_frame, "ui")
end

-- Insert a link (prompts for text and URL)
function MarkdownEditor:_insertLink()
  -- In a full implementation, this would show input dialogs
  -- For now, insert a template link
  local current_text = self.content
  local link_template = "[link text](url)"

  self.content = current_text .. " " .. link_template
  if self.editor and type(self.editor.setText) == "function" then
    self.editor:setText(self.content)
  end

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
  -- Use self.content (kept up to date by edit_callback)
  local content = self.content

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
  -- Use self.content
  local content = self.content

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
  -- Use self.content (kept up to date by edit_callback)
  local content = self.content

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
  -- Stop auto-dismiss check
  self:_stopAutoDismissCheck()

  -- Final auto-save before closing (if not already handled)
  if self.auto_save_created and self.auto_save_filename then
    -- Use self.content (already up to date from edit_callback)
    if note_manager.validate_content(self.content) then
      file_storage.save_note(self.auto_save_filename, self.content)
    end
  end
end

return MarkdownEditor
