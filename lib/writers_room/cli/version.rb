# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Version < Thor
      desc "version", "Show WritersRoom version"
      def version
        puts "WritersRoom #{WritersRoom::VERSION}"
      end
    end
  end
end
