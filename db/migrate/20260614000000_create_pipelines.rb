class CreatePipelines < ActiveRecord::Migration[7.1]
  def change
    create_table :pipelines do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :template_key, null: false, default: 'custom'

      t.timestamps
    end

    add_index :pipelines, [:account_id, :name], unique: true

    create_table :pipeline_stages do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false
      t.string :color, null: false, default: '#6B7280'
      t.boolean :terminal, null: false, default: false
      t.string :outcome_key

      t.timestamps
    end

    add_index :pipeline_stages, [:pipeline_id, :position], unique: true
    add_check_constraint :pipeline_stages, 'position >= 0', name: 'pipeline_stages_position_non_negative'
    add_check_constraint :pipeline_stages,
                         '(terminal AND outcome_key IS NOT NULL) OR (NOT terminal AND outcome_key IS NULL)',
                         name: 'pipeline_stages_terminal_outcome_consistency'
  end
end
