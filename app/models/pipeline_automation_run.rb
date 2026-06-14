# == Schema Information
#
# Table name: pipeline_automation_runs
#
#  id                          :bigint           not null, primary key
#  attempt_count               :integer          default(0), not null
#  error_message               :text
#  metadata                    :jsonb            not null
#  skip_reason                 :string
#  status                      :integer          default("pending"), not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  pipeline_activity_id        :bigint
#  pipeline_automation_rule_id :bigint           not null
#  pipeline_item_id            :bigint           not null
#  stage_transition_id         :bigint           not null
#
class PipelineAutomationRun < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline_automation_rule, inverse_of: :runs
  belongs_to :pipeline_item, inverse_of: :automation_runs
  belongs_to :stage_transition,
             class_name: 'PipelineItemStageTransition',
             inverse_of: :automation_runs
  belongs_to :pipeline_activity, inverse_of: :automation_run, optional: true
  has_many :action_runs,
           class_name: 'PipelineAutomationActionRun',
           inverse_of: :pipeline_automation_run,
           dependent: :destroy

  enum :status, { pending: 0, succeeded: 1, skipped: 2, failed: 3, processing: 4 }, prefix: true

  validates :attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :associations_share_context

  def terminal?
    status_succeeded? || status_skipped?
  end

  private

  def associations_share_context
    return unless automation_context_present?

    errors.add(:base, context_mismatch_error) unless rule_and_transition_match?
    return if activity_matches?

    errors.add(:pipeline_activity, I18n.t('errors.pipeline_automation_run.activity_mismatch'))
  end

  def automation_context_present?
    account.present? &&
      pipeline_automation_rule.present? &&
      pipeline_item.present? &&
      stage_transition.present?
  end

  def rule_and_transition_match?
    pipeline_automation_rule.account_id == account_id &&
      pipeline_automation_rule.pipeline_id == pipeline_item.pipeline_id &&
      stage_transition.account_id == account_id &&
      stage_transition.pipeline_item_id == pipeline_item_id
  end

  def activity_matches?
    pipeline_activity.blank? || pipeline_activity.pipeline_item_id == pipeline_item_id
  end

  def context_mismatch_error
    I18n.t('errors.pipeline_automation_run.context_mismatch')
  end
end
