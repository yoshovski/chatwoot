<script setup>
import { computed, onMounted, reactive, ref, toRef, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store.js';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { usePolicy } from 'dashboard/composables/usePolicy';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Select from 'dashboard/components-next/select/Select.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';
import EmptyState from 'dashboard/components-next/kit/EmptyState.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import WidgetLivePreview from 'dashboard/components-next/Inbox/WidgetLivePreview.vue';
import PlaygroundTestSetup from './PlaygroundTestSetup.vue';
import WhyThisAnswer from './WhyThisAnswer.vue';
import FixAnswerPanel from './FixAnswerPanel.vue';
import { usePlaygroundSession } from './usePlaygroundSession';
import { useWidgetTestChat } from './useWidgetTestChat';

// The AI agent test: the customer's real website chat on the left, what explains each reply on the right.
const props = defineProps({
  assistantId: { type: Number, required: true },
});

const { t } = useI18n();
const store = useStore();
const { isFeatureFlagEnabled } = usePolicy();
const isV2 = computed(() => isFeatureFlagEnabled(FEATURE_FLAGS.CAPTAIN_V2));

const assistantIdRef = toRef(props, 'assistantId');
const assistant = useFunctionGetter(
  'captainAssistants/getRecord',
  assistantIdRef
);
const connectedInboxes = useMapGetter('captainInboxes/getRecords');
const isLoadingInboxes = ref(true);
const hasInboxError = ref(false);
const selectedInboxId = ref(null);

const widgetInboxes = computed(() =>
  connectedInboxes.value.filter(
    inbox => inbox.channel_type === 'Channel::WebWidget'
  )
);
const selectedInbox = computed(
  () =>
    widgetInboxes.value.find(inbox => inbox.id === selectedInboxId.value) ||
    widgetInboxes.value[0] ||
    null
);
const inboxOptions = computed(() =>
  widgetInboxes.value.map(inbox => ({ value: inbox.id, label: inbox.name }))
);

const session = reactive(usePlaygroundSession({ assistantId: assistantIdRef }));
const {
  widgetMessages,
  replies,
  isLoading,
  hasConversation,
  send,
  submit,
  reset,
} = useWidgetTestChat({
  assistantId: assistantIdRef,
  agentName: computed(() => assistant.value?.name),
  // Test setup overrides exist only with Captain V2, where the setup panel is shown.
  session,
});

const preview = ref(null);
const setupPanel = ref(null);
const fixPanel = ref(null);
const activeReplyId = ref(null);
const fixedReplyIds = ref(new Set());
const widgetConfig = {};

const repliesNewestFirst = computed(() => [...replies.value].reverse());

watch(
  () => replies.value.length,
  () => {
    activeReplyId.value = replies.value.at(-1)?.id ?? null;
  }
);

const startOver = () => {
  reset();
  fixedReplyIds.value = new Set();
  preview.value?.showHome();
};

const markFixed = reply => {
  fixedReplyIds.value = new Set([...fixedReplyIds.value, reply.id]);
};

const loadInboxes = async () => {
  isLoadingInboxes.value = true;
  hasInboxError.value = false;
  try {
    await store.dispatch('captainInboxes/get', {
      assistantId: props.assistantId,
    });
  } catch {
    hasInboxError.value = true;
  } finally {
    isLoadingInboxes.value = false;
  }
};

watch(selectedInbox, startOver);
watch(
  isV2,
  enabled => {
    if (enabled) session.initialize();
  },
  { immediate: true }
);
onMounted(loadInboxes);
</script>

<template>
  <div class="flex min-h-0 flex-col gap-4">
    <div class="flex flex-wrap items-center gap-2">
      <p
        class="mb-0 me-auto flex min-w-0 items-center gap-1.5 text-sm text-n-slate-11"
      >
        <span class="i-lucide-shield-check size-4 shrink-0 text-n-teal-11" />
        {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.NOT_COUNTED') }}
      </p>
      <Select
        v-if="inboxOptions.length > 1"
        v-model="selectedInboxId"
        :options="inboxOptions"
        :aria-label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WIDGET_LABEL')"
      />
      <NextButton
        v-if="isV2"
        sm
        :faded="session.hasOverrides"
        :ghost="!session.hasOverrides"
        :color="session.hasOverrides ? 'iris' : 'slate'"
        icon="i-lucide-settings-2"
        :label="t('CAPTAIN.PLAYGROUND.SETUP.TITLE')"
        data-test="playground-test-setup-button"
        @click="setupPanel.open()"
      />
      <NextButton
        sm
        faded
        slate
        icon="i-lucide-rotate-ccw"
        :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.START_OVER')"
        :disabled="!hasConversation"
        data-test="widget-test-start-over"
        @click="startOver"
      />
    </div>

    <div v-if="isLoadingInboxes" class="flex justify-center py-16">
      <Spinner :size="24" class="text-n-slate-10" />
    </div>

    <EmptyState
      v-else-if="hasInboxError"
      tone="error"
      icon="i-lucide-triangle-alert"
      :title="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.LOAD_ERROR')"
    >
      <NextButton
        sm
        faded
        slate
        :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.RETRY')"
        @click="loadInboxes"
      />
    </EmptyState>

    <EmptyState
      v-else-if="!selectedInbox"
      icon="i-lucide-message-circle"
      :title="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.NO_WIDGET.TITLE')"
      :description="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.NO_WIDGET.DESCRIPTION')"
    >
      <router-link
        :to="{
          name: 'captain_assistants_inboxes_index',
          params: { assistantId },
        }"
      >
        <NextButton
          sm
          :label="t('CAPTAIN.PLAYGROUND.WIDGET_TEST.NO_WIDGET.ACTION')"
        />
      </router-link>
    </EmptyState>

    <div
      v-else
      class="grid items-start gap-6 lg:grid-cols-[minmax(0,26rem)_minmax(0,1fr)]"
    >
      <WidgetLivePreview
        ref="preview"
        :inbox-id="selectedInbox.id"
        :config="widgetConfig"
        :messages="widgetMessages"
        :typing="isLoading"
        test-mode
        @send="send"
        @submit="submit"
      />
      <section class="flex min-w-0 flex-col gap-3">
        <h2
          class="mb-0 font-display text-base font-semibold tracking-display text-n-slate-12"
        >
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.TITLE') }}
        </h2>
        <p
          v-if="!replies.length"
          class="mb-0 rounded-card bg-n-solid-2 p-5 text-sm text-n-slate-11 shadow-card"
        >
          {{ t('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.EMPTY') }}
        </p>
        <WhyThisAnswer
          v-for="reply in repliesNewestFirst"
          :key="reply.id"
          :reply="reply"
          :active="reply.id === activeReplyId"
          :fixed="fixedReplyIds.has(reply.id)"
          @select="activeReplyId = $event.id"
          @fix="fixPanel.open($event)"
        />
      </section>
    </div>

    <FixAnswerPanel
      ref="fixPanel"
      :assistant-id="assistantId"
      @saved="markFixed"
    />
    <SidePanel
      v-if="isV2"
      ref="setupPanel"
      width="lg"
      :title="t('CAPTAIN.PLAYGROUND.SETUP.TITLE')"
      :description="t('CAPTAIN.PLAYGROUND.SETUP.DESCRIPTION')"
    >
      <PlaygroundTestSetup :session="session" />
    </SidePanel>
  </div>
</template>
