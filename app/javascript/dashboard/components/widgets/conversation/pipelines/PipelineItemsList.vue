<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import AgentsAPI from 'dashboard/api/agents';
import PipelineActivitiesAPI from 'dashboard/api/pipelineActivities';
import PipelineItemsAPI from 'dashboard/api/pipelineItems';
import PipelinesAPI from 'dashboard/api/pipelines';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { buildPipelineActivityPayload } from 'dashboard/routes/dashboard/pipelines/helpers/activities';
import { buildPipelineItemPayload } from 'dashboard/routes/dashboard/pipelines/helpers/board';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  contactId: {
    type: Number,
    required: true,
  },
});

const { locale, t } = useI18n();
const pipelines = ref([]);
const agents = ref([]);
const linkedItems = ref([]);
const compatibleItems = ref([]);
const isLoading = ref(false);
const activeItemId = ref(null);
const permissionDenied = ref(false);
const loadFailed = ref(false);
const showCreateForm = ref(false);
const activityItemId = ref(null);

const createForm = reactive({
  pipelineId: '',
  stageId: '',
  title: '',
  ownerId: '',
});

const activityForm = reactive({
  activityType: 'task',
  title: '',
  dueAt: '',
  assigneeId: '',
  notes: '',
});

const selectedPipeline = computed(() =>
  pipelines.value.find(pipeline => pipeline.id === createForm.pipelineId)
);

const linkCandidates = computed(() => {
  const linkedIds = new Set(linkedItems.value.map(item => item.id));
  return compatibleItems.value.filter(item => !linkedIds.has(item.id));
});

const pipelineFor = item =>
  pipelines.value.find(pipeline => pipeline.id === item.pipeline_id);

const stageFor = item =>
  pipelineFor(item)?.stages.find(stage => stage.id === item.stage_id);

const formatActivityTime = value =>
  new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));

const isPermissionError = error =>
  [401, 403].includes(error?.response?.status);

const handleError = (error, fallbackKey) => {
  if (isPermissionError(error)) {
    permissionDenied.value = true;
    return;
  }
  useAlert(t(fallbackKey));
};

const loadItems = async () => {
  const [linkedResponse, compatibleResponse] = await Promise.all([
    PipelineItemsAPI.get({ conversationId: props.conversationId }),
    PipelineItemsAPI.get({ contactId: props.contactId }),
  ]);
  linkedItems.value = linkedResponse.data;
  compatibleItems.value = compatibleResponse.data;
};

const loadContext = async () => {
  if (!props.contactId) return;

  isLoading.value = true;
  permissionDenied.value = false;
  loadFailed.value = false;
  try {
    const [pipelinesResponse, agentsResponse] = await Promise.all([
      PipelinesAPI.get(),
      AgentsAPI.get(),
    ]);
    pipelines.value = pipelinesResponse.data;
    agents.value = agentsResponse.data;
    await loadItems();
    createForm.pipelineId = pipelines.value[0]?.id || '';
  } catch (error) {
    if (isPermissionError(error)) {
      permissionDenied.value = true;
    } else {
      loadFailed.value = true;
    }
  } finally {
    isLoading.value = false;
  }
};

const resetCreateForm = () => {
  Object.assign(createForm, {
    pipelineId: pipelines.value[0]?.id || '',
    stageId: pipelines.value[0]?.stages[0]?.id || '',
    title: '',
    ownerId: '',
  });
};

