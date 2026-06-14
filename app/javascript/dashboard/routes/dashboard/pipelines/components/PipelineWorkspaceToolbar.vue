<script setup>
import { computed } from 'vue';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  viewMode: {
    type: String,
    required: true,
  },
  filters: {
    type: Object,
    required: true,
  },
  stages: {
    type: Array,
    default: () => [],
  },
  agents: {
    type: Array,
    default: () => [],
  },
  teams: {
    type: Array,
    default: () => [],
  },
  inboxes: {
    type: Array,
    default: () => [],
  },
  labels: {
    type: Array,
    default: () => [],
  },
  channels: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['update:viewMode', 'update:filters', 'clear']);

const modes = [
  { value: 'kanban', icon: 'i-lucide-columns-3' },
  { value: 'list', icon: 'i-lucide-list' },
  { value: 'attention', icon: 'i-lucide-circle-alert' },
];

const hasActiveFilters = computed(() =>
  Object.entries(props.filters).some(([key, value]) =>
    key === 'sort' ? value !== 'recent' : Boolean(value)
  )
);

const updateFilter = (key, value) => {
  emit('update:filters', {
    ...props.filters,
    [key]: value,
  });
};
</script>

<template>
  <div class="flex flex-col gap-3 border-b border-n-weak px-5 py-3">
    <div class="flex flex-wrap items-center gap-2">
      <div
        class="flex rounded-lg bg-n-alpha-black2 p-1"
        :aria-label="$t('PIPELINES_BOARD.VIEWS.LABEL')"
        role="group"
      >
        <button
          v-for="mode in modes"
          :key="mode.value"
          type="button"
          class="flex h-8 items-center gap-1.5 rounded-md px-2.5 text-xs font-medium"
          :class="
            viewMode === mode.value
              ? 'bg-n-solid-1 text-n-slate-12 shadow-sm'
              : 'text-n-slate-10 hover:text-n-slate-12'
          "
          :aria-pressed="viewMode === mode.value"
          @click="$emit('update:viewMode', mode.value)"
        >
          <Icon :icon="mode.icon" class="size-3.5" />
          {{ $t(`PIPELINES_BOARD.VIEWS.${mode.value.toUpperCase()}`) }}
        </button>
      </div>

      <label class="relative min-w-56 flex-1">
        <span class="sr-only">
          {{ $t('PIPELINES_BOARD.FILTERS.SEARCH_LABEL') }}
        </span>
        <Icon
          icon="i-lucide-search"
          class="pointer-events-none absolute left-2.5 top-2.5 size-4 text-n-slate-9"
        />
        <input
          :value="filters.q"
          type="search"
          class="h-9 w-full rounded-lg border-0 bg-n-alpha-black2 pl-9 pr-3 text-sm text-n-slate-12 outline outline-1 -outline-offset-1 outline-n-weak placeholder:text-n-slate-9 focus:outline-n-brand"
          :placeholder="$t('PIPELINES_BOARD.FILTERS.SEARCH_PLACEHOLDER')"
          @input="updateFilter('q', $event.target.value)"
        />
      </label>

      <Button
        v-if="hasActiveFilters"
        variant="ghost"
        color="slate"
        size="sm"
        icon="i-lucide-filter-x"
        :label="$t('PIPELINES_BOARD.FILTERS.CLEAR')"
        @click="$emit('clear')"
      />
    </div>

    <div class="flex gap-2 overflow-x-auto pb-1">
      <select
        :value="filters.sort"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.SORT')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('sort', $event.target.value)"
      >
        <option value="recent">
          {{ $t('PIPELINES_BOARD.FILTERS.SORT_RECENT') }}
        </option>
        <option value="oldest">
          {{ $t('PIPELINES_BOARD.FILTERS.SORT_OLDEST') }}
        </option>
        <option value="next_activity">
          {{ $t('PIPELINES_BOARD.FILTERS.SORT_NEXT_ACTIVITY') }}
        </option>
        <option value="priority">
          {{ $t('PIPELINES_BOARD.FILTERS.SORT_PRIORITY') }}
        </option>
      </select>

      <select
        :value="filters.stageId"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.STAGE')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('stageId', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_STAGES') }}</option>
        <option v-for="stage in stages" :key="stage.id" :value="stage.id">
          {{ stage.name }}
        </option>
      </select>

      <select
        :value="filters.ownerId"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.OWNER')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('ownerId', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_OWNERS') }}</option>
        <option value="unassigned">
          {{ $t('PIPELINES_BOARD.FORM.UNASSIGNED') }}
        </option>
        <option v-for="agent in agents" :key="agent.id" :value="agent.id">
          {{ agent.available_name }}
        </option>
      </select>

      <select
        :value="filters.teamId"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.TEAM')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('teamId', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_TEAMS') }}</option>
        <option value="unassigned">
          {{ $t('PIPELINES_BOARD.FORM.NO_TEAM') }}
        </option>
        <option v-for="team in teams" :key="team.id" :value="team.id">
          {{ team.name }}
        </option>
      </select>

      <select
        :value="filters.inboxId"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.INBOX')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('inboxId', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_INBOXES') }}</option>
        <option v-for="inbox in inboxes" :key="inbox.id" :value="inbox.id">
          {{ inbox.name }}
        </option>
      </select>

      <select
        :value="filters.channel"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.CHANNEL')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('channel', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_CHANNELS') }}</option>
        <option
          v-for="channel in channels"
          :key="channel.value"
          :value="channel.value"
        >
          {{ channel.label }}
        </option>
      </select>

      <select
        :value="filters.label"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.LABEL')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('label', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ALL_LABELS') }}</option>
        <option v-for="label in labels" :key="label.id" :value="label.title">
          {{ label.title }}
        </option>
      </select>

      <select
        :value="filters.dueState"
        :aria-label="$t('PIPELINES_BOARD.FILTERS.DUE_STATE')"
        class="h-8 shrink-0 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
        @change="updateFilter('dueState', $event.target.value)"
      >
        <option value="">{{ $t('PIPELINES_BOARD.FILTERS.ANY_DUE_STATE') }}</option>
        <option value="overdue">
          {{ $t('PIPELINES_BOARD.FILTERS.OVERDUE') }}
        </option>
        <option value="upcoming">
          {{ $t('PIPELINES_BOARD.FILTERS.UPCOMING') }}
        </option>
        <option value="missing">
          {{ $t('PIPELINES_BOARD.FILTERS.MISSING') }}
        </option>
      </select>
    </div>
  </div>
</template>
