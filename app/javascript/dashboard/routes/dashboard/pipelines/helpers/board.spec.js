import {
  buildPipelineItemPayload,
  groupItemsByStage,
  pipelineCapabilities,
} from './board';

describe('#groupItemsByStage', () => {
  it('keeps stage order and groups matching cards', () => {
    const stages = [
      { id: 1, name: 'New' },
      { id: 2, name: 'Qualified' },
    ];
    const items = [
      { id: 3, stage_id: 2 },
      { id: 4, stage_id: 1 },
    ];

    expect(groupItemsByStage(stages, items)).toEqual([
      { id: 1, name: 'New', items: [{ id: 4, stage_id: 1 }] },
      { id: 2, name: 'Qualified', items: [{ id: 3, stage_id: 2 }] },
    ]);
  });
});

describe('#buildPipelineItemPayload', () => {
  it('omits empty optional values', () => {
    expect(
      buildPipelineItemPayload({
        pipelineId: 1,
        stageId: 2,
        contactId: 3,
        ownerId: '',
        teamId: '',
        title: ' ',
        priority: '',
        value: '',
        dueDate: '',
        conversationId: '',
      })
    ).toEqual({
      pipeline_item: {
        pipeline_id: 1,
        stage_id: 2,
        contact_id: 3,
      },
    });
  });

  it('normalizes supported optional values', () => {
    expect(
      buildPipelineItemPayload({
        pipelineId: 1,
        stageId: 2,
        contactId: 3,
        ownerId: 4,
        teamId: 5,
        title: ' Renewal ',
        priority: 'high',
        value: '2500.50',
        dueDate: '2026-06-30',
        conversationId: 12,
      })
    ).toEqual({
      pipeline_item: {
        pipeline_id: 1,
        stage_id: 2,
        contact_id: 3,
        owner_id: 4,
        team_id: 5,
        title: 'Renewal',
        priority: 'high',
        value: 2500.5,
        due_date: '2026-06-30',
        conversation_id: 12,
      },
    });
  });
});

describe('#pipelineCapabilities', () => {
  it('normalizes server capabilities for UI controls', () => {
    expect(
      pipelineCapabilities({
        capabilities: {
          view: true,
          create_item: true,
          update_item: true,
          move_item: false,
          archive_item: false,
          configure: false,
          export: false,
          automate: false,
        },
      })
    ).toEqual({
      canView: true,
      canCreate: true,
      canUpdate: true,
      canMove: false,
      canArchive: false,
      canConfigure: false,
      canExport: false,
      canAutomate: false,
    });
  });

  it('defaults every capability to false when authorization is absent', () => {
    expect(pipelineCapabilities({})).toEqual({
      canView: false,
      canCreate: false,
      canUpdate: false,
      canMove: false,
      canArchive: false,
      canConfigure: false,
      canExport: false,
      canAutomate: false,
    });
  });
});
