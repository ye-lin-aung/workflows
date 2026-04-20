require "test_helper"

class Workflows::StepTest < ActiveSupport::TestCase
  test "builds a step from a hash" do
    step = Workflows::Step.new(
      caption: "teacher.grade_assignment.step_1",
      action: "click",
      target: "[data-tour='student-row-jordan_patel']"
    )
    assert_equal "click", step.action
    assert_equal "[data-tour='student-row-jordan_patel']", step.target
    assert_equal "teacher.grade_assignment.step_1", step.caption
  end

  test "defaults action to 'none'" do
    step = Workflows::Step.new(caption: "anything")
    assert_equal "none", step.action
  end

  test "has? returns true for presence of optional fields" do
    step = Workflows::Step.new(caption: "x", action: "fill", target: "a", value: "b")
    assert step.value?
    refute step.wait_for?
    refute step.assert?
  end

  test "prefers data-tour selector, reports when target_css escape hatch is used" do
    data_tour = Workflows::Step.new(caption: "x", action: "click", target: "[data-tour='foo']")
    css = Workflows::Step.new(caption: "x", action: "click", target_css: ".foo")
    refute data_tour.escape_hatch?
    assert css.escape_hatch?
  end

  test "resolved_target returns target when present, otherwise target_css" do
    assert_equal "[data-tour='x']", Workflows::Step.new(caption: "x", target: "[data-tour='x']").resolved_target
    assert_equal ".fallback", Workflows::Step.new(caption: "x", target_css: ".fallback").resolved_target
    assert_nil Workflows::Step.new(caption: "x").resolved_target
  end
end
