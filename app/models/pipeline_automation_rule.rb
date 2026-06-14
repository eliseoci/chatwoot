# == Schema Information
#
# Table name: pipeline_automation_rules
#
#  id              :bigint           not null, primary key
#  conditions      :jsonb            not null
#  enabled         :boolean          default(TRUE), not null
#  name            :string           not null
#  trigger_type    :integer          default("pipeline_item_stage_changed"), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :bigint           not null
#  pipeline_id     :bigint           not null
#  target_stage_id :bigint           not null
#
class PipelineAutomationRule < ApplicationRecord
  ACTIVITY_STATES = %w[missing upcoming overdue].freeze
  CONDITION_ATTRIBUTES = %w[
    priority owner_id team_id field_value stage_id contact_id inbox_id channel label activity_state
  ].freeze
  CONDITION_OPERATORS = %w[equals not_equals present not_present].freeze
  CONDITION_REFERENCE_VALIDATORS = {
    'owner_id' => :validate_owner_reference,
    'team_id' => :validate_team_reference,
    'field_value' => :validate_field_reference,
    'stage_id' => :validate_stage_reference,
    'contact_id' => :validate_contact_reference,
    'inbox_id' => :validate_inbox_reference,
    'label' => :validate_label_reference,
    'activity_state' => :validate_activity_state
  }.freeze

  belongs_to :account
  belongs_to :pipeline, inverse_of: :automation_rules
  belongs_to :target_stage, class_name: 'PipelineStage', inverse_of: :automation_rules
  has_many :actions,
           -> { order(:position, :id) },
           class_name: 'PipelineAutomationAction',
           inverse_of: :pipeline_automation_rule,
           dependent: :destroy
  has_many :runs,
           class_name: 'PipelineAutomationRun',
           inverse_of: :pipeline_automation_rule,
           dependent: :destroy

  enum :trigger_type, { pipeline_item_stage_changed: 0 }

  accepts_nested_attributes_for :actions, allow_destroy: true

  before_validation :normalize_configuration

  validates :name, presence: true, length: { maximum: 120 }
  validates :enabled, inclusion: { in: [true, false] }
  validate :associations_share_account_and_pipeline
  validate :conditions_are_supported
  validate :at_least_one_action

  private

  def normalize_configuration
    self.conditions = Array(conditions).map { |condition| condition.to_h.deep_stringify_keys }
    actions.each_with_index do |action, index|
      action.account ||= account
      action.position = index if action.position.blank?
    end
  end

  def associations_share_account_and_pipeline
    return if account.blank? || pipeline.blank? || target_stage.blank?

    errors.add(:pipeline, account_mismatch_error) if pipeline.account_id != account_id
    return if target_stage.account_id == account_id && target_stage.pipeline_id == pipeline_id

    errors.add(:target_stage, I18n.t('errors.pipeline_automation_rule.stage_mismatch'))
  end

  def conditions_are_supported
    conditions.each do |condition|
      validate_condition_shape(condition)
      validate_condition_reference(condition)
    end
  end

  def validate_condition_shape(condition)
    attribute = condition['attribute']
    operator = condition['operator']
    return if CONDITION_ATTRIBUTES.include?(attribute) && CONDITION_OPERATORS.include?(operator)

    errors.add(:conditions, I18n.t('errors.pipeline_automation_rule.invalid_condition'))
  end

  def validate_condition_reference(condition)
    validator = CONDITION_REFERENCE_VALIDATORS[condition['attribute']]
    send(validator, condition) if validator.present?
  end

  def validate_owner_reference(condition)
    validate_account_record(condition, account&.users, :conditions)
  end

  def validate_team_reference(condition)
    validate_account_record(condition, account&.teams, :conditions)
  end

  def validate_stage_reference(condition)
    validate_account_record(condition, pipeline&.stages, :conditions)
  end

  def validate_contact_reference(condition)
    validate_account_record(condition, account&.contacts, :conditions)
  end

  def validate_inbox_reference(condition)
    validate_account_record(condition, account&.inboxes, :conditions)
  end

  def validate_account_record(condition, scope, attribute)
    return if condition['operator'].in?(%w[present not_present])
    return if scope&.exists?(condition['value'])

    errors.add(attribute, account_mismatch_error)
  end

  def validate_field_reference(condition)
    field_key = condition['field_key'].to_s
    return if field_key.present? && pipeline&.field_definitions&.active&.exists?(key: field_key)

    errors.add(:conditions, I18n.t('errors.pipeline_automation_rule.invalid_field'))
  end

  def validate_label_reference(condition)
    return if condition['operator'].in?(%w[present not_present])
    return if account&.labels&.exists?(title: condition['value'].to_s)

    errors.add(:conditions, I18n.t('errors.pipeline_automation_rule.invalid_label'))
  end

  def validate_activity_state(condition)
    return if condition['operator'].in?(%w[present not_present])
    return if ACTIVITY_STATES.include?(condition['value'])

    errors.add(:conditions, I18n.t('errors.pipeline_automation_rule.invalid_activity_state'))
  end

  def at_least_one_action
    return if actions.reject(&:marked_for_destruction?).any?

    errors.add(:actions, I18n.t('errors.pipeline_automation_rule.actions_required'))
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_automation_rule.account_mismatch')
  end
end
