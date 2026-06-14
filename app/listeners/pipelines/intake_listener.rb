class Pipelines::IntakeListener < BaseListener
  def conversation_created(event)
    conversation, account = extract_conversation_and_account(event)
    return unless account.pipeline_intake_rules.enabled.exists?

    Pipelines::IntakeConversationJob.perform_later(account.id, conversation.id)
  end
end
