class CreatePipelineItemConversationsAndEvents < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_item_conversations
    create_pipeline_item_events
  end

  private

  def create_pipeline_item_conversations
    create_table :pipeline_item_conversations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_item, null: false, foreign_key: true
      t.references :conversation, null: false, foreign_key: { on_delete: :cascade }
      t.references :linked_by, null: false, foreign_key: { to_table: :users }
      t.string :source, null: false

      t.timestamps
    end

    add_index :pipeline_item_conversations,
              [:pipeline_item_id, :conversation_id],
              unique: true,
              name: 'index_pipeline_item_conversations_on_item_and_conversation'
  end

  def create_pipeline_item_events
    create_table :pipeline_item_events do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_item, null: false, foreign_key: true
      t.references :conversation, foreign_key: { on_delete: :nullify }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :event_type, null: false
      t.string :source, null: false

      t.timestamps
    end

    add_index :pipeline_item_events,
              [:pipeline_item_id, :created_at],
              name: 'index_pipeline_item_events_on_item_and_created_at'
    add_check_constraint :pipeline_item_events,
                         'event_type BETWEEN 0 AND 1',
                         name: 'pipeline_item_events_type_range'
  end
end
