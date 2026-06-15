<script setup>
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  report: {
    type: Object,
    default: null,
  },
  isLoading: {
    type: Boolean,
    default: false,
  },
  loadState: {
    type: String,
    default: 'ready',
  },
});

defineEmits(['retry']);

const formatCount = value =>
  new Intl.NumberFormat(undefined, { maximumFractionDigits: 0 }).format(
    Number(value || 0)
  );

const formatAge = seconds => {
  const totalSeconds = Math.max(Number(seconds || 0), 0);
  const unit = totalSeconds < 86400 ? 'hour' : 'day';
  const divisor = unit === 'hour' ? 3600 : 86400;

  return new Intl.NumberFormat(undefined, {
    style: 'unit',
    unit,
    unitDisplay: 'short',
    maximumFractionDigits: 1,
  }).format(totalSeconds / divisor);
};

const formatGeneratedAt = generatedAt =>
  new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(generatedAt));

const sourceTranslationKey = source =>
  `PIPELINES_BOARD.REPORTS.ATTRIBUTION.SOURCE.${source.toUpperCase()}`;

const channelTranslationKey = channel => {
  const key = channel?.replace('Channel::', '').toUpperCase();
  const supported = [
    'API',
    'EMAIL',
    'FACEBOOKPAGE',
    'INSTAGRAM',
    'LINE',
    'SMS',
    'TELEGRAM',
    'TIKTOK',
    'TWILIOSMS',
    'WEBWIDGET',
    'WHATSAPP',
  ];

  return supported.includes(key) ? key : 'OTHER';
};
</script>

