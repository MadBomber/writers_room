# frozen_string_literal: true

module WritersRoom
  # Data class representing a creative writing medium type.
  # Loaded from YAML config files in config/media/.
  class Medium
    attr_reader :id, :label, :universal_elements, :specific_elements,
                :scaffolded_dirs, :workflows, :statuses, :chat_specialists

    def initialize(id:, label:, universal_elements: [], specific_elements: {},
                   scaffolded_dirs: [], workflows: [], statuses: [],
                   chat_specialists: [])
      @id                 = id.to_sym
      @label              = label.to_s
      @universal_elements = Array(universal_elements).map(&:to_sym)
      @specific_elements  = normalize_specific_elements(specific_elements)
      @scaffolded_dirs    = Array(scaffolded_dirs).map(&:to_s)
      @workflows          = Array(workflows).map(&:to_sym)
      @statuses           = Array(statuses).map(&:to_s)
      @chat_specialists   = normalize_chat_specialists(chat_specialists)
    end

    def self.from_yaml(hash)
      new(
        id:                 hash["id"],
        label:              hash["label"],
        universal_elements: hash["universal_elements"],
        specific_elements:  hash["specific_elements"],
        scaffolded_dirs:    hash["scaffolded_dirs"],
        workflows:          hash["workflows"],
        statuses:           hash["statuses"],
        chat_specialists:   hash["chat_specialists"]
      )
    end

    def has_chat_specialists?
      @chat_specialists.any?
    end

    def to_s
      label
    end

    def inspect
      "#<#{self.class} id=#{id.inspect} label=#{label.inspect}>"
    end

    private

    def normalize_specific_elements(elements)
      return {} unless elements.is_a?(Hash)

      elements.transform_keys(&:to_s)
    end

    def normalize_chat_specialists(specialists)
      return [] unless specialists.is_a?(Array)

      specialists.map do |entry|
        next unless entry.is_a?(Hash)
        entry.transform_keys(&:to_sym)
      end.compact
    end
  end
end
