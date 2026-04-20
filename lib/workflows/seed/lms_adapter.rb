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
        build_assessments(courses)
        build_sections(courses)
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

        # AI Studio is feature-flagged per account. The teacher/ai_studio_lesson
        # workflow needs it enabled; without it the controller redirects away
        # before we can target anything. Idempotent on re-seed.
        if account.respond_to?(:ai_studio_enabled=) && !account.ai_studio_enabled
          account.update!(ai_studio_enabled: true)
        end

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

        # Enroll the subject-matter teacher as an instructor so they pass
        # `authorize_course` on pages like teach/gradebook and teach/assessments.
        algebra, biology = courses
        instructor_enrollments = [
          [users[:teacher_ms_alvarez], algebra],
          [users[:teacher_mr_chen],    biology]
        ]
        instructor_enrollments.each do |user, course|
          ::Enrollment.find_or_create_by!(user: user, course: course) do |e|
            e.account = account if e.respond_to?(:account=)
            e.role = :instructor if e.respond_to?(:role=)
            e.status = :active if e.respond_to?(:status=)
          end
        end
      end

      def build_assessments(courses)
        # One assignment per course so the gradebook renders the full table
        # (rows + columns). The gradebook view hides its student rows entirely
        # when a course has zero assessments, so the workflow's selectors
        # would never appear without this.
        algebra, _biology = courses
        ::Assessment.find_or_create_by!(course: algebra, title: "Linear Equations Quiz") do |a|
          a.assessment_type = :quiz if a.respond_to?(:assessment_type=)
          a.description = "Short quiz covering one- and two-step linear equations." if a.respond_to?(:description=)
        end

        # A second, fully-seeded quiz with questions, used by the
        # student/take_assessment workflow. A student needs real questions
        # to answer, so we attach one multiple_choice and one short_answer
        # question. Mixing auto-gradable and non-auto-gradable means the
        # assessment goes to :submitted (pending grading) rather than
        # :graded after submit — either state renders the results page,
        # which is all the workflow asserts.
        quiz = ::Assessment.find_or_create_by!(course: algebra, title: "Algebra I Fundamentals Quiz") do |a|
          a.assessment_type = :quiz if a.respond_to?(:assessment_type=)
          a.description = "Warm-up quiz: identify linear forms and explain a factoring step." if a.respond_to?(:description=)
          # Leave max_attempts nil (unlimited) so rerunning the
          # student/take_assessment workflow never hits the "no attempts
          # remaining" branch.
          a.show_correct_answers = true if a.respond_to?(:show_correct_answers=)
        end

        build_quiz_questions(quiz)
      end

      # Seeds a single empty course section on the Algebra course so the
      # teacher/ai_studio_lesson workflow has somewhere to land when it
      # clicks "Add lesson". The section itself has no lessons by design —
      # the workflow authors one.
      def build_sections(courses)
        algebra, _biology = courses
        ::CourseSection.find_or_create_by!(course: algebra, title: "Unit 1: Linear Equations") do |s|
          s.position = 1
        end
      end

      def build_quiz_questions(quiz)
        return unless defined?(::AssessmentQuestion)

        mc_content = "Which of the following is a linear equation in one variable?"
        mc = quiz.assessment_questions.find_or_initialize_by(content: mc_content)
        if mc.new_record?
          mc.question_type = :multiple_choice if mc.respond_to?(:question_type=)
          mc.points        = 1 if mc.respond_to?(:points=)
          mc.position      = 1 if mc.respond_to?(:position=)
          mc.required      = true if mc.respond_to?(:required=)
          mc.metadata      = {
            "options" => [
              { "id" => "a", "text" => "x^2 + 3 = 7" },
              { "id" => "b", "text" => "2x + 5 = 11" },
              { "id" => "c", "text" => "xy = 4" },
              { "id" => "d", "text" => "sqrt(x) = 3" }
            ],
            "correct_answer" => "b"
          } if mc.respond_to?(:metadata=)
          mc.save!
        end

        sa_content = "Briefly explain why factoring polynomial expressions is useful when solving equations."
        sa = quiz.assessment_questions.find_or_initialize_by(content: sa_content)
        if sa.new_record?
          sa.question_type = :short_answer if sa.respond_to?(:question_type=)
          sa.points        = 2 if sa.respond_to?(:points=)
          sa.position      = 2 if sa.respond_to?(:position=)
          sa.required      = true if sa.respond_to?(:required=)
          sa.save!
        end
      end
    end
  end
end
