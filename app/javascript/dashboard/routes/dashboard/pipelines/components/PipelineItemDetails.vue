<script setup>
import {
  computed,
  nextTick,
  onBeforeUnmount,
  onMounted,
  reactive,
  ref,
  watch,
} from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { initializeFieldValues } from '../helpers/customFields';

const props = defineProps({
  item: {
    type: Object,
    required: true,
  },
  candidateConversations: {
    type: Array,
    default: () => [],
  },
  isLoadingCandidates: {
    type: Boolean,
    default: false,
  },
  activeConversationId: {
    type: Number,
    default: null,
  },
  activities: {
    type: Array,
    default: () => [],
  },
  isLoadingActivities: {
    type: Boolean,
    default: false,
  },
  agents: {
    type: Array,
    default: () => [],
  },
  activeActivityId: {
    type: Number,
    default: null,
  },
  activeActivityAction: {
    type: String,
    default: null,
  },
  fieldDefinitions: {
    type: Array,
    default: () => [],
  },
  requiredFieldKeys: {
    type: Array,
    default: () => [],
  },
  isSavingFieldValues: {
    type: Boolean,
    default: false,
  },
  canEdit: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits([
  'close',
  'link-conversation',
  'unlink-conversation',
  'open-conversation',
  'save-activity',
  'complete-activity',
  'cancel-activity',
  'save-field-values',
]);

const { locale, t } = useI18n();
const closeButtonRef = ref(null);
const selectedConversationId = ref('');
const editingActivityId = ref(null);
const activityForm = reactive({
  activityType: 'task',
  title: '',
  dueAt: '',
  assigneeId: '',
  notes: '',
});
const fieldForm = reactive({});

const linkedConversationIds = computed(
  () =>
    new Set(
      (props.item.linked_conversations || []).map(conversation => conversation.id)
    )
);

const availableConversations = computed(() =>
  props.candidateConversations.filter(
    conversation => !linkedConversationIds.value.has(conversation.id)
  )
);

const isActivityFormValid = computed(
  () => activityForm.title.trim() && activityForm.dueAt
);

const activityTypes = computed(() =>
  ['task', 'call', 'message', 'meeting', 'custom'].map(value => ({
    value,
    label: t(`PIPELINES_BOARD.ACTIVITIES.TYPE.${value.toUpperCase()}`),
  }))
);

const statusLabel = status =>
  t(`PIPELINES_BOARD.DETAIL.CONVERSATION_STATUS.${status.toUpperCase()}`);

const channelLabel = channelType => {
  const channel = channelType?.replace('Channel::', '').toUpperCase();
  const key = `PIPELINES_BOARD.DETAIL.CHANNEL.${channel}`;
  const translated = t(key);
  return translated === key ? t('PIPELINES_BOARD.DETAIL.CHANNEL.OTHER') : translated;
};

const candidateChannel = conversation =>
  conversation.meta?.channel || conversation.inbox?.channel_type;

const candidateLabel = conversation =>
  t('PIPELINES_BOARD.DETAIL.LINK.CANDIDATE_OPTION', {
    id: conversation.id,
    channel: channelLabel(candidateChannel(conversation)),
    status: statusLabel(conversation.status),
  });

const formatLastActivity = value => {
  if (!value) return t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.NO_ACTIVITY');

  const parsedValue =
    typeof value === 'number' ? new Date(value * 1000) : new Date(value);

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(parsedValue);
};

const formatActivityTime = value =>
  new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

const activityTypeLabel = value =>
  t(`PIPELINES_BOARD.ACTIVITIES.TYPE.${value.toUpperCase()}`);

const activityStatusLabel = value =>
  t(`PIPELINES_BOARD.ACTIVITIES.STATUS.${value.toUpperCase()}`);

const storedFieldValue = definition =>
  props.item.field_values?.[definition.key];

const hasStoredFieldValue = definition => {
  const value = storedFieldValue(definition);
  return value !== null && value !== undefined && value !== '';
};

const formatStoredFieldValue = definition => {
  const value = storedFieldValue(definition);
  if (definition.field_type === 'number') {
    return new Intl.NumberFormat(locale.value).format(Number(value));
  }
  if (definition.field_type === 'currency') {
    return new Intl.NumberFormat(locale.value, {
      style: 'currency',
      currency: definition.settings.currency,
    }).format(Number(value));
  }
  if (definition.field_type === 'date') {
    return new Intl.DateTimeFormat(locale.value, {
      dateStyle: 'medium',
    }).format(new Date(`${value}T00:00:00`));
  }
  if (definition.field_type === 'boolean') {
    return t(
      value
        ? 'PIPELINES_BOARD.FIELDS.BOOLEAN_YES'
        : 'PIPELINES_BOARD.FIELDS.BOOLEAN_NO'
    );
  }
  if (definition.field_type === 'user_reference') {
    return (
      props.agents.find(agent => agent.id === Number(value))?.available_name ||
      t('PIPELINES_BOARD.FIELDS.USER_UNAVAILABLE')
    );
  }
  return value;
};

const toLocalInputValue = value => {
  if (!value) return '';
  const date = new Date(value);
  const localDate = new Date(date.getTime() - date.getTimezoneOffset() * 60000);
  return localDate.toISOString().slice(0, 16);
};

const resetActivityForm = () => {
  editingActivityId.value = null;
  Object.assign(activityForm, {
    activityType: 'task',
    title: '',
    dueAt: '',
    assigneeId: '',
    notes: '',
  });
};

const editActivity = activity => {
  editingActivityId.value = activity.id;
  Object.assign(activityForm, {
    activityType: activity.activity_type,
    title: activity.title,
    dueAt: toLocalInputValue(activity.due_at),
    assigneeId: activity.assignee?.id || '',
    notes: activity.notes || '',
  });
};

const saveActivity = () => {
  if (!isActivityFormValid.value) return;
  emit('save-activity', {
    id: editingActivityId.value,
    ...activityForm,
  });
};

const resetFieldForm = () => {
  Object.keys(fieldForm).forEach(key => delete fieldForm[key]);
  Object.assign(
    fieldForm,
    initializeFieldValues(props.fieldDefinitions, props.item.field_values)
  );
};

const saveFieldValues = () => {
  emit('save-field-values', { ...fieldForm });
};

const submitLink = () => {
  if (!selectedConversationId.value) return;
  emit('link-conversation', Number(selectedConversationId.value));
};

const handleKeydown = event => {
  if (event.key === 'Escape') emit('close');
};

watch(
  () => props.item.id,
  () => {
    selectedConversationId.value = '';
    resetActivityForm();
    resetFieldForm();
  }
);

watch(
  () =>
    props.fieldDefinitions
      .map(definition => `${definition.id}:${definition.updated_at}`)
      .join(','),
  resetFieldForm
);

watch(() => props.item.field_values, resetFieldForm, { deep: true });

watch(
  () =>
    props.activities
      .map(activity => `${activity.id}:${activity.updated_at}`)
      .join(','),
  resetActivityForm
);

watch(
  () => props.item.linked_conversations?.length || 0,
  () => {
    selectedConversationId.value = '';
  }
);

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
  resetFieldForm();
  nextTick(() => closeButtonRef.value?.$el?.focus());
});

