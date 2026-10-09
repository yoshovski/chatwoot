<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';

const props = defineProps({
  handoff: { type: Object, required: true },
});

const { t } = useI18n();

// Why the run would have handed off, shown on hover so the pill itself stays short.
const reasonText = computed(() => {
  const { source, reason } = props.handoff;
  switch (source) {
    case 'tool':
      return reason
        ? t(
            'CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.TOOL_WITH_REASON',
            {
              reason,
            }
          )
        : t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.TOOL');
    case 'declared':
      return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.DECLARED');
    case 'safety_net':
      return t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.SAFETY_NET');
    default:
      return t(
        'CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF_REASON.EMPTY_RESPONSE'
      );
  }
});
</script>

<template>
  <div class="flex justify-center">
    <span
      v-tooltip="reasonText"
      class="rounded-full bg-n-amber-3 px-3 py-1 text-center text-xs text-n-amber-11"
      data-test="playground-handoff"
    >
      {{ t('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF') }}
    </span>
  </div>
</template>
