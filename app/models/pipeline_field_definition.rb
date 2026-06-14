# == Schema Information
#
# Table name: pipeline_field_definitions
#
#  id          :bigint           not null, primary key
#  archived_at :datetime
#  field_type  :integer          not null
#  key         :string           not null
#  label       :string           not null
#  position    :integer          default(0), not null
#  settings    :jsonb            not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  pipeline_id :bigint           not null
#
class PipelineFieldDefinition < ApplicationRecord
  FIELD_TYPES = %w[text number currency date boolean list link user_reference].freeze

  belongs_to :account
  belongs_to :pipeline, inverse_of: :field_definitions

  enum :field_type, FIELD_TYPES.each_with_index.to_h

  scope :active, -> { where(archived_at: nil) }
  scope :ordered, -> { order(:position, :id) }

  before_validation :assign_key, on: :create
  before_validation :normalize_settings

  validates :key, presence: true,
                  format: { with: /\A[a-z][a-z0-9_]*\z/ },
                  uniqueness: { scope: :pipeline_id }
  validates :label, presence: true, length: { maximum: 120 }
  validates :field_type, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :account_matches_pipeline
  validate :settings_match_type
  validate :field_type_is_immutable, on: :update

  def archived?
    archived_at.present?
  end

  private

  def assign_key
    return if key.present? || pipeline.blank? || label.blank?

    base_key = label.parameterize(separator: '_').gsub(/\A[^a-z]+/, '').presence || 'field'
    candidate = base_key
    suffix = 2
    while pipeline.field_definitions.exists?(key: candidate)
      candidate = "#{base_key}_#{suffix}"
      suffix += 1
    end
    self.key = candidate
  end

  def normalize_settings
    self.settings = settings.to_h.deep_stringify_keys
  end

  def account_matches_pipeline
    return if account_id.blank? || pipeline.blank? || account_id == pipeline.account_id

    errors.add(:account, I18n.t('errors.pipeline_field_definition.account_mismatch'))
  end

  def settings_match_type
    validate_list_choices if list?
    validate_currency_code if currency?
  end

  def validate_list_choices
    choices = Array(settings['choices']).map(&:to_s).map(&:strip).compact_blank
    return if choices.present? && choices.uniq.length == choices.length

    errors.add(:settings, I18n.t('errors.pipeline_field_definition.list_choices'))
  end

  def validate_currency_code
    return if settings['currency'].to_s.match?(/\A[A-Z]{3}\z/)

    errors.add(:settings, I18n.t('errors.pipeline_field_definition.currency_code'))
  end

  def field_type_is_immutable
    return unless will_save_change_to_field_type?

    errors.add(:field_type, I18n.t('errors.pipeline_field_definition.type_immutable'))
  end
end
