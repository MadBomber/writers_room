# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Export < Thor
      namespace "export"

      desc "manuscript", "Export project as a formatted manuscript"
      method_option :output,
                    aliases: "-o",
                    type: :string,
                    desc: "Output file path (default: <project_name>_manuscript.md)"
      def manuscript
        project = Dir.pwd
        metadata = WritersRoom::ProjectMetadata.new(project)
        medium_id = metadata.medium.to_sym

        formatter = select_formatter(project, medium_id)
        output = options[:output] || "#{sanitize(metadata.name)}_manuscript.md"

        formatter.export(output)
        say "Exported manuscript to: #{output}", :green
      rescue StandardError => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "bible", "Export the story bible as a formatted document"
      method_option :output,
                    aliases: "-o",
                    type: :string,
                    default: "story_bible_export.md",
                    desc: "Output file path"
      def bible
        project = Dir.pwd
        story_bible = WritersRoom::StoryBible.new(project)
        story_bible.regenerate

        lines = ["# Story Bible\n"]
        lines << "*Generated: #{Time.now}*\n"

        story_bible.elements_by_type.each do |type, entries|
          lines << "## #{type.capitalize}\n"
          entries.each do |entry|
            lines << "### #{entry['name']}"
            lines << "- Aliases: #{entry['aliases'].join(', ')}" if entry["aliases"]&.any?
            lines << "- Status: #{entry['status']}" if entry["status"]
            lines << "- Path: #{entry['path']}"
            lines << ""
          end
        end

        File.write(options[:output], lines.join("\n"))
        say "Exported story bible to: #{options[:output]}", :green
      rescue StandardError => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "references", "Export cross-reference graph"
      method_option :output,
                    aliases: "-o",
                    type: :string,
                    default: "cross_references.md",
                    desc: "Output file path"
      def references
        project = Dir.pwd
        xref = WritersRoom::CrossReference.new(project)
        xref.scan

        graph = xref.graph

        lines = ["# Cross References\n"]
        lines << "*Generated: #{Time.now}*\n"
        lines << "## Reference Graph\n"

        if graph[:edges].empty?
          lines << "No cross-references found."
        else
          graph[:edges].each do |edge|
            lines << "- **#{edge[:from]}** references **#{edge[:to]}**"
          end
        end

        File.write(options[:output], lines.join("\n"))
        say "Exported cross-references to: #{options[:output]}", :green
      rescue StandardError => e
        say "Error: #{e.message}", :red
        exit 1
      end

      private

      def select_formatter(project, medium_id)
        case medium_id
        when :novel, :novella, :short_story
          WritersRoom::Formatters::NovelFormatter.new(project)
        when :screenplay, :stage_play
          WritersRoom::Formatters::ScreenplayFormatter.new(project)
        when :dialog
          WritersRoom::Formatters::TranscriptFormatter.new(project)
        else
          WritersRoom::Formatters::BaseFormatter.new(project)
        end
      end

      def sanitize(name)
        name.to_s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/(^_|_$)/, "")
      end
    end
  end
end
