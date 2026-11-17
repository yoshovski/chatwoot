<script setup>
import { useId } from 'vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

defineProps({
  items: { type: Array, required: true },
  unavailable: { type: Boolean, default: false },
});
const headingId = useId();
const iconTones = {
  conversations: 'bg-n-teal-3 text-n-teal-11',
  ai: 'bg-n-violet-3 text-n-violet-11',
  visitors: 'bg-n-blue-3 text-n-blue-11',
};
</script>

<template>
  <section class="flex flex-col gap-2.5" :aria-labelledby="headingId">
    <h2
      :id="headingId"
      class="m-0 font-display text-base font-semibold text-n-slate-12"
    >
      {{ $t('HOME.DASHBOARD.QUICK_ACTIONS') }}
    </h2>
    <div v-if="items.length" class="grid grid-cols-1 gap-2.5 sm:grid-cols-3">
      <RouterLink
        v-for="item in items"
        :key="item.key"
        :to="item.to"
        class="group flex min-h-16 min-w-0 items-center gap-2.5 rounded-card border border-n-container bg-n-solid-2 px-3 py-2.5 hover:border-n-blue-8 focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      >
        <span
          class="grid size-8 shrink-0 place-items-center rounded-md"
          :class="iconTones[item.key]"
        >
          <Icon :icon="item.icon" class="size-4" />
        </span>
        <span class="min-w-0 flex-1">
          <span class="block text-sm font-semibold text-n-slate-12">
            {{ item.label }}
          </span>
          <span class="mt-0.5 block text-xs text-n-slate-11">
            {{ item.detail }}
          </span>
        </span>
        <Icon
          icon="i-lucide-arrow-up-right"
          class="size-3.5 shrink-0 text-n-slate-10 group-hover:text-n-blue-11"
        />
      </RouterLink>
    </div>
    <p v-if="unavailable" class="m-0 text-xs text-n-slate-11">
      {{ $t('HOME.DASHBOARD.LIVE_UNAVAILABLE') }}
    </p>
  </section>
</template>
