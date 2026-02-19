# frozen_string_literal: true

require "yaml"

module WritersRoom
  # Parses and renders Markdown files with YAML front matter.
  #
  # Front matter is delimited by `---` at the start of the file:
  #
  #   ---
  #   title: My Document
  #   tags: [a, b]
  #   ---
  #
  #   Body content here.
  #
  module FrontMatter
    module_function

    # Parse a string containing front matter + body.
    #
    # @param content [String] raw file content
    # @param symbolize_keys [Boolean] convert metadata keys to symbols (default: true)
    # @return [Hash] { metadata: Hash, body: String }
    def parse(content, symbolize_keys: true)
      content = content.to_s

      unless content.start_with?("---")
        return { metadata: {}, body: content.strip }
      end

      # Split on the closing `---` delimiter (second occurrence)
      parts = content.split(/^---\s*$/, 3)

      # parts[0] is empty (before first ---), parts[1] is YAML, parts[2] is body
      if parts.length >= 3
        raw_meta = YAML.safe_load(parts[1], permitted_classes: [Date, Time, Symbol]) || {}
        body = parts[2].to_s.strip
      else
        raw_meta = {}
        body = content.strip
      end

      metadata = symbolize_keys ? deep_symbolize_keys(raw_meta) : raw_meta

      { metadata: metadata, body: body }
    end

    # Load and parse a file with front matter.
    #
    # @param path [String] file path
    # @param symbolize_keys [Boolean] convert metadata keys to symbols (default: true)
    # @return [Hash] { metadata: Hash, body: String }
    def load_file(path, symbolize_keys: true)
      content = File.read(path)
      parse(content, symbolize_keys: symbolize_keys)
    end

    # Render metadata + body back to a front matter string.
    #
    # @param metadata [Hash] YAML metadata
    # @param body [String] markdown body
    # @return [String] rendered content
    def dump(metadata, body = "")
      meta_str = metadata.empty? ? "" : stringify_keys(metadata).to_yaml.sub(/^---\n/, "")
      result = "---\n#{meta_str}---\n"
      result += "\n#{body}\n" unless body.empty?
      result
    end

    # @api private
    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize_keys(v) }
      when Array
        obj.map { |v| deep_symbolize_keys(v) }
      else
        obj
      end
    end

    # @api private
    def stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
  end
end
