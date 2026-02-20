# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    # Generic element management subcommand.
    # A single class handles all element types, registered dynamically per medium.
    class Element < Thor
      class_option :project,
                   type: :string,
                   desc: "Project directory (default: current directory)"

      desc "create NAME", "Create a new element"
      method_option :status,
                    type: :string,
                    default: "draft",
                    desc: "Initial status"
      method_option :body,
                    type: :string,
                    default: "",
                    desc: "Body content"
      def create(name)
        collection = build_collection
        el = collection.create(name,
          metadata: { "status" => options[:status] },
          body: options[:body])

        say "Created #{element_type}: #{el.name} (#{el.path})", :green
      rescue WritersRoom::Error => e
        say "Error: #{e.message}", :red
        exit 1
      end

      desc "list", "List all elements of this type"
      def list
        collection = build_collection
        elements = collection.list

        if elements.empty?
          say "No #{element_type} found.", :yellow
          return
        end

        elements.each do |el|
          status_tag = el[:status] ? " [#{el[:status]}]" : ""
          say "  #{el[:name]}#{status_tag} (#{el[:slug]})", :white
        end
      end

      desc "show SLUG", "Show details of an element"
      def show(slug)
        collection = build_collection
        el = collection.find_by_slug(slug) || collection.find_by_name_or_alias(slug)

        unless el
          say "Not found: #{slug}", :red
          exit 1
        end

        say "#{el.name}", :green
        say "  Slug: #{el.slug}", :white
        say "  Status: #{el.status || 'none'}", :white
        say "  Aliases: #{el.aliases.join(', ')}", :white unless el.aliases.empty?
        say "  Version: #{el.version}", :white if el.version
        say "  Path: #{el.path}", :white
        say "" unless el.body.empty?
        say el.body unless el.body.empty?
      end

      desc "version SLUG", "Create a new version of an element"
      method_option :status,
                    type: :string,
                    default: "draft",
                    desc: "Status for the new version"
      def version(slug)
        collection = build_collection
        el = collection.find_by_slug(slug)

        unless el
          say "Not found: #{slug}", :red
          exit 1
        end

        versioner = WritersRoom::Versioner.new(File.dirname(el.path), slug)
        based_on = versioner.latest_version ? File.basename(versioner.latest_version) : nil

        new_version = versioner.create_new_version(
          metadata: { "name" => el.name, "status" => options[:status] },
          based_on: based_on
        )

        say "Created version #{new_version.version} of #{el.name}", :green
        say "  Path: #{new_version.path}", :white
      end

      desc "status SLUG NEW_STATUS", "Update the status of an element"
      def status(slug, new_status)
        collection = build_collection
        el = collection.find_by_slug(slug)

        unless el
          say "Not found: #{slug}", :red
          exit 1
        end

        el.metadata[:status] = new_status
        el.save

        say "Updated #{el.name} status to: #{new_status}", :green
      end

      no_commands do
        def element_type
          self.class.instance_variable_get(:@element_type_name) || "element"
        end

        def build_collection
          project = options[:project] || Dir.pwd
          dir = File.join(project, dir_for_element_type(project))
          WritersRoom::ElementCollection.new(dir, element_type: element_type.to_sym)
        end

        def dir_for_element_type(project)
          # Try medium-specific element config first
          begin
            metadata = WritersRoom::ProjectMetadata.new(project)
            medium = WritersRoom::MediumRegistry.find(metadata.medium)

            # Check specific_elements for a dir mapping
            medium.specific_elements.each do |_key, config|
              if config["singular"] == element_type || _key == element_type
                return config["dir"] || _key
              end
            end

            # Check scaffolded_dirs for a matching plural
            plural = "#{element_type}s"
            return plural if medium.scaffolded_dirs.include?(plural)
          rescue StandardError
            # Fall through
          end

          # Default: try plural form if dir exists, else singular
          plural = "#{element_type}s"
          Dir.exist?(File.join(project, plural)) ? plural : element_type
        end
      end

      # Factory method to create a subclass for a specific element type.
      # Assigns the class to a constant under Commands so Thor can display
      # a human-readable name instead of an anonymous class reference.
      def self.for_type(type_name)
        const_name = type_name.to_s.split("_").map(&:capitalize).join
        if Commands.const_defined?(const_name, false)
          return Commands.const_get(const_name, false)
        end

        klass = Class.new(self) do
          namespace type_name.to_s
        end
        klass.instance_variable_set(:@element_type_name, type_name.to_s)
        Commands.const_set(const_name, klass)
        klass
      end
    end
  end
end
