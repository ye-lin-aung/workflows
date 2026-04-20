require "test_helper"

class Workflows::WorkflowTest < ActiveSupport::TestCase
  def valid_attrs
    {
      name: "teacher/grade_assignment",
      title: "teacher.grade_assignment.title",
      description: "teacher.grade_assignment.description",
      host: "lms",
      persona: "teacher_ms_alvarez",
      start_at: 'teach_gradebook_path(section: "algebra_i")',
      viewport: { width: 1440, height: 900 },
      setup: [{ factory: "assignment", attrs: { title: "Chapter 3" } }],
      steps: [
        Workflows::Step.new(caption: "teacher.grade_assignment.step_1"),
        Workflows::Step.new(caption: "teacher.grade_assignment.step_2",
                            action: "click",
                            target: "[data-tour='student-row-jordan_patel']")
      ]
    }
  end

  test "exposes required and optional attributes" do
    wf = Workflows::Workflow.new(**valid_attrs)
    assert_equal "teacher/grade_assignment", wf.name
    assert_equal "lms", wf.host
    assert_equal "teacher_ms_alvarez", wf.persona
    assert_equal 'teach_gradebook_path(section: "algebra_i")', wf.start_at
    assert_equal 2, wf.steps.size
    assert_equal({ width: 1440, height: 900 }, wf.viewport)
  end

  test "defaults viewport when omitted" do
    attrs = valid_attrs
    attrs.delete(:viewport)
    wf = Workflows::Workflow.new(**attrs)
    assert_equal({ width: 1440, height: 900 }, wf.viewport)
  end

  test "defaults setup to empty array when omitted" do
    attrs = valid_attrs
    attrs.delete(:setup)
    wf = Workflows::Workflow.new(**attrs)
    assert_equal [], wf.setup
  end

  test "tour_id projects name into dotted form" do
    wf = Workflows::Workflow.new(**valid_attrs)
    assert_equal "teacher.grade_assignment", wf.tour_id
  end

  test "host_sym returns symbol form" do
    wf = Workflows::Workflow.new(**valid_attrs)
    assert_equal :lms, wf.host_sym
  end
end
