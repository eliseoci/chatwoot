class CreatePipelineAutomations < ActiveRecord::Migration[7.1]
  def change
    create_pipeline_automation_rules
    create_pipeline_automation_runs
  end

  private

  def create_pipeline_automation_rules
    create_table :pipeline_automation_rules do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :target_stage, null: false, foreign_key: { to_table: :pipeline_stages }
      t.string :name, null: false
      t.boolean :enabled, null: false, default: true
      t.integer :trigger_type, null: false, default: 0
      t.jsonb :conditions, null: false, default: []
      t.integer :action_type, null: false, default: 0
      t.jsonb :action_config, null: false, default: {}

      t.timestamps
    end

    add_pipeline_automation_rule_indexes
    add_pipeline_automation_rule_constraints
  end

  def add_pipeline_automation_rule_indexes
    add_index :pipeline_automation_rules, [:pipeline_id, :target_stage_id],
              name: 'index_pipeline_automation_rules_on_pipeline_and_stage'
  end

  def add_pipeline_automation_rule_constraints
    add_check_constraint :pipeline_automation_rules,
                         'trigger_type = 0',
                         name: 'pipeline_automation_rules_trigger_type'
    add_check_constraint :pipeline_automation_rules,
                         'action_type = 0',
                         name: 'pipeline_automation_rules_action_type'
  end

  def create_pipeline_automation_runs
    create_table :pipeline_automation_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_automation_rule, null: false, foreign_key: true
      t.references :pipeline_item, null: false, foreign_key: true
      t.references :stage_transition,
                   null: false,
                   foreign_key: { to_table: :pipeline_item_stage_transitions }
      t.references :pipeline_activity, foreign_key: true
      t.integer :status, null: false, default: 0
      t.integer :attempt_count, null: false, default: 0
      t.string :skip_reason
      t.text :error_message
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_pipeline_automation_run_indexes
    add_pipeline_automation_run_constraints
  end

  def add_pipeline_automation_run_indexes
    add_index :pipeline_automation_runs,
              [:pipeline_automation_rule_id, :stage_transition_id],
              unique: true,
              name: 'index_pipeline_automation_runs_on_rule_and_transition'
  end

  def add_pipeline_automation_run_constraints
    add_check_constraint :pipeline_automation_runs,
                         'status BETWEEN 0 AND 3',
                         name: 'pipeline_automation_runs_status_range'
    add_check_constraint :pipeline_automation_runs,
                         'attempt_count >= 0',
                         name: 'pipeline_automation_runs_attempt_count_non_negative'
  end
end
