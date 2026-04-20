module Workflows
  module Seed
    # Materializes Workflows::Seed::DemoSchool into school_os-side models:
    # School, User (has_secure_password), Role, UserRole, SchoolMembership,
    # ParentStudentLink, plus Subject density for non-empty views.
    # Idempotent.
    #
    # school-management's User enforces a password-complexity policy
    # (min length 8, uppercase + digit by default), so the seed uses a
    # compliant default that host sign-in adapters must also fill in.
    class SchoolOsAdapter
      DEFAULT_PASSWORD = "Password1!"
      SCHOOL_CODE      = "LAKESIDE"
      DEFAULT_THEME    = "default"

      def call
        raise "school_os models not loaded" unless defined?(::School) && defined?(::Role)

        school = build_school
        users  = build_users
        assign_roles(users)
        assign_memberships(school, users)
        build_parent_links(users)
        build_subjects(school)
        build_section_with_enrollments(school, users)
        users
      end

      private

      def build_school
        ::School.find_or_create_by!(code: SCHOOL_CODE) do |s|
          s.name  = Workflows::Seed::DemoSchool.school[:name]
          s.theme = DEFAULT_THEME if s.respond_to?(:theme=)
        end
      end

      def build_users
        Workflows::Seed::DemoSchool.all_personas.each_with_object({}) do |persona, acc|
          first, *rest = persona[:display_name].split
          last = rest.last || first
          # Strip common honorifics so the stored first_name reads naturally.
          first = first.sub(/\A(Ms\.|Mr\.|Dr\.|Mrs\.)\z/, "").strip.presence || first
          user = ::User.find_or_initialize_by(email_address: persona[:email])
          if user.new_record?
            user.first_name = first
            user.last_name  = last
            user.password = DEFAULT_PASSWORD
            user.password_confirmation = DEFAULT_PASSWORD
            user.date_of_birth = persona[:key].to_s.start_with?("student") ? 14.years.ago : 40.years.ago
            user.terms_accepted_at = Time.current
            user.email_confirmed_at = Time.current
            user.save!
          end
          acc[persona[:key]] = user
        end
      end

      def assign_roles(users)
        role_map = {
          teacher: "Instructor",
          student: "Student",
          parent:  "Parent",
          admin:   "Admin"
        }
        users.each do |key, user|
          prefix = key.to_s.split("_").first
          role_name = role_map[prefix.to_sym]
          next unless role_name
          role = ::Role.find_or_create_by!(name: role_name) { |r| r.system_role = true }
          user.user_roles.find_or_create_by!(role: role)
        end
        grant_demo_permissions
      end

      # Some host test environments load fixtures that pre-populate Role but
      # not the full set of RolePermissions expected by the production seed.
      # Demo personas rely on those grants to reach their workflow pages, so
      # backfill the minimum set idempotently. No-op if Permission records
      # are missing (e.g. Permission.sync! hasn't been run yet).
      def grant_demo_permissions
        return unless defined?(::Permission) && defined?(::RolePermission)

        grants = {
          "Instructor" => {
            "attendance" => %w[read create],
            "gradebook"  => %w[read create update],
            "assignments" => %w[read create update delete],
            "report_cards" => %w[read]
          },
          "Student" => {
            "attendance" => %w[read]
          },
          "Admin" => {
            "attendance" => %w[read create update delete]
          }
        }

        grants.each do |role_name, features|
          role = ::Role.find_by(name: role_name)
          next unless role
          features.each do |feature, actions|
            actions.each do |action|
              perm = ::Permission.find_by(feature: feature, action: action)
              next unless perm
              role.role_permissions.find_or_create_by!(permission: perm)
            end
          end
        end
      end

      def assign_memberships(school, users)
        # school-management's SchoolMembership.role_type enum is
        # {student: 0, teacher: 1, staff: 2}. Parents don't get a
        # school-membership record in this schema — a User + ParentStudentLink
        # is enough for parents to see their linked children.
        role_type_for = lambda do |key|
          case key.to_s.split("_").first
          when "teacher" then :teacher
          when "student" then :student
          when "admin"   then :staff
          else :none
          end
        end

        users.each do |key, user|
          # Personas flagged `onboarding: true` (e.g. a new admin setting up
          # their first school) must have no school membership so the app's
          # onboarding wizard kicks in on first sign-in.
          persona = Workflows::Seed::DemoSchool.find_persona(key)
          next if persona && persona[:onboarding]

          role_type = role_type_for.call(key)
          next if role_type == :none # parents skip SchoolMembership

          user.school_memberships.find_or_create_by!(school: school) do |m|
            m.role_type  = role_type
            m.started_at = Time.current if m.respond_to?(:started_at=)
          end
        end
      end

      def build_parent_links(users)
        Workflows::Seed::DemoSchool.parents.each do |parent|
          parent_user  = users[parent[:key]]
          student_user = users[parent[:child_key]]
          next unless parent_user && student_user

          student_membership = student_user.school_memberships.first
          next unless student_membership

          ::ParentStudentLink.find_or_create_by!(
            parent_user: parent_user,
            student_membership: student_membership
          ) do |psl|
            psl.effective_from = Date.current if psl.respond_to?(:effective_from=)
            psl.verified = true if psl.respond_to?(:verified=)
          end
        end
      end

      def build_subjects(school)
        # Subject density keeps Instructor-facing views from rendering empty.
        # school-management's Subject requires a unique code per school, so
        # derive one from the name.
        return unless defined?(::Subject)

        Workflows::Seed::DemoSchool.teachers.each do |teacher|
          subject_name = teacher[:subject]
          code = subject_name.upcase.gsub(/[^A-Z0-9]/, "_").gsub(/_+/, "_").sub(/\A_+|_+\z/, "")
          ::Subject.find_or_create_by!(school: school, code: code) do |s|
            s.name = subject_name
          end
        end
      end

      # Builds the Programme → AcademicYear → Term → GradeLevel → Section chain
      # needed by the teacher/mark_attendance workflow. The section is named
      # "Period 2 — Algebra I" (matching Ms. Alvarez's DemoSchool period+subject
      # fields) and all 5 demo students are enrolled. Idempotent.
      def build_section_with_enrollments(school, users)
        return unless defined?(::Programme) && defined?(::Section) && defined?(::SectionEnrollment)

        programme = ::Programme.find_or_create_by!(school: school, name: "Main Programme") do |p|
          p.programme_type = "k12"
        end

        academic_year = ::AcademicYear.find_or_create_by!(school: school, name: Workflows::Seed::DemoSchool.school[:academic_year]) do |ay|
          ay.start_date = Date.new(2026, 8, 1)
          ay.end_date   = Date.new(2027, 6, 30)
          ay.current    = true
        end
        ::AcademicYear.set_current!(academic_year) unless academic_year.current?

        term = ::Term.find_or_create_by!(academic_year: academic_year, name: "Semester 1") do |t|
          t.term_type  = "semester"
          t.start_date = academic_year.start_date
          t.end_date   = academic_year.start_date + 4.months
        end

        grade_level = ::GradeLevel.find_or_create_by!(programme: programme, name: "Grade 9") do |gl|
          gl.level_order = 9
        end

        section = ::Section.find_or_create_by!(grade_level: grade_level, term: term, name: "Period 2 — Algebra I") do |s|
          s.capacity = 30
        end

        student_keys = %i[student_jordan_patel student_sofia_ramirez student_dev_kapoor student_ava_thompson student_wei_zhang]
        student_keys.each do |key|
          user = users[key]
          next unless user
          membership = user.school_memberships.find_by(school: school)
          next unless membership
          ::SectionEnrollment.find_or_create_by!(school_membership: membership, section: section) do |se|
            se.enrolled_at = Time.current if se.respond_to?(:enrolled_at=)
          end
        end
      end
    end
  end
end
