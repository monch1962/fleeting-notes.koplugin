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

--- Start the plugin
-- Called when user activates the plugin from the menu
function Plugin:start()
  -- Create and show the editor
  local editor = MarkdownEditor:new{
    content = "",
    on_save = function(note)
      -- Note was successfully saved
      self:show_notification(_("Note saved: ") .. note.filename)
    end,
    on_close = function(saved)
      -- Editor was closed
      if not saved then
        self:show_notification(_("Note discarded"))
      end
    end,
  }

  UIManager:show(editor)
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