const createItem = async () => {
  activeItemId.value = 0;
  try {
    await PipelineItemsAPI.create(
      buildPipelineItemPayload({
        pipelineId: createForm.pipelineId,
        stageId: createForm.stageId,
        contactId: props.contactId,
        ownerId: createForm.ownerId,
        teamId: '',
        title: createForm.title,
        priority: '',
        value: '',
        dueDate: '',
        conversationId: props.conversationId,
      })
    );
    await loadItems();
    showCreateForm.value = false;
    resetCreateForm();
    useAlert(t('PIPELINES_SIDEBAR.API.CREATE_SUCCESS'));
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.CREATE_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

const linkItem = async item => {
  activeItemId.value = item.id;
  try {
    await PipelineItemsAPI.linkConversation(item.id, {
      conversationId: props.conversationId,
      source: 'conversation_sidebar',
    });
    await loadItems();
    useAlert(t('PIPELINES_SIDEBAR.API.LINK_SUCCESS'));
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.LINK_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

const unlinkItem = async item => {
  activeItemId.value = item.id;
  try {
    await PipelineItemsAPI.unlinkConversation(item.id, {
      conversationId: props.conversationId,
      source: 'conversation_sidebar',
    });
    await loadItems();
    useAlert(t('PIPELINES_SIDEBAR.API.UNLINK_SUCCESS'));
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.UNLINK_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

const changeStage = async (item, stageId) => {
  activeItemId.value = item.id;
  try {
    const response = await PipelineItemsAPI.transition(item.id, {
      stageId: Number(stageId),
      source: 'conversation_sidebar',
    });
    Object.assign(item, response.data);
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.STAGE_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

const changeOwner = async (item, ownerId) => {
  activeItemId.value = item.id;
  try {
    const response = await PipelineItemsAPI.updateOwnership(item.id, {
      ownerId: ownerId ? Number(ownerId) : null,
      source: 'conversation_sidebar',
    });
    Object.assign(item, response.data);
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.OWNER_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

const openActivityForm = item => {
  activityItemId.value = item.id;
  Object.assign(activityForm, {
    activityType: 'task',
    title: '',
    dueAt: '',
    assigneeId: item.owner?.id || '',
    notes: '',
  });
};

const scheduleActivity = async item => {
  activeItemId.value = item.id;
  try {
    const response = await PipelineActivitiesAPI.create(
      item.id,
      buildPipelineActivityPayload({
        ...activityForm,
        source: 'conversation_sidebar',
      })
    );
    item.next_activity = response.data;
    activityItemId.value = null;
    useAlert(t('PIPELINES_SIDEBAR.API.ACTIVITY_SUCCESS'));
  } catch (error) {
    handleError(error, 'PIPELINES_SIDEBAR.API.ACTIVITY_ERROR');
  } finally {
    activeItemId.value = null;
  }
};

watch(
  selectedPipeline,
  pipeline => {
    createForm.stageId = pipeline?.stages[0]?.id || '';
  },
  { immediate: true }
);

watch(
  () => props.conversationId,
  loadContext
);

onMounted(loadContext);
</script>

<template>
  <div class="flex flex-col gap-3 p-3">
    <div v-if="isLoading" class="flex justify-center py-6">
      <Spinner />
    </div>

    <div
      v-else-if="permissionDenied"
      class="rounded-lg bg-n-ruby-2 p-3 text-sm text-n-ruby-11"
    >
      {{ $t('PIPELINES_SIDEBAR.PERMISSION_DENIED') }}
    </div>

    <div
      v-else-if="loadFailed"
      class="flex flex-col items-start gap-2 rounded-lg bg-n-alpha-black2 p-3"
    >
      <p class="mb-0 text-sm text-n-slate-11">
        {{ $t('PIPELINES_SIDEBAR.LOAD_ERROR') }}
      </p>
      <Button
        variant="ghost"
        color="slate"
        size="xs"
        :label="$t('PIPELINES_SIDEBAR.RETRY')"
        @click="loadContext"
      />
    </div>

    <template v-else>
      <div class="flex flex-wrap gap-2">
        <Button
          v-if="pipelines.length"
          size="xs"
          icon="i-lucide-plus"
          :label="$t('PIPELINES_SIDEBAR.CREATE_ACTION')"
          @click="
            resetCreateForm();
            showCreateForm = !showCreateForm;
          "
        />
      </div>

      <p class="mb-0 text-xs text-n-slate-9">
        {{ $t('PIPELINES_SIDEBAR.STATUS_SEPARATION') }}
      </p>

      <div
        v-if="!pipelines.length"
        class="rounded-lg border border-dashed border-n-weak p-4 text-center"
      >
        <Icon
          icon="i-lucide-panels-top-left"
          class="mx-auto mb-2 size-5 text-n-slate-9"
        />
        <p class="mb-0 text-sm text-n-slate-10">
          {{ $t('PIPELINES_SIDEBAR.NO_PIPELINES') }}
        </p>
      </div>

      <form
        v-if="showCreateForm"
        class="flex flex-col gap-3 rounded-lg bg-n-alpha-black2 p-3"
        @submit.prevent="createItem"
      >
        <label class="flex flex-col gap-1 text-xs font-medium text-n-slate-11">
          {{ $t('PIPELINES_SIDEBAR.FORM.PIPELINE') }}
          <select
            v-model.number="createForm.pipelineId"
            class="h-8 rounded-md border-0 bg-n-solid-1 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <option
              v-for="pipeline in pipelines"
              :key="pipeline.id"
              :value="pipeline.id"
            >
              {{ pipeline.name }}
            </option>
          </select>
        </label>
        <label class="flex flex-col gap-1 text-xs font-medium text-n-slate-11">
          {{ $t('PIPELINES_SIDEBAR.FORM.STAGE') }}
          <select
            v-model.number="createForm.stageId"
            class="h-8 rounded-md border-0 bg-n-solid-1 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <option
              v-for="stage in selectedPipeline?.stages || []"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.name }}
            </option>
          </select>
        </label>
        <Input
          v-model="createForm.title"
          :label="$t('PIPELINES_SIDEBAR.FORM.TITLE')"
          :placeholder="$t('PIPELINES_SIDEBAR.FORM.TITLE_PLACEHOLDER')"
        />
        <label class="flex flex-col gap-1 text-xs font-medium text-n-slate-11">
          {{ $t('PIPELINES_SIDEBAR.FORM.OWNER') }}
          <select
            v-model.number="createForm.ownerId"
            class="h-8 rounded-md border-0 bg-n-solid-1 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <option value="">
              {{ $t('PIPELINES_SIDEBAR.UNASSIGNED') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.available_name }}
            </option>
          </select>
        </label>
        <Button
          type="submit"
          size="xs"
          :label="$t('PIPELINES_SIDEBAR.FORM.CREATE')"
          :disabled="!createForm.pipelineId || !createForm.stageId"
          :is-loading="activeItemId === 0"
        />
      </form>

      <div
        v-if="pipelines.length && !linkedItems.length"
        class="rounded-lg border border-dashed border-n-weak p-4 text-center"
      >
        <Icon
          icon="i-lucide-panels-top-left"
          class="mx-auto mb-2 size-5 text-n-slate-9"
        />
        <p class="mb-0 text-sm text-n-slate-10">
          {{ $t('PIPELINES_SIDEBAR.EMPTY') }}
        </p>
      </div>

      <article
        v-for="item in linkedItems"
        :key="item.id"
        class="flex flex-col gap-3 rounded-lg bg-n-alpha-black2 p-3"
      >
        <div class="flex items-start justify-between gap-2">
          <div class="min-w-0">
            <p class="mb-0 truncate text-sm font-medium text-n-slate-12">
              {{ item.display_title }}
            </p>
            <p class="mb-0 text-xs text-n-slate-9">
              {{
                $t('PIPELINES_SIDEBAR.PIPELINE_STAGE', {
                  pipeline: pipelineFor(item)?.name,
                  stage: stageFor(item)?.name,
                })
              }}
            </p>
          </div>
          <Button
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-unlink"
            :aria-label="$t('PIPELINES_SIDEBAR.UNLINK')"
            :is-loading="activeItemId === item.id"
            :disabled="activeItemId !== null"
            @click="unlinkItem(item)"
          />
        </div>

        <label class="flex flex-col gap-1 text-xs text-n-slate-10">
          {{ $t('PIPELINES_SIDEBAR.STAGE_LABEL') }}
          <select
            :value="item.stage_id"
            class="h-8 rounded-md border-0 bg-n-solid-1 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
            :disabled="activeItemId !== null"
            @change="changeStage(item, $event.target.value)"
          >
            <option
              v-for="stage in pipelineFor(item)?.stages || []"
              :key="stage.id"
              :value="stage.id"
            >
              {{ stage.name }}
            </option>
          </select>
        </label>

        <label class="flex flex-col gap-1 text-xs text-n-slate-10">
          {{ $t('PIPELINES_SIDEBAR.OWNER_LABEL') }}
          <select
            :value="item.owner?.id || ''"
            class="h-8 rounded-md border-0 bg-n-solid-1 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
            :disabled="activeItemId !== null"
            @change="changeOwner(item, $event.target.value)"
          >
            <option value="">
              {{ $t('PIPELINES_SIDEBAR.UNASSIGNED') }}
            </option>
            <option v-for="agent in agents" :key="agent.id" :value="agent.id">
              {{ agent.available_name }}
            </option>
          </select>
        </label>

        <div
          v-if="item.next_activity"
          class="rounded-md bg-n-solid-1 p-2 text-xs text-n-slate-11"
        >
          <p class="mb-0 font-medium text-n-slate-12">
            {{ item.next_activity.title }}
          </p>
          <p class="mb-0">
            {{
              $t('PIPELINES_SIDEBAR.NEXT_ACTIVITY', {
                date: formatActivityTime(item.next_activity.due_at),
              })
            }}
          </p>
        </div>

        <Button
          v-if="activityItemId !== item.id"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-calendar-plus"
          :label="$t('PIPELINES_SIDEBAR.ACTIVITY_ACTION')"
          @click="openActivityForm(item)"
        />

        <form
          v-else
          class="flex flex-col gap-2 rounded-md bg-n-solid-1 p-2"
          @submit.prevent="scheduleActivity(item)"
        >
          <Input
            v-model="activityForm.title"
            :label="$t('PIPELINES_SIDEBAR.ACTIVITY.TITLE')"
            :placeholder="$t('PIPELINES_SIDEBAR.ACTIVITY.TITLE_PLACEHOLDER')"
          />
          <label class="flex flex-col gap-1 text-xs text-n-slate-10">
            {{ $t('PIPELINES_SIDEBAR.ACTIVITY.DUE_AT') }}
            <input
              v-model="activityForm.dueAt"
              type="datetime-local"
              class="h-8 rounded-md border-0 bg-n-alpha-black2 px-2 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
            />
          </label>
          <div class="flex gap-2">
            <Button
              type="submit"
              size="xs"
              :label="$t('PIPELINES_SIDEBAR.ACTIVITY.SCHEDULE')"
              :disabled="!activityForm.title.trim() || !activityForm.dueAt"
              :is-loading="activeItemId === item.id"
            />
            <Button
              variant="ghost"
              color="slate"
              size="xs"
              :label="$t('PIPELINES_SIDEBAR.CANCEL')"
              @click="activityItemId = null"
            />
          </div>
        </form>
      </article>

      <div v-if="linkCandidates.length" class="flex flex-col gap-2">
        <p class="mb-0 text-xs font-medium text-n-slate-10">
          {{ $t('PIPELINES_SIDEBAR.LINK_TITLE') }}
        </p>
        <div
          v-for="item in linkCandidates"
          :key="item.id"
          class="flex items-center justify-between gap-2 rounded-lg border border-n-weak p-2"
        >
          <div class="min-w-0">
            <p class="mb-0 truncate text-sm text-n-slate-12">
              {{ item.display_title }}
            </p>
            <p class="mb-0 text-xs text-n-slate-9">
              {{ pipelineFor(item)?.name }} · {{ stageFor(item)?.name }}
            </p>
          </div>
          <Button
            variant="ghost"
            color="blue"
            size="xs"
            icon="i-lucide-link"
            :label="$t('PIPELINES_SIDEBAR.LINK')"
            :is-loading="activeItemId === item.id"
            :disabled="activeItemId !== null"
            @click="linkItem(item)"
          />
        </div>
      </div>
    </template>
  </div>
</template>
