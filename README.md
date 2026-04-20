# workflows

Unified workflow authoring: one YAML file becomes a driver.js tour, a Minitest system test, and an MP4 video with WebVTT subtitles. Shared between LMS and school-os.

See `docs/superpowers/specs/2026-04-20-workflows-design.md` in school-management for the full design.

## Requirements

- Ruby >= 3.4.0
- Rails >= 8.1
- Node + Playwright Chromium (`npx playwright install chromium`)
- ffmpeg (for webm → mp4 transcoding)

## Installation (host app)

Add to Gemfile:

    gem "workflows", path: "../workflows"

Then:

    bundle install
    bin/rails generate workflows:install
    bin/rails db:migrate        # no-op in Phase 1 (no migrations)
