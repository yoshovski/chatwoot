<script setup>
import { computed, ref, toRef } from 'vue';
import { useI18n } from 'vue-i18n';
import api from 'dashboard/api/accountSubscription';
import Select from 'dashboard/components-next/select/Select.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import { useBillingView } from '../useBillingView';

// What happens at the limit, as one switch: off, the AI pauses and the team takes over; on, a pack is bought.
const props = defineProps({ billing: { type: Object, required: true } });
const emit = defineEmits(['refresh']);
const { t } = useI18n();
const { money, pack } = useBillingView(toRef(props, 'billing'));

const MAX_PACK_OPTIONS = 10;
const saving = ref(false);
const failed = ref(false);
const auto = computed(() => props.billing.top_up.auto);
const switchedOff = computed(
  () => Boolean(auto.value.failed_at) && !auto.value.enabled
);
const packOptions = computed(() =>
  Array.from({ length: MAX_PACK_OPTIONS }, (_, index) => ({
    value: index + 1,
    label: t('BILLING_PAGE.AUTO.MAX_OPTION', { count: index + 1 }, index + 1),
  }))
);

const save = async changes => {
  saving.value = true;
  failed.value = false;
  try {
    await api.updateTopUpSettings({
      auto_top_up_enabled: auto.value.enabled,
      auto_top_up_max_packs: auto.value.max_packs,
      ...changes,
    });
  } catch {
    failed.value = true;
  } finally {
    saving.value = false;
    emit('refresh');
  }
};
</script>

<template>
  <section
    class="flex min-w-0 flex-col gap-2 rounded-card bg-n-solid-2 px-6 py-4 shadow-card outline outline-1 -outline-offset-1 outline-n-container"
  >
    <div class="flex items-center justify-between gap-4">
      <div class="flex min-w-0 flex-col">
        <h2 class="mb-0 text-sm font-medium text-n-slate-12">
          {{ t('BILLING_PAGE.AUTO.TITLE') }}
        </h2>
        <p class="mb-0 text-sm text-n-slate-11">
          {{
            auto.enabled
              ? t('BILLING_PAGE.AUTO.ON', {
                  count: pack.conversations,
                  price: money(pack.amount_cents, pack.currency),
                })
              : t('BILLING_PAGE.AUTO.OFF')
          }}
        </p>
      </div>
      <Switch
        :model-value="auto.enabled"
        :disabled="saving"
        :aria-label="t('BILLING_PAGE.AUTO.TITLE')"
        @update:model-value="value => save({ auto_top_up_enabled: value })"
      />
    </div>
    <div
      v-if="auto.enabled"
      class="flex items-center gap-2 text-sm text-n-slate-11"
    >
      <span>{{ t('BILLING_PAGE.AUTO.MAX_LABEL') }}</span>
      <Select
        :model-value="auto.max_packs"
        :options="packOptions"
        :disabled="saving"
        :aria-label="t('BILLING_PAGE.AUTO.MAX_LABEL')"
        @update:model-value="
          value => save({ auto_top_up_max_packs: Number(value) })
        "
      />
    </div>
    <p v-if="switchedOff" class="mb-0 text-sm text-n-amber-11" role="status">
      {{ t('BILLING_PAGE.AUTO.SWITCHED_OFF') }}
    </p>
    <p v-if="failed" class="mb-0 text-sm text-n-ruby-11" role="alert">
      {{ t('BILLING_PAGE.AUTO.SAVE_ERROR') }}
    </p>
  </section>
</template>
