require "yaml"

module Workflows
  module Prospect
    class Catalog
      DuplicateId = Class.new(StandardError)

      attr_reader :entries

      def self.load_file(path)
        raw = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
        new(raw.fetch("questions", []))
      end

      def initialize(raw_entries)
        seen = {}
        @entries = raw_entries.map do |h|
          entry = CatalogEntry.new(h)
          raise DuplicateId, "duplicate id: #{entry.id}" if seen[entry.id]
          seen[entry.id] = true
          entry
        end
      end

      # Optional filters: {persona_prefix: "admin", id_suffix: "create_school"}
      def filter(persona_prefix: nil, id_suffix: nil)
        entries.select do |e|
          (persona_prefix.nil? || e.persona.to_s.start_with?(persona_prefix.to_s)) &&
            (id_suffix.nil? || e.id.end_with?(id_suffix.to_s))
        end
      end
    end
  end
end
