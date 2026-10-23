<script setup>
import { computed, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';
import { useExactTimestamp } from 'shared/composables/useExactTimestamp';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { isPdfDocument } from 'shared/helpers/documentHelper';

import Icon from 'dashboard/components-next/icon/Icon.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Checkbox from 'dashboard/components-next/checkbox/Checkbox.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import { LIST_COLUMNS } from './listColumns';

const props = defineProps({
  id: { type: Number, required: true },
  question: { type: String, required: true },
  answer: { type: String, required: true },
  enabled: { type: Boolean, default: true },
  documentable: { type: Object, default: null },
  updatedAt: { type: Number, required: true },
  usedInConversationsCount: { type: Number, default: 0 },
  // Administrators can select, edit, delete and turn FAQs on or off.
  canManage: { type: Boolean, default: false },
  isSelected: { type: Boolean, default: false },
});
const emit = defineEmits([
  'select',
  'toggle',
  'action',
  'navigate',
  'viewConversations',
]);

const { t } = useI18n();
const { formatMessage, getPlainText } = useMessageFormatter();
const exactTimestamp = useExactTimestamp();
const expanded = ref(false);

const selected = computed({
  get: () => props.isSelected,
  set: () => emit('select', props.id),
});
const enabledState = computed({
  get: () => props.enabled,
  set: enabled => emit('toggle', { id: props.id, enabled }),
});

const showMenu = ref(false);

const menuItems = computed(() => {
  const items = [
    {
      label: t('KNOWLEDGE_LIST.EDIT'),
      action: 'edit',
      value: 'edit',
      icon: 'i-lucide-pencil-line',
    },
  ];
  if (props.documentable?.type === 'User' && props.usedInConversationsCount) {
    items.push({
      label: t('CAPTAIN.DOCUMENTS.USED_IN_CONVERSATIONS', {
        n: props.usedInConversationsCount,
      }),
      action: 'viewConversations',
      value: 'viewConversations',
      icon: 'i-lucide-messages-square',
    });
  }
  items.push({
    label: t('KNOWLEDGE_LIST.DELETE'),
    action: 'delete',
    value: 'delete',
    icon: 'i-lucide-trash',
  });
  return items;
});

const handleMenuAction = ({ action }) => {
  showMenu.value = false;
  if (action === 'viewConversations') {
    emit('viewConversations', props.id);
  } else {
    emit('action', { action, id: props.id });
  }
};

const ORIGINS = {
  page: {
    key: 'FROM_PAGE',
    icon: 'i-lucide-globe',
    tone: 'bg-n-blue-3 text-n-blue-11',
  },
  file: {
    key: 'FROM_FILE',
    icon: 'i-lucide-file-text',
    tone: 'bg-n-ruby-3 text-n-ruby-11',
  },
  conversation: {
    key: 'FROM_CONVERSATION',
    icon: 'i-lucide-messages-square',
    tone: 'bg-n-amber-3 text-n-amber-11',
  },
  hand: {
    key: 'BY_HAND',
    icon: 'i-lucide-pencil',
    tone: 'bg-n-teal-3 text-n-teal-11',
  },
};

const origin = computed(() => {
  const item = props.documentable;
  if (item?.type === 'Captain::Document') {
    const isFile =
      isPdfDocument(item.external_link) ||
      item.external_link?.startsWith('MARKDOWN:');
    return { ...ORIGINS[isFile ? 'file' : 'page'], name: item.name };
  }
  if (item?.type === 'Conversation') {
    return {
      ...ORIGINS.conversation,
      name: t('CAPTAIN.RESPONSES.DOCUMENTABLE.CONVERSATION', {
        id: item.display_id,
      }),
    };
  }
  return { ...ORIGINS.hand, name: item?.available_name || '' };
});
</script>

<template>
  <div
    class="group flex items-start gap-3 px-4 py-3 border-b border-n-weak last:border-b-0 last:rounded-b-xl transition-colors hover:bg-n-alpha-1"
    :class="{ 'bg-n-brand/5': isSelected }"
  >
    <Checkbox
      v-if="canManage"
      v-model="selected"
      class="mt-0.5"
      :aria-label="question"
    />
    <div class="flex flex-col flex-1 min-w-0 gap-1">
      <button
        type="button"
        class="flex items-center gap-1.5 p-0 text-sm font-medium text-start bg-transparent border-0 hover:text-n-blue-11"
        :class="enabled ? 'text-n-slate-12' : 'text-n-slate-11'"
        :aria-expanded="expanded"
        @click="expanded = !expanded"
      >
        <span class="truncate">{{ question }}</span>
        <Icon
          :icon="expanded ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
          class="size-3.5 shrink-0 text-n-slate-10"
        />
      </button>
      <div
        v-if="expanded"
        v-dompurify-html="formatMessage(answer)"
        class="text-sm leading-relaxed text-n-slate-12 [&_p]:mb-2 [&_p:last-child]:mb-0 [&_ul]:ps-5 [&_ul]:list-disc [&_ol]:ps-5 [&_ol]:list-decimal [&_a]:text-n-blue-11 [&_a]:underline"
      />
      <span v-else class="text-xs truncate text-n-slate-11">
        {{ getPlainText(answer) }}
      </span>
    </div>
    <span
      class="items-center gap-1.5 min-w-0 text-xs text-n-slate-11"
      :class="LIST_COLUMNS.from"
    >
      <span
        class="inline-flex items-center justify-center rounded size-5 shrink-0"
        :class="origin.tone"
      >
        <Icon :icon="origin.icon" class="size-3" />
      </span>
      <button
        v-if="documentable?.type === 'Conversation'"
        type="button"
        class="truncate hover:underline"
        @click="emit('navigate', documentable)"
      >
        {{ origin.name }}
      </button>
      <span v-else class="truncate" :title="origin.name">
        {{ origin.name || $t(`KNOWLEDGE_LIST.ORIGIN.${origin.key}`) }}
      </span>
    </span>
    <span
      v-tooltip.top="{
        content: exactTimestamp(updatedAt),
        delay: { show: 500, hide: 0 },
      }"
      class="text-xs truncate text-n-slate-10"
      :class="LIST_COLUMNS.updated"
    >
      {{ dynamicTime(updatedAt) }}
    </span>
    <div :class="LIST_COLUMNS.inUse">
      <Switch
        v-if="canManage"
        v-model="enabledState"
        :aria-label="
          enabled ? t('CAPTAIN.RESPONSES.PAUSE') : t('CAPTAIN.RESPONSES.RESUME')
        "
      />
    </div>
    <div
      v-on-clickaway="() => (showMenu = false)"
      class="relative"
      :class="LIST_COLUMNS.actions"
    >
      <Button
        v-if="canManage"
        :aria-label="$t('KNOWLEDGE_LIST.MORE_ACTIONS')"
        icon="i-lucide-ellipsis-vertical"
        color="slate"
        variant="ghost"
        size="xs"
        @click="showMenu = !showMenu"
      />
      <DropdownMenu
        v-if="showMenu"
        :menu-items="menuItems"
        class="z-30 mt-1 top-full ltr:right-0 rtl:left-0 w-56"
        @action="handleMenuAction"
      />
    </div>
  </div>
</template>
