require "singleton"

module Workflows
  class Configuration
    include Singleton

    attr_accessor :workflows_path, :videos_output_path, :persona_resolver, :sign_in_adapter,
                  :minio_client, :host_name

    def initialize
      @workflows_path     = nil   # set by host: Rails.root.join("config/workflows")
      @videos_output_path = nil   # set by host: Rails.root.join("tmp/workflow_videos")
      @persona_resolver   = nil   # host-supplied lambda: ->(persona_name) { user_record_or_nil }
      @sign_in_adapter    = nil   # host-supplied lambda: ->(page, user) { signs the user in via playwright }
      @minio_client       = nil   # host-supplied Workflows::MinioClient (or duck-typed equivalent)
      @host_name          = nil   # host-supplied Symbol: :lms or :school_os (used as MinIO key prefix)
    end
  end
end
