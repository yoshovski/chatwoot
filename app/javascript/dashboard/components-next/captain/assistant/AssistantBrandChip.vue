<script setup>
import { computed } from 'vue';
import { useMapGetter } from 'dashboard/composables/store';

const props = defineProps({
  name: {
    type: String,
    default: '',
  },
});

const globalConfig = useMapGetter('globalConfig/get');

const brandName = computed(() => globalConfig.value?.captainBrandName);

const isVisible = computed(
  () =>
    Boolean(brandName.value) &&
    props.name.trim().toLowerCase() !== brandName.value.trim().toLowerCase()
);
</script>

<template>
  <span
    v-if="isVisible"
    class="inline-flex items-center px-1.5 py-0.5 text-xs font-medium rounded-md shrink-0 bg-n-alpha-2 text-n-slate-11"
  >
    {{ brandName }}
  </span>
</template>
