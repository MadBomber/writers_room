# frozen_string_literal: true

module WritersRoom
  module Formatters
    # Base class for medium-specific output formatters.
    class BaseFormatter
      attr_reader :project_path, :medium, :metadata

      def initialize(project_path)
        @project_path = File.expand_path(project_path)
        @metadata     = ProjectMetadata.new(@project_path)
        @medium       = MediumRegistry.find(@metadata.medium.to_sym) rescue MediumRegistry.find(:dialog)
      end

      def format
        sections = []
        sections << title_page
        sections << table_of_contents
        sections.concat(body_sections)
        sections.compact.join("\n\n---\n\n")
      end

      def export(output_path)
        content = format
        File.write(output_path, content)
        output_path
      end

      protected

      def title_page
        <<~PAGE
          # #{@metadata.name}

          *Medium: #{@medium.label}*
          *Generated: #{Time.now}*
        PAGE
      end

      def table_of_contents
        nil
      end

      def body_sections
        []
      end

      def load_elements(dir_name)
        dir = File.join(@project_path, dir_name)
        return [] unless Dir.exist?(dir)
        ElementCollection.new(dir, element_type: dir_name).all
      end
    end
  end
end
