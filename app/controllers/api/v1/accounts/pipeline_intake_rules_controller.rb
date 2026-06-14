class Api::V1::Accounts::PipelineIntakeRulesController < Api::V1::Accounts::BaseController
  before_action :fetch_rule, only: [:update, :destroy]
  before_action :check_authorization

  def index
    @rules = Current.account.pipeline_intake_rules
                    .includes(:pipeline, :initial_stage, :inbox)
                    .in_priority_order
  end

  def create
    @rule = Current.account.pipeline_intake_rules.new(rule_attributes)
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
    @rule = Current.account.pipeline_intake_rules.find(params[:id])
  end

  def assign_account_scoped_associations
    @rule.pipeline = Current.account.pipelines.find(rule_params[:pipeline_id])
    @rule.initial_stage = @rule.pipeline.stages.find(rule_params[:initial_stage_id])
    @rule.inbox = fetch_inbox
  end

  def fetch_inbox
    return if rule_params[:inbox_id].blank?

    Current.account.inboxes.find(rule_params[:inbox_id])
  end

  def rule_attributes
    rule_params.permit(:channel_type, :enabled, :position)
  end

  def rule_params
    params.require(:pipeline_intake_rule).permit(
      :pipeline_id,
      :initial_stage_id,
      :inbox_id,
      :channel_type,
      :enabled,
      :position
    )
  end
end
