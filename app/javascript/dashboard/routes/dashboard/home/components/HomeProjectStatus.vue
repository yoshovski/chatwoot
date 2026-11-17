<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import ListRow from 'dashboard/components-next/kit/ListRow.vue';
import SectionCard from 'dashboard/components-next/kit/SectionCard.vue';

const props = defineProps({
  items: { type: Array, required: true },
  isAdmin: { type: Boolean, default: false },
  site: { type: String, default: '' },
  setupRoute: { type: Object, default: null },
});
const router = useRouter();
const { t } = useI18n();
const itemsWithState = computed(() => {
  const missing = {
    widget: t('HOME.DASHBOARD.INSTALL_UNCONFIRMED'),
    mailbox: t('HOME.DASHBOARD.MAILBOX_NOT_CONNECTED'),
    domain: t('HOME.DASHBOARD.DOMAIN_NOT_CONFIGURED'),
  };
  return props.items.map(item => ({
    ...item,
    hint:
      item.state === 'missing'
        ? missing[item.key]
        : [item.stateLabel, item.key === 'widget' ? props.site : '']
            .filter(Boolean)
            .join(' · '),
  }));
});
</script>

<template>
  <SectionCard
    :title="$t('HOME.STATUS.TITLE')"
    :to="isAdmin ? { name: 'settings_inbox_list' } : null"
    :link-label="$t('HOME.DASHBOARD.MANAGE_CHANNELS')"
  >
    <ul class="m-0 flex list-none flex-col divide-y divide-n-weak p-0">
      <ListRow
        v-for="item in itemsWithState"
        :key="item.key"
        wrap-text
        :title="item.label"
        :tone="item.tone"
        :hint="item.hint"
        :action-label="item.canAct ? item.actionLabel || item.stateLabel : ''"
        @action="router.push(item.to)"
      />
    </ul>
    <RouterLink
      v-if="setupRoute"
      :to="setupRoute"
      class="w-fit text-sm font-medium text-n-blue-11 hover:underline"
    >
      {{ $t('HOME.GETTING_STARTED.TITLE') }}
    </RouterLink>
  </SectionCard>
</template>
