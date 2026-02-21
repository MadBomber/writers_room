# frozen_string_literal: true

require "io/console"
require "reline"

module WritersRoom
  # Terminal chat interface for ChatSession.
  # Prints styled output directly to stdout (terminal scrollback works).
  # Streams LLM responses token by token in single-robot mode.
  # Collects and displays labeled responses in multi-robot mode.
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

    # Color palette for specialist labels (bold variants)
    SPECIALIST_COLORS = [
      "\e[1;32m", # Green bold
      "\e[1;33m", # Yellow bold
      "\e[1;35m", # Magenta bold
      "\e[1;34m", # Blue bold
      "\e[1;31m", # Red bold
      "\e[1;36m", # Cyan bold
    ].freeze

    HISTORY_MAX = 500

    # @param session [ChatSession] business logic handler for commands
    # @param chat_room [ChatRoom, nil] multi-robot chat room (nil for single-robot)
    def initialize(session, chat_room: nil)
      @session    = session
      @chat_room  = chat_room
      @multi_robot = !chat_room.nil?
      @specialist_color_map = {}
      @color_index = 0
      @history_path = resolve_history_path

      assign_specialist_colors if @multi_robot
    end

    def run
      @session.log_session_start
      load_history

      print_styled(@session.welcome_text)

      if @multi_robot
        print_specialist_roster
      else
        ctx = @session.context_text
        print_styled(ctx) unless ctx.empty?
      end

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

        begin
          if @multi_robot
            send_multi_robot_message(text)
          else
            send_streaming_message(text)
          end
        rescue Interrupt
          puts
          print_dim("  Cancelled")
          puts
        rescue => e
          puts
          print_dim("  Error: #{e.message}")
          puts
          @session.logger.error("CHAT ERROR: #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        end
      end

      puts
      print_dim(@session.goodbye_text)
      puts
      save_history
      @session.log_session_end
      @session.messages
    end

    private

    # --- Input ---

    def read_input
      # Wrap ANSI escapes in \001..\002 so Reline doesn't count them as visible
      # characters — prevents cursor positioning bugs.
      label = @multi_robot ? "You: " : "> "
      prompt = "\001#{ANSI[:cyan]}\002\001#{ANSI[:bold]}\002#{label}\001#{ANSI[:reset]}\002"
      $stdout.flush
      line = Reline.readline(prompt, false)
      return nil if line.nil?

      stripped = line.strip
      unless stripped.empty?
        Reline::HISTORY.push(stripped)
      end
      stripped
    end

    # --- History Persistence ---

    def resolve_history_path
      if @session.project_path
        File.join(@session.project_path, ".wr_chat_history")
      else
        dir = File.join(Dir.home, ".writers_room")
        File.join(dir, "chat_history")
      end
    end

    def load_history
      return unless @history_path && File.exist?(@history_path)

      File.readlines(@history_path, chomp: true).last(HISTORY_MAX).each do |line|
        Reline::HISTORY.push(line)
      end
    rescue StandardError
      # History is non-critical; silently ignore errors
    end

    def save_history
      return unless @history_path

      require "fileutils"
      FileUtils.mkdir_p(File.dirname(@history_path))

      entries = Reline::HISTORY.to_a.last(HISTORY_MAX)
      File.write(@history_path, entries.join("\n") + "\n")
    rescue StandardError
      # History is non-critical; silently ignore errors
    end

    # --- Multi-Robot Chat ---

    def print_specialist_roster
      roster = @chat_room.specialist_roster
      puts
      puts "#{ANSI[:yellow]}#{ANSI[:bold]}Writers' Room Specialists:#{ANSI[:reset]}"
      puts

      roster.each do |spec|
        color = color_for_specialist(spec[:id])
        puts "  #{color}#{spec[:label]}#{ANSI[:reset]} (#{ANSI[:dim]}@#{spec[:id]}#{ANSI[:reset]}) — #{spec[:description]}"
        puts "    #{ANSI[:dim]}Domains: #{spec[:domains].join(', ')}#{ANSI[:reset]}"
      end

      puts
      print_dim("  Tip: Use @specialist_id to address a specialist directly")
      puts
    end

    def send_multi_robot_message(text)
      @session.messages << { role: "user", content: text }
      @session.logger.info("USER: #{text}")

      # No echo needed — Reline prompt already showed "You: text"
      puts

      responses = nil

      with_spinner("Writers' room is thinking") do
        responses = @chat_room.send_user_message(text)
      end

      if responses.nil? || responses.empty?
        print_dim("  No response from the writers' room.")
        puts
        return
      end

      render_round_responses(responses)
      $stdout.flush

      # Record all responses as a single assistant message for session history
      combined = responses.map { |r| "[#{r[:label]}]: #{r[:content]}" }.join("\n\n")
      @session.messages << { role: "assistant", content: combined }
      @session.logger.info("ROUND: #{responses.length} response(s)")

      print_multi_status_line
    rescue => e
      puts
      print_dim("  Error: #{e.message}")
      puts
      @session.logger.error("MULTI-ROBOT ERROR: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
    end

    def render_round_responses(responses)
      responses.each do |resp|
        color = color_for_specialist(resp[:from])
        label = resp[:label] || resp[:from]

        puts "#{color}#{ANSI[:bold]}#{label}:#{ANSI[:reset]}"
        puts render_ansi(resp[:content].to_s)
        puts
        $stdout.flush
      end
    end

    def assign_specialist_colors
      return unless @chat_room

      # Showrunner gets its own color
      @specialist_color_map["showrunner"] = "\e[1;37m" # White bold

      @chat_room.specialist_roster.each do |spec|
        @specialist_color_map[spec[:id]] = SPECIALIST_COLORS[@color_index % SPECIALIST_COLORS.length]
        @color_index += 1
      end
    end

    def color_for_specialist(id)
      @specialist_color_map[id.to_s] || SPECIALIST_COLORS[0]
    end

    def print_specialist_help
      roster = @chat_room.specialist_roster
      puts
      puts "#{ANSI[:yellow]}#{ANSI[:bold]}  Specialists#{ANSI[:reset]}"
      puts
      roster.each do |spec|
        color = color_for_specialist(spec[:id])
        puts "  #{color}@#{spec[:id]}#{ANSI[:reset]} — #{spec[:description]}"
      end
      puts
      print_dim("  Address a specialist directly with @id at the start of your message.")
    end

    def print_multi_status_line
      exchanges = @session.messages.count { |m| m[:role] == "user" }
      print_dim("  #{exchanges} round#{"s" unless exchanges == 1}")
    end

    # --- Streaming Chat (single-robot mode) ---

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
            spinner_thread.kill
            spinner_thread.join(1)
            clear_spinner
            spinner_cleared = true
          end

          print delta
          $stdout.flush
          full_response += delta
        end
      rescue Interrupt
        unless spinner_cleared
          spinner_thread.kill
          spinner_thread.join(1)
          clear_spinner
        end
        puts
        print_dim("  Cancelled")
        puts
        @session.messages.pop # remove the user message we added
        return
      ensure
        unless spinner_cleared
          spinner_thread.kill
          spinner_thread.join(1)
          clear_spinner
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
        print_specialist_help if @multi_robot && result[:output].include?("Commands")
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
        thread.join(1) # Wait for spinner thread to actually stop
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
      table_rows = []

      lines.each do |raw|
        # Flush collected table rows when we hit a non-table line
        if table_rows.any? && !raw.strip.match?(/\A\|.*\|\s*\z/)
          result.concat(render_ansi_table(table_rows))
          table_rows = []
        end

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

        # Collect table rows for grouped rendering with alignment
        if raw.strip.match?(/\A\|.*\|\s*\z/)
          table_rows << raw.strip
          next
        end

        result << render_ansi_line(raw)
      end

      # Flush remaining
      result.concat(render_ansi_table(table_rows)) if table_rows.any?
      code_lines.each { |cl| result << "  #{ANSI[:light_green]}#{cl}#{ANSI[:reset]}" }

      result.join("\n")
    end

    def render_ansi_line(raw)
      stripped = raw.strip

      case stripped
      when /\A(---|___|\*\*\*)\s*\z/
        "#{ANSI[:dark_gray]}#{"─" * terminal_width}#{ANSI[:reset]}"
      when /\A####+(.*)/
        "#{ANSI[:cyan]}#{inline_ansi($1.strip)}#{ANSI[:reset]}"
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
      when /\A\s*(\d+)\.\s+(.*)/
        "  #{$1}. #{inline_ansi($2)}"
      else
        inline_ansi(stripped)
      end
    end

    # Render a group of table rows with aligned columns and capped widths.
    def render_ansi_table(rows)
      parsed = rows.map { |row| row.split("|").map(&:strip).reject(&:empty?) }
      return [] if parsed.empty?

      max_cols = parsed.map(&:length).max
      separator_indices = parsed.each_index.select do |i|
        parsed[i].all? { |c| c.match?(/\A[-:]+\z/) }
      end

      # Calculate column widths from plain text (no markdown markup)
      col_widths = Array.new(max_cols, 0)
      parsed.each_with_index do |cells, i|
        next if separator_indices.include?(i)
        cells.each_with_index do |cell, j|
          col_widths[j] = [strip_markdown(cell).length, col_widths[j]].max
        end
      end

      # Cap column widths to fit terminal
      available = terminal_width - (max_cols * 3) - 1
      cap = [available / [max_cols, 1].max, 10].max
      col_widths = col_widths.map { |w| [w, cap].min }

      result = []
      parsed.each_with_index do |cells, i|
        if separator_indices.include?(i)
          line = col_widths.map { |w| "─" * (w + 2) }.join("┼")
          result << "#{ANSI[:dark_gray]}#{line}#{ANSI[:reset]}"
        else
          rendered = cells.each_with_index.map do |cell, j|
            fit_table_cell(cell, col_widths[j] || 10)
          end
          result << " #{rendered.join(" #{ANSI[:dark_gray]}│#{ANSI[:reset]} ")}"
        end
      end

      result
    end

    # Fit a table cell to a target width: truncate if too long, pad if too short.
    # Applies inline_ansi for bold/italic/code rendering within cells.
    def fit_table_cell(cell, width)
      plain = strip_markdown(cell)
      if plain.length > width
        # Truncate to fit — use plain text to avoid breaking markdown
        inline_ansi(plain[0, width - 1] + "…")
      elsif plain.length < width
        padding = width - plain.length
        inline_ansi(cell) + " " * padding
      else
        inline_ansi(cell)
      end
    end

    # Strip markdown formatting to get plain text for width measurement.
    def strip_markdown(text)
      text.gsub(/\*\*(.+?)\*\*/, '\1')
          .gsub(/\*(.+?)\*/, '\1')
          .gsub(/`([^`]+)`/, '\1')
          .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
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
