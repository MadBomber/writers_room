# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Config < Thor
      desc "config", "Show current configuration"

      def config
        config_path = File.join(Dir.pwd, "config.yml")

        unless File.exist?(config_path)
          say "No config.yml found in current directory.", :yellow
          say "Run 'wr init <project_name>' to create a new project.", :yellow
          exit 1
        end

        config = WritersRoom::Config.new(config_path)
        say "Configuration (#{config_path}):", :cyan
        say "  Provider:   #{config.provider}", :white
        say "  Model:      #{config.model_name}", :white
      rescue StandardError => e
        say "Error reading configuration: #{e.message}", :red
        exit 1
      end
    end
  end
end
