require "test_helper"
require "tempfile"

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

  test "render_video delegates to RecordMode under I18n.with_locale" do
    captured_locale = nil
    fake_result = { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }

    fake_workflow = Object.new
    fake_record_mode_instance = Object.new
    fake_record_mode_instance.define_singleton_method(:run) do
      captured_locale = I18n.locale
      fake_result
    end

    prev_available = I18n.available_locales
    I18n.available_locales = (prev_available + [:es]).uniq

    # Stub class methods by swapping the singleton method and restoring in ensure.
    loader_sc = Workflows::YamlLoader.singleton_class
    loader_sc.send(:alias_method, :__orig_load_file, :load_file)
    loader_sc.send(:define_method, :load_file) { |_path| fake_workflow }

    rm_sc = Workflows::Runner::RecordMode.singleton_class
    rm_sc.send(:alias_method, :__orig_new, :new)
    rm_sc.send(:define_method, :new) { |**_kw| fake_record_mode_instance }

    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment",
      locale: "es", source: "main", sha: "a" * 40
    )
    result = p.send(:render_video)
    assert_equal fake_result, result
    assert_equal :es, captured_locale
  ensure
    I18n.available_locales = prev_available if prev_available
    if Workflows::YamlLoader.singleton_class.method_defined?(:__orig_load_file) ||
       Workflows::YamlLoader.singleton_class.private_method_defined?(:__orig_load_file)
      Workflows::YamlLoader.singleton_class.send(:alias_method, :load_file, :__orig_load_file)
      Workflows::YamlLoader.singleton_class.send(:remove_method, :__orig_load_file)
    end
    if Workflows::Runner::RecordMode.singleton_class.method_defined?(:__orig_new) ||
       Workflows::Runner::RecordMode.singleton_class.private_method_defined?(:__orig_new)
      Workflows::Runner::RecordMode.singleton_class.send(:alias_method, :new, :__orig_new)
      Workflows::Runner::RecordMode.singleton_class.send(:remove_method, :__orig_new)
    end
  end

  test "extract_poster runs ffmpeg and returns the jpg path" do
    p = Workflows::Publisher.new(
      workflow_name: "x/y", locale: "en", source: "main", sha: "a" * 40
    )

    Tempfile.create(["fake", ".mp4"]) do |f|
      f.write("x"); f.close
      p.define_singleton_method(:ffprobe_duration) { |_| 10.0 }

      system_args = nil
      p.define_singleton_method(:run_ffmpeg) { |*args| system_args = args; true }
      poster_path = p.send(:extract_poster, f.path)
      assert_equal f.path.sub(/\.mp4\z/, ".jpg"), poster_path
      assert system_args, "expected ffmpeg to be invoked"
      assert_includes system_args, "-ss"
    end
  end

  test "upload_all uploads mp4 + vtt + poster to source_dir keys" do
    uploads = []
    fake_client = Object.new
    fake_client.define_singleton_method(:upload) do |key:, path:, content_type:|
      uploads << { key: key, path: path, content_type: content_type }
    end

    Workflows.config.minio_client = fake_client
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment", locale: "en",
      source: "pr", pr_number: 42, sha: "a" * 40
    )
    p.send(:upload_all, { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }, "/tmp/a.jpg")

    assert_equal 3, uploads.size
    keys = uploads.map { |u| u[:key] }
    assert_includes keys, "lms/prs/42/#{"a" * 40}/teacher-grade_assignment-en.mp4"
    assert_includes keys, "lms/prs/42/#{"a" * 40}/teacher-grade_assignment-en.vtt"
    assert_includes keys, "lms/prs/42/#{"a" * 40}/teacher-grade_assignment-en.jpg"
  ensure
    Workflows.config.minio_client = nil
  end

  test "upload_all also writes current/ keys on main" do
    uploads = []
    fake_client = Object.new
    fake_client.define_singleton_method(:upload) do |key:, path:, content_type:|
      uploads << key
    end

    Workflows.config.minio_client = fake_client
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment", locale: "en",
      source: "main", sha: "a" * 40
    )
    p.send(:upload_all, { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }, "/tmp/a.jpg")

    assert_equal 6, uploads.size
    assert_includes uploads, "lms/current/teacher-grade_assignment-en.mp4"
    assert_includes uploads, "lms/current/teacher-grade_assignment-en.vtt"
    assert_includes uploads, "lms/current/teacher-grade_assignment-en.jpg"
  ensure
    Workflows.config.minio_client = nil
  end

  test "persist_record creates a Workflows::Video row with correct keys" do
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment", locale: "en",
      source: "main", sha: "a" * 40
    )
    p.define_singleton_method(:webvtt_duration) { |_| 5432 }

    record = p.send(:persist_record, { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }, "/tmp/a.jpg")

    assert_equal "teacher/grade_assignment", record.workflow_name
    assert_equal "en",                       record.locale
    assert_equal "a" * 40,                   record.commit_sha
    assert_equal "main",                     record.source
    assert_equal 5432,                       record.duration_ms
    assert_equal "lms/main/#{"a" * 40}/teacher-grade_assignment-en.mp4", record.mp4_key
  ensure
    Workflows::Video.delete_all
  end

  test "persist_record is idempotent on same identity" do
    p = Workflows::Publisher.new(
      workflow_name: "teacher/grade_assignment", locale: "en",
      source: "main", sha: "a" * 40
    )
    p.define_singleton_method(:webvtt_duration) { |_| 5432 }

    a = p.send(:persist_record, { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }, "/tmp/a.jpg")
    b = p.send(:persist_record, { mp4: "/tmp/a.mp4", vtt: "/tmp/a.vtt" }, "/tmp/a.jpg")
    assert_equal a.id, b.id
  ensure
    Workflows::Video.delete_all
  end
end
