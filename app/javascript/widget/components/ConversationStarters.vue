<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  starters: { type: Array, default: () => [] },
});

const emit = defineEmits(['select']);

const widgetColor = useMapGetter('appConfig/getWidgetColor');
const widgetTextColor = useMapGetter('appConfig/getWidgetTextColor');
const activeStarters = computed(() =>
  props.starters.filter(starter => starter.enabled !== false && starter.title)
);
</script>

<template>
  <div
    v-show="activeStarters.length"
    class="flex flex-col gap-1 rounded-xl bg-n-background p-2 shadow outline outline-1 outline-n-container dark:bg-n-solid-2"
  >
    <button
      v-for="starter in activeStarters"
      :key="starter.id"
      type="button"
      class="flex w-full items-center justify-between gap-3 rounded-lg px-3 py-2.5 text-start text-sm font-medium"
      :style="{ backgroundColor: widgetColor, color: widgetTextColor }"
      @click="emit('select', starter.title)"
    >
      <span>{{ starter.title }}</span>
      <i class="i-lucide-chevron-right size-4 shrink-0 rtl:rotate-180" />
    </button>
  </div>
</template>
