# frozen_string_literal: true

module WritersRoom
  module Formatters
    # Formats a novel project into a manuscript-style document.
    class NovelFormatter < BaseFormatter
      def table_of_contents
        chapters = load_elements("chapters")
        return nil if chapters.empty?

        lines = ["## Table of Contents\n"]
        chapters.sort_by { |c| c.metadata[:chapter_number] || c.metadata["chapter_number"] || 0 }.each_with_index do |ch, i|
          lines << "#{i + 1}. #{ch.name}"
        end
        lines.join("\n")
      end

      def body_sections
        sections = []

        # Characters section
        characters = load_elements("characters")
        if characters.any?
          sections << format_characters(characters)
        end

        # Chapters
        chapters = load_elements("chapters")
        chapters.sort_by { |c| c.metadata[:chapter_number] || c.metadata["chapter_number"] || 0 }.each do |ch|
          sections << format_chapter(ch)
        end

        sections
      end

      private

      def format_characters(characters)
        lines = ["## Characters\n"]
        characters.each do |ch|
          lines << "### #{ch.name}"
          lines << ch.body unless ch.body.empty?
          lines << ""
        end
        lines.join("\n")
      end

      def format_chapter(chapter)
        num = chapter.metadata[:chapter_number] || chapter.metadata["chapter_number"]
        header = num ? "## Chapter #{num}: #{chapter.name}" : "## #{chapter.name}"

        "#{header}\n\n#{chapter.body}"
      end
    end
  end
end
