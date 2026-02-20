# frozen_string_literal: true

require "ratatui_ruby"

module WritersRoom
  # Terminal UI for ChatSession using ratatui_ruby.
  # Owns the event loop, layout, drawing, input editing, scrolling, and spinner animation.
  # Delegates all business logic to ChatSession.
  #
  # Layout (19-row minimum):
  #   Row 0..15  Messages scrollback (flex, bordered)
  #   Row 16     Status bar — spinner animation, exchange count
  #   Row 17-18  Input area (bordered, 1 usable line)
  class ChatTui
    SPINNER_FRAMES = %w[⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷].freeze
    POLL_TIMEOUT   = 0.05  # 50ms ≈ 20fps for spinner

    TASK_LABELS = {
      chat:      "Thinking",
      summary:   "Summarizing",
      save:      "Saving",
      auto_save: "Analyzing & saving"
    }.freeze

    def initialize(session)
      @session       = session
      @display_lines = []
      @input_buffer  = ""
      @cursor_pos    = 0
      @scroll_offset = 0
      @auto_scroll   = true
      @state         = :idle       # :idle or :waiting
      @running       = true
      @llm_thread    = nil
      @spinner_tick  = 0
      @pending_task  = nil
    end

    # Run the TUI event loop. Blocks until user exits.
    def run
      @session.log_session_start

      append_system_message(@session.welcome_text)
      ctx = @session.context_text
      append_system_message(ctx) unless ctx.empty?

      RatatuiRuby.run do |tui|
        @tui = tui
        while @running
          draw_frame(tui)
          handle_event(tui.poll_event(timeout: POLL_TIMEOUT))
          check_llm_thread
        end
      end

      @session.log_session_end
      @session.messages
    end

    private

    # --- Layout & Drawing ---

    def draw_frame(tui)
      tui.draw do |frame|
        areas = tui.split(
          frame.area,
          direction: :vertical,
          constraints: [tui.flex(1), tui.fixed(1), tui.fixed(3)]
        )

        draw_messages(tui, frame, areas[0])
        draw_status_bar(tui, frame, areas[1])
        draw_input(tui, frame, areas[2])
      end
    end

    def draw_messages(_tui, frame, area)
      block = RatatuiRuby::Widgets::Block.new(
        borders: [:all],
        border_type: :rounded,
        border_style: RatatuiRuby::Style::Style.new(fg: :dark_gray)
      )

      inner = block.inner(area)
      visible_height = inner.height

      max_scroll = [(@display_lines.length - visible_height), 0].max
      @scroll_offset = @scroll_offset.clamp(0, max_scroll)
      @scroll_offset = max_scroll if @auto_scroll

      paragraph = RatatuiRuby::Widgets::Paragraph.new(
        text: @display_lines.empty? ? "" : @display_lines,
        block: block,
        wrap: true,
        scroll: [@scroll_offset, 0]
      )

      frame.render_widget(paragraph, area)
    end

    def draw_status_bar(_tui, frame, area)
      spans = build_status_spans(area.width)
      line  = RatatuiRuby::Text::Line.new(spans: spans)

      paragraph = RatatuiRuby::Widgets::Paragraph.new(text: [line])
      frame.render_widget(paragraph, area)
    end

    def build_status_spans(width)
      if @state == :waiting
        build_spinner_spans(width)
      else
        build_idle_status_spans(width)
      end
    end

    def build_spinner_spans(width)
      tick  = SPINNER_FRAMES[@spinner_tick % SPINNER_FRAMES.length]
      label = TASK_LABELS[@pending_task] || "Working"
      dots  = "." * ((@spinner_tick / 4) % 4)

      left_text = " #{tick}  #{label}#{dots}"
      hint_text = "Ctrl+C to cancel "
      bar_width = [width - left_text.length - hint_text.length, 0].max
      bar_fill  = (@spinner_tick % (bar_width + 1))
      bar       = ("\u2588" * bar_fill).ljust(bar_width)

      [
        RatatuiRuby::Text::Span.styled(
          left_text,
          RatatuiRuby::Style::Style.new(fg: :yellow, modifiers: [:bold])
        ),
        RatatuiRuby::Text::Span.styled(
          bar,
          RatatuiRuby::Style::Style.new(fg: :dark_gray)
        ),
        RatatuiRuby::Text::Span.styled(
          hint_text,
          RatatuiRuby::Style::Style.new(fg: :dark_gray, modifiers: [:italic])
        )
      ]
    end

    def build_idle_status_spans(_width)
      exchanges = @session.messages.count / 2
      project   = @session.context[:project_name]
      parts     = []

      if project
        parts << RatatuiRuby::Text::Span.styled(
          " #{project}",
          RatatuiRuby::Style::Style.new(fg: :cyan)
        )
        parts << RatatuiRuby::Text::Span.styled(
          " \u2502 ",
          RatatuiRuby::Style::Style.new(fg: :dark_gray)
        )
      end

      parts << RatatuiRuby::Text::Span.styled(
        "#{exchanges} exchanges",
        RatatuiRuby::Style::Style.new(fg: :dark_gray)
      )

      parts << RatatuiRuby::Text::Span.styled(
        " \u2502 ",
        RatatuiRuby::Style::Style.new(fg: :dark_gray)
      )

      parts << RatatuiRuby::Text::Span.styled(
        "PgUp/PgDn scroll \u2502 Enter send \u2502 Esc quit",
        RatatuiRuby::Style::Style.new(fg: :dark_gray)
      )

      parts
    end

    def draw_input(_tui, frame, area)
      border_style = if @state == :waiting
                       RatatuiRuby::Style::Style.new(fg: :yellow)
                     else
                       RatatuiRuby::Style::Style.new(fg: :dark_gray)
                     end

      block = RatatuiRuby::Widgets::Block.new(
        borders: [:all],
        border_type: :rounded,
        border_style: border_style
      )

      display_text = "> #{@input_buffer}"
      paragraph = RatatuiRuby::Widgets::Paragraph.new(
        text: display_text,
        block: block
      )

      frame.render_widget(paragraph, area)

      if @state == :idle
        cursor_x = area.x + 1 + 2 + @cursor_pos  # border(1) + "> "(2) + position
        cursor_y = area.y + 1                       # border(1)
        frame.set_cursor_position(cursor_x, cursor_y)
      end
    end

    # --- Event Handling ---

    def handle_event(event)
      # Always advance spinner tick when waiting (even on Event::None)
      @spinner_tick += 1 if @state == :waiting

      return if event.is_a?(RatatuiRuby::Event::None)
      return unless event.key?

      handle_key_event(event)
    end

    def handle_key_event(event)
      if event.ctrl_c? || event.interrupt?
        if @state == :waiting
          cancel_llm_request
        else
          @running = false
        end
        return
      end

      if event.code == "esc"
        @running = false
        return
      end

      if @state == :waiting
        handle_scroll_key(event)
        return
      end

      case event.code
      when "enter"
        submit_input
      when "backspace"
        if @cursor_pos > 0
          @input_buffer = @input_buffer[0...(@cursor_pos - 1)] + @input_buffer[@cursor_pos..]
          @cursor_pos -= 1
        end
      when "delete"
        if @cursor_pos < @input_buffer.length
          @input_buffer = @input_buffer[0...@cursor_pos] + @input_buffer[(@cursor_pos + 1)..]
        end
      when "left"
        @cursor_pos = [@cursor_pos - 1, 0].max
      when "right"
        @cursor_pos = [@cursor_pos + 1, @input_buffer.length].min
      when "home"
        @cursor_pos = 0
      when "end"
        @cursor_pos = @input_buffer.length
      when "page_up"
        scroll_page_up
      when "page_down"
        scroll_page_down
      when "up"
        scroll_up if event.alt? || event.ctrl?
      when "down"
        scroll_down if event.alt? || event.ctrl?
      else
        if event.text?
          char = event.char
          if char
            @input_buffer = @input_buffer[0...@cursor_pos] + char + @input_buffer[@cursor_pos..]
            @cursor_pos += 1
          end
        end
      end
    end

    def handle_scroll_key(event)
      case event.code
      when "page_up"  then scroll_page_up
      when "page_down" then scroll_page_down
      when "up"        then scroll_up
      when "down"      then scroll_down
      end
    end

    # --- Input Submission ---

    def submit_input
      text = @input_buffer.strip
      return if text.empty?

      @input_buffer = ""
      @cursor_pos   = 0

      if @session.exit_command?(text)
        @running = false
        return
      end

      result = @session.handle_command(text)
      if result[:handled]
        append_system_message(result[:output]) if result[:output]

        if result[:clear_display]
          @display_lines.clear
          @scroll_offset = 0
        end

        launch_async_command(result) if result[:async]
        return
      end

      send_chat_message(text)
    end

    def send_chat_message(text)
      append_user_message(text)

      @state        = :waiting
      @spinner_tick = 0
      @pending_task = :chat
      @llm_thread   = Thread.new do
        @session.chat(text)
      rescue => e
        { text: "**Error**: #{e.message}", guardrail: false }
      end
    end

    def launch_async_command(result)
      @state        = :waiting
      @spinner_tick = 0
      @pending_task = result[:async]

      @llm_thread = Thread.new do
        case result[:async]
        when :summary   then @session.execute_summary
        when :save      then @session.execute_save(*result[:args])
        when :auto_save then @session.execute_auto_save
        end
      rescue => e
        "**Error**: #{e.message}"
      end
    end

    # --- Async LLM Thread Management ---

    def check_llm_thread
      return unless @llm_thread && !@llm_thread.alive?

      result = @llm_thread.value
      @llm_thread = nil
      @state      = :idle

      case @pending_task
      when :chat
        if result.is_a?(Hash)
          append_assistant_message(result[:text])
          if result[:guardrail]
            append_system_message("*Exchange removed from context — you can continue normally.*")
          end
        end
      when :summary
        append_system_message(result) if result.is_a?(String)
      when :save, :auto_save
        if result.is_a?(Array)
          result.each { |msg| append_system_message(msg) }
        elsif result.is_a?(String)
          append_system_message(result)
        end
      end

      @pending_task = nil
      scroll_to_bottom
    end

    def cancel_llm_request
      if @llm_thread&.alive?
        @llm_thread.kill
        @llm_thread = nil
      end

      @state        = :idle
      @pending_task = nil
      append_system_message("*Request cancelled*")
    end

    # --- Message Display ---

    def append_user_message(text)
      @display_lines << RatatuiRuby::Text::Line.new(spans: [])
      @display_lines << RatatuiRuby::Text::Line.new(
        spans: [
          RatatuiRuby::Text::Span.styled(
            "You:",
            RatatuiRuby::Style::Style.new(fg: :cyan, modifiers: [:bold])
          )
        ]
      )
      @display_lines.concat(MarkdownRenderer.render(text))
      scroll_to_bottom
    end

    def append_assistant_message(text)
      @display_lines << RatatuiRuby::Text::Line.new(spans: [])
      @display_lines << RatatuiRuby::Text::Line.new(
        spans: [
          RatatuiRuby::Text::Span.styled(
            "Assistant:",
            RatatuiRuby::Style::Style.new(fg: :green, modifiers: [:bold])
          )
        ]
      )
      @display_lines.concat(MarkdownRenderer.render(text))
      scroll_to_bottom
    end

    def append_system_message(text)
      @display_lines.concat(MarkdownRenderer.render(text))
      scroll_to_bottom
    end

    # --- Scrolling ---

    def scroll_up
      @auto_scroll = false
      @scroll_offset = [@scroll_offset - 1, 0].max
    end

    def scroll_down
      @scroll_offset += 1
      check_auto_scroll
    end

    def scroll_page_up
      @auto_scroll = false
      @scroll_offset = [@scroll_offset - 10, 0].max
    end

    def scroll_page_down
      @scroll_offset += 10
      check_auto_scroll
    end

    def scroll_to_bottom
      @auto_scroll   = true
      @scroll_offset = [(@display_lines.length - 10), 0].max
    end

    def check_auto_scroll
      max_scroll = [(@display_lines.length - 10), 0].max
      @auto_scroll = true if @scroll_offset >= max_scroll
    end
  end
end
