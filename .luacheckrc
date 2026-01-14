-- Luacheck configuration for fleeting-notes.koplugin

-- Ignore self (global variable)
globals = {"_"}

-- Read-only globals (KOReader APIs - available in runtime)
read_globals = {
  -- KOReader UI
  "UIManager",
  "Widget",
  "InputContainer",
  "CenterContainer",
  "TextWidget",
  "Button",
  "TextBoxWidget",
  "HorizontalGroup",
  "HorizontalSpan",
  "VerticalGroup",
  "VerticalSpan",
  "FrameContainer",
  "BottomContainer",
  "TopContainer",
  "LeftContainer",
  "RightContainer",
  "UnderlineContainer",
  "LineWidget",
  "ProgressWidget",
  "CloseButton",
  "ConfirmBox",
  "InputDialog",
  "InfoMessage",
  "Notification",

  -- KOReader utilities
  "DataStorage",
  "G_reader_settings",
  "_",

  -- Lua standard libraries
  "string",
  "table",
  "io",
  "os",
  "math",
  "utf8",
  "package",
  "debug",
  "loadstring",
  "pairs",
  "ipairs",
  "next",
  "pcall",
  "xpcall",
  "error",
  "type",
  "tostring",
  "tonumber",
  "select",
  "assert",
  "unpack",
  "setmetatable",
  "getmetatable",
  "rawget",
  "rawset",
  "rawequal",
  "require",
  "module",
  "print",
}

-- Unused arguments (prefixed with _)
unused_args = false

-- Unused second argument in for loops
ignore = { "431/.*", "211/_", "212/_" }

-- Max line length
max_line_length = 150

-- Allow unused code for definitions
unused = false

-- Allow redefinition of unused arguments
redefined = false
