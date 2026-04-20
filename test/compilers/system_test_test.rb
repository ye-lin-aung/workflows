require "test_helper"

class Workflows::Compilers::SystemTestTest < ActiveSupport::TestCase
  def fixture_workflow
    Workflows::YamlLoader.load_file(File.expand_path("../fixtures/workflows/valid_minimal.yml", __dir__))
  end

  test "produces a thin Minitest file that delegates to Runner::TestMode" do
    src = Workflows::Compilers::SystemTest.call(fixture_workflow)

    assert_match %r{require "application_system_test_case"}, src
    assert_match %r{class Workflows::Demo::HelloTest < ApplicationSystemTestCase}, src
    assert_match %r{test "demo/hello"}, src
    assert_match %r{Workflows::Runner::TestMode.new\("demo/hello"\)\.run\(self\)}, src
  end

  test "derives a CamelCase classname from the workflow name" do
    wf = fixture_workflow
    src = Workflows::Compilers::SystemTest.call(wf)
    # teacher/grade_assignment -> Workflows::Teacher::GradeAssignmentTest
    # demo/hello -> Workflows::Demo::HelloTest (shown above)
    # student/ai_studio_lesson -> Workflows::Student::AiStudioLessonTest
    assert_match /class Workflows::Demo::HelloTest/, src
  end

  test "write_to writes the compiled source to the host's test/system/workflows/ tree" do
    wf = fixture_workflow
    Dir.mktmpdir do |dir|
      path = Workflows::Compilers::SystemTest.write_to(wf, test_root: dir)
      assert_equal File.join(dir, "workflows/demo/hello_test.rb"), path
      assert File.exist?(path)
      assert_match /Workflows::Runner::TestMode/, File.read(path)
    end
  end
end
