module Workflows
  module Seed
    # Canonical demo school data shared by every workflow video. The same
    # characters appear across clips so the videos feel like one coherent
    # school. Host adapters (LmsAdapter, SchoolOsAdapter) materialize these
    # abstract records into each host's real schema.
    module DemoSchool
      SCHOOL = {
        name: "Lakeside Academy",
        academic_year: "2026-2027"
      }.freeze

      TEACHERS = [
        { key: :teacher_ms_alvarez, display_name: "Ms. Alvarez", email: "alvarez@demo.edu",
          subject: "Algebra I",     period: 2 },
        { key: :teacher_mr_chen,    display_name: "Mr. Chen",    email: "chen@demo.edu",
          subject: "Biology",       period: 4 },
        { key: :teacher_ms_okafor,  display_name: "Ms. Okafor",  email: "okafor@demo.edu",
          subject: "English Lit",   period: 6 }
      ].freeze

      STUDENTS = [
        { key: :student_jordan_patel,   display_name: "Jordan Patel",   email: "jordan@demo.edu",
          archetype: :strong },
        { key: :student_sofia_ramirez,  display_name: "Sofia Ramirez",  email: "sofia@demo.edu",
          archetype: :weak },
        { key: :student_dev_kapoor,     display_name: "Dev Kapoor",     email: "dev@demo.edu",
          archetype: :average },
        { key: :student_ava_thompson,   display_name: "Ava Thompson",   email: "ava@demo.edu",
          archetype: :new },
        { key: :student_wei_zhang,      display_name: "Wei Zhang",      email: "wei@demo.edu",
          archetype: :at_risk }
      ].freeze

      PARENTS = [
        { key: :parent_priya_patel,     display_name: "Priya Patel",    email: "priya@demo.edu",
          child_key: :student_jordan_patel },
        { key: :parent_luis_ramirez,    display_name: "Luis Ramirez",   email: "luis@demo.edu",
          child_key: :student_sofia_ramirez }
      ].freeze

      ADMINS = [
        { key: :admin_dr_kim,      display_name: "Dr. Kim",     email: "kim@demo.edu" },
        { key: :admin_new_marisol, display_name: "Marisol Tan", email: "marisol@demo.edu", onboarding: true }
      ].freeze

      module_function

      def school     ; SCHOOL     ; end
      def teachers   ; TEACHERS   ; end
      def students   ; STUDENTS   ; end
      def parents    ; PARENTS    ; end
      def admins     ; ADMINS     ; end

      def all_personas
        TEACHERS + STUDENTS + PARENTS + ADMINS
      end

      def find_persona(key)
        all_personas.find { |p| p[:key] == key.to_sym }
      end

      def call(host:)
        adapter = adapter_for(host)
        adapter.call
      end

      def adapter_for(host)
        case host.to_sym
        when :lms       then Workflows::Seed::LmsAdapter.new
        when :school_os then Workflows::Seed::SchoolOsAdapter.new
        else raise ArgumentError, "unknown host #{host.inspect}"
        end
      end
    end
  end
end
