namespace :workflows do
  desc "Render a workflow to MP4+VTT. Usage: bin/rails 'workflows:render[name]'"
  task :render, [:name] => :environment do |_t, args|
    ENV["WORKFLOWS_RECORD_MODE"] = "1"
    name = args[:name] or abort "usage: workflows:render[name]"
    path = File.join(Workflows.config.workflows_path, "#{name}.yml")
    wf = Workflows::YamlLoader.load_file(path)
    output = Workflows.config.videos_output_path.to_s
    FileUtils.mkdir_p(output)
    result = Workflows::Runner::RecordMode.new(workflow: wf, output_dir: output).run
    puts "rendered: #{result[:mp4]}"
    puts "subtitle: #{result[:vtt]}"
  end

  desc "Compile workflow YAML into generated system-test files"
  task compile_tests: :environment do
    root = Workflows.config.workflows_path.to_s
    test_root = Rails.root.join("test/system")
    count = 0
    Workflows::YamlLoader.load_directory(root).each do |wf|
      Workflows::Compilers::SystemTest.write_to(wf, test_root: test_root.to_s)
      count += 1
    end
    puts "compiled #{count} workflow tests into #{test_root}/workflows/"
  end

  desc "Audit selectors and caption i18n keys for every workflow"
  task audit: :environment do
    result = Workflows::Audit.new.run
    if result[:ok]
      puts "OK: no workflow audit issues."
    else
      warn "#{result[:issues].size} workflow audit issue(s) found:"
      result[:issues].each { |i| warn "  - #{i.inspect}" }
      exit 1
    end
  end

  desc "Publish a single workflow to MinIO. Usage: bin/rails 'workflows:publish[name,locale]'"
  task :publish, [:name, :locale] => :environment do |_t, args|
    ENV["WORKFLOWS_RECORD_MODE"] = "1"
    name = args[:name] or abort "usage: workflows:publish[name,locale]"
    locale = args[:locale] || "en"
    result = Workflows::Publisher.new(workflow_name: name, locale: locale).call
    if result
      puts "published: #{name} [#{locale}]"
    else
      puts "deduped (already in MinIO): #{name} [#{locale}]"
    end
  end

  desc "Publish every workflow × every locale that has a translation"
  task publish_all: :environment do
    ENV["WORKFLOWS_RECORD_MODE"] = "1"
    Workflows::Publisher.publish_all
    puts "publish_all complete."
  end

  desc "Publish only workflows affected by the current PR diff"
  task affected: :environment do
    ENV["WORKFLOWS_RECORD_MODE"] = "1"
    base = ENV["GITHUB_BASE_REF"] || "main"
    `git fetch origin #{base}:refs/remotes/origin/#{base} 2>/dev/null`
    changed = `git diff --name-only origin/#{base}...HEAD`.lines.map(&:strip)

    narrow = changed.any? && changed.all? { |f| f.start_with?("config/workflows/") }
    names = if narrow
      changed.filter_map { |f| f.match(%r{config/workflows/(.+)\.yml})&.[](1) }.uniq
    else
      Workflows::Publisher.send(:workflow_names)
    end

    locales = Workflows::Publisher.send(:locales_with_translations)
    puts "Publishing #{names.size} workflows × #{locales.size} locales (#{narrow ? 'narrow' : 'broad'} mode)"

    names.each do |n|
      locales.each do |l|
        Workflows::Publisher.new(workflow_name: n, locale: l).call
      end
    end
  end

  desc "Print Markdown catalog of current/ URLs"
  task catalog: :environment do
    Workflows::Catalog.print_markdown
  end
end
