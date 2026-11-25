<script setup>
import SectionCard from 'next/kit/SectionCard.vue';
import SettingsHelp from 'dashboard/components-next/captain/pageComponents/assistant/settings/SettingsHelp.vue';

defineProps({
  title: { type: String, default: '' },
  help: { type: String, default: '' },
  description: { type: String, default: '' },
});
</script>

<template>
  <SectionCard :title="title" class="!p-4 sm:!p-5">
    <template v-if="help" #actions>
      <SettingsHelp :label="title" :text="help" />
    </template>
    <p v-if="description" class="m-0 text-sm text-n-slate-11">
      {{ description }}
    </p>
    <slot />
  </SectionCard>
</template>
