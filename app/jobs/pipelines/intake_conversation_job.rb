class Pipelines::IntakeConversationJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(account_id, conversation_id)
    account = Account.find(account_id)
    conversation = account.conversations.includes(:contact, :inbox).find(conversation_id)
    intake_rule = Pipelines::Intake::RuleMatcher.new(conversation: conversation).perform
    return if intake_rule.blank?

    Pipelines::Items::FindOrCreateForConversationService.new(
      conversation: conversation,
      intake_rule: intake_rule
    ).perform
  end
end
