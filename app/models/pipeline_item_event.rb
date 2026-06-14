# == Schema Information
#
# Table name: pipeline_item_events
#
#  id               :bigint           not null, primary key
#  event_type       :integer          not null
#  metadata         :jsonb            not null
#  source           :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  actor_id         :bigint
#  conversation_id  :bigint
#  pipeline_activity_id :bigint
#  pipeline_item_id :bigint           not null
#
class PipelineItemEvent < ApplicationRecord
  SOURCES = PipelineItemConversation::SOURCES

  belongs_to :account
  belongs_to :pipeline_item, inverse_of: :events
  belongs_to :conversation, optional: true
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :pipeline_activity, inverse_of: :events, optional: true

  enum :event_type, {
    conversation_linked: 0,
    conversation_unlinked: 1,
    automatic_item_created: 2,
    conversation_deduplicated: 3,
    parallel_item_created: 4,
    activity_created: 5,
    activity_updated: 6,
    activity_completed: 7,
    activity_canceled: 8
  }

  validates :source, presence: true, inclusion: { in: SOURCES }
  validate :associations_share_account
  validate :pipeline_activity_matches_item

  private

  def associations_share_account
    return if account_id.blank?

    validate_account(:pipeline_item, pipeline_item)
    validate_account(:conversation, conversation)
    validate_account(:pipeline_activity, pipeline_activity)
    return if actor.blank? || account.account_users.exists?(user_id: actor_id)

    errors.add(:actor, account_mismatch_error)
  end

  def validate_account(attribute, record)
    return if record.blank? || record.account_id == account_id

    errors.add(attribute, account_mismatch_error)
  end

  def pipeline_activity_matches_item
    return if pipeline_activity.blank? || pipeline_item.blank?
    return if pipeline_activity.pipeline_item_id == pipeline_item_id

    errors.add(:pipeline_activity, I18n.t('errors.pipeline_item_event.activity_mismatch'))
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_item_event.account_mismatch')
  end
end
