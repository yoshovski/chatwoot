<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// "Growth trial · 14 days · no card". The plan comes from `?plan=` (the pricing page); Growth without it.
const DEFAULT_PLAN = 'growth';

const route = useRoute();
const planName = computed(() => {
  const plan = String(route.query.plan || DEFAULT_PLAN).toLowerCase();
  return plan.charAt(0).toUpperCase() + plan.slice(1);
});
</script>

<template>
  <p
    class="mb-0 inline-flex items-center gap-1.5 rounded-full bg-n-blue-3 px-3 py-1 text-xs font-medium text-n-blue-11"
  >
    <Icon icon="i-lucide-sparkles" class="size-3.5" />
    {{ $t('REGISTER.PLAN_TRIAL', { plan: planName }) }}
  </p>
</template>
