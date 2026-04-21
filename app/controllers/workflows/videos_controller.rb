module Workflows
  class VideosController < ActionController::Base
    # Public page — no auth. We inherit from ActionController::Base instead of
    # the host's ApplicationController so Devise/session before_actions don't
    # fire.
    layout false
    allow_browser versions: :modern, if: -> { respond_to?(:allow_browser) }

    def index
      @by_role = Workflows::Video
        .where(source: "main")
        .order(workflow_name: :asc, rendered_at: :desc)
        .group_by { |v| v.workflow_name.split("/").first }
      @roles = @by_role.keys.sort
      @host  = Workflows.config.host_name.to_s.tr("_", " ").titleize
    end
  end
end