<template>
  <main class="min-h-0 flex-1 overflow-y-auto p-5">
    <div
      v-if="isLoading"
      class="flex min-h-64 items-center justify-center gap-2 text-sm text-n-slate-11"
    >
      <Icon icon="i-lucide-loader-circle" class="size-4 animate-spin" />
      {{ $t('PIPELINES_BOARD.REPORTS.LOADING') }}
    </div>

    <div
      v-else-if="loadState === 'error'"
      class="flex min-h-64 flex-col items-center justify-center gap-3 text-center"
    >
      <Icon icon="i-lucide-triangle-alert" class="size-8 text-n-amber-10" />
      <div>
        <h2 class="text-heading-2 text-n-slate-12">
          {{ $t('PIPELINES_BOARD.REPORTS.ERROR_TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{ $t('PIPELINES_BOARD.REPORTS.ERROR_DESCRIPTION') }}
        </p>
      </div>
      <Button
        :label="$t('PIPELINES_BOARD.REPORTS.RETRY')"
        @click="$emit('retry')"
      />
    </div>

    <div
      v-else-if="!report"
      class="flex min-h-64 flex-col items-center justify-center gap-2 text-center"
    >
      <Icon icon="i-lucide-chart-no-axes-column" class="size-8 text-n-slate-9" />
      <p class="mb-0 text-sm text-n-slate-11">
        {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
      </p>
    </div>

    <div v-else class="mx-auto flex max-w-7xl flex-col gap-5">
      <div class="flex flex-wrap items-end justify-between gap-2">
        <div>
          <h2 class="text-heading-2 text-n-slate-12">
            {{ $t('PIPELINES_BOARD.REPORTS.TITLE') }}
          </h2>
          <p class="mb-0 text-sm text-n-slate-11">
            {{ $t('PIPELINES_BOARD.REPORTS.DESCRIPTION') }}
          </p>
        </div>
        <p class="mb-0 text-xs text-n-slate-10">
          {{
            $t('PIPELINES_BOARD.REPORTS.AS_OF', {
              date: formatGeneratedAt(report.generated_at),
              timezone: report.timezone,
            })
          }}
        </p>
      </div>

      <section
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <div class="border-b border-n-weak px-4 py-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ $t('PIPELINES_BOARD.REPORTS.STAGES.TITLE') }}
          </h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full min-w-[36rem] text-left text-sm">
            <thead class="bg-n-alpha-black2 text-xs text-n-slate-10">
              <tr>
                <th class="px-4 py-2 font-medium">
                  {{ $t('PIPELINES_BOARD.REPORTS.STAGES.STAGE') }}
                </th>
                <th class="px-4 py-2 text-right font-medium">
                  {{ $t('PIPELINES_BOARD.REPORTS.STAGES.ITEMS') }}
                </th>
                <th class="px-4 py-2 text-right font-medium">
                  {{ $t('PIPELINES_BOARD.REPORTS.STAGES.AVERAGE_AGE') }}
                </th>
                <th class="px-4 py-2 text-right font-medium">
                  {{ $t('PIPELINES_BOARD.REPORTS.STAGES.OLDEST_AGE') }}
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-n-weak">
              <tr
                v-for="stage in report.stages"
                :key="stage.id"
                data-testid="pipeline-report-stage"
              >
                <td class="px-4 py-3 font-medium text-n-slate-12">
                  {{ stage.name }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ formatCount(stage.item_count) }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ formatAge(stage.average_age_seconds) }}
                </td>
                <td class="px-4 py-3 text-right text-n-slate-11">
                  {{ formatAge(stage.oldest_age_seconds) }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </section>

      <div class="grid gap-5 xl:grid-cols-2">
        <section
          class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div class="border-b border-n-weak px-4 py-3">
            <h3 class="text-heading-3 text-n-slate-12">
              {{ $t('PIPELINES_BOARD.REPORTS.ACTIVITIES.TITLE') }}
            </h3>
          </div>
          <dl class="grid grid-cols-2 border-b border-n-weak sm:grid-cols-4">
            <div
              v-for="bucket in ['due', 'overdue', 'completed', 'canceled']"
              :key="bucket"
              class="border-r border-n-weak px-4 py-3 last:border-r-0"
            >
              <dt class="text-xs text-n-slate-10">
                {{
                  $t(
                    `PIPELINES_BOARD.REPORTS.ACTIVITIES.${bucket.toUpperCase()}`
                  )
                }}
              </dt>
              <dd class="mt-1 text-heading-2 text-n-slate-12">
                {{ formatCount(report.activities.summary[bucket]) }}
              </dd>
            </div>
          </dl>
          <div class="overflow-x-auto">
            <table class="w-full min-w-[34rem] text-left text-sm">
              <thead class="bg-n-alpha-black2 text-xs text-n-slate-10">
                <tr>
                  <th class="px-4 py-2 font-medium">
                    {{ $t('PIPELINES_BOARD.REPORTS.ACTIVITIES.OWNER') }}
                  </th>
                  <th
                    v-for="bucket in [
                      'due',
                      'overdue',
                      'completed',
                      'canceled',
                    ]"
                    :key="bucket"
                    class="px-3 py-2 text-right font-medium"
                  >
                    {{
                      $t(
                        `PIPELINES_BOARD.REPORTS.ACTIVITIES.${bucket.toUpperCase()}`
                      )
                    }}
                  </th>
                </tr>
              </thead>
              <tbody class="divide-y divide-n-weak">
                <tr
                  v-for="owner in report.activities.owners"
                  :key="owner.assignee_id || 'unassigned'"
                >
                  <td class="px-4 py-3 font-medium text-n-slate-12">
                    {{
                      owner.assignee_name ||
                      $t('PIPELINES_BOARD.REPORTS.ACTIVITIES.UNASSIGNED')
                    }}
                  </td>
                  <td
                    v-for="bucket in [
                      'due',
                      'overdue',
                      'completed',
                      'canceled',
                    ]"
                    :key="bucket"
                    class="px-3 py-3 text-right text-n-slate-11"
                  >
                    {{ formatCount(owner[bucket]) }}
                  </td>
                </tr>
                <tr v-if="!report.activities.owners.length">
                  <td colspan="5" class="px-4 py-6 text-center text-n-slate-10">
                    {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </section>

        <section
          class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
        >
          <div class="border-b border-n-weak px-4 py-3">
            <h3 class="text-heading-3 text-n-slate-12">
              {{ $t('PIPELINES_BOARD.REPORTS.OUTCOMES.TITLE') }}
            </h3>
          </div>
          <div
            v-if="report.outcomes.length"
            class="divide-y divide-n-weak"
          >
            <article
              v-for="outcome in report.outcomes"
              :key="outcome.stage_id"
              class="px-4 py-3"
            >
              <div class="flex items-center justify-between gap-3">
                <div>
                  <p class="mb-0 font-medium text-n-slate-12">
                    {{ outcome.stage_name }}
                  </p>
                  <p class="mb-0 text-xs text-n-slate-10">
                    {{ $t('PIPELINES_BOARD.REPORTS.OUTCOMES.OUTCOME') }}
                  </p>
                </div>
                <span
                  class="rounded-md bg-n-alpha-black2 px-2 py-1 text-sm font-medium text-n-slate-12"
                >
                  {{ formatCount(outcome.item_count) }}
                </span>
              </div>
              <ul v-if="outcome.reasons.length" class="mt-3 flex flex-col gap-2">
                <li
                  v-for="reason in outcome.reasons"
                  :key="reason.reason || 'none'"
                  class="flex items-center justify-between gap-3 text-sm"
                >
                  <span class="text-n-slate-11">
                    {{
                      reason.reason ||
                      $t('PIPELINES_BOARD.REPORTS.OUTCOMES.NO_REASON')
                    }}
                  </span>
                  <span class="text-n-slate-10">
                    {{ formatCount(reason.item_count) }}
                  </span>
                </li>
              </ul>
            </article>
          </div>
          <p v-else class="mb-0 px-4 py-6 text-center text-sm text-n-slate-10">
            {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
          </p>
        </section>
      </div>

      <section
        class="overflow-hidden rounded-xl border border-n-weak bg-n-solid-1"
      >
        <div class="border-b border-n-weak px-4 py-3">
          <h3 class="text-heading-3 text-n-slate-12">
            {{ $t('PIPELINES_BOARD.REPORTS.ATTRIBUTION.TITLE') }}
          </h3>
        </div>
        <div class="grid divide-y divide-n-weak md:grid-cols-3 md:divide-x md:divide-y-0">
          <div class="p-4">
            <h4 class="text-xs font-medium uppercase text-n-slate-10">
              {{ $t('PIPELINES_BOARD.REPORTS.ATTRIBUTION.SOURCES') }}
            </h4>
            <ul class="mt-3 flex flex-col gap-2">
              <li
                v-for="source in report.attribution.sources"
                :key="source.key"
                class="flex items-center justify-between gap-3 text-sm"
              >
                <span class="text-n-slate-11">
                  {{ $t(sourceTranslationKey(source.key)) }}
                </span>
                <span class="font-medium text-n-slate-12">
                  {{ formatCount(source.item_count) }}
                </span>
              </li>
              <li
                v-if="!report.attribution.sources.length"
                class="text-sm text-n-slate-10"
              >
                {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
              </li>
            </ul>
          </div>

          <div class="p-4">
            <h4 class="text-xs font-medium uppercase text-n-slate-10">
              {{ $t('PIPELINES_BOARD.REPORTS.ATTRIBUTION.INBOXES') }}
            </h4>
            <ul class="mt-3 flex flex-col gap-2">
              <li
                v-for="inbox in report.attribution.inboxes"
                :key="inbox.id"
                class="flex items-center justify-between gap-3 text-sm"
              >
                <span class="truncate text-n-slate-11">{{ inbox.name }}</span>
                <span class="font-medium text-n-slate-12">
                  {{ formatCount(inbox.item_count) }}
                </span>
              </li>
              <li
                v-if="!report.attribution.inboxes.length"
                class="text-sm text-n-slate-10"
              >
                {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
              </li>
            </ul>
          </div>

          <div class="p-4">
            <h4 class="text-xs font-medium uppercase text-n-slate-10">
              {{ $t('PIPELINES_BOARD.REPORTS.ATTRIBUTION.CHANNELS') }}
            </h4>
            <ul class="mt-3 flex flex-col gap-2">
              <li
                v-for="channel in report.attribution.channels"
                :key="channel.key"
                class="flex items-center justify-between gap-3 text-sm"
              >
                <span class="text-n-slate-11">
                  {{
                    $t(
                      `PIPELINES_BOARD.DETAIL.CHANNEL.${channelTranslationKey(
                        channel.key
                      )}`
                    )
                  }}
                </span>
                <span class="font-medium text-n-slate-12">
                  {{ formatCount(channel.item_count) }}
                </span>
              </li>
              <li
                v-if="!report.attribution.channels.length"
                class="text-sm text-n-slate-10"
              >
                {{ $t('PIPELINES_BOARD.REPORTS.EMPTY') }}
              </li>
            </ul>
          </div>
        </div>
      </section>
    </div>
  </main>
</template>
