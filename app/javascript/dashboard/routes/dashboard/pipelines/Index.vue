<script setup>
import {
  computed,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import { useEmitter } from 'dashboard/composables/emitter';
import { useUISettings } from 'dashboard/composables/useUISettings';
import Draggable from 'vuedraggable';

import AgentsAPI from 'dashboard/api/agents';
import ContactAPI from 'dashboard/api/contacts';
import InboxesAPI from 'dashboard/api/inboxes';
import LabelsAPI from 'dashboard/api/labels';
import PipelineActivitiesAPI from 'dashboard/api/pipelineActivities';
import PipelineItemsAPI from 'dashboard/api/pipelineItems';
import PipelinesAPI from 'dashboard/api/pipelines';
import TeamsAPI from 'dashboard/api/teams';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import PipelineItemDetails from './components/PipelineItemDetails.vue';
import PipelineItemTable from './components/PipelineItemTable.vue';
import PipelineWorkspaceToolbar from './components/PipelineWorkspaceToolbar.vue';
import {
  buildPipelineActivityPayload,
  sortActivities,
} from './helpers/activities';
import { buildPipelineItemPayload, groupItemsByStage } from './helpers/board';
import { transitionMissingFields } from './helpers/customFields';
import {
  attentionItems,
  channelTranslationKey,
  conversationChangeAffectsItems,
  DEFAULT_PIPELINE_FILTERS,
  mergePipelineWorkspacePreference,
  pipelineLoadStateForError,
  readPipelineWorkspacePreference,
  sortPipelineItems,
} from './helpers/workspace';

const route = useRoute();
const router = useRouter();
const { locale, t } = useI18n();
const { uiSettings, updateUISettings } = useUISettings();

const pipelines = ref([]);
const items = ref([]);
const contacts = ref([]);
const agents = ref([]);
const teams = ref([]);
const inboxes = ref([]);
const labels = ref([]);
const activePipelineId = ref(null);
const columns = ref([]);
const isLoading = ref(true);
const loadState = ref('ready');
const isCreating = ref(false);
const dialogRef = ref(null);
const expandedTimelineItems = ref([]);
const timelines = reactive({});
const selectedItem = ref(null);
const candidateConversations = ref([]);
const isLoadingCandidates = ref(false);
const activeConversationId = ref(null);
const activities = ref([]);
const isLoadingActivities = ref(false);
const activeActivityId = ref(null);
const activeActivityAction = ref(null);
const isSavingFieldValues = ref(false);
const promptedRequiredFieldKeys = ref([]);
const viewMode = ref('kanban');
const filters = reactive({ ...DEFAULT_PIPELINE_FILTERS });
let conversationOperationSequence = 0;
let activityOperationSequence = 0;
let itemsRequestSequence = 0;
let filterRefreshTimer = null;
let realtimeRefreshTimer = null;

const form = reactive({
  title: '',
  stageId: '',
  contactId: '',
  ownerId: '',
  teamId: '',
  priority: '',
  value: '',
  dueDate: '',
});

const activePipeline = computed(() =>
  pipelines.value.find(pipeline => pipeline.id === activePipelineId.value)
);

const selectedRequiredFieldKeys = computed(() => {
  if (!selectedItem.value) return [];

  const currentStageKeys =
    activePipeline.value?.stages.find(
      stage => stage.id === selectedItem.value.stage_id
    )?.required_field_keys || [];

  return [...new Set([...currentStageKeys, ...promptedRequiredFieldKeys.value])];
});

const sortedItems = computed(() => sortPipelineItems(items.value, filters.sort));

const visibleItems = computed(() =>
  viewMode.value === 'attention'
    ? attentionItems(sortedItems.value)
    : sortedItems.value
);

const isCreateDisabled = computed(() => !form.stageId || !form.contactId);

const priorityOptions = computed(() => [
  { value: '', label: t('PIPELINES_BOARD.FORM.PRIORITY_NONE') },
  { value: 'low', label: t('PIPELINES_BOARD.PRIORITY.LOW') },
  { value: 'medium', label: t('PIPELINES_BOARD.PRIORITY.MEDIUM') },
  { value: 'high', label: t('PIPELINES_BOARD.PRIORITY.HIGH') },
  { value: 'urgent', label: t('PIPELINES_BOARD.PRIORITY.URGENT') },
]);

const priorityLabel = priority =>
  priorityOptions.value.find(option => option.value === priority)?.label;

const formatValue = value =>
  new Intl.NumberFormat(locale.value, {
    maximumFractionDigits: 2,
  }).format(Number(value));

const formatDueDate = dueDate =>
  new Intl.DateTimeFormat(locale.value, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  }).format(new Date(`${dueDate}T00:00:00`));

