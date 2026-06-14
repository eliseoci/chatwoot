class ExpandPipelineAutomations < ActiveRecord::Migration[7.1]
  def up
    add_attention_state
    create_pipeline_automation_actions
    migrate_existing_actions
    create_pipeline_automation_action_runs
    remove_legacy_action_columns
    expand_automation_run_statuses
  end

  def down
    restore_legacy_action_columns
    collapse_automation_run_statuses
    drop_table :pipeline_automation_action_runs
    drop_table :pipeline_automation_actions
    remove_column :pipeline_items, :attention_note
    remove_column :pipeline_items, :attention_required
  end

  private

  def add_attention_state
    add_column :pipeline_items, :attention_required, :boolean, null: false, default: false
    add_column :pipeline_items, :attention_note, :string
  end

  def create_pipeline_automation_actions
    create_table :pipeline_automation_actions do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_automation_rule,
                   null: false,
                   foreign_key: true,
                   index: { name: 'index_pipeline_actions_on_rule_id' }
      t.integer :position, null: false, default: 0
      t.integer :action_type, null: false
      t.jsonb :config, null: false, default: {}
      t.string :secret

      t.timestamps
    end

    add_pipeline_automation_action_constraints
  end

  def add_pipeline_automation_action_constraints
    add_index :pipeline_automation_actions,
              [:pipeline_automation_rule_id, :position],
              unique: true,
              name: 'index_pipeline_automation_actions_on_rule_and_position'
    add_check_constraint :pipeline_automation_actions,
                         'action_type BETWEEN 0 AND 8',
                         name: 'pipeline_automation_actions_type_range'
    add_check_constraint :pipeline_automation_actions,
                         'position >= 0',
                         name: 'pipeline_automation_actions_position_non_negative'
  end

  def migrate_existing_actions
    execute <<~SQL.squish
      INSERT INTO pipeline_automation_actions
        (account_id, pipeline_automation_rule_id, position, action_type, config, created_at, updated_at)
      SELECT account_id, id, 0, action_type, action_config, created_at, updated_at
      FROM pipeline_automation_rules
    SQL
  end

  def create_pipeline_automation_action_runs
    create_table :pipeline_automation_action_runs do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline_automation_run,
                   null: false,
                   foreign_key: true,
                   index: { name: 'index_pipeline_action_runs_on_run_id' }
      t.references :pipeline_automation_action,
                   null: false,
                   foreign_key: true,
                   index: { name: 'index_pipeline_action_runs_on_action_id' }
      t.integer :status, null: false, default: 0
      t.integer :attempt_count, null: false, default: 0
      t.jsonb :result, null: false, default: {}
      t.text :error_message

      t.timestamps
    end

    add_pipeline_automation_action_run_constraints
  end

  def add_pipeline_automation_action_run_constraints
    add_index :pipeline_automation_action_runs,
              [:pipeline_automation_run_id, :pipeline_automation_action_id],
              unique: true,
              name: 'index_pipeline_action_runs_on_run_and_action'
    add_check_constraint :pipeline_automation_action_runs,
                         'status BETWEEN 0 AND 2',
                         name: 'pipeline_automation_action_runs_status_range'
    add_check_constraint :pipeline_automation_action_runs,
                         'attempt_count >= 0',
                         name: 'pipeline_automation_action_runs_attempt_count_non_negative'
  end

  def remove_legacy_action_columns
    remove_check_constraint :pipeline_automation_rules,
                            name: 'pipeline_automation_rules_action_type'
    remove_column :pipeline_automation_rules, :action_type
    remove_column :pipeline_automation_rules, :action_config
  end

  def expand_automation_run_statuses
    remove_check_constraint :pipeline_automation_runs,
                            name: 'pipeline_automation_runs_status_range'
    add_check_constraint :pipeline_automation_runs,
                         'status BETWEEN 0 AND 4',
                         name: 'pipeline_automation_runs_status_range'
  end

  def restore_legacy_action_columns
    add_column :pipeline_automation_rules, :action_type, :integer, null: false, default: 0
    add_column :pipeline_automation_rules, :action_config, :jsonb, null: false, default: {}

    execute <<~SQL.squish
      UPDATE pipeline_automation_rules AS rules
      SET action_type = actions.action_type,
          action_config = actions.config
      FROM pipeline_automation_actions AS actions
      WHERE actions.pipeline_automation_rule_id = rules.id
        AND actions.position = 0
    SQL

    add_check_constraint :pipeline_automation_rules,
                         'action_type = 0',
                         name: 'pipeline_automation_rules_action_type'
  end

  def collapse_automation_run_statuses
    execute 'UPDATE pipeline_automation_runs SET status = 3 WHERE status = 4'
    remove_check_constraint :pipeline_automation_runs,
                            name: 'pipeline_automation_runs_status_range'
    add_check_constraint :pipeline_automation_runs,
                         'status BETWEEN 0 AND 3',
                         name: 'pipeline_automation_runs_status_range'
  end
end
