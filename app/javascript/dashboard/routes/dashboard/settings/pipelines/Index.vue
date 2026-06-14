<script setup>
import { computed, onMounted, reactive, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import InboxesAPI from 'dashboard/api/inboxes';
import PipelineIntakeRulesAPI from 'dashboard/api/pipelineIntakeRules';
import PipelinesAPI from 'dashboard/api/pipelines';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import PipelineFieldSettings from './components/PipelineFieldSettings.vue';
import { buildIntakeRulePayload } from './helpers/intakeRuleForm';
import { buildPipelinePayload } from './helpers/pipelineForm';

const { t } = useI18n();
const pipelines = ref([]);
const templates = ref([]);
const intakeRules = ref([]);
const inboxes = ref([]);
const isLoading = ref(true);
const isCreating = ref(false);
const isSavingRule = ref(false);
const activeRuleId = ref(null);

const form = reactive({
  name: '',
  description: '',
  templateKey: 'sales',
  customStages: '',
});

const ruleForm = reactive({
  pipelineId: '',
  initialStageId: '',
  inboxId: '',
  channelType: '',
});

const selectedTemplate = computed(() =>
  templates.value.find(template => template.key === form.templateKey)
);

const customStageNames = computed(() =>
  form.customStages
    .split('\n')
    .map(stage => stage.trim())
    .filter(Boolean)
);

const isCreateDisabled = computed(
  () =>
    !form.name.trim() ||
    !form.templateKey ||
    (form.templateKey === 'custom' && !customStageNames.value.length)
);

const selectedRulePipeline = computed(() =>
  pipelines.value.find(pipeline => pipeline.id === ruleForm.pipelineId)
);

const channelTypes = computed(() =>
  [...new Set(inboxes.value.map(inbox => inbox.channel_type))].sort()
);

const isRuleCreateDisabled = computed(
  () => !ruleForm.pipelineId || !ruleForm.initialStageId
);

const channelLabel = channelType => {
  const channel = channelType?.replace('Channel::', '').toUpperCase();
  const key = `PIPELINES_SETTINGS.INTAKE.CHANNEL.${channel}`;
  const translated = t(key);
  return translated === key ? t('PIPELINES_SETTINGS.INTAKE.CHANNEL.OTHER') : translated;
};

const ruleEligibility = rule => {
  if (rule.inbox && rule.channel_type) {
    return t('PIPELINES_SETTINGS.INTAKE.LIST.INBOX_AND_CHANNEL', {
      inbox: rule.inbox.name,
      channel: channelLabel(rule.channel_type),
    });
  }
  if (rule.inbox) {
    return t('PIPELINES_SETTINGS.INTAKE.LIST.INBOX_ONLY', {
      inbox: rule.inbox.name,
    });
  }
  if (rule.channel_type) {
    return t('PIPELINES_SETTINGS.INTAKE.LIST.CHANNEL_ONLY', {
      channel: channelLabel(rule.channel_type),
    });
  }
  return t('PIPELINES_SETTINGS.INTAKE.LIST.ALL_CONVERSATIONS');
};

const resetForm = () => {
  form.name = '';
  form.description = '';
  form.templateKey = 'sales';
  form.customStages = '';
};

const loadPipelines = async () => {
  isLoading.value = true;
  try {
    const [
      pipelinesResponse,
      templatesResponse,
      rulesResponse,
      inboxesResponse,
    ] = await Promise.all([
      PipelinesAPI.get(),
      PipelinesAPI.getTemplates(),
      PipelineIntakeRulesAPI.get(),
      InboxesAPI.get(),
    ]);
    pipelines.value = pipelinesResponse.data;
    templates.value = templatesResponse.data;
    intakeRules.value = rulesResponse.data;
    inboxes.value = inboxesResponse.data.payload;
    ruleForm.pipelineId = pipelines.value[0]?.id || '';
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.LOAD_ERROR'));
  } finally {
    isLoading.value = false;
  }
};

const createPipeline = async () => {
  if (isCreateDisabled.value) return;

  isCreating.value = true;
  try {
    const response = await PipelinesAPI.create(
      buildPipelinePayload({
        name: form.name,
        description: form.description,
        templateKey: form.templateKey,
        customStages: form.customStages,
      })
    );
    pipelines.value.push(response.data);
    pipelines.value.sort((left, right) => left.name.localeCompare(right.name));
    ruleForm.pipelineId ||= response.data.id;
    resetForm();
    useAlert(t('PIPELINES_SETTINGS.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const createIntakeRule = async () => {
  if (isRuleCreateDisabled.value) return;

  isSavingRule.value = true;
  try {
    const response = await PipelineIntakeRulesAPI.create(
      buildIntakeRulePayload({
        ...ruleForm,
        position: intakeRules.value.length,
      })
    );
    intakeRules.value.push(response.data);
    ruleForm.inboxId = '';
    ruleForm.channelType = '';
    useAlert(t('PIPELINES_SETTINGS.API.RULE_CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.RULE_CREATE_ERROR'));
  } finally {
    isSavingRule.value = false;
  }
};

const toggleIntakeRule = async rule => {
  activeRuleId.value = rule.id;
  try {
    const response = await PipelineIntakeRulesAPI.update(
      rule.id,
      buildIntakeRulePayload({
        pipelineId: rule.pipeline_id,
        initialStageId: rule.initial_stage_id,
        inboxId: rule.inbox_id,
        channelType: rule.channel_type,
        enabled: !rule.enabled,
        position: rule.position,
      })
    );
    Object.assign(rule, response.data);
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.RULE_UPDATE_ERROR'));
  } finally {
    activeRuleId.value = null;
  }
};

const deleteIntakeRule = async rule => {
  activeRuleId.value = rule.id;
  try {
    await PipelineIntakeRulesAPI.delete(rule.id);
    intakeRules.value = intakeRules.value.filter(item => item.id !== rule.id);
    useAlert(t('PIPELINES_SETTINGS.API.RULE_DELETE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.RULE_DELETE_ERROR'));
  } finally {
    activeRuleId.value = null;
  }
};

const updatePipeline = updatedPipeline => {
  pipelines.value = pipelines.value.map(pipeline =>
    pipeline.id === updatedPipeline.id ? updatedPipeline : pipeline
  );
};

watch(
  selectedRulePipeline,
  pipeline => {
    ruleForm.initialStageId = pipeline?.stages[0]?.id || '';
  },
  { immediate: true }
);

onMounted(loadPipelines);
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :loading-message="$t('PIPELINES_SETTINGS.LOADING')"
    :no-records-found="false"
  >
    <template #header>
      <BaseSettingsHeader
        :title="$t('PIPELINES_SETTINGS.HEADER')"
        :description="$t('PIPELINES_SETTINGS.DESCRIPTION')"
      />
    </template>

    <template #body>
      <div class="grid gap-8 xl:grid-cols-[minmax(18rem,24rem)_minmax(0,1fr)]">
        <form
          class="flex flex-col gap-4 self-start rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak"
          @submit.prevent="createPipeline"
        >
          <div class="flex flex-col gap-1">
            <h2 class="text-heading-2 text-n-slate-12">
              {{ $t('PIPELINES_SETTINGS.FORM.TITLE') }}
            </h2>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{ $t('PIPELINES_SETTINGS.FORM.DESCRIPTION') }}
            </p>
          </div>

          <Input
            v-model="form.name"
            :label="$t('PIPELINES_SETTINGS.FORM.NAME_LABEL')"
            :placeholder="$t('PIPELINES_SETTINGS.FORM.NAME_PLACEHOLDER')"
          />

          <TextArea
            v-model="form.description"
            :label="$t('PIPELINES_SETTINGS.FORM.DESCRIPTION_LABEL')"
            :placeholder="
              $t('PIPELINES_SETTINGS.FORM.DESCRIPTION_PLACEHOLDER')
            "
          />

          <label
            for="pipeline-template"
            class="flex flex-col gap-1 text-heading-3 text-n-slate-12"
          >
            {{ $t('PIPELINES_SETTINGS.FORM.TEMPLATE_LABEL') }}
            <select
              id="pipeline-template"
              v-model="form.templateKey"
              class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
            >
              <option
                v-for="template in templates"
                :key="template.key"
                :value="template.key"
              >
                {{ template.name }}
              </option>
            </select>
          </label>

          <p
            v-if="selectedTemplate"
            class="mb-0 text-body-main text-n-slate-11"
          >
            {{ selectedTemplate.description }}
          </p>

          <TextArea
            v-if="form.templateKey === 'custom'"
            v-model="form.customStages"
            :label="$t('PIPELINES_SETTINGS.FORM.CUSTOM_STAGES_LABEL')"
            :placeholder="
              $t('PIPELINES_SETTINGS.FORM.CUSTOM_STAGES_PLACEHOLDER')
            "
            :max-length="2000"
          />

          <Button
            type="submit"
            :label="$t('PIPELINES_SETTINGS.FORM.SUBMIT')"
            :disabled="isCreateDisabled"
            :is-loading="isCreating"
          />
        </form>

        <section class="flex min-w-0 flex-col gap-4">
          <div>
            <h2 class="text-heading-2 text-n-slate-12">
              {{ $t('PIPELINES_SETTINGS.LIST.TITLE') }}
            </h2>
            <p class="mb-0 text-body-main text-n-slate-11">
              {{ $t('PIPELINES_SETTINGS.LIST.DESCRIPTION') }}
            </p>
          </div>

          <div
            v-if="!pipelines.length"
            class="rounded-xl border border-dashed border-n-weak px-5 py-12 text-center text-body-main text-n-slate-11"
          >
            {{ $t('PIPELINES_SETTINGS.LIST.EMPTY') }}
          </div>

          <article
            v-for="pipeline in pipelines"
            :key="pipeline.id"
            class="flex flex-col gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <div class="flex items-start gap-3">
              <span
                class="flex size-9 shrink-0 items-center justify-center rounded-lg bg-n-blue-3 text-n-blue-11"
              >
                <Icon icon="i-lucide-columns-3" class="size-4" />
              </span>
              <div class="min-w-0">
                <h3 class="truncate text-heading-3 text-n-slate-12">
                  {{ pipeline.name }}
                </h3>
                <p v-if="pipeline.description" class="mb-0 text-sm text-n-slate-11">
                  {{ pipeline.description }}
                </p>
              </div>
            </div>

            <ol class="flex flex-wrap items-center gap-2">
              <li
                v-for="stage in pipeline.stages"
                :key="stage.id"
                class="flex items-center gap-1.5 rounded-lg bg-n-alpha-black2 px-2.5 py-1.5 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak"
              >
                <span class="size-2 rounded-full bg-n-slate-8" />
                <span>{{ stage.name }}</span>
                <span
                  v-if="stage.terminal"
                  class="rounded bg-n-teal-3 px-1.5 py-0.5 text-xs text-n-teal-11"
                >
                  {{ $t('PIPELINES_SETTINGS.LIST.TERMINAL') }}
                </span>
              </li>
            </ol>

            <PipelineFieldSettings
              :pipeline="pipeline"
              @update:pipeline="updatePipeline"
            />
          </article>

          <div class="mt-4 border-t border-n-weak pt-8">
            <div>
              <h2 class="text-heading-2 text-n-slate-12">
                {{ $t('PIPELINES_SETTINGS.INTAKE.TITLE') }}
              </h2>
              <p class="mb-0 text-body-main text-n-slate-11">
                {{ $t('PIPELINES_SETTINGS.INTAKE.DESCRIPTION') }}
              </p>
            </div>
          </div>

          <form
            class="grid gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak md:grid-cols-2"
            @submit.prevent="createIntakeRule"
          >
            <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
              {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.PIPELINE') }}
              <select
                v-model.number="ruleForm.pipelineId"
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
              {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.INITIAL_STAGE') }}
              <select
                v-model.number="ruleForm.initialStageId"
                class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
              >
                <option
                  v-for="stage in selectedRulePipeline?.stages || []"
                  :key="stage.id"
                  :value="stage.id"
                >
                  {{ stage.name }}
                </option>
              </select>
            </label>

            <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
              {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.INBOX') }}
              <select
                v-model.number="ruleForm.inboxId"
                class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
              >
                <option value="">
                  {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.ANY_INBOX') }}
                </option>
                <option
                  v-for="inbox in inboxes"
                  :key="inbox.id"
                  :value="inbox.id"
                >
                  {{ inbox.name }}
                </option>
              </select>
            </label>

            <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
              {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.CHANNEL') }}
              <select
                v-model="ruleForm.channelType"
                class="h-10 rounded-lg border-0 bg-n-alpha-black2 px-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak focus:outline-n-brand"
              >
                <option value="">
                  {{ $t('PIPELINES_SETTINGS.INTAKE.FORM.ANY_CHANNEL') }}
                </option>
                <option
                  v-for="channelType in channelTypes"
                  :key="channelType"
                  :value="channelType"
                >
                  {{ channelLabel(channelType) }}
                </option>
              </select>
            </label>

            <Button
              class="md:col-span-2"
              type="submit"
              icon="i-lucide-workflow"
              :label="$t('PIPELINES_SETTINGS.INTAKE.FORM.SUBMIT')"
              :disabled="isRuleCreateDisabled"
              :is-loading="isSavingRule"
            />
          </form>

          <div
            v-if="!intakeRules.length"
            class="rounded-xl border border-dashed border-n-weak px-5 py-8 text-center text-body-main text-n-slate-11"
          >
            {{ $t('PIPELINES_SETTINGS.INTAKE.LIST.EMPTY') }}
          </div>

          <article
            v-for="rule in intakeRules"
            :key="rule.id"
            class="flex items-center justify-between gap-4 rounded-xl bg-n-solid-1 p-4 outline outline-1 -outline-offset-1 outline-n-weak"
          >
            <div class="min-w-0">
              <div class="flex items-center gap-2">
                <h3 class="truncate text-heading-3 text-n-slate-12">
                  {{
                    $t('PIPELINES_SETTINGS.INTAKE.LIST.DESTINATION', {
                      pipeline: rule.pipeline.name,
                      stage: rule.initial_stage.name,
                    })
                  }}
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
                      ? $t('PIPELINES_SETTINGS.INTAKE.LIST.ACTIVE')
                      : $t('PIPELINES_SETTINGS.INTAKE.LIST.PAUSED')
                  }}
                </span>
              </div>
              <p class="mb-0 text-sm text-n-slate-10">
                {{ ruleEligibility(rule) }}
              </p>
            </div>

            <div class="flex shrink-0 items-center gap-2">
              <Button
                variant="ghost"
                color="slate"
                size="xs"
                :icon="rule.enabled ? 'i-lucide-pause' : 'i-lucide-play'"
                :label="
                  rule.enabled
                    ? $t('PIPELINES_SETTINGS.INTAKE.LIST.PAUSE')
                    : $t('PIPELINES_SETTINGS.INTAKE.LIST.RESUME')
                "
                :is-loading="activeRuleId === rule.id"
                :disabled="activeRuleId !== null"
                @click="toggleIntakeRule(rule)"
              />
              <Button
                variant="ghost"
                color="ruby"
                size="xs"
                icon="i-lucide-trash-2"
                :label="$t('PIPELINES_SETTINGS.INTAKE.LIST.DELETE')"
                :disabled="activeRuleId !== null"
                @click="deleteIntakeRule(rule)"
              />
            </div>
          </article>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
