<script setup>
import { computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import Select from 'dashboard/components-next/select/Select.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { demoUrl } from './playgroundAccent';

const props = defineProps({
  assistantId: { type: Number, required: true },
});

// The inbox whose widget the replies are drawn like; null falls back to the brand colour.
const selectedInbox = defineModel({ type: Object, default: null });

const { t } = useI18n();
const store = useStore();
const connectedInboxes = useMapGetter('captainInboxes/getRecords');

const widgetInboxes = computed(() =>
  connectedInboxes.value.filter(
    inbox => inbox.channel_type === 'Channel::WebWidget'
  )
);

const options = computed(() => [
  { value: 0, label: t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.DEFAULT_LOOK') },
  ...widgetInboxes.value.map(inbox => ({
    value: inbox.id,
    label: t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.INBOX_LOOK', {
      name: inbox.name,
    }),
  })),
]);

const selectedId = computed({
  get: () => selectedInbox.value?.id ?? 0,
  set: id => {
    selectedInbox.value = widgetInboxes.value.find(i => i.id === id) ?? null;
  },
});

const handleDemoClick = event => {
  if (!selectedInbox.value) {
    event.preventDefault();
    return;
  }
  event.preventDefault();
  window.open(demoUrl(selectedInbox.value), '_blank', 'noopener,noreferrer');
};

const loadInboxes = async () => {
  selectedInbox.value = null;
  await store.dispatch('captainInboxes/get', {
    assistantId: props.assistantId,
  });
  selectedInbox.value = widgetInboxes.value[0] ?? null;
};

onMounted(loadInboxes);
watch(() => props.assistantId, loadInboxes);
</script>

<template>
  <div class="flex items-center gap-2">
    <Select
      v-if="widgetInboxes.length > 1"
      v-model="selectedId"
      :options="options"
      :aria-label="t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.INBOX_LABEL')"
    />
    <a
      v-if="selectedInbox?.demo_mode_enabled"
      :href="demoUrl(selectedInbox)"
      target="_blank"
      rel="noopener noreferrer"
      data-test="playground-demo-link"
      @click="handleDemoClick"
    >
      <NextButton
        ghost
        sm
        slate
        class="pointer-events-none"
        icon="i-lucide-external-link"
        :label="t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.OPEN_DEMO')"
      />
    </a>
  </div>
</template>
