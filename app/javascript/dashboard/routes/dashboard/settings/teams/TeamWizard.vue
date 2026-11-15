<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import Icon from 'next/icon/Icon.vue';
import PageHeader from 'next/kit/PageHeader.vue';

// Creating or editing a team: the header, the three steps in a row, then the current step.
const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  steps: {
    type: Array,
    required: true,
    // [{ route, label }]
  },
});

const route = useRoute();
const current = computed(() =>
  props.steps.findIndex(step => step.route === route.name)
);
</script>

<template>
  <section class="flex w-full min-w-0 flex-col gap-5 pb-5 pt-2">
    <PageHeader :title="title" :description="description" />
    <ol class="m-0 flex list-none flex-wrap items-center gap-2 p-0">
      <li
        v-for="(step, index) in steps"
        :key="step.route"
        class="flex items-center gap-2"
        :aria-current="index === current ? 'step' : undefined"
      >
        <span
          class="inline-flex items-center gap-2 rounded-full px-3 py-1 text-sm font-medium"
          :class="
            index === current
              ? 'bg-n-blue-3 text-n-blue-11'
              : index < current
                ? 'text-n-slate-12'
                : 'text-n-slate-10'
          "
        >
          <Icon
            v-if="index < current"
            icon="i-lucide-circle-check"
            class="size-4 text-n-teal-10"
          />
          <span
            v-else
            class="grid size-5 place-items-center rounded-full text-xs"
            :class="
              index === current
                ? 'bg-n-blue-9 text-white'
                : 'bg-n-alpha-2 text-n-slate-11'
            "
          >
            {{ index + 1 }}
          </span>
          {{ step.label }}
        </span>
        <Icon
          v-if="index < steps.length - 1"
          icon="i-lucide-chevron-right"
          class="size-4 text-n-slate-9 rtl:rotate-180"
        />
      </li>
    </ol>
    <router-view />
  </section>
</template>
