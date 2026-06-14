# == Schema Information
#
# Table name: pipeline_stages
#
#  id          :bigint           not null, primary key
#  color       :string           default("#6B7280"), not null
#  name        :string           not null
#  outcome_key :string
#  position    :integer          not null
#  terminal    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  account_id  :bigint           not null
#  pipeline_id :bigint           not null
#
class PipelineStage < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline, inverse_of: :stages

  validates :name, presence: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :pipeline_id }
  validates :color, presence: true, format: { with: /\A#[0-9A-F]{6}\z/i }
  validates :outcome_key, presence: true, if: :terminal?
  validates :outcome_key, absence: true, unless: :terminal?
  validate :account_matches_pipeline

  private

  def account_matches_pipeline
    return if account_id.blank? || pipeline.blank? || account_id == pipeline.account_id

    errors.add(:account, I18n.t('errors.pipeline_stage.account_mismatch'))
  end
end
