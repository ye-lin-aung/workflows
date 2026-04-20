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
  end
end
