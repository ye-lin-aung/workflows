# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_20_000001) do
  create_table "workflows_videos", force: :cascade do |t|
    t.string "commit_sha", null: false
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "locale", null: false
    t.string "mp4_key", null: false
    t.string "poster_key", null: false
    t.integer "pr_number"
    t.datetime "rendered_at", null: false
    t.string "source", null: false
    t.datetime "updated_at", null: false
    t.string "vtt_key", null: false
    t.string "workflow_name", null: false
    t.index ["workflow_name", "locale", "commit_sha", "source"], name: "index_workflows_videos_identity", unique: true
    t.index ["workflow_name", "locale", "source", "rendered_at"], name: "index_workflows_videos_latest"
  end
end
