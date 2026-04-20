module Workflows
  module Seed
    # Materializes Workflows::Seed::DemoSchool into lms-side models:
    # Users (Devise), Accounts (Jumpstart Pro shared-account = "instructor"),
    # Courses + Lessons + Assessments, Enrollments. Idempotent: calling it
    # twice leaves the DB in the same state as calling it once.
    class LmsAdapter
      DEFAULT_PASSWORD = "password"

      def call
        raise "LMS models not loaded" unless defined?(::User)

        users = build_users
        instructor_account = build_instructor_account(users)
        courses = build_courses(instructor_account)
        build_enrollments(users, courses)
        users
      end

      private

      def build_users
        Workflows::Seed::DemoSchool.all_personas.each_with_object({}) do |persona, acc|
          user = ::User.find_or_initialize_by(email: persona[:email])
          if user.new_record?
            user.password = DEFAULT_PASSWORD
            user.password_confirmation = DEFAULT_PASSWORD
            user.first_name = persona[:display_name].split.first
            user.last_name  = persona[:display_name].split.last
            user.confirmed_at = Time.current
            user.save!
          end
          acc[persona[:key]] = user
        end
      end

      def build_instructor_account(users)
        alvarez = users[:teacher_ms_alvarez]
        account = ::Account.find_or_create_by!(name: Workflows::Seed::DemoSchool.school[:name], personal: false)
        alvarez.account_users.find_or_create_by!(account: account) { |au| au.admin = true }

        # Attach students to the shared account so instructor dashboards see them.
        %i[student_jordan_patel student_sofia_ramirez student_dev_kapoor student_ava_thompson student_wei_zhang].each do |k|
          users[k].account_users.find_or_create_by!(account: account) { |au| au.admin = false }
        end

        account
      end

      def build_courses(account)
        algebra = ::Course.find_or_create_by!(title: "Algebra I Fundamentals", account: account) do |c|
          c.description = "Linear equations, quadratic expressions, and foundational problem solving."
          c.status = :published if c.respond_to?(:status=)
        end
        biology = ::Course.find_or_create_by!(title: "Biology — Cells and Life", account: account) do |c|
          c.description = "The cell as the unit of life; genetics; ecosystems."
          c.status = :published if c.respond_to?(:status=)
        end
        [algebra, biology]
      end

      def build_enrollments(users, courses)
        student_keys = %i[student_jordan_patel student_sofia_ramirez student_dev_kapoor student_ava_thompson student_wei_zhang]
        student_keys.each do |k|
          courses.each do |course|
            ::Enrollment.find_or_create_by!(user: users[k], course: course)
          end
        end
      end
    end
  end
end
