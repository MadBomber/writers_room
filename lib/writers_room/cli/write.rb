# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Write < Thor
      desc "develop-concept", "Develop the project concept into a fuller description"
      method_option :chat,
                    type: :boolean,
                    default: false,
                    desc: "Interactive chat mode with LLM"

      def develop_concept
        require_relative "../writer"

        writer = WritersRoom::Writer.new

        if options[:chat]
          say "Starting interactive chat about the concept...", :cyan
          say ""
          result = writer.develop_concept(chat: true)

          say "\n" + "=" * 60, :green
          say "CHAT SESSION COMPLETE", :green
          say "=" * 60, :green
          say ""
          say "Summary:", :cyan
          say result[:summary], :white
          say ""
          say "Chat saved to: #{result[:chat_log]}", :yellow
          return
        end

        say "Developing project concept...", :cyan
        say "This may take a moment as the LLM generates content...", :yellow
        say ""

        result = writer.develop_concept(chat: false)

        say "=" * 60, :green
        say "CONCEPT DEVELOPMENT COMPLETE", :green
        say "=" * 60, :green
        say ""
        say "Original Concept:", :cyan
        say result[:original], :white
        say ""
        say "Developed Concept:", :cyan
        say result[:developed], :white
        say ""
        say "=" * 60, :green
        say "Saved to: #{result[:saved_to]}", :yellow
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error developing concept: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "develop-character NAME", "Create a detailed character profile"
      method_option :personality,
                    aliases: "-p",
                    type: :string,
                    desc: "Basic personality description"
      method_option :background,
                    aliases: "-b",
                    type: :string,
                    desc: "Background notes"
      method_option :chat,
                    type: :boolean,
                    default: false,
                    desc: "Interactive chat mode with LLM"

      def develop_character(name)
        require_relative "../writer"

        writer = WritersRoom::Writer.new

        basic_info = {
          personality: options[:personality],
          background: options[:background]
        }.compact

        if options[:chat]
          say "Starting interactive chat about character: #{name}", :cyan
          say ""
          result = writer.develop_character(name, basic_info, chat: true)

          say "\n" + "=" * 60, :green
          say "CHAT SESSION COMPLETE", :green
          say "=" * 60, :green
          say ""
          say "Summary:", :cyan
          say result[:summary], :white
          say ""
          say "Chat saved to: #{result[:chat_log]}", :yellow
          return
        end

        say "Developing character profile for: #{name}", :cyan
        say "This may take a moment as the LLM generates content...", :yellow
        say ""

        result = writer.develop_character(name, basic_info, chat: false)

        say "=" * 60, :green
        say "CHARACTER PROFILE: #{name}", :green
        say "=" * 60, :green
        say ""
        say result[:profile], :white
        say ""
        say "=" * 60, :green
        say "Saved to: #{result[:saved_to]}", :yellow
        say ""
        say "Next step: Create the character with 'wr character create #{name}'", :cyan
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error developing character: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "create-arc NAME", "Create a story arc outline"
      method_option :description,
                    aliases: "-d",
                    type: :string,
                    required: true,
                    desc: "Brief description of the arc"
      method_option :chat,
                    type: :boolean,
                    default: false,
                    desc: "Interactive chat mode with LLM"

      def create_arc(name)
        require_relative "../writer"

        writer = WritersRoom::Writer.new

        if options[:chat]
          say "Starting interactive chat about story arc: #{name}", :cyan
          say ""
          result = writer.create_arc(name, options[:description], chat: true)

          say "\n" + "=" * 60, :green
          say "CHAT SESSION COMPLETE", :green
          say "=" * 60, :green
          say ""
          say "Summary:", :cyan
          say result[:summary], :white
          say ""
          say "Chat saved to: #{result[:chat_log]}", :yellow
          return
        end

        say "Creating story arc: #{name}", :cyan
        say "This may take a moment as the LLM generates content...", :yellow
        say ""

        result = writer.create_arc(name, options[:description], chat: false)

        say "=" * 60, :green
        say "STORY ARC: #{name}", :green
        say "=" * 60, :green
        say ""
        say "Description:", :cyan
        say options[:description], :white
        say ""
        say "Detailed Outline:", :cyan
        say result[:outline], :white
        say ""
        say "=" * 60, :green
        say "Saved to: #{result[:saved_to]}", :yellow
        say ""
        say "Next step: Break down into scenes with 'wr write breakdown-scenes \"#{name}\"'", :cyan
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error creating arc: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "breakdown-scenes ARC_NAME", "Break down an arc into scene suggestions"
      method_option :num_scenes,
                    aliases: "-n",
                    type: :numeric,
                    default: 5,
                    desc: "Number of scenes to generate"
      method_option :chat,
                    type: :boolean,
                    default: false,
                    desc: "Interactive chat mode with LLM"

      def breakdown_scenes(arc_name)
        require_relative "../writer"

        writer = WritersRoom::Writer.new

        if options[:chat]
          say "Starting interactive chat about scene breakdown: #{arc_name}", :cyan
          say ""
          result = writer.breakdown_scenes(arc_name, num_scenes: options[:num_scenes], chat: true)

          say "\n" + "=" * 60, :green
          say "CHAT SESSION COMPLETE", :green
          say "=" * 60, :green
          say ""
          say "Summary:", :cyan
          say result[:summary], :white
          say ""
          say "Chat saved to: #{result[:chat_log]}", :yellow
          return
        end

        say "Breaking down arc into scenes: #{arc_name}", :cyan
        say "Generating #{options[:num_scenes]} scene suggestions...", :yellow
        say ""

        result = writer.breakdown_scenes(arc_name, num_scenes: options[:num_scenes], chat: false)

        say "=" * 60, :green
        say "SCENE BREAKDOWN: #{arc_name}", :green
        say "=" * 60, :green
        say ""
        say result[:breakdown], :white
        say ""
        say "=" * 60, :green
        say "Saved to: #{result[:saved_to]}", :yellow
        say ""
        say "Next steps:", :cyan
        say "  1. Review the scene breakdown", :white
        say "  2. Create scene files with 'wr scene create <SCENE_NAME>'", :white
        say "  3. Direct scenes with 'wr direct <scene_file>'", :white
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error breaking down scenes: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      desc "list-arcs", "List all story arcs in the project"
      def list_arcs
        require_relative "../writer"

        writer = WritersRoom::Writer.new
        arcs = writer.metadata.story_arcs

        if arcs.empty?
          say "No story arcs found.", :yellow
          say "Create an arc with 'wr write create-arc <NAME> -d \"description\"'", :cyan
          exit 0
        end

        say "Story Arcs:", :cyan
        say ""

        arcs.each_with_index do |arc, index|
          say "#{index + 1}. #{arc['name']}", :green
          say "   Description: #{arc['description']}", :white
          say "   Created: #{arc['created_at']}", :white
          say ""
        end
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error listing arcs: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
