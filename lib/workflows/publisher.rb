module Workflows
  # Orchestrates render → upload → persist for a single (workflow, locale) on
  # the current commit. Thin layer over Phase 1's RecordMode.
  class Publisher
    def initialize(workflow_name:, locale:,
                   source: nil, pr_number: nil, sha: nil)
      @workflow_name = workflow_name
      @locale        = locale
      @source        = source    || detect_source
      @pr_number     = pr_number || detect_pr_number
      @sha           = sha       || detect_sha
    end

    def call
      raise NotImplementedError, "filled in Task 9"
    end

    private

    # --- Key builders ---

    def host_prefix
      Workflows.config.host_name.to_s
    end

    def flat_name
      @workflow_name.tr("/", "-")
    end

    def source_dir
      @source == "main" ? "main/#{@sha}" : "prs/#{@pr_number}/#{@sha}"
    end

    def mp4_key;           "#{host_prefix}/#{source_dir}/#{flat_name}-#{@locale}.mp4"; end
    def vtt_key;           "#{host_prefix}/#{source_dir}/#{flat_name}-#{@locale}.vtt"; end
    def poster_key;        "#{host_prefix}/#{source_dir}/#{flat_name}-#{@locale}.jpg"; end

    def current_mp4_key;    "#{host_prefix}/current/#{flat_name}-#{@locale}.mp4"; end
    def current_vtt_key;    "#{host_prefix}/current/#{flat_name}-#{@locale}.vtt"; end
    def current_poster_key; "#{host_prefix}/current/#{flat_name}-#{@locale}.jpg"; end

    # --- Environment detection ---

    def detect_sha
      ENV["GITHUB_SHA"].presence || `git rev-parse HEAD 2>/dev/null`.strip.presence || "unknown"
    end

    def detect_pr_number
      ENV["PR_NUMBER"].to_i if ENV["PR_NUMBER"].present?
    end

    def detect_source
      ENV["PR_NUMBER"].present? ? "pr" : "main"
    end
  end
end
