require "test_helper"

class Workflows::PublisherTest < ActiveSupport::TestCase
  setup do
    Workflows.config.host_name = :lms
  end

  teardown do
    Workflows.config.host_name = nil
  end

  test "mp4_key for main source" do
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment",
      locale: "en",
      source: "main",
      sha: "a" * 40
    )
    assert_equal "lms/main/#{"a" * 40}/teacher-grade_assignment-en.mp4", p.send(:mp4_key)
  end

  test "mp4_key for pr source includes pr_number" do
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment",
      locale: "es",
      source: "pr",
      pr_number: 42,
      sha: "b" * 40
    )
    assert_equal "lms/prs/42/#{"b" * 40}/teacher-grade_assignment-es.mp4", p.send(:mp4_key)
  end

  test "current_mp4_key is prefix/current regardless of source" do
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment", locale: "en", source: "main", sha: "x" * 40
    )
    assert_equal "lms/current/teacher-grade_assignment-en.mp4", p.send(:current_mp4_key)
  end

  test "flat_name replaces slashes with hyphens" do
    p = Workflows::Publisher.new(
      workflow_name: "a/b/c", locale: "en", source: "main", sha: "x" * 40
    )
    assert_equal "a-b-c", p.send(:flat_name)
  end

  test "vtt and poster keys share the source_dir with mp4" do
    p = Workflows::Publisher.new(
      workflow_name: "student/take_assessment",
      locale: "en", source: "pr", pr_number: 7, sha: "z" * 40
    )
    prefix = "lms/prs/7/#{"z" * 40}/student-take_assessment-en"
    assert_equal "#{prefix}.mp4", p.send(:mp4_key)
    assert_equal "#{prefix}.vtt", p.send(:vtt_key)
    assert_equal "#{prefix}.jpg", p.send(:poster_key)
  end

  test "detect_source returns pr when PR_NUMBER env set" do
    ENV["PR_NUMBER"] = "101"
    ENV["GITHUB_SHA"] = "c" * 40
    p = Workflows::Publisher.new(workflow_name: "x/y", locale: "en")
    assert_equal "pr", p.instance_variable_get(:@source)
    assert_equal 101, p.instance_variable_get(:@pr_number)
  ensure
    ENV.delete("PR_NUMBER"); ENV.delete("GITHUB_SHA")
  end

  test "detect_source returns main when PR_NUMBER absent" do
    ENV.delete("PR_NUMBER")
    ENV["GITHUB_SHA"] = "d" * 40
    p = Workflows::Publisher.new(workflow_name: "x/y", locale: "en")
    assert_equal "main", p.instance_variable_get(:@source)
    assert_nil p.instance_variable_get(:@pr_number)
  ensure
    ENV.delete("GITHUB_SHA")
  end
end
