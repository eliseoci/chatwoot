class AddPipelineCustomFields < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_field_definitions
    add_column :pipeline_items, :field_values, :jsonb, null: false, default: {}
    add_column :pipeline_stages, :required_field_keys, :string, array: true, null: false, default: []
    extend_pipeline_item_event_types
  end

  private

  def create_pipeline_field_definitions
    create_table :pipeline_field_definitions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.string :key, null: false
      t.string :label, null: false
      t.integer :field_type, null: false
      t.integer :position, null: false, default: 0
      t.jsonb :settings, null: false, default: {}
      t.datetime :archived_at

      t.timestamps
    end

    add_pipeline_field_definition_indexes
    add_pipeline_field_definition_constraints
  end

  def add_pipeline_field_definition_indexes
    add_index :pipeline_field_definitions, [:pipeline_id, :key], unique: true
    add_index :pipeline_field_definitions, [:pipeline_id, :archived_at, :position],
              name: 'index_pipeline_fields_on_pipeline_archive_position'
  end

  def add_pipeline_field_definition_constraints
    add_check_constraint :pipeline_field_definitions,
                         'field_type BETWEEN 0 AND 7',
                         name: 'pipeline_field_definitions_type_range'
    add_check_constraint :pipeline_field_definitions,
                         'position >= 0',
                         name: 'pipeline_field_definitions_position_non_negative'
  end

  def extend_pipeline_item_event_types
    remove_check_constraint :pipeline_item_events, name: 'pipeline_item_events_type_range'
    add_check_constraint :pipeline_item_events,
                         'event_type BETWEEN 0 AND 10',
                         name: 'pipeline_item_events_type_range'
  end
end