onBeforeUnmount(() => document.removeEventListener('keydown', handleKeydown));
</script>

<template>
  <Teleport to="body">
    <div
      class="fixed inset-0 z-50 flex justify-end bg-n-alpha-black1 backdrop-blur-[2px]"
    >
      <button
        type="button"
        class="absolute inset-0 cursor-default"
        :aria-label="$t('PIPELINES_BOARD.DETAIL.CLOSE')"
        @click="emit('close')"
      />
      <aside
        class="relative z-10 flex h-full w-full max-w-lg flex-col bg-n-solid-1 shadow-xl outline outline-1 -outline-offset-1 outline-n-weak"
        role="dialog"
        aria-modal="true"
        :aria-label="$t('PIPELINES_BOARD.DETAIL.ARIA_LABEL')"
      >
        <header
          class="flex items-start justify-between gap-4 border-b border-n-weak px-5 py-4"
        >
          <div class="min-w-0">
            <p class="mb-1 text-xs font-medium uppercase tracking-wide text-n-slate-9">
              {{ $t('PIPELINES_BOARD.DETAIL.EYEBROW') }}
            </p>
            <h2 class="truncate text-heading-2 text-n-slate-12">
              {{ item.display_title }}
            </h2>
            <p class="mb-0 text-sm text-n-slate-11">
              {{ item.contact.name || item.contact.email || item.contact.phone_number }}
            </p>
          </div>
          <Button
            ref="closeButtonRef"
            variant="ghost"
            color="slate"
            size="sm"
            icon="i-lucide-x"
            :aria-label="$t('PIPELINES_BOARD.DETAIL.CLOSE')"
            @click="emit('close')"
          />
        </header>

        <div class="flex flex-1 flex-col gap-6 overflow-y-auto p-5">
          <section v-if="fieldDefinitions.length" class="flex flex-col gap-3">
            <div>
              <h3 class="text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.FIELDS.TITLE') }}
              </h3>
              <p class="mb-0 text-sm text-n-slate-10">
                {{ $t('PIPELINES_BOARD.FIELDS.DESCRIPTION') }}
              </p>
            </div>

            <form
              class="grid gap-3 rounded-xl bg-n-alpha-black2 p-4 sm:grid-cols-2"
              :class="{ 'opacity-70': !canEdit }"
              :inert="!canEdit"
              @submit.prevent="saveFieldValues"
            >
              <div
                v-for="definition in fieldDefinitions"
                :key="definition.id"
                class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
                :class="{ 'sm:col-span-2': definition.field_type === 'text' }"
              >
                <label
                  :for="`pipeline-field-${definition.id}`"
                  class="flex items-center gap-2"
                >
                  {{ definition.label }}
                  <span
                    v-if="requiredFieldKeys.includes(definition.key)"
                    class="rounded bg-n-amber-3 px-1.5 py-0.5 text-xs text-n-amber-11"
                  >
                    {{ $t('PIPELINES_BOARD.FIELDS.REQUIRED') }}
                  </span>
                </label>

                <input
                  v-if="definition.field_type === 'text'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model="fieldForm[definition.key]"
                  type="text"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                />
                <input
                  v-else-if="
                    definition.field_type === 'number' ||
                    definition.field_type === 'currency'
                  "
                  v-model="fieldForm[definition.key]"
                  :id="`pipeline-field-${definition.id}`"
                  type="number"
                  step="any"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                />
                <span
                  v-if="definition.field_type === 'currency'"
                  class="text-xs font-normal text-n-slate-9"
                >
                  {{
                    $t('PIPELINES_BOARD.FIELDS.CURRENCY_HINT', {
                      currency: definition.settings.currency,
                    })
                  }}
                </span>
                <input
                  v-else-if="definition.field_type === 'date'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model="fieldForm[definition.key]"
                  type="date"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                />
                <select
                  v-else-if="definition.field_type === 'boolean'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model="fieldForm[definition.key]"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                >
                  <option value="">
                    {{ $t('PIPELINES_BOARD.FIELDS.SELECT_PLACEHOLDER') }}
                  </option>
                  <option :value="true">
                    {{ $t('PIPELINES_BOARD.FIELDS.BOOLEAN_YES') }}
                  </option>
                  <option :value="false">
                    {{ $t('PIPELINES_BOARD.FIELDS.BOOLEAN_NO') }}
                  </option>
                </select>
                <select
                  v-else-if="definition.field_type === 'list'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model="fieldForm[definition.key]"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                >
                  <option value="">
                    {{ $t('PIPELINES_BOARD.FIELDS.SELECT_PLACEHOLDER') }}
                  </option>
                  <option
                    v-for="choice in definition.settings.choices"
                    :key="choice"
                    :value="choice"
                  >
                    {{ choice }}
                  </option>
                </select>
                <input
                  v-else-if="definition.field_type === 'link'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model="fieldForm[definition.key]"
                  type="url"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                  :placeholder="$t('PIPELINES_BOARD.FIELDS.LINK_PLACEHOLDER')"
                />
                <select
                  v-else-if="definition.field_type === 'user_reference'"
                  :id="`pipeline-field-${definition.id}`"
                  v-model.number="fieldForm[definition.key]"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm font-normal outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                >
                  <option value="">
                    {{ $t('PIPELINES_BOARD.FIELDS.USER_PLACEHOLDER') }}
                  </option>
                  <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                    {{ agent.available_name }}
                  </option>
                </select>
                <span
                  v-if="hasStoredFieldValue(definition)"
                  class="text-xs font-normal text-n-slate-9"
                >
                  {{
                    $t('PIPELINES_BOARD.FIELDS.CURRENT_VALUE', {
                      value: formatStoredFieldValue(definition),
                    })
                  }}
                </span>
              </div>

              <Button
                class="sm:col-span-2"
                type="submit"
                size="sm"
                icon="i-lucide-save"
                :label="$t('PIPELINES_BOARD.FIELDS.SAVE')"
                :is-loading="isSavingFieldValues"
                :disabled="isSavingFieldValues"
              />
            </form>
          </section>

          <section class="flex flex-col gap-3">
            <div>
              <h3 class="text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.ACTIVITIES.TITLE') }}
              </h3>
              <p class="mb-0 text-sm text-n-slate-10">
                {{ $t('PIPELINES_BOARD.ACTIVITIES.DESCRIPTION') }}
              </p>
            </div>

            <form
              class="grid gap-3 rounded-xl bg-n-alpha-black2 p-4 sm:grid-cols-2"
              :class="{ 'opacity-70': !canEdit }"
              :inert="!canEdit"
              @submit.prevent="saveActivity"
            >
              <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.ACTIVITIES.FORM.TYPE') }}
                <select
                  v-model="activityForm.activityType"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                >
                  <option
                    v-for="type in activityTypes"
                    :key="type.value"
                    :value="type.value"
                  >
                    {{ type.label }}
                  </option>
                </select>
              </label>

              <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.ACTIVITIES.FORM.DUE_AT') }}
                <input
                  v-model="activityForm.dueAt"
                  type="datetime-local"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                />
              </label>

              <Input
                v-model="activityForm.title"
                class="sm:col-span-2"
                :label="$t('PIPELINES_BOARD.ACTIVITIES.FORM.TITLE')"
                :placeholder="
                  $t('PIPELINES_BOARD.ACTIVITIES.FORM.TITLE_PLACEHOLDER')
                "
              />

              <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.ACTIVITIES.FORM.ASSIGNEE') }}
                <select
                  v-model.number="activityForm.assigneeId"
                  class="h-9 rounded-lg border-0 bg-n-solid-1 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                >
                  <option value="">
                    {{ $t('PIPELINES_BOARD.ACTIVITIES.FORM.UNASSIGNED') }}
                  </option>
                  <option v-for="agent in agents" :key="agent.id" :value="agent.id">
                    {{ agent.available_name }}
                  </option>
                </select>
              </label>

              <TextArea
                v-model="activityForm.notes"
                :label="$t('PIPELINES_BOARD.ACTIVITIES.FORM.NOTES')"
                :placeholder="
                  $t('PIPELINES_BOARD.ACTIVITIES.FORM.NOTES_PLACEHOLDER')
                "
              />

              <div class="flex gap-2 sm:col-span-2">
                <Button
                  type="submit"
                  size="sm"
                  icon="i-lucide-calendar-plus"
                  :label="
                    editingActivityId
                      ? $t('PIPELINES_BOARD.ACTIVITIES.FORM.SAVE')
                      : $t('PIPELINES_BOARD.ACTIVITIES.FORM.ADD')
                  "
                  :disabled="
                    !isActivityFormValid ||
                    isLoadingActivities ||
                    activeActivityId !== null
                  "
                  :is-loading="
                    activeActivityAction === 'save' &&
                    activeActivityId === (editingActivityId || 0)
                  "
                />
                <Button
                  v-if="editingActivityId"
                  variant="ghost"
                  color="slate"
                  size="sm"
                  :label="$t('PIPELINES_BOARD.ACTIVITIES.FORM.DISCARD')"
                  :disabled="activeActivityId !== null"
                  @click="resetActivityForm"
                />
              </div>
            </form>

            <div
              v-if="isLoadingActivities"
              class="rounded-xl border border-dashed border-n-weak px-4 py-6 text-center text-sm text-n-slate-10"
            >
              {{ $t('PIPELINES_BOARD.ACTIVITIES.LOADING') }}
            </div>

            <div
              v-else-if="!activities.length"
              class="rounded-xl border border-dashed border-n-weak px-4 py-6 text-center text-sm text-n-slate-10"
            >
              {{ $t('PIPELINES_BOARD.ACTIVITIES.EMPTY') }}
            </div>

            <article
              v-for="activity in activities"
              :key="activity.id"
              class="flex flex-col gap-3 rounded-xl p-4 outline outline-1 -outline-offset-1"
              :class="
                activity.overdue
                  ? 'bg-n-ruby-2 outline-n-ruby-6'
                  : 'bg-n-alpha-black2 outline-n-weak'
              "
            >
              <div class="flex items-start justify-between gap-3">
                <div class="min-w-0">
                  <div class="flex flex-wrap items-center gap-2">
                    <span class="text-xs font-medium text-n-slate-10">
                      {{ activityTypeLabel(activity.activity_type) }}
                    </span>
                    <span
                      v-if="activity.overdue"
                      class="rounded bg-n-ruby-3 px-1.5 py-0.5 text-xs text-n-ruby-11"
                    >
                      {{ $t('PIPELINES_BOARD.ACTIVITIES.OVERDUE') }}
                    </span>
                    <span
                      v-else-if="activity.status !== 'scheduled'"
                      class="rounded bg-n-alpha-black2 px-1.5 py-0.5 text-xs text-n-slate-10"
                    >
                      {{ activityStatusLabel(activity.status) }}
                    </span>
                  </div>
                  <h4 class="mt-1 text-sm font-medium text-n-slate-12">
                    {{ activity.title }}
                  </h4>
                  <p class="mb-0 text-xs text-n-slate-10">
                    {{
                      $t('PIPELINES_BOARD.ACTIVITIES.DUE', {
                        date: formatActivityTime(activity.due_at),
                      })
                    }}
                  </p>
                  <p v-if="activity.assignee" class="mb-0 text-xs text-n-slate-10">
                    {{
                      $t('PIPELINES_BOARD.ACTIVITIES.ASSIGNED_TO', {
                        name: activity.assignee.name,
                      })
                    }}
                  </p>
                  <p v-if="activity.notes" class="mb-0 mt-2 text-sm text-n-slate-11">
                    {{ activity.notes }}
                  </p>
                </div>
              </div>

              <div
                v-if="activity.status === 'scheduled' && canEdit"
                class="flex flex-wrap gap-2 border-t border-n-weak pt-3"
              >
                <Button
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-pencil"
                  :label="$t('PIPELINES_BOARD.ACTIVITIES.EDIT')"
                  :disabled="activeActivityId !== null"
                  @click="editActivity(activity)"
                />
                <Button
                  variant="ghost"
                  color="teal"
                  size="xs"
                  icon="i-lucide-check"
                  :label="$t('PIPELINES_BOARD.ACTIVITIES.COMPLETE')"
                  :is-loading="
                    activeActivityAction === 'complete' &&
                    activeActivityId === activity.id
                  "
                  :disabled="activeActivityId !== null"
                  @click="emit('complete-activity', activity.id)"
                />
                <Button
                  variant="ghost"
                  color="ruby"
                  size="xs"
                  icon="i-lucide-x"
                  :label="$t('PIPELINES_BOARD.ACTIVITIES.CANCEL')"
                  :is-loading="
                    activeActivityAction === 'cancel' &&
                    activeActivityId === activity.id
                  "
                  :disabled="activeActivityId !== null"
                  @click="emit('cancel-activity', activity.id)"
                />
              </div>
            </article>
          </section>

          <section class="flex flex-col gap-3">
            <div>
              <h3 class="text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.DETAIL.LINK.TITLE') }}
              </h3>
              <p class="mb-0 text-sm text-n-slate-10">
                {{ $t('PIPELINES_BOARD.DETAIL.LINK.DESCRIPTION') }}
              </p>
            </div>

            <div class="flex gap-2">
              <select
                v-model="selectedConversationId"
                :aria-label="$t('PIPELINES_BOARD.DETAIL.LINK.SELECT_LABEL')"
                class="h-9 min-w-0 flex-1 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
                :disabled="
                  !canEdit || isLoadingCandidates || !availableConversations.length
                "
              >
                <option disabled value="">
                  {{
                    isLoadingCandidates
                      ? $t('PIPELINES_BOARD.DETAIL.LINK.LOADING')
                      : $t('PIPELINES_BOARD.DETAIL.LINK.PLACEHOLDER')
                  }}
                </option>
                <option
                  v-for="conversation in availableConversations"
                  :key="conversation.id"
                  :value="conversation.id"
                >
                  {{ candidateLabel(conversation) }}
                </option>
              </select>
              <Button
                size="sm"
                icon="i-lucide-link"
                :label="$t('PIPELINES_BOARD.DETAIL.LINK.ACTION')"
                :disabled="
                  !canEdit ||
                  !selectedConversationId ||
                  activeConversationId !== null
                "
                :is-loading="activeConversationId === Number(selectedConversationId)"
                @click="submitLink"
              />
            </div>

            <p
              v-if="!isLoadingCandidates && !availableConversations.length"
              class="mb-0 text-xs text-n-slate-9"
            >
              {{ $t('PIPELINES_BOARD.DETAIL.LINK.EMPTY') }}
            </p>
          </section>

          <section class="flex flex-col gap-3">
            <div class="flex items-center justify-between">
              <h3 class="text-heading-3 text-n-slate-12">
                {{ $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.TITLE') }}
              </h3>
              <span class="text-xs text-n-slate-9">
                {{ item.linked_conversations.length }}
              </span>
            </div>

            <div
              v-if="!item.linked_conversations.length"
              class="flex flex-col items-center gap-2 rounded-xl bg-n-alpha-black2 px-4 py-8 text-center"
            >
              <Icon icon="i-lucide-messages-square" class="size-5 text-n-slate-9" />
              <p class="mb-0 text-sm text-n-slate-10">
                {{ $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.EMPTY') }}
              </p>
            </div>

            <article
              v-for="conversation in item.linked_conversations"
              :key="conversation.id"
              class="flex flex-col gap-3 rounded-xl bg-n-alpha-black2 p-4 outline outline-1 -outline-offset-1 outline-n-weak"
            >
              <div class="flex items-start justify-between gap-3">
                <div class="flex min-w-0 items-start gap-3">
                  <span
                    class="flex size-8 shrink-0 items-center justify-center rounded-lg bg-n-blue-3 text-n-blue-11"
                  >
                    <Icon icon="i-lucide-message-square" class="size-4" />
                  </span>
                  <div class="min-w-0">
                    <p class="mb-0 text-sm font-medium text-n-slate-12">
                      {{
                        $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.CONVERSATION_ID', {
                          id: conversation.id,
                        })
                      }}
                    </p>
                    <p class="mb-0 truncate text-xs text-n-slate-10">
                      {{
                        $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.CHANNEL_INBOX', {
                          channel: channelLabel(conversation.inbox.channel_type),
                          inbox: conversation.inbox.name,
                        })
                      }}
                    </p>
                  </div>
                </div>
                <span
                  class="rounded-md bg-n-alpha-black2 px-2 py-1 text-xs text-n-slate-11"
                >
                  {{ statusLabel(conversation.status) }}
                </span>
              </div>

              <dl class="grid grid-cols-2 gap-3 text-xs">
                <div>
                  <dt class="text-n-slate-9">
                    {{ $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.ASSIGNEE') }}
                  </dt>
                  <dd class="text-n-slate-11">
                    {{
                      conversation.assignee?.name ||
                      $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.UNASSIGNED')
                    }}
                  </dd>
                </div>
                <div>
                  <dt class="text-n-slate-9">
                    {{ $t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.LAST_ACTIVITY') }}
                  </dt>
                  <dd class="text-n-slate-11">
                    {{ formatLastActivity(conversation.last_activity_at) }}
                  </dd>
                </div>
              </dl>

              <div class="flex items-center justify-between border-t border-n-weak pt-3">
                <Button
                  v-if="canEdit"
                  variant="ghost"
                  color="slate"
                  size="xs"
                  icon="i-lucide-unlink"
                  :label="$t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.UNLINK')"
                  :is-loading="activeConversationId === conversation.id"
                  :disabled="activeConversationId !== null"
                  @click="emit('unlink-conversation', conversation.id)"
                />
                <Button
                  variant="ghost"
                  color="blue"
                  size="xs"
                  icon="i-lucide-external-link"
                  :label="$t('PIPELINES_BOARD.DETAIL.CONVERSATIONS.OPEN')"
                  @click="emit('open-conversation', conversation.id)"
                />
              </div>
            </article>
          </section>
        </div>
      </aside>
    </div>
  </Teleport>
</template>
