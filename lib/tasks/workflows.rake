# lib/tasks/workflows.rake
namespace :workflows do
  desc "Render a workflow to MP4+VTT. Usage: bin/rails workflows:render[teacher/grade_assignment]"
  task :render, [:name] => :environment do |_t, args|
    name = args[:name] or abort "usage: workflows:render[name]"
    path = File.join(Workflows.config.workflows_path, "#{name}.yml")
    wf = Workflows::YamlLoader.load_file(path)
    output = Workflows.config.videos_output_path.to_s
    FileUtils.mkdir_p(output)
    result = Workflows::Runner::RecordMode.new(workflow: wf, output_dir: output).run
    puts "rendered: #{result[:mp4]}"
    puts "subtitle: #{result[:vtt]}"
  end

  desc "Compile workflow YAML into generated system-test files under test/system/workflows/"
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
end
