import {
  attentionItems,
  channelTranslationKey,
  conversationChangeAffectsItems,
  DEFAULT_PIPELINE_FILTERS,
  mergePipelineWorkspacePreference,
  pipelineLoadStateForError,
  readPipelineWorkspacePreference,
  sortPipelineItems,
} from './workspace';

describe('pipeline workspace preferences', () => {
  it('keeps view state isolated by account and pipeline', () => {
    const existing = {
      pipeline_workspace_preferences: {
        1: {
          10: { viewMode: 'list', filters: { q: 'existing' } },
        },
      },
    };

    const merged = mergePipelineWorkspacePreference(existing, 2, 20, {
      viewMode: 'attention',
      filters: { ownerId: 7 },
    });

    expect(merged['1']['10'].viewMode).toBe('list');
    expect(merged['2']['20']).toEqual({
      viewMode: 'attention',
      filters: { ...DEFAULT_PIPELINE_FILTERS, ownerId: 7 },
    });
  });

  it('reads safe defaults for unknown or invalid preferences', () => {
    expect(readPipelineWorkspacePreference({}, 1, 2)).toEqual({
      viewMode: 'kanban',
      filters: DEFAULT_PIPELINE_FILTERS,
    });
    expect(
      readPipelineWorkspacePreference(
        {
          pipeline_workspace_preferences: {
            1: { 2: { viewMode: 'invalid', filters: { q: 'Acme' } } },
          },
        },
        1,
        2
      )
    ).toEqual({
      viewMode: 'kanban',
      filters: { ...DEFAULT_PIPELINE_FILTERS, q: 'Acme' },
    });
  });

  it('restores the report workspace mode', () => {
    expect(
      readPipelineWorkspacePreference(
        {
          pipeline_workspace_preferences: {
            1: { 2: { viewMode: 'report' } },
          },
        },
        1,
        2
      )
    ).toEqual({
      viewMode: 'report',
      filters: DEFAULT_PIPELINE_FILTERS,
    });
  });
});

describe('pipeline workspace context', () => {
  const items = [
    {
      id: 1,
      workspace: {
        conversation_ids: [42],
        attention_reasons: ['overdue_activity'],
      },
    },
    {
      id: 2,
      workspace: { conversation_ids: [43], attention_reasons: [] },
    },
  ];

  it('selects attention items and linked conversation events', () => {
    expect(attentionItems(items).map(item => item.id)).toEqual([1]);
    expect(conversationChangeAffectsItems(items, 42)).toBe(true);
    expect(conversationChangeAffectsItems(items, 99)).toBe(false);
  });

  it('normalizes channel translation keys', () => {
    expect(channelTranslationKey('Channel::Whatsapp')).toBe('WHATSAPP');
  });

  it('distinguishes permission failures from unavailable states', () => {
    expect(pipelineLoadStateForError({ response: { status: 403 } })).toBe(
      'forbidden'
    );
    expect(pipelineLoadStateForError({ response: { status: 500 } })).toBe(
      'error'
    );
  });

  it('sorts by operational activity, next action, and priority', () => {
    const sortable = [
      {
        id: 1,
        priority: 'low',
        next_activity: null,
        workspace: { last_activity_at: '2026-06-10T00:00:00Z' },
      },
      {
        id: 2,
        priority: 'urgent',
        next_activity: { due_at: '2026-06-15T00:00:00Z' },
        workspace: { last_activity_at: '2026-06-14T00:00:00Z' },
      },
    ];

    expect(sortPipelineItems(sortable, 'recent').map(item => item.id)).toEqual([
      2, 1,
    ]);
    expect(
      sortPipelineItems(sortable, 'next_activity').map(item => item.id)
    ).toEqual([2, 1]);
    expect(
      sortPipelineItems(sortable, 'priority').map(item => item.id)
    ).toEqual([2, 1]);
  });
});
