class AddOutcomeReasonToPipelineItemStageTransitions < ActiveRecord::Migration[7.1]
  def change
    add_column :pipeline_item_stage_transitions, :outcome_reason, :string
  end
end
