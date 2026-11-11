<script setup>
import { computed } from 'vue';

// A small trend line. Colour comes from the parent's text colour.
const props = defineProps({
  points: { type: Array, required: true },
});

const WIDTH = 100;
const HEIGHT = 32;
const PADDING = 3;

const coordinates = computed(() => {
  const max = Math.max(...props.points);
  const min = Math.min(...props.points);
  const range = max - min || 1;
  const step = WIDTH / (props.points.length - 1);
  return props.points.map((point, index) => [
    Math.round(index * step * 10) / 10,
    Math.round(
      (HEIGHT - PADDING - ((point - min) / range) * (HEIGHT - PADDING * 2)) * 10
    ) / 10,
  ]);
});
const line = computed(() =>
  coordinates.value.map(pair => pair.join(',')).join(' ')
);
const area = computed(() => `0,${HEIGHT} ${line.value} ${WIDTH},${HEIGHT}`);
</script>

<template>
  <svg
    :viewBox="`0 0 ${WIDTH} ${HEIGHT}`"
    preserveAspectRatio="none"
    aria-hidden="true"
  >
    <polygon :points="area" class="fill-current opacity-10" />
    <polyline
      :points="line"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      vector-effect="non-scaling-stroke"
    />
  </svg>
</template>
