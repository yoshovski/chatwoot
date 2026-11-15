<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from 'vue-i18n';
import Icon from 'next/icon/Icon.vue';
import { findSettingsPage } from './settingsSections';

defineProps({
  containScroll: { type: Boolean, default: false },
  keepAlive: {
    type: Boolean,
    default: true,
  },
});

const route = useRoute();
const { t } = useI18n();

// Routes that manage filters/pagination via query params opt out of
// query-keyed remounts, else every filter change rebuilds the page.
const routeKey = computed(() => {
  if (route.meta.reuseOnTabChange) {
    return `${route.name}:${route.params.accountId}:${route.params.inboxId}`;
  }
  return route.meta.reuseOnQueryChange ? route.path : route.fullPath;
});

// The settings frame: a page listed on the settings home links back to it; a page under it
// (such as editing a team) links back to that page. Billing and Channels have no back link.
const back = computed(() => {
  const page = findSettingsPage(route.name);
  if (!page) return null;
  if (page.route === route.name) {
    return { to: { name: 'settings_home' }, label: t('SETTINGS_HOME.BACK') };
  }
  return {
    to: { name: page.route },
    // eslint-disable-next-line @intlify/vue-i18n/no-dynamic-keys -- Key from the fixed settings list.
    label: t(`SETTINGS_HOME.PAGES.${page.key}.LABEL`),
  };
});
</script>

<template>
  <div
    class="flex min-h-0 w-full h-full flex-col overflow-auto bg-n-background pb-8 pt-4"
    :class="{ 'overscroll-contain': containScroll }"
  >
    <div class="mx-auto flex w-full max-w-[64rem] flex-col gap-2 px-4 sm:px-6">
      <router-link
        v-if="back"
        :to="back.to"
        class="inline-flex w-fit items-center gap-1 pt-2 text-sm font-medium text-n-slate-11 hover:text-n-blue-11"
      >
        <Icon icon="i-lucide-arrow-left" class="size-4 rtl:rotate-180" />
        {{ back.label }}
      </router-link>
      <router-view v-slot="{ Component }">
        <keep-alive v-if="keepAlive">
          <component :is="Component" :key="routeKey" />
        </keep-alive>
        <component :is="Component" v-else :key="routeKey" />
      </router-view>
    </div>
  </div>
</template>
