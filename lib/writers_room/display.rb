# frozen_string_literal: true

module WritersRoom
  # Terminal output formatting for scene direction.
  # Per-character color rotation, optional file logging.
  class Display
    COLORS = [
      "\e[1;36m", # Cyan bold
      "\e[1;32m", # Green bold
      "\e[1;33m", # Yellow bold
      "\e[1;35m", # Magenta bold
      "\e[1;34m", # Blue bold
      "\e[1;31m", # Red bold
    ].freeze

    DIRECTOR_COLOR = "\e[0;37m"   # White
    INFO_COLOR     = "\e[0;90m"   # Gray
    RESET          = "\e[0m"

    # @param log_path [String, nil] optional file path for logging
    # @param color [Boolean] enable ANSI colors (default: auto-detect TTY)
    def initialize(log_path: nil, color: $stdout.tty?)
      @color = color
      @character_colors = {}
      @color_index = 0
      @log_file = log_path ? File.open(log_path, "a") : nil
    end

    # Display character dialog.
    #
    # @param from [String] character name
    # @param text [String] dialog content
    # @param emotion [String, nil] optional emotional tag
    def dialog(from, text, emotion: nil)
      color = color_for(from)
      emotion_tag = emotion ? " [#{emotion}]" : ""
      line = "#{from}#{emotion_tag}: #{text}"

      puts colorize(color, line)
      log(line)
    end

    # Display a director note (stage direction).
    #
    # @param text [String] director note
    def director_note(text)
      line = "[DIRECTOR: #{text}]"
      puts colorize(DIRECTOR_COLOR, line)
      log(line)
    end

    # Display scene header.
    #
    # @param info [Hash] scene metadata
    def scene_header(info)
      number = info[:scene_number] || info["scene_number"]
      name   = info[:scene_name]   || info["scene_name"]
      loc    = info[:location]     || info["location"]
      chars  = info[:characters]   || info["characters"] || []

      text = <<~HEADER

        #{"=" * 60}
        SCENE #{number}: #{name}
        Location: #{loc}
        Characters: #{Array(chars).join(', ')}
        #{"=" * 60}

      HEADER

      puts colorize("\e[1;36m", text)
      log(text)
    end

    # Display a banner message.
    #
    # @param text [String] banner text
    def banner(text)
      bar = "=" * 60
      puts colorize("\e[1;36m", "\n#{bar}\n#{text}\n#{bar}\n")
      log("#{bar}\n#{text}\n#{bar}")
    end

    # Display a separator line.
    def separator
      line = "-" * 60
      puts colorize(INFO_COLOR, line)
      log(line)
    end

    # Display info text (gray).
    #
    # @param text [String] informational message
    def info(text)
      puts colorize(INFO_COLOR, text)
      log(text)
    end

    # Display scene statistics.
    #
    # @param stats [Hash] statistics hash
    def stats(stats)
      puts colorize("\e[1;36m", "\n#{'=' * 60}")
      puts colorize("\e[1;36m", "SCENE STATISTICS")
      puts colorize("\e[1;36m", "=" * 60)
      puts "Total lines: #{stats[:total_lines]}"
      puts "\nLines by character:"

      (stats[:lines_by_character] || {}).sort_by { |_, count| -count }.each do |char, count|
        puts "  #{char}: #{count}"
      end

      puts colorize("\e[1;36m", "=" * 60)
    end

    # Display an incoming message notification (for bus debugging).
    #
    # @param to [String] receiver name
    # @param from [String] sender name
    # @param content [String] message content
    def incoming(to, from, content)
      line = "[#{from} -> #{to}] #{content.to_s[0..80]}"
      log(line)
    end

    # Display a memory write notification.
    #
    # @param writer [String] who wrote
    # @param key [String] memory key
    def memory_write(writer, key)
      line = "[MEMORY] #{writer} wrote :#{key}"
      puts colorize(INFO_COLOR, line)
      log(line)
    end

    # Display broadcast message.
    #
    # @param from [String] sender
    # @param message [String] content
    def broadcast(from, message)
      dialog(from, message)
    end

    # Display scene completion.
    #
    # @param who [String] who marked it complete
    def complete(who)
      line = "[COMPLETE] Scene marked complete by #{who}"
      puts colorize("\e[1;32m", line)
      log(line)
    end

    # Close the log file if open.
    def close
      @log_file&.close
    end

    private

    def color_for(character)
      @character_colors[character] ||= begin
        c = COLORS[@color_index % COLORS.length]
        @color_index += 1
        c
      end
    end

    def colorize(code, text)
      return text unless @color

      "#{code}#{text}#{RESET}"
    end

    def log(text)
      return unless @log_file

      @log_file.puts("[#{Time.now.strftime('%H:%M:%S')}] #{text}")
      @log_file.flush
    end
  end
end