const formatTransitionTime = createdAt =>
  new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(createdAt));

const formatActivityTime = dueAt =>
  new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(dueAt));

const activityTypeLabel = activityType =>
  t(`PIPELINES_BOARD.ACTIVITIES.TYPE.${activityType.toUpperCase()}`);

const channelLabel = channelType => {
  const key = `PIPELINES_BOARD.DETAIL.CHANNEL.${channelTranslationKey(
    channelType
  )}`;
  const translated = t(key);
  return translated === key
    ? t('PIPELINES_BOARD.DETAIL.CHANNEL.OTHER')
    : translated;
};

const channelOptions = computed(() =>
  [...new Set(inboxes.value.map(inbox => inbox.channel_type))]
    .filter(Boolean)
    .sort()
    .map(channel => ({
      value: channel,
      label: channelLabel(channel),
    }))
);

const attentionReasonLabel = reason =>
  t(`PIPELINES_BOARD.ATTENTION.REASONS.${reason.toUpperCase()}`);

const timelineActor = transition =>
  transition.actor?.name || t('PIPELINES_BOARD.TIMELINE.SYSTEM_ACTOR');

const timelineConversation = transition =>
  transition.conversation?.id ||
  t('PIPELINES_BOARD.TIMELINE.REMOVED_CONVERSATION');

const syncColumns = () => {
  columns.value = groupItemsByStage(
    activePipeline.value?.stages || [],
    sortedItems.value
  );
};

const loadItems = async () => {
  const requestId = ++itemsRequestSequence;
  const pipelineId = activePipelineId.value;
  if (!activePipelineId.value) {
    items.value = [];
    syncColumns();
    return;
  }

  const response = await PipelineItemsAPI.get({
    pipelineId,
    ...filters,
  });
  if (
    requestId !== itemsRequestSequence ||
    pipelineId !== activePipelineId.value
  ) {
    return;
  }
  items.value = response.data;
  syncColumns();
};

const restoreWorkspacePreference = () => {
  if (!activePipelineId.value) return;

  const preference = readPipelineWorkspacePreference(
    uiSettings.value,
    route.params.accountId,
    activePipelineId.value
  );
  viewMode.value = preference.viewMode;
  Object.assign(filters, preference.filters);
};

const saveWorkspacePreference = () => {
  if (!activePipelineId.value) return;

  updateUISettings({
    pipeline_workspace_preferences: mergePipelineWorkspacePreference(
      uiSettings.value,
      route.params.accountId,
      activePipelineId.value,
      {
        viewMode: viewMode.value,
        filters,
      }
    ),
  });
};

const loadBoard = async () => {
  isLoading.value = true;
  loadState.value = 'ready';
  try {
    const [
      pipelinesResponse,
      contactsResponse,
      agentsResponse,
      teamsResponse,
      inboxesResponse,
      labelsResponse,
    ] = await Promise.all([
      PipelinesAPI.get(),
      ContactAPI.get(1),
      AgentsAPI.get(),
      TeamsAPI.get(),
      InboxesAPI.get(),
      LabelsAPI.get(),
    ]);

    pipelines.value = pipelinesResponse.data;
    contacts.value = contactsResponse.data.payload;
    agents.value = agentsResponse.data;
    teams.value = teamsResponse.data;
    inboxes.value = inboxesResponse.data.payload;
    labels.value = labelsResponse.data.payload;

    const routePipelineId = Number(route.params.pipelineId);
    activePipelineId.value =
      pipelines.value.find(pipeline => pipeline.id === routePipelineId)?.id ||
      pipelines.value[0]?.id ||
      null;

    restoreWorkspacePreference();
    await loadItems();
  } catch (error) {
    loadState.value = pipelineLoadStateForError(error);
  } finally {
    isLoading.value = false;
  }
};

const refreshFilteredItems = () => {
  clearTimeout(filterRefreshTimer);
  filterRefreshTimer = setTimeout(async () => {
    saveWorkspacePreference();
    try {
      await loadItems();
      loadState.value = 'ready';
    } catch (error) {
      loadState.value = pipelineLoadStateForError(error);
    }
  }, 250);
};

const updateFilters = nextFilters => {
  Object.assign(filters, nextFilters);
  refreshFilteredItems();
};

const clearFilters = () => {
  Object.assign(filters, DEFAULT_PIPELINE_FILTERS);
  refreshFilteredItems();
};

const updateViewMode = mode => {
  viewMode.value = mode;
  saveWorkspacePreference();
};

const resetForm = () => {
  Object.assign(form, {
    title: '',
    stageId: activePipeline.value?.stages[0]?.id || '',
    contactId: '',
    ownerId: '',
    teamId: '',
    priority: '',
    value: '',
    dueDate: '',
  });
};

