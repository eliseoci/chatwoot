require 'rails_helper'

RSpec.describe Pipelines::Items::TransitionStageService do
  let(:account) { create(:account) }
  let(:actor) { create(:user, account: account) }
  let(:pipeline) { create(:pipeline, :with_stages, account: account) }
  let(:item) do
    create(
      :pipeline_item,
      account: account,
      pipeline: pipeline,
      stage: pipeline.stages.first,
      contact: create(:contact, account: account)
    )
  end

  def transition(target_stage_id, source: 'api', pipeline_item: item)
    described_class.new(
      pipeline_item: pipeline_item,
      target_stage_id: target_stage_id,
      actor: actor,
      source: source
    ).perform
  end

  it 'moves the item and records an append-only transition' do
    target_stage = pipeline.stages.second

    expect { transition(target_stage.id, source: 'board_drag') }
      .to change(PipelineItemStageTransition, :count).by(1)

    history = item.stage_transitions.last
    expect(item.reload.stage).to eq(target_stage)
    expect(history).to have_attributes(
      from_stage: pipeline.stages.first,
      to_stage: target_stage,
      actor: actor,
      source: 'board_drag'
    )
  end

  it 'rejects a stage outside the current pipeline' do
    other_stage = create(:pipeline_stage)

    expect { transition(other_stage.id) }.to raise_error(ActiveRecord::RecordNotFound)
    expect(item.reload.stage).to eq(pipeline.stages.first)
  end

  it 'uses the locked current stage when another transition already won the race' do
    second_stage = pipeline.stages.second
    third_stage = create(:pipeline_stage, account: account, pipeline: pipeline, position: 2)
    stale_item = PipelineItem.find(item.id)

    transition(second_stage.id)
    transition(third_stage.id, pipeline_item: stale_item)

    latest_history = item.stage_transitions.order(:id).last
    expect(latest_history.from_stage).to eq(second_stage)
    expect(latest_history.to_stage).to eq(third_stage)
  end

  it 'rolls the item back when history persistence fails' do
    allow(PipelineItemStageTransition).to receive(:create!).and_raise(ActiveRecord::RecordInvalid)

    expect { transition(pipeline.stages.second.id) }.to raise_error(ActiveRecord::RecordInvalid)
    expect(item.reload.stage).to eq(pipeline.stages.first)
    expect(item.stage_transitions).to be_empty
  end

  it 'does not create duplicate history when the stage is unchanged' do
    expect { transition(pipeline.stages.first.id) }.not_to change(PipelineItemStageTransition, :count)
  end

  it 'does not change conversation status in the same account' do
    conversation = create(:conversation, account: account, status: :open)

    transition(pipeline.stages.second.id)

    expect(conversation.reload).to be_open
  end

  it 'does not transition an item when a conversation resolves' do
    conversation = create(:conversation, account: account, status: :open)

    conversation.update!(status: :resolved)

    expect(item.reload.stage).to eq(pipeline.stages.first)
    expect(item.stage_transitions).to be_empty
  end
end
