require "rails/generators/base"
require "rails/generators/active_record/migration/migration_generator"

module Workflows
  module Generators
    class InstallGenerator < ::Rails::Generators::Base
      include ::Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_migration
        migration_template(
          "create_workflows_videos.rb.tt",
          "db/migrate/create_workflows_videos.rb",
          migration_version: migration_version
        )
      end

      def show_readme
        say ""
        say "workflows gem installed.", :green
        say ""
        say "Next steps:"
        say "  1. Run migrations:"
        say "       bin/rails db:migrate"
        say "  2. Set MinIO env vars (WORKFLOWS_MINIO_ENDPOINT, WORKFLOWS_MINIO_ACCESS_KEY, WORKFLOWS_MINIO_SECRET_KEY)"
        say "  3. Add `config.host_name` and `config.minio_client` in config/initializers/workflows.rb"
        say ""
      end

      private

      def migration_version
        ActiveRecord::Migration.current_version
      end
    end
  end
end
