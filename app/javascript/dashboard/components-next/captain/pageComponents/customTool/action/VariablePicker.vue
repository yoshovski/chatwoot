<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';

const props = defineProps({
  // { inputs, outputs, contact } from variablesBefore
  variables: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['insert']);
const { t } = useI18n();
const isOpen = ref(false);

const GROUPS = ['inputs', 'outputs', 'contact'];

const menuSections = computed(() =>
  GROUPS.map(group => ({
    title: t(`CAPTAIN.CUSTOM_TOOLS.ACTION.VARIABLES.${group.toUpperCase()}`),
    emptyState: t('CAPTAIN.CUSTOM_TOOLS.ACTION.VARIABLES.EMPTY'),
    items: props.variables[group].map(name => ({
      label: name,
      value: name,
      action: 'insert',
    })),
  }))
);

const handleAction = ({ value }) => {
  emit('insert', `{{ ${value} }}`);
  isOpen.value = false;
};
</script>

<template>
  <div v-on-clickaway="() => (isOpen = false)" class="relative">
    <Button
      type="button"
      size="xs"
      variant="faded"
      color="slate"
      class="font-mono"
      label="{ }"
      :aria-label="t('CAPTAIN.CUSTOM_TOOLS.ACTION.VARIABLES.INSERT')"
      @click="isOpen = !isOpen"
    />
    <DropdownMenu
      v-if="isOpen"
      :menu-sections="menuSections"
      class="z-30 mt-1 top-full ltr:right-0 rtl:left-0 w-60 max-h-72 overflow-y-auto"
      @action="handleAction"
    />
  </div>
</template>
