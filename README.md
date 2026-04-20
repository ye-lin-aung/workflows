# workflows

Author each workflow as one YAML file → tour + system test + video.

Shared between LMS (`lms`) and school-os (`school-management`).

## Why

Onboarding flows get told three ways today: as a driver.js tour inside the app, as a system test in CI, and as a recorded product video on the marketing site. Each copy drifts. When a selector moves or a button is relabelled, the tour still highlights the old element, the test quietly stops exercising the new flow, and the video goes stale for months before anyone notices.

`workflows` fixes that by making the YAML file the single source of truth. One document names the persona, the starting route, and the ordered steps; three compilers project it into the three outputs. Change the YAML, every output updates. Break a selector, `bin/rails workflows:audit` and the generated system test both fail before the tour reaches a user.

Phase 2.1 layers persistence on top: published videos live in MinIO, CI re-publishes on every PR and `main` merge, and a Markdown catalog lists the latest rendered URL per workflow per locale.

## Requirements

- Ruby >= 3.4.0
- Rails >= 8.1
- Node + Playwright Chromium (`npx playwright install chromium`)
- ffmpeg (for webm → mp4 transcoding and poster extraction)
- MinIO (optional; only needed for Phase 2.1 publishing). A local one-liner: `docker run -p 9000:9000 -p 9001:9001 minio/minio server /data --console-address :9001`

## Installation

Both host apps vendor the gem under `vendor/gems/workflows/` and reference it via a path Gemfile entry. This is deliberate: the runner, seeder, and publisher need to be in lockstep with the host's seed data and authentication, and vendoring lets us land coordinated changes across the gem + host in one commit.

Add to the host's `Gemfile`:

```ruby
gem "workflows", path: "vendor/gems/workflows"
```

Then:

```bash
bundle install
bin/rails generate workflows:install
bin/rails db:migrate
```

The install generator copies one migration (`create_workflows_videos`) — the AR-backed index of published videos used by `Workflows::Publisher`. There are no other schema additions.

## Host configuration

Every host app must ship `config/initializers/workflows.rb`. The full shape:

```ruby
Workflows.configure do |config|
  config.workflows_path     = Rails.root.join("config/workflows")
  config.videos_output_path = Rails.root.join("tmp/workflow_videos")
  config.host_name          = :lms   # or :school_os — used as the MinIO key prefix

  # Look up a User by the canonical email the demo seed assigns to a persona.
  # Returning nil raises PersonaNotFound at runner time.
  config.persona_resolver = lambda do |persona_key|
    persona = Workflows::Seed::DemoSchool.find_persona(persona_key)
    next nil unless persona
    User.find_by(email: persona[:email])
  end

  # Drive the host's real sign-in form with Playwright so recordings and
  # system tests exercise the same login path as real users.
  config.sign_in_adapter = lambda do |adapter, user|
    base =
      if ENV["WORKFLOWS_RECORD_HOST"]
        ENV["WORKFLOWS_RECORD_HOST"]
      elsif defined?(Capybara) && Capybara.current_session.server
        Capybara.current_session.server.base_url
      else
        "http://127.0.0.1:3000"
      end
    adapter.goto("#{base}/users/sign_in")
    adapter.fill("input[name='user[email]']", user.email)
    adapter.fill("input[name='user[password]']", "password")
    adapter.page.expect_navigation do
      adapter.page.click("button[type='submit']")
    end
  end

  # Phase 2.1 — optional. When the env vars are unset, publishing is a no-op
  # and the runner still records locally to videos_output_path.
  if ENV["WORKFLOWS_MINIO_ENDPOINT"].present?
    config.minio_client = Workflows::MinioClient.new(
      endpoint:   ENV.fetch("WORKFLOWS_MINIO_ENDPOINT"),
      access_key: ENV.fetch("WORKFLOWS_MINIO_ACCESS_KEY"),
      secret_key: ENV.fetch("WORKFLOWS_MINIO_SECRET_KEY"),
      bucket:     ENV.fetch("WORKFLOWS_MINIO_BUCKET", "workflow-videos")
    )
  end
end
```

The sign-in adapter is host-specific. LMS uses Devise (`/users/sign_in`, `user[email]`, `user[password]`). school-management uses `has_secure_password` (`/session/new`, `email_address`, `password`). Both shipped initializers are worth reading as paired examples.

## Authoring a workflow

Drop a YAML file under `config/workflows/<role>/<name>.yml`. Minimal shape:

```yaml
name: teacher/grade_assignment
title: teacher.grade_assignment.title
description: teacher.grade_assignment.description
host: lms
persona: teacher_ms_alvarez
start_at: 'teach_course_gradebook_index_path("algebra-i-fundamentals")'

setup: []

steps:
  - caption: teacher.grade_assignment.step_1
    wait_for: { selector: "[data-tour='gradebook-table']" }

  - caption: teacher.grade_assignment.step_2
    action: click
    target: "[data-tour='view-details-jordan']"

  - caption: teacher.grade_assignment.step_3
    wait_for: { selector: "[data-tour='student-gradebook-title']", contains: "Jordan" }

  - caption: teacher.grade_assignment.step_4
    assert: { selector: "[data-tour='student-grades']" }
```

