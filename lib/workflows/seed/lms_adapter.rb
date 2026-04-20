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
        courses = build_courses(instructor_account, users)
        build_enrollments(users, courses, instructor_account)
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
            # Jumpstart Pro requires terms-of-service acceptance on :create.
            user.terms_of_service = "1" if user.respond_to?(:terms_of_service=)
            user.save!
          end
          acc[persona[:key]] = user
        end
      end

      def build_instructor_account(users)
        alvarez = users[:teacher_ms_alvarez]
        school_name = Workflows::Seed::DemoSchool.school[:name]

        # lms's Account requires an owner (belongs_to :owner, not optional) and
        # defaults to account_type: :organization (required so courses can be
        # created — see Account#can_create_content?).
        account = ::Account.find_or_create_by!(name: school_name, personal: false) do |a|
          a.owner = alvarez
          a.account_type = :organization if a.respond_to?(:account_type=)
        end

        # The before_create callback on Account creates an admin account_user
        # for the owner; make sure it's there even on a rerun.
        alvarez.account_users.find_or_create_by!(account: account) { |au| au.admin = true }

        # Attach the other teachers and all students to the shared account so
        # instructor dashboards see them.
        %i[teacher_mr_chen teacher_ms_okafor admin_dr_kim].each do |k|
          users[k].account_users.find_or_create_by!(account: account) { |au| au.admin = (k == :admin_dr_kim) }
        end
        %i[student_jordan_patel student_sofia_ramirez student_dev_kapoor student_ava_thompson student_wei_zhang].each do |k|
          users[k].account_users.find_or_create_by!(account: account) { |au| au.admin = false }
        end

        account
      end

      def build_courses(account, users)
        # lms's Course requires a created_by user (belongs_to :created_by,
        # class_name: "User"), so attribute it to the subject-matter teacher.
        alvarez = users[:teacher_ms_alvarez]
        chen    = users[:teacher_mr_chen]

        algebra = ::Course.find_or_create_by!(title: "Algebra I Fundamentals", account: account) do |c|
          c.description = "Linear equations, quadratic expressions, and foundational problem solving."
          c.created_by = alvarez if c.respond_to?(:created_by=)
          c.status = :published if c.respond_to?(:status=)
        end
        biology = ::Course.find_or_create_by!(title: "Biology — Cells and Life", account: account) do |c|
          c.description = "The cell as the unit of life; genetics; ecosystems."
          c.created_by = chen if c.respond_to?(:created_by=)
          c.status = :published if c.respond_to?(:status=)
        end
        [algebra, biology]
      end

      def build_enrollments(users, courses, account)
        # lms's Enrollment requires account_id and a role (0=student default).
        student_keys = %i[student_jordan_patel student_sofia_ramirez student_dev_kapoor student_ava_thompson student_wei_zhang]
        student_keys.each do |k|
          courses.each do |course|
            ::Enrollment.find_or_create_by!(user: users[k], course: course) do |e|
              e.account = account if e.respond_to?(:account=)
              e.role = :student if e.respond_to?(:role=)
              e.status = :active if e.respond_to?(:status=)
            end
          end
        end
      end
    end
  end
end
