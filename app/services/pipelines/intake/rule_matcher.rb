class Pipelines::Intake::RuleMatcher
  def initialize(conversation:)
    @conversation = conversation
  end

  def perform
    conversation.account.pipeline_intake_rules
                .enabled
                .in_priority_order
                .includes(:inbox, :pipeline, :initial_stage)
                .detect { |rule| rule.matches?(conversation) }
  end

  private

  attr_reader :conversation
end
