<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';

import Button from 'dashboard/components-next/button/Button.vue';
import Banner from 'dashboard/components-next/banner/Banner.vue';
import HubspotAPI from 'dashboard/api/hubspot';

import Integration from './Integration.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const props = defineProps({
  error: { type: String, default: '' },
});

const { t } = useI18n();
const store = useStore();
const integrationLoaded = ref(false);
const isAuthorizing = ref(false);

const integration = useFunctionGetter('integrations/getIntegration', 'hubspot');
const uiFlags = useMapGetter('integrations/getUIFlags');

const hook = computed(() => integration.value.hooks?.[0]);
const settings = computed(() => hook.value?.settings || {});
const needsReconnect = computed(
  () => !!settings.value.reauthorization_required
);

const authorize = async () => {
  isAuthorizing.value = true;
  try {
    const { data } = await HubspotAPI.generateAuthorization();
    window.location.href = data.url;
  } catch {
    useAlert(t('INTEGRATION_SETTINGS.HUBSPOT.CONNECT_ERROR'));
    isAuthorizing.value = false;
  }
};

onMounted(async () => {
  await store.dispatch('integrations/get', 'hubspot');
  integrationLoaded.value = true;
});
</script>

<template>
  <SettingsLayout :is-loading="!integrationLoaded || uiFlags.isFetching">
    <template #header>
      <BaseSettingsHeader
        :title="t('INTEGRATION_SETTINGS.HUBSPOT.HEADER')"
        description=""
        :back-button-label="t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <Banner v-if="props.error" color="ruby">
          {{ t('INTEGRATION_SETTINGS.HUBSPOT.CONNECT_ERROR') }}
        </Banner>
        <Banner
          v-if="needsReconnect"
          color="amber"
          :action-label="t('INTEGRATION_SETTINGS.HUBSPOT.RECONNECT')"
          @action="authorize"
        >
          {{ t('INTEGRATION_SETTINGS.HUBSPOT.REAUTHORIZE') }}
        </Banner>
        <Integration
          :integration-id="integration.id"
          :integration-name="integration.name"
          :integration-description="integration.description"
          :integration-enabled="integration.enabled"
          :integration-action="integration.enabled ? 'disconnect' : ''"
          :action-button-text="t('INTEGRATION_SETTINGS.HUBSPOT.DISCONNECT')"
          :delete-confirmation-text="{
            title: t('INTEGRATION_SETTINGS.HUBSPOT.DELETE.TITLE'),
            message: t('INTEGRATION_SETTINGS.HUBSPOT.DELETE.MESSAGE'),
          }"
        >
          <template #action>
            <Button
              faded
              blue
              :is-loading="isAuthorizing"
              :label="t('INTEGRATION_SETTINGS.HUBSPOT.CONNECT')"
              @click="authorize"
            />
          </template>
        </Integration>
        <div
          v-if="hook"
          class="flex flex-col gap-1 p-6 outline outline-1 outline-n-container bg-n-card rounded-xl sm:flex-row sm:items-center sm:justify-between"
        >
          <div class="flex flex-col gap-1">
            <span class="text-heading-3 text-n-slate-12">
              {{ t('INTEGRATION_SETTINGS.HUBSPOT.PORTAL.TITLE') }}
            </span>
            <span class="text-body-main text-n-slate-11">
              {{
                t('INTEGRATION_SETTINGS.HUBSPOT.PORTAL.DETAILS', {
                  domain: settings.hub_domain,
                  portalId: settings.portal_id,
                })
              }}
            </span>
          </div>
          <Button
            faded
            slate
            :is-loading="isAuthorizing"
            :label="t('INTEGRATION_SETTINGS.HUBSPOT.RECONNECT')"
            @click="authorize"
          />
        </div>
      </div>
    </template>
  </SettingsLayout>
</template>
