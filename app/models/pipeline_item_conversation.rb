# == Schema Information
#
# Table name: pipeline_item_conversations
#
#  id               :bigint           not null, primary key
#  source           :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  conversation_id  :bigint           not null
#  linked_by_id     :bigint
#  pipeline_item_id :bigint           not null
#
class PipelineItemConversation < ApplicationRecord
  SOURCES = %w[api item_detail conversation_sidebar automation conversation_created manual_override].freeze

  belongs_to :account
  belongs_to :pipeline_item, inverse_of: :conversation_links
  belongs_to :conversation
  belongs_to :linked_by, class_name: 'User', optional: true

  validates :conversation_id, uniqueness: { scope: :pipeline_item_id }
  validates :source, presence: true, inclusion: { in: SOURCES }
  validate :associations_share_account
  validate :conversation_matches_contact
  after_commit :broadcast_pipeline_item_update, on: [:create, :destroy]

  private

  def broadcast_pipeline_item_update
    Pipelines::Items::RealtimeBroadcastService.call(
      pipeline_item,
      event_name: PIPELINE_ITEM_UPDATED
    )
  end

  def associations_share_account
    return if account_id.blank?

    validate_account(:pipeline_item, pipeline_item)
    validate_account(:conversation, conversation)
    return if linked_by.blank? || account.account_users.exists?(user_id: linked_by_id)

    errors.add(:linked_by, account_mismatch_error)
  end

  def validate_account(attribute, record)
    return if record.blank? || record.account_id == account_id

    errors.add(attribute, account_mismatch_error)
  end

  def conversation_matches_contact
    return if pipeline_item.blank? || conversation.blank? || pipeline_item.contact_id == conversation.contact_id

    errors.add(:conversation, I18n.t('errors.pipeline_item_conversation.contact_mismatch'))
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_item_conversation.account_mismatch')
  end
end
