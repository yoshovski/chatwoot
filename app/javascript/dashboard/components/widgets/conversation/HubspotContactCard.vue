<script setup>
import { ref, computed, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStoreGetters } from 'dashboard/composables/store';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { frontendURL } from 'dashboard/helper/URLHelper';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import HubspotAPI from 'dashboard/api/hubspot';

const props = defineProps({
  contactId: { type: [Number, String], required: true },
});

const { t } = useI18n();
const getters = useStoreGetters();
const { run } = useAbortableRequest();

const SUPERSEDED = Symbol('superseded');
const card = ref(null);
const state = ref('loading');

const integrationURL = computed(() =>
  frontendURL(
    `accounts/${getters.getCurrentAccountId.value}/settings/integrations/hubspot`
  )
);

const details = computed(() =>
  [
    [t('CONVERSATION_SIDEBAR.HUBSPOT.FIELDS.EMAIL'), card.value?.email],
    [t('CONVERSATION_SIDEBAR.HUBSPOT.FIELDS.PHONE'), card.value?.phone],
    [
      t('CONVERSATION_SIDEBAR.HUBSPOT.FIELDS.LIFECYCLE_STAGE'),
      card.value?.lifecyclestage,
    ],
    [
      t('CONVERSATION_SIDEBAR.HUBSPOT.FIELDS.LEAD_STATUS'),
      card.value?.hs_lead_status,
    ],
    [t('CONVERSATION_SIDEBAR.HUBSPOT.FIELDS.OWNER'), card.value?.owner_name],
  ]
    .filter(([, value]) => value)
    .map(([label, value]) => ({ label, value }))
);

const fetchCard = async () => {
  state.value = 'loading';
  try {
    const response = await run(
      signal => HubspotAPI.getContact(props.contactId, { signal }),
      { onAbort: SUPERSEDED }
    );
    if (response === SUPERSEDED) return;
    const { data } = response;
    card.value = data;
    if (data.error === 'reauthorize') state.value = 'reauthorize';
    else if (data.error) state.value = 'error';
    else state.value = data.found ? 'found' : 'not_found';
  } catch {
    state.value = 'error';
  }
};

watch(() => props.contactId, fetchCard, { immediate: true });
</script>

<template>
  <div class="px-4 py-2 text-n-slate-12" :data-state="state">
    <div
      v-if="state === 'loading'"
      class="flex items-center justify-center p-4"
    >
      <Spinner :size="32" class="text-n-brand" />
    </div>
    <p v-else-if="state === 'not_found'" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.HUBSPOT.NOT_FOUND') }}
    </p>
    <p v-else-if="state === 'reauthorize'" class="m-0 text-sm text-n-slate-11">
      {{ t('CONVERSATION_SIDEBAR.HUBSPOT.REAUTHORIZE') }}
      <router-link :to="integrationURL" class="text-n-blue-11 hover:underline">
        {{ t('CONVERSATION_SIDEBAR.HUBSPOT.OPEN_SETTINGS') }}
      </router-link>
    </p>
    <p v-else-if="state === 'error'" class="m-0 text-sm text-n-ruby-11">
      {{ t('CONVERSATION_SIDEBAR.HUBSPOT.ERROR') }}
    </p>
    <div v-else class="flex flex-col gap-3">
      <span class="text-sm font-medium text-n-slate-12">
        {{ card.name || card.email }}
      </span>
      <dl class="grid grid-cols-[auto_minmax(0,1fr)] gap-x-3 gap-y-1.5 m-0">
        <template v-for="detail in details" :key="detail.label">
          <dt class="text-sm text-n-slate-11">
            {{ detail.label }}
          </dt>
          <dd class="m-0 text-sm truncate text-n-slate-12">
            {{ detail.value }}
          </dd>
        </template>
      </dl>
      <a
        :href="card.url"
        target="_blank"
        rel="noopener noreferrer"
        class="inline-flex items-center gap-1 text-sm font-medium text-n-blue-11 hover:underline"
      >
        {{ t('CONVERSATION_SIDEBAR.HUBSPOT.OPEN') }}
        <i class="i-lucide-external-link size-3.5" aria-hidden="true" />
      </a>
    </div>
  </div>
</template>
