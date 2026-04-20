require "test_helper"

class Workflows::YamlLoaderTest < ActiveSupport::TestCase
  FIX = File.expand_path("fixtures/workflows", __dir__)

  test "loads a minimal valid workflow" do
    wf = Workflows::YamlLoader.load_file("#{FIX}/valid_minimal.yml")
    assert_equal "demo/hello", wf.name
    assert_equal "lms", wf.host
    assert_equal 1, wf.steps.size
    assert_equal "none", wf.steps.first.action
  end

  test "loads a full workflow with all optional fields" do
    wf = Workflows::YamlLoader.load_file("#{FIX}/valid_full.yml")
    assert_equal "school_os", wf.host
    assert_equal({ width: 1920, height: 1080 }, wf.viewport)
    assert_equal 1, wf.setup.size
    assert_equal 4, wf.steps.size
    assert_equal "fill", wf.steps[1].action
    assert_equal "Alice", wf.steps[1].value
    assert wf.steps[2].escape_hatch?
    assert wf.steps[3].assert?
  end

  test "rejects unknown top-level keys with a useful error" do
    err = assert_raises(Workflows::YamlLoader::SchemaError) do
      Workflows::YamlLoader.load_file("#{FIX}/invalid_unknown_key.yml")
    end
    assert_match /bogus_field/, err.message
    assert_match /invalid_unknown_key.yml/, err.message
  end

  test "rejects missing required fields" do
    err = assert_raises(Workflows::YamlLoader::SchemaError) do
      Workflows::YamlLoader.load_file("#{FIX}/invalid_missing_name.yml")
    end
    assert_match /name/, err.message
  end

  test "rejects unknown action values" do
    err = assert_raises(Workflows::YamlLoader::SchemaError) do
      Workflows::YamlLoader.load_file("#{FIX}/invalid_step_action.yml")
    end
    assert_match /action.*teleport/, err.message
  end

  test "loads all workflows from a directory" do
    Dir.mktmpdir do |dir|
      FileUtils.cp("#{FIX}/valid_minimal.yml", "#{dir}/a.yml")
      FileUtils.cp("#{FIX}/valid_full.yml", "#{dir}/b.yml")
      workflows = Workflows::YamlLoader.load_directory(dir)
      assert_equal 2, workflows.size
      assert_equal %w[demo/full demo/hello], workflows.map(&:name).sort
    end
  end
end
