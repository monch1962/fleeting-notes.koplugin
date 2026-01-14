-- markdown_formatter.lua
-- Helper functions for Markdown syntax insertion and formatting
-- Handles text selection, wrapping, and toggling Markdown syntax

local markdown_formatter = {}

--- Wrap text in bold markers
-- @param text string: Text to wrap
-- @return string: Bold-wrapped text
function markdown_formatter.wrap_bold(text)
  return "**" .. text .. "**"
end

--- Wrap text in italic markers
-- @param text string: Text to wrap
-- @return string: Italic-wrapped text
function markdown_formatter.wrap_italic(text)
  return "*" .. text .. "*"
end

--- Wrap text in code markers
-- @param text string: Text to wrap
-- @return string: Code-wrapped text
function markdown_formatter.wrap_code(text)
  return "`" .. text .. "`"
end

--- Insert heading prefix
-- @param level number: Heading level (1-6)
-- @return string: Heading prefix (e.g., "# ", "## ", etc.)
function markdown_formatter.insert_heading(level)
  local valid_level = math.max(1, math.min(6, level or 1))
  return string.rep("#", valid_level) .. " "
end

--- Insert list prefix
-- @param ordered boolean: True for numbered list, false for bullet list
-- @return string: List prefix (e.g., "- " or "1. ")
function markdown_formatter.insert_list(ordered)
  if ordered then
    return "1. "
  else
    return "- "
  end
end

--- Insert markdown link
-- @param text string: Link text
-- @param url string: Link URL
-- @return string: Markdown link
function markdown_formatter.insert_link(text, url)
  return "[" .. (text or "") .. "](" .. (url or "") .. ")"
end

