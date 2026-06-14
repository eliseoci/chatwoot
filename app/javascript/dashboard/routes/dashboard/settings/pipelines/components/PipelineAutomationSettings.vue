<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PipelineAutomationRulesAPI from 'dashboard/api/pipelineAutomationRules';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { buildAutomationRulePayload } from '../helpers/automationRuleForm';

const props = defineProps({
  pipelines: {
    type: Array,
    required: true,
  },
  agents: {
    type: Array,
    required: true,
  },
  teams: {
    type: Array,
    required: true,
  },
  labels: {
    type: Array,
    required: true,
  },
});

const { t } = useI18n();
const rules = ref([]);
const isLoading = ref(true);
const isSaving = ref(false);
const activeRuleId = ref(null);
const ACTION_TYPES = [
  'create_activity',
  'assign_owner',
  'assign_team',
  'update_field',
  'add_labels',
  'remove_labels',
  'send_internal_notification',
  'send_webhook',
  'update_attention',
];

const form = reactive({
  name: '',
  pipelineId: '',
  targetStageId: '',
  priority: '',
  actionType: 'create_activity',
  activityTitle: '',
  activityType: 'task',
  assigneeId: '',
  dueMode: 'relative',
  dueInMinutes: 60,
  dueAt: '',
  notes: '',
  ownerId: '',
  teamId: '',
  fieldKey: '',
  fieldValue: '',
  label: '',
  recipientId: '',
  notificationMessage: '',
  webhookUrl: '',
  webhookSecret: '',
  attentionState: 'required',
  attentionNote: '',
});

const selectedPipeline = computed(() =>
  props.pipelines.find(pipeline => pipeline.id === form.pipelineId)
);

const isCreateDisabled = computed(
  () =>
    !form.name.trim() ||
    !form.pipelineId ||
    !form.targetStageId ||
    !actionIsValid()
);

const actionIsValid = () => {
  switch (form.actionType) {
    case 'create_activity':
      return (
        form.activityTitle.trim() &&
        (form.dueMode === 'relative'
          ? Number(form.dueInMinutes) > 0
          : Boolean(form.dueAt))
      );
    case 'update_field':
      return Boolean(form.fieldKey);
    case 'add_labels':
    case 'remove_labels':
      return Boolean(form.label);
    case 'send_internal_notification':
      return Boolean(form.recipientId && form.notificationMessage.trim());
    case 'send_webhook':
      return Boolean(form.webhookUrl.trim() && form.webhookSecret.trim());
    case 'update_attention':
      return Boolean(form.attentionState);
    default:
      return true;
  }
};

const resetForm = () => {
  form.name = '';
  form.priority = '';
  form.actionType = 'create_activity';
  form.activityTitle = '';
  form.activityType = 'task';
  form.assigneeId = '';
  form.dueMode = 'relative';
  form.dueInMinutes = 60;
  form.dueAt = '';
  form.notes = '';
  form.ownerId = '';
  form.teamId = '';
  form.fieldKey = '';
  form.fieldValue = '';
  form.label = '';
  form.recipientId = '';
  form.notificationMessage = '';
  form.webhookUrl = '';
  form.webhookSecret = '';
  form.attentionState = 'required';
  form.attentionNote = '';
};

const loadRules = async () => {
  isLoading.value = true;
  try {
    const response = await PipelineAutomationRulesAPI.get();
    rules.value = response.data;
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const createRule = async () => {
  if (isCreateDisabled.value) return;

  isSaving.value = true;
  try {
    const response = await PipelineAutomationRulesAPI.create(
      buildAutomationRulePayload(form)
    );
    rules.value.push(response.data);
    resetForm();
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.CREATE_ERROR'));
  } finally {
    isSaving.value = false;
  }
};

const toggleRule = async rule => {
  activeRuleId.value = rule.id;
  try {
    const response = await PipelineAutomationRulesAPI.update(rule.id, {
      pipeline_automation_rule: {
        name: rule.name,
        pipeline_id: rule.pipeline_id,
        target_stage_id: rule.target_stage_id,
        enabled: !rule.enabled,
        trigger_type: rule.trigger_type,
      },
    });
    Object.assign(rule, response.data);
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.UPDATE_ERROR'));
  } finally {
    activeRuleId.value = null;
  }
};

const deleteRule = async rule => {
  activeRuleId.value = rule.id;
  try {
    await PipelineAutomationRulesAPI.delete(rule.id);
    rules.value = rules.value.filter(item => item.id !== rule.id);
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.AUTOMATIONS.API.DELETE_ERROR'));
  } finally {
    activeRuleId.value = null;
  }
};

const ruleDueLabel = action => {
  if (action.config.due_mode === 'relative') {
    return t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.RELATIVE_DUE', {
      minutes: action.config.due_in_minutes,
    });
  }

  return t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.FIXED_DUE', {
    date: new Intl.DateTimeFormat(undefined, {
      dateStyle: 'medium',
      timeStyle: 'short',
    }).format(new Date(action.config.due_at)),
  });
};

