# frozen_string_literal: true

require "yaml"
require "fileutils"

module WritersRoom
  # Writer helps develop the story: expands concepts, develops characters,
  # creates story arcs, and breaks down scenes.
  #
  # Uses RobotLab template switching: each method updates the robot's
  # template + context before running, rather than inlining prompts.
  class Writer
    attr_reader :project_path, :metadata, :robot

    def initialize(project_path = Dir.pwd)
      @project_path = File.expand_path(project_path)

      unless File.exist?(File.join(@project_path, "config.yml")) ||
             File.exist?(File.join(@project_path, "project.md"))
        raise Error, "No project found. Run 'wr init <project_name>' first."
      end

      @metadata = ProjectMetadata.new(@project_path)
      setup_robot

    end

    # Develop the project concept into a fuller description using LLM
    def develop_concept(chat: false)
      current_concept = @metadata.concept

      if current_concept.empty?
        raise Error, "No concept found. Initialize project with a concept first."
      end

      if chat
        chat_result = chat_about_concept(current_concept)
        return chat_result if chat_result
      end

      @robot.update(
        template: :develop_concept,
        context: { concept: current_concept }
      )

      result = @robot.run("Develop this concept into a fuller project description.")
      developed_concept = result.reply

      notes_path = File.join(@project_path, "concept_development.md")
      File.write(notes_path, <<~MARKDOWN)
        # Project Concept Development

        ## Original Concept
        #{current_concept}

        ## Developed Concept
        #{developed_concept}

        *Generated: #{Time.now}*
      MARKDOWN

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

      if chat
        chat_result = chat_about_character(name, personality, background)
        return chat_result if chat_result
      end

      @robot.update(
        template: :develop_character,
        context: {
          project_concept: @metadata.concept,
          character_name: name,
          personality: personality,
          background: background
        }
      )

      result = @robot.run("Create a detailed character profile for #{name}.")
      character_profile = result.reply

      dev_path = File.join(@project_path, "characters", "#{sanitize_filename(name)}_development.md")
      FileUtils.mkdir_p(File.dirname(dev_path))

      File.write(dev_path, <<~MARKDOWN)
        # Character Profile: #{name}

        #{character_profile}

        ---
        *Generated: #{Time.now}*
        *Based on: #{personality}*
      MARKDOWN

      {
        name: name,
        profile: character_profile,
        saved_to: dev_path
      }
    end

    # Create a story arc
    def create_arc(arc_name, description, chat: false)
      if chat
        chat_result = chat_about_arc(arc_name, description)
        return chat_result if chat_result
      end

      @robot.update(
        template: :create_arc,
        context: {
          project_concept: @metadata.concept,
          arc_name: arc_name,
          arc_description: description
        }
      )

      result = @robot.run("Create a detailed arc outline for \"#{arc_name}\".")
      arc_outline = result.reply

      arc_data = {
        "name" => arc_name,
        "description" => description,
        "outline" => arc_outline,
        "created_at" => Time.now.to_s
      }

      @metadata.add_story_arc(arc_data)

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

      {
        name: arc_name,
        outline: arc_outline,
        saved_to: arc_path
      }
    end

    # Break down an arc into scene suggestions
    def breakdown_scenes(arc_name, num_scenes: 5, chat: false)
      arc = @metadata.story_arcs.find { |a| a["name"] == arc_name }

      unless arc
        raise Error, "Arc '#{arc_name}' not found. Create it first with 'wr write create-arc'."
      end

      if chat
        chat_result = chat_about_scene_breakdown(arc_name, arc, num_scenes)
        return chat_result if chat_result
      end

      @robot.update(
        template: :breakdown_scenes,
        context: {
          project_concept: @metadata.concept,
          arc_name: arc_name,
          arc_description: arc["description"],
          arc_outline: arc["outline"],
          num_scenes: num_scenes
        }
      )

      result = @robot.run("Break this arc down into #{num_scenes} scenes.")
      scene_breakdown = result.reply

      breakdown_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_breakdown.md")

      File.write(breakdown_path, <<~MARKDOWN)
        # Scene Breakdown: #{arc_name}

        #{scene_breakdown}

        ---
        *Generated: #{Time.now}*
        *Scenes requested: #{num_scenes}*
      MARKDOWN

      {
        arc: arc_name,
        breakdown: scene_breakdown,
        saved_to: breakdown_path
      }
    end

    private

    def chat_about_concept(current_concept)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: current_concept,
        task: "Developing the project concept",
        subject: "Project Concept"
      }

      session = ChatSession.new(context: context)
      session.start

      chat_log_path = File.join(@project_path, "concept_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    def chat_about_character(name, personality, background)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Developing character: #{name}",
        subject: name,
        additional: "Personality: #{personality}\nBackground: #{background}"
      }

      session = ChatSession.new(context: context)
      session.start

      chat_log_path = File.join(@project_path, "characters", "#{sanitize_filename(name)}_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        name: name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    def chat_about_arc(arc_name, description)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Creating story arc: #{arc_name}",
        subject: arc_name,
        additional: "Description: #{description}"
      }

      session = ChatSession.new(context: context)
      session.start

      chat_log_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        name: arc_name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    def chat_about_scene_breakdown(arc_name, arc, num_scenes)
      require_relative "chat_session"

      context = {
        project_name: @metadata.name,
        project_concept: @metadata.concept,
        task: "Breaking down arc into scenes: #{arc_name}",
        subject: arc_name,
        additional: "Arc Description: #{arc['description']}\nRequested scenes: #{num_scenes}"
      }

      session = ChatSession.new(context: context)
      session.start

      chat_log_path = File.join(@project_path, "arcs", "#{sanitize_filename(arc_name)}_breakdown_chat_#{Time.now.to_i}.md")
      session.save(chat_log_path)

      {
        arc: arc_name,
        chat_log: chat_log_path,
        summary: session.summary,
        messages: session.messages
      }
    end

    def setup_robot
      run_config = LLMSetup.build_run_config
      tools = build_file_tools

      @robot = RobotLab.build(
        name: "writer",
        config: run_config,
        system_prompt: "You are a creative writing assistant.",
        local_tools: tools
      )
    end

    def build_file_tools
      [
        ReadFileTool.new(project_path: @project_path),
        WriteFileTool.new(project_path: @project_path),
        ListDirectoryTool.new(project_path: @project_path)
      ]
    end

    def sanitize_filename(name)
      name.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/(^_|_$)/, "")
    end
  end
end
