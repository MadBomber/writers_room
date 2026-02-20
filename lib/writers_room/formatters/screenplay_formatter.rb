# frozen_string_literal: true

module WritersRoom
  module Formatters
    # Formats a screenplay project into industry-standard-ish output.
    class ScreenplayFormatter < BaseFormatter
      def title_page
        <<~PAGE
          #{@metadata.name.upcase}



          Written by
          [Author Name]



          *Generated: #{Time.now}*
        PAGE
      end

      def body_sections
        sections = []

        scenes = load_elements("scenes")
        scenes.each do |scene|
          sections << format_scene(scene)
        end

        sections
      end

      private

      def format_scene(scene)
        location = scene.metadata[:location] || scene.metadata["location"] || "UNKNOWN"
        lines = []
        lines << "#{location.upcase}"
        lines << ""
        lines << scene.body unless scene.body.empty?
        lines.join("\n")
      end
    end
  end
end
