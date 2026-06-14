class Pipelines::CreateFromTemplateService
  def initialize(account:, attributes:)
    @account = account
    @attributes = attributes.to_h.with_indifferent_access
  end

  def perform
    Pipeline.transaction do
      pipeline = account.pipelines.new(pipeline_attributes)
      stages = stage_attributes(pipeline)
      pipeline.save!

      stages.each_with_index do |stage, position|
        pipeline.stages.create!(
          stage.slice(:name, :color, :terminal, :outcome_key).merge(account: account, position: position)
        )
      end

      pipeline
    end
  end

  private

  attr_reader :account, :attributes

  def pipeline_attributes
    attributes.slice(:name, :description, :template_key)
  end

  def stage_attributes(pipeline)
    template = Pipelines::Templates.fetch(attributes[:template_key])
    return template[:stages] if template.present? && attributes[:template_key] != 'custom'

    custom_stages = Array(attributes[:stages]).map(&:with_indifferent_access)
    return custom_stages if custom_stages.present?

    pipeline.errors.add(:stages, I18n.t('errors.pipeline.stages_required'))
    raise ActiveRecord::RecordInvalid, pipeline
  end
end
