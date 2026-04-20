class CreateWorkflowsVideos < ActiveRecord::Migration[8.1]
  def change
    create_table :workflows_videos do |t|
      t.string  :workflow_name, null: false
      t.string  :locale,        null: false
      t.string  :commit_sha,    null: false
      t.string  :source,        null: false
      t.integer :pr_number
      t.integer :duration_ms
      t.datetime :rendered_at,  null: false
      t.string  :mp4_key,       null: false
      t.string  :vtt_key,       null: false
      t.string  :poster_key,    null: false
      t.timestamps
    end

    add_index :workflows_videos,
              [:workflow_name, :locale, :commit_sha, :source],
              unique: true,
              name: "index_workflows_videos_identity"
    add_index :workflows_videos,
              [:workflow_name, :locale, :source, :rendered_at],
              name: "index_workflows_videos_latest"
  end
end
