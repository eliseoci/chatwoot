class Pipelines::Templates
  DEFAULT_COLOR = '#6B7280'.freeze

  DEFINITIONS = {
    'sales' => {
      stages: [
        { key: 'new_lead' },
        { key: 'qualified' },
        { key: 'proposal' },
        { key: 'won', terminal: true, outcome_key: 'won' },
        { key: 'lost', terminal: true, outcome_key: 'lost' }
      ]
    },
    'support' => {
      stages: [
        { key: 'new' },
        { key: 'investigating' },
        { key: 'waiting' },
        { key: 'resolved', terminal: true, outcome_key: 'completed' }
      ]
    },
    'recruitment' => {
      stages: [
        { key: 'applied' },
        { key: 'screening' },
        { key: 'interview' },
        { key: 'hired', terminal: true, outcome_key: 'hired' },
        { key: 'rejected', terminal: true, outcome_key: 'rejected' }
      ]
    },
    'onboarding' => {
      stages: [
        { key: 'new_customer' },
        { key: 'setup' },
        { key: 'training' },
        { key: 'live', terminal: true, outcome_key: 'completed' }
      ]
    },
    'collections' => {
      stages: [
        { key: 'new_account' },
        { key: 'contacted' },
        { key: 'payment_plan' },
        { key: 'paid', terminal: true, outcome_key: 'paid' },
        { key: 'escalated', terminal: true, outcome_key: 'escalated' }
      ]
    },
    'real_estate' => {
      stages: [
        { key: 'new_inquiry' },
        { key: 'qualified' },
        { key: 'viewing' },
        { key: 'offer' },
        { key: 'closed', terminal: true, outcome_key: 'won' },
        { key: 'lost', terminal: true, outcome_key: 'lost' }
      ]
    },
    'custom' => { stages: [] }
  }.freeze

  class << self
    def all
      DEFINITIONS.map { |key, definition| serialize(key, definition) }
    end

    def fetch(key)
      definition = DEFINITIONS[key.to_s]
      return if definition.blank?

      serialize(key.to_s, definition)
    end

    private

    def serialize(key, definition)
      {
        key: key,
        name: I18n.t("pipeline_templates.#{key}.name"),
        description: I18n.t("pipeline_templates.#{key}.description"),
        stages: definition[:stages].map.with_index do |stage, position|
          {
            name: I18n.t("pipeline_templates.#{key}.stages.#{stage[:key]}"),
            position: position,
            color: DEFAULT_COLOR,
            terminal: stage.fetch(:terminal, false),
            outcome_key: stage[:outcome_key]
          }
        end
      }
    end
  end
end
