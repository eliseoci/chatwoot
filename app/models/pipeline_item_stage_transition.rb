# == Schema Information
#
# Table name: pipeline_item_stage_transitions
#
#  id               :bigint           not null, primary key
#  source           :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  actor_id         :bigint           not null
#  from_stage_id    :bigint           not null
#  pipeline_item_id :bigint           not null
#  to_stage_id      :bigint           not null
#
class PipelineItemStageTransition < ApplicationRecord
  SOURCES = %w[api board_drag board_command conversation_sidebar].freeze

  belongs_to :account
  belongs_to :pipeline_item, inverse_of: :stage_transitions
  belongs_to :from_stage, class_name: 'PipelineStage', inverse_of: :outgoing_item_transitions
  belongs_to :to_stage, class_name: 'PipelineStage', inverse_of: :incoming_item_transitions
  belongs_to :actor, class_name: 'User', inverse_of: :pipeline_item_stage_transitions
  has_many :automation_runs,
           class_name: 'PipelineAutomationRun',
           foreign_key: :stage_transition_id,
           inverse_of: :stage_transition,
           dependent: :destroy

  validates :source, presence: true, inclusion: { in: SOURCES }
  validate :associations_match_pipeline_item

  private

  def associations_match_pipeline_item
    return if account.blank? || pipeline_item.blank?

    errors.add(:pipeline_item, mismatch_message) if pipeline_item.account_id != account_id
    validate_stage(:from_stage, from_stage)
    validate_stage(:to_stage, to_stage)
    errors.add(:actor, mismatch_message) unless account.account_users.exists?(user_id: actor_id)
  end

  def validate_stage(attribute, stage)
    return if stage.blank?
    return if stage.account_id == account_id && stage.pipeline_id == pipeline_item.pipeline_id

    errors.add(attribute, mismatch_message)
  end

  def mismatch_message
    I18n.t('errors.pipeline_item_stage_transition.mismatch')
  end
end
