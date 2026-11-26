<script setup>
import { computed } from 'vue';

const props = defineProps({
  progress: { type: Object, required: true },
  to: { type: Object, required: true },
});
const emit = defineEmits(['skip']);
const percent = computed(
  () => (props.progress.doneCount / props.progress.total) * 100
);
</script>

<template>
  <section
    class="workspace-widget workspace-inset flex flex-wrap items-center gap-x-4 gap-y-3 rounded-card border border-n-container bg-n-slate-2 px-4 py-4 sm:px-5"
  >
    <div
      class="relative grid size-12 shrink-0 place-items-center sm:size-14"
      role="progressbar"
      :aria-label="$t('HOME.GETTING_STARTED.TITLE')"
      :aria-valuenow="progress.doneCount"
      :aria-valuemax="progress.total"
      aria-valuemin="0"
    >
      <svg
        class="absolute inset-0 size-full -rotate-90"
        viewBox="0 0 56 56"
        aria-hidden="true"
        fill="none"
      >
        <circle
          cx="28"
          cy="28"
          r="24"
          stroke-width="5"
          class="stroke-n-teal-5"
        />
        <circle
          v-if="percent > 0"
          cx="28"
          cy="28"
          r="24"
          pathLength="100"
          stroke-width="5"
          stroke-linecap="round"
          :stroke-dasharray="`${percent} 100`"
          class="stroke-n-teal-9"
        />
      </svg>
      <span
        aria-hidden="true"
        class="text-sm font-semibold tabular-nums text-n-slate-12"
      >
        {{ `${progress.doneCount}/${progress.total}` }}
      </span>
    </div>
    <div class="min-w-40 flex-1">
      <h2
        class="m-0 font-display text-base font-semibold text-n-slate-12 sm:text-lg"
      >
        {{ $t('HOME.DASHBOARD.FINALIZE_SETUP') }}
      </h2>
      <p class="mb-0 mt-1 text-sm text-n-slate-11">
        {{ $t('HOME.DASHBOARD.FINALIZE_SETUP_HINT') }}
      </p>
    </div>
    <div class="ms-auto flex shrink-0 items-center gap-2.5">
      <button
        type="button"
        class="min-h-9 rounded-lg border border-n-slate-6 px-3 text-sm font-medium text-n-slate-12 hover:bg-n-slate-4"
        @click="emit('skip')"
      >
        {{ $t('HOME.SETUP.SKIP') }}
      </button>
      <RouterLink
        :to="to"
        class="inline-flex min-h-9 items-center rounded-lg bg-n-blue-4 px-3 text-sm font-medium text-n-blue-11 hover:bg-n-blue-5"
      >
        {{ $t('HOME.DASHBOARD.FINISH_SETUP') }}
      </RouterLink>
    </div>
  </section>
</template>
