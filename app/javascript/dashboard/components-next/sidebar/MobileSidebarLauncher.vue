<script setup>
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';

defineProps({
  isMobileSidebarOpen: { type: Boolean, default: false },
});
defineEmits(['toggle']);
const { t } = useI18n();
</script>

<template>
  <!-- Keep the existing bottom menu trigger in a reserved row, including threads.
       The routed task and its primary action can never sit underneath it. -->
  <div
    id="mobile-sidebar-launcher"
    class="flex min-h-16 shrink-0 items-center border-t border-n-weak bg-n-background px-4 pt-2 pb-[max(0.5rem,env(safe-area-inset-bottom))] md:hidden"
  >
    <Button
      icon="i-lucide-menu"
      :label="t('PLATFORM_NAV.MENU')"
      :aria-label="t('PLATFORM_NAV.MENU')"
      :aria-expanded="isMobileSidebarOpen"
      aria-controls="co-navigation"
      color="slate"
      variant="ghost"
      lg
      @click="$emit('toggle')"
    />
  </div>
</template>
