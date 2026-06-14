class Pipelines::Automations::RuleEvaluator
  Result = Struct.new(:matched?, :reason, keyword_init: true)
  CONDITION_VALUE_METHODS = {
    'priority' => :priority_value,
    'owner_id' => :owner_value,
    'team_id' => :team_value,
    'field_value' => :field_value,
    'stage_id' => :stage_value,
    'contact_id' => :contact_value,
    'inbox_id' => :inbox_values,
    'channel' => :channel_values,
    'label' => :label_values,
    'activity_state' => :activity_state_value
  }.freeze

  def initialize(rule:, stage_transition:)
    @rule = rule
    @stage_transition = stage_transition
  end

  def perform
    return Result.new(matched?: false, reason: 'disabled') unless rule.enabled?
    return Result.new(matched?: false, reason: 'target_stage_mismatch') unless target_stage_matches?
    return Result.new(matched?: false, reason: 'conditions_not_met') unless conditions_match?

    Result.new(matched?: true)
  end

  private

  attr_reader :rule, :stage_transition

  delegate :pipeline_item, to: :stage_transition

  def target_stage_matches?
    rule.pipeline_id == pipeline_item.pipeline_id && rule.target_stage_id == stage_transition.to_stage_id
  end

  def conditions_match?
    rule.conditions.all? { |condition| condition_matches?(condition) }
  end

  def condition_matches?(condition)
    value = condition_value(condition)
    case condition['operator']
    when 'equals'
      includes_or_equals?(value, condition['value'])
    when 'not_equals'
      !includes_or_equals?(value, condition['value'])
    when 'present'
      value.present?
    when 'not_present'
      value.blank?
    end
  end

  def condition_value(condition)
    value_method = CONDITION_VALUE_METHODS[condition['attribute']]
    send(value_method, condition) if value_method.present?
  end

  def priority_value(_condition)
    pipeline_item.priority
  end

  def owner_value(_condition)
    pipeline_item.owner_id
  end

  def team_value(_condition)
    pipeline_item.team_id
  end

  def field_value(condition)
    pipeline_item.field_values[condition['field_key']]
  end

  def stage_value(_condition)
    stage_transition.to_stage_id
  end

  def contact_value(_condition)
    pipeline_item.contact_id
  end

  def inbox_values(_condition)
    linked_conversations.pluck(:inbox_id)
  end

  def channel_values(_condition)
    linked_conversations.includes(:inbox).filter_map do |conversation|
      conversation.inbox&.channel_type
    end.uniq
  end

  def label_values(_condition)
    linked_conversations.flat_map(&:cached_label_list_array).uniq
  end

  def activity_state_value(_condition)
    activity_state
  end

  def linked_conversations
    pipeline_item.linked_conversations
  end

  def activity_state
    activity = pipeline_item.next_activity
    return 'missing' if activity.blank?
    return 'overdue' if activity.overdue?

    'upcoming'
  end

  def includes_or_equals?(actual, expected)
    return actual.any? { |value| equivalent?(value, expected) } if actual.is_a?(Array)

    equivalent?(actual, expected)
  end

  def equivalent?(actual, expected)
    actual == expected || actual.to_s == expected.to_s
  end
end
