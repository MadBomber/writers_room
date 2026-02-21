# frozen_string_literal: true

require "logger"

module WritersRoom
  # Interactive chat session with LLM for creative consultation.
  # Owns business logic only — no rendering. ChatTui handles the terminal UI.
  class ChatSession
    attr_reader :robot, :context, :messages, :logger, :project_path

    # Context keys that contain large data structures meant for the LLM,
    # not for display to the user or inclusion in saved transcripts.
    CONTEXT_DISPLAY_SKIP = %i[additional existing_elements project_elements element_contents].freeze

    # @param context [Hash] conversation context (project info, task, etc.)
    # @param template [Symbol, nil] optional RobotLab template for the session
    # @param project_path [String, nil] path to the WritersRoom project for saving elements
    def initialize(context: {}, template: nil, project_path: nil)
      @context      = context
      @template     = template
      @project_path = project_path
      @messages     = []
      setup_logger
      setup_robot
    end

    # Log session start (called by ChatTui on launch)
    def log_session_start
      @logger.info("=" * 60)
      @logger.info("Session started")
      @context.each do |key, value|
        next if CONTEXT_DISPLAY_SKIP.include?(key)
        @logger.info("  #{key}: #{value}")
      end
      @logger.info("=" * 60)
    end

    # Log session end (called by ChatTui on exit)
    def log_session_end
      @logger.info("Session ended — #{@messages.count / 2} exchanges")
      @logger.info("=" * 60)
    end

    # Send a user message to the LLM. Returns the assistant reply string.
    # Does NOT render anything — ChatTui handles display.
    def chat(user_message)
      @messages << { role: "user", content: user_message }
      @logger.info("USER: #{user_message}")

      result = @robot.run(user_message)
      assistant_message = result.reply || ""

      @messages << { role: "assistant", content: assistant_message }
      @logger.info("ASSISTANT: #{assistant_message}")

      if guardrail_refusal?(assistant_message)
        @logger.warn("GUARDRAIL: refusal detected, removing exchange from context")
        @messages.pop(2)
        return { text: assistant_message, guardrail: true }
      end

      { text: assistant_message, guardrail: false }
    end

    # Get the conversation summary. Blocks on LLM call.
    def summary
      return "No conversation yet." if @messages.empty?

      @robot.update(system_prompt: build_system_prompt)
      result = @robot.run(
        "Please provide a concise summary of our conversation and any key decisions or ideas that emerged."
      )

      result.reply || "Unable to generate summary."
    end

    # Save conversation transcript to file.
    # Does NOT call the LLM — exits instantly.
    def save(filepath)
      require "fileutils"

      FileUtils.mkdir_p(File.dirname(filepath))

      content = "# Chat Session: #{Time.now}\n\n"
      content += "## Context\n\n"
      @context.each do |key, value|
        next if CONTEXT_DISPLAY_SKIP.include?(key)
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

      File.write(filepath, content)
      filepath
    end

    # Check if input is an exit command
    def exit_command?(input)
      return false if input.nil?
      %w[exit quit q bye].include?(input.strip.downcase)
    end

    # Handle a command. Returns a Hash describing the result:
    #   { handled: true, output: "markdown string" }
    #   { handled: true, output: "...", clear_display: true }
    #   { handled: true, async: :summary }
    #   { handled: true, async: :save, args: [type, name] }
    #   { handled: true, async: :save_last }
    #   { handled: true, async: :auto_save }
    #   { handled: false }
    def handle_command(input)
      stripped = input.strip
      lowered  = stripped.downcase

      # Match save with args: "save <type> <name>"
      if stripped =~ /\Asave\s+(\w+)\s+(.+)\z/i
        @logger.info("COMMAND: save #{$1} #{$2.strip}")
        return { handled: true, async: :save, args: [$1.downcase, $2.strip] }
      end

      case lowered
      when "help"
        @logger.info("COMMAND: help")
        { handled: true, output: help_text }
      when "context"
        @logger.info("COMMAND: context")
        { handled: true, output: context_text }
      when "summary"
        @logger.info("COMMAND: summary")
        { handled: true, async: :summary }
      when "clear"
        @logger.info("COMMAND: clear")
        @messages.clear
        { handled: true, output: "*Conversation cleared*", clear_display: true }
      when "save", "save all"
        @logger.info("COMMAND: save (auto-detect)")
        { handled: true, async: :auto_save }
      when /\Asave(\s|$)/
        @logger.info("COMMAND: save last")
        { handled: true, async: :save_last }
      else
        { handled: false }
      end
    end

    # Return the help text as a markdown string
    def help_text
      <<~HELP
        ## Commands

        - `save it` — save the last assistant response as a project element
        - `save <type> <name>` — save discussed content as an element
        - `save` / `save all` — auto-detect all elements and save them
        - `help` — show this help
        - `context` — show current context
        - `summary` — get conversation summary
        - `clear` — clear conversation history
        - `exit` — end chat session (also: `quit`, `q`, `bye`)

        Just type your message to chat with the LLM.
      HELP
    end

    # Return the context as a markdown string
    def context_text
      return "" if @context.empty?

      lines = ["## Context\n"]
      @context.each do |key, value|
        next if CONTEXT_DISPLAY_SKIP.include?(key)
        lines << "- **#{key}**: #{value}"
      end
      lines.join("\n")
    end

    # Return welcome text as a markdown string
    def welcome_text
      <<~WELCOME
        # WritersRoom Chat Session

        Type your questions or ideas. Type `exit` or `quit` to end.
        Type `help` for available commands.
      WELCOME
    end

    # Return goodbye text as a markdown string
    def goodbye_text
      "**Chat session ended** — #{@messages.count / 2} exchanges"
    end

    # Execute a save operation. Returns array of markdown output strings.
    # Blocks on LLM calls.
    def execute_save(element_type, name)
      outputs = []

      unless @project_path
        @logger.warn("Save failed: no project context")
        return ["**No project context** — cannot save elements."]
      end

      types = valid_element_types
      unless types.key?(element_type)
        @logger.warn("Save failed: unknown element type '#{element_type}'")
        return ["**Unknown element type** `#{element_type}`. Valid types: #{types.keys.join(', ')}"]
      end

      if @messages.empty?
        @logger.warn("Save failed: no conversation yet")
        return ["**Nothing discussed yet** — have a conversation first."]
      end

      @logger.info("Extracting #{element_type} details for '#{name}'")
      outputs << "*Extracting #{element_type} details for '#{name}'...*"

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
      outputs << save_element(element_type, parsed)
      outputs
    end

    # Execute auto-save. Returns array of markdown output strings.
    # Blocks on LLM calls.
    def execute_auto_save
      outputs = []

      unless @project_path
        @logger.warn("Auto-save failed: no project context")
        return ["**No project context** — cannot save elements."]
      end

      if @messages.empty?
        @logger.warn("Auto-save failed: no conversation yet")
        return ["**Nothing discussed yet** — have a conversation first."]
      end

      types = valid_element_types
      type_list = types.keys.join(", ")

      @logger.info("Auto-detecting elements to save (valid types: #{type_list})")
      outputs << "*Analyzing conversation to determine what to save...*"

      detection_prompt = <<~PROMPT
        Based on our conversation, what story elements did we discuss or develop?

        Respond with ONLY lines in this format, one per element. No other text:
        TYPE: NAME

        Where TYPE is EXACTLY one of: #{type_list}
        And NAME is the element name.

        If we discussed multiple elements, list each on its own line.
        Only include elements where we developed meaningful content worth saving.
        Do NOT use any type not in the list above.
      PROMPT

      result = @robot.run(detection_prompt)
      reply = result.reply || ""

      elements = reply.strip.lines.filter_map { |line|
        if line =~ /\A\s*(\w+):\s*(.+)/i
          type = $1.strip.downcase
          name = $2.strip
          if types.key?(type)
            [type, name]
          else
            @logger.warn("Auto-save: skipping unknown type '#{type}' for '#{name}'")
            nil
          end
        end
      }

      if elements.empty?
        outputs << <<~MSG
          **Could not detect any elements** to save from the conversation.

          Try: `save <type> <name>` (e.g. `save character Alice`)
        MSG
        return outputs
      end

      lines = ["Found **#{elements.size}** element(s) to save:\n"]
      elements.each { |type, name| lines << "- #{type}: **#{name}**" }
      outputs << lines.join("\n")

      elements.each do |type, name|
        outputs.concat(execute_save(type, name))
      end

      outputs
    end

    # Save the last assistant response directly as a project element.
    # Uses a quick LLM call to identify type and name, then writes the
    # raw content — no re-extraction or summarization.
    # Returns array of markdown output strings.
    def execute_save_last
      unless @project_path
        @logger.warn("Save-last failed: no project context")
        return ["**No project context** — cannot save elements."]
      end

      last_assistant = @messages.reverse.find { |m| m[:role] == "assistant" }
      unless last_assistant
        @logger.warn("Save-last failed: no assistant message")
        return ["**Nothing to save** — no assistant response yet."]
      end

      types = valid_element_types
      type_list = types.keys.join(", ")

      @logger.info("Save-last: identifying element from last response")

      id_prompt = <<~PROMPT
        Look at the last thing you wrote in our conversation.
        What single story element best describes it?

        Respond with ONLY one line in this format, no other text:
        TYPE: NAME

        Where TYPE is EXACTLY one of: #{type_list}
        And NAME is the element name (e.g. "Chapter 2" or "Mara Kode").
        Do NOT use any type not in the list above.
      PROMPT

      result = @robot.run(id_prompt)
      reply = result.reply || ""

      match = reply.strip.match(/\A\s*(\w+):\s*(.+)/i)
      unless match
        @logger.warn("Save-last: could not identify element from LLM response: #{reply}")
        return ["**Could not identify** what to save. Try: `save <type> <name>` (e.g. `save chapter Chapter 2`)"]
      end

      element_type = match[1].strip.downcase
      name = match[2].strip

      unless types.key?(element_type)
        @logger.warn("Save-last: LLM returned invalid type '#{element_type}'")
        return ["**Unknown element type** `#{element_type}`. Try: `save <type> <name>` where type is one of: #{type_list}"]
      end

      content = last_assistant[:content]

      @logger.info("Save-last: saving #{element_type} '#{name}' (#{content.length} chars)")

      dir = resolve_element_dir(element_type)
      slug = Element.sanitize(name)
      path = File.join(dir, "#{slug}.md")

      metadata = { "name" => name, "status" => "draft" }
      parsed = { name: name, previous_names: [], aliases: [], status: "draft", body: content }

      old_path = find_existing_element(dir, parsed)

      if old_path && old_path != path
        el = Element.load(old_path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, content)
        el.instance_variable_set(:@path, path)
        el.instance_variable_set(:@slug, slug)
        el.save
        File.delete(old_path)
        @logger.info("Renamed #{element_type}: #{File.basename(old_path, '.md')} -> #{name} (#{path})")
        ["**Saved** #{element_type}: #{name} (`#{path}`)"]
      elsif File.exist?(path)
        el = Element.load(path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, content)
        el.save
        @logger.info("Updated #{element_type}: #{name} -> #{path}")
        ["**Saved** #{element_type}: #{name} (`#{path}`)"]
      else
        require "fileutils"
        FileUtils.mkdir_p(dir)
        file_content = FrontMatter.dump(metadata, content)
        File.write(path, file_content)
        @logger.info("Created #{element_type}: #{name} -> #{path}")
        ["**Saved** #{element_type}: #{name} (`#{path}`)"]
      end
    rescue StandardError => e
      @logger.error("Error in save-last: #{e.message}")
      ["**Error** saving: #{e.message}"]
    end

    # Execute summary. Returns markdown string.
    def execute_summary
      "\n## Summary\n\n#{summary}"
    end

    private

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
        ListDirectoryTool.new(project_path: @project_path),
        OpenEditorTool.new(project_path: @project_path)
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

    # Returns a markdown string describing the save result.
    def save_element(element_type, parsed)
      dir = resolve_element_dir(element_type)

      slug = Element.sanitize(parsed[:name])
      path = File.join(dir, "#{slug}.md")

      metadata = { "name" => parsed[:name], "status" => parsed[:status] }
      metadata["aliases"] = parsed[:aliases] if parsed[:aliases].any?

      old_path = find_existing_element(dir, parsed)

      if old_path && old_path != path
        el = Element.load(old_path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, parsed[:body]) unless parsed[:body].empty?
        el.instance_variable_set(:@path, path)
        el.instance_variable_set(:@slug, slug)
        el.save
        File.delete(old_path)
        @logger.info("Renamed #{element_type}: #{File.basename(old_path, '.md')} -> #{parsed[:name]} (#{path})")
        "**Renamed** #{element_type}: #{File.basename(old_path, '.md')} -> #{parsed[:name]} (`#{path}`)"
      elsif File.exist?(path)
        el = Element.load(path)
        el.metadata.merge!(FrontMatter.deep_symbolize_keys(metadata))
        el.instance_variable_set(:@body, parsed[:body]) unless parsed[:body].empty?
        el.save
        @logger.info("Updated #{element_type}: #{parsed[:name]} -> #{path}")
        "**Updated** #{element_type}: #{parsed[:name]} (`#{path}`)"
      else
        FileUtils.mkdir_p(dir)
        content = FrontMatter.dump(metadata, parsed[:body])
        File.write(path, content)
        @logger.info("Created #{element_type}: #{parsed[:name]} -> #{path}")
        "**Created** #{element_type}: #{parsed[:name]} (`#{path}`)"
      end
    rescue StandardError => e
      @logger.error("Error saving #{element_type} '#{parsed[:name]}': #{e.message}")
      "**Error** saving #{element_type}: #{e.message}"
    end

    def find_existing_element(dir, parsed)
      return nil unless Dir.exist?(dir)

      collection = ElementCollection.new(dir)

      parsed[:previous_names]&.each do |prev_name|
        el = collection.find_by_name_or_alias(prev_name)
        return el.path if el
      end

      el = collection.find_by_name_or_alias(parsed[:name])
      return el.path if el

      nil
    end

    # Build a map of valid singular element types to their directory names,
    # derived from the medium config. Only these types can be saved.
    def valid_element_types
      types = {}

      begin
        metadata = ProjectMetadata.new(@project_path)
        medium = MediumRegistry.find(metadata.medium)

        # From specific_elements (e.g. chapters: {dir: "chapters", singular: "chapter"})
        medium.specific_elements.each do |key, config|
          singular = config["singular"] || key.to_s.chomp("s")
          dir = config["dir"] || key.to_s
          types[singular] = dir
        end

        # From scaffolded_dirs (e.g. "characters" → singular "character")
        medium.scaffolded_dirs.each do |dir_name|
          next if %w[transcripts drafts].include?(dir_name)
          singular = dir_name.chomp("s")
          types[singular] ||= dir_name
        end
      rescue StandardError
        # No medium config available — no valid types
      end

      types
    end

    # Resolve element type to a project directory path.
    # Only returns directories for types defined in the medium config.
    def resolve_element_dir(element_type)
      types = valid_element_types
      dir_name = types[element_type]

      unless dir_name
        raise "Unknown element type '#{element_type}'. Valid types: #{types.keys.join(', ')}"
      end

      File.join(@project_path, dir_name)
    end
  end
end
