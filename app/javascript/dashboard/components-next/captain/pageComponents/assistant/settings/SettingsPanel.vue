<script setup>
import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import SidePanel from 'dashboard/components-next/side-panel/SidePanel.vue';

// Side-panel editor for one setting. Edits change the page draft; the page's save bar
// commits them, so every settings page saves the same way.
const props = defineProps({
  title: { type: String, required: true },
  description: { type: String, default: '' },
  width: { type: String, default: 'lg' },
});

const open = defineModel('open', { type: Boolean, default: false });
const { t } = useI18n();
const panel = ref(null);

watch(open, value => {
  if (value) panel.value?.open();
  else panel.value?.close();
});
</script>

<template>
  <SidePanel
    ref="panel"
    :title="props.title"
    :description="props.description"
    :width="props.width"
    @close="open = false"
  >
    <div class="flex flex-col gap-5">
      <slot />
    </div>
    <template #footer>
      <div class="flex justify-end">
        <Button
          type="button"
          variant="faded"
          color="slate"
          :label="t('CAPTAIN.AGENT_UX.DONE')"
          @click="open = false"
        />
      </div>
    </template>
  </SidePanel>
</template>
