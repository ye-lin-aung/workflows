require "yaml"

module Workflows
  # Reads a workflow YAML file, validates the schema strictly, and returns a
  # Workflow value object. Strict: unknown keys at top level or inside a step
  # raise SchemaError. All errors reference the source filename.
  module YamlLoader
    class SchemaError < StandardError; end

    TOP_KEYS_REQUIRED = %w[name title description host persona start_at steps].freeze
    TOP_KEYS_OPTIONAL = %w[viewport setup].freeze
    TOP_KEYS_ALL      = (TOP_KEYS_REQUIRED + TOP_KEYS_OPTIONAL).freeze

    STEP_KEYS_REQUIRED = %w[caption].freeze
    STEP_KEYS_OPTIONAL = %w[action target target_css value wait_for assert hold_ms].freeze
    STEP_KEYS_ALL      = (STEP_KEYS_REQUIRED + STEP_KEYS_OPTIONAL).freeze

    HOSTS = %w[lms school_os].freeze

    class << self
      def load_file(path)
        data = YAML.safe_load_file(path, permitted_classes: [Symbol], aliases: true)
        raise SchemaError, "#{path}: YAML root must be a mapping" unless data.is_a?(Hash)

        validate_top_level!(data, path)
        validate_steps!(data["steps"], path)

        Workflow.new(
          name:        data["name"],
          title:       data["title"],
          description: data["description"],
          host:        data["host"],
          persona:     data["persona"],
          start_at:    data["start_at"],
          viewport:    symbolize_viewport(data["viewport"]),
          setup:       data["setup"],
          steps:       data["steps"].map { |s| build_step(s) }
        )
      rescue Psych::SyntaxError => e
        raise SchemaError, "#{path}: YAML parse error — #{e.message}"
      end

      def load_directory(dir, glob: "**/*.yml")
        return [] unless File.directory?(dir)

        Dir.glob(File.join(dir, glob)).sort.map { |path| load_file(path) }
      end

      private

      def validate_top_level!(data, path)
        missing = TOP_KEYS_REQUIRED - data.keys
        raise SchemaError, "#{path}: missing required keys: #{missing.join(", ")}" if missing.any?

        unknown = data.keys - TOP_KEYS_ALL
        raise SchemaError, "#{path}: unknown top-level keys: #{unknown.join(", ")}" if unknown.any?

        unless HOSTS.include?(data["host"])
          raise SchemaError, "#{path}: host must be one of #{HOSTS.join("/")}; got #{data["host"].inspect}"
        end

        unless data["steps"].is_a?(Array) && data["steps"].any?
          raise SchemaError, "#{path}: steps must be a non-empty array"
        end
      end

      def validate_steps!(steps, path)
        steps.each_with_index do |step, idx|
          raise SchemaError, "#{path}: step #{idx} must be a mapping" unless step.is_a?(Hash)

          missing = STEP_KEYS_REQUIRED - step.keys
          raise SchemaError, "#{path}: step #{idx} missing keys: #{missing.join(", ")}" if missing.any?

          unknown = step.keys - STEP_KEYS_ALL
          raise SchemaError, "#{path}: step #{idx} unknown keys: #{unknown.join(", ")}" if unknown.any?

          action = step["action"] || "none"
          unless Step::ALLOWED_ACTIONS.include?(action.to_s)
            raise SchemaError, "#{path}: step #{idx} action #{action.inspect} not in #{Step::ALLOWED_ACTIONS.join("/")}"
          end

          if %w[fill select].include?(action.to_s) && step["value"].nil?
            raise SchemaError, "#{path}: step #{idx} action=#{action} requires a value"
          end

          if action.to_s != "none" && step["target"].nil? && step["target_css"].nil?
            raise SchemaError, "#{path}: step #{idx} action=#{action} requires target or target_css"
          end
        end
      end

      def build_step(hash)
        Step.new(
          caption:    hash["caption"],
          action:     hash["action"] || "none",
          target:     hash["target"],
          target_css: hash["target_css"],
          value:      hash["value"],
          wait_for:   symbolize_keys(hash["wait_for"]),
          assert:     symbolize_keys(hash["assert"]),
          hold_ms:    hash["hold_ms"]
        )
      end

      def symbolize_viewport(hash)
        return nil if hash.nil?
        { width: hash["width"] || hash[:width], height: hash["height"] || hash[:height] }
      end

      def symbolize_keys(hash)
        return nil if hash.nil?
        hash.transform_keys(&:to_sym)
      end
    end
  end
end
