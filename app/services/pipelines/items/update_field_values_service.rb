require 'uri'

class Pipelines::Items::UpdateFieldValuesService
  INVALID_VALUE = Object.new.freeze

  def initialize(pipeline_item:, values:, actor:, source:)
    @pipeline_item = pipeline_item
    @values = values.to_h.stringify_keys
    @actor = actor
    @source = source
  end

  def perform
    PipelineItem.transaction do
      pipeline_item.lock!
      definitions = active_definitions.index_by(&:key)
      reject_unknown_fields!(definitions)

      normalized_values = normalize_values(definitions)
      previous_values = pipeline_item.field_values.deep_dup
      next pipeline_item if normalized_values.empty? && values.empty?

      pipeline_item.update!(field_values: previous_values.merge(normalized_values).compact)
      record_event(previous_values, pipeline_item.field_values)
      pipeline_item
    end
  end

  private

  attr_reader :pipeline_item, :values, :actor, :source

  def active_definitions
    pipeline_item.pipeline.field_definitions.active.where(key: values.keys)
  end

  def reject_unknown_fields!(definitions)
    unknown_keys = values.keys - definitions.keys
    return if unknown_keys.empty?

    pipeline_item.errors.add(
      :field_values,
      I18n.t('errors.pipeline_item.unknown_fields', keys: unknown_keys.join(', '))
    )
    raise ActiveRecord::RecordInvalid, pipeline_item
  end

  def normalize_values(definitions)
    values.to_h do |key, value|
      definition = definitions.fetch(key)
      normalized_value = normalize_value_with_errors(definition, value)
      add_invalid_value_error(definition) if normalized_value.equal?(INVALID_VALUE)
      [key, normalized_value]
    end
  end

  def normalize_value_with_errors(definition, value)
    normalize_value(definition, value)
  rescue ActiveRecord::RecordNotFound, ArgumentError, URI::InvalidURIError
    INVALID_VALUE
  end

  def normalize_value(definition, value)
    return nil if removable_value?(value)

    send("normalize_#{definition.field_type}", definition, value)
  end

  def removable_value?(value)
    value.nil? || (value.is_a?(String) && value.strip.empty?)
  end

  def normalize_text(_definition, value)
    value.to_s.strip
  end

  def normalize_number(_definition, value)
    BigDecimal(value.to_s).to_s('F')
  end

  alias normalize_currency normalize_number

  def normalize_date(_definition, value)
    Date.iso8601(value.to_s).iso8601
  end

  def normalize_boolean(_definition, value)
    return value if [true, false].include?(value)
    return true if value.to_s == 'true'
    return false if value.to_s == 'false'

    raise ArgumentError
  end

  def normalize_list(definition, value)
    normalized_value = value.to_s
    return normalized_value if Array(definition.settings['choices']).include?(normalized_value)

    raise ArgumentError
  end

  def normalize_link(_definition, value)
    uri = URI.parse(value.to_s)
    raise URI::InvalidURIError unless uri.is_a?(URI::HTTP) && uri.host.present?

    uri.to_s
  end

  def normalize_user_reference(_definition, value)
    pipeline_item.account.users.find(value).id
  end

  def add_invalid_value_error(definition)
    pipeline_item.errors.add(
      :field_values,
      I18n.t('errors.pipeline_item.invalid_field_value', label: definition.label)
    )
    raise ActiveRecord::RecordInvalid, pipeline_item
  end

  def record_event(previous_values, current_values)
    changed_keys = values.keys.reject { |key| previous_values[key] == current_values[key] }
    return if changed_keys.empty?

    PipelineItemEvent.create!(
      account: pipeline_item.account,
      pipeline_item: pipeline_item,
      actor: actor,
      event_type: :field_values_updated,
      source: source,
      metadata: { changed_field_keys: changed_keys }
    )
  end
end
