<script setup>
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  items: {
    type: Array,
    default: () => [],
  },
  stages: {
    type: Array,
    default: () => [],
  },
  attentionMode: {
    type: Boolean,
    default: false,
  },
  canMove: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['move', 'open']);
const { locale, t } = useI18n();

const formatDateTime = value => {
  if (!value) return t('PIPELINES_BOARD.LIST.NO_ACTIVITY');

  return new Intl.DateTimeFormat(locale.value, {
    dateStyle: 'medium',
    timeStyle: 'short',
  }).format(new Date(value));
};

const attentionLabel = reason =>
  t(`PIPELINES_BOARD.ATTENTION.REASONS.${reason.toUpperCase()}`);

const channelLabel = channelType => {
  const channel = channelType?.replace('Channel::', '').toUpperCase();
  const key = `PIPELINES_BOARD.DETAIL.CHANNEL.${channel}`;
  const translated = t(key);
  return translated === key
    ? t('PIPELINES_BOARD.DETAIL.CHANNEL.OTHER')
    : translated;
};

const openWithKeyboard = (item, event) => {
  if (!['Enter', ' '].includes(event.key)) return;

  event.preventDefault();
  emit('open', item);
};
</script>

<template>
  <div class="min-w-0 flex-1 overflow-auto p-5">
    <div
      v-if="!items.length"
      class="flex min-h-56 flex-col items-center justify-center gap-2 rounded-xl border border-dashed border-n-weak text-center"
    >
      <p class="mb-0 text-sm font-medium text-n-slate-12">
        {{
          $t(
            attentionMode
              ? 'PIPELINES_BOARD.ATTENTION.EMPTY_TITLE'
              : 'PIPELINES_BOARD.LIST.EMPTY_TITLE'
          )
        }}
      </p>
      <p class="mb-0 text-xs text-n-slate-10">
        {{
          $t(
            attentionMode
              ? 'PIPELINES_BOARD.ATTENTION.EMPTY_DESCRIPTION'
              : 'PIPELINES_BOARD.LIST.EMPTY_DESCRIPTION'
          )
        }}
      </p>
    </div>

    <table v-else class="w-full min-w-[1100px] border-separate border-spacing-0">
      <thead>
        <tr class="text-left text-xs font-medium text-n-slate-9">
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.ITEM') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.STAGE') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.OWNER_TEAM') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.CHANNEL') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.LAST_ACTIVITY') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.NEXT_ACTIVITY') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.PRIORITY') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            {{ $t('PIPELINES_BOARD.LIST.ATTENTION') }}
          </th>
          <th class="border-b border-n-weak px-3 py-2">
            <span class="sr-only">{{ $t('PIPELINES_BOARD.LIST.ACTIONS') }}</span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="item in items"
          :key="item.id"
          tabindex="0"
          class="text-sm text-n-slate-11 outline-none hover:bg-n-alpha-black2 focus:bg-n-alpha-black2"
          @keydown="openWithKeyboard(item, $event)"
        >
          <td class="border-b border-n-weak px-3 py-3">
            <p class="mb-0 max-w-56 truncate font-medium text-n-slate-12">
              {{ item.display_title }}
            </p>
            <p class="mb-0 max-w-56 truncate text-xs text-n-slate-9">
              {{ item.contact.name || item.contact.email || item.contact.phone_number }}
            </p>
          </td>
          <td class="border-b border-n-weak px-3 py-3">
            <select
              :value="item.stage_id"
              class="h-8 rounded-md border-0 bg-n-alpha-black2 px-2 text-xs text-n-slate-11 outline outline-1 -outline-offset-1 outline-n-weak"
              :aria-label="
                $t('PIPELINES_BOARD.MOVE.COMMAND_LABEL', {
                  title: item.display_title,
                })
              "
              :disabled="!canMove"
              @change="
                $emit('move', {
                  item,
                  stageId: Number($event.target.value),
                })
              "
            >
              <option v-for="stage in stages" :key="stage.id" :value="stage.id">
                {{ stage.name }}
              </option>
            </select>
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-xs">
            <p class="mb-0">{{ item.owner?.name || $t('PIPELINES_BOARD.FORM.UNASSIGNED') }}</p>
            <p class="mb-0 text-n-slate-9">
              {{ item.team?.name || $t('PIPELINES_BOARD.FORM.NO_TEAM') }}
            </p>
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-xs">
            <p
              v-for="inbox in item.workspace?.inboxes || []"
              :key="inbox.id"
              class="mb-0"
            >
              {{ inbox.name }} · {{ channelLabel(inbox.channel_type) }}
            </p>
            <p v-if="!item.workspace?.inboxes?.length" class="mb-0 text-n-slate-9">
              {{ $t('PIPELINES_BOARD.LIST.NO_CHANNEL') }}
            </p>
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-xs">
            {{ formatDateTime(item.workspace?.last_activity_at) }}
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-xs">
            <template v-if="item.next_activity">
              <p class="mb-0 font-medium text-n-slate-12">
                {{ item.next_activity.title }}
              </p>
              <p
                class="mb-0"
                :class="item.next_activity.overdue ? 'text-n-ruby-11' : 'text-n-slate-9'"
              >
                {{ formatDateTime(item.next_activity.due_at) }}
              </p>
            </template>
            <span v-else class="text-n-slate-9">
              {{ $t('PIPELINES_BOARD.LIST.NO_NEXT_ACTIVITY') }}
            </span>
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-xs">
            {{
              item.priority
                ? $t(`PIPELINES_BOARD.PRIORITY.${item.priority.toUpperCase()}`)
                : $t('PIPELINES_BOARD.LIST.NO_PRIORITY')
            }}
          </td>
          <td class="border-b border-n-weak px-3 py-3">
            <div class="flex max-w-64 flex-wrap gap-1">
              <span
                v-for="reason in item.workspace?.attention_reasons || []"
                :key="reason"
                class="rounded-md bg-n-amber-3 px-1.5 py-0.5 text-xs text-n-amber-11"
                :title="
                  reason === 'manual_attention'
                    ? item.workspace.attention_note
                    : ''
                "
              >
                {{ attentionLabel(reason) }}
              </span>
              <span
                v-if="!item.workspace?.attention_reasons?.length"
                class="text-xs text-n-slate-9"
              >
                {{ $t('PIPELINES_BOARD.ATTENTION.NONE') }}
              </span>
            </div>
          </td>
          <td class="border-b border-n-weak px-3 py-3 text-right">
            <Button
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-panel-right-open"
              :label="$t('PIPELINES_BOARD.DETAIL.ACTION')"
              @click="$emit('open', item)"
            />
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>
