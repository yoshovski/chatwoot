<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

// What explains one test reply: the scenario that answered, the knowledge it used, the actions it ran, the time.
const props = defineProps({
  reply: { type: Object, required: true },
  active: { type: Boolean, default: false },
  // A fix (FAQ or rule) was saved for this reply.
  fixed: { type: Boolean, default: false },
});

defineEmits(['fix', 'select']);

const { t } = useI18n();

const ACTION_ICONS = {
  completed: 'i-lucide-circle-check text-n-teal-11',
  failed: 'i-lucide-circle-x text-n-ruby-11',
  running: 'i-lucide-loader-circle text-n-slate-10',
};
const SOURCE_ICONS = {
  faq: 'i-lucide-message-circle-question',
  product: 'i-lucide-shopping-bag',
  knowledge: 'i-lucide-file-text',
};

const handler = computed(
  () =>
    props.reply.runDetails?.handler?.title ||
    t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.MAIN_AGENT')
);
const seconds = computed(() =>
  props.reply.runDetails
    ? (props.reply.runDetails.duration_ms / 1000).toFixed(1)
    : null
);
const actions = computed(() =>
  (props.reply.runDetails?.events || []).filter(event => event.type === 'tool')
);
const sourceIcon = source =>
  SOURCE_ICONS[source.kind] || SOURCE_ICONS.knowledge;

const handoffReason = computed(() => {
  const { source, reason } = props.reply.handoff || {};
  if (source === 'tool' && reason) {
    return t(
      'CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.TOOL_WITH_REASON',
      {
        reason,
      }
    );
  }
  if (source === 'tool') {
    return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.TOOL');
  }
  if (source === 'declared') {
    return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.DECLARED');
  }
  if (source === 'safety_net') {
    return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.SAFETY_NET');
  }
  return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.EMPTY_RESPONSE');
});
</script>

<template>
  <article
    class="flex flex-col gap-3 rounded-card bg-n-solid-2 p-4 shadow-card outline outline-1 -outline-offset-1 transition-[outline-color]"
    :class="active ? 'outline-n-blue-8' : 'outline-n-container'"
    @click="$emit('select', reply)"
  >
    <header class="flex items-start justify-between gap-3">
      <p class="mb-0 min-w-0 break-words text-sm font-medium text-n-slate-12">
        {{ reply.question }}
      </p>
      <span
        v-if="seconds"
        class="shrink-0 text-xs tabular-nums text-n-slate-10"
      >
        {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.SECONDS', { seconds }) }}
      </span>
    </header>

    <p
      v-if="reply.error"
      class="mb-0 rounded-lg bg-n-ruby-3 px-3 py-2 text-sm text-n-ruby-11"
      role="alert"
    >
      {{ reply.error }}
    </p>

    <dl v-else class="mb-0 grid gap-2.5 text-sm">
      <div class="flex gap-2">
        <dt class="w-24 shrink-0 text-n-slate-11">
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.ANSWERED_BY') }}
        </dt>
        <dd class="mb-0 min-w-0 text-n-slate-12">{{ handler }}</dd>
      </div>
      <div class="flex gap-2">
        <dt class="w-24 shrink-0 text-n-slate-11">
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.SOURCES') }}
        </dt>
        <dd class="mb-0 flex min-w-0 flex-col gap-1">
          <template v-if="reply.sources.length">
            <span
              v-for="(source, index) in reply.sources"
              :key="`${source.title}-${index}`"
              class="flex min-w-0 items-center gap-1.5"
            >
              <Icon
                :icon="sourceIcon(source)"
                class="size-4 shrink-0 text-n-slate-10"
              />
              <a
                v-if="source.url"
                :href="source.url"
                target="_blank"
                rel="noopener noreferrer"
                class="truncate text-n-blue-11 hover:underline"
                @click.stop
              >
                {{ source.title || source.url }}
              </a>
              <span v-else class="truncate text-n-slate-12">
                {{ source.title || source.document_title }}
              </span>
            </span>
          </template>
          <span v-else class="text-n-slate-10">
            {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.NO_SOURCES') }}
          </span>
        </dd>
      </div>
      <div class="flex gap-2">
        <dt class="w-24 shrink-0 text-n-slate-11">
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.ACTIONS') }}
        </dt>
        <dd class="mb-0 flex min-w-0 flex-col gap-1">
          <template v-if="actions.length">
            <span
              v-for="(action, index) in actions"
              :key="`${action.name}-${index}`"
              class="flex items-center gap-1.5 text-n-slate-12"
            >
              <Icon
                :icon="ACTION_ICONS[action.status] || ACTION_ICONS.running"
                class="size-4 shrink-0"
              />
              <span class="truncate">{{ action.name }}</span>
            </span>
          </template>
          <span v-else class="text-n-slate-10">
            {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.NO_ACTIONS') }}
          </span>
        </dd>
      </div>
      <p
        v-if="reply.handoff"
        class="mb-0 rounded-lg bg-n-amber-3 px-3 py-2 text-n-amber-11"
      >
        {{ t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF') }}
        {{ handoffReason }}
      </p>
    </dl>

    <footer v-if="!reply.error" class="flex justify-end">
      <span
        v-if="fixed"
        class="flex items-center gap-1.5 text-sm text-n-teal-11"
        data-test="why-fixed"
      >
        <Icon icon="i-lucide-circle-check" class="size-4" />
        {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.FIXED') }}
      </span>
      <NextButton
        v-else
        sm
        faded
        slate
        icon="i-lucide-wand-sparkles"
        :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.FIX')"
        data-test="why-fix"
        @click.stop="$emit('fix', reply)"
      />
    </footer>
  </article>
</template>