Real example: [`config/workflows/teacher/grade_assignment.yml`](../../lms/config/workflows/teacher/grade_assignment.yml) in the lms app.

### Top-level keys

| Key | Required | Purpose |
|---|---|---|
| `name` | yes | Canonical id. Must match the file path (`teacher/grade_assignment` ↔ `config/workflows/teacher/grade_assignment.yml`). |
| `title` | yes | i18n key resolved at render time. Shown as popover header in the tour and on the video catalog. |
| `description` | yes | i18n key. Optional in the tour output. |
| `host` | yes | `lms` or `school_os`. Must match `config.host_name`; the runner ignores workflows targeting a different host. |
| `persona` | yes | Key into `Workflows::Seed::DemoSchool` — resolved to a `User` by the host's `persona_resolver`. |
| `start_at` | yes | Ruby expression evaluated against the host's URL helpers, e.g. `teach_course_gradebook_index_path("algebra-i-fundamentals")`. |
| `viewport` | no | `{ width, height }` — defaults to 1440 × 900. |
| `setup` | no | Array of host-specific fixture commands run before the first step. |
| `steps` | yes | Non-empty ordered list. |

### Step keys

| Key | Purpose |
|---|---|
| `caption` | Required. i18n key (`teacher.grade_assignment.step_3`) or inline string. Displayed as subtitle in the video and as popover body in the tour. |
| `action` | One of `none` / `click` / `fill` / `select` / `check` / `uncheck` / `hover` / `press` / `upload` / `visit`. Defaults to `none` (caption-only). |
| `target` | Preferred selector. Should use the `[data-tour='…']` convention so the audit stays happy. |
| `target_css` | Escape hatch for when no `data-tour` hook is feasible. The audit will flag every use. |
| `value` | Required for `fill` and `select`. |
| `wait_for` | `{ selector: "...", contains: "..." }` — blocks until the DOM satisfies it. |
| `assert` | `{ selector: "...", contains: "..." }` — fails the test if not present. |
| `hold_ms` | Extra pause (ms) before moving on. Only affects recording, not test time. |

Strict schema: unknown keys raise `Workflows::YamlLoader::SchemaError` with the filename in the message.

### i18n captions

Every `caption` key referenced in a YAML file must exist in `config/locales/workflows.<locale>.yml` in the host app. The audit rake task verifies this against `I18n.default_locale`; locales present as files but missing a key fall back to I18n's standard missing-translation behavior.

## Running workflows

Seven rake tasks are provided. The three most common during dev:

```bash
# Validate every YAML: schema, duplicate names, missing i18n keys, target_css escape hatches.
bin/rails workflows:audit

# Regenerate the Minitest system tests from YAML, then run them.
bin/rails workflows:compile_tests
bin/rails test:system test/system/workflows/

# Record one workflow to MP4 + VTT under tmp/workflow_videos/.
# Boot the Rails server first (bin/dev); the runner navigates to it over HTTP.
bin/rails 'workflows:render[teacher/grade_assignment]'
```

The compiled tests are checked into the host's `test/system/workflows/` tree — git sees every workflow change, not just the YAML edit.

## Publishing (Phase 2.1)

Publishing takes a locally-rendered MP4 + VTT, extracts a poster JPEG with ffmpeg, uploads all three to MinIO, and writes a row to `workflows_videos`.

```bash
# One workflow × one locale.
bin/rails 'workflows:publish[teacher/grade_assignment,en]'

# Every workflow × every locale that has a config/locales/workflows.<locale>.yml.
bin/rails workflows:publish_all

# Only the workflows whose YAML changed in the current PR (falls back to publish_all
# if non-workflow files are also touched).
bin/rails workflows:affected

# Print a Markdown table of current/ signed URLs — pasted into docs and release notes.
bin/rails workflows:catalog
```

### MinIO key layout

```
workflow-videos/
├── lms/
│   ├── main/<sha>/teacher-grade_assignment-en.{mp4,vtt,jpg}    # every main-branch render, keyed by commit
│   ├── current/teacher-grade_assignment-en.{mp4,vtt,jpg}       # overwritten on every main render; what the catalog links to
│   └── prs/<pr_number>/<sha>/...                               # 7-day TTL (lifecycle rule from bin/workflows-minio-bootstrap)
└── school_os/
    └── ...
```

`main/` is immutable per-SHA. `current/` is a single pointer that marketing and docs can hotlink without ever updating the URL. `prs/` gets auto-expired by the MinIO lifecycle rule the bootstrap script installs, so preview renders don't accumulate.

