<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import PipelinesAPI from 'dashboard/api/pipelines';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SettingsLayout from '../SettingsLayout.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { buildPipelinePayload } from './helpers/pipelineForm';

const { t } = useI18n();
const pipelines = ref([]);
const templates = ref([]);
const isLoading = ref(true);
const isCreating = ref(false);

const form = reactive({
  name: '',
  description: '',
  templateKey: 'sales',
  customStages: '',
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

const resetForm = () => {
  form.name = '';
  form.description = '';
  form.templateKey = 'sales';
  form.customStages = '';
};

const loadPipelines = async () => {
  isLoading.value = true;
  try {
    const [pipelinesResponse, templatesResponse] = await Promise.all([
      PipelinesAPI.get(),
      PipelinesAPI.getTemplates(),
    ]);
    pipelines.value = pipelinesResponse.data;
    templates.value = templatesResponse.data;
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
    resetForm();
    useAlert(t('PIPELINES_SETTINGS.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.API.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

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
          </article>
        </section>
      </div>
    </template>
  </SettingsLayout>
</template>
