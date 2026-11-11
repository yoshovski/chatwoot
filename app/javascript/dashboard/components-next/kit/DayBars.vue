<script setup>
import { computed } from 'vue';

// Conversations per day, the AI agent's share stacked under the team's. Labels come from the caller.
const props = defineProps({
  // [{ label, ai, team }]
  days: { type: Array, required: true },
  label: { type: String, required: true },
  aiLabel: { type: String, required: true },
  teamLabel: { type: String, required: true },
});

const SLOT = 40;
const BAR = 12;
const HEIGHT = 120;
const GAP = 2;

const bars = computed(() => {
  const max = Math.max(...props.days.map(day => day.ai + day.team), 1);
  return props.days.map((day, index) => {
    const ai = (day.ai / max) * HEIGHT;
    const team = (day.team / max) * HEIGHT;
    return {
      label: day.label,
      x: index * SLOT + (SLOT - BAR) / 2,
      ai: { y: HEIGHT - ai, height: ai },
      team: { y: HEIGHT - ai - team - GAP, height: team },
    };
  });
});
</script>

<template>
  <div class="flex flex-col gap-2">
    <svg
      :viewBox="`0 0 ${days.length * SLOT} ${HEIGHT}`"
      class="h-32 w-full"
      preserveAspectRatio="none"
      role="img"
      :aria-label="label"
    >
      <template v-for="bar in bars" :key="bar.label">
        <rect
          :x="bar.x"
          :y="bar.team.y"
          :width="BAR"
          :height="bar.team.height"
          rx="2"
          class="fill-n-amber-8"
        />
        <rect
          :x="bar.x"
          :y="bar.ai.y"
          :width="BAR"
          :height="bar.ai.height"
          rx="2"
          class="fill-n-blue-9"
        />
      </template>
    </svg>
    <div class="flex text-center text-xs text-n-slate-10">
      <span v-for="bar in bars" :key="bar.label" class="flex-1">
        {{ bar.label }}
      </span>
    </div>
    <div class="flex gap-4 text-xs text-n-slate-11">
      <span class="inline-flex items-center gap-1.5">
        <span class="size-2 rounded-sm bg-n-blue-9" />
        {{ aiLabel }}
      </span>
      <span class="inline-flex items-center gap-1.5">
        <span class="size-2 rounded-sm bg-n-amber-8" />
        {{ teamLabel }}
      </span>
    </div>
  </div>
</template>
