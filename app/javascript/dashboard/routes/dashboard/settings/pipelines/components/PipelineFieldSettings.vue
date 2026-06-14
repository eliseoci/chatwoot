<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import PipelineFieldDefinitionsAPI from 'dashboard/api/pipelineFieldDefinitions';
import PipelineStagesAPI from 'dashboard/api/pipelineStages';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import { buildFieldDefinitionPayload } from 'dashboard/routes/dashboard/pipelines/helpers/customFields';

const props = defineProps({
  pipeline: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['update:pipeline']);
const { t } = useI18n();
const isCreating = ref(false);
const activeDefinitionId = ref(null);
const activeStageId = ref(null);
const editingDefinitionId = ref(null);

const form = reactive({
  label: '',
  fieldType: 'text',
  choices: '',
  currency: 'USD',
});

const editForm = reactive({
  label: '',
  choices: '',
  currency: 'USD',
});

const fieldTypes = computed(() =>
  [
    'text',
    'number',
    'currency',
    'date',
    'boolean',
    'list',
    'link',
    'user_reference',
  ].map(value => ({
    value,
    label: t(`PIPELINES_SETTINGS.FIELDS.TYPES.${value.toUpperCase()}`),
  }))
);

const definitions = computed(() => props.pipeline.field_definitions || []);

const isCreateDisabled = computed(() => {
  if (!form.label.trim()) return true;
  if (form.fieldType === 'list') {
    return !form.choices
      .split('\n')
      .map(choice => choice.trim())
      .filter(Boolean).length;
  }
  if (form.fieldType === 'currency') {
    return !/^[a-z]{3}$/i.test(form.currency.trim());
  }
  return false;
});

const replacePipeline = changes => {
  emit('update:pipeline', { ...props.pipeline, ...changes });
};

const resetForm = () => {
  Object.assign(form, {
    label: '',
    fieldType: 'text',
    choices: '',
    currency: 'USD',
  });
};

const createDefinition = async () => {
  if (isCreateDisabled.value) return;

  isCreating.value = true;
  try {
    const response = await PipelineFieldDefinitionsAPI.create(
      props.pipeline.id,
      buildFieldDefinitionPayload(form)
    );
    replacePipeline({
      field_definitions: [...definitions.value, response.data],
    });
    resetForm();
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.CREATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.CREATE_ERROR'));
  } finally {
    isCreating.value = false;
  }
};

const startEditing = definition => {
  editingDefinitionId.value = definition.id;
  Object.assign(editForm, {
    label: definition.label,
    choices: (definition.settings?.choices || []).join('\n'),
    currency: definition.settings?.currency || 'USD',
  });
};

const updateDefinition = async definition => {
  activeDefinitionId.value = definition.id;
  try {
    const response = await PipelineFieldDefinitionsAPI.update(
      props.pipeline.id,
      definition.id,
      buildFieldDefinitionPayload({
        ...editForm,
        fieldType: definition.field_type,
      })
    );
    replacePipeline({
      field_definitions: definitions.value.map(item =>
        item.id === definition.id ? response.data : item
      ),
    });
    editingDefinitionId.value = null;
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.UPDATE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.UPDATE_ERROR'));
  } finally {
    activeDefinitionId.value = null;
  }
};

const archiveDefinition = async definition => {
  activeDefinitionId.value = definition.id;
  try {
    await PipelineFieldDefinitionsAPI.delete(props.pipeline.id, definition.id);
    replacePipeline({
      field_definitions: definitions.value.filter(item => item.id !== definition.id),
      stages: props.pipeline.stages.map(stage => ({
        ...stage,
        required_field_keys: (stage.required_field_keys || []).filter(
          key => key !== definition.key
        ),
      })),
    });
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.ARCHIVE_SUCCESS'));
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.ARCHIVE_ERROR'));
  } finally {
    activeDefinitionId.value = null;
  }
};

const moveDefinition = async (definition, direction) => {
  const currentIndex = definitions.value.findIndex(item => item.id === definition.id);
  const targetIndex = currentIndex + direction;
  if (targetIndex < 0 || targetIndex >= definitions.value.length) return;

  const reordered = [...definitions.value];
  [reordered[currentIndex], reordered[targetIndex]] = [
    reordered[targetIndex],
    reordered[currentIndex],
  ];
  activeDefinitionId.value = definition.id;
  try {
    const response = await PipelineFieldDefinitionsAPI.reorder(
      props.pipeline.id,
      reordered.map(item => item.id)
    );
    replacePipeline({ field_definitions: response.data });
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.REORDER_ERROR'));
  } finally {
    activeDefinitionId.value = null;
  }
};

const toggleRequirement = async (stage, fieldKey) => {
  const currentKeys = stage.required_field_keys || [];
  const requiredFieldKeys = currentKeys.includes(fieldKey)
    ? currentKeys.filter(key => key !== fieldKey)
    : [...currentKeys, fieldKey];
  activeStageId.value = stage.id;
  try {
    const response = await PipelineStagesAPI.updateRequirements(
      props.pipeline.id,
      stage.id,
      requiredFieldKeys
    );
    replacePipeline({
      stages: props.pipeline.stages.map(item =>
        item.id === stage.id
          ? { ...item, required_field_keys: response.data.required_field_keys }
          : item
      ),
    });
  } catch (error) {
    useAlert(t('PIPELINES_SETTINGS.FIELDS.API.REQUIREMENTS_ERROR'));
  } finally {
    activeStageId.value = null;
  }
};
</script>

<template>
  <section class="flex flex-col gap-4 border-t border-n-weak pt-5">
    <div>
      <h4 class="text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.FIELDS.TITLE') }}
      </h4>
      <p class="mb-0 text-sm text-n-slate-10">
        {{ $t('PIPELINES_SETTINGS.FIELDS.DESCRIPTION') }}
      </p>
    </div>

    <form
      class="grid gap-3 rounded-lg bg-n-alpha-black2 p-3 md:grid-cols-2"
      @submit.prevent="createDefinition"
    >
      <Input
        v-model="form.label"
        :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.LABEL')"
        :placeholder="$t('PIPELINES_SETTINGS.FIELDS.FORM.LABEL_PLACEHOLDER')"
      />
      <label class="flex flex-col gap-1 text-heading-3 text-n-slate-12">
        {{ $t('PIPELINES_SETTINGS.FIELDS.FORM.TYPE') }}
        <select
          v-model="form.fieldType"
          class="h-10 rounded-lg border-0 bg-n-solid-1 px-3 text-sm outline outline-1 -outline-offset-1 outline-n-weak"
        >
          <option v-for="type in fieldTypes" :key="type.value" :value="type.value">
            {{ type.label }}
          </option>
        </select>
      </label>
      <TextArea
        v-if="form.fieldType === 'list'"
        v-model="form.choices"
        class="md:col-span-2"
        :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.CHOICES')"
        :placeholder="$t('PIPELINES_SETTINGS.FIELDS.FORM.CHOICES_PLACEHOLDER')"
      />
      <Input
        v-if="form.fieldType === 'currency'"
        v-model="form.currency"
        :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.CURRENCY')"
        :placeholder="$t('PIPELINES_SETTINGS.FIELDS.FORM.CURRENCY_PLACEHOLDER')"
      />
      <Button
        class="md:col-span-2"
        type="submit"
        icon="i-lucide-plus"
        :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.ADD')"
        :disabled="isCreateDisabled"
        :is-loading="isCreating"
      />
    </form>

    <p v-if="!definitions.length" class="mb-0 text-sm text-n-slate-10">
      {{ $t('PIPELINES_SETTINGS.FIELDS.EMPTY') }}
    </p>

    <div v-for="(definition, index) in definitions" :key="definition.id">
      <form
        v-if="editingDefinitionId === definition.id"
        class="grid gap-3 rounded-lg bg-n-alpha-black2 p-3 md:grid-cols-2"
        @submit.prevent="updateDefinition(definition)"
      >
        <Input
          v-model="editForm.label"
          :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.LABEL')"
        />
        <p class="mb-0 self-end pb-2 text-sm text-n-slate-10">
          {{ $t(`PIPELINES_SETTINGS.FIELDS.TYPES.${definition.field_type.toUpperCase()}`) }}
        </p>
        <TextArea
          v-if="definition.field_type === 'list'"
          v-model="editForm.choices"
          class="md:col-span-2"
          :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.CHOICES')"
        />
        <Input
          v-if="definition.field_type === 'currency'"
          v-model="editForm.currency"
          :label="$t('PIPELINES_SETTINGS.FIELDS.FORM.CURRENCY')"
        />
        <div class="flex gap-2 md:col-span-2">
          <Button
            type="submit"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.SAVE')"
            :is-loading="activeDefinitionId === definition.id"
          />
          <Button
            variant="ghost"
            color="slate"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.CANCEL')"
            @click="editingDefinitionId = null"
          />
        </div>
      </form>

      <div
        v-else
        class="flex items-center justify-between gap-3 rounded-lg bg-n-alpha-black2 p-3"
      >
        <div class="min-w-0">
          <p class="mb-0 truncate font-medium text-n-slate-12">
            {{ definition.label }}
          </p>
          <p class="mb-0 text-xs text-n-slate-10">
            {{
              $t(
                `PIPELINES_SETTINGS.FIELDS.TYPES.${definition.field_type.toUpperCase()}`
              )
            }}
          </p>
        </div>
        <div class="flex shrink-0 gap-1">
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-arrow-up"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.MOVE_UP')"
            :disabled="index === 0 || activeDefinitionId !== null"
            @click="moveDefinition(definition, -1)"
          />
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-arrow-down"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.MOVE_DOWN')"
            :disabled="index === definitions.length - 1 || activeDefinitionId !== null"
            @click="moveDefinition(definition, 1)"
          />
          <Button
            variant="ghost"
            color="slate"
            size="xs"
            icon="i-lucide-pencil"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.EDIT')"
            @click="startEditing(definition)"
          />
          <Button
            variant="ghost"
            color="ruby"
            size="xs"
            icon="i-lucide-archive"
            :label="$t('PIPELINES_SETTINGS.FIELDS.ACTIONS.ARCHIVE')"
            :disabled="activeDefinitionId !== null"
            @click="archiveDefinition(definition)"
          />
        </div>
      </div>
    </div>

    <div v-if="definitions.length" class="flex flex-col gap-3">
      <div>
        <h4 class="text-heading-3 text-n-slate-12">
          {{ $t('PIPELINES_SETTINGS.FIELDS.REQUIREMENTS.TITLE') }}
        </h4>
        <p class="mb-0 text-sm text-n-slate-10">
          {{ $t('PIPELINES_SETTINGS.FIELDS.REQUIREMENTS.DESCRIPTION') }}
        </p>
      </div>
      <div
        v-for="stage in pipeline.stages"
        :key="stage.id"
        class="rounded-lg bg-n-alpha-black2 p-3"
      >
        <p class="mb-2 font-medium text-n-slate-12">{{ stage.name }}</p>
        <div class="flex flex-wrap gap-2">
          <label
            v-for="definition in definitions"
            :key="definition.id"
            class="flex items-center gap-2 rounded-md bg-n-solid-1 px-2.5 py-1.5 text-sm text-n-slate-11"
          >
            <input
              type="checkbox"
              :checked="(stage.required_field_keys || []).includes(definition.key)"
              :disabled="activeStageId !== null"
              @change="toggleRequirement(stage, definition.key)"
            />
            {{ definition.label }}
          </label>
        </div>
      </div>
    </div>
  </section>
</template>
