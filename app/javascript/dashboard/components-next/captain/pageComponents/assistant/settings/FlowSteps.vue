<script setup>
// Vertical diagram of what happens, step by step. Each step: { icon, title, detail?, tone? }.
defineProps({
  title: {
    type: String,
    required: true,
  },
  steps: {
    type: Array,
    required: true,
  },
});

const TONE_CLASSES = {
  blue: 'bg-n-blue-3 text-n-blue-11',
  teal: 'bg-n-teal-3 text-n-teal-11',
  amber: 'bg-n-amber-3 text-n-amber-11',
  slate: 'bg-n-slate-3 text-n-slate-11',
};
</script>

<template>
  <section class="flex flex-col gap-2">
    <span class="text-xs font-medium text-n-slate-11">{{ title }}</span>
    <ol
      class="flex flex-col p-4 m-0 list-none rounded-2xl outline outline-1 outline-n-weak bg-n-solid-1"
    >
      <li
        v-for="(step, index) in steps"
        :key="step.key || index"
        class="relative flex gap-3"
        :class="{ 'pb-5': index < steps.length - 1 }"
      >
        <span
          v-if="index < steps.length - 1"
          class="absolute top-9 bottom-1 w-px ltr:left-[0.9375rem] rtl:right-[0.9375rem] bg-n-weak"
          aria-hidden="true"
        />
        <span
          class="relative flex items-center justify-center rounded-full size-8 shrink-0"
          :class="TONE_CLASSES[step.tone || 'slate']"
          aria-hidden="true"
        >
          <span :class="step.icon" class="size-4" />
        </span>
        <div class="flex flex-col min-w-0 gap-1 pt-1">
          <span class="text-sm font-medium text-n-slate-12">
            {{ step.title }}
          </span>
          <span
            v-if="step.detail"
            class="text-xs break-words whitespace-pre-line text-n-slate-11"
            :class="{
              'px-3 py-2 mt-0.5 rounded-xl bg-n-slate-2 text-n-slate-12 text-sm':
                step.quote,
            }"
          >
            {{ step.detail }}
          </span>
          <ul
            v-if="step.branches?.length"
            class="flex flex-col gap-1.5 p-0 m-0 mt-1 list-none"
          >
            <li
              v-for="branch in step.branches"
              :key="branch.label"
              class="flex items-center gap-2 text-xs text-n-slate-11"
            >
              <span :class="branch.icon" class="size-3.5 shrink-0" />
              {{ branch.label }}
            </li>
          </ul>
        </div>
      </li>
    </ol>
  </section>
</template>
