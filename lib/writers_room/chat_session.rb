# frozen_string_literal: true

require "debug_me"
include DebugMe

require "ruby_llm"
require "io/console"

module WritersRoom
  # Interactive chat session with LLM for creative consultation
  class ChatSession
    attr_reader :llm, :context, :messages, :config

    def initialize(config:, context: {})
      @config = config
      @context = context
      @messages = []
      setup_llm

      debug_me("ChatSession initialized") { context.keys }
    end

    # Start an interactive chat session
    def start
      display_welcome
      display_context

      loop do
        print "\n#{prompt_symbol} "
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

      response = @llm.chat(
        messages: system_messages + @messages,
        temperature: 0.7
      )

      assistant_message = extract_response(response)
      @messages << { role: "assistant", content: assistant_message }

      puts "\n#{assistant_symbol} #{assistant_message}"

      assistant_message
    end

    # Get the conversation summary
    def summary
      return "No conversation yet." if @messages.empty?

      # Ask LLM to summarize the conversation
      summary_prompt = {
        role: "user",
        content: "Please provide a concise summary of our conversation and any key decisions or ideas that emerged."
      }

      response = @llm.chat(
        messages: system_messages + @messages + [summary_prompt],
        temperature: 0.5
      )

      extract_response(response)
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

    def setup_llm
      # Configure RubyLLM with provider-specific settings
      provider = @config.provider || "ollama"
      model = @config.model_name || "gpt-oss:20b"

      RubyLLM.configure do |config|
        if provider == "ollama"
          config.ollama_api_base = ENV["OLLAMA_URL"] || "http://localhost:11434"
        elsif provider == "openai"
          config.openai_api_key = ENV["OPENAI_API_KEY"]
        elsif provider == "anthropic"
          config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
        end
      end

      # Create chat client for the specified model
      # RubyLLM uses just the model name, not "provider/model"
      @llm = RubyLLM.chat(model: model)

      debug_me("LLM setup complete for ChatSession") do
        [provider, model]
      end
    end

    def system_messages
      system_content = build_system_prompt
      [{ role: "system", content: system_content }]
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
      puts "\n" + "=" * 60
      puts "  WRITERSROOM CHAT SESSION"
      puts "=" * 60
      puts "\nStarting interactive chat with LLM..."
      puts "Type your questions or ideas. Type 'exit' or 'quit' to end."
      puts "Type 'help' for available commands."
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
      puts "\n" + "=" * 60
      puts "  Chat session ended"
      puts "=" * 60
      puts "\nTotal exchanges: #{@messages.count / 2}"
    end

    def prompt_symbol
      "💬"
    end

    def assistant_symbol
      "🤖"
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
        puts "\n📝 Summary:\n#{summary}"
        true
      when "clear"
        @messages.clear
        puts "\n✓ Conversation cleared"
        true
      else
        false
      end
    end

    def show_help
      puts "\nAvailable commands:"
      puts "  help     - Show this help"
      puts "  context  - Show current context"
      puts "  summary  - Get conversation summary"
      puts "  clear    - Clear conversation history"
      puts "  exit     - End chat session (also: quit, q, bye)"
      puts "\nOtherwise, just type your message to chat with the LLM."
    end

    def extract_response(response)
      text = if response.is_a?(String)
          response
        elsif response.respond_to?(:content)
          response.content
        elsif response.respond_to?(:text)
          response.text
        elsif response.is_a?(Hash) && response[:content]
          response[:content]
        else
          response.to_s
        end

      text.strip
    end
  end
end
