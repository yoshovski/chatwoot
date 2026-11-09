<script setup>
import { useI18n } from 'vue-i18n';

// One numbered step of the API action editor; the number turns into a tick once the step is filled in.
defineProps({
  number: { type: Number, required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  done: { type: Boolean, default: false },
  optional: { type: Boolean, default: false },
});

const { t } = useI18n();
</script>

<template>
  <section class="grid grid-cols-[2rem_minmax(0,1fr)] gap-x-4">
    <div class="flex flex-col items-center">
      <span
        class="flex items-center justify-center text-sm font-semibold rounded-full size-8 shrink-0"
        :class="
          done ? 'bg-n-teal-3 text-n-teal-11' : 'bg-n-alpha-2 text-n-slate-11'
        "
      >
        <span v-if="done" class="i-lucide-check size-4" />
        <template v-else>{{ number }}</template>
      </span>
      <span class="flex-1 w-px mt-2 bg-n-weak" aria-hidden="true" />
    </div>
    <div class="flex flex-col gap-3 pb-10 min-w-0">
      <div class="flex items-start justify-between gap-3 min-h-8">
        <div class="flex flex-col gap-0.5">
          <h2
            class="flex items-center gap-2 m-0 text-base font-semibold text-n-slate-12"
          >
            {{ title }}
            <span
              v-if="optional"
              class="px-1.5 py-0.5 text-xs font-normal rounded-md bg-n-alpha-2 text-n-slate-11"
            >
              {{ t('CAPTAIN.AGENT_UX.API.OPTIONAL') }}
            </span>
          </h2>
          <p v-if="description" class="m-0 text-sm text-n-slate-11">
            {{ description }}
          </p>
        </div>
        <slot name="actions" />
      </div>
      <slot />
    </div>
  </section>
</template>
