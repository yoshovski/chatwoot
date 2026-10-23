<script setup>
import { computed, ref } from 'vue';
import { useToggle } from '@vueuse/core';
import { useI18n } from 'vue-i18n';
import { dynamicTime } from 'shared/helpers/timeHelper';

import CardLayout from 'dashboard/components-next/CardLayout.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';
import Policy from 'dashboard/components/policy.vue';

// One connected MCP server, laid out like a custom tool card, with its tools listed under it.
const props = defineProps({
  server: { type: Object, required: true },
  isUpdating: { type: Boolean, default: false },
});

const emit = defineEmits(['action', 'toggleTool']);

const { t } = useI18n();

const [showActionsDropdown, toggleDropdown] = useToggle();
const showTools = ref(false);

const enabledCount = computed(
  () => props.server.tools.filter(tool => tool.enabled).length
);

const STATUS_CLASSES = {
  connected: 'bg-n-teal-3 text-n-teal-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
  pending: 'bg-n-alpha-2 text-n-slate-11',
};

const menuItems = computed(() => [
  {
    label: t('CAPTAIN.MCP_SERVERS.REFRESH'),
    value: 'refresh',
    action: 'refresh',
    icon: 'i-lucide-refresh-cw',
  },
  {
    label: t('CAPTAIN.MCP_SERVERS.EDIT'),
    value: 'edit',
    action: 'edit',
    icon: 'i-lucide-pencil-line',
  },
  {
    label: t('CAPTAIN.MCP_SERVERS.DELETE'),
    value: 'delete',
    action: 'delete',
    icon: 'i-lucide-trash',
  },
]);

const handleAction = ({ action }) => {
  toggleDropdown(false);
  emit('action', { action, server: props.server });
};
</script>

<template>
  <CardLayout class="relative">
    <div class="relative flex justify-between w-full gap-1">
      <div class="flex items-center min-w-0 gap-2">
        <span
          class="inline-flex items-center justify-center rounded-md size-6 shrink-0 bg-n-iris-3 text-n-iris-11"
        >
          <i class="i-lucide-plug size-3.5" aria-hidden="true" />
        </span>
        <span class="text-base font-medium text-n-slate-12 line-clamp-1">
          {{ server.name }}
        </span>
        <span
          class="px-2 py-0.5 text-xs rounded-full shrink-0"
          :class="STATUS_CLASSES[server.status]"
        >
          {{ t(`CAPTAIN.MCP_SERVERS.STATUS.${server.status.toUpperCase()}`) }}
        </span>
      </div>
      <Policy
        v-on-clickaway="() => toggleDropdown(false)"
        :permissions="['administrator']"
        class="relative flex items-center group"
      >
        <Button
          icon="i-lucide-ellipsis-vertical"
          color="slate"
          size="xs"
          class="rounded-md group-hover:bg-n-alpha-2"
          :is-loading="isUpdating"
          :aria-label="t('CAPTAIN.MCP_SERVERS.ACTIONS')"
          @click="toggleDropdown()"
        />
        <DropdownMenu
          v-if="showActionsDropdown"
          :menu-items="menuItems"
          class="mt-1 ltr:right-0 rtl:right-0 top-full"
          @action="handleAction($event)"
        />
      </Policy>
    </div>
    <div class="flex items-center justify-between w-full min-w-0 gap-4">
      <div class="flex items-center flex-1 min-w-0 gap-3">
        <span class="text-sm truncate text-n-slate-11">
          {{ server.endpoint_url }}
        </span>
        <span
          v-if="server.auth_type !== 'none'"
          class="inline-flex items-center gap-1 text-sm shrink-0 text-n-slate-11"
        >
          <i class="text-base i-lucide-lock" />
          {{
            t(
              `CAPTAIN.MCP_SERVERS.FORM.AUTH_TYPES.${server.auth_type.toUpperCase()}`
            )
          }}
        </span>
      </div>
      <span
        v-if="server.synced_at"
        class="text-sm text-n-slate-11 line-clamp-1 shrink-0"
      >
        {{ dynamicTime(server.synced_at) }}
      </span>
    </div>
    <p
      v-if="server.status === 'failed' && server.last_error"
      class="m-0 text-sm text-n-ruby-11"
    >
      {{ server.last_error }}
    </p>
    <button
      v-if="server.tools.length"
      type="button"
      class="inline-flex items-center self-start gap-1 text-sm font-medium text-n-slate-12 hover:text-n-blue-11"
      :aria-expanded="showTools"
      @click="showTools = !showTools"
    >
      <i
        class="i-lucide-chevron-right size-4 transition-transform rtl:rotate-180"
        :class="{ 'rotate-90 rtl:rotate-90': showTools }"
        aria-hidden="true"
      />
      {{
        t('CAPTAIN.MCP_SERVERS.TOOLS_ON', {
          enabled: enabledCount,
          total: server.tools.length,
        })
      }}
    </button>
    <p
      v-else-if="server.status === 'connected'"
      class="m-0 text-sm text-n-slate-11"
    >
      {{ t('CAPTAIN.MCP_SERVERS.NO_TOOLS') }}
    </p>

    <template #after>
      <ul
        v-if="showTools"
        class="flex flex-col p-0 px-6 pb-5 m-0 divide-y divide-n-weak"
      >
        <li
          v-for="tool in server.tools"
          :key="tool.name"
          class="flex items-start justify-between gap-4 py-3 list-none"
        >
          <div class="flex flex-col min-w-0 gap-0.5">
            <span class="text-sm font-medium text-n-slate-12">
              {{ tool.title }}
            </span>
            <span
              v-if="tool.description"
              class="text-sm text-n-slate-11 line-clamp-2"
            >
              {{ tool.description }}
            </span>
          </div>
          <Policy
            as="span"
            :permissions="['administrator']"
            class="inline-flex items-center pt-1"
          >
            <Switch
              :model-value="tool.enabled"
              :disabled="isUpdating"
              :aria-label="tool.title"
              @update:model-value="
                emit('toggleTool', { server, tool, enabled: $event })
              "
            />
          </Policy>
        </li>
      </ul>
    </template>
  </CardLayout>
</template>
