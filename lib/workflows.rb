require "workflows/version"
require "workflows/engine"
require "workflows/configuration"

module Workflows
  # Workflows::YamlLoader, ::Workflow, ::Step, ::Compilers, ::Runner, ::Seed
  # are autoloaded by Zeitwerk from lib/workflows/*.rb — see the Zeitwerk
  # configuration in lib/workflows/engine.rb.
  #
  # Workflows::Configuration is required eagerly above because hosts call
  # Workflows.configure { ... } from config/initializers/workflows.rb, which
  # runs at :load_config_initializers — BEFORE :setup_main_autoloader.

  def self.configure
    yield(Configuration.instance)
  end

  def self.config
    Configuration.instance
  end
end