const actionSummary = rule => {
  const action = rule.actions[0];
  if (!action) return '';
  if (action.action_type === 'create_activity') {
    return t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.ACTIVITY_SUMMARY', {
      activity: action.config.title,
      due: ruleDueLabel(action),
    });
  }
  return t(
    `PIPELINES_SETTINGS.AUTOMATIONS.ACTIONS.${action.action_type.toUpperCase()}`
  );
};

const runStatusLabel = status =>
  t(`PIPELINES_SETTINGS.AUTOMATIONS.RUNS.STATUS.${status.toUpperCase()}`);

watch(
  () => props.pipelines,
  pipelines => {
    form.pipelineId ||= pipelines[0]?.id || '';
  },
  { immediate: true }
);

watch(
  selectedPipeline,
  pipeline => {
    form.targetStageId = pipeline?.stages[0]?.id || '';
    form.fieldKey = pipeline?.field_definitions?.[0]?.key || '';
  },
  { immediate: true }
);

onMounted(loadRules);
</script>

<template>
  <section class="flex flex-col gap-4 border-t border-n-weak pt-8">
    <div>
      <h2 class="text-heading-2 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.TITLE') }}
      </h2>
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.DESCRIPTION') }}
      </p>
    </div>

    <form
      class="grid gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak md:grid-cols-2"
      @submit.prevent="createRule"
    >
      <Input
        v-model="form.name"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.NAME')"
        :placeholder="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.NAME_PLACEHOLDER')"
      />

      <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.PIPELINE') }}
        <select
          v-model.number="form.pipelineId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
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

      <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.TARGET_STAGE') }}
        <select
          v-model.number="form.targetStageId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
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

      <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.PRIORITY') }}
        <select
          v-model="form.priority"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ANY_PRIORITY') }}
          </option>
          <option value="low">{{ $t('PIPELINES_BOARD.PRIORITY.LOW') }}</option>
          <option value="medium">
            {{ $t('PIPELINES_BOARD.PRIORITY.MEDIUM') }}
          </option>
          <option value="high">{{ $t('PIPELINES_BOARD.PRIORITY.HIGH') }}</option>
          <option value="urgent">
            {{ $t('PIPELINES_BOARD.PRIORITY.URGENT') }}
          </option>
        </select>
      </label>

      <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ACTION_TYPE') }}
        <select
          v-model="form.actionType"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option
            v-for="actionType in ACTION_TYPES"
            :key="actionType"
            :value="actionType"
          >
            {{
              $t(
                `PIPELINES_SETTINGS.AUTOMATIONS.ACTIONS.${actionType.toUpperCase()}`
              )
            }}
          </option>
        </select>
      </label>

      <Input
        v-if="form.actionType === 'create_activity'"
        v-model="form.activityTitle"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ACTIVITY_TITLE')"
        :placeholder="
          $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ACTIVITY_TITLE_PLACEHOLDER')
        "
      />

      <label
        v-if="form.actionType === 'create_activity'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ACTIVITY_TYPE') }}
        <select
          v-model="form.activityType"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option
            v-for="type in ['task', 'call', 'message', 'meeting', 'custom']"
            :key="type"
            :value="type"
          >
            {{ $t(`PIPELINES_BOARD.ACTIVITIES.TYPE.${type.toUpperCase()}`) }}
          </option>
        </select>
      </label>

      <label
        v-if="form.actionType === 'create_activity'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ASSIGNEE') }}
        <select
          v-model.number="form.assigneeId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="">
            {{ $t('PIPELINES_BOARD.ACTIVITIES.FORM.UNASSIGNED') }}
          </option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>

      <label
        v-if="form.actionType === 'create_activity'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.DUE_MODE') }}
        <select
          v-model="form.dueMode"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="relative">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.RELATIVE') }}
          </option>
          <option value="fixed">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.FIXED') }}
          </option>
        </select>
      </label>

      <Input
        v-if="
          form.actionType === 'create_activity' &&
          form.dueMode === 'relative'
        "
        v-model="form.dueInMinutes"
        type="number"
        min="1"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.DUE_IN_MINUTES')"
      />
      <label
        v-else-if="
          form.actionType === 'create_activity' && form.dueMode === 'fixed'
        "
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.DUE_AT') }}
        <input
          v-model="form.dueAt"
          type="datetime-local"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        />
      </label>

      <TextArea
        v-if="form.actionType === 'create_activity'"
        v-model="form.notes"
        class="md:col-span-2"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.NOTES')"
        :placeholder="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.NOTES_PLACEHOLDER')"
      />

      <label
        v-if="form.actionType === 'assign_owner'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.OWNER') }}
        <select
          v-model.number="form.ownerId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.CLEAR_ASSIGNMENT') }}
          </option>
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>

      <label
        v-if="form.actionType === 'assign_team'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.TEAM') }}
        <select
          v-model.number="form.teamId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.CLEAR_ASSIGNMENT') }}
          </option>
          <option v-for="team in teams" :key="team.id" :value="team.id">
            {{ team.name }}
          </option>
        </select>
      </label>

      <label
        v-if="form.actionType === 'update_field'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.FIELD') }}
        <select
          v-model="form.fieldKey"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option
            v-for="field in selectedPipeline?.field_definitions || []"
            :key="field.key"
            :value="field.key"
          >
            {{ field.label }}
          </option>
        </select>
      </label>

      <Input
        v-if="form.actionType === 'update_field'"
        v-model="form.fieldValue"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.FIELD_VALUE')"
      />

      <label
        v-if="['add_labels', 'remove_labels'].includes(form.actionType)"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.LABEL') }}
        <select
          v-model="form.label"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option v-for="label in labels" :key="label.id" :value="label.title">
            {{ label.title }}
          </option>
        </select>
      </label>

      <label
        v-if="form.actionType === 'send_internal_notification'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.RECIPIENT') }}
        <select
          v-model.number="form.recipientId"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option v-for="agent in agents" :key="agent.id" :value="agent.id">
            {{ agent.name }}
          </option>
        </select>
      </label>

      <TextArea
        v-if="form.actionType === 'send_internal_notification'"
        v-model="form.notificationMessage"
        class="md:col-span-2"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.NOTIFICATION_MESSAGE')"
      />

      <Input
        v-if="form.actionType === 'send_webhook'"
        v-model="form.webhookUrl"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.WEBHOOK_URL')"
        placeholder="https://"
      />

      <Input
        v-if="form.actionType === 'send_webhook'"
        v-model="form.webhookSecret"
        type="password"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.WEBHOOK_SECRET')"
      />

      <label
        v-if="form.actionType === 'update_attention'"
        class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
      >
        {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ATTENTION_STATE') }}
        <select
          v-model="form.attentionState"
          class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
        >
          <option value="required">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ATTENTION_REQUIRED') }}
          </option>
          <option value="cleared">
            {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ATTENTION_CLEARED') }}
          </option>
        </select>
      </label>

      <TextArea
        v-if="
          form.actionType === 'update_attention' &&
          form.attentionState === 'required'
        "
        v-model="form.attentionNote"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.ATTENTION_NOTE')"
      />

      <Button
        class="md:col-span-2"
        type="submit"
        icon="i-lucide-zap"
        :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.FORM.SUBMIT')"
        :disabled="isCreateDisabled"
        :is-loading="isSaving"
      />
    </form>

    <p
      v-if="isLoading"
      class="mb-0 rounded-xl border border-dashed border-n-weak px-5 py-8 text-center text-body-main text-n-slate-11"
    >
      {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.LOADING') }}
    </p>
    <p
      v-else-if="!rules.length"
      class="mb-0 rounded-xl border border-dashed border-n-weak px-5 py-8 text-center text-body-main text-n-slate-11"
    >
      {{ $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.EMPTY') }}
    </p>

    <article
      v-for="rule in rules"
      :key="rule.id"
      class="flex items-center justify-between gap-4 rounded-xl bg-n-solid-1 p-4 outline outline-1 -outline-offset-1 outline-n-weak"
    >
      <div class="min-w-0">
        <div class="flex items-center gap-2">
          <h3 class="truncate text-heading-3 text-n-slate-12">
            {{ rule.name }}
          </h3>
          <span
            class="rounded px-1.5 py-0.5 text-xs"
            :class="
              rule.enabled
                ? 'bg-n-teal-3 text-n-teal-11'
                : 'bg-n-alpha-black2 text-n-slate-10'
            "
          >
            {{
              rule.enabled
                ? $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.ACTIVE')
                : $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.PAUSED')
            }}
          </span>
        </div>
        <p class="mb-0 text-sm text-n-slate-10">
          {{
            $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.SUMMARY', {
              pipeline: rule.pipeline.name,
              stage: rule.target_stage.name,
              action: actionSummary(rule),
            })
          }}
        </p>
        <div
          v-if="rule.recent_runs?.length"
          class="mt-2 flex flex-wrap gap-2 text-xs text-n-slate-10"
        >
          <span
            v-for="run in rule.recent_runs.slice(0, 3)"
            :key="run.id"
            class="rounded bg-n-alpha-black2 px-2 py-1"
            :title="run.error_message || ''"
          >
            {{
              $t('PIPELINES_SETTINGS.AUTOMATIONS.RUNS.SUMMARY', {
                status: runStatusLabel(run.status),
                attempts: run.attempt_count,
              })
            }}
          </span>
        </div>
      </div>

      <div class="flex shrink-0 items-center gap-2">
        <Button
          variant="ghost"
          color="slate"
          size="xs"
          :icon="rule.enabled ? 'i-lucide-pause' : 'i-lucide-play'"
          :label="
            rule.enabled
              ? $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.PAUSE')
              : $t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.RESUME')
          "
          :is-loading="activeRuleId === rule.id"
          :disabled="activeRuleId !== null"
          @click="toggleRule(rule)"
        />
        <Button
          variant="ghost"
          color="ruby"
          size="xs"
          icon="i-lucide-trash-2"
          :label="$t('PIPELINES_SETTINGS.AUTOMATIONS.LIST.DELETE')"
          :disabled="activeRuleId !== null"
          @click="deleteRule(rule)"
        />
      </div>
    </article>
  </section>
</template>
