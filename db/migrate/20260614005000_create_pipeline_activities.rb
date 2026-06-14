class CreatePipelineActivities < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_activities
    add_pipeline_activity_indexes
    extend_pipeline_item_events
  end

  private

  def create_pipeline_activities
    create_table :pipeline_activities do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_item, null: false, foreign_key: true
      t.references :assignee, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :created_by, foreign_key: { to_table: :users, on_delete: :nullify }
      t.integer :activity_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.string :title, null: false
      t.datetime :due_at, null: false
      t.datetime :completed_at
      t.datetime :canceled_at
      t.text :notes
      t.timestamps
    end
  end

  def add_pipeline_activity_indexes
    add_index :pipeline_activities,
              [:pipeline_item_id, :status, :due_at],
              name: 'index_pipeline_activities_on_item_status_due_at'
    add_index :pipeline_activities,
              [:assignee_id, :status, :due_at],
              name: 'index_pipeline_activities_on_assignee_status_due_at'
    add_check_constraint :pipeline_activities,
                         'activity_type >= 0 AND activity_type <= 4',
                         name: 'pipeline_activities_type_range'
    add_check_constraint :pipeline_activities,
                         'status >= 0 AND status <= 2',
                         name: 'pipeline_activities_status_range'
  end

  def extend_pipeline_item_events
    add_reference :pipeline_item_events,
                  :pipeline_activity,
                  foreign_key: { on_delete: :nullify }
    add_column :pipeline_item_events, :metadata, :jsonb, null: false, default: {}
    remove_check_constraint :pipeline_item_events, name: 'pipeline_item_events_type_range'
    add_check_constraint :pipeline_item_events,
                         'event_type >= 0 AND event_type <= 8',
                         name: 'pipeline_item_events_type_range'
  end
end
