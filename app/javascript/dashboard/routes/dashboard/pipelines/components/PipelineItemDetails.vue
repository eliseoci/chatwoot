<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

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
});

const emit = defineEmits([
  'close',
  'link-conversation',
  'unlink-conversation',
  'open-conversation',
]);

const { locale, t } = useI18n();
const closeButtonRef = ref(null);
const selectedConversationId = ref('');

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
  }
);

watch(
  () => props.item.linked_conversations?.length || 0,
  () => {
    selectedConversationId.value = '';
  }
);

onMounted(() => {
  document.addEventListener('keydown', handleKeydown);
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
                :disabled="isLoadingCandidates || !availableConversations.length"
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
                :disabled="!selectedConversationId || activeConversationId !== null"
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
