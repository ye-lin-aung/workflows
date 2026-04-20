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

    # --- Rendering ---

    def yaml_path
      File.join(Workflows.config.workflows_path.to_s, "#{@workflow_name}.yml")
    end

    def render_video
      I18n.with_locale(@locale) do
        workflow = Workflows::YamlLoader.load_file(yaml_path)
        Workflows::Runner::RecordMode.new(
          workflow:   workflow,
          output_dir: Dir.mktmpdir("workflow-publish")
        ).run
      end
    end

    # --- Poster extraction ---

    def extract_poster(mp4_path)
      duration_s  = ffprobe_duration(mp4_path)
      timestamp   = (duration_s * 0.30).round(3)
      poster_path = mp4_path.sub(/\.mp4\z/, ".jpg")
      run_ffmpeg("-y", "-ss", timestamp.to_s, "-i", mp4_path,
                 "-frames:v", "1", "-q:v", "2", poster_path) ||
        raise("ffmpeg poster extraction failed for #{mp4_path}")
      poster_path
    end

    def ffprobe_duration(mp4_path)
      out = `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "#{mp4_path}" 2>/dev/null`
      out.to_f
    end

    def run_ffmpeg(*args)
      system("ffmpeg", *args, out: File::NULL, err: File::NULL)
    end
  end
end
