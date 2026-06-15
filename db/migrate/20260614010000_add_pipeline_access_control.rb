class AddPipelineAccessControl < ActiveRecord::Migration[7.1]
  def change
    add_column :pipelines, :access_mode, :integer, null: false, default: 0
    add_check_constraint :pipelines,
                         'access_mode BETWEEN 0 AND 1',
                         name: 'pipelines_access_mode_range'

    create_table :pipeline_access_grants do |t|
      t.references :account, null: false, foreign_key: true
      t.references :pipeline, null: false, foreign_key: true
      t.references :user, foreign_key: { on_delete: :cascade }
      t.references :team, foreign_key: { on_delete: :cascade }
      t.integer :access_level, null: false, default: 0

      t.timestamps
    end

    add_access_grant_indexes
    add_access_grant_constraints
  end

  private

  def add_access_grant_indexes
    add_index :pipeline_access_grants,
              [:pipeline_id, :user_id],
              unique: true,
              where: 'user_id IS NOT NULL',
              name: 'index_pipeline_access_grants_on_pipeline_and_user'
    add_index :pipeline_access_grants,
              [:pipeline_id, :team_id],
              unique: true,
              where: 'team_id IS NOT NULL',
              name: 'index_pipeline_access_grants_on_pipeline_and_team'
  end

  def add_access_grant_constraints
    add_check_constraint :pipeline_access_grants,
                         'access_level BETWEEN 0 AND 1',
                         name: 'pipeline_access_grants_level_range'
    add_check_constraint :pipeline_access_grants,
                         '(user_id IS NOT NULL) <> (team_id IS NOT NULL)',
                         name: 'pipeline_access_grants_one_grantee'
  end
end