--- Toggle bold formatting (wrap or unwrap)
-- @param text string: Text to toggle
-- @return string: Text with bold toggled
function markdown_formatter.toggle_bold(text)
  -- Handle empty string
  if not text or text == "" then
    return ""
  end

  -- Count leading asterisks
  local leading_stars = 0
  for i = 1, #text do
    if text:sub(i, i) == "*" then
      leading_stars = leading_stars + 1
    else
      break
    end
  end

  -- Count trailing asterisks
  local trailing_stars = 0
  for i = #text, 1, -1 do
    if text:sub(i, i) == "*" then
      trailing_stars = trailing_stars + 1
    else
      break
    end
  end

  -- If we have **text** (exactly 2+ on both sides), unwrap by removing exactly 2 from each side
  if leading_stars >= 2 and trailing_stars >= 2 then
    -- Extract the text after removing all leading and trailing asterisks
    local inner = text:sub(leading_stars + 1, #text - trailing_stars)
    -- Add back (leading_stars - 2) asterisks on each side
    return string.rep("*", leading_stars - 2) .. inner .. string.rep("*", trailing_stars - 2)
  end

  -- If we have any asterisks but mismatched, add 1 to each side (keeping existing)
  if leading_stars > 0 or trailing_stars > 0 then
    return "*" .. text .. "*"
  end

  -- Not wrapped, wrap it with **
  return "**" .. text .. "**"
end

--- Toggle italic formatting (wrap or unwrap)
-- @param text string: Text to toggle
-- @return string: Text with italic toggled
function markdown_formatter.toggle_italic(text)
  -- Handle empty string
  if not text or text == "" then
    return ""
  end

  -- Check if already wrapped in italic
  local trimmed = text:match("^%s*(.-)%s*$")

  -- Check for *text* pattern (but not **text**)
  if trimmed:match("^%*.+%*$") and not trimmed:match("^%*%*.+") then
    -- Unwrap: remove outer * markers
    local unwrapped = trimmed:match("^%*(.-)%*$")
    if unwrapped then
      return unwrapped
    end
  end

  -- Not wrapped, wrap it
  return markdown_formatter.wrap_italic(text)
end

--- Toggle code formatting (wrap or unwrap)
-- @param text string: Text to toggle
-- @return string: Text with code toggled
function markdown_formatter.toggle_code(text)
  -- Handle empty string
  if not text or text == "" then
    return ""
  end

  -- Check if already wrapped in code
  local trimmed = text:match("^%s*(.-)%s*$")

  -- Check for `text` pattern
  if trimmed:match("^`.+`$") then
    -- Unwrap: remove outer ` markers
    local unwrapped = trimmed:match("^`(.-)`$")
    if unwrapped then
      return unwrapped
    end
  end

  -- Not wrapped, wrap it
  return markdown_formatter.wrap_code(text)
end

--- Wrap text in wiki link markers for Obsidian
-- @param text string: Text to wrap
-- @return string: Wiki link wrapped text
function markdown_formatter.wrap_wiki_link(text)
  return "[[" .. text .. "]]"
end

--- Toggle wiki link formatting (wrap or unwrap)
-- @param text string: Text to toggle
-- @return string: Text with wiki link toggled
function markdown_formatter.toggle_wiki_link(text)
  -- Count leading brackets
  local leading_brackets = 0
  for i = 1, #text do
    if text:sub(i, i) == "[" then
      leading_brackets = leading_brackets + 1
    else
      break
    end
  end

  -- Count trailing brackets
  local trailing_brackets = 0
  for i = #text, 1, -1 do
    if text:sub(i, i) == "]" then
      trailing_brackets = trailing_brackets + 1
    else
      break
    end
  end

  -- If we have [[text]] (exactly 2+ on both sides), unwrap by removing exactly 2 from each side
  if leading_brackets >= 2 and trailing_brackets >= 2 then
    local inner = text:sub(leading_brackets + 1, #text - trailing_brackets)
    return string.rep("[", leading_brackets - 2) .. inner .. string.rep("]", trailing_brackets - 2)
  end

  -- If we have any brackets but mismatched or <2, add 1 to each side
  if leading_brackets > 0 or trailing_brackets > 0 then
    return "[" .. text .. "]"
  end

  -- Not wrapped, wrap it with [[
  return "[[" .. text .. "]]"
end

--- Apply formatting to selected text in a larger text
-- @param full_text string: The full text content
-- @param format_type string: Type of formatting ("bold", "italic", "code", "heading", "list", "wiki_link")
-- @param start_pos number: Start position of selection (1-indexed)
-- @param end_pos number: End position of selection (1-indexed)
-- @param ...: Additional parameters (e.g., heading level, ordered list)
-- @return string: Text with formatting applied
function markdown_formatter.apply_formatting(full_text, format_type, start_pos, end_pos, ...)
  -- Validate inputs
  if not full_text or full_text == "" then
    -- For insertion operations (heading, list), return the prefix
    if format_type == "heading" then
      local level = select(1, ...) or 1
      return markdown_formatter.insert_heading(level)
    elseif format_type == "list" then
      local ordered = select(1, ...)
      return markdown_formatter.insert_list(ordered)
    end
    return full_text
  end

  -- Handle empty or invalid selection (insert at position)
  if not start_pos or start_pos < 1 then
    start_pos = 1
  end
  if not end_pos or end_pos > #full_text then
    end_pos = #full_text
  end

  -- Extract selected text
  local before = full_text:sub(1, start_pos - 1)
  local selection = full_text:sub(start_pos, end_pos)
  local after = full_text:sub(end_pos + 1)

  -- Apply formatting based on type
  local formatted = selection

  if format_type == "bold" then
    formatted = markdown_formatter.toggle_bold(selection)
  elseif format_type == "italic" then
    formatted = markdown_formatter.toggle_italic(selection)
  elseif format_type == "code" then
    formatted = markdown_formatter.toggle_code(selection)
  elseif format_type == "wiki_link" then
    formatted = markdown_formatter.toggle_wiki_link(selection)
  elseif format_type == "heading" then
    -- Insert heading prefix at start of line
    local level = select(1, ...) or 1
    formatted = markdown_formatter.insert_heading(level) .. selection
  elseif format_type == "list" then
    -- Insert list prefix
    local ordered = select(1, ...)
    formatted = markdown_formatter.insert_list(ordered) .. selection
  else
    -- Unknown format type, return unchanged
    return full_text
  end

  return before .. formatted .. after
end

return markdown_formatter
