<script setup>
import { ref, computed, onMounted } from 'vue';
import { useFunctionGetter, useStore } from 'dashboard/composables/store';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import shopifyAPI from 'dashboard/api/integrations/shopify';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';

const store = useStore();
const { t } = useI18n();

const dialogRef = ref(null);
const disconnectDialogRef = ref(null);

const integrationLoaded = ref(false);
const isSubmitting = ref(false);
const isSyncing = ref(false);
const isDisconnecting = ref(false);
const storeUrl = ref('');
const storeUrlError = ref('');
const shopifyHook = ref(null);

const integration = useFunctionGetter('integrations/getIntegration', 'shopify');

const currentState = computed(() => {
  if (!shopifyHook.value) return 'disconnected';
  return (
    shopifyHook.value.state ||
    (integration.value.enabled ? 'connected' : 'disconnected')
  );
});

const shopDomain = computed(() => shopifyHook.value?.shop_domain || '');
const installUrl = computed(() => shopifyHook.value?.install_url || '');
const storefrontUrl = computed(() => shopifyHook.value?.storefront_url || '');

const validateStoreUrl = url => {
  const pattern =
    /^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?\.myshopify\.(?:com|io)$/i;
  return pattern.test(url);
};

const openStoreUrlDialog = () => {
  storeUrl.value = '';
  storeUrlError.value = '';
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const hideStoreUrlModal = () => {
  storeUrl.value = '';
  storeUrlError.value = '';
  isSubmitting.value = false;
};

const openDisconnectDialog = () => {
  if (disconnectDialogRef.value) {
    disconnectDialogRef.value.open();
  }
};

const closeDisconnectDialog = () => {
  if (disconnectDialogRef.value) {
    disconnectDialogRef.value.close();
  }
};

const isTogglingCatalog = ref(false);

const catalogStatus = computed(() => {
  return (
    shopifyHook.value?.catalog_status ||
    (currentState.value === 'connected' ? 'on' : 'off')
  );
});

const catalogStatusLabel = computed(() => {
  switch (catalogStatus.value) {
    case 'on':
      return t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.STATUS.ON');
    case 'importing':
      return t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.STATUS.IMPORTING');
    case 'needs_reconnect':
      return t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.STATUS.NEEDS_RECONNECT');
    case 'off':
      return t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.STATUS.OFF');
    default:
      return catalogStatus.value;
  }
});

const fetchShopifyStatus = async () => {
  try {
    const { data } = await shopifyAPI.getStatus();
    shopifyHook.value = data.hook || data;
  } catch (error) {
    shopifyHook.value = null;
  } finally {
    integrationLoaded.value = true;
  }
};

const handlePauseCatalog = async () => {
  try {
    isTogglingCatalog.value = true;
    const { data } = await shopifyAPI.pauseCatalog();
    shopifyHook.value = data.hook || data;
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.PAUSED_SUCCESS'));
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isTogglingCatalog.value = false;
  }
};

const handleResumeCatalog = async () => {
  try {
    isTogglingCatalog.value = true;
    const { data } = await shopifyAPI.resumeCatalog();
    shopifyHook.value = data.hook || data;
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.RESUMED_SUCCESS'));
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isTogglingCatalog.value = false;
  }
};

const handleStoreUrlSubmit = async () => {
  try {
    storeUrlError.value = '';
    const cleanUrl = storeUrl.value.trim().toLowerCase();
    if (!validateStoreUrl(cleanUrl)) {
      storeUrlError.value = t(
        'INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.INVALID_URL'
      );
      return;
    }

    isSubmitting.value = true;
    const { data } = await shopifyAPI.requestConnection({
      shopDomain: cleanUrl,
    });
    shopifyHook.value = data.hook || data;
    await store.dispatch('integrations/get', 'shopify');
    hideStoreUrlModal();
    if (dialogRef.value) {
      dialogRef.value.close();
    }
  } catch (error) {
    storeUrlError.value = error.response?.data?.error || error.message;
  } finally {
    isSubmitting.value = false;
  }
};

const handleSyncStatus = async () => {
  try {
    isSyncing.value = true;
    const { data } = await shopifyAPI.syncStatus();
    shopifyHook.value = data.hook || data;
    await store.dispatch('integrations/get', 'shopify');
    useAlert(t('INTEGRATION_SETTINGS.SHOPIFY.STATE.STATUS_REFRESHED'));
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isSyncing.value = false;
  }
};

const handleInstall = () => {
  if (installUrl.value) {
    window.open(installUrl.value, '_blank', 'noopener,noreferrer');
  }
};

const handleDisconnect = async () => {
  try {
    isDisconnecting.value = true;
    await shopifyAPI.disconnect();
    shopifyHook.value = null;
    await store.dispatch('integrations/get', 'shopify');
    closeDisconnectDialog();
    useAlert(t('INTEGRATION_SETTINGS.DELETE.API.SUCCESS_MESSAGE'));
  } catch (error) {
    useAlert(error.response?.data?.error || error.message);
  } finally {
    isDisconnecting.value = false;
  }
};

onMounted(async () => {
  await store.dispatch('integrations/get', 'shopify');
  await fetchShopifyStatus();
});
</script>

<template>
  <SettingsLayout :is-loading="!integrationLoaded">
    <template #header>
      <BaseSettingsHeader
        :title="$t('INTEGRATION_SETTINGS.SHOPIFY.HEADER')"
        description=""
        feature-name="shopify_integration"
        :back-button-label="$t('INTEGRATION_SETTINGS.HEADER')"
      />
    </template>
    <template #body>
      <div class="flex flex-col gap-6">
        <!-- Disconnected State -->
        <div
          v-if="currentState === 'disconnected'"
          class="flex flex-col items-start justify-between lg:flex-row lg:items-center p-6 outline outline-n-container outline-1 bg-n-card rounded-xl gap-6"
        >
          <div
            class="flex items-start lg:items-center justify-start flex-1 m-0 gap-6 flex-col lg:flex-row"
          >
            <div
              class="flex h-16 w-16 items-center justify-center flex-shrink-0"
            >
              <img
                :src="`/dashboard/images/integrations/${integration.id || 'shopify'}.png`"
                class="max-w-full rounded-md border border-n-weak shadow-sm block dark:hidden bg-n-alpha-3 dark:bg-n-alpha-2"
              />
              <img
                :src="`/dashboard/images/integrations/${integration.id || 'shopify'}-dark.png`"
                class="max-w-full rounded-md border border-n-weak shadow-sm hidden dark:block bg-n-alpha-3 dark:bg-n-alpha-2"
              />
            </div>
            <div>
              <h3 class="mb-1 text-heading-1 text-n-slate-12">
                {{ integration.name || 'Shopify' }}
              </h3>
              <p class="text-n-slate-11 text-body-main">
                {{ integration.description }}
              </p>
            </div>
          </div>
          <div class="flex justify-center items-center mb-0">
            <Button
              color="teal"
              :label="t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
              @click="openStoreUrlDialog"
            />
          </div>
        </div>

        <!-- Active/In-Progress States -->
        <div
          v-else
          class="flex flex-col p-6 outline outline-n-container outline-1 bg-n-card rounded-xl gap-6"
        >
          <div
            class="flex flex-col lg:flex-row lg:items-center justify-between gap-4"
          >
            <div class="flex items-center gap-4">
              <div
                class="flex h-14 w-14 items-center justify-center flex-shrink-0"
              >
                <img
                  :src="`/dashboard/images/integrations/${integration.id || 'shopify'}.png`"
                  class="max-w-full rounded-md border border-n-weak shadow-sm block dark:hidden bg-n-alpha-3 dark:bg-n-alpha-2"
                />
                <img
                  :src="`/dashboard/images/integrations/${integration.id || 'shopify'}-dark.png`"
                  class="max-w-full rounded-md border border-n-weak shadow-sm hidden dark:block bg-n-alpha-3 dark:bg-n-alpha-2"
                />
              </div>
              <div>
                <h3 class="text-heading-2 text-n-slate-12 font-semibold">
                  {{ shopDomain }}
                </h3>
                <p v-if="storefrontUrl" class="text-xs text-n-slate-11">
                  {{ storefrontUrl }}
                </p>
              </div>
            </div>

            <!-- State Badge -->
            <div>
              <span
                v-if="currentState === 'requested'"
                class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-300"
              >
                {{ t('INTEGRATION_SETTINGS.SHOPIFY.STATE.REQUESTED_TITLE') }}
              </span>
              <span
                v-else-if="currentState === 'pending_install'"
                class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
              >
                {{
                  t('INTEGRATION_SETTINGS.SHOPIFY.STATE.PENDING_INSTALL_TITLE')
                }}
              </span>
              <span
                v-else-if="currentState === 'importing'"
                class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800 dark:bg-purple-900/30 dark:text-purple-300"
              >
                {{ t('INTEGRATION_SETTINGS.SHOPIFY.STATE.IMPORTING_TITLE') }}
              </span>
              <span
                v-else-if="currentState === 'connected'"
                class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-300"
              >
                {{ t('INTEGRATION_SETTINGS.SHOPIFY.STATE.CONNECTED_TITLE') }}
              </span>
              <span
                v-else-if="currentState === 'needs_reconnect'"
                class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-300"
              >
                {{
                  t('INTEGRATION_SETTINGS.SHOPIFY.STATE.NEEDS_RECONNECT_TITLE')
                }}
              </span>
            </div>
          </div>

          <!-- Description Box for State -->
          <div class="rounded-lg bg-n-alpha-2 p-4 text-sm text-n-slate-11">
            <p v-if="currentState === 'requested'">
              {{
                t('INTEGRATION_SETTINGS.SHOPIFY.STATE.REQUESTED_DESCRIPTION', {
                  shopDomain,
                })
              }}
            </p>
            <p v-else-if="currentState === 'pending_install'">
              {{
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.STATE.PENDING_INSTALL_DESCRIPTION'
                )
              }}
            </p>
            <p v-else-if="currentState === 'importing'">
              {{
                t('INTEGRATION_SETTINGS.SHOPIFY.STATE.IMPORTING_DESCRIPTION')
              }}
            </p>
            <p v-else-if="currentState === 'connected'">
              {{
                t('INTEGRATION_SETTINGS.SHOPIFY.STATE.CONNECTED_DESCRIPTION', {
                  shopDomain,
                })
              }}
            </p>
            <p v-else-if="currentState === 'needs_reconnect'">
              {{
                t(
                  'INTEGRATION_SETTINGS.SHOPIFY.STATE.NEEDS_RECONNECT_DESCRIPTION'
                )
              }}
            </p>
          </div>

          <!-- Catalog Knowledge Sync Status -->
          <div
            v-if="currentState === 'connected' || currentState === 'importing'"
            class="flex flex-col sm:flex-row sm:items-center justify-between p-4 rounded-lg border border-n-weak bg-n-alpha-1 gap-4"
          >
            <div>
              <div class="flex items-center gap-2 mb-1">
                <span
                  class="w-2 h-2 rounded-full"
                  :class="{
                    'bg-emerald-500': catalogStatus === 'on',
                    'bg-purple-500': catalogStatus === 'importing',
                    'bg-amber-500': catalogStatus === 'needs_reconnect',
                    'bg-slate-400': catalogStatus === 'off'
                  }"
                />
                <h4
                  class="text-xs font-semibold text-n-slate-12 uppercase tracking-wide"
                >
                  {{ t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.STATUS_TITLE') }}:
                  <span class="text-n-slate-12 font-bold">{{
                    catalogStatusLabel
                  }}</span>
                </h4>
              </div>
              <p class="text-xs text-n-slate-11">
                {{ t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.DESCRIPTION') }}
              </p>
            </div>
            <div
              v-if="currentState === 'connected'"
              class="flex items-center gap-2 flex-shrink-0"
            >
              <Button
                v-if="catalogStatus === 'off'"
                variant="outline"
                size="sm"
                :is-loading="isTogglingCatalog"
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.RESUME_BUTTON')"
                @click="handleResumeCatalog"
              />
              <Button
                v-else-if="catalogStatus === 'on'"
                variant="outline"
                size="sm"
                :is-loading="isTogglingCatalog"
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.CATALOG.PAUSE_BUTTON')"
                @click="handlePauseCatalog"
              />
            </div>
          </div>

          <!-- Action Buttons -->
          <div
            class="flex flex-wrap items-center justify-between gap-4 pt-2 border-t border-n-weak"
          >
            <div class="flex items-center gap-3">
              <Button
                v-if="currentState === 'pending_install' && installUrl"
                color="teal"
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.STATE.INSTALL_BUTTON')"
                @click="handleInstall"
              />
              <Button
                variant="outline"
                :is-loading="isSyncing"
                :label="
                  currentState === 'pending_install'
                    ? t('INTEGRATION_SETTINGS.SHOPIFY.STATE.CHECK_STATUS')
                    : t('INTEGRATION_SETTINGS.SHOPIFY.STATE.REFRESH')
                "
                @click="handleSyncStatus"
              />
            </div>
            <div>
              <Button
                variant="ghost"
                color="ruby"
                :label="t('INTEGRATION_SETTINGS.SHOPIFY.STATE.DISCONNECT')"
                @click="openDisconnectDialog"
              />
            </div>
          </div>
        </div>

        <!-- Store URL Dialog -->
        <Dialog
          ref="dialogRef"
          :title="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.TITLE')"
          :is-loading="isSubmitting"
          @confirm="handleStoreUrlSubmit"
          @close="hideStoreUrlModal"
        >
          <Input
            v-model="storeUrl"
            :label="t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.LABEL')"
            :placeholder="
              t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.PLACEHOLDER')
            "
            :message="
              !storeUrlError
                ? t('INTEGRATION_SETTINGS.SHOPIFY.STORE_URL.HELP')
                : storeUrlError
            "
            :message-type="storeUrlError ? 'error' : 'info'"
          />
        </Dialog>

        <!-- Disconnect Confirmation Dialog -->
        <Dialog
          ref="disconnectDialogRef"
          type="alert"
          :title="t('INTEGRATION_SETTINGS.SHOPIFY.STATE.DISCONNECT_TITLE')"
          :description="
            t('INTEGRATION_SETTINGS.SHOPIFY.STATE.DISCONNECT_MESSAGE')
          "
          :confirm-button-label="
            t('INTEGRATION_SETTINGS.SHOPIFY.STATE.DISCONNECT')
          "
          :cancel-button-label="
            t('INTEGRATION_SETTINGS.WEBHOOK.DELETE.CONFIRM.NO')
          "
          :is-loading="isDisconnecting"
          @confirm="handleDisconnect"
          @close="closeDisconnectDialog"
        />
      </div>
    </template>
  </SettingsLayout>
</template>
