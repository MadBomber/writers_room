# frozen_string_literal: true

require "strscan"
require "ratatui_ruby"

module WritersRoom
  # Converts markdown strings to arrays of RatatuiRuby::Text::Line with styled spans.
  # Handles headers, bold, italic, code blocks, inline code, lists, blockquotes,
  # horizontal rules, tables, and links.
  class MarkdownRenderer
    Span  = RatatuiRuby::Text::Span
    Line  = RatatuiRuby::Text::Line
    Style = RatatuiRuby::Style::Style

    STYLES = {
      h1:          Style.new(fg: :yellow, modifiers: [:bold]),
      h2:          Style.new(fg: :yellow, modifiers: [:bold]),
      h3:          Style.new(fg: :cyan, modifiers: [:bold]),
      bold:        Style.new(modifiers: [:bold]),
      italic:      Style.new(modifiers: [:italic]),
      code_inline: Style.new(fg: :light_green),
      code_block:  Style.new(fg: :light_green),
      link:        Style.new(fg: :light_blue, modifiers: [:underlined]),
      quote:       Style.new(fg: :dark_gray, modifiers: [:italic]),
      rule:        Style.new(fg: :dark_gray),
      list_marker: Style.new(fg: :dark_gray),
      table_sep:   Style.new(fg: :dark_gray),
      table_head:  Style.new(modifiers: [:bold]),
      default:     Style.new
    }.freeze

    # Render a markdown string into an array of Text::Line objects.
    #
    # @param markdown [String] the markdown content
    # @param width [Integer] available width for horizontal rules and tables
    # @return [Array<RatatuiRuby::Text::Line>]
    def self.render(markdown, width: 80)
      new(width:).render(markdown)
    end

    def initialize(width: 80)
      @width = width
    end

    def render(markdown)
      return [] if markdown.nil? || markdown.empty?

      lines      = markdown.lines.map(&:chomp)
      result     = []
      in_code    = false
      code_lines = []

      lines.each do |raw|
        if in_code
          if raw.strip.start_with?("```")
            result.concat(render_code_block(code_lines))
            code_lines = []
            in_code = false
          else
            code_lines << raw
          end
          next
        end

        if raw.strip.start_with?("```")
          in_code = true
          next
        end

        result << parse_line(raw)
      end

      # Unclosed code block — render what we have
      result.concat(render_code_block(code_lines)) unless code_lines.empty?

      result
    end

    private

    def parse_line(raw)
      stripped = raw.strip

      case stripped
      when /\A(#{Regexp.escape("---")}|#{Regexp.escape("***")}|#{Regexp.escape("___")})\s*\z/
        render_horizontal_rule
      when /\A###\s+(.*)/
        render_header($1, :h3)
      when /\A##\s+(.*)/
        render_header($1, :h2)
      when /\A#\s+(.*)/
        render_header($1, :h1)
      when /\A>\s?(.*)/
        render_blockquote($1)
      when /\A\s*[-*+]\s+(.*)/
        render_list_item($1)
      when /\A\s*\d+\.\s+(.*)/
        render_list_item($1, ordered: true)
      when /\A\|.*\|\s*\z/
        render_table_row(stripped)
      else
        build_line(parse_inline(stripped))
      end
    end

    def render_header(text, level)
      spans = parse_inline(text)
      styled_spans = spans.map { |s| Span.styled(s.content, STYLES[level]) }
      build_line(styled_spans)
    end

    def render_blockquote(text)
      prefix = Span.styled("\u2502 ", STYLES[:quote])
      inner  = parse_inline(text).map { |s| Span.styled(s.content, STYLES[:quote]) }
      build_line([prefix] + inner)
    end

    def render_list_item(text, ordered: false)
      marker = ordered ? "  \u2022 " : "  \u2022 "
      prefix = Span.styled(marker, STYLES[:list_marker])
      build_line([prefix] + parse_inline(text))
    end

    def render_horizontal_rule
      rule_text = "\u2500" * [@width - 2, 10].max
      build_line([Span.styled(rule_text, STYLES[:rule])])
    end

    def render_code_block(lines)
      lines.map do |line|
        build_line([Span.styled("  #{line}", STYLES[:code_block])])
      end
    end

    def render_table_row(raw)
      cells = raw.split("|").map(&:strip).reject(&:empty?)

      # Detect separator rows like |---|---|
      if cells.all? { |c| c.match?(/\A[-:]+\z/) }
        sep = cells.map { |c| "\u2500" * [c.length, 3].max }
        text = "\u2502" + sep.join("\u2502") + "\u2502"
        return build_line([Span.styled(text, STYLES[:table_sep])])
      end

      # Detect if this is a header row (first data row before separator)
      spans = cells.flat_map.with_index do |cell, i|
        sep_span = i > 0 ? [Span.styled(" \u2502 ", STYLES[:table_sep])] : []
        sep_span + parse_inline(cell)
      end

      build_line(spans)
    end

    # Parse inline markdown elements: **bold**, *italic*, `code`, [text](url)
    def parse_inline(text)
      return [Span.raw("")] if text.nil? || text.empty?

      spans   = []
      scanner = StringScanner.new(text)

      until scanner.eos?
        if scanner.scan(/\*\*(.+?)\*\*/)
          spans << Span.styled(scanner[1], STYLES[:bold])
        elsif scanner.scan(/\*(.+?)\*/)
          spans << Span.styled(scanner[1], STYLES[:italic])
        elsif scanner.scan(/`([^`]+)`/)
          spans << Span.styled(scanner[1], STYLES[:code_inline])
        elsif scanner.scan(/\[([^\]]+)\]\(([^)]+)\)/)
          spans << Span.styled(scanner[1], STYLES[:link])
        elsif scanner.scan(/[^*`\[]+/)
          spans << Span.raw(scanner.matched)
        else
          spans << Span.raw(scanner.getch)
        end
      end

      spans.empty? ? [Span.raw("")] : spans
    end

    def build_line(spans)
      Line.new(spans:)
    end
  end
end