CI runs `workflows:affected` on pull requests (narrow, dedup-skips any `main/<sha>` that's already uploaded) and `workflows:publish_all` on pushes to `main` and nightly. See `.github/workflows/workflow-videos.yml` in each host for the full pipeline.

For the full design — why MinIO, why per-SHA + current/ pointer, CI layout, PR comment format — read `docs/superpowers/specs/2026-04-20-workflow-videos-hosting-design.md` in the school-management repo.

## Tutorials integration

Both host apps mount the [`tutorials`](https://github.com/ye-lin-aung/tutorials) gem alongside `workflows`. The two are wired together through `Tutorials::SourceResolver`: the workflows engine registers a lambda that reads every `config/workflows/*.yml`, compiles each through `Workflows::Compilers::Tour`, and hands back tour-shape hashes which the tutorials registry loads alongside any legacy `config/tours/*.yml`.

The upshot: authoring a workflow automatically gives you a driver.js tour. There's no duplicate YAML, no hand-kept id mapping, no extra generator step. The tour's `id` is the workflow's `name` with slashes swapped for dots (`teacher/grade_assignment` → `teacher.grade_assignment`). Caption i18n keys pass through verbatim; the tutorials gem resolves them at render time.

Caption-only steps (no `target` / `target_css`) are dropped from the tour projection — driver.js requires an element to highlight — but they still appear as subtitles in the video.

## Examples

- [`docs/EXAMPLES.md`](docs/EXAMPLES.md) — cookbook with 15 recipes covering common authoring patterns, both host initializer shapes (Devise + `has_secure_password`), programmatic invocation, and debugging.
- [`examples/workflows/`](examples/workflows/) — 4 copy-pasteable archetype YAMLs: form fill, multi-step wizard, read-only navigation, async content.

## Development

The gem ships a dummy Rails app under `test/dummy/` used by every test. Run the suite:

```bash
bundle install
npx playwright install chromium   # Playwright-dependent tests need Chromium locally
bundle exec rake test
```

Tests cover:
- YAML loader (schema validation, error messages)
- All three compilers (Tour, SystemTest, WebVTT)
- Both runner modes (TestMode, RecordMode) — the RecordMode test is a smoke test that actually boots Chromium
- Audit
- Publisher (MinIO uploads, dedup, record persistence — MinioClient is stubbed via `Aws::S3::Client#stub_responses`)
- Catalog
- MinioClient (direct AWS SDK stubs)
- PrCommenter (Octokit stubbed)
- Seed adapters (lms + school_os)

### Testing against MinIO

The `Publisher` tests stub MinIO; to exercise the real path end-to-end, bring up a local MinIO and run the bootstrap script:

```bash
docker run -d -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=minioadmin -e MINIO_ROOT_PASSWORD=minioadmin \
  minio/minio server /data --console-address :9001

export WORKFLOWS_MINIO_ENDPOINT=http://localhost:9000
export WORKFLOWS_MINIO_ACCESS_KEY=minioadmin
export WORKFLOWS_MINIO_SECRET_KEY=minioadmin
export WORKFLOWS_MINIO_BUCKET=workflow-videos

bin/workflows-minio-bootstrap        # creates bucket, applies 7-day TTL on prs/ prefixes
```

From there, `bin/rails workflows:publish_all` in either host app hits your local MinIO.

## Architecture

Three layers:

```
┌───────────────────────────────────────────────────────────┐
│  Authoring                                                │
│    config/workflows/<role>/<name>.yml                     │
│    Workflows::YamlLoader → Workflows::Workflow + Step     │
│    Workflows::Audit (selector discipline, i18n coverage)  │
├───────────────────────────────────────────────────────────┤
│  Compilers (pure functions of a Workflow)                 │
│    Workflows::Compilers::Tour        → tutorials gem      │
│    Workflows::Compilers::SystemTest  → test/system/…      │
│    Workflows::Compilers::Webvtt      → foo.vtt            │
├───────────────────────────────────────────────────────────┤
│  Execution                                                │
│    Workflows::Runner::Base           (dispatch + seed)    │
│    Workflows::Runner::TestMode       (Capybara)           │
│    Workflows::Runner::RecordMode     (Playwright + ffmpeg)│
│    Workflows::Seed::DemoSchool + host adapters            │
│    Workflows::Publisher → MinioClient → Workflows::Video  │
│    Workflows::Catalog / Workflows::PrCommenter            │
└───────────────────────────────────────────────────────────┘
```

The authoring and compiler layers are pure Ruby — no Rails boot needed to load them. The execution layer depends on the host: the seed adapters need host models, the runner's sign-in adapter needs the host's auth, and the publisher needs MinIO. This separation keeps the YAML loader + three compilers fast and unit-testable in isolation.

## Design docs

Full design and implementation plans live in the school-management repo:

- `docs/superpowers/specs/2026-04-20-workflows-design.md` — Phase 1 design
- `docs/superpowers/plans/2026-04-20-workflows.md` — Phase 1 plan
- `docs/superpowers/specs/2026-04-20-workflow-videos-hosting-design.md` — Phase 2.1 design (MinIO, CI, catalog, PR comments)
- `docs/superpowers/plans/2026-04-20-workflow-videos-hosting.md` — Phase 2.1 plan

## License

MIT — see `MIT-LICENSE`.
