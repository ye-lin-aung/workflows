require "test_helper"

class Workflows::Seed::SchoolOsAdapterTest < ActiveSupport::TestCase
  test "creates users, school, roles, memberships when school_os models are loaded" do
    skip "school_os host models not loaded" unless defined?(::School) && defined?(::Role)

    Workflows::Seed::SchoolOsAdapter.new.call

    school = ::School.find_by(name: "Lakeside Academy")
    assert school, "expected demo school"

    alvarez = ::User.find_by(email_address: "alvarez@demo.edu")
    assert alvarez, "expected teacher user"
    assert alvarez.roles.exists?(name: "Instructor"), "expected Instructor role"

    jordan = ::User.find_by(email_address: "jordan@demo.edu")
    assert jordan, "expected student user"
    assert jordan.roles.exists?(name: "Student"), "expected Student role"

    priya = ::User.find_by(email_address: "priya@demo.edu")
    assert priya, "expected parent user"
    assert ::ParentStudentLink.where(parent_user: priya).exists?, "expected parent link"
  end
end
