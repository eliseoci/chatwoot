class CreatePipelineIntakeRules < ActiveRecord::Migration[7.1]
  def change
    allow_system_conversation_links
    expand_pipeline_item_event_types
    create_pipeline_intake_rules
  end

  private

  def allow_system_conversation_links
    change_column_null :pipeline_item_conversations, :linked_by_id, true
  end

  def expand_pipeline_item_event_types
    remove_check_constraint :pipeline_item_events, name: 'pipeline_item_events_type_range'
    add_check_constraint :pipeline_item_events,
                         'event_type BETWEEN 0 AND 4',
                         name: 'pipeline_item_events_type_range'
  end

  def create_pipeline_intake_rules
    create_table :pipeline_intake_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :initial_stage, null: false, foreign_key: { to_table: :pipeline_stages }
      t.references :inbox, foreign_key: { on_delete: :cascade }
      t.string :channel_type
      t.boolean :enabled, default: true, null: false
      t.integer :position, default: 0, null: false

      t.timestamps
    end

    add_index :pipeline_intake_rules, [:account_id, :position]
    add_check_constraint :pipeline_intake_rules,
                         'position >= 0',
                         name: 'pipeline_intake_rules_position_non_negative'
  end
end
