# frozen_string_literal: true

module WritersRoom
  # Data class representing a creative writing medium type.
  # Loaded from YAML config files in config/media/.
  class Medium
    attr_reader :id, :label, :universal_elements, :specific_elements,
                :scaffolded_dirs, :workflows, :statuses

    def initialize(id:, label:, universal_elements: [], specific_elements: {},
                   scaffolded_dirs: [], workflows: [], statuses: [])
      @id                 = id.to_sym
      @label              = label.to_s
      @universal_elements = Array(universal_elements).map(&:to_sym)
      @specific_elements  = normalize_specific_elements(specific_elements)
      @scaffolded_dirs    = Array(scaffolded_dirs).map(&:to_s)
      @workflows          = Array(workflows).map(&:to_sym)
      @statuses           = Array(statuses).map(&:to_s)
    end

    def self.from_yaml(hash)
      new(
        id:                 hash["id"],
        label:              hash["label"],
        universal_elements: hash["universal_elements"],
        specific_elements:  hash["specific_elements"],
        scaffolded_dirs:    hash["scaffolded_dirs"],
        workflows:          hash["workflows"],
        statuses:           hash["statuses"]
      )
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
  end
end
