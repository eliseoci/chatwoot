# == Schema Information
#
# Table name: pipeline_activities
#
#  id               :bigint           not null, primary key
#  activity_type    :integer          default("task"), not null
#  canceled_at      :datetime
#  completed_at     :datetime
#  due_at           :datetime         not null
#  notes            :text
#  status           :integer          default("scheduled"), not null
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  account_id       :bigint           not null
#  assignee_id      :bigint
#  created_by_id    :bigint
#  pipeline_item_id :bigint           not null
#
class PipelineActivity < ApplicationRecord
  belongs_to :account
  belongs_to :pipeline_item, inverse_of: :activities
  belongs_to :assignee,
             class_name: 'User',
             inverse_of: :assigned_pipeline_activities,
             optional: true
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :events,
           class_name: 'PipelineItemEvent',
           inverse_of: :pipeline_activity,
           dependent: :nullify
  has_one :automation_run,
          class_name: 'PipelineAutomationRun',
          inverse_of: :pipeline_activity,
          dependent: :nullify

  enum :activity_type, { task: 0, call: 1, message: 2, meeting: 3, custom: 4 }, prefix: true
  enum :status, { scheduled: 0, completed: 1, canceled: 2 }, prefix: true

  validates :title, presence: true, length: { maximum: 255 }
  validates :due_at, presence: true
  validate :associations_share_account
  validate :terminal_timestamps_match_status
  after_commit :broadcast_pipeline_item_update, on: [:create, :update, :destroy]

  scope :next_due, -> { where(status: :scheduled).order(:due_at, :id) }
  scope :operational_order, lambda {
    order(Arel.sql('CASE WHEN status = 0 THEN 0 ELSE 1 END'), :due_at, :id)
  }

  def overdue?(at: Time.current)
    status_scheduled? && due_at < at
  end

  private

  def broadcast_pipeline_item_update
    Pipelines::Items::RealtimeBroadcastService.call(
      pipeline_item,
      event_name: PIPELINE_ITEM_UPDATED
    )
  end

  def associations_share_account
    return if account_id.blank?

    errors.add(:pipeline_item, account_mismatch_error) if pipeline_item.present? && pipeline_item.account_id != account_id

    validate_account_user(:assignee, assignee_id)
    validate_account_user(:created_by, created_by_id)
  end

  def validate_account_user(attribute, user_id)
    return if user_id.blank? || account.account_users.exists?(user_id: user_id)

    errors.add(attribute, account_mismatch_error)
  end

  def terminal_timestamps_match_status
    errors.add(:completed_at, :blank) if status_completed? && completed_at.blank?
    errors.add(:canceled_at, :blank) if status_canceled? && canceled_at.blank?
  end

  def account_mismatch_error
    I18n.t('errors.pipeline_activity.account_mismatch')
  end
end
