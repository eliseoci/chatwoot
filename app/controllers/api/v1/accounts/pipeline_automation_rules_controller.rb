class Api::V1::Accounts::PipelineAutomationRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_rule, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @rules = Current.account.pipeline_automation_rules
                    .includes(:pipeline, :target_stage, :actions, runs: :action_runs)
                    .order(:created_at, :id)
  end

  def create
    @rule = Current.account.pipeline_automation_rules.new(rule_attributes)
    assign_account_scoped_associations
    @rule.save!
  end

  def update
    @rule.assign_attributes(rule_attributes)
    assign_account_scoped_associations
    @rule.save!
  end

  def destroy
    @rule.destroy!
    head :no_content
  end

  private

  def fetch_rule
    @rule = Current.account.pipeline_automation_rules.find(params[:id])
  end

  def assign_account_scoped_associations
    @rule.pipeline = Current.account.pipelines.find(rule_params[:pipeline_id]) if rule_params[:pipeline_id].present?
    return if rule_params[:target_stage_id].blank?

    @rule.target_stage = @rule.pipeline.stages.find(rule_params[:target_stage_id])
  end

  def rule_attributes
    attributes = rule_params.permit(
      :name,
      :enabled,
      :trigger_type,
      conditions: [:attribute, :operator, :value, :field_key],
      actions: [
        :id,
        :position,
        :action_type,
        :secret,
        :_destroy,
        { config: {} }
      ]
    ).to_h
    actions = attributes.delete('actions')
    attributes['actions_attributes'] = actions if actions.present?
    attributes
  end

  def rule_params
    params.require(:pipeline_automation_rule)
  end
end
