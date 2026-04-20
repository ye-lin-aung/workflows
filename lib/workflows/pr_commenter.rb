require "octokit"

module Workflows
  # Posts a Markdown comment on a GitHub PR listing rendered workflow video previews.
  class PrCommenter
    PR_SIGNED_URL_EXPIRY = 7 * 24 * 3600

    def self.post(pr_number:)
      videos = Workflows::Video
        .where(pr_number: pr_number, source: "pr")
        .order(:workflow_name, :locale)
      return if videos.empty?

      body = build_markdown(videos)
      return unless body

      client = Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
      client.add_comment(
        ENV.fetch("GITHUB_REPOSITORY"),
        pr_number,
        body
      )
    end

    def self.build_markdown(videos)
      return nil if videos.empty?

      lines = ["📹 Workflow video previews (#{videos.size})", ""]
      videos.each do |v|
        lines << "<details><summary>#{v.workflow_name} [#{v.locale}]</summary>"
        lines << ""
        lines << "[▶ Watch](#{v.mp4_url(expires_in: PR_SIGNED_URL_EXPIRY)}) · " \
                 "[🖼 Poster](#{v.poster_url(expires_in: PR_SIGNED_URL_EXPIRY)}) · " \
                 "[📝 VTT](#{v.vtt_url(expires_in: PR_SIGNED_URL_EXPIRY)})"
        lines << "</details>"
      end
      lines.join("\n")
    end
  end
end
