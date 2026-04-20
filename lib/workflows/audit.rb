module Workflows
  # Walks every workflow YAML and flags issues the spec's audit rule set
  # cares about:
  #   - target_css escape-hatch usage (selector not prefixed with data-tour)
  #   - duplicate workflow names across files
  #   - missing i18n caption keys (only when an I18n backend is present)
  class Audit
    def initialize(workflows_path: Workflows.config.workflows_path.to_s,
                   locale: I18n.default_locale)
      @workflows_path = workflows_path
      @locale         = locale
    end

    def run
      workflows = YamlLoader.load_directory(@workflows_path)
      issues = []
      issues.concat(check_duplicate_names(workflows))
      workflows.each do |wf|
        issues.concat(check_escape_hatches(wf))
        issues.concat(check_i18n_keys(wf)) if I18n.backend
      end
      { ok: issues.empty?, issues: issues }
    end

    private

    def check_duplicate_names(workflows)
      dups = workflows.group_by(&:name).select { |_, v| v.size > 1 }
      dups.keys.map { |name| { kind: :duplicate_name, name: name } }
    end

    def check_escape_hatches(workflow)
      workflow.steps.each_with_index.flat_map do |step, idx|
        next [] unless step.escape_hatch?
        [{ kind: :target_css_escape_hatch, workflow: workflow.name, step_index: idx, selector: step.target_css }]
      end
    end

    def check_i18n_keys(workflow)
      workflow.steps.each_with_index.flat_map do |step, idx|
        next [] unless i18n_key?(step.caption)
        next [] if I18n.exists?(step.caption, @locale)
        [{ kind: :missing_i18n_key, workflow: workflow.name, step_index: idx, key: step.caption }]
      end
    end

    def i18n_key?(str)
      str.is_a?(String) && str.match?(/\A[a-z0-9_]+(\.[a-z0-9_]+)+\z/i)
    end
  end
end
