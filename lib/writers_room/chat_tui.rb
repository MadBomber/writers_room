# frozen_string_literal: true

require "io/console"

module WritersRoom
  # Terminal chat interface for ChatSession.
  # Prints styled output directly to stdout (terminal scrollback works).
  # Streams LLM responses token by token.
  # Input and status stay at the bottom of the terminal.
  class ChatTui
    SPINNER_FRAMES = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze

    ANSI = {
      reset:       "\e[0m",
      bold:        "\e[1m",
      dim:         "\e[2m",
      italic:      "\e[3m",
      underline:   "\e[4m",
      red:         "\e[31m",
      green:       "\e[32m",
      yellow:      "\e[33m",
      blue:        "\e[34m",
      magenta:     "\e[35m",
      cyan:        "\e[36m",
      dark_gray:   "\e[90m",
      light_green: "\e[92m",
      light_blue:  "\e[94m",
    }.freeze

    def initialize(session)
      @session = session
    end

    def run
      @session.log_session_start

      print_styled(@session.welcome_text)
      ctx = @session.context_text
      print_styled(ctx) unless ctx.empty?
      puts

      loop do
        text = read_input
        break if text.nil?
        break if @session.exit_command?(text)
        next  if text.empty?

        result = @session.handle_command(text)
        if result[:handled]
          handle_command_result(result)
          next
        end

        send_streaming_message(text)
      end

      puts
      print_dim(@session.goodbye_text)
      puts
      @session.log_session_end
      @session.messages
    end

    private

    # --- Input ---

    def read_input
      print "#{ANSI[:cyan]}#{ANSI[:bold]}> #{ANSI[:reset]}"
      $stdout.flush
      line = $stdin.gets
      return nil if line.nil?
      line.chomp.strip
    end

    # --- Streaming Chat ---

    def send_streaming_message(text)
      @session.messages << { role: "user", content: text }
      @session.logger.info("USER: #{text}")

      print_user_label
      puts text
      puts

      print_assistant_label

      # Stream the response token by token
      full_response = ""
      spinner_cleared = false
      spinner_thread  = start_spinner

      begin
        @session.robot.ask(text) do |chunk|
          delta = chunk.content
          next unless delta

          unless spinner_cleared
            clear_spinner
            spinner_thread.kill
            spinner_cleared = true
          end

          print delta
          $stdout.flush
          full_response += delta
        end
      rescue Interrupt
        unless spinner_cleared
          clear_spinner
          spinner_thread.kill
        end
        puts
        print_dim("  Cancelled")
        puts
        @session.messages.pop # remove the user message we added
        return
      ensure
        unless spinner_cleared
          clear_spinner
          spinner_thread.kill
        end
      end

      puts
      puts

      @session.messages << { role: "assistant", content: full_response }
      @session.logger.info("ASSISTANT: #{full_response}")

      if guardrail_refusal?(full_response)
        @session.logger.warn("GUARDRAIL: refusal detected, removing exchange from context")
        @session.messages.pop(2)
        print_dim("  Exchange removed from context — you can continue normally.")
        puts
      end

      print_status_line
    end

    # --- Command Handling ---

    def handle_command_result(result)
      if result[:clear_display]
        # Can't clear terminal scrollback, but we can print a separator
        puts
        print_dim("--- conversation cleared ---")
        puts
      end

      if result[:output]
        print_styled(result[:output])
        puts
      end

      if result[:async]
        execute_async_command(result)
      end
    end

    def execute_async_command(result)
      case result[:async]
      when :summary
        with_spinner("Summarizing") do
          output = @session.execute_summary
          print_styled(output)
          puts
        end
      when :save
        with_spinner("Saving") do
          outputs = @session.execute_save(*result[:args])
          outputs.each { |msg| print_styled(msg); puts }
        end
      when :save_last
        with_spinner("Saving") do
          outputs = @session.execute_save_last
          outputs.each { |msg| print_styled(msg); puts }
        end
      when :auto_save
        with_spinner("Analyzing") do
          outputs = @session.execute_auto_save
          outputs.each { |msg| print_styled(msg); puts }
        end
      end
    end

    # --- Spinner ---

    def start_spinner
      Thread.new do
        i = 0
        loop do
          frame = SPINNER_FRAMES[i % SPINNER_FRAMES.length]
          print "\r#{ANSI[:yellow]}#{ANSI[:bold]}  #{frame} #{ANSI[:reset]}#{ANSI[:dim]}thinking...#{ANSI[:reset]}"
          $stdout.flush
          sleep 0.08
          i += 1
        end
      end
    end

    def clear_spinner
      print "\r\e[2K"  # carriage return + clear entire line
      $stdout.flush
    end

    def with_spinner(label)
      thread = Thread.new do
        i = 0
        loop do
          frame = SPINNER_FRAMES[i % SPINNER_FRAMES.length]
          print "\r#{ANSI[:yellow]}#{ANSI[:bold]}  #{frame} #{ANSI[:reset]}#{ANSI[:dim]}#{label}...#{ANSI[:reset]}"
          $stdout.flush
          sleep 0.08
          i += 1
        end
      end

      begin
        yield
      ensure
        thread.kill
        clear_spinner
      end
    end

    # --- Styled Output ---

    def print_user_label
      print "#{ANSI[:cyan]}#{ANSI[:bold]}You: #{ANSI[:reset]}"
    end

    def print_assistant_label
      print "#{ANSI[:green]}#{ANSI[:bold]}Assistant: #{ANSI[:reset]}"
      puts
    end

    def print_dim(text)
      puts "#{ANSI[:dim]}#{text}#{ANSI[:reset]}"
    end

    def print_status_line
      exchanges = @session.messages.count / 2
      print_dim("  #{exchanges} exchange#{"s" unless exchanges == 1}")
    end

    def print_styled(markdown)
      return if markdown.nil? || markdown.strip.empty?

      puts render_ansi(markdown)
    end

    # --- ANSI Markdown Rendering ---

    def render_ansi(markdown)
      lines = markdown.lines.map(&:chomp)
      result = []
      in_code = false
      code_lines = []

      lines.each do |raw|
        if in_code
          if raw.strip.start_with?("```")
            code_lines.each { |cl| result << "  #{ANSI[:light_green]}#{cl}#{ANSI[:reset]}" }
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

        result << render_ansi_line(raw)
      end

      # Unclosed code block
      code_lines.each { |cl| result << "  #{ANSI[:light_green]}#{cl}#{ANSI[:reset]}" }

      result.join("\n")
    end

    def render_ansi_line(raw)
      stripped = raw.strip

      case stripped
      when /\A(---|___|\*\*\*)\s*\z/
        "#{ANSI[:dark_gray]}#{"─" * terminal_width}#{ANSI[:reset]}"
      when /\A###\s+(.*)/
        "#{ANSI[:cyan]}#{ANSI[:bold]}#{inline_ansi($1)}#{ANSI[:reset]}"
      when /\A##\s+(.*)/
        "#{ANSI[:yellow]}#{ANSI[:bold]}#{inline_ansi($1)}#{ANSI[:reset]}"
      when /\A#\s+(.*)/
        "#{ANSI[:yellow]}#{ANSI[:bold]}#{inline_ansi($1)}#{ANSI[:reset]}"
      when /\A>\s?(.*)/
        "#{ANSI[:dark_gray]}#{ANSI[:italic]}  │ #{inline_ansi($1)}#{ANSI[:reset]}"
      when /\A\s*[-*+]\s+(.*)/
        "  • #{inline_ansi($1)}"
      when /\A\s*\d+\.\s+(.*)/
        "  • #{inline_ansi($1)}"
      when /\A\|.*\|\s*\z/
        render_ansi_table_row(stripped)
      else
        inline_ansi(stripped)
      end
    end

    def render_ansi_table_row(raw)
      cells = raw.split("|").map(&:strip).reject(&:empty?)

      if cells.all? { |c| c.match?(/\A[-:]+\z/) }
        "#{ANSI[:dark_gray]}#{cells.map { |c| "─" * [c.length, 3].max }.join("─┼─")}#{ANSI[:reset]}"
      else
        cells.join(" │ ")
      end
    end

    def inline_ansi(text)
      return "" if text.nil? || text.empty?

      text
        .gsub(/\*\*(.+?)\*\*/)  { "#{ANSI[:bold]}#{$1}#{ANSI[:reset]}" }
        .gsub(/\*(.+?)\*/)      { "#{ANSI[:italic]}#{$1}#{ANSI[:reset]}" }
        .gsub(/`([^`]+)`/)       { "#{ANSI[:light_green]}#{$1}#{ANSI[:reset]}" }
        .gsub(/\[([^\]]+)\]\([^)]+\)/) { "#{ANSI[:light_blue]}#{ANSI[:underline]}#{$1}#{ANSI[:reset]}" }
    end

    def terminal_width
      IO.console&.winsize&.last || 80
    end

    # --- Guardrail ---

    REFUSAL_PATTERNS = ChatSession::REFUSAL_PATTERNS

    def guardrail_refusal?(message)
      return false if message.nil? || message.length > 500
      REFUSAL_PATTERNS.any? { |pat| message.match?(pat) }
    end
  end
end
