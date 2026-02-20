# frozen_string_literal: true

module WritersRoom
  # Cross-collection alias resolution.
  # Searches multiple ElementCollections to resolve a name or alias.
  class AliasResolver
    def initialize(collections)
      @collections = Array(collections)
    end

    # Resolve a name/alias to a single Element.
    # Returns the element if unambiguous, raises if ambiguous or not found.
    def resolve(query)
      candidates = find_all(query)

      case candidates.length
      when 0
        nil
      when 1
        candidates.first
      else
        raise Error, "Ambiguous name '#{query}'. Matches: #{candidates.map(&:name).join(', ')}"
      end
    end

    # Find all elements matching the query across all collections.
    def find_all(query)
      @collections.flat_map { |col| col.search(query) }.uniq { |el| el.path }
    end

    # Check whether a query resolves unambiguously.
    def resolvable?(query)
      find_all(query).length == 1
    end

    # Add a collection to the resolver.
    def add_collection(collection)
      @collections << collection
    end
  end
end
