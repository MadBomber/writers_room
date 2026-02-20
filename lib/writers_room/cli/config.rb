# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Config < Thor
      desc "config", "Show current configuration"

      def config
        cfg = WritersRoom.config
        say "Configuration:", :cyan
        say "  Provider:   #{cfg.provider}", :white
        say "  Model:      #{cfg.model_name}", :white
        say "  Scene max lines: #{cfg.scene.max_lines}", :white
        say "  Scene timeout:   #{cfg.scene.timeout}s", :white
      rescue StandardError => e
        say "Error reading configuration: #{e.message}", :red
        exit 1
      end
    end
  end
end
