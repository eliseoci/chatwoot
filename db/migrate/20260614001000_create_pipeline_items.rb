class CreatePipelineItems < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_items_table
    add_pipeline_item_constraints
  end

  private

  def create_pipeline_items_table
    create_table :pipeline_items do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :stage, null: false, foreign_key: { to_table: :pipeline_stages }
      t.references :contact, null: false, foreign_key: { on_delete: :cascade }
      t.references :owner, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :team, foreign_key: { on_delete: :nullify }
      t.string :title
      t.integer :priority
      t.decimal :value, precision: 15, scale: 2
      t.date :due_date

      t.timestamps
    end

    add_index :pipeline_items, [:pipeline_id, :stage_id]
  end

  def add_pipeline_item_constraints
    add_check_constraint :pipeline_items,
                         'priority IS NULL OR priority BETWEEN 0 AND 3',
                         name: 'pipeline_items_priority_range'
    add_check_constraint :pipeline_items,
                         'value IS NULL OR value >= 0',
                         name: 'pipeline_items_value_non_negative'
  end
end
