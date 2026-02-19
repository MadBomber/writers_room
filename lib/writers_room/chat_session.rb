# frozen_string_literal: true


require "io/console"

module WritersRoom
  # Interactive chat session with LLM for creative consultation.
  # Uses LLMSetup for shared configuration instead of duplicating setup.
  class ChatSession
    attr_reader :robot, :context, :messages

    # @param context [Hash] conversation context (project info, task, etc.)
    # @param template [Symbol, nil] optional RobotLab template for the session
    def initialize(context: {}, template: nil)
      @context = context
      @template = template
      @messages = []
      setup_robot
    end

    # Start an interactive chat session
    def start
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
      @messages
    end

    # Chat with a single message (non-interactive)
    def chat(user_message)
      @messages << { role: "user", content: user_message }

      result = @robot.run(user_message)
      assistant_message = result.reply || ""

      @messages << { role: "assistant", content: assistant_message }

      puts "\nAssistant: #{assistant_message}"

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

    def setup_robot
      run_config = LLMSetup.build_run_config

      if @template
        @robot = RobotLab.build(
          name: "chat_session",
          template: @template,
          context: @context,
          config: run_config
        )
      else
        @robot = RobotLab.build(
          name: "chat_session",
          system_prompt: build_system_prompt,
          config: run_config
        )
      end
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
      puts <<~WELCOME

        #{"=" * 60}
          WRITERSROOM CHAT SESSION
        #{"=" * 60}

        Starting interactive chat with LLM...
        Type your questions or ideas. Type 'exit' or 'quit' to end.
        Type 'help' for available commands.
      WELCOME
    end

    def display_context
      return if @context.empty?

      puts "\n--- Context ---"
      @context.each do |key, value|
        next if key == :additional
        puts "#{key}: #{value}"
      end
      puts "---------------"
    end

    def display_goodbye
      puts <<~GOODBYE

        #{"=" * 60}
          Chat session ended
        #{"=" * 60}

        Total exchanges: #{@messages.count / 2}
      GOODBYE
    end

    def exit_command?(input)
      return false if input.nil?
      %w[exit quit q bye].include?(input.strip.downcase)
    end

    def handle_command(input)
      case input.strip.downcase
      when "help"
        show_help
        true
      when "context"
        display_context
        true
      when "summary"
        puts "\nSummary:\n#{summary}"
        true
      when "clear"
        @messages.clear
        puts "\nConversation cleared"
        true
      else
        false
      end
    end

    def show_help
      puts <<~HELP

        Available commands:
          help     - Show this help
          context  - Show current context
          summary  - Get conversation summary
          clear    - Clear conversation history
          exit     - End chat session (also: quit, q, bye)

        Otherwise, just type your message to chat with the LLM.
      HELP
    end
  end
end
