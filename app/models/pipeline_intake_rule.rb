# == Schema Information
#
# Table name: pipeline_intake_rules
#
#  id               :bigint           not null, primary key
#  channel_type     :string
#  enabled          :boolean          default(TRUE), not null
#  position         :integer          default(0), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  inbox_id         :bigint
#  initial_stage_id :bigint           not null
#  pipeline_id      :bigint           not null
#
class PipelineIntakeRule < ApplicationRecord
  CHANNEL_TYPES = %w[
    Channel::Api
    Channel::Email
    Channel::FacebookPage
    Channel::Instagram
    Channel::Line
    Channel::Sms
    Channel::Telegram
    Channel::Tiktok
    Channel::TwilioSms
    Channel::WebWidget
    Channel::Whatsapp
  ].freeze

  belongs_to :account
  belongs_to :pipeline, inverse_of: :intake_rules
  belongs_to :initial_stage, class_name: 'PipelineStage', inverse_of: :intake_rules
  belongs_to :inbox, optional: true

  scope :enabled, -> { where(enabled: true) }
  scope :in_priority_order, -> { order(:position, :id) }

  validates :channel_type, inclusion: { in: CHANNEL_TYPES }, allow_blank: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :associations_share_account
  validate :initial_stage_belongs_to_pipeline

  def matches?(conversation)
    return false if inbox_id.present? && inbox_id != conversation.inbox_id
    return false if channel_type.present? && channel_type != conversation.inbox.channel_type

    true
  end

  private

  def associations_share_account
    return if account_id.blank?

    validate_account(:pipeline, pipeline)
    validate_account(:initial_stage, initial_stage)
    validate_account(:inbox, inbox)
  end

  def validate_account(attribute, record)
    return if record.blank? || record.account_id == account_id

    errors.add(attribute, I18n.t('errors.pipeline_intake_rule.account_mismatch'))
  end

  def initial_stage_belongs_to_pipeline
    return if initial_stage.blank? || pipeline.blank? || initial_stage.pipeline_id == pipeline_id

    errors.add(:initial_stage, I18n.t('errors.pipeline_intake_rule.stage_mismatch'))
  end
end
