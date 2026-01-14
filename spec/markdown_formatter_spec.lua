-- spec/markdown_formatter_spec.lua
-- Tests for markdown_formatter.lua

describe("markdown_formatter", function()
  local markdown_formatter

  setup(function()
    markdown_formatter = require("markdown_formatter")
  end)

  teardown(function()
    package.loaded["markdown_formatter"] = nil
  end)

  describe("wrap_bold", function()
    it("should wrap text in bold markers", function()
      local result = markdown_formatter.wrap_bold("hello")
      assert.is.equals("**hello**", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.wrap_bold("")
      assert.is.equals("****", result)
    end)

    it("should handle text with spaces", function()
      local result = markdown_formatter.wrap_bold("hello world")
      assert.is.equals("**hello world**", result)
    end)

    it("should handle text with existing markdown", function()
      local result = markdown_formatter.wrap_bold("*italic*")
      assert.is.equals("***italic***", result)
    end)
  end)

  describe("wrap_italic", function()
    it("should wrap text in italic markers", function()
      local result = markdown_formatter.wrap_italic("hello")
      assert.is.equals("*hello*", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.wrap_italic("")
      assert.is.equals("**", result)
    end)

    it("should handle text with spaces", function()
      local result = markdown_formatter.wrap_italic("hello world")
      assert.is.equals("*hello world*", result)
    end)
  end)

  describe("wrap_code", function()
    it("should wrap text in code markers", function()
      local result = markdown_formatter.wrap_code("hello")
      assert.is.equals("`hello`", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.wrap_code("")
      assert.is.equals("``", result)
    end)

    it("should handle text with spaces", function()
      local result = markdown_formatter.wrap_code("hello world")
      assert.is.equals("`hello world`", result)
    end)
  end)

  describe("insert_heading", function()
    it("should insert level 1 heading", function()
      local result = markdown_formatter.insert_heading(1)
      assert.is.equals("# ", result)
    end)

    it("should insert level 2 heading", function()
      local result = markdown_formatter.insert_heading(2)
      assert.is.equals("## ", result)
    end)

    it("should insert level 3 heading", function()
      local result = markdown_formatter.insert_heading(3)
      assert.is.equals("### ", result)
    end)

    it("should default to level 1 for invalid level", function()
      local result = markdown_formatter.insert_heading(0)
      assert.is.equals("# ", result)
    end)

    it("should cap at level 6", function()
      local result = markdown_formatter.insert_heading(10)
      assert.is.equals("###### ", result)
    end)
  end)

  describe("insert_list", function()
    it("should insert bullet list prefix", function()
      local result = markdown_formatter.insert_list(false)
      assert.is.equals("- ", result)
    end)

    it("should insert numbered list prefix", function()
      local result = markdown_formatter.insert_list(true)
      assert.is.equals("1. ", result)
    end)

    it("should default to bullet list for no argument", function()
      local result = markdown_formatter.insert_list()
      assert.is.equals("- ", result)
    end)
  end)

  describe("insert_link", function()
    it("should create markdown link", function()
      local result = markdown_formatter.insert_link("Google", "https://google.com")
      assert.is.equals("[Google](https://google.com)", result)
    end)

    it("should handle empty text", function()
      local result = markdown_formatter.insert_link("", "https://google.com")
      assert.is.equals("[](https://google.com)", result)
    end)

    it("should handle empty URL", function()
      local result = markdown_formatter.insert_link("Google", "")
      assert.is.equals("[Google]()", result)
    end)

    it("should handle empty both", function()
      local result = markdown_formatter.insert_link("", "")
      assert.is.equals("[]()", result)
    end)
  end)

  describe("wrap_wiki_link", function()
    it("should wrap text in wiki link markers", function()
      local result = markdown_formatter.wrap_wiki_link("My Note")
      assert.is.equals("[[My Note]]", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.wrap_wiki_link("")
      assert.is.equals("[[]]", result)
    end)

    it("should handle text with spaces", function()
      local result = markdown_formatter.wrap_wiki_link("another note")
      assert.is.equals("[[another note]]", result)
    end)
  end)

  describe("toggle_wiki_link", function()
    it("should wrap plain text in wiki link", function()
      local result = markdown_formatter.toggle_wiki_link("My Note")
      assert.is.equals("[[My Note]]", result)
    end)

    it("should unwrap already wiki-linked text", function()
      local result = markdown_formatter.toggle_wiki_link("[[My Note]]")
      assert.is.equals("My Note", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.toggle_wiki_link("")
      assert.is.equals("[[]]", result)
    end)

    it("should not unwrap if markers are mismatched", function()
      local result = markdown_formatter.toggle_wiki_link("[[My Note]")
      -- Should wrap it to make it complete
      assert.is.equals("[[[My Note]]]", result)
    end)
  end)

  describe("toggle_bold", function()
    it("should wrap plain text in bold", function()
      local result = markdown_formatter.toggle_bold("hello")
      assert.is.equals("**hello**", result)
    end)

    it("should unwrap already bold text", function()
      local result = markdown_formatter.toggle_bold("**hello**")
      assert.is.equals("hello", result)
    end)

    it("should handle text with extra asterisks", function()
      local result = markdown_formatter.toggle_bold("***hello***")
      assert.is.equals("*hello*", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.toggle_bold("")
      assert.is.equals("", result)
    end)

    it("should not unwrap if markers are mismatched", function()
      local result = markdown_formatter.toggle_bold("**hello*")
      assert.is.equals("***hello**", result)  -- Adds one more to make it even
    end)
  end)

  describe("toggle_italic", function()
    it("should wrap plain text in italic", function()
      local result = markdown_formatter.toggle_italic("hello")
      assert.is.equals("*hello*", result)
    end)

    it("should unwrap already italic text", function()
      local result = markdown_formatter.toggle_italic("*hello*")
      assert.is.equals("hello", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.toggle_italic("")
      assert.is.equals("", result)
    end)
  end)

  describe("toggle_code", function()
    it("should wrap plain text in code", function()
      local result = markdown_formatter.toggle_code("hello")
      assert.is.equals("`hello`", result)
    end)

    it("should unwrap already code-wrapped text", function()
      local result = markdown_formatter.toggle_code("`hello`")
      assert.is.equals("hello", result)
    end)

    it("should handle empty string", function()
      local result = markdown_formatter.toggle_code("")
      assert.is.equals("", result)
    end)
  end)

  describe("apply_formatting", function()
    it("should apply bold formatting to selection", function()
      local result = markdown_formatter.apply_formatting("hello world", "bold", 1, 5)
      -- Should wrap "hello" in bold
      assert.is.equals("**hello** world", result)
    end)

    it("should apply italic formatting to selection", function()
      local result = markdown_formatter.apply_formatting("hello world", "italic", 1, 5)
      assert.is.equals("*hello* world", result)
    end)

    it("should apply code formatting to selection", function()
      local result = markdown_formatter.apply_formatting("hello world", "code", 1, 5)
      assert.is.equals("`hello` world", result)
    end)

    it("should apply wiki link formatting to selection", function()
      local result = markdown_formatter.apply_formatting("hello world", "wiki_link", 1, 5)
      assert.is.equals("[[hello]] world", result)
    end)

    it("should handle invalid format type", function()
      local result = markdown_formatter.apply_formatting("hello", "invalid", 1, 5)
      assert.is.equals("hello", result)
    end)

    it("should handle empty text", function()
      local result = markdown_formatter.apply_formatting("", "bold", 1, 1)
      assert.is.equals("", result)
    end)

    it("should insert heading when no selection", function()
      local result = markdown_formatter.apply_formatting("", "heading", 1, 1, 2)
      assert.is.equals("## ", result)
    end)

    it("should insert list when no selection", function()
      local result = markdown_formatter.apply_formatting("", "list", 1, 1, false)
      assert.is.equals("- ", result)
    end)
  end)
end)
