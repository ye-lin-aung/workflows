require "test_helper"

class Workflows::Prospect::CatalogEntryTest < ActiveSupport::TestCase
  def question_hash
    {
      "id" => "admin_create_school",
      "type" => "question",
      "group" => "Onboarding",
      "persona" => "admin_new_marisol",
      "question" => "How do I create a new school?",
      "start_route" => "root_path",
      "expected_workflow" => "admin/onboard_school"
    }
  end

  def scenario_hash
    {
      "id" => "admin_transfer_student",
      "type" => "scenario",
      "group" => "Admissions",
      "persona" => "admin_dr_kim",
      "question" => "How do I onboard a transfer student?",
      "start_route" => "admin_dashboard_path",
      "setup" => [{ "factory" => "Student", "attrs" => { "first_name" => "Alex" } }],
      "sub_goals" => [
        "Locate the student's record",
        "Record their prior school",
        "Enroll them in the correct grade level",
        "Attach a guardian"
      ]
    }
  end

  test "builds a simple question entry" do
    e = Workflows::Prospect::CatalogEntry.new(question_hash)
    assert e.question?
    refute e.scenario?
    assert_equal "admin_create_school", e.id
    assert_equal :admin_new_marisol, e.persona
    assert_equal "How do I create a new school?", e.question
    assert_equal "root_path", e.start_route
    assert_equal "admin/onboard_school", e.expected_workflow
    assert_equal [], e.sub_goals
    assert_equal [], e.setup
  end

  test "builds a scenario entry with sub_goals + setup" do
    e = Workflows::Prospect::CatalogEntry.new(scenario_hash)
    assert e.scenario?
    refute e.question?
    assert_equal 4, e.sub_goals.size
    assert_equal 1, e.setup.size
    assert_equal "Student", e.setup.first[:factory]
    assert_equal "Alex", e.setup.first[:attrs][:first_name]
  end

  test "defaults budget by type — question vs scenario" do
    q = Workflows::Prospect::CatalogEntry.new(question_hash)
    assert_equal 480_000, q.budget[:time_cap_ms]
    assert_equal 4,       q.budget[:depth_cap]
    assert_equal 40_000,  q.budget[:token_cap]

    s = Workflows::Prospect::CatalogEntry.new(scenario_hash)
    assert_equal 900_000, s.budget[:time_cap_ms]
    assert_equal 5,       s.budget[:depth_cap]
    assert_equal 80_000,  s.budget[:token_cap]
  end

  test "explicit budget overrides defaults" do
    h = scenario_hash.merge("budget" => { "time_cap_ms" => 1_800_000, "depth_cap" => 6, "token_cap" => 120_000 })
    e = Workflows::Prospect::CatalogEntry.new(h)
    assert_equal 1_800_000, e.budget[:time_cap_ms]
    assert_equal 6,         e.budget[:depth_cap]
    assert_equal 120_000,   e.budget[:token_cap]
  end

  test "rejects unknown type" do
    err = assert_raises(ArgumentError) do
      Workflows::Prospect::CatalogEntry.new(question_hash.merge("type" => "invalid"))
    end
    assert_match(/type/, err.message)
  end

  test "rejects missing required fields" do
    %w[id persona question].each do |field|
      h = question_hash.dup
      h.delete(field)
      assert_raises(ArgumentError, "missing #{field} should raise") do
        Workflows::Prospect::CatalogEntry.new(h)
      end
    end
  end
end
