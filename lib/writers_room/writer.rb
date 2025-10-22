# frozen_string_literal: true

require "debug_me"
include DebugMe

require "yaml"
require "fileutils"
require "ruby_llm"

module WritersRoom
  # Writer helps develop the story: expands concepts, develops characters,
  # creates story arcs, and breaks down scenes
  class Writer
    attr_reader :project_path, :metadata, :config, :llm

    def initialize(project_path = Dir.pwd)
      @project_path = File.expand_path(project_path)

      unless File.exist?(File.join(@project_path, "config.yml"))
        raise Error, "No config.yml found. Run 'wr init <project_name>' first."
      end

      @config = Config.new(File.join(@project_path, "config.yml"))
      @metadata = ProjectMetadata.new(@project_path)
      setup_llm

      debug_me("Writer initialized for project") { @metadata.name }
    end

    # Develop the project concept into a fuller description using LLM
    def develop_concept(chat: false)
      current_concept = @metadata.concept

      if current_concept.empty?
        raise Error, "No concept found. Initialize project with a concept first."
      end

      # If chat mode, start interactive session first
      if chat
        chat_result = chat_about_concept(current_concept)
        return chat_result if chat_result
      end

      system_prompt = <<~SYSTEM
        You are an experienced story developer helping to expand a project concept.
        Your job is to take a brief concept and develop it into a richer, more detailed description
        that provides direction for writers, characters, and scenes.

        Focus on:
        - Core themes and tone
        - The world/setting
        - Central conflict or dramatic question
        - Potential character types
        - Story structure possibilities

        Keep it concise but evocative (3-5 paragraphs).
      SYSTEM

      user_prompt = <<~USER
        Here is the current concept:

        #{current_concept}

        Please develop this into a fuller, more detailed project description that will guide
        the creative team.
      USER

      response = @llm.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.8
      )

      developed_concept = extract_response(response)

      # Save to a development notes file
      notes_path = File.join(@project_path, "concept_development.md")
      File.write(notes_path, <<~MARKDOWN)
        # Project Concept Development

        ## Original Concept
        #{current_concept}

        ## Developed Concept
        #{developed_concept}

        *Generated: #{Time.now}*
      MARKDOWN

      debug_me("Concept developed") { notes_path }

      {
        original: current_concept,
        developed: developed_concept,
        saved_to: notes_path
      }
    end

    # Develop a character profile from basic information
    def develop_character(name, basic_info = {}, chat: false)
      personality = basic_info[:personality] || basic_info["personality"] || "to be determined"
      background = basic_info[:background] || basic_info["background"] || ""

      # If chat mode, start interactive session first
      if chat
        chat_result = chat_about_character(name, personality, background)
        return chat_result if chat_result
      end

      system_prompt = <<~SYSTEM
        You are a character development expert helping to create rich, three-dimensional characters.
        Given a character name and basic information, develop a detailed character profile.

        Include:
        - Detailed personality traits and quirks
        - Background and history
        - Motivations and fears
        - Speaking style and mannerisms
        - Internal conflicts
        - Potential character arc
        - Relationships with other characters (general types)

        Format the response as a structured character profile.
      SYSTEM

      user_prompt = <<~USER
        Project Concept:
        #{@metadata.concept}

        Character to develop:
        Name: #{name}
        Basic Personality: #{personality}
        Background Notes: #{background}

        Please create a detailed character profile for #{name}.
      USER

      response = @llm.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.7
      )

      character_profile = extract_response(response)

      # Save to character development file
      dev_path = File.join(@project_path, "characters", "#{sanitize_filename(name)}_development.md")
      FileUtils.mkdir_p(File.dirname(dev_path))

      File.write(dev_path, <<~MARKDOWN)
        # Character Profile: #{name}

        #{character_profile}

        ---
        *Generated: #{Time.now}*
        *Based on: #{personality}*
      MARKDOWN

      debug_me("Character developed") { [name, dev_path] }

      {
        name: name,
        profile: character_profile,
        saved_to: dev_path
      }
    end

    # Create a story arc
    def create_arc(arc_name, description, chat: false)
      # If chat mode, start interactive session first
      if chat
        chat_result = chat_about_arc(arc_name, description)
        return chat_result if chat_result
      end

      system_prompt = <<~SYSTEM
        You are a story structure expert helping to develop narrative arcs.
        Given an arc name and description, create a detailed arc outline.

        Include:
        - Arc overview and purpose
        - Beginning state
        - Key events and turning points
        - Character development within this arc
        - Ending state
        - Thematic elements

        Keep it structured and clear for writers to use.
      SYSTEM

      user_prompt = <<~USER
        Project Concept:
        #{@metadata.concept}

        Arc to develop:
        Name: #{arc_name}
        Description: #{description}

        Please create a detailed arc outline for "#{arc_name}".
      USER

      response = @llm.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.7
      )

      arc_outline = extract_response(response)

      # Save arc to metadata and create arc file
      arc_data = {
        "name" => arc_name,
        "description" => description,
        "outline" => arc_outline,
        "created_at" => Time.now.to_s
      }

      @metadata.add_story_arc(arc_data)

      # Save detailed arc file
      arc_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}.md")
      FileUtils.mkdir_p(File.dirname(arc_path))

      File.write(arc_path, <<~MARKDOWN)
        # Story Arc: #{arc_name}

        ## Description
        #{description}

        ## Detailed Outline
        #{arc_outline}

        ---
        *Created: #{Time.now}*
      MARKDOWN

      debug_me("Arc created") { [arc_name, arc_path] }

      {
        name: arc_name,
        outline: arc_outline,
        saved_to: arc_path
      }
    end

    # Break down an arc into scene suggestions
    def breakdown_scenes(arc_name, num_scenes: 5, chat: false)
      # Find the arc
      arc = @metadata.story_arcs.find { |a| a["name"] == arc_name }

      unless arc
        raise Error, "Arc '#{arc_name}' not found. Create it first with 'wr write create-arc'."
      end

      # If chat mode, start interactive session first
      if chat
        chat_result = chat_about_scene_breakdown(arc_name, arc, num_scenes)
        return chat_result if chat_result
      end

      system_prompt = <<~SYSTEM
        You are a scene breakdown expert helping to structure narrative arcs into scenes.
        Given an arc outline, break it down into specific scenes.

        For each scene provide:
        - Scene name/number
        - Location/setting
        - Characters involved
        - What happens (brief summary)
        - Dramatic purpose/objective
        - Emotional tone

        Format as a numbered list of scenes.
      SYSTEM

      user_prompt = <<~USER
        Project Concept:
        #{@metadata.concept}

        Arc to break down:
        Name: #{arc_name}
        Description: #{arc["description"]}

        Arc Outline:
        #{arc["outline"]}

        Please break this arc down into #{num_scenes} scenes.
      USER

      response = @llm.chat(
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: user_prompt }
        ],
        temperature: 0.6
      )

      scene_breakdown = extract_response(response)

      # Save breakdown file
      breakdown_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_breakdown.md")

      File.write(breakdown_path, <<~MARKDOWN)
        # Scene Breakdown: #{arc_name}

        #{scene_breakdown}

        ---
        *Generated: #{Time.now}*
        *Scenes requested: #{num_scenes}*
      MARKDOWN

      debug_me("Scenes broken down") { [arc_name, breakdown_path] }

      {
        arc: arc_name,
        breakdown: scene_breakdown,
        saved_to: breakdown_path
      }
    end

    private

    # Chat about concept development
    def chat_about_concept(current_concept)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: current_concept,
        task: "Developing the project concept",
        subject: "Project Concept"
      }

      session = ChatSession.new(config: @config, context: context)
      session.start

      # Save chat log
      chat_log_path = File.join(@project_path, "concept_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    # Chat about character development
    def chat_about_character(name, personality, background)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Developing character: #{name}",
        subject: name,
        additional: "Personality: #{personality}\nBackground: #{background}"
      }

      session = ChatSession.new(config: @config, context: context)
      session.start

      # Save chat log
      chat_log_path = File.join(@project_path, "characters", "#{sanitize_filename(name)}_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        name: name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    # Chat about story arc creation
    def chat_about_arc(arc_name, description)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Creating story arc: #{arc_name}",
        subject: arc_name,
        additional: "Description: #{description}"
      }

      session = ChatSession.new(config: @config, context: context)
      session.start

      # Save chat log
      chat_log_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        name: arc_name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    # Chat about scene breakdown
    def chat_about_scene_breakdown(arc_name, arc, num_scenes)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Breaking down arc into scenes: #{arc_name}",
        subject: arc_name,
        additional: "Arc Description: #{arc['description']}\nRequested scenes: #{num_scenes}"
      }

      session = ChatSession.new(config: @config, context: context)
      session.start

      # Save chat log
      chat_log_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_breakdown_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        arc: arc_name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

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

      debug_me("LLM setup complete for Writer") do
        [provider, model]
      end
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

    def sanitize_filename(name)
      name.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/(^_|_$)/, "")
    end
  end
end
