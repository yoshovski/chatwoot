<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import { useStore, useMapGetter } from 'dashboard/composables/store';
import { useAccount } from 'dashboard/composables/useAccount';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { useMessageContext } from './provider.js';
import { MESSAGE_VARIANTS, ORIENTATION } from './constants';

const props = defineProps({
  messageId: { type: Number, required: true },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const { orientation, variant, createdAt } = useMessageContext();
const store = useStore();
const { isCloudFeatureEnabled } = useAccount();

const isOpen = ref(false);
const showOtherSources = ref(false);

const showSparkle = computed(() =>
  isCloudFeatureEnabled(FEATURE_FLAGS.CAPTAIN_V2)
);

const session = computed(() =>
  store.getters['captainAgentSessions/getSessionByMessageId'](props.messageId)
);
const hasFetched = computed(() =>
  store.getters['captainAgentSessions/hasFetched'](props.messageId)
);
const isLoading = computed(
  () =>
    !hasFetched.value ||
    store.getters['captainAgentSessions/isFetching'](props.messageId)
);

const sourceKinds = computed(() => ({
  faq: {
    icon: 'i-ph-question',
    kindLabel: t('CONVERSATION.CAPTAIN_GENERATION.KINDS.FAQ'),
  },
  document: {
    icon: 'i-ph-file-text',
    kindLabel: t('CONVERSATION.CAPTAIN_GENERATION.KINDS.DOCUMENT'),
  },
  product: {
    icon: 'i-ph-package',
    kindLabel: t('CONVERSATION.CAPTAIN_GENERATION.KINDS.PRODUCT'),
  },
  knowledge: {
    icon: 'i-ph-books',
    kindLabel: t('CONVERSATION.CAPTAIN_GENERATION.KINDS.KNOWLEDGE'),
  },
}));

// Sessions captured before sources were recorded only know the cited documents
// and the FAQs the search returned.
const legacySources = computed(() => [
  ...(session.value?.citations || []).map(citation => ({
    ...citation,
    kind: 'document',
    url: citation.link,
    used: true,
  })),
  ...(session.value?.usedFaqs || []).map(faq => ({
    ...faq,
    kind: 'faq',
    faqId: faq.id,
    used: false,
  })),
]);

const sources = computed(() => {
  const recorded = session.value?.sources || [];
  const list = recorded.length ? recorded : legacySources.value;
  return list.map(source => ({
    ...source,
    ...(sourceKinds.value[source.kind] || sourceKinds.value.knowledge),
  }));
});
const usedSources = computed(() => sources.value.filter(s => s.used));
const otherSources = computed(() => sources.value.filter(s => !s.used));

const faqsUrl = computed(() => {
  if (!session.value?.assistantId) return null;
  return router.resolve({
    name: 'captain_assistants_responses_index',
    params: {
      accountId: route.params.accountId,
      assistantId: session.value.assistantId,
    },
  }).href;
});

const sourceLink = source => {
  if (source.url) {
    return {
      href: source.url,
      label:
        source.kind === 'product'
          ? t('CONVERSATION.CAPTAIN_GENERATION.VIEW_PRODUCT')
          : t('CONVERSATION.CAPTAIN_GENERATION.OPEN_SOURCE'),
    };
  }
  if (source.kind === 'faq' && faqsUrl.value) {
    return {
      href: faqsUrl.value,
      label: t('CONVERSATION.CAPTAIN_GENERATION.OPEN_FAQS'),
    };
  }
  return null;
};

const scenarioTitles = computed(() =>
  (session.value?.scenarios || []).reduce((map, scenario) => {
    map[scenario.id] = scenario.title;
    return map;
  }, {})
);

// Fallback for agents without a matching scenario title:
// "chatwoot_assistant" → "Chatwoot assistant",
// "scenario_5_chatwoot_uptime_agent" → "Chatwoot uptime".
const humanizeAgentName = agentName => {
  const label = agentName
    .replace(/^scenario_\d+_/, '')
    .replace(/_agent$/, '')
    .replaceAll('_', ' ')
    .trim();
  return label.charAt(0).toUpperCase() + label.slice(1);
};

const handoffLabel = agentName => {
  const scenarioId = agentName.match(/^scenario_(\d+)/)?.[1];
  return scenarioTitles.value[scenarioId] || humanizeAgentName(agentName);
};

// Built-in tools get a plain-language step; custom tools fall back to their
// humanized name ("custom_get_status_page" → "Get Status Page").
const toolSteps = computed(() => ({
  faq_lookup: {
    icon: 'i-ph-magnifying-glass',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.FAQ_LOOKUP'),
  },
  catalog_product_search: {
    icon: 'i-ph-package',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.PRODUCT_SEARCH'),
  },
  browse_catalog: {
    icon: 'i-ph-storefront',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.BROWSE_CATALOG'),
  },
  track_order: {
    icon: 'i-ph-truck',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.TRACK_ORDER'),
  },
  handoff: {
    icon: 'i-ph-user-switch',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.HANDOFF'),
  },
  add_private_note: {
    icon: 'i-ph-note',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.PRIVATE_NOTE'),
  },
  add_contact_note: {
    icon: 'i-ph-note',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.CONTACT_NOTE'),
  },
  add_label_to_conversation: {
    icon: 'i-ph-tag',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.ADD_LABEL'),
  },
  update_priority: {
    icon: 'i-ph-flag',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.UPDATE_PRIORITY'),
  },
  resolve_conversation: {
    icon: 'i-ph-check-circle',
    label: t('CONVERSATION.CAPTAIN_GENERATION.TOOLS.RESOLVE'),
  },
}));

const ACRONYMS = ['faq', 'api', 'url', 'id', 'sla', 'csat'];

const toolKey = name =>
  (name || '')
    .split('--')
    .pop()
    .replace(/^custom_/, '');

const humanizeToolName = name =>
  toolKey(name)
    .split('_')
    .filter(Boolean)
    .map(word =>
      ACRONYMS.includes(word)
        ? word.toUpperCase()
        : word.charAt(0).toUpperCase() + word.slice(1)
    )
    .join(' ');

// Argument keys are camelCased by the store ("labelName"); show "Label Name".
const humanizeArgumentKey = key =>
  key
    .replace(/([a-z])([A-Z])/g, '$1 $2')
    .split(' ')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');

const formatArguments = args => {
  if (!args || typeof args !== 'object') return '';
  if (args.query) return `“${args.query}”`;
  return Object.entries(args)
    .map(([key, value]) => `${humanizeArgumentKey(key)}: ${value}`)
    .join(', ');
};

const toolStep = call => {
  const known = toolSteps.value[toolKey(call.name)];
  return {
    icon: known?.icon || 'i-ph-wrench',
    label: known?.label || humanizeToolName(call.name),
    detail: formatArguments(call.arguments),
  };
};

// Timeline of what Captain did during the run: tool calls (with their
// arguments) and scenario/agent handoffs. Message bodies and raw tool
// results are intentionally not echoed here.
const steps = computed(() => {
  const runContext = session.value?.runContext;
  const result = [];
  let currentAgent = null;

  (Array.isArray(runContext) ? runContext : []).forEach(entry => {
    if (entry?.role !== 'assistant') return;

    const agentName = entry.agentName;
    if (agentName && agentName !== currentAgent) {
      if (currentAgent !== null) {
        result.push({
          icon: 'i-ph-user-switch',
          label: t('CONVERSATION.CAPTAIN_GENERATION.STEP_HANDOFF', {
            name: handoffLabel(agentName),
          }),
        });
      }
      currentAgent = agentName;
    }

    (entry.toolCalls || []).forEach(call => {
      // Agent-to-agent transfers surface as "handoff_to_<agent>" tool calls;
      // the agent_name change above already yields a handoff step for them.
      if (call.name?.startsWith('handoff_to_')) return;

      result.push(toolStep(call));
    });
  });

  return result;
});

const currentUser = useMapGetter('getCurrentUser');
const isSuperAdmin = computed(() => currentUser.value.type === 'SuperAdmin');

// Model and credits are only surfaced to super admins and in development.
const devDetails = computed(() => {
  if (!session.value) return null;
  if (!import.meta.env.DEV && !isSuperAdmin.value) return null;
  const model = t('CONVERSATION.CAPTAIN_GENERATION.MODEL', {
    model: session.value.llmModel,
  });
  const credits = t('CONVERSATION.CAPTAIN_GENERATION.CREDITS', {
    credits: session.value.creditsConsumed,
  });
  return `${model} · ${credits}`;
});

// With the sparkle at the row start, the meta gets pushed to the opposite end;
// without it, fall back to the message orientation.
const rowLayoutClass = computed(() => {
  if (showSparkle.value) return 'justify-between';
  return orientation.value === ORIENTATION.LEFT
    ? 'justify-start'
    : 'justify-end';
});

// Blend the sparkle with the bubble background: amber on private notes,
// slate everywhere else. Tokens adapt to dark mode on their own.
const sparkleColorClass = computed(() => {
  if (variant.value === MESSAGE_VARIANTS.PRIVATE) {
    return isOpen.value
      ? 'text-n-amber-12/80'
      : 'text-n-amber-12/40 hover:text-n-amber-12/70';
  }
  return isOpen.value
    ? 'text-n-slate-12'
    : 'text-n-slate-11/60 hover:text-n-slate-12';
});

const popoverAlign = computed(() =>
  orientation.value === ORIENTATION.LEFT ? 'start' : 'end'
);

const prefetch = () => {
  store.dispatch('captainAgentSessions/fetch', {
    messageId: props.messageId,
    createdAt: createdAt.value,
  });
};

const onPopoverShow = () => {
  isOpen.value = true;
  prefetch();
};

const onPopoverHide = () => {
  isOpen.value = false;
};
</script>

<template>
  <div class="flex items-center gap-1.5" :class="rowLayoutClass">
    <Popover
      v-if="showSparkle"
      :align="popoverAlign"
      @show="onPopoverShow"
      @hide="onPopoverHide"
    >
      <button
        v-tooltip="t('CONVERSATION.CAPTAIN_GENERATION.TITLE')"
        type="button"
        class="inline-flex items-center gap-1 p-0 bg-transparent border-0 cursor-pointer"
        :class="sparkleColorClass"
        @mouseenter="prefetch"
        @focus="prefetch"
      >
        <Icon icon="i-ph-sparkle-fill" class="size-3.5" />
        <span class="text-xs">
          {{ t('CONVERSATION.CAPTAIN_GENERATION.BUTTON') }}
        </span>
      </button>
      <template #content>
        <div class="flex flex-col gap-4 p-4 overflow-y-auto w-96 max-h-[30rem]">
          <span v-if="isLoading" class="text-xs text-n-slate-11">
            {{ t('CONVERSATION.CAPTAIN_GENERATION.LOADING') }}
          </span>
          <span v-else-if="!session" class="text-xs text-n-slate-11">
            {{ t('CONVERSATION.CAPTAIN_GENERATION.EMPTY') }}
          </span>
          <template v-else>
            <div class="flex flex-col gap-2">
              <span class="text-sm font-medium text-n-slate-12">
                {{
                  usedSources.length
                    ? t(
                        'CONVERSATION.CAPTAIN_GENERATION.USED_SOURCES',
                        usedSources.length
                      )
                    : t('CONVERSATION.CAPTAIN_GENERATION.NO_SOURCES')
                }}
              </span>
              <span
                v-if="!usedSources.length"
                class="text-xs leading-normal text-n-slate-11"
              >
                {{ t('CONVERSATION.CAPTAIN_GENERATION.NO_SOURCES_HINT') }}
              </span>
              <div
                v-for="source in usedSources"
                :key="`${source.kind}-${source.reference || source.id}`"
                class="flex flex-col gap-1 p-3 rounded-lg bg-n-alpha-1"
              >
                <span
                  class="inline-flex items-center gap-1 text-xs text-n-slate-11"
                >
                  <Icon :icon="source.icon" class="size-3.5" />
                  {{ source.kindLabel }}
                </span>
                <span class="text-sm font-medium break-words text-n-slate-12">
                  {{ source.title }}
                </span>
                <p
                  v-if="source.excerpt"
                  class="m-0 text-xs leading-normal break-words line-clamp-3 text-n-slate-11"
                >
                  {{ source.excerpt }}
                </p>
                <a
                  v-if="sourceLink(source)"
                  :href="sourceLink(source).href"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="inline-flex items-center gap-1 text-xs text-n-blue-11 hover:underline"
                >
                  {{ sourceLink(source).label }}
                  <Icon icon="i-ph-arrow-square-out" class="size-3" />
                </a>
              </div>
            </div>
            <div v-if="otherSources.length" class="flex flex-col gap-2">
              <button
                type="button"
                class="inline-flex items-center gap-1 p-0 text-xs font-medium bg-transparent border-0 cursor-pointer text-n-slate-11 hover:text-n-slate-12"
                @click="showOtherSources = !showOtherSources"
              >
                <Icon
                  :icon="
                    showOtherSources ? 'i-ph-caret-down' : 'i-ph-caret-right'
                  "
                  class="size-3"
                />
                {{
                  t('CONVERSATION.CAPTAIN_GENERATION.OTHER_SOURCES', {
                    count: otherSources.length,
                  })
                }}
              </button>
              <ul v-if="showOtherSources" class="flex flex-col gap-1.5 m-0 p-0">
                <li
                  v-for="source in otherSources"
                  :key="`${source.kind}-${source.reference || source.id}`"
                  class="flex items-start gap-1.5 text-xs list-none text-n-slate-12"
                >
                  <Icon
                    :icon="source.icon"
                    class="flex-shrink-0 mt-0.5 size-3.5 text-n-slate-11"
                  />
                  <a
                    v-if="sourceLink(source)"
                    :href="sourceLink(source).href"
                    target="_blank"
                    rel="noopener noreferrer"
                    class="break-words hover:underline"
                  >
                    {{ source.title }}
                  </a>
                  <span v-else class="break-words">{{ source.title }}</span>
                </li>
              </ul>
            </div>
            <div v-if="steps.length" class="flex flex-col gap-2">
              <span class="text-xs font-medium text-n-slate-11">
                {{ t('CONVERSATION.CAPTAIN_GENERATION.TIMELINE') }}
              </span>
              <div class="flex flex-col">
                <div
                  v-for="(step, index) in steps"
                  :key="index"
                  class="flex gap-2.5"
                >
                  <div class="flex flex-col items-center">
                    <span
                      class="flex items-center justify-center rounded-full size-5 bg-n-alpha-2 text-n-slate-11"
                    >
                      <Icon :icon="step.icon" class="size-3" />
                    </span>
                    <span
                      v-if="index < steps.length - 1"
                      class="flex-1 w-px min-h-2 bg-n-weak"
                    />
                  </div>
                  <div
                    class="flex flex-col min-w-0 gap-0.5"
                    :class="index < steps.length - 1 ? 'pb-3' : ''"
                  >
                    <span class="text-xs font-medium leading-5 text-n-slate-12">
                      {{ step.label }}
                    </span>
                    <span
                      v-if="step.detail"
                      class="text-xs break-words text-n-slate-11"
                    >
                      {{ step.detail }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
            <span v-if="devDetails" class="text-xs text-n-slate-11">
              {{ devDetails }}
            </span>
          </template>
        </div>
      </template>
    </Popover>
    <slot name="meta" />
  </div>
</template>
