-- settings.lua
-- Manages plugin settings with KOReader's settings system

local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")
local Device = require("device")

local settings = {}

-- Settings file path
local settings_file
local settings_data

-- Default settings
local defaults = {
  use_color_ui = nil,  -- nil = auto-detect, true = force on, false = force off
}

--- Initialize settings module
-- Must be called before using other settings functions
function settings.init()
  local base_dir = DataStorage:getDataDir()
  settings_file = base_dir .. "/fleeting-notes.settings.lua"

  -- Load existing settings or create new
  settings_data = LuaSettings:open(settings_file)
  settings_data:readSetting("use_color_ui", defaults.use_color_ui)
end

--- Get the use_color_ui setting
-- @return boolean|nil: true = force on, false = force off, nil = auto-detect
function settings.get_use_color_ui()
  if not settings_data then
    settings.init()
  end

  local user_setting = settings_data:readSetting("use_color_ui")

  -- If user hasn't set a preference, auto-detect based on device
  if user_setting == nil then
    return Device:hasColorScreen()
  end

  return user_setting
end

--- Set the use_color_ui setting
-- @param value boolean|nil: true = force on, false = force off, nil = auto-detect
function settings.set_use_color_ui(value)
  if not settings_data then
    settings.init()
  end

  settings_data:saveSetting("use_color_ui", value)
  settings_data:flush()
end

--- Check if color UI should be used
-- Combines user preference with device capability
-- @return boolean: true if colors should be used
function settings.should_use_color()
  local setting = settings.get_use_color_ui()

  -- nil means auto-detect
  if setting == nil then
    return Device:hasColorScreen()
  end

  return setting
end

--- Reset all settings to defaults
function settings.reset()
  if not settings_data then
    settings.init()
  end

  for key, value in pairs(defaults) do
    settings_data:saveSetting(key, value)
  end
  settings_data:flush()
end

--- Get current settings as table
-- @return table: Current settings
function settings.get_all()
  if not settings_data then
    settings.init()
  end

  return {
    use_color_ui = settings_data:readSetting("use_color_ui", defaults.use_color_ui),
  }
end

return settings
