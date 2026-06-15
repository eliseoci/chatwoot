# == Schema Information
#
# Table name: pipeline_access_grants
#
#  id           :bigint           not null, primary key
#  access_level :integer          default("viewer"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#  pipeline_id  :bigint           not null
#  team_id      :bigint
#  user_id      :bigint
#
class PipelineAccessGrant < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline, inverse_of: :access_grants
  belongs_to :user, optional: true
  belongs_to :team, optional: true

  enum :access_level, { viewer: 0, operator: 1 }, prefix: true

  validates :user_id, uniqueness: { scope: :pipeline_id }, allow_nil: true
  validates :team_id, uniqueness: { scope: :pipeline_id }, allow_nil: true
  validate :exactly_one_grantee
  validate :associations_share_account

  private

  def exactly_one_grantee
    return if user.present? ^ team.present?

    errors.add(:base, I18n.t('errors.pipeline_access_grant.one_grantee'))
  end

  def associations_share_account
    return if account.blank? || pipeline.blank?

    validate_pipeline_account
    validate_user_account
    validate_team_account
  end

  def validate_pipeline_account
    errors.add(:pipeline, account_mismatch_error) if pipeline.account_id != account_id
  end

  def validate_user_account
    return if user.blank? || account.account_users.exists?(user_id: user_id)

    errors.add(:user, account_mismatch_error)
  end

  def validate_team_account
    return if team.blank? || team.account_id == account_id

    errors.add(:team, account_mismatch_error)
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_access_grant.account_mismatch')
  end
end
