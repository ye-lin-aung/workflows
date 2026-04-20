require "test_helper"

class Workflows::Seed::LmsAdapterTest < ActiveSupport::TestCase
  # This adapter uses real LMS models (User, Account, Course, Enrollment),
  # which only exist inside the lms host app. We run this test against the
  # lms host via a helper rake task:
  #   bin/rails workflows:test_seed_lms
  # Invoked directly from here, there are no models — skip.
  test "creates users, courses, and enrollments when LMS models are loaded" do
    skip "lms host models not loaded" unless defined?(::Course) && defined?(::Account)

    Workflows::Seed::LmsAdapter.new.call

    ms_alvarez = ::User.find_by(email: "alvarez@demo.edu")
    assert ms_alvarez, "expected teacher user"
    assert ms_alvarez.accounts.any? { |a| a.account_users.where.not(user_id: ms_alvarez.id).exists? },
           "expected teacher to have a shared account (instructor role)"

    jordan = ::User.find_by(email: "jordan@demo.edu")
    assert jordan, "expected student user"
    assert ::Enrollment.where(user: jordan).exists?, "expected student enrollment"
  end
end
