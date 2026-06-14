export const DEFAULT_PIPELINE_FILTERS = Object.freeze({
  q: '',
  stageId: '',
  ownerId: '',
  teamId: '',
  inboxId: '',
  channel: '',
  label: '',
  dueState: '',
  sort: 'recent',
});

export const normalizePipelineFilters = filters =>
  Object.keys(DEFAULT_PIPELINE_FILTERS).reduce(
    (result, key) => ({
      ...result,
      [key]: filters?.[key] ?? DEFAULT_PIPELINE_FILTERS[key],
    }),
    {}
  );

export const readPipelineWorkspacePreference = (
  uiSettings,
  accountId,
  pipelineId
) => {
  const preference =
    uiSettings?.pipeline_workspace_preferences?.[String(accountId)]?.[
      String(pipelineId)
    ];

  return {
    viewMode: ['kanban', 'list', 'attention'].includes(preference?.viewMode)
      ? preference.viewMode
      : 'kanban',
    filters: normalizePipelineFilters(preference?.filters),
  };
};

export const mergePipelineWorkspacePreference = (
  uiSettings,
  accountId,
  pipelineId,
  preference
) => {
  const preferences = uiSettings?.pipeline_workspace_preferences || {};
  const accountKey = String(accountId);
  const pipelineKey = String(pipelineId);

  return {
    ...preferences,
    [accountKey]: {
      ...(preferences[accountKey] || {}),
      [pipelineKey]: {
        viewMode: preference.viewMode,
        filters: normalizePipelineFilters(preference.filters),
      },
    },
  };
};

export const attentionItems = items =>
  items.filter(item => item.workspace?.attention_reasons?.length);

export const sortPipelineItems = (items, sort) => {
  const sorted = [...items];
  const activityTime = item =>
    new Date(item.workspace?.last_activity_at || 0).getTime();
  const nextActivityTime = item =>
    item.next_activity
      ? new Date(item.next_activity.due_at).getTime()
      : Infinity;
  const priority = { urgent: 0, high: 1, medium: 2, low: 3 };

  if (sort === 'oldest') {
    return sorted.sort(
      (left, right) => activityTime(left) - activityTime(right)
    );
  }
  if (sort === 'next_activity') {
    return sorted.sort(
      (left, right) => nextActivityTime(left) - nextActivityTime(right)
    );
  }
  if (sort === 'priority') {
    return sorted.sort(
      (left, right) =>
        (priority[left.priority] ?? 4) - (priority[right.priority] ?? 4)
    );
  }
  return sorted.sort((left, right) => activityTime(right) - activityTime(left));
};

export const conversationChangeAffectsItems = (items, conversationId) =>
  items.some(item =>
    item.workspace?.conversation_ids?.includes(Number(conversationId))
  );

export const pipelineLoadStateForError = error =>
  [401, 403].includes(error?.response?.status) ? 'forbidden' : 'error';

export const channelTranslationKey = channelType =>
  channelType?.replace('Channel::', '').toUpperCase();
