require "test_helper"

class Workflows::CatalogTest < ActiveSupport::TestCase
  class FakeClient
    attr_accessor :existing_keys, :signed

    def initialize
      @existing_keys = Set.new
      @signed = {}
    end

    def exists?(key)
      @existing_keys.include?(key)
    end

    def signed_url(key, expires_in:)
      @signed[key] = expires_in
      "https://minio/#{key}?sig=#{expires_in}"
    end
  end

  setup do
    Workflows.config.host_name = :lms
    @fake = FakeClient.new
    Workflows.config.minio_client = @fake
    @tmp = Dir.mktmpdir
    Workflows.config.workflows_path = @tmp

    File.write(File.join(@tmp, "demo.yml"), <<~YML)
      name: demo/x
      title: t
      description: d
      host: lms
      persona: u
      start_at: root_path
      steps:
        - caption: c
    YML

    @loc_dir = Dir.mktmpdir
    File.write(File.join(@loc_dir, "workflows.en.yml"), "en: {}")
    File.write(File.join(@loc_dir, "workflows.es.yml"), "es: {}")
  end

  teardown do
    Workflows.config.host_name = nil
    Workflows.config.minio_client = nil
    Workflows.config.workflows_path = nil
    FileUtils.rm_rf(@tmp)
    FileUtils.rm_rf(@loc_dir)
  end

  test "prints markdown table for existing current/ objects" do
    @fake.existing_keys << "lms/current/demo-x-en.mp4"

    output = capture_stdout do
      Workflows::Catalog.print_markdown(locales_dir: @loc_dir)
    end

    assert_match(/\| Workflow \| Locale \| Video \| Subtitles \| Poster \|/, output)
    assert_match(%r{\| demo/x \| en \| }, output)
    assert_match(%r{minio/lms/current/demo-x-en.mp4}, output)
    refute_match(%r{demo/x \| es }, output)
  end

  test "prints hint when no current/ objects exist" do
    output = capture_stdout do
      Workflows::Catalog.print_markdown(locales_dir: @loc_dir)
    end
    assert_match(/Nothing to show/, output)
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
