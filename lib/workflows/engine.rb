module Workflows
  class Engine < ::Rails::Engine
    isolate_namespace Workflows

    # Zeitwerk autoload root for pure-Ruby classes under lib/workflows/*.rb.
    # Mirrors the tutorials gem's pattern — version.rb is excluded because it
    # defines a VERSION constant inside the module rather than following the
    # filename-to-constant convention.
    initializer "workflows.zeitwerk_lib", before: :set_autoload_paths do
      loader = Rails.autoloaders.main
      lib_workflows = root.join("lib/workflows").to_s
      loader.push_dir(lib_workflows, namespace: Workflows)
      loader.ignore(root.join("lib/workflows/version.rb").to_s)
    end

    # Load rake tasks into the host app.
    rake_tasks do
      load File.expand_path("../tasks/workflows.rake", __dir__)
    end

    # Don't auto-append migrations — this gem has none in Phase 1.
    def append_migrations(app)
    end

    # Hand the tutorials gem a callable that projects our workflow YAML into
    # tour hashes. When tutorials' SourceResolver runs it will include these
    # alongside any legacy config/tours/*.yml files.
    initializer "workflows.register_tutorials_hook", after: :load_config_initializers do
      next unless defined?(::Tutorials::SourceResolver)

      ::Tutorials::SourceResolver.register_hook(lambda do |workflows_dir|
        next [] unless workflows_dir && File.directory?(workflows_dir)
        Workflows::YamlLoader.load_directory(workflows_dir).map do |wf|
          Workflows::Compilers::Tour.call(wf)
        end
      end)
    end
  end
end
