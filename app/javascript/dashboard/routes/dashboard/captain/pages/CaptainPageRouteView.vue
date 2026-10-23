<script setup>
import { watch } from 'vue';
import { useRoute } from 'vue-router';
import { useUISettings } from 'dashboard/composables/useUISettings';

const route = useRoute();
const { uiSettings, updateUISettings } = useUISettings();

watch(
  () => route.params.assistantId,
  newAssistantId => {
    if (
      newAssistantId &&
      newAssistantId !== String(uiSettings.value.last_active_assistant_id)
    ) {
      updateUISettings({
        last_active_assistant_id: Number(newAssistantId),
      });
    }
  }
);
</script>

<template>
  <!-- min-w-0 lets wide lists shrink so the Copilot panel beside them stays on screen. -->
  <div class="flex w-full h-full min-w-0 min-h-0">
    <section
      class="flex flex-1 h-full min-w-0 px-0 overflow-hidden bg-n-surface-1"
    >
      <router-view />
    </section>
  </div>
</template>
