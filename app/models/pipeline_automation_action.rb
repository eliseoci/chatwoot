# == Schema Information
#
# Table name: pipeline_automation_actions
#
#  id                          :bigint           not null, primary key
#  action_type                 :integer          not null
#  config                      :jsonb            not null
#  position                    :integer          default(0), not null
#  secret                      :string
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  account_id                  :bigint           not null
#  pipeline_automation_rule_id :bigint           not null
#
class PipelineAutomationAction < ApplicationRecord
  ACTIVITY_TYPES = PipelineActivity.activity_types.keys.freeze
  ATTENTION_STATES = %w[required cleared].freeze
  DUE_MODES = %w[relative fixed].freeze

  belongs_to :account
  belongs_to :pipeline_automation_rule, inverse_of: :actions
  has_many :action_runs,
           class_name: 'PipelineAutomationActionRun',
           inverse_of: :pipeline_automation_action,
           dependent: :destroy

  enum :action_type, {
    create_activity: 0,
    assign_owner: 1,
    assign_team: 2,
    update_field: 3,
    add_labels: 4,
    remove_labels: 5,
    send_internal_notification: 6,
    send_webhook: 7,
    update_attention: 8
  }

  encrypts :secret if Chatwoot.encryption_configured?

  before_validation :normalize_config

  validates :position,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 },
            uniqueness: { scope: :pipeline_automation_rule_id }
  validate :account_matches_rule
  validate :configuration_is_valid

  private

  def normalize_config
    self.config = config.to_h.deep_stringify_keys
  end

  def account_matches_rule
    return if account.blank? || pipeline_automation_rule.blank?
    return if account_id == pipeline_automation_rule.account_id

    errors.add(:account, account_mismatch_error)
  end

  def configuration_is_valid
    send("validate_#{action_type}") if action_type.present?
  end

  def validate_create_activity
    validate_activity_title
    validate_activity_type
    validate_account_user(config['assignee_id'])
    validate_due_configuration
  end

  def validate_assign_owner
    validate_account_user(config['owner_id'])
  end

  def validate_assign_team
    return if config['team_id'].blank? || account&.teams&.exists?(config['team_id'])

    errors.add(:config, account_mismatch_error)
  end

  def validate_update_field
    field_key = config['field_key'].to_s
    return if field_key.present? && pipeline&.field_definitions&.active&.exists?(key: field_key)

    errors.add(:config, I18n.t('errors.pipeline_automation_action.invalid_field'))
  end

  def validate_add_labels
    validate_labels
  end

  def validate_remove_labels
    validate_labels
  end

  def validate_send_internal_notification
    if config['recipient_id'].blank?
      errors.add(:config, account_mismatch_error)
      return
    end

    validate_account_user(config['recipient_id'])
    return if config['message'].to_s.strip.present?

    errors.add(:config, I18n.t('errors.pipeline_automation_action.notification_message'))
  end

  def validate_send_webhook
    errors.add(:secret, :blank) if secret.blank?
    return if valid_webhook_url?

    errors.add(:config, I18n.t('errors.pipeline_automation_action.webhook_url'))
  end

  def validate_update_attention
    return if ATTENTION_STATES.include?(config['state'])

    errors.add(:config, I18n.t('errors.pipeline_automation_action.attention_state'))
  end

  def validate_activity_title
    return if config['title'].to_s.strip.present?

    errors.add(:config, I18n.t('errors.pipeline_automation_action.activity_title'))
  end

  def validate_activity_type
    return if ACTIVITY_TYPES.include?(config['activity_type'])

    errors.add(:config, I18n.t('errors.pipeline_automation_action.activity_type'))
  end

  def validate_due_configuration
    due_mode = config['due_mode']
    unless DUE_MODES.include?(due_mode)
      errors.add(:config, I18n.t('errors.pipeline_automation_action.due_mode'))
      return
    end

    due_mode == 'relative' ? validate_relative_due_time : validate_fixed_due_time
  end

  def validate_relative_due_time
    minutes = Integer(config['due_in_minutes'], exception: false)
    return if minutes.present? && minutes.positive?

    errors.add(:config, I18n.t('errors.pipeline_automation_action.relative_due_time'))
  end

  def validate_fixed_due_time
    return if Time.zone.parse(config['due_at'].to_s).present?

    errors.add(:config, I18n.t('errors.pipeline_automation_action.fixed_due_time'))
  rescue ArgumentError
    errors.add(:config, I18n.t('errors.pipeline_automation_action.fixed_due_time'))
  end

  def validate_account_user(user_id)
    return if user_id.blank? || account&.users&.exists?(user_id)

    errors.add(:config, account_mismatch_error)
  end

  def validate_labels
    labels = normalized_labels
    return if labels.present? && account_label_count(labels) == labels.length

    errors.add(:config, I18n.t('errors.pipeline_automation_action.invalid_labels'))
  end

  def normalized_labels
    Array(config['labels']).map(&:to_s).map(&:strip).compact_blank.uniq
  end

  def account_label_count(labels)
    account&.labels&.where(title: labels)&.count.to_i
  end

  def valid_webhook_url?
    uri = URI.parse(config['url'].to_s)
    uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    false
  end

  def pipeline
    pipeline_automation_rule&.pipeline
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_automation_action.account_mismatch')
  end
end
