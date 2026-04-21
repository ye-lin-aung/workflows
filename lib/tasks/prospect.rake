namespace :prospect do
  desc "Explore the app as a new-user persona. Usage: bin/rails 'prospect:explore[admin,create_school]' — both args optional."
  task :explore, [:persona_prefix, :id_suffix] => :environment do |_t, args|
    require "workflows/prospect/catalog"
    require "workflows/prospect/mcp_client"
    require "workflows/prospect/explorer"
    require "workflows/prospect/report_writer"
    require "anthropic"

    target = ENV.fetch("PROSPECT_TARGET", "http://localhost:3000")
    api_key = ENV.fetch("ANTHROPIC_API_KEY") do
      abort "ANTHROPIC_API_KEY is required. Export it or put it in .env."
    end

    catalog_path = Rails.root.join("config/prospect_questions.yml")
    abort "config/prospect_questions.yml not found in this app" unless File.exist?(catalog_path)

    catalog = Workflows::Prospect::Catalog.load_file(catalog_path.to_s)
    entries = catalog.filter(persona_prefix: args[:persona_prefix], id_suffix: args[:id_suffix])
    if entries.empty?
      puts "[prospect] no entries match filters (persona_prefix=#{args[:persona_prefix].inspect} id_suffix=#{args[:id_suffix].inspect})"
      exit 0
    end

    puts "[prospect] target: #{target}"
    puts "[prospect] #{entries.size} question(s) selected"

    timestamp = Time.now.utc.strftime("%Y-%m-%dT%H-%M-%SZ")
    root_dir  = Rails.root.join("tmp/prospect-reports/#{timestamp}").to_s
    writer    = Workflows::Prospect::ReportWriter.new(root_dir: root_dir, target_url: target)

    anthropic = Anthropic::Client.new(api_key: api_key)
    mcp = Workflows::Prospect::McpClient.new(
      command: "npx",
      args: ["--yes", "@playwright/mcp@latest", "--isolated", "--headless"]
    )
    mcp.start

    threads = []
    begin
      entries.each_with_index do |entry, i|
        puts "[prospect] ▶ #{entry.id} — #{i + 1}/#{entries.size}"
        started = Time.now
        explorer = Workflows::Prospect::Explorer.new(anthropic_client: anthropic, mcp_client: mcp)
        state = explorer.explore(entry: entry, target_url: target)
        writer.write_thread(state)
        threads << state
        elapsed = (Time.now - started).to_i
        puts "[prospect] ✓ #{entry.id} — #{state.verdict} — #{elapsed}s"
      end
    ensure
      mcp.stop
    end

    writer.write_index(threads)
    puts "[prospect] Done. Reports at #{root_dir}"
    puts "[prospect] Summary: #{threads.group_by(&:verdict).transform_values(&:size)}"
  end
end
