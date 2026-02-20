# frozen_string_literal: true

require "yaml"

module WritersRoom
  # Registry of available medium types, loaded from YAML config files.
  # Lazy-loads on first access.
  module MediumRegistry
    MEDIA_CONFIG_DIR = File.expand_path("config/media", __dir__)

    class << self
      def find(id)
        media_map[id.to_sym] || raise(Error, "Unknown medium: #{id}")
      end

      def all
        media_map.values
      end

      def ids
        media_map.keys
      end

      def reset!
        @media_map = nil
      end

      private

      def media_map
        @media_map ||= load_all
      end

      def load_all
        result = {}

        Dir.glob(File.join(MEDIA_CONFIG_DIR, "*.yml")).each do |path|
          yaml = YAML.safe_load_file(path)
          medium = Medium.from_yaml(yaml)
          result[medium.id] = medium
        end

        result
      end
    end
  end
end
