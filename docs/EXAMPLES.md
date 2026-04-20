# Workflows cookbook

Fifteen recipes covering the patterns you hit while authoring, running, and
debugging workflows. Every code block is meant to be copy-pasteable — no
`...` placeholders. Where a recipe assumes host-specific wiring (initializer,
i18n file), the companion recipe is cross-linked.

If you are new to the gem: read `../README.md` first for the install + schema
overview, then come back here.

## Table of contents

1. [Minimal workflow](#1-minimal-workflow)
2. [Form fill](#2-form-fill)
3. [Async content with `wait_for` + `contains`](#3-async-content-with-wait_for--contains)
4. [Turbo frame update](#4-turbo-frame-update)
5. [Multi-step wizard](#5-multi-step-wizard)
6. [Read-only navigation](#6-read-only-navigation)
7. [`target_css` escape hatch](#7-target_css-escape-hatch)
8. [Multi-locale workflow](#8-multi-locale-workflow)
9. [Per-workflow `setup:` block](#9-per-workflow-setup-block)
10. [Devise + Jumpstart initializer](#10-devise--jumpstart-initializer)
11. [`has_secure_password` + sessions initializer](#11-has_secure_password--sessions-initializer)
12. [Running a workflow programmatically](#12-running-a-workflow-programmatically)
13. [Publishing programmatically](#13-publishing-programmatically)
14. [FakeAdapter for runner unit tests](#14-fakeadapter-for-runner-unit-tests)
15. [Debugging a failing system test](#15-debugging-a-failing-system-test)

---

## 1. Minimal workflow

When to use: as your starting template for any new workflow. Shows the
smallest YAML the loader accepts — navigate to a route, assert one selector
is present, done.

```yaml
name: teacher/view_gradebook
title: teacher.view_gradebook.title
description: teacher.view_gradebook.description
host: lms
persona: teacher_ms_alvarez
start_at: 'teach_course_gradebook_index_path("algebra-i-fundamentals")'

setup: []

steps:
  - caption: teacher.view_gradebook.step_1
    wait_for: { selector: "[data-tour='gradebook-table']" }

  - caption: teacher.view_gradebook.step_2
    assert: { selector: "[data-tour='gradebook-row-jordan']" }
```

Every top-level key in this file is required except `viewport` and `setup`.
`name` must match the file path under `config/workflows/` (so this lives at
`config/workflows/teacher/view_gradebook.yml`). `host` must be one of `lms`
or `school_os` and must match `Workflows.config.host_name` — the runner
ignores workflows targeting a different host. `persona` is a key into
`Workflows::Seed::DemoSchool` and gets resolved to a real `User` record by
your host's `persona_resolver` (Recipe 10, Recipe 11). `start_at` is a Ruby
expression — `instance_eval`ed against `Rails.application.routes.url_helpers`,
so anything a URL helper would accept works.

`caption` is the only required field on a step. Everything else is optional.
A step with no `action` defaults to `action: none` — a caption-only step that
just waits or asserts. Captions here are i18n keys (Recipe 8); use inline
strings if you prefer.

---

## 2. Form fill

When to use: any flow where the user creates or edits a record. Covers every
writing action in `Workflows::Step::ALLOWED_ACTIONS` — `fill`, `select`,
`check`, `uncheck`, `click` — plus a wait-for-substring assertion on the
success state.

```yaml
name: teacher/create_assignment
title: teacher.create_assignment.title
description: teacher.create_assignment.description
host: lms
persona: teacher_ms_alvarez
start_at: 'new_teach_course_assignment_path("algebra-i-fundamentals")'

setup: []

steps:
  - caption: teacher.create_assignment.step_1
    wait_for: { selector: "[data-tour='assignment-form']" }

  - caption: teacher.create_assignment.step_2
    action: fill
    target: "[data-tour='assignment-title']"
    value: "Factoring Quadratics — Problem Set 3"

  - caption: teacher.create_assignment.step_3
    action: fill
    target: "[data-tour='assignment-instructions']"
    value: "Complete problems 1 through 20 from section 4.3. Show all work."

  - caption: teacher.create_assignment.step_4
    action: select
    target: "[data-tour='assignment-type']"
    value: "homework"

  - caption: teacher.create_assignment.step_5
    action: fill
    target: "[data-tour='assignment-due-date']"
    value: "2026-05-15"

  - caption: teacher.create_assignment.step_6
    action: check
    target: "[data-tour='assignment-allow-late']"

  - caption: teacher.create_assignment.step_7
    action: uncheck
    target: "[data-tour='assignment-notify-parents']"

  - caption: teacher.create_assignment.step_8
    action: click
    target: "[data-tour='assignment-submit']"
    wait_for: { selector: "[data-tour='flash-notice']", contains: "Assignment was successfully created" }

  - caption: teacher.create_assignment.step_9
    assert: { selector: "[data-tour='assignment-detail-hero']" }
```

`fill` and `select` both require a `value`; the schema loader raises
`SchemaError` at load time if you omit it. `check` and `uncheck` operate on
checkbox inputs and don't take a value. The last step's `wait_for.contains`
lets the runner block until the flash message appears before asserting the
detail hero — otherwise a slow-rendering redirect could race the assertion.
Combine with Recipe 3 for AJAX-driven form submits.

---

## 3. Async content with `wait_for` + `contains`

When to use: any step where the DOM changes after the runner's action
completes — Turbo Stream responses, fetch-based updates, long-polling
indicators. `wait_for` re-polls until the selector exists *and* (optionally)
its text content includes the given substring.

```yaml
name: student/submit_quiz_answer
title: student.submit_quiz_answer.title
description: student.submit_quiz_answer.description
host: lms
persona: student_jordan_patel
start_at: 'assessment_path(Assessment.find_by!(title: "Algebra I Fundamentals Quiz"))'

setup: []

steps:
  - caption: student.submit_quiz_answer.step_1
    wait_for: { selector: "[data-tour='question-0']" }

  - caption: student.submit_quiz_answer.step_2
    action: fill
    target: "[data-tour='short-answer']"
    value: "x = 3 or x = -5"

  - caption: student.submit_quiz_answer.step_3
    action: click
    target: "[data-tour='save-answer']"

  - caption: student.submit_quiz_answer.step_4
    # Server responds with a Turbo Stream that updates the status pill.
    # wait_for blocks until the pill's text contains "Saved".
    wait_for: { selector: "[data-tour='answer-status']", contains: "Saved" }
    hold_ms: 800

  - caption: student.submit_quiz_answer.step_5
    assert: { selector: "[data-tour='answer-status']", contains: "Saved" }
```

`wait_for` without `contains` blocks until the selector matches any element
(Playwright's default `wait_for_selector`). `wait_for` *with* `contains`
additionally uses `wait_for_function` to poll the element's `textContent`
every animation frame until the substring appears — so it survives Turbo's
asynchronous morph. `hold_ms` pauses for 800ms *after* the wait succeeds;
this is purely for the recorded video's pacing and has no effect on test
runtime.

The default Playwright timeout is 10 seconds per wait. Raise it via an
environment variable if you need to — see Recipe 15.

---

## 4. Turbo frame update

When to use: a step where the response lands in a named `<turbo-frame>` on
the page — gradebook row updates, inline edits, filter refreshes. The adapter
looks up `turbo-frame#<id>` specifically rather than a CSS selector, so you
don't have to remember the frame's DOM structure.

```yaml
name: teacher/inline_grade_update
title: teacher.inline_grade_update.title
description: teacher.inline_grade_update.description
host: lms
persona: teacher_ms_alvarez
start_at: 'teach_course_gradebook_index_path("algebra-i-fundamentals")'

setup: []

steps:
  - caption: teacher.inline_grade_update.step_1
    wait_for: { selector: "[data-tour='gradebook-table']" }

  - caption: teacher.inline_grade_update.step_2
    action: click
    target: "[data-tour='grade-cell-row-42']"
    wait_for: { selector: "[data-tour='grade-cell-input-row-42']" }

  - caption: teacher.inline_grade_update.step_3
    action: fill
    target: "[data-tour='grade-cell-input-row-42']"
    value: "85"

  - caption: teacher.inline_grade_update.step_4
    action: press
    target: "[data-tour='grade-cell-input-row-42']"
    value: "Enter"
    wait_for: { turbo_frame: "row-42", contains: "85" }

  - caption: teacher.inline_grade_update.step_5
    assert: { selector: "[data-tour='grade-cell-row-42']", contains: "85" }
```

`wait_for: { turbo_frame: "row-42", contains: "85" }` is translated by the
adapter into `wait_for_selector("turbo-frame#row-42", contains: "85")`. If
your frame renders in stages (outer frame first, then inner content), the
`contains` clause re-polls until the substring shows up, so you don't get a
false-positive on a momentarily empty frame.

`press` with `value: "Enter"` dispatches a keypress — useful for forms that
submit on `Enter` without a separate click. If you omit `value`, `press`
defaults to `Enter` (see `Workflows::Runner::Base#dispatch`).

---

## 5. Multi-step wizard

When to use: onboarding flows, multi-page forms, any UI where the user clicks
"Continue" several times and you need to wait for the next panel to render
before proceeding. The pattern is: wait for the current step's container,
fill its inputs, click Continue, wait for the *next* step's container.

```yaml
name: admin/onboard_school
title: admin.onboard_school.title
description: admin.onboard_school.description
host: school_os
persona: admin_new_marisol
start_at: onboarding_wizard_path

setup: []

steps:
  - caption: admin.onboard_school.step_1
    wait_for: { selector: "[data-tour-step='onboarding-step-school']" }

  - caption: admin.onboard_school.step_2
    action: fill
    target: "[data-tour='onboarding-school-name']"
    value: "Mapleton Secondary"

  - caption: admin.onboard_school.step_3
    action: click
    target: "[data-tour='onboarding-continue']"
    wait_for: { selector: "[data-tour-step='onboarding-step-academic-year']" }

  - caption: admin.onboard_school.step_4
    action: fill
    target: "[data-tour='onboarding-ay-name']"
    value: "2026/2027"

  - caption: admin.onboard_school.step_5
    action: fill
    target: "[data-tour='onboarding-ay-start']"
    value: "2026-08-01"

  - caption: admin.onboard_school.step_6
    action: click
    target: "[data-tour='onboarding-continue']"
    wait_for: { selector: "[data-tour-step='onboarding-step-terms']" }

  - caption: admin.onboard_school.step_7
    action: click
    target: "[data-tour='onboarding-continue']"
    wait_for: { selector: "[data-tour-step='onboarding-step-programme-grades']" }

  - caption: admin.onboard_school.step_8
    action: fill
    target: "[data-tour='onboarding-programme-name']"
    value: "Main Programme"

  - caption: admin.onboard_school.step_9
    action: click
    target: "[data-tour='onboarding-finish']"
    wait_for: { selector: "[data-tour='dashboard-welcome']" }

  - caption: admin.onboard_school.step_10
    assert: { selector: "[data-tour='dashboard-welcome']" }
```

The key discipline is the `wait_for` on every Continue click. Without it,
the next step's `fill` races the Turbo swap and writes into the previous
step's input — which fails silently on a fast machine and flakily on CI.
Always structure wizards as `click Continue, wait_for next-step-container`.

Use `[data-tour-step='...']` as a convention for the wizard step containers
themselves (plural) and reserve `[data-tour='...']` for individual widgets
inside a step. That keeps the audit output (Recipe 7) readable when a step
container is missing.

For a full 19-step version with the same pattern, see
`school-management/config/workflows/admin/onboard_school.yml` in the host
app. The `examples/workflows/multi_step_wizard.yml` archetype in this repo
is a condensed 14-step template you can drop in unchanged.

---

## 6. Read-only navigation

When to use: product tours that show the viewer around without changing
data — a parent viewing a child's progress, a student browsing available
courses. No writes means no `setup:`, no fixtures to worry about, no cleanup
between runs. Lean on `hold_ms` to pace the video for human comprehension.

```yaml
name: parent/view_child
title: parent.view_child.title
description: parent.view_child.description
host: school_os
persona: parent_priya_patel
start_at: parent_root_path

setup: []

steps:
  - caption: parent.view_child.step_1
    wait_for: { selector: "[data-tour='parent-dashboard-hero']" }

  - caption: parent.view_child.step_2
    action: click
    target: "[data-tour='parent-child-open-jordan']"
    wait_for: { selector: "[data-tour='parent-child-detail-hero']" }

  - caption: parent.view_child.step_3
    wait_for: { selector: "[data-tour='parent-child-grades']" }
    hold_ms: 1200

  - caption: parent.view_child.step_4
    wait_for: { selector: "[data-tour='parent-child-attendance']" }
    hold_ms: 1200

  - caption: parent.view_child.step_5
    action: click
    target: "[data-tour='parent-back-to-dashboard']"
    wait_for: { selector: "[data-tour='parent-dashboard-hero']" }
```

`hold_ms` is a recording-only pause. The runner sleeps for `hold_ms / 1000.0`
seconds after the caption updates but before the next step dispatches; in
`TestMode` this is skipped entirely, so your system test runtime doesn't
balloon. 1200ms is a good default for "look at this" steps — long enough for
a human to read and scan the region, short enough that a six-step video stays
under ten seconds.

`action: hover` is also useful for read-only tours — hovering highlights the
target element with the cursor overlay (see
`lib/workflows/runner/cursor_overlay.rb`) without firing any click handler.

---

## 7. `target_css` escape hatch

When to use: you genuinely can't add a `data-tour` attribute to the element
you need to act on. Common cases: a third-party library (a date picker's
calendar day cell, a Stripe Elements iframe) or a dynamically-generated SVG
that doesn't let you drop attributes on its descendants.

```yaml
name: admin/attach_legacy_widget
title: admin.attach_legacy_widget.title
description: admin.attach_legacy_widget.description
host: school_os
persona: admin_new_marisol
start_at: admin_widgets_path

setup: []

steps:
  - caption: admin.attach_legacy_widget.step_1
    wait_for: { selector: "[data-tour='widget-panel']" }

  - caption: admin.attach_legacy_widget.step_2
    action: click
    # Third-party chart.js legend has no data-tour hook and we can't
    # monkey-patch its renderer.
    target_css: ".chartjs-legend-item:nth-child(2)"
    wait_for: { selector: "[data-tour='legend-detail']" }

  - caption: admin.attach_legacy_widget.step_3
    assert: { selector: "[data-tour='legend-detail']", contains: "Revenue" }
```

The audit flags this step at load time. Running
`bin/rails workflows:audit` prints an entry like:

```
{ kind: :target_css_escape_hatch,
  workflow: "admin/attach_legacy_widget",
  step_index: 1,
  selector: ".chartjs-legend-item:nth-child(2)" }
```

The audit never fails the build on escape hatches — they're a deliberate
feature — but the count is reviewed per PR. When you have to use one,
open the PR with:

1. A comment on the affected step explaining *why* `data-tour` isn't
   feasible (third-party library, generated markup, etc.).
2. If the third-party can be wrapped in your own component that *does*
   expose `data-tour`, prefer that — the escape hatch is a smell, not a
   permanent solution.

See `Workflows::Step#escape_hatch?` for the detection logic: any step where
`target` is nil and `target_css` is present.

---

## 8. Multi-locale workflow

When to use: the user-facing title, description, and step captions need to
render in more than one language. The YAML stays locale-agnostic — captions
are i18n keys — and you add one `config/locales/workflows.<locale>.yml` per
language. `Workflows::Publisher` reads the list of locales from that file
set at publish time.

The workflow:

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

`config/locales/workflows.en.yml`:

```yaml
en:
  teacher:
    grade_assignment:
      title: "Grade an assignment"
      description: "Open a student's gradebook and review their work."
      step_1: "We land on the gradebook table."
      step_2: "Click Jordan's row to open their detail view."
      step_3: "The detail view confirms we're on Jordan's record."
      step_4: "The per-assignment grades are now visible."
```

`config/locales/workflows.es.yml`:

```yaml
es:
  teacher:
    grade_assignment:
      title: "Calificar una tarea"
      description: "Abre la libreta de calificaciones de un estudiante y revisa su trabajo."
      step_1: "Llegamos a la tabla de la libreta de calificaciones."
      step_2: "Haz clic en la fila de Jordan para abrir su vista de detalle."
      step_3: "La vista de detalle confirma que estamos en el registro de Jordan."
      step_4: "Las calificaciones por tarea ya son visibles."
```

To record a Spanish video:

```bash
LOCALE=es bin/rails 'workflows:render[teacher/grade_assignment]'
```

`RecordMode` reads `ENV["LOCALE"]` and wraps the whole render in
`I18n.with_locale`, so every caption resolves into the target language.
`Workflows::Publisher.publish_all` discovers locales by globbing
`config/locales/workflows.*.yml` — drop a new file in, CI picks it up on
the next run.

The audit (`bin/rails workflows:audit`) checks every caption key against
`I18n.default_locale` and prints any missing keys as `{ kind:
:missing_i18n_key }` entries. Non-default locales aren't checked — that's
intentional; Rails' normal missing-translation fallback surfaces gaps
visibly enough for QA.

---

## 9. Per-workflow `setup:` block

When to use: the workflow needs a fixture the demo seed doesn't ship — an
edge-case record, a pre-existing draft, a parent-student relationship that
only exists for this scenario. The `setup:` key takes an array of
`{ factory:, attrs: }` hashes; the runner calls
`factory.to_s.classify.safe_constantize.create!(attrs)` before the first
step.

```yaml
name: teacher/grade_late_submission
title: teacher.grade_late_submission.title
description: teacher.grade_late_submission.description
host: lms
persona: teacher_ms_alvarez
start_at: 'teach_course_gradebook_index_path("algebra-i-fundamentals")'

setup:
  - factory: assignment
    attrs:
      course_id: 1
      title: "Late-homework Problem Set"
      due_at: "2026-04-01T00:00:00Z"
      allow_late: true
  - factory: submission
    attrs:
      assignment_id: 42
      student_id: 7
      submitted_at: "2026-04-10T14:22:00Z"
      state: "submitted_late"

steps:
  - caption: teacher.grade_late_submission.step_1
    wait_for: { selector: "[data-tour='gradebook-table']" }

  - caption: teacher.grade_late_submission.step_2
    action: click
    target: "[data-tour='submission-late-badge']"
    wait_for: { selector: "[data-tour='late-submission-detail']" }

  - caption: teacher.grade_late_submission.step_3
    assert: { selector: "[data-tour='late-submission-detail']", contains: "10 April" }
```

The resolution is literal: `"assignment".classify` → `"Assignment"` →
`Assignment.create!(course_id: 1, ...)`. Use the real model name; namespaced
models work too (`factory: "billing/invoice"` → `Billing::Invoice`).

`setup:` is best used as a shim, not a replacement for the demo seed.
`Workflows::Seed::DemoSchool` seeds the baseline persona, course, and
assignment graph that every workflow relies on; `setup:` just layers on the
one or two extras this particular scenario needs. If you find yourself
writing a 15-line `setup:`, consider adding the data to the shared seed
instead.

Setup runs only in `TestMode`. `RecordMode` hits a live Rails server and
assumes the seed has already been run via `bin/rails db:seed`. This is
deliberate — record mode is for manual video rendering against a running
app, not for creating isolated scenarios.

---

## 10. Devise + Jumpstart initializer

When to use: your host is built on Jumpstart Pro (or any Devise-backed Rails
app). The `sign_in_adapter` drives the standard `/users/sign_in` form with
Playwright — same path a real user would take — so Warden, after-sign-in
redirects, and any Devise hooks all fire. This is the initializer shape for
the `lms` host.

```ruby
# config/initializers/workflows.rb
Workflows.configure do |config|
  config.workflows_path     = Rails.root.join("config/workflows")
  config.videos_output_path = Rails.root.join("tmp/workflow_videos")
  config.host_name          = :lms

  # Persona resolver — maps a persona key from the YAML to a real User.
  # The demo seed assigns canonical emails per persona; we look those up.
  # Return nil to cause the runner to raise PersonaNotFound.
  config.persona_resolver = lambda do |persona_key|
    persona = Workflows::Seed::DemoSchool.find_persona(persona_key)
    next nil unless persona
    User.find_by(email: persona[:email])
  end

  # Sign-in adapter — drives the Devise form with Playwright.
  # Every call is wrapped so it works whether we're running under a booted
  # Capybara server (system tests) or against a free-standing Rails dev
  # server (bin/rails workflows:render).
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
    # Wait for the navigation Devise kicks off after a successful POST.
    # Without this, the next adapter.goto races the form submission and can
    # land back on /users/sign_in.
    adapter.page.expect_navigation do
      adapter.page.click("button[type='submit']")
    end
  end

  # Phase 2.1: MinIO client for published videos. When the env vars are
  # unset, publishing is a no-op and the runner still records locally to
  # videos_output_path.
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

The dev password `"password"` is a seed convention — every persona the demo
seed creates has this password, which is fine because the seed runs only
under `Rails.env.test?` or `Rails.env.development?`. If your seed uses a
different convention, change the literal in the adapter.

`adapter.page.expect_navigation do ... end` wraps the click in a navigation
wait — it blocks until the browser reports that a new document has loaded.
Without it, `adapter.page.click` returns as soon as Playwright dispatches the
click, which is well before the server's 302 comes back. The very next
`adapter.goto(start_at)` in the runner then races the redirect and lands
you back on the sign-in page intermittently on slow CI.

Companion: Recipe 11 is the same shape for hosts that use `has_secure_password`
instead of Devise.

---

## 11. `has_secure_password` + sessions initializer

When to use: your host uses Rails' built-in `has_secure_password` (8.x
authentication generator) and a hand-rolled `SessionsController` at
`/session`. No Devise, no Warden. This is the initializer shape for the
`school-management` host.

```ruby
# config/initializers/workflows.rb
Workflows.configure do |config|
  config.workflows_path     = Rails.root.join("config/workflows")
  config.videos_output_path = Rails.root.join("tmp/workflow_videos")
  config.host_name          = :school_os

  # Persona resolver — note `email_address`, not `email`. The 8.x auth
  # generator uses the more verbose column name; has_secure_password itself
  # doesn't care what you call the column, so hosts differ.
  config.persona_resolver = lambda do |persona_key|
    persona = Workflows::Seed::DemoSchool.find_persona(persona_key)
    next nil unless persona
    User.find_by(email_address: persona[:email])
  end

  # Sign-in adapter — drives the /session/new form with Playwright.
  # Mirror the Devise adapter's base-URL selection so the same lambda works
  # in system-test, record, and local-dev modes.
  config.sign_in_adapter = lambda do |adapter, user|
    base =
      if ENV["WORKFLOWS_RECORD_HOST"]
        ENV["WORKFLOWS_RECORD_HOST"]
      elsif defined?(Capybara) && Capybara.current_session.server
        Capybara.current_session.server.base_url
      else
        "http://127.0.0.1:3000"
      end
    adapter.goto("#{base}/session/new")
    adapter.fill("input[name='email_address']", user.email_address)
    adapter.fill("input[name='password']", "Password1!")
    # The built-in sessions form submits with an <input type="submit"> rather
    # than a button, so the click selector differs from the Devise flow.
    adapter.page.expect_navigation do
      adapter.page.click("input[type='submit']")
    end
  end

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

Three things that differ from the Devise version in Recipe 10:

1. `email_address` column instead of `email` — the 8.x auth generator's
   convention.
2. `/session/new` URL path instead of `/users/sign_in`.
3. `input[type='submit']` click target instead of `button[type='submit']`.

Everything else — the base-URL selection, the `expect_navigation` wrap, the
`host_name`, the MinIO wiring — is identical. Copy the Devise version and
change those three lines.

The seed convention for dev passwords on school-management is `"Password1!"`
(capital P, one digit, one symbol — whatever your host's password policy
requires). If the seed uses something else, change the literal.

---

## 12. Running a workflow programmatically

When to use: ad-hoc debugging, custom tooling that needs to render a
workflow on demand, or a one-off script that has to render multiple
workflows with shared expensive setup (a shared DB snapshot, for example).
The rake task is fine for day-to-day — reach for this when you need more
control.

```ruby
# From `bin/rails console` or a one-off script. Rails must be booted
# before this runs — Workflows::YamlLoader evaluates the workflow's
# start_at against Rails URL helpers.

workflow = Workflows::YamlLoader.load_file(
  Rails.root.join("config/workflows/teacher/grade_assignment.yml")
)

result = Workflows::Runner::RecordMode.new(
  workflow:   workflow,
  output_dir: Rails.root.join("tmp/workflow_videos")
).run

puts "MP4: #{result[:mp4]}"
puts "VTT: #{result[:vtt]}"
```

`RecordMode#run` returns a `{ mp4:, vtt: }` hash — the two paths of the
freshly-rendered files. MP4 is the transcoded video; VTT is the WebVTT
caption track compiled from the step captions with start/end timestamps per
step. You can drop both into an HTML5 `<video>` tag with
`<track kind="captions" src="...vtt">` and have a fully-captioned product
video, no extra tooling.

To render every workflow in one go:

```ruby
Workflows::YamlLoader
  .load_directory(Workflows.config.workflows_path.to_s)
  .each do |wf|
    puts "Rendering #{wf.name}..."
    Workflows::Runner::RecordMode.new(
      workflow:   wf,
      output_dir: Workflows.config.videos_output_path
    ).run
  end
```

`RecordMode` hits a live Rails server — make sure `bin/dev` is running, or
export `WORKFLOWS_RECORD_HOST=http://staging.example.com` to record against
a remote app. The sign-in adapter (Recipe 10 / Recipe 11) takes care of
authentication before the first step runs.

---

## 13. Publishing programmatically

When to use: one-off backfill of a video that didn't get published (dedup
collision, CI flake, missed locale), or testing the publish path locally
before pushing a CI change. The rake task `workflows:publish[NAME,LOCALE]`
covers the common case; reach for `Publisher.new.call` when you need to
pass a specific SHA or PR number from outside the usual git environment.

```ruby
result = Workflows::Publisher.new(
  workflow_name: "teacher/grade_assignment",
  locale:        "en",
  source:        "main",
  sha:           "deadbeef",
  pr_number:     nil
).call

# For a PR-scoped publish:
result = Workflows::Publisher.new(
  workflow_name: "teacher/grade_assignment",
  locale:        "en",
  source:        "pr",
  pr_number:     1234,
  sha:           "cafebabe"
).call
```

Defaults: `source` is derived from `ENV["PR_NUMBER"]` (present → `"pr"`,
absent → `"main"`), `sha` falls back to `ENV["GITHUB_SHA"]` or
`git rev-parse HEAD`, `pr_number` falls back to `ENV["PR_NUMBER"]`. Omit
any argument and the detection logic kicks in — the explicit call above is
useful when you're replaying from a known commit offline.

`Publisher#call` returns the `Workflows::Video` AR record for the
(workflow, locale, sha, source) tuple. If the MinIO key already exists and
`source == "pr"`, it skips the render entirely and returns the existing
record — MinIO's presence check is the dedup gate, so repeat runs are
cheap. Set `ENV["FORCE_RENDER"] = "1"` before calling if you want to bypass
dedup (e.g. after fixing a flaky render).

The shared MinIO key layout — `host/main/<sha>/...`,
`host/current/...`, `host/prs/<pr>/<sha>/...` — is documented in the
README. The current-pointer overwrite only happens for `source: "main"`,
not `"pr"`.

---

## 14. FakeAdapter for runner unit tests

When to use: testing your own extension of `Workflows::Runner::Base`, a
custom dispatch strategy, or any logic that calls into the runner and needs
to assert on *which* adapter calls happened in what order. Skips Playwright
entirely — no browser, no real DOM, runs in under a second.

The pattern comes straight from the gem's own tests
(`test/runner/base_test.rb`):

```ruby
require "test_helper"

class MyRunnerExtensionTest < ActiveSupport::TestCase
  class FakeAdapter
    attr_reader :calls, :values

    def initialize
      @calls  = []
      @values = {}
    end

    # Every action the runner might dispatch records itself into @calls
    # as [method_name, *args]. Tests inspect @calls to assert behavior.
    %i[goto click fill select check uncheck hover upload].each do |m|
      define_method(m) { |*args| @calls << [m, *args] }
    end

    def press(selector, key)          ; @calls << [:press, selector, key]        ; end
    def text(sel)                     ; @values[sel] || ""                       ; end
    def value(sel)                    ; @values[sel] || ""                       ; end
    def wait_for_selector(*a, **k)    ; @calls << [:wait_for_selector, *a, k]    ; end
    def wait_for_turbo_frame(*a, **k) ; @calls << [:wait_for_turbo_frame, *a, k] ; end
    def current_url                   ; "http://127.0.0.1:3000/"                 ; end
  end

  def fixture_workflow
    Workflows::YamlLoader.load_file(
      File.expand_path("../fixtures/workflows/grade_assignment.yml", __dir__)
    )
  end

  test "runs every step through the adapter" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(
      :@values,
      { "[data-tour='student-gradebook-title']" => "Jordan Patel" }
    )
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow)

    # Assert the step types fired in order.
    actions = adapter.calls.map(&:first)
    assert_equal :wait_for_selector, actions.first
    assert_includes actions, :click
  end

  test "passes fill values to the adapter" do
    adapter = FakeAdapter.new
    adapter.instance_variable_set(
      :@values,
      { "[data-tour='student-gradebook-title']" => "Jordan Patel" }
    )
    Workflows::Runner::Base.new(adapter: adapter).execute(fixture_workflow)

    fill = adapter.calls.find { |c| c[0] == :fill }
    assert_equal "[data-tour='name-input']", fill[1]
    assert_equal "Alice", fill[2]
  end
end
```

The FakeAdapter's surface area is the *exact* set of methods
`Workflows::Runner::Base#dispatch` and the wait/assert helpers call:
`click`, `fill`, `select`, `check`, `uncheck`, `hover`, `press`, `upload`,
`goto`, `wait_for_selector`, `wait_for_turbo_frame`, and the reader
`current_url`. Add any other adapter method your own subclass uses. Don't
bother stubbing Playwright itself — the runner never touches it directly.

Record mode does expect `video_path` and a `page` that responds to
`screenshot` and `content`; if you're testing RecordMode specifically, add
those. TestMode in isolation does not need them.

---

## 15. Debugging a failing system test

When to use: a workflow's compiled system test just failed on CI and you need
to figure out why. The gem saves a screenshot and HTML snapshot on every
failure, so you rarely have to guess.

**First, look at `tmp/workflow_failures/`.** `TestMode#run` rescues every
exception and writes two files before re-raising:

```
tmp/workflow_failures/teacher_grade_assignment.png
tmp/workflow_failures/teacher_grade_assignment.html
```

The filename is the workflow name with slashes turned into underscores. The
PNG is a full-page screenshot at the moment of failure. The HTML is
`adapter.page.content` — the post-Turbo DOM, not the server's original
response, so any Turbo Stream updates that ran are reflected. Open both,
compare to what the workflow expects. Nine times out of ten the answer is
obvious: a selector moved, a flash message is phrased differently, a
before-action redirected to the wrong page.

On GitHub Actions, add this to your CI job so the artifacts upload on
failure:

```yaml
- name: Upload workflow failure artifacts
  if: failure()
  uses: actions/upload-artifact@v4
  with:
    name: workflow-failures
    path: tmp/workflow_failures/
```

**To run a single workflow's compiled test in isolation:**

```bash
bin/rails workflows:compile_tests
bin/rails test test/system/workflows/teacher/grade_assignment_test.rb
```

The compile step is idempotent — run it after every YAML edit. Running the
single file takes maybe 15 seconds vs several minutes for the full suite.

**To temporarily raise the Playwright timeout:**

Each `wait_for_selector` call in the adapter uses a 10-second timeout by
default. If you're hitting timeouts on a specific step on a slow local
machine, set a higher one transiently via an env var and re-run:

```bash
WORKFLOWS_PLAYWRIGHT_TIMEOUT_MS=30000 \
  bin/rails test test/system/workflows/teacher/grade_assignment_test.rb
```

(Only applies if your fork of the adapter reads that env var — stock
`Workflows::Runner::PlaywrightAdapter#wait_for_selector` takes an explicit
`timeout_ms:` keyword; add a `timeout_ms: ENV.fetch(..., 10_000).to_i` line
to make it env-configurable.)

**To re-render the video for a failing workflow without running the test:**

```bash
bin/dev &                                                # server in another terminal
LOCALE=en bin/rails 'workflows:render[teacher/grade_assignment]'
```

`RecordMode` writes the MP4 to `tmp/workflow_videos/teacher_grade_assignment.mp4`
regardless of whether any step failed — the caption bar in the video ticks
through each step as it fires, so you can watch the exact moment the flow
breaks. Often the test fails because of a timing issue that only shows up
under full load (DB, Turbo, JS); the recorded video makes the sequence
visible.

**Common failure modes and what to check:**

- `PersonaNotFound`: your `persona_resolver` returned nil. Is the seed
  loaded? Is the canonical email in `Workflows::Seed::DemoSchool` still
  the same?
- `locator.click: Timeout exceeded`: the target selector isn't appearing.
  Run the audit (`bin/rails workflows:audit`) — if the selector was renamed,
  the audit's `tutorials:audit_selectors` equivalent catches it.
- Tests pass locally but fail on CI: usually a `wait_for` missing between a
  click and the next action. See Recipe 5 for the wizard pattern and
  Recipe 3 for async content.
- The screenshot shows a sign-in page: the `sign_in_adapter` silently
  failed. Add `adapter.page.screenshot(path: "tmp/post-signin.png")` right
  after the `expect_navigation` block and re-run — if the screenshot shows
  the login page still, the credentials didn't take (Recipe 10, Recipe 11).
