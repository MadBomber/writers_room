# frozen_string_literal: true

require "thor"

module WritersRoom
  module Commands
    class Chat < Thor
      desc "chat", "Start a context-aware interactive writing session"

      def chat
        context = WritersRoom::ContextDetector.new.detect

        if context.in_project?
          start_project_chat(context)
        else
          start_init_chat
        end
      rescue StandardError => e
        say "Error starting chat: #{e.message}", :red
        say e.backtrace.first(5).join("\n"), :red if ENV["DEBUG"]
        exit 1
      end

      private

      def start_project_chat(context)
        medium = context.medium
        state  = context.project_state
        metadata = WritersRoom::ProjectMetadata.new(context.project_path)

        chat_context = {
          project_name:  metadata.name,
          medium_id:     medium.id.to_s,
          medium_label:  medium.label,
          concept:       metadata.concept,
          project_state: state.summary
        }

        if context.element_type
          chat_context[:element_type] = context.element_type
          dir = File.join(context.project_path, context.element_type.to_s)
          collection = WritersRoom::ElementCollection.new(dir, element_type: context.element_type)
          chat_context[:existing_elements] = collection.list
          chat_context[:element_contents] = load_element_contents(collection)
          template = :context_chat_element
        else
          chat_context[:project_elements] = load_project_elements(context.project_path, medium)
          template = :context_chat_root
        end

        session = WritersRoom::ChatSession.new(
          context: chat_context,
          template: template,
          project_path: context.project_path
        )
        session.start

        save_chat_log(context.project_path, session)
      end

      def start_init_chat
        chat_context = {
          media_types: WritersRoom::MediumRegistry.all
        }

        session = WritersRoom::ChatSession.new(context: chat_context, template: :context_chat_init)
        session.start
      end

      def load_project_elements(project_path, medium)
        elements_by_type = {}
        medium.scaffolded_dirs.each do |dir_name|
          dir = File.join(project_path, dir_name)
          next unless Dir.exist?(dir)
          collection = WritersRoom::ElementCollection.new(dir, element_type: dir_name)
          contents = load_element_contents(collection)
          elements_by_type[dir_name] = contents if contents.any?
        end
        elements_by_type
      end

      def load_element_contents(collection)
        collection.all.map { |el|
          {
            name: el.name,
            slug: el.slug,
            status: el.status,
            aliases: el.aliases,
            body: el.body
          }
        }
      end

      def save_chat_log(project_path, session)
        return if session.messages.empty?

        log_dir = File.join(project_path, "transcripts")
        FileUtils.mkdir_p(log_dir)
        log_path = File.join(log_dir, "chat_#{Time.now.to_i}.md")
        session.save(log_path)
      end
    end
  end
end
