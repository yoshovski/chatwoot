<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Icon from 'dashboard/components-next/icon/Icon.vue';

// "Learned 6 of 40 pages": what the instant agent and the import have read so far. Never blocks anything. Until the
// pages to import are chosen, the server counts only what is read (learned = total), so that shows as "so far".
const props = defineProps({
  learned: { type: Number, default: 0 },
  total: { type: Number, default: 0 },
  reading: { type: Boolean, default: false },
  onBrand: { type: Boolean, default: false },
});

const { t } = useI18n();

const label = computed(() => {
  if (!props.learned) return t('HOME.GUIDED.FINDING');
  if (props.learned < props.total)
    return t('HOME.GUIDED.LEARNED', {
      learned: props.learned,
      total: props.total,
    });
  return props.reading
    ? t('HOME.GUIDED.LEARNED_SO_FAR', { count: props.learned }, props.learned)
    : t('HOME.GUIDED.LEARNED_ALL', { count: props.learned }, props.learned);
});
const stillReading = computed(
  () => props.reading || props.learned < props.total
);
const percent = computed(() => {
  if (!props.learned) return 0;
  if (props.learned < props.total)
    return Math.round((props.learned / props.total) * 100);
  return stillReading.value ? 15 : 100;
});
</script>

<template>
  <div class="flex flex-col gap-2" aria-live="polite">
    <div class="flex items-center gap-2 text-sm font-medium">
      <Icon
        icon="i-lucide-book-open-check"
        class="size-4 shrink-0"
        :class="onBrand ? 'text-white' : 'text-n-blue-11'"
      />
      <span :class="onBrand ? 'text-white' : 'text-n-slate-12'">
        {{ label }}
      </span>
    </div>
    <div
      class="h-1.5 w-full overflow-hidden rounded-full"
      :class="onBrand ? 'bg-white/25' : 'bg-n-alpha-2'"
    >
      <div
        class="h-full rounded-full transition-all duration-500"
        :class="onBrand ? 'bg-white' : 'bg-n-brand'"
        :style="{ width: `${percent}%` }"
      />
    </div>
    <p
      v-if="stillReading"
      class="mb-0 text-xs"
      :class="onBrand ? 'text-white/85' : 'text-n-slate-11'"
    >
      {{ $t('HOME.GUIDED.LEARNING_MORE') }}
    </p>
  </div>
</template>
