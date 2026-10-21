<script setup>
import { computed, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { useMapGetter } from 'dashboard/composables/store';
import Button from 'dashboard/components-next/button/Button.vue';
import CardLayout from 'dashboard/components-next/CardLayout.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Policy from 'dashboard/components/policy.vue';
import ToolChip from 'dashboard/components-next/captain/scenarios/ToolChip.vue';
import ScenarioForm from 'dashboard/components-next/captain/scenarios/ScenarioForm.vue';
import { formatInstructionWithToolChips } from 'dashboard/components-next/captain/scenarios/instructionFormatter';

const props = defineProps({
  id: {
    type: Number,
    required: true,
  },
  title: {
    type: String,
    required: true,
  },
  description: {
    type: String,
    required: true,
  },
  instruction: {
    type: String,
    required: true,
  },
  tools: {
    type: Array,
    default: () => [],
  },
  enabled: {
    type: Boolean,
    default: true,
  },
  isUpdating: {
    type: Boolean,
    default: false,
  },
  selectable: {
    type: Boolean,
    default: false,
  },
  isSelected: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['select', 'hover', 'delete', 'update', 'toggle']);

const { t } = useI18n();
const { formatMessage } = useMessageFormatter();

const modelValue = computed({
  get: () => props.isSelected,
  set: () => emit('select', props.id),
});

const enabledState = computed({
  get: () => props.enabled,
  set: enabled => emit('toggle', { id: props.id, enabled }),
});

const MAX_VISIBLE_TOOLS = 3;
const visibleTools = computed(() => props.tools.slice(0, MAX_VISIBLE_TOOLS));
const hiddenToolCount = computed(
  () => props.tools.length - visibleTools.value.length
);

const state = reactive({
  title: '',
  description: '',
  instruction: '',
});

const scenarioFormRef = ref(null);

const [isEditing, toggleEditing] = useToggle();
const [isInstructionExpanded, toggleInstructionExpanded] = useToggle();
const [showMenu, toggleMenu] = useToggle();

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.MENU.EDIT'),
    action: 'edit',
    value: 'edit',
    icon: 'i-lucide-pencil-line',
  },
  {
    label: t('CAPTAIN.ASSISTANTS.SCENARIOS.MENU.DELETE'),
    action: 'delete',
    value: 'delete',
    icon: 'i-lucide-trash',
  },
]);

const captainTools = useMapGetter('captainTools/getRecords');
const formattedInstruction = computed(() =>
  formatInstructionWithToolChips(props.instruction, captainTools.value, {
    formatMessage,
    unavailableText: t('CAPTAIN.ASSISTANTS.SCENARIOS.TOOLS.UNAVAILABLE'),
  })
);

const startEdit = () => {
  Object.assign(state, {
    title: props.title,
    description: props.description,
    instruction: props.instruction,
  });
  toggleEditing(true);
};

const handleMenuAction = ({ action }) => {
  toggleMenu(false);
  if (action === 'edit') startEdit();
  else emit('delete', props.id);
};

const onClickUpdate = () => {
  if (!scenarioFormRef.value.validate()) return;
  emit('update', { id: props.id, ...state });
  toggleEditing(false);
};

const LINK_INSTRUCTION_CLASS =
  '[&_a[href^="tool://"]]:text-n-iris-11 [&_a:not([href^="tool://"])]:text-n-slate-12 [&_a]:pointer-events-none [&_a]:cursor-default';
</script>

<template>
  <CardLayout
    selectable
    class="relative [&>div]:!py-3"
    :class="{
      '[&>div]:ltr:!pr-3 [&>div]:rtl:!pl-3': !isEditing,
      '[&>div]:ltr:!pr-10 [&>div]:rtl:!pl-10': isEditing,
    }"
    layout="row"
    @mouseenter="emit('hover', true)"
    @mouseleave="emit('hover', false)"
  >
    <div
      v-show="selectable && !isEditing"
      class="absolute top-3.5 ltr:left-3 rtl:right-3"
    >
      <Checkbox v-model="modelValue" />
    </div>

    <div v-if="!isEditing" class="flex flex-col w-full min-w-0">
      <div class="flex items-center w-full gap-3">
        <button
          type="button"
          class="flex flex-col flex-1 min-w-0 p-0 text-start bg-transparent border-0"
          :aria-expanded="isInstructionExpanded"
          @click="toggleInstructionExpanded()"
        >
          <span class="flex items-center gap-1.5 min-w-0">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ title }}
            </span>
            <span
              class="size-3.5 shrink-0 text-n-slate-10 transition-transform i-lucide-chevron-down"
              :class="[{ 'rotate-180': isInstructionExpanded }]"
            />
          </span>
          <span class="text-sm truncate text-n-slate-11">
            {{ description }}
          </span>
        </button>
        <div
          v-if="tools.length"
          class="items-center hidden gap-1 md:flex shrink-0"
        >
          <ToolChip
            v-for="toolId in visibleTools"
            :key="toolId"
            :tool-id="toolId"
          />
          <span v-if="hiddenToolCount" class="text-xs text-n-slate-10">
            {{ `+${hiddenToolCount}` }}
          </span>
        </div>
        <Policy
          as="span"
          :permissions="['administrator']"
          class="inline-flex items-center shrink-0"
        >
          <Switch
            v-model="enabledState"
            :disabled="isUpdating"
            :aria-label="
              t('CAPTAIN.ASSISTANTS.SCENARIOS.STATUS.TOGGLE', { title })
            "
            :class="{ 'opacity-50 cursor-not-allowed': isUpdating }"
          />
        </Policy>
        <div
          v-on-clickaway="() => toggleMenu(false)"
          class="relative flex items-center shrink-0"
        >
          <Button
            icon="i-lucide-ellipsis-vertical"
            slate
            xs
            ghost
            :aria-label="t('CAPTAIN.ASSISTANTS.SCENARIOS.MENU.LABEL')"
            @click="toggleMenu()"
          />
          <DropdownMenu
            v-if="showMenu"
            :menu-items="menuItems"
            class="z-20 mt-1 min-w-36 ltr:right-0 rtl:left-0 top-full"
            @action="handleMenuAction"
          />
        </div>
      </div>

      <div
        v-if="isInstructionExpanded"
        class="flex flex-col gap-2 pt-3 mt-3 border-t border-n-weak"
      >
        <p
          v-dompurify-html:toolLinks="formattedInstruction"
          class="mb-0 text-sm prose-sm prose min-w-0 break-words text-n-slate-12 max-w-none"
          :class="LINK_INSTRUCTION_CLASS"
        />
        <span v-if="!tools.length" class="text-xs text-n-slate-11">
          {{ t('CAPTAIN.ASSISTANTS.SCENARIOS.TOOLS.INHERITED_ALL') }}
        </span>
      </div>
    </div>
    <div v-else class="relative flex flex-col w-full gap-4">
      <ScenarioForm
        ref="scenarioFormRef"
        v-model:title="state.title"
        v-model:description="state.description"
        v-model:instruction="state.instruction"
      />
      <div class="flex items-center gap-3">
        <Button
          faded
          slate
          sm
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.UPDATE.CANCEL')"
          @click="toggleEditing(false)"
        />
        <Button
          sm
          :label="t('CAPTAIN.ASSISTANTS.SCENARIOS.UPDATE.UPDATE')"
          @click="onClickUpdate"
        />
      </div>
    </div>
  </CardLayout>
</template>
