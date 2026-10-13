<script setup>
import { computed } from 'vue';
import { useFunctionGetter } from 'dashboard/composables/store.js';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import { accentAttrs } from './playgroundAccent';

const props = defineProps({
  assistantId: { type: Number, required: true },
  widgetColor: { type: String, default: '' },
  widgetTextColor: { type: String, default: '' },
});

const assistant = useFunctionGetter(
  'captainAssistants/getRecord',
  computed(() => props.assistantId)
);
</script>

<template>
  <div
    class="flex items-center gap-2.5 rounded-lg px-3 py-1.5"
    v-bind="accentAttrs(widgetColor, widgetTextColor)"
  >
    <Avatar
      :name="assistant.name || ''"
      :src="assistant.avatar_url"
      rounded-full
      :size="24"
    />
    <span class="truncate text-sm font-medium">{{ assistant.name }}</span>
  </div>
</template>
