require "test_helper"

class Workflows::VideoTest < ActiveSupport::TestCase
  # Minitest 6 no longer ships the `stub` helper from minitest/mock.
  # Replace the singleton method on the given object with one that returns
  # `value`, run the block, then remove the singleton override so the
  # original method (defined on the class) is called again.
  def with_stub(obj, method, value)
    obj.define_singleton_method(method) { |*_args, **_kwargs| value }
    yield
  ensure
    obj.singleton_class.send(:remove_method, method) if obj.singleton_class.method_defined?(method)
  end

  def valid_attrs
    {
      workflow_name: "teacher/grade_assignment",
      locale: "en",
      commit_sha: "a" * 40,
      source: "main",
      rendered_at: Time.current,
      mp4_key: "lms/main/aaaa/teacher-grade_assignment-en.mp4",
      vtt_key: "lms/main/aaaa/teacher-grade_assignment-en.vtt",
      poster_key: "lms/main/aaaa/teacher-grade_assignment-en.jpg"
    }
  end

  test "creates with valid attrs" do
    v = Workflows::Video.create!(valid_attrs)
    assert v.persisted?
    assert_equal "en", v.locale
  end

  test "rejects missing required fields" do
    v = Workflows::Video.new
    refute v.valid?
    assert v.errors[:workflow_name].any?
    assert v.errors[:locale].any?
    assert v.errors[:commit_sha].any?
    assert v.errors[:source].any?
  end

  test "source must be main or pr" do
    v = Workflows::Video.new(valid_attrs.merge(source: "branch"))
    refute v.valid?
    assert_match(/not included/, v.errors[:source].first)
  end

  test "identity index prevents duplicate (workflow, locale, sha, source)" do
    Workflows::Video.create!(valid_attrs)
    assert_raises(ActiveRecord::RecordNotUnique) do
      Workflows::Video.create!(valid_attrs)
    end
  end

  test "current_main scope returns latest main record" do
    _older = Workflows::Video.create!(valid_attrs.merge(commit_sha: "a" * 40, rendered_at: 2.hours.ago))
    newer  = Workflows::Video.create!(valid_attrs.merge(commit_sha: "b" * 40, rendered_at: 1.hour.ago))
    latest = Workflows::Video.current_main("teacher/grade_assignment", "en")
    assert_equal newer.id, latest.id
  end

  test "mp4_url calls MinioClient#signed_url with the mp4_key" do
    fake_client = Struct.new(:last_args) do
      def signed_url(key, expires_in:)
        self.last_args = { key: key, expires_in: expires_in }
        "https://signed/#{key}?exp=#{expires_in}"
      end
    end.new(nil)

    with_stub(Workflows.config, :minio_client, fake_client) do
      v = Workflows::Video.new(valid_attrs)
      url = v.mp4_url(expires_in: 60)
      assert_equal "https://signed/#{v.mp4_key}?exp=60", url
      assert_equal v.mp4_key, fake_client.last_args[:key]
      assert_equal 60, fake_client.last_args[:expires_in]
    end
  end

  teardown do
    Workflows::Video.delete_all
  end
end
