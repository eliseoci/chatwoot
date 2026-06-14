<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import AgentsAPI from 'dashboard/api/agents';
import ContactAPI from 'dashboard/api/contacts';
import PipelineItemsAPI from 'dashboard/api/pipelineItems';
import PipelinesAPI from 'dashboard/api/pipelines';
import TeamsAPI from 'dashboard/api/teams';
import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { buildPipelineItemPayload, groupItemsByStage } from './helpers/board';

const route = useRoute();
const router = useRouter();
const { locale, t } = useI18n();

const pipelines = ref([]);
const items = ref([]);
const contacts = ref([]);
const agents = ref([]);
const teams = ref([]);
const activePipelineId = ref(null);
const isLoading = ref(true);
const isCreating = ref(false);
const dialogRef = ref(null);

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

const columns = computed(() =>
  groupItemsByStage(activePipeline.value?.stages || [], items.value)
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

const loadItems = async () => {
  if (!activePipelineId.value) {
    items.value = [];
    return;
  }

  const response = await PipelineItemsAPI.get({
    pipelineId: activePipelineId.value,
  });
  items.value = response.data;
};

const loadBoard = async () => {
  isLoading.value = true;
  try {
    const [pipelinesResponse, contactsResponse, agentsResponse, teamsResponse] =
      await Promise.all([
        PipelinesAPI.get(),
        ContactAPI.get(1),
        AgentsAPI.get(),
        TeamsAPI.get(),
      ]);

    pipelines.value = pipelinesResponse.data;
    contacts.value = contactsResponse.data.payload;
    agents.value = agentsResponse.data;
    teams.value = teamsResponse.data;

    const routePipelineId = Number(route.params.pipelineId);
    activePipelineId.value =
      pipelines.value.find(pipeline => pipeline.id === routePipelineId)?.id ||
      pipelines.value[0]?.id ||
      null;

    await loadItems();
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
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
    items.value.unshift(response.data);
    dialogRef.value?.close();
    useAlert(t('PIPELINES_BOARD.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_BOARD.API.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const changePipeline = async () => {
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
      loadItems();
    }
  }
);

onMounted(loadBoard);
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

    <main v-else class="flex flex-1 gap-4 overflow-x-auto p-5">
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

        <div class="flex min-h-24 flex-col gap-2 rounded-xl bg-n-alpha-black2 p-2">
          <article
            v-for="item in column.items"
            :key="item.id"
            class="flex flex-col gap-3 rounded-lg bg-n-solid-1 p-3 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <div>
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
              v-if="item.owner || item.team"
              class="flex items-center gap-1.5 text-xs text-n-slate-10"
            >
              <Icon icon="i-lucide-user-round" class="size-3.5" />
              <span v-if="item.owner">{{ item.owner.name }}</span>
              <span v-if="item.owner && item.team">·</span>
              <span v-if="item.team">{{ item.team.name }}</span>
            </div>
          </article>

          <p
            v-if="!column.items.length"
            class="mb-0 px-2 py-6 text-center text-xs text-n-slate-10"
          >
            {{ $t('PIPELINES_BOARD.EMPTY_STAGE') }}
          </p>
        </div>
      </section>
    </main>

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
  </div>
</template>
