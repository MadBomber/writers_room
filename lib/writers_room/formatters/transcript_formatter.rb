# frozen_string_literal: true

module WritersRoom
  module Formatters
    # Formats dialog/transcript projects.
    class TranscriptFormatter < BaseFormatter
      def body_sections
        sections = []

        # Include scene transcripts
        transcripts_dir = File.join(@project_path, "transcripts")
        if Dir.exist?(transcripts_dir)
          Dir.glob(File.join(transcripts_dir, "*.{txt,md}")).sort.each do |file|
            sections << "### #{File.basename(file)}\n\n#{File.read(file)}"
          end
        end

        sections
      end
    end
  end
end
