# frozen_string_literal: true

require "test_helper"
require "ratatui_ruby"

class MarkdownRendererTest < Minitest::Test
  Span  = RatatuiRuby::Text::Span
  Line  = RatatuiRuby::Text::Line
  Style = RatatuiRuby::Style::Style

  def render(text, width: 80)
    WritersRoom::MarkdownRenderer.render(text, width: width)
  end

  # --- Headers ---

  def test_h1_header
    lines = render("# Hello World")
    assert_equal 1, lines.length

    span = lines[0].spans[0]
    assert_equal "Hello World", span.content
    assert_includes span.style.modifiers, :bold
    assert_equal :yellow, span.style.fg
  end

  def test_h2_header
    lines = render("## Sub Heading")
    assert_equal 1, lines.length

    span = lines[0].spans[0]
    assert_equal "Sub Heading", span.content
    assert_includes span.style.modifiers, :bold
    assert_equal :yellow, span.style.fg
  end

  def test_h3_header
    lines = render("## Sub Heading\n### Third Level")
    assert_equal 2, lines.length

    span = lines[1].spans[0]
    assert_equal "Third Level", span.content
    assert_equal :cyan, span.style.fg
  end

  # --- Inline Formatting ---

  def test_bold_text
    lines = render("This is **bold** text")
    assert_equal 1, lines.length

    spans = lines[0].spans
    assert_equal "This is ", spans[0].content
    assert_equal "bold", spans[1].content
    assert_includes spans[1].style.modifiers, :bold
    assert_equal " text", spans[2].content
  end

  def test_italic_text
    lines = render("This is *italic* text")
    assert_equal 1, lines.length

    spans = lines[0].spans
    assert_equal "italic", spans[1].content
    assert_includes spans[1].style.modifiers, :italic
  end

  def test_inline_code
    lines = render("Use `bundle exec` to run")
    assert_equal 1, lines.length

    spans = lines[0].spans
    assert_equal "bundle exec", spans[1].content
    assert_equal :light_green, spans[1].style.fg
  end

  def test_link
    lines = render("Visit [Ruby](https://ruby-lang.org) for more")
    assert_equal 1, lines.length

    spans = lines[0].spans
    assert_equal "Ruby", spans[1].content
    assert_equal :light_blue, spans[1].style.fg
    assert_includes spans[1].style.modifiers, :underlined
  end

  # --- Block Elements ---

  def test_code_block
    md = "```\nputs 'hello'\nputs 'world'\n```"
    lines = render(md)
    assert_equal 2, lines.length

    lines.each do |line|
      assert_equal :light_green, line.spans[0].style.fg
    end

    assert_includes lines[0].spans[0].content, "puts 'hello'"
    assert_includes lines[1].spans[0].content, "puts 'world'"
  end

  def test_blockquote
    lines = render("> This is a quote")
    assert_equal 1, lines.length

    spans = lines[0].spans
    # First span is the "│ " prefix
    assert_includes spans[0].content, "\u2502"
    assert_equal :dark_gray, spans[0].style.fg
  end

  def test_unordered_list
    lines = render("- First item\n- Second item")
    assert_equal 2, lines.length

    lines.each do |line|
      assert_includes line.spans[0].content, "\u2022"  # bullet
    end
  end

  def test_horizontal_rule
    lines = render("---")
    assert_equal 1, lines.length

    span = lines[0].spans[0]
    assert_includes span.content, "\u2500"
    assert_equal :dark_gray, span.style.fg
  end

  # --- Table ---

  def test_table_row
    lines = render("| Name | Value |")
    assert_equal 1, lines.length

    all_content = lines[0].spans.map(&:content).join
    assert_includes all_content, "Name"
    assert_includes all_content, "Value"
  end

  def test_table_separator
    lines = render("|---|---|")
    assert_equal 1, lines.length
    assert_equal :dark_gray, lines[0].spans[0].style.fg
  end

  # --- Edge Cases ---

  def test_nil_input
    assert_equal [], render(nil)
  end

  def test_empty_input
    assert_equal [], render("")
  end

  def test_plain_text
    lines = render("Just plain text")
    assert_equal 1, lines.length
    assert_equal "Just plain text", lines[0].spans[0].content
  end

  def test_multiline_text
    lines = render("Line one\nLine two\nLine three")
    assert_equal 3, lines.length
  end

  def test_unclosed_code_block
    md = "```\nputs 'hello'"
    lines = render(md)
    assert_equal 1, lines.length
    assert_includes lines[0].spans[0].content, "puts 'hello'"
  end

  def test_mixed_formatting
    lines = render("**bold** and *italic* and `code`")
    assert_equal 1, lines.length

    spans = lines[0].spans
    assert_equal "bold", spans[0].content
    assert_includes spans[0].style.modifiers, :bold
    assert_equal " and ", spans[1].content
    assert_equal "italic", spans[2].content
    assert_includes spans[2].style.modifiers, :italic
    assert_equal " and ", spans[3].content
    assert_equal "code", spans[4].content
    assert_equal :light_green, spans[4].style.fg
  end
end
