class Pipelines::Items::MissingRequiredFieldsError < StandardError
  attr_reader :field_definitions

  def initialize(field_definitions)
    @field_definitions = field_definitions
    super(I18n.t('errors.pipeline_item.missing_required_fields'))
  end

  def field_keys
    field_definitions.map(&:key)
  end
end
