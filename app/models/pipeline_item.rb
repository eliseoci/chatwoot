# == Schema Information
#
# Table name: pipeline_items
#
#  id          :bigint           not null, primary key
#  due_date    :date
#  field_values :jsonb            not null
#  priority    :integer
#  title       :string
#  value       :decimal(15, 2)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  contact_id  :bigint           not null
#  owner_id    :bigint
#  pipeline_id :bigint           not null
#  stage_id    :bigint           not null
#  team_id     :bigint
#
class PipelineItem < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline, inverse_of: :items
  belongs_to :stage, class_name: 'PipelineStage', inverse_of: :items
  belongs_to :contact
  belongs_to :owner, class_name: 'User', inverse_of: :owned_pipeline_items, optional: true
  belongs_to :team, optional: true
  has_many :stage_transitions,
           class_name: 'PipelineItemStageTransition',
           inverse_of: :pipeline_item,
           dependent: :destroy
  has_many :conversation_links,
           class_name: 'PipelineItemConversation',
           inverse_of: :pipeline_item,
           dependent: :destroy
  has_many :linked_conversations, through: :conversation_links, source: :conversation
  has_many :events,
           class_name: 'PipelineItemEvent',
           inverse_of: :pipeline_item,
           dependent: :destroy
  has_many :activities,
           class_name: 'PipelineActivity',
           inverse_of: :pipeline_item,
           dependent: :destroy
  has_many :scheduled_activities,
           -> { next_due },
           class_name: 'PipelineActivity',
           inverse_of: :pipeline_item,
           dependent: :destroy

  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3 }, prefix: true

  validates :title, length: { maximum: 255 }, allow_blank: true
  validates :value, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :associations_share_account
  validate :stage_belongs_to_pipeline
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated

  def display_title
    title.presence || contact.name.presence || contact.email.presence || contact.phone_number
  end

  def next_activity
    scheduled_activities.first
  end

  private

  def broadcast_created
    Pipelines::Items::RealtimeBroadcastService.call(
      self,
      event_name: PIPELINE_ITEM_CREATED
    )
  end

  def broadcast_updated
    Pipelines::Items::RealtimeBroadcastService.call(
      self,
      event_name: PIPELINE_ITEM_UPDATED
    )
  end

  def associations_share_account
    return if account_id.blank?

    validate_account(:pipeline, pipeline)
    validate_account(:stage, stage)
    validate_account(:contact, contact)
    validate_account(:team, team)

    return if owner.blank? || account.account_users.exists?(user_id: owner_id)

    errors.add(:owner, I18n.t('errors.pipeline_item.account_mismatch'))
  end

  def validate_account(attribute, record)
    return if record.blank? || record.account_id == account_id

    errors.add(attribute, I18n.t('errors.pipeline_item.account_mismatch'))
  end

  def stage_belongs_to_pipeline
    return if stage.blank? || pipeline.blank? || stage.pipeline_id == pipeline_id

    errors.add(:stage, I18n.t('errors.pipeline_item.stage_mismatch'))
  end
end
