<script setup>
import SettingsHelp from './SettingsHelp.vue';
defineProps({
  helpNote: { type: String, default: '' },
  title: {
    type: String,
    default: '',
  },
  description: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <section
    class="flex flex-col px-5 py-4 rounded-xl outline outline-1 outline-n-weak bg-n-solid-1"
  >
    <header v-if="title" class="flex flex-col gap-0.5 pb-1">
      <div class="flex items-center gap-1">
        <h3 class="m-0 text-sm font-semibold text-n-slate-12">{{ title }}</h3>
        <SettingsHelp
          v-if="helpNote"
          :label="title"
          :text="description"
          :note="helpNote"
        />
      </div>
      <p v-if="description && !helpNote" class="mb-0 text-sm text-n-slate-11">
        {{ description }}
      </p>
    </header>
    <div class="flex flex-col divide-y divide-n-weak">
      <slot />
    </div>
  </section>
</template>
