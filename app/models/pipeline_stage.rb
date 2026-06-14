# == Schema Information
#
# Table name: pipeline_stages
#
#  id          :bigint           not null, primary key
#  color       :string           default("#6B7280"), not null
#  name        :string           not null
#  outcome_key :string
#  position    :integer          not null
#  required_field_keys :string           default([]), not null, is an Array
#  terminal    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  pipeline_id :bigint           not null
#
class PipelineStage < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline, inverse_of: :stages
  has_many :items, class_name: 'PipelineItem', inverse_of: :stage, dependent: :restrict_with_error
  has_many :intake_rules,
           class_name: 'PipelineIntakeRule',
           foreign_key: :initial_stage_id,
           inverse_of: :initial_stage,
           dependent: :restrict_with_error
  has_many :outgoing_item_transitions,
           class_name: 'PipelineItemStageTransition',
           foreign_key: :from_stage_id,
           inverse_of: :from_stage,
           dependent: :restrict_with_error
  has_many :incoming_item_transitions,
           class_name: 'PipelineItemStageTransition',
           foreign_key: :to_stage_id,
           inverse_of: :to_stage,
           dependent: :restrict_with_error

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :pipeline_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-F]{6}\z/i }
  validates :outcome_key, presence: true, if: :terminal?
  validates :outcome_key, absence: true, unless: :terminal?
  validate :account_matches_pipeline
  validate :required_fields_belong_to_pipeline

  before_validation :normalize_required_field_keys

  private

  def account_matches_pipeline
    return if account_id.blank? || pipeline.blank? || account_id == pipeline.account_id

    errors.add(:account, I18n.t('errors.pipeline_stage.account_mismatch'))
  end

  def normalize_required_field_keys
    self.required_field_keys = Array(required_field_keys).map(&:to_s).map(&:strip).compact_blank.uniq
  end

  def required_fields_belong_to_pipeline
    return if pipeline.blank? || required_field_keys.blank?

    available_keys = pipeline.field_definitions.active.where(key: required_field_keys).pluck(:key)
    return if available_keys.sort == required_field_keys.sort

    errors.add(:required_field_keys, I18n.t('errors.pipeline_stage.invalid_required_fields'))
  end
end
