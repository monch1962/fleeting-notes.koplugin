-- main.lua
-- Fleeting Notes KOReader Plugin Entry Point
-- Captures quick notes while reading with Markdown support and Obsidian compatibility

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

-- Load local modules
local MarkdownEditor = require("markdown_editor")
local note_manager = require("note_manager")

local Plugin = {
  -- Plugin is enabled by default
  disabled = false,

  -- Menu item text
  menu_text = _("Fleeting Notes"),

  -- Check if plugin should be shown in menu
  is_always_enabled = true,
}

--- Initialize the plugin
-- Called when KOReader loads the plugin
function Plugin:init()
  -- Set up notes directory
  local base_dir = DataStorage:getDataDir()
  self.notes_dir = base_dir .. "/fleeting-notes"

  -- Ensure directory exists
  note_manager.set_notes_dir(self.notes_dir)
  note_manager.ensure_notes_dir(self.notes_dir)
end

--- Create and show a new note editor
-- @param content string: Optional initial content
function Plugin:create_editor(content)
  content = content or ""

  -- Create and show the editor
  local editor = MarkdownEditor:new{
    content = content,
    on_save = function(note)
      -- Note was successfully saved (also called by Save & New)
      -- Don't show notification here - Save & New handles it
    end,
    on_close = function(saved)
      -- Editor was closed
      -- No notification needed - the individual buttons handle feedback
    end,
    on_new_note = function()
      -- Create a new note immediately
      self:create_editor("")
    end,
  }

  UIManager:show(editor)
end

--- Start the plugin
-- Called when user activates the plugin from the menu
function Plugin:start()
  self:create_editor("")
end

--- Show a notification message
-- @param message string: Message to display
function Plugin:show_notification(message)
  local InfoMessage = require("ui/widget/infomessage")
  UIManager:show(InfoMessage:new{
    text = message,
    timeout = 2,
  })
end

return Plugin
