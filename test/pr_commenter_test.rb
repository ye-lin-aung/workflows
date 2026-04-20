require "test_helper"

class Workflows::PrCommenterTest < ActiveSupport::TestCase
  setup do
    Workflows.config.host_name = :lms
    @fake_client = Struct.new(:calls) do
      def signed_url(key, expires_in:)
        "https://minio/#{key}?exp=#{expires_in}"
      end
    end.new([])
    Workflows.config.minio_client = @fake_client
  end

  teardown do
    Workflows.config.host_name = nil
    Workflows.config.minio_client = nil
    Workflows::Video.delete_all
  end

  test "build_markdown produces a <details> block per video" do
    v1 = Workflows::Video.create!(
      workflow_name: "teacher/grade_assignment", locale: "en",
      commit_sha: "a" * 40, source: "pr", pr_number: 42, duration_ms: 5000,
      rendered_at: Time.current,
      mp4_key: "lms/prs/42/aaaa/teacher-grade_assignment-en.mp4",
      vtt_key: "lms/prs/42/aaaa/teacher-grade_assignment-en.vtt",
      poster_key: "lms/prs/42/aaaa/teacher-grade_assignment-en.jpg"
    )
    v2 = Workflows::Video.create!(
      workflow_name: "student/take_assessment", locale: "en",
      commit_sha: "a" * 40, source: "pr", pr_number: 42, duration_ms: 6000,
      rendered_at: Time.current,
      mp4_key: "lms/prs/42/aaaa/student-take_assessment-en.mp4",
      vtt_key: "lms/prs/42/aaaa/student-take_assessment-en.vtt",
      poster_key: "lms/prs/42/aaaa/student-take_assessment-en.jpg"
    )

    md = Workflows::PrCommenter.build_markdown([v1, v2])
    assert_match(/📹 Workflow video previews \(2\)/, md)
    assert_match(%r{<details><summary>teacher/grade_assignment \[en\]</summary>}, md)
    assert_match(%r{<details><summary>student/take_assessment \[en\]</summary>}, md)
    assert_match(%r{\[▶ Watch\]\(https://minio/}, md)
    assert_match(/\[🖼 Poster\]/, md)
    assert_match(/\[📝 VTT\]/, md)
  end

  test "build_markdown returns nil for empty list" do
    assert_nil Workflows::PrCommenter.build_markdown([])
  end

  test ".post skips when no videos are persisted for the PR" do
    result = Workflows::PrCommenter.post(pr_number: 99)
    assert_nil result  # returns early
  end

  test ".post calls Octokit#add_comment with repo + pr_number + body" do
    Workflows::Video.create!(
      workflow_name: "a/b", locale: "en", commit_sha: "x" * 40,
      source: "pr", pr_number: 7, duration_ms: 1, rendered_at: Time.current,
      mp4_key: "lms/prs/7/x/a-b-en.mp4", vtt_key: "lms/prs/7/x/a-b-en.vtt",
      poster_key: "lms/prs/7/x/a-b-en.jpg"
    )

    received = {}
    fake_octokit = Object.new
    fake_octokit.define_singleton_method(:add_comment) do |repo, pr, body|
      received[:repo] = repo; received[:pr] = pr; received[:body] = body
    end

    ENV["GITHUB_REPOSITORY"] = "org/lms"
    ENV["GITHUB_TOKEN"]      = "t"

    # Stub Octokit::Client.new to return our fake
    original = Octokit::Client.method(:new)
    Octokit::Client.singleton_class.send(:define_method, :new) { |**_| fake_octokit }
    begin
      Workflows::PrCommenter.post(pr_number: 7)
    ensure
      Octokit::Client.singleton_class.send(:define_method, :new, original)
    end

    assert_equal "org/lms", received[:repo]
    assert_equal 7, received[:pr]
    assert_match(/📹 Workflow video previews/, received[:body])
  ensure
    ENV.delete("GITHUB_REPOSITORY"); ENV.delete("GITHUB_TOKEN")
  end
end
