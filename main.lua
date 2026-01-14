-- main.lua
-- Fleeting Notes KOReader Plugin Entry Point
-- Captures quick notes while reading with Markdown support and Obsidian compatibility

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

-- Load local modules
local MarkdownEditor = require("markdown_editor")
local note_manager = require("note_manager")
local plugin_settings = require("settings")

local Plugin = WidgetContainer:extend{
  name = "fleeting_notes",
  is_doc_only = false,
  disabled = false,
}

--- Initialize the plugin
-- Called when KOReader loads the plugin
function Plugin:init()
  -- Set up notes directory
  local base_dir = DataStorage:getDataDir()
  self.notes_dir = base_dir .. "/fleeting-notes"

  -- Ensure directory exists and set it
  local file_storage = require("file_storage")
  file_storage.set_notes_dir(self.notes_dir)
  file_storage.ensure_notes_dir()

  -- Register plugin in the main menu
  self.ui.menu:registerToMainMenu(self)
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

--- Add plugin to the main menu
-- @param menu_items table: Menu items table to populate
function Plugin:addToMainMenu(menu_items)
  menu_items.fleeting_notes = {
    text = _("Fleeting Notes"),
    sorting_hint = "more_tools",
    sub_item_table = {
      {
        text = _("New note"),
        callback = function()
          self:start()
        end,
      },
      {
        text = _("Settings"),
        separator = true,
        sub_item_table = {
          {
            text = _("Use color UI"),
            checked_func = function()
              return plugin_settings.get_use_color_ui()
            end,
            callback = function()
              local current = plugin_settings.get_use_color_ui()
              local new_value

              -- Toggle through states: auto -> on -> off -> auto
              if current == nil then
                new_value = true  -- Auto -> On
              elseif current == true then
                new_value = false  -- On -> Off
              else
                new_value = nil  -- Off -> Auto
              end

              plugin_settings.set_use_color_ui(new_value)

              -- Show notification
              local msg
              if new_value == nil then
                msg = _("Color UI: Auto-detect")
              elseif new_value == true then
                msg = _("Color UI: Enabled")
              else
                msg = _("Color UI: Disabled")
              end

              self:show_notification(msg)
            end,
            help_text = _([[
Choose when to use color UI:
• Auto-detect: Use colors on color devices
• Enabled: Always use colors
• Disabled: Never use colors

Changes take effect when you open a new note.]]),
          },
        },
      },
    },
  }
end

return Plugin
