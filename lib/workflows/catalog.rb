module Workflows
  # Prints a Markdown catalog of current/ MinIO URLs.
  class Catalog
    # AWS SigV4 caps presigned URLs at 7 days (604_800 s). Catalog URLs are
    # meant for docs/PR comments; a week is plenty — re-run the task to refresh.
    CATALOG_EXPIRY = 7 * 24 * 3600 - 60   # just under one week

    def self.print_markdown(locales_dir: nil)
      rows = build_rows(locales_dir: locales_dir)
      if rows.empty?
        puts "# Nothing to show — run workflows:publish_all on main first."
        return
      end

      puts "| Workflow | Locale | Video | Subtitles | Poster |"
      puts "|---|---|---|---|---|"
      rows.each { |r| puts r }
    end

    def self.build_rows(locales_dir: nil)
      client    = Workflows.config.minio_client
      host      = Workflows.config.host_name.to_s
      workflows = Workflows::YamlLoader.load_directory(Workflows.config.workflows_path.to_s)
      locales   = Workflows::Publisher.send(:locales_with_translations, locales_dir: locales_dir)

      workflows.flat_map do |wf|
        locales.filter_map do |locale|
          flat = wf.name.tr("/", "-")
          mp4_key    = "#{host}/current/#{flat}-#{locale}.mp4"
          vtt_key    = "#{host}/current/#{flat}-#{locale}.vtt"
          poster_key = "#{host}/current/#{flat}-#{locale}.jpg"

          next unless client.exists?(mp4_key)

          "| #{wf.name} | #{locale} | " \
          "[▶](#{client.signed_url(mp4_key, expires_in: CATALOG_EXPIRY)}) | " \
          "[vtt](#{client.signed_url(vtt_key, expires_in: CATALOG_EXPIRY)}) | " \
          "[🖼](#{client.signed_url(poster_key, expires_in: CATALOG_EXPIRY)}) |"
        end
      end
    end
  end
end