const openCreateDialog = () => {
  resetForm();
  dialogRef.value?.open();
};

const createItem = async () => {
  if (isCreateDisabled.value) return;

  isCreating.value = true;
  try {
    const response = await PipelineItemsAPI.create(
      buildPipelineItemPayload({
        pipelineId: activePipelineId.value,
        stageId: form.stageId,
        contactId: form.contactId,
        ownerId: form.ownerId,
        teamId: form.teamId,
        title: form.title,
        priority: form.priority,
        value: form.value,
        dueDate: form.dueDate,
      })
    );
    items.value.unshift({
      ...response.data,
      linked_conversations: [],
    });
    syncColumns();
    dialogRef.value?.close();
    useAlert(t('PIPELINES_BOARD.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const transitionItem = async (item, targetStageId, source, optimistic = true) => {
  const previousStageId = item.stage_id;
  if (previousStageId === targetStageId) return;

  item.stage_id = targetStageId;
  if (optimistic) syncColumns();

  try {
    const response = await PipelineItemsAPI.transition(item.id, {
      stageId: targetStageId,
      source,
    });
    Object.assign(item, response.data);
    promptedRequiredFieldKeys.value = [];
    expandedTimelineItems.value = expandedTimelineItems.value.filter(
      itemId => itemId !== item.id
    );
    timelines[item.id] = null;
  } catch (error) {
    item.stage_id = previousStageId;
    syncColumns();
    const missingFields = transitionMissingFields(error);
    if (missingFields.length) {
      promptedRequiredFieldKeys.value = missingFields.map(field => field.key);
      useAlert(
        t('PIPELINES_BOARD.API.TRANSITION_REQUIRED_FIELDS', {
          fields: missingFields.map(field => field.label).join(', '),
        })
      );
      openItemDetails(item);
    } else {
      useAlert(t('PIPELINES_BOARD.API.TRANSITION_ERROR'));
    }
  }
};

const handleDragChange = (event, column) => {
  if (!event.added) return;

  transitionItem(event.added.element, column.id, 'board_drag', false);
};

const moveItemWithCommand = (item, event) => {
  transitionItem(
    item,
    Number(event.target.value),
    'board_command',
    true
  );
};

const moveItemFromList = ({ item, stageId }) => {
  transitionItem(item, stageId, 'board_command', true);
};

const toggleTimeline = async item => {
  if (expandedTimelineItems.value.includes(item.id)) {
    expandedTimelineItems.value = expandedTimelineItems.value.filter(
      itemId => itemId !== item.id
    );
    return;
  }

  expandedTimelineItems.value.push(item.id);
  if (timelines[item.id]) return;

  try {
    const response = await PipelineItemsAPI.timeline(item.id);
    timelines[item.id] = response.data;
  } catch (error) {
    expandedTimelineItems.value = expandedTimelineItems.value.filter(
      itemId => itemId !== item.id
    );
    useAlert(t('PIPELINES_BOARD.API.TIMELINE_ERROR'));
  }
};

const openItemDetails = async item => {
  item.linked_conversations ||= [];
  selectedItem.value = item;
  candidateConversations.value = [];
  isLoadingCandidates.value = true;
  isLoadingActivities.value = true;
  const itemId = item.id;

  try {
    const [
      conversationsResponse,
      linkedConversationsResponse,
      activitiesResponse,
    ] = await Promise.all([
      ContactAPI.getConversations(item.contact.id),
      PipelineItemsAPI.linkedConversations(item.id),
      PipelineActivitiesAPI.get(item.id),
    ]);
    if (selectedItem.value?.id !== itemId) return;
    candidateConversations.value = conversationsResponse.data.payload;
    item.linked_conversations = linkedConversationsResponse.data;
    activities.value = sortActivities(activitiesResponse.data);
  } catch (error) {
    if (selectedItem.value?.id !== itemId) return;
    useAlert(t('PIPELINES_BOARD.API.DETAIL_LOAD_ERROR'));
  } finally {
    if (selectedItem.value?.id === itemId) {
      isLoadingCandidates.value = false;
      isLoadingActivities.value = false;
    }
  }
};

const closeItemDetails = () => {
  conversationOperationSequence += 1;
  activityOperationSequence += 1;
  selectedItem.value = null;
  candidateConversations.value = [];
  activeConversationId.value = null;
  activities.value = [];
  isLoadingActivities.value = false;
  activeActivityId.value = null;
  activeActivityAction.value = null;
  isSavingFieldValues.value = false;
  promptedRequiredFieldKeys.value = [];
};

const saveFieldValues = async fieldValues => {
  if (!selectedItem.value) return;

  const item = selectedItem.value;
  isSavingFieldValues.value = true;
  try {
    const response = await PipelineItemsAPI.updateFieldValues(item.id, {
      fieldValues,
      source: 'item_detail',
    });
    Object.assign(item, response.data);
    promptedRequiredFieldKeys.value = [];
    timelines[item.id] = null;
    useAlert(t('PIPELINES_BOARD.API.FIELD_VALUES_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.FIELD_VALUES_ERROR'));
  } finally {
    if (selectedItem.value?.id === item.id) {
      isSavingFieldValues.value = false;
    }
  }
};

const linkConversation = async conversationId => {
  if (!selectedItem.value) return;

  const item = selectedItem.value;
  const operationId = ++conversationOperationSequence;
  activeConversationId.value = conversationId;
  try {
    const response = await PipelineItemsAPI.linkConversation(item.id, {
      conversationId,
      source: 'item_detail',
    });
    if (
      !item.linked_conversations.some(
        conversation => conversation.id === response.data.id
      )
    ) {
      item.linked_conversations.unshift(response.data);
    }
    timelines[item.id] = null;
    expandedTimelineItems.value = expandedTimelineItems.value.filter(
      itemId => itemId !== item.id
    );
    useAlert(t('PIPELINES_BOARD.API.CONVERSATION_LINK_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.CONVERSATION_LINK_ERROR'));
  } finally {
    if (operationId === conversationOperationSequence) {
      activeConversationId.value = null;
    }
  }
};

const unlinkConversation = async conversationId => {
  if (!selectedItem.value) return;

  const item = selectedItem.value;
  const operationId = ++conversationOperationSequence;
  activeConversationId.value = conversationId;
  try {
    await PipelineItemsAPI.unlinkConversation(item.id, {
      conversationId,
      source: 'item_detail',
    });
    item.linked_conversations = item.linked_conversations.filter(
      conversation => conversation.id !== conversationId
    );
    timelines[item.id] = null;
    expandedTimelineItems.value = expandedTimelineItems.value.filter(
      itemId => itemId !== item.id
    );
    useAlert(t('PIPELINES_BOARD.API.CONVERSATION_UNLINK_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.CONVERSATION_UNLINK_ERROR'));
  } finally {
    if (operationId === conversationOperationSequence) {
      activeConversationId.value = null;
    }
  }
};

const syncNextActivity = item => {
  item.next_activity =
    sortActivities(activities.value).find(
      activity => activity.status === 'scheduled'
    ) || null;
};

const saveActivity = async activityForm => {
  if (!selectedItem.value) return;

  const item = selectedItem.value;
  const operationId = ++activityOperationSequence;
  activeActivityId.value = activityForm.id || 0;
  activeActivityAction.value = 'save';

  try {
    const payload = buildPipelineActivityPayload(activityForm);
    const response = activityForm.id
      ? await PipelineActivitiesAPI.update(item.id, activityForm.id, payload)
      : await PipelineActivitiesAPI.create(item.id, payload);
    if (
      operationId !== activityOperationSequence ||
      selectedItem.value?.id !== item.id
    ) {
      return;
    }
    const existingIndex = activities.value.findIndex(
      activity => activity.id === response.data.id
    );
    if (existingIndex === -1) {
      activities.value.push(response.data);
    } else {
      activities.value.splice(existingIndex, 1, response.data);
    }
    activities.value = sortActivities(activities.value);
    syncNextActivity(item);
    timelines[item.id] = null;
    useAlert(
      t(
        activityForm.id
          ? 'PIPELINES_BOARD.API.ACTIVITY_UPDATE_SUCCESS'
          : 'PIPELINES_BOARD.API.ACTIVITY_CREATE_SUCCESS'
      )
    );
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.ACTIVITY_SAVE_ERROR'));
  } finally {
    if (operationId === activityOperationSequence) {
      activeActivityId.value = null;
      activeActivityAction.value = null;
    }
  }
};

const changeActivityStatus = async (activityId, action) => {
  if (!selectedItem.value) return;

  const item = selectedItem.value;
  const operationId = ++activityOperationSequence;
  activeActivityId.value = activityId;
  activeActivityAction.value = action;

  try {
    const response = await PipelineActivitiesAPI[action](
      item.id,
      activityId,
      'item_detail'
    );
    if (
      operationId !== activityOperationSequence ||
      selectedItem.value?.id !== item.id
    ) {
      return;
    }
    const activityIndex = activities.value.findIndex(
      activity => activity.id === activityId
    );
    if (activityIndex >= 0) {
      activities.value.splice(activityIndex, 1, response.data);
    }
    activities.value = sortActivities(activities.value);
    syncNextActivity(item);
    timelines[item.id] = null;
    useAlert(t(`PIPELINES_BOARD.API.ACTIVITY_${action.toUpperCase()}_SUCCESS`));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.ACTIVITY_STATUS_ERROR'));
  } finally {
    if (operationId === activityOperationSequence) {
      activeActivityId.value = null;
      activeActivityAction.value = null;
    }
  }
};

const openConversation = conversationId => {
  router.push({
    name: 'inbox_conversation',
    params: {
      accountId: route.params.accountId,
      conversation_id: conversationId,
    },
  });
};

const changePipeline = async () => {
  restoreWorkspacePreference();
  await router.push({
    name: 'pipelines_board',
    params: { pipelineId: activePipelineId.value },
  });

  try {
    await loadItems();
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.LOAD_ERROR'));
  }
};

const scheduleRealtimeRefresh = () => {
  clearTimeout(realtimeRefreshTimer);
  realtimeRefreshTimer = setTimeout(async () => {
    try {
      await loadItems();
    } catch (error) {
      loadState.value = pipelineLoadStateForError(error);
    }
  }, 150);
};

const handlePipelineItemChanged = payload => {
  if (Number(payload.pipeline_id) !== activePipelineId.value) return;

  scheduleRealtimeRefresh();
};

const handlePipelineConversationChanged = payload => {
  const conversationId = payload.id || payload.conversation_id;
  if (!conversationId) return;
  if (!conversationChangeAffectsItems(items.value, conversationId)) return;

  scheduleRealtimeRefresh();
};

useEmitter(BUS_EVENTS.PIPELINE_ITEM_CHANGED, handlePipelineItemChanged);
useEmitter(
  BUS_EVENTS.PIPELINE_CONVERSATION_CHANGED,
  handlePipelineConversationChanged
);
useEmitter(BUS_EVENTS.WEBSOCKET_RECONNECT_COMPLETED, scheduleRealtimeRefresh);

watch(
  () => route.params.pipelineId,
  pipelineId => {
    const parsedPipelineId = Number(pipelineId);
    if (
      parsedPipelineId &&
      parsedPipelineId !== activePipelineId.value &&
      pipelines.value.some(pipeline => pipeline.id === parsedPipelineId)
    ) {
      activePipelineId.value = parsedPipelineId;
      restoreWorkspacePreference();
      loadItems();
    }
  }
);

onMounted(loadBoard);
onBeforeUnmount(() => {
  clearTimeout(filterRefreshTimer);
  clearTimeout(realtimeRefreshTimer);
});
</script>

<template>
  <div class="flex h-full min-w-0 flex-col bg-n-background">
    <header
      class="flex flex-wrap items-center justify-between gap-3 border-b border-n-weak px-5 py-4"
    >
      <div class="flex min-w-0 items-center gap-3">
        <span
          class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-n-blue-3 text-n-blue-11"
        >
          <Icon icon="i-lucide-columns-3" class="size-4" />
        </span>
        <div class="min-w-0">
          <h1 class="text-heading-2 text-n-slate-12">
            {{ $t('PIPELINES_BOARD.HEADER') }}
          </h1>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ $t('PIPELINES_BOARD.DESCRIPTION') }}
          </p>
        </div>
      </div>

      <div class="flex items-center gap-2">
        <select
          v-if="pipelines.length"
          v-model.number="activePipelineId"
          :aria-label="$t('PIPELINES_BOARD.PIPELINE_SELECTOR')"
          class="h-9 min-w-48 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          @change="changePipeline"
        >
          <option
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            :value="pipeline.id"
          >
            {{ pipeline.name }}
          </option>
        </select>
        <Button
          v-if="activePipeline"
          size="sm"
          icon="i-lucide-plus"
          :label="$t('PIPELINES_BOARD.ADD_ITEM')"
          @click="openCreateDialog"
        />
      </div>
    </header>

    <div
      v-if="isLoading"
      class="flex flex-1 items-center justify-center text-sm text-n-slate-11"
    >
      {{ $t('PIPELINES_BOARD.LOADING') }}
    </div>

    <div
      v-else-if="loadState === 'forbidden'"
      class="flex flex-1 flex-col items-center justify-center gap-3 px-6 text-center"
    >
      <Icon icon="i-lucide-shield-alert" class="size-8 text-n-ruby-10" />
      <div>
        <h2 class="text-heading-2 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.STATES.FORBIDDEN_TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PIPELINES_BOARD.STATES.FORBIDDEN_DESCRIPTION') }}
        </p>
      </div>
    </div>

    <div
      v-else-if="loadState === 'error'"
      class="flex flex-1 flex-col items-center justify-center gap-3 px-6 text-center"
    >
      <Icon icon="i-lucide-triangle-alert" class="size-8 text-n-amber-10" />
      <div>
        <h2 class="text-heading-2 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.STATES.ERROR_TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PIPELINES_BOARD.STATES.ERROR_DESCRIPTION') }}
        </p>
      </div>
      <Button :label="$t('PIPELINES_BOARD.STATES.RETRY')" @click="loadBoard" />
    </div>

    <div
      v-else-if="!pipelines.length"
      class="flex flex-1 flex-col items-center justify-center gap-3 px-6 text-center"
    >
      <Icon icon="i-lucide-columns-3" class="size-8 text-n-slate-10" />
      <div>
        <h2 class="text-heading-2 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.EMPTY_PIPELINES.TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PIPELINES_BOARD.EMPTY_PIPELINES.DESCRIPTION') }}
        </p>
      </div>
      <router-link :to="{ name: 'settings_pipelines_index' }">
        <Button :label="$t('PIPELINES_BOARD.EMPTY_PIPELINES.ACTION')" />
      </router-link>
    </div>

    <template v-else>
      <PipelineWorkspaceToolbar
        :view-mode="viewMode"
        :filters="filters"
        :stages="activePipeline?.stages || []"
        :agents="agents"
        :teams="teams"
        :inboxes="inboxes"
        :labels="labels"
        :channels="channelOptions"
        @update:view-mode="updateViewMode"
        @update:filters="updateFilters"
        @clear="clearFilters"
      />

      <main
        v-if="viewMode === 'kanban'"
        class="flex flex-1 gap-4 overflow-x-auto p-5"
      >
      <section
        v-for="column in columns"
        :key="column.id"
        class="flex w-72 shrink-0 flex-col gap-3"
      >
        <div class="flex items-center justify-between px-1">
          <div class="flex min-w-0 items-center gap-2">
            <span class="size-2 rounded-full bg-n-slate-8" />
            <h2 class="truncate text-heading-3 text-n-slate-12">
              {{ column.name }}
            </h2>
          </div>
          <span class="text-xs text-n-slate-10">
            {{ column.items.length }}
          </span>
        </div>

        <Draggable
          v-model="column.items"
          :group="{ name: 'pipeline-items' }"
          item-key="id"
          handle=".pipeline-item-drag-handle"
          class="flex min-h-24 flex-col gap-2 rounded-xl bg-n-alpha-black2 p-2"
          ghost-class="opacity-50"
          @change="handleDragChange($event, column)"
        >
          <template #item="{ element: item }">
            <article
              class="flex flex-col gap-3 rounded-lg bg-n-solid-1 p-3 outline outline-1 -outline-offset-1 outline-n-weak"
            >
              <div class="flex items-start gap-2">
                <button
                  type="button"
                  class="pipeline-item-drag-handle mt-0.5 cursor-grab text-n-slate-9 hover:text-n-slate-11"
                  :aria-label="
                    $t('PIPELINES_BOARD.MOVE.DRAG_LABEL', {
                      title: item.display_title,
                    })
                  "
                >
                  <Icon icon="i-lucide-grip-vertical" class="size-4" />
                </button>
                <div class="min-w-0 flex-1">
                  <h3 class="text-heading-3 text-n-slate-12">
                    {{ item.display_title }}
                  </h3>
                  <p
                    v-if="item.title && item.contact.name"
                    class="mb-0 truncate text-xs text-n-slate-11"
                  >
                    {{ item.contact.name }}
                  </p>
                </div>
              </div>

              <div class="flex flex-wrap gap-1.5">
                <span
                  v-if="item.priority"
                  class="rounded-md bg-n-amber-3 px-2 py-1 text-xs text-n-amber-11"
                >
                  {{ priorityLabel(item.priority) }}
                </span>
                <span
                  v-if="item.value !== null"
                  class="rounded-md bg-n-alpha-black2 px-2 py-1 text-xs text-n-slate-11"
                >
                  {{ formatValue(item.value) }}
                </span>
                <span
                  v-if="item.due_date"
                  class="rounded-md bg-n-alpha-black2 px-2 py-1 text-xs text-n-slate-11"
                >
                  {{ formatDueDate(item.due_date) }}
                </span>
              </div>

              <div
                v-if="item.workspace?.attention_reasons?.length"
                class="flex flex-wrap gap-1"
              >
                <span
                  v-for="reason in item.workspace.attention_reasons.slice(0, 2)"
                  :key="reason"
                  class="rounded-md bg-n-ruby-3 px-1.5 py-0.5 text-xs text-n-ruby-11"
                >
                  {{ attentionReasonLabel(reason) }}
                </span>
                <span
                  v-if="item.workspace.attention_reasons.length > 2"
                  class="rounded-md bg-n-alpha-black2 px-1.5 py-0.5 text-xs text-n-slate-10"
                >
                  +{{ item.workspace.attention_reasons.length - 2 }}
                </span>
              </div>

              <div
                v-if="item.owner || item.team"
                class="flex items-center gap-1.5 text-xs text-n-slate-10"
              >
                <Icon icon="i-lucide-user-round" class="size-3.5" />
                <span v-if="item.owner">{{ item.owner.name }}</span>
                <span v-if="item.owner && item.team">·</span>
                <span v-if="item.team">{{ item.team.name }}</span>
              </div>

              <div
                v-if="item.next_activity"
                class="flex items-start gap-2 rounded-lg px-2.5 py-2 text-xs"
                :class="
                  item.next_activity.overdue
                    ? 'bg-n-ruby-3 text-n-ruby-11'
                    : 'bg-n-alpha-black2 text-n-slate-11'
                "
              >
                <Icon
                  :icon="
                    item.next_activity.overdue
                      ? 'i-lucide-circle-alert'
                      : 'i-lucide-calendar-clock'
                  "
                  class="mt-0.5 size-3.5 shrink-0"
                />
                <div class="min-w-0">
                  <p class="mb-0 truncate font-medium">
                    {{ item.next_activity.title }}
                  </p>
                  <p class="mb-0 opacity-80">
                    {{
                      item.next_activity.overdue
                        ? $t('PIPELINES_BOARD.ACTIVITIES.CARD_OVERDUE', {
                            type: activityTypeLabel(
                              item.next_activity.activity_type
                            ),
                            date: formatActivityTime(item.next_activity.due_at),
                          })
                        : $t('PIPELINES_BOARD.ACTIVITIES.CARD_DUE', {
                            type: activityTypeLabel(
                              item.next_activity.activity_type
                            ),
                            date: formatActivityTime(item.next_activity.due_at),
                          })
                    }}
                  </p>
                </div>
              </div>

              <div class="flex items-center gap-2 border-t border-n-weak pt-2">
                <select
                  :value="item.stage_id"
                  :aria-label="
                    $t('PIPELINES_BOARD.MOVE.COMMAND_LABEL', {
                      title: item.display_title,
                    })
                  "
                  class="h-7 min-w-0 flex-1 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                  @change="moveItemWithCommand(item, $event)"
                >
                  <option
                    v-for="stage in activePipeline.stages"
                    :key="stage.id"
                    :value="stage.id"
                  >
                    {{ stage.name }}
                  </option>
                </select>
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-panel-right-open"
                  :label="$t('PIPELINES_BOARD.DETAIL.ACTION')"
                  @click="openItemDetails(item)"
                />
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-history"
                  :label="$t('PIPELINES_BOARD.TIMELINE.ACTION')"
                  @click="toggleTimeline(item)"
                />
              </div>

              <ol
                v-if="expandedTimelineItems.includes(item.id)"
                class="flex flex-col gap-2 border-t border-n-weak pt-2"
              >
                <li
                  v-for="transition in timelines[item.id] || []"
                  :key="transition.id"
                  class="text-xs text-n-slate-11"
                >
                  <template v-if="transition.event_type === 'stage_transition'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.STAGE_EVENT', {
                        from: transition.from_stage.name,
                        to: transition.to_stage.name,
                        actor: timelineActor(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'conversation_linked'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.CONVERSATION_LINKED', {
                        id: timelineConversation(transition),
                        actor: timelineActor(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'conversation_unlinked'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.CONVERSATION_UNLINKED', {
                        id: timelineConversation(transition),
                        actor: timelineActor(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'automatic_item_created'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.AUTOMATIC_ITEM_CREATED', {
                        id: timelineConversation(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'conversation_deduplicated'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.CONVERSATION_DEDUPLICATED', {
                        id: timelineConversation(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'parallel_item_created'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.PARALLEL_ITEM_CREATED', {
                        id: timelineConversation(transition),
                        actor: timelineActor(transition),
                      })
                    }}
                  </template>
                  <template v-else-if="transition.event_type === 'ownership_changed'">
                    {{
                      $t('PIPELINES_BOARD.TIMELINE.OWNERSHIP_CHANGED', {
                        actor: timelineActor(transition),
                        from:
                          transition.ownership?.from_owner?.name ||
                          $t('PIPELINES_BOARD.FORM.UNASSIGNED'),
                        to:
                          transition.ownership?.to_owner?.name ||
                          $t('PIPELINES_BOARD.FORM.UNASSIGNED'),
                      })
                    }}
                  </template>
                  <template v-else>
                    {{
                      $t(
                        `PIPELINES_BOARD.TIMELINE.${transition.event_type.toUpperCase()}`,
                        {
                          title: transition.activity?.title,
                          actor: timelineActor(transition),
                        }
                      )
                    }}
                  </template>
                  <span class="block text-n-slate-9">
                    {{ formatTransitionTime(transition.created_at) }}
                  </span>
                </li>
                <li
                  v-if="timelines[item.id]?.length === 0"
                  class="text-xs text-n-slate-9"
                >
                  {{ $t('PIPELINES_BOARD.TIMELINE.EMPTY') }}
                </li>
              </ol>
            </article>
          </template>

          <template #footer>
            <p
              v-if="!column.items.length"
              class="mb-0 px-2 py-6 text-center text-xs text-n-slate-10"
            >
              {{ $t('PIPELINES_BOARD.EMPTY_STAGE') }}
            </p>
          </template>
        </Draggable>
      </section>
      </main>

      <PipelineItemTable
        v-else
        :items="visibleItems"
        :stages="activePipeline?.stages || []"
        :attention-mode="viewMode === 'attention'"
        @move="moveItemFromList"
        @open="openItemDetails"
      />
    </template>

    <Dialog
      ref="dialogRef"
      :title="$t('PIPELINES_BOARD.FORM.TITLE')"
      :description="$t('PIPELINES_BOARD.FORM.DESCRIPTION')"
      :confirm-button-label="$t('PIPELINES_BOARD.FORM.SUBMIT')"
      :disable-confirm-button="isCreateDisabled"
      :is-loading="isCreating"
      overflow-y-auto
      @confirm="createItem"
    >
      <div class="grid gap-4 sm:grid-cols-2">
        <Input
          v-model="form.title"
          class="sm:col-span-2"
          :label="$t('PIPELINES_BOARD.FORM.TITLE_LABEL')"
          :placeholder="$t('PIPELINES_BOARD.FORM.TITLE_PLACEHOLDER')"
        />

        <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.FORM.CONTACT_LABEL') }}
          <select
            v-model.number="form.contactId"
            class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          >
            <option disabled value="">
              {{ $t('PIPELINES_BOARD.FORM.CONTACT_PLACEHOLDER') }}
            </option>
            <option
              v-for="contact in contacts"
              :key="contact.id"
              :value="contact.id"
            >
              {{ contact.name || contact.email || contact.phone_number }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.FORM.STAGE_LABEL') }}
          <select
            v-model.number="form.stageId"
            class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          >
            <option
              v-for="stage in activePipeline?.stages || []"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.name }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.FORM.OWNER_LABEL') }}
          <select
            v-model.number="form.ownerId"
            class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          >
            <option value="">
              {{ $t('PIPELINES_BOARD.FORM.UNASSIGNED') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.available_name }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.FORM.TEAM_LABEL') }}
          <select
            v-model.number="form.teamId"
            class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          >
            <option value="">
              {{ $t('PIPELINES_BOARD.FORM.NO_TEAM') }}
            </option>
            <option v-for="team in teams" :key="team.id" :value="team.id">
              {{ team.name }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.FORM.PRIORITY_LABEL') }}
          <select
            v-model="form.priority"
            class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
          >
            <option
              v-for="option in priorityOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>

        <Input
          v-model="form.value"
          type="number"
          min="0"
          :label="$t('PIPELINES_BOARD.FORM.VALUE_LABEL')"
          :placeholder="$t('PIPELINES_BOARD.FORM.VALUE_PLACEHOLDER')"
        />

        <Input
          v-model="form.dueDate"
          type="date"
          class="sm:col-span-2"
          :label="$t('PIPELINES_BOARD.FORM.DUE_DATE_LABEL')"
        />
      </div>
    </Dialog>

    <PipelineItemDetails
      v-if="selectedItem"
      :item="selectedItem"
      :candidate-conversations="candidateConversations"
      :is-loading-candidates="isLoadingCandidates"
      :active-conversation-id="activeConversationId"
      :activities="activities"
      :is-loading-activities="isLoadingActivities"
      :agents="agents"
      :active-activity-id="activeActivityId"
      :active-activity-action="activeActivityAction"
      :field-definitions="activePipeline?.field_definitions || []"
      :required-field-keys="selectedRequiredFieldKeys"
      :is-saving-field-values="isSavingFieldValues"
      @close="closeItemDetails"
      @link-conversation="linkConversation"
      @unlink-conversation="unlinkConversation"
      @open-conversation="openConversation"
      @save-activity="saveActivity"
      @complete-activity="changeActivityStatus($event, 'complete')"
      @cancel-activity="changeActivityStatus($event, 'cancel')"
      @save-field-values="saveFieldValues"
    />
  </div>
</template>
