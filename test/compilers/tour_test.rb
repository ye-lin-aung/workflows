require "test_helper"

class Workflows::Compilers::TourTest < ActiveSupport::TestCase
  def build_workflow
    Workflows::YamlLoader.load_file(File.expand_path("../fixtures/workflows/valid_full.yml", __dir__))
  end

  test "projects workflow into tutorials tour hash shape" do
    tour = Workflows::Compilers::Tour.call(build_workflow)

    assert_equal "demo.full", tour[:id]
    assert_equal "demo.full.title", tour[:title_key]
    assert_equal "demo.full.description", tour[:description_key]
    # Every step that has a target or target_css produces a popover entry.
    # The caption-only first step (wait_for only, no target) is dropped.
    refute_empty tour[:steps]
    tour[:steps].each do |step|
      assert step[:element].present?, "step missing element"
      assert step[:body_key].present?, "step missing body_key"
    end
  end

  test "drops action/value/wait_for/assert fields from projected steps" do
    tour = Workflows::Compilers::Tour.call(build_workflow)
    tour[:steps].each do |step|
      refute step.key?(:action)
      refute step.key?(:value)
      refute step.key?(:wait_for)
      refute step.key?(:assert)
    end
  end

  test "skips steps without a target selector" do
    wf = Workflows::YamlLoader.load_file(File.expand_path("../fixtures/workflows/valid_minimal.yml", __dir__))
    tour = Workflows::Compilers::Tour.call(wf)
    # valid_minimal has one caption-only step, so the tour has zero steps.
    assert_empty tour[:steps]
  end

  test "resolves target_css escape hatch as element selector" do
    tour = Workflows::Compilers::Tour.call(build_workflow)
    css_step = tour[:steps].find { |s| s[:element] == ".submit-button" }
    assert css_step, "expected target_css step to appear as element"
  end

  test "includes a derived route for tutorials availability checks" do
    tour = Workflows::Compilers::Tour.call(build_workflow)
    # Workflows use Ruby helpers like `admin_dashboard_path`; the tour route
    # takes the raw start_at string by default. Hosts can override via route_override:
    # in the YAML (Phase 2).
    assert_equal "admin_dashboard_path", tour[:route]
  end
end
