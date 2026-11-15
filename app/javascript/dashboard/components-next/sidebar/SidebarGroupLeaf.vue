<script setup>
import { isVNode, computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import { useSidebarContext } from './provider';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';

const props = defineProps({
  label: { type: String, required: true },
  to: { type: [String, Object], required: true },
  icon: { type: [String, Object], default: null },
  active: { type: Boolean, default: false },
  component: { type: Function, default: null },
  badgeCount: { type: [Number, String], default: 0 },
});

const { resolvePermissions, resolveFeatureFlag } = useSidebarContext();

const shouldRenderComponent = computed(() => {
  return typeof props.component === 'function' || isVNode(props.component);
});
</script>

<template>
  <Policy
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="relative min-w-0 list-none"
  >
    <component
      :is="to ? 'router-link' : 'div'"
      :to="to"
      :title="label"
      :aria-current="active ? 'page' : undefined"
      class="group flex h-9 min-w-0 items-center gap-2.5 rounded-lg px-2.5 text-sm transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-n-brand"
      :class="
        active
          ? 'active bg-n-brand/10 font-medium text-n-blue-11'
          : 'text-n-slate-12 hover:bg-n-alpha-2'
      "
    >
      <component
        :is="component"
        v-if="shouldRenderComponent"
        v-bind="{ label, icon, active, badgeCount }"
      />
      <template v-else>
        <span
          class="grid size-[1.125rem] shrink-0 place-items-center"
          :class="active ? 'text-n-blue-11' : 'text-n-slate-11'"
        >
          <Icon v-if="icon" :icon="icon" class="size-[1.125rem]" />
        </span>
        <span class="min-w-0 flex-1 truncate">{{ label }}</span>
        <SidebarUnreadBadge :count="badgeCount" />
      </template>
    </component>
  </Policy>
</template>
