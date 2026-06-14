class CreatePipelineItemStageTransitions < ActiveRecord::Migration[7.1]
  def change
    create_table :pipeline_item_stage_transitions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_item, null: false, foreign_key: true
      t.references :from_stage, null: false, foreign_key: { to_table: :pipeline_stages }
      t.references :to_stage, null: false, foreign_key: { to_table: :pipeline_stages }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :source, null: false

      t.timestamps
    end

    add_index :pipeline_item_stage_transitions,
              [:pipeline_item_id, :created_at],
              name: 'index_pipeline_item_transitions_on_item_and_created_at'
  end
end
