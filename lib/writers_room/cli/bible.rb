# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Bible < Thor
      namespace "bible"

      desc "regenerate", "Regenerate the story bible index from project files"
      def regenerate
        project = Dir.pwd
        bible = WritersRoom::StoryBible.new(project)
        bible.regenerate

        say "Story bible regenerated: #{bible.element_count} elements indexed", :green
      rescue StandardError => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "show", "Show the story bible contents"
      def show
        project = Dir.pwd
        bible = WritersRoom::StoryBible.new(project)

        if bible.element_count.zero?
          say "Story bible is empty. Run 'wr bible regenerate' first.", :yellow
          return
        end

        bible.elements_by_type.each do |type, entries|
          say "\n#{type.capitalize}:", :cyan
          entries.each do |entry|
            aliases_str = entry["aliases"]&.any? ? " (aka #{entry['aliases'].join(', ')})" : ""
            status_str = entry["status"] ? " [#{entry['status']}]" : ""
            say "  #{entry['name']}#{aliases_str}#{status_str}", :white
          end
        end
      end

      desc "search TERM", "Search the story bible for a name or alias"
      def search(term)
        project = Dir.pwd
        bible = WritersRoom::StoryBible.new(project)
        result = bible.resolve(term)

        if result
          say "Found: #{result['name']} (#{result['type']})", :green
          say "  Path: #{result['path']}", :white
          say "  Aliases: #{result['aliases'].join(', ')}", :white if result["aliases"]&.any?
          say "  Status: #{result['status']}", :white if result["status"]
        else
          say "No match for '#{term}'", :yellow
        end
      end
    end
  end
end
