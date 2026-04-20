module Workflows
  module Seed
    # Materializes Workflows::Seed::DemoSchool into school_os-side models:
    # School, User (has_secure_password), Role, UserRole, SchoolMembership,
    # ParentStudentLink, plus Section/Subject/Assignment density for non-empty
    # views. Idempotent.
    class SchoolOsAdapter
      DEFAULT_PASSWORD = "password"

      def call
        raise "school_os models not loaded" unless defined?(::School) && defined?(::Role)

        school = build_school
        users  = build_users
        assign_roles(users)
        assign_memberships(school, users)
        build_parent_links(users)
        build_sections_and_subjects(school)
        users
      end

      private

      def build_school
        ::School.find_or_create_by!(name: Workflows::Seed::DemoSchool.school[:name])
      end

      def build_users
        Workflows::Seed::DemoSchool.all_personas.each_with_object({}) do |persona, acc|
          first, *rest = persona[:display_name].split
          last = rest.last || first
          user = ::User.find_or_initialize_by(email_address: persona[:email])
          if user.new_record?
            user.first_name = first.sub(/\A(Ms\.|Mr\.|Dr\.)/, "").strip.presence || first
            user.first_name = first if user.first_name.blank?
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
      end

      def assign_memberships(school, users)
        users.each_value do |user|
          user.school_memberships.find_or_create_by!(school: school) do |m|
            m.status = :active if m.respond_to?(:status=)
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
          )
        end
      end

      def build_sections_and_subjects(school)
        # Sections and subject density are nice-to-have for visually non-empty
        # views — keep each model optional via defined? so tests that don't
        # need them aren't blocked by missing classes.
        return unless defined?(::Section) && defined?(::Subject)

        Workflows::Seed::DemoSchool.teachers.each do |teacher|
          subject = ::Subject.find_or_create_by!(name: teacher[:subject], school: school)
          ::Section.find_or_create_by!(name: "Period #{teacher[:period]} — #{teacher[:subject]}",
                                       subject: subject, school: school)
        end
      end
    end
  end
end
