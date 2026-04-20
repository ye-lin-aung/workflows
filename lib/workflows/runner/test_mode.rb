module Workflows
  module Runner
    # Runs a workflow as a Minitest system test. Loaded by generated files
    # in the host app's test/system/workflows/ tree.
    #
    # The host must have configured:
    #   Workflows.config.workflows_path   — root of config/workflows YAML
    #   Workflows.config.persona_resolver — ->(persona_key) { user_record or nil }
    #   Workflows.config.sign_in_adapter  — ->(page, user) { signs in via Playwright }
    class TestMode
      PersonaNotFound = Class.new(StandardError)

      def initialize(workflow_name)
        @name = workflow_name
      end

      def run(system_test)
        workflow = load_workflow
        apply_setup(workflow)
        user = resolve_persona(workflow.persona)
        adapter = build_adapter(workflow.viewport, system_test)
        adapter.start
        begin
          Workflows.config.sign_in_adapter.call(adapter, user)
          adapter.goto(build_start_url(workflow, system_test))
          Base.new(adapter: adapter).execute(workflow)
        ensure
          adapter.stop
        end
      end

      private

      def load_workflow
        path = File.join(Workflows.config.workflows_path.to_s, "#{@name}.yml")
        raise "workflow not found: #{path}" unless File.exist?(path)
        YamlLoader.load_file(path)
      end

      def apply_setup(workflow)
        workflow.setup.each do |spec|
          klass_name = spec["factory"] || spec[:factory]
          attrs      = (spec["attrs"] || spec[:attrs] || {}).transform_keys(&:to_sym)
          model = klass_name.to_s.classify.safe_constantize
          raise "setup: unknown factory class #{klass_name}" unless model
          model.create!(attrs)
        end
      end

      def resolve_persona(key)
        resolver = Workflows.config.persona_resolver
        raise "Workflows.config.persona_resolver is not set" unless resolver

        user = resolver.call(key)
        raise PersonaNotFound, "persona not found: #{key}" unless user
        user
      end

      def build_adapter(viewport, system_test)
        PlaywrightAdapter.new(headless: true, viewport: viewport)
      end

      def build_start_url(workflow, system_test)
        # Evaluate the Ruby helper in the context of the host's URL helpers.
        path = Rails.application.routes.url_helpers.instance_eval(workflow.start_at)
        "http://#{system_test.host}:#{system_test.port}#{path}"
      end
    end
  end
end
