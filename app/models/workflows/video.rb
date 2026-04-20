module Workflows
  class Video < ApplicationRecord
    self.table_name = "workflows_videos"

    validates :workflow_name, :locale, :commit_sha, :source, presence: true
    validates :mp4_key, :vtt_key, :poster_key, :rendered_at, presence: true
    validates :source, inclusion: { in: %w[main pr] }

    scope :current_main, ->(workflow_name, locale) {
      where(workflow_name: workflow_name, locale: locale, source: "main")
        .order(rendered_at: :desc).first
    }

    def mp4_url(expires_in:)
      Workflows.config.minio_client.signed_url(mp4_key, expires_in: expires_in.to_i)
    end

    def vtt_url(expires_in:)
      Workflows.config.minio_client.signed_url(vtt_key, expires_in: expires_in.to_i)
    end

    def poster_url(expires_in:)
      Workflows.config.minio_client.signed_url(poster_key, expires_in: expires_in.to_i)
    end
  end
end
