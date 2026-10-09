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
    class="flex items-center gap-3 rounded-xl px-4 py-3"
    v-bind="accentAttrs(widgetColor, widgetTextColor)"
  >
    <Avatar
      :name="assistant.name || ''"
      :src="assistant.avatar_url"
      rounded-full
      :size="32"
    />
    <span class="truncate text-base font-medium">{{ assistant.name }}</span>
  </div>
</template>
