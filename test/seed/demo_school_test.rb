require "test_helper"

class Workflows::Seed::DemoSchoolTest < ActiveSupport::TestCase
  test "exposes the canonical school metadata" do
    school = Workflows::Seed::DemoSchool.school
    assert_equal "Lakeside Academy", school[:name]
    assert_equal "2026-2027", school[:academic_year]
  end

  test "defines three teachers with expected subjects and periods" do
    teachers = Workflows::Seed::DemoSchool.teachers
    assert_equal 3, teachers.size
    alvarez = teachers.find { |t| t[:key] == :teacher_ms_alvarez }
    assert_equal "Ms. Alvarez", alvarez[:display_name]
    assert_equal "Algebra I", alvarez[:subject]
    assert_equal 2, alvarez[:period]
  end

  test "defines five students with archetypes" do
    students = Workflows::Seed::DemoSchool.students
    assert_equal 5, students.size
    archetypes = students.map { |s| s[:archetype] }.sort
    assert_equal %i[at_risk average new strong weak], archetypes
    jordan = students.find { |s| s[:key] == :student_jordan_patel }
    assert_equal "Jordan Patel", jordan[:display_name]
    assert_equal :strong, jordan[:archetype]
  end

  test "defines two parents linked to known students" do
    parents = Workflows::Seed::DemoSchool.parents
    assert_equal 2, parents.size
    priya = parents.find { |p| p[:key] == :parent_priya_patel }
    assert_equal "Priya Patel", priya[:display_name]
    assert_equal :student_jordan_patel, priya[:child_key]
  end

  test "defines one admin" do
    admins = Workflows::Seed::DemoSchool.admins
    assert_equal 1, admins.size
    assert_equal "Dr. Kim", admins.first[:display_name]
  end

  test "find_persona looks up any member by persona key" do
    assert_equal "Ms. Alvarez", Workflows::Seed::DemoSchool.find_persona(:teacher_ms_alvarez)[:display_name]
    assert_equal "Jordan Patel", Workflows::Seed::DemoSchool.find_persona(:student_jordan_patel)[:display_name]
    assert_nil Workflows::Seed::DemoSchool.find_persona(:no_such_key)
  end

  test "all persona keys have an email in the demo.edu domain" do
    Workflows::Seed::DemoSchool.all_personas.each do |p|
      assert_match /@demo\.edu\z/, p[:email]
    end
  end
end
