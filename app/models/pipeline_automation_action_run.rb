# == Schema Information
#
# Table name: pipeline_automation_action_runs
#
#  id                            :bigint           not null, primary key
#  attempt_count                 :integer          default(0), not null
#  error_message                 :text
#  result                        :jsonb            not null
#  status                        :integer          default("pending"), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  account_id                    :bigint           not null
#  pipeline_automation_action_id :bigint           not null
#  pipeline_automation_run_id    :bigint           not null
#
class PipelineAutomationActionRun < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline_automation_run, inverse_of: :action_runs
  belongs_to :pipeline_automation_action, inverse_of: :action_runs

  enum :status, { pending: 0, succeeded: 1, failed: 2 }, prefix: true

  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :associations_share_context

  private

  def associations_share_context
    return if account.blank? || pipeline_automation_run.blank? || pipeline_automation_action.blank?
    return if account_context_matches? && rule_context_matches?

    errors.add(:base, I18n.t('errors.pipeline_automation_action_run.context_mismatch'))
  end

  def account_context_matches?
    account_id == pipeline_automation_run.account_id &&
      account_id == pipeline_automation_action.account_id
  end

  def rule_context_matches?
    pipeline_automation_run.pipeline_automation_rule_id ==
      pipeline_automation_action.pipeline_automation_rule_id
  end
end
