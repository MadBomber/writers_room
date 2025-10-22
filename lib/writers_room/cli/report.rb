# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Report < Thor
      desc "report", "Generate production report from all transcripts"

      def report
        require_relative "../producer"

        producer = WritersRoom::Producer.new
        report_data = producer.generate_report

        if report_data[:total_scenes].zero?
          say "No transcripts found in transcripts/ directory", :yellow
          say "Run 'wr produce' or 'wr direct' to create transcripts", :yellow
          exit 0
        end

        say "=" * 60, :cyan
        say "PRODUCTION REPORT", :cyan
        say "=" * 60, :cyan
        say "Total scenes: #{report_data[:total_scenes]}", :white
        say "Total lines: #{report_data[:total_lines]}", :white
        say ""
        say "Lines by character:", :white

        report_data[:lines_by_character].sort_by { |_, count| -count }.each do |char, count|
          percentage = (count.to_f / report_data[:total_lines] * 100).round(1)
          say "  #{char}: #{count} (#{percentage}%)", :white
        end

        say ""
        say "Transcripts:", :white
        report_data[:transcripts].each do |transcript|
          say "  #{transcript}", :white
        end
        say "=" * 60, :cyan
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      rescue StandardError => e
        say "Error generating report: #{e.message}", :red
        say e.backtrace.join("\n"), :red if ENV["DEBUG"]
        exit 1
      end
    end
  end
end
