require "workflows/version"
require "workflows/engine"
require "workflows/configuration"
require "workflows/minio_client"

module Workflows
  # Workflows::YamlLoader, ::Workflow, ::Step, ::Compilers, ::Runner, ::Seed
  # are autoloaded by Zeitwerk from lib/workflows/*.rb — see the Zeitwerk
  # configuration in lib/workflows/engine.rb.
  #
  # Configuration and MinioClient are required eagerly because hosts
  # instantiate them from config/initializers/workflows.rb, which runs at
  # :load_config_initializers — BEFORE :setup_main_autoloader.

  def self.configure
    yield(Configuration.instance)
  end

  def self.config
    Configuration.instance
  end
end
