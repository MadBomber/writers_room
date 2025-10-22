# frozen_string_literal: true

require_relative "lib/writers_room/version"

Gem::Specification.new do |spec|
  spec.name = "writers_room"
  spec.version = WritersRoom::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "A Ruby gem for managing a writers' room"
  spec.description = "under development"
  spec.homepage = "https://github.com/madbomber/writers_room"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/madbomber/writers_room"
  spec.metadata["changelog_uri"] = "https://github.com/madbomber/writers_room/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[test/ spec/ features/ .git .github appvesor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = ["wr"]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "zeitwerk", "~> 2.6"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "ruby_llm", ">= 1.8"
  spec.add_dependency "debug_me", ">= 1.0"
  spec.add_dependency "redis", ">= 5.0"
  spec.add_dependency "smart_message", ">= 0.0.17"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
