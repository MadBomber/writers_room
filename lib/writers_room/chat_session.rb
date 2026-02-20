# frozen_string_literal: true


require "io/console"
require "logger"

module WritersRoom
  # Interactive chat session with LLM for creative consultation.
  # Uses LLMSetup for shared configuration instead of duplicating setup.
  class ChatSession
    attr_reader :robot, :context, :messages, :logger

    # @param context [Hash] conversation context (project info, task, etc.)
    # @param template [Symbol, nil] optional RobotLab template for the session
    # @param project_path [String, nil] path to the WritersRoom project for saving elements
    def initialize(context: {}, template: nil, project_path: nil)
      @context      = context
      @template     = template
      @project_path = project_path
      @messages     = []
      @glow_available = system("which glow > /dev/null 2>&1")
      setup_logger
      setup_robot
    end

    # Start an interactive chat session
    def start
      log_session_start
      display_welcome
      display_context

      loop do
        print "\n> "
        user_input = STDIN.gets&.chomp

        break if exit_command?(user_input)
        next if user_input.nil? || user_input.strip.empty?

        handle_command(user_input) || chat(user_input)
      end

      display_goodbye
      log_session_end
      @messages
    end

    # Chat with a single message (non-interactive)
    def chat(user_message)
      @messages << { role: "user", content: user_message }
      @logger.info("USER: #{user_message}")

      result = @robot.run(user_message)
      assistant_message = result.reply || ""

      @messages << { role: "assistant", content: assistant_message }
      @logger.info("ASSISTANT: #{assistant_message}")

      if guardrail_refusal?(assistant_message)
        # Log it but remove from LLM context so future messages aren't poisoned
        @logger.warn("GUARDRAIL: refusal detected, removing exchange from context")
        @messages.pop(2)
        render(assistant_message)
        render("*Exchange removed from context — you can continue normally.*")
      else
        render(assistant_message)
      end

      assistant_message
    end

    # Get the conversation summary
    def summary
      return "No conversation yet." if @messages.empty?

      @robot.update(system_prompt: build_system_prompt)
      result = @robot.run(
        "Please provide a concise summary of our conversation and any key decisions or ideas that emerged."
      )

      result.reply || "Unable to generate summary."
    end

    # Save conversation to file
    def save(filepath)
      require "fileutils"

      FileUtils.mkdir_p(File.dirname(filepath))

      content = "# Chat Session: #{Time.now}\n\n"
      content += "## Context\n\n"
      @context.each do |key, value|
        content += "- **#{key}**: #{value}\n"
      end
      content += "\n## Conversation\n\n"

      @messages.each do |msg|
        if msg[:role] == "user"
          content += "**You**: #{msg[:content]}\n\n"
        else
          content += "**Assistant**: #{msg[:content]}\n\n"
        end
      end

      content += "\n## Summary\n\n#{summary}\n"

      File.write(filepath, content)
      filepath
    end

    private

    # Render markdown text through glow, falling back to plain puts.
    def render(text)
      return puts(text) unless @glow_available && STDOUT.tty?

      IO.popen(["glow", "-w", terminal_width.to_s], "w") do |io|
        io.write(text)
      end
    rescue Errno::ENOENT, Errno::EPIPE
      puts text
    end

    def terminal_width
      IO.console&.winsize&.last || 80
    end

    def setup_logger
      if @project_path
        log_path = File.join(@project_path, "wr.log")
        @logger = Logger.new(log_path, "weekly")
        @logger.formatter = proc { |severity, datetime, _progname, msg|
          "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
        }
      else
        @logger = Logger.new(File::NULL)
      end
    end

    def log_session_start
      @logger.info("=" * 60)
      @logger.info("Session started")
      @context.each do |key, value|
        next if key == :additional || key == :existing_elements
        @logger.info("  #{key}: #{value}")
      end
      @logger.info("=" * 60)
    end

    def log_session_end
      @logger.info("Session ended — #{@messages.count / 2} exchanges")
      @logger.info("=" * 60)
    end

    def setup_robot
      run_config = LLMSetup.build_run_config
      tools = @project_path ? build_file_tools : []

      if @template
        @robot = RobotLab.build(
          name: "chat_session",
          template: @template,
          context: @context,
          config: run_config,
          local_tools: tools
        )
      else
        @robot = RobotLab.build(
          name: "chat_session",
          system_prompt: build_system_prompt,
          config: run_config,
          local_tools: tools
        )
      end
      tool_names = tools.map(&:name).join(", ")
      @logger.info("Robot configured: template=#{@template || 'none'}, tools=#{tool_names}")
    end

    def build_file_tools
      [
        ReadFileTool.new(project_path: @project_path),
        WriteFileTool.new(project_path: @project_path),
        ListDirectoryTool.new(project_path: @project_path)
      ]
    end

    def build_system_prompt
      prompt = <<~SYSTEM
        You are a creative consultant helping to develop a WritersRoom project.
        You should provide thoughtful, creative suggestions and help flesh out ideas.

        Be conversational and collaborative. Ask clarifying questions when needed.
        Provide specific, actionable suggestions.
      SYSTEM

      if @context[:project_name]
        prompt += "\n\nProject: #{@context[:project_name]}"
      end

      if @context[:project_concept]
        prompt += "\nProject Concept: #{@context[:project_concept]}"
      end

      if @context[:task]
        prompt += "\n\nCurrent Task: #{@context[:task]}"
      end

      if @context[:subject]
        prompt += "\nSubject: #{@context[:subject]}"
      end

      if @context[:additional]
        prompt += "\n\nAdditional Context:\n#{@context[:additional]}"
      end

      prompt
    end

    def display_welcome
      render <<~WELCOME
        # WritersRoom Chat Session

        Starting interactive chat with LLM...
        Type your questions or ideas. Type `exit` or `quit` to end.
        Type `help` for available commands.
      WELCOME
    end

    def display_context
      return if @context.empty?

      lines = ["## Context\n"]
      @context.each do |key, value|
        next if key == :additional
        lines << "- **#{key}**: #{value}"
      end

      render(lines.join("\n"))
    end

    def display_goodbye
      render <<~GOODBYE
        ---

        **Chat session ended** — #{@messages.count / 2} exchanges
      GOODBYE
    end

    REFUSAL_PATTERNS = [
      /\bI can't help with that\b/i,
      /\bI cannot help with that\b/i,
      /\bI'm not able to help with that\b/i,
      /\bI'm unable to\b/i,
      /\bI cannot assist with\b/i,
      /\bI can't assist with\b/i,
      /\bI cannot provide\b/i,
      /\bI can't provide\b/i,
      /\bI'm sorry.{0,20}(can't|cannot|won't|unable)\b/i,
      /\bagainst my (guidelines|policy|programming)\b/i,
      /\bnot appropriate for me to\b/i,
      /\bI must (decline|refuse)\b/i
    ].freeze

    def guardrail_refusal?(message)
      return false if message.nil? || message.length > 500
      REFUSAL_PATTERNS.any? { |pat| message.match?(pat) }
    end

    def exit_command?(input)
      return false if input.nil?
      %w[exit quit q bye].include?(input.strip.downcase)
    end

    def handle_command(input)
      stripped = input.strip
      lowered  = stripped.downcase

      case lowered
      when "help"
        @logger.info("COMMAND: help")
        show_help
        true
      when "context"
        @logger.info("COMMAND: context")
        display_context
        true
      when "summary"
        @logger.info("COMMAND: summary")
        render("\n## Summary\n\n#{summary}")
        true
      when "clear"
        @logger.info("COMMAND: clear")
        @messages.clear
        render("*Conversation cleared*")
        true
      when /\Asave\s+(\w+)\s+(.+)\z/
        @logger.info("COMMAND: save #{$1} #{$2.strip}")
        handle_save($1, $2.strip)
        true
      when "save"
        @logger.info("COMMAND: save (auto-detect)")
        handle_auto_save
        true
      else
        false
      end
    end

    def show_help
      render <<~HELP
        ## Commands

        | Command | Description |
        |---------|-------------|
        | `save <type> <name>` | Save discussed content as an element |
        | `save` | Auto-detect what was discussed and save it |
        | `help` | Show this help |
        | `context` | Show current context |
        | `summary` | Get conversation summary |
        | `clear` | Clear conversation history |
        | `exit` | End chat session (also: `quit`, `q`, `bye`) |

        **Examples:**
        - `save character Alice`
        - `save chapter The Beginning`

        Otherwise, just type your message to chat with the LLM.
      HELP
    end

    def handle_save(element_type, name)
      unless @project_path
        @logger.warn("Save failed: no project context")
        render("**No project context** — cannot save elements.")
        return
      end

      if @messages.empty?
        @logger.warn("Save failed: no conversation yet")
        render("**Nothing discussed yet** — have a conversation first.")
        return
      end

      @logger.info("Extracting #{element_type} details for '#{name}'")
      render("*Extracting #{element_type} details for '#{name}'...*")

      extraction_prompt = <<~PROMPT
        Based on our conversation, extract the key details for a #{element_type} named "#{name}".

        Respond with ONLY the following format, no other text:

        NAME: #{name}
        PREVIOUS_NAMES: comma-separated list of any earlier names this #{element_type} was known by during our conversation, or NONE
        ALIASES: comma-separated list of alternate names/nicknames, or NONE
        STATUS: draft
        ---BODY---
        Write a concise profile/description based on what we discussed. Include all important details: personality, background, motivation, relationships, or any other relevant information we covered. Use plain prose, not bullet points.
      PROMPT

      result = @robot.run(extraction_prompt)
      reply = result.reply || ""
      @logger.debug("LLM extraction response:\n#{reply}")

      parsed = parse_extraction(reply, name)
      @logger.info("Parsed extraction: name=#{parsed[:name]}, aliases=#{parsed[:aliases].inspect}, status=#{parsed[:status]}, body_length=#{parsed[:body].length}")
      save_element(element_type, parsed)
    end

    def handle_auto_save
      unless @project_path
        @logger.warn("Auto-save failed: no project context")
        render("**No project context** — cannot save elements.")
        return
      end

      if @messages.empty?
        @logger.warn("Auto-save failed: no conversation yet")
        render("**Nothing discussed yet** — have a conversation first.")
        return
      end

      @logger.info("Auto-detecting elements to save")
      render("*Analyzing conversation to determine what to save...*")

      detection_prompt = <<~PROMPT
        Based on our conversation, what story elements did we discuss or develop?

        Respond with ONLY lines in this format, one per element. No other text:
        TYPE: NAME

        Where TYPE is one of: character, chapter, scene, location, setting, arc, relationship, theme
        And NAME is the element name.

        If we discussed multiple elements, list each on its own line.
        Only include elements where we developed meaningful content worth saving.
      PROMPT

      result = @robot.run(detection_prompt)
      reply = result.reply || ""

      elements = reply.strip.lines.filter_map { |line|
        if line =~ /\A\s*(\w+):\s*(.+)/i
          [$1.strip.downcase, $2.strip]
        end
      }

      if elements.empty?
        render <<~MSG
          **Could not detect any elements** to save from the conversation.

          Try: `save <type> <name>` (e.g. `save character Alice`)
        MSG
        return
      end

      lines = ["Found **#{elements.size}** element(s) to save:\n"]
      elements.each { |type, name| lines << "- #{type}: **#{name}**" }
      render(lines.join("\n"))

      elements.each do |type, name|
        handle_save(type, name)
      end
    end

    def parse_extraction(reply, default_name)
      lines = reply.strip.lines.map(&:strip)

      name           = default_name
      previous_names = []
      aliases        = []
      status         = "draft"
      body           = ""

      in_body = false

      lines.each do |line|
        if in_body
          body += "#{line}\n"
        elsif line =~ /\A---BODY---\z/i
          in_body = true
        elsif line =~ /\ANAME:\s*(.+)/i
          name = $1.strip
        elsif line =~ /\APREVIOUS_NAMES?:\s*(.+)/i
          raw = $1.strip
          previous_names = raw.downcase == "none" ? [] : raw.split(",").map(&:strip)
        elsif line =~ /\AALIASES:\s*(.+)/i
          raw = $1.strip
          aliases = raw.downcase == "none" ? [] : raw.split(",").map(&:strip)
        elsif line =~ /\ASTATUS:\s*(.+)/i
          status = $1.strip.downcase
        end
      end

      { name: name, previous_names: previous_names, aliases: aliases, status: status, body: body.strip }
    end

    def save_element(element_type, parsed)
      # Resolve the correct directory for this element type
      dir = resolve_element_dir(element_type)

      slug = Element.sanitize(parsed[:name])
      path = File.join(dir, "#{slug}.md")

      metadata = { "name" => parsed[:name], "status" => parsed[:status] }
      metadata["aliases"] = parsed[:aliases] if parsed[:aliases].any?

      # Check for rename: look for an existing file under a previous name
      old_path = find_existing_element(dir, parsed)

      if old_path && old_path != path
        # Rename: update content and move file
        el = Element.load(old_path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, parsed[:body]) unless parsed[:body].empty?
        el.instance_variable_set(:@path, path)
        el.instance_variable_set(:@slug, slug)
        el.save
        File.delete(old_path)
        @logger.info("Renamed #{element_type}: #{File.basename(old_path, '.md')} -> #{parsed[:name]} (#{path})")
        render("**Renamed** #{element_type}: #{File.basename(old_path, '.md')} -> #{parsed[:name]} (`#{path}`)")
      elsif File.exist?(path)
        # Update existing element in place
        el = Element.load(path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, parsed[:body]) unless parsed[:body].empty?
        el.save
        @logger.info("Updated #{element_type}: #{parsed[:name]} -> #{path}")
        render("**Updated** #{element_type}: #{parsed[:name]} (`#{path}`)")
      else
        # Create new element
        FileUtils.mkdir_p(dir)
        content = FrontMatter.dump(metadata, parsed[:body])
        File.write(path, content)
        @logger.info("Created #{element_type}: #{parsed[:name]} -> #{path}")
        render("**Created** #{element_type}: #{parsed[:name]} (`#{path}`)")
      end
    rescue StandardError => e
      @logger.error("Error saving #{element_type} '#{parsed[:name]}': #{e.message}")
      render("**Error** saving #{element_type}: #{e.message}")
    end

    def find_existing_element(dir, parsed)
      return nil unless Dir.exist?(dir)

      collection = ElementCollection.new(dir)

      # Search by previous names first (explicit rename)
      parsed[:previous_names]&.each do |prev_name|
        el = collection.find_by_name_or_alias(prev_name)
        return el.path if el
      end

      # Also search by the current name in case the slug differs
      # (e.g. existing file was created with a slightly different sanitization)
      el = collection.find_by_name_or_alias(parsed[:name])
      return el.path if el

      nil
    end

    def resolve_element_dir(element_type)
      begin
        metadata = ProjectMetadata.new(@project_path)
        medium = MediumRegistry.find(metadata.medium)

        # Check specific_elements for a dir mapping
        medium.specific_elements.each do |_key, config|
          if config["singular"] == element_type || _key == element_type
            return File.join(@project_path, config["dir"] || _key)
          end
        end

        # Check scaffolded_dirs for a matching plural
        plural = "#{element_type}s"
        if medium.scaffolded_dirs.include?(plural)
          return File.join(@project_path, plural)
        end
      rescue StandardError
        # Fall through
      end

      # Default: try plural form if dir exists, else singular
      plural = "#{element_type}s"
      plural_path = File.join(@project_path, plural)
      Dir.exist?(plural_path) ? plural_path : File.join(@project_path, element_type)
    end
  end
end
