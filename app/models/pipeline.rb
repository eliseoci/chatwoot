# == Schema Information
#
# Table name: pipelines
#
#  id           :bigint           not null, primary key
#  description  :text
#  name         :string           not null
#  template_key :string           default("custom"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  account_id   :bigint           not null
#
class Pipeline < ApplicationRecord
  TEMPLATE_KEYS = %w[sales support recruitment onboarding collections real_estate custom].freeze

  belongs_to :account
  has_many :stages, -> { order(:position) }, class_name: 'PipelineStage', dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :account_id }
  validates :template_key, presence: true, inclusion: { in: TEMPLATE_KEYS }
end
