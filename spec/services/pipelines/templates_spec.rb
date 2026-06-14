require 'rails_helper'

RSpec.describe Pipelines::Templates do
  it 'exposes the six workflow templates and custom option' do
    expect(described_class.all.pluck(:key)).to eq(
      %w[sales support recruitment onboarding collections real_estate custom]
    )
  end

  it 'marks terminal business outcomes explicitly' do
    sales = described_class.fetch('sales')

    expect(sales[:stages].select { |stage| stage[:terminal] }.pluck(:outcome_key)).to eq(%w[won lost])
  end

  it 'does not infer outcomes for active stages' do
    described_class.all.each do |template|
      template[:stages].reject { |stage| stage[:terminal] }.each do |stage|
        expect(stage[:outcome_key]).to be_nil
      end
    end
  end
end
