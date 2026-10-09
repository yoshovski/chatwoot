<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { useAlert } from 'dashboard/composables';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import Button from 'dashboard/components-next/button/Button.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const props = defineProps({
  compact: {
    type: Boolean,
    default: false,
  },
  initialHook: {
    type: Object,
    default: null,
  },
  initialProductsData: {
    type: Object,
    default: null,
  },
});

const emit = defineEmits(['resumed']);

const THUMBNAIL_WIDTH = 96;

const { t } = useI18n();
const route = useRoute();
const { checkPermissions } = usePolicy();

const hook = ref(props.initialHook);
const productsData = ref(props.initialProductsData);
const isResuming = ref(false);

const isAdmin = computed(() => checkPermissions(['administrator']));

const isDisconnected = computed(() => {
  if (!hook.value) return true;
  return (
    hook.value.state === 'disconnected' ||
    (!hook.value.id && !hook.value.state) ||
    hook.value.connected === false
  );
});

const catalogStatus = computed(() => {
  if (isDisconnected.value) return 'not_connected';
  if (hook.value?.catalog_status) return hook.value.catalog_status;
  if (hook.value?.state === 'needs_reconnect') return 'needs_reconnect';
  if (hook.value?.state === 'importing') return 'importing';
  return 'off';
});

const counts = computed(() => productsData.value?.counts || {});
const total = computed(() => productsData.value?.total || 0);

const syncedCount = computed(() => counts.value.synced || 0);
const failedCount = computed(() => counts.value.failed || 0);

const importPercent = computed(() => {
  if (!total.value || total.value <= 0) return 0;
  return Math.min(
    100,
    Math.max(0, Math.round((syncedCount.value / total.value) * 100))
  );
});

const thumbnailUrl = url => {
  if (!url) return null;
  try {
    const parsed = new URL(url);
    if (parsed.hostname === 'cdn.shopify.com') {
      parsed.searchParams.set('width', THUMBNAIL_WIDTH);
    }
    return parsed.toString();
  } catch {
    return null;
  }
};

const productThumbnails = computed(() => {
  const items = productsData.value?.items || [];
  return items
    .filter(item => Boolean(item?.image_url))
    .slice(0, 5)
    .map(item => thumbnailUrl(item.image_url))
    .filter(Boolean);
});

const productsRoute = computed(() => ({
  name: 'captain_assistants_products_index',
  params: route.params,
}));

const productsFailedRoute = computed(() => ({
  name: 'captain_assistants_products_index',
  params: route.params,
  query: { status: 'failed' },
}));

const shopifySettingsRoute = computed(() => ({
  name: 'settings_integrations_shopify',
  params: { accountId: route.params?.accountId },
}));

const fetchProducts = async () => {
  try {
    const { data } = await shopifyAPI.getCatalogProducts({ page: 1 });
    productsData.value = data;
  } catch {
    // Keep empty counts if products cannot be fetched
  }
};

const fetchStatus = async () => {
  try {
    const { data } = await shopifyAPI.getStatus();
    const fetchedHook = data.hook || data;
    hook.value = fetchedHook;

    const status =
      fetchedHook?.catalog_status ||
      (fetchedHook?.state === 'connected' ? 'on' : null);

    if (status === 'on' || status === 'importing') {
      await fetchProducts();
    }
  } catch {
    hook.value = null;
  }
};

const handleResume = async () => {
  isResuming.value = true;
  try {
    const { data } = await shopifyAPI.resumeCatalog();
    hook.value = data.hook || data;
    emit('resumed');
    useAlert(t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RESUME_SUCCESS'));
    await fetchProducts();
  } catch (error) {
    useAlert(
      error?.response?.data?.error ||
        t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RESUME_ERROR')
    );
  } finally {
    isResuming.value = false;
  }
};

onMounted(() => {
  if (!props.initialHook) {
    fetchStatus();
  } else if (
    !props.initialProductsData &&
    (props.initialHook.catalog_status === 'on' ||
      props.initialHook.catalog_status === 'importing')
  ) {
    fetchProducts();
  }
});
</script>

<template>
  <div>
    <div
      v-if="!isDisconnected || isAdmin"
      class="w-full transition-all duration-200"
    >
      <!-- Compact layout for Products tab -->
      <div
        v-if="compact"
        class="flex flex-wrap items-center justify-between gap-3 px-4 py-3 mb-4 rounded-xl border text-sm"
        :class="{
          'border-n-teal-6/40 bg-gradient-to-r from-n-teal-2/40 via-n-teal-1/20 to-transparent dark:from-n-teal-3/10 dark:via-n-teal-2/5 dark:to-transparent':
            catalogStatus === 'on',
          'border-n-amber-6/40 bg-gradient-to-r from-n-amber-2/30 via-n-amber-1/10 to-transparent dark:from-n-amber-3/10 dark:via-n-amber-2/5 dark:to-transparent':
            catalogStatus === 'importing',
          'border-n-ruby-8/70 bg-gradient-to-r from-n-ruby-2/30 via-n-ruby-1/10 to-transparent dark:from-n-ruby-3/10 dark:via-n-ruby-2/5 dark:to-transparent':
            catalogStatus === 'needs_reconnect',
          'border-n-weak bg-n-alpha-2 opacity-85':
            catalogStatus === 'off' || catalogStatus === 'not_connected',
        }"
      >
        <div class="flex items-center gap-3 min-w-0">
          <span
            class="flex items-center justify-center size-8 rounded-lg shrink-0"
            :class="{
              'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400':
                catalogStatus === 'on',
              'bg-amber-500/10 text-amber-600 dark:text-amber-400':
                catalogStatus === 'importing',
              'bg-ruby-500/10 text-ruby-600 dark:text-ruby-400':
                catalogStatus === 'needs_reconnect',
              'bg-n-slate-3 text-n-slate-10':
                catalogStatus === 'off' || catalogStatus === 'not_connected',
            }"
          >
            <Icon icon="i-lucide-shopping-bag" class="size-4" />
          </span>

          <div class="flex flex-col min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-medium text-n-slate-12 truncate">
                {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE') }}
              </span>
              <span
                v-if="catalogStatus === 'on'"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-700 dark:text-emerald-400"
              >
                <span class="size-1.5 rounded-full bg-emerald-500" />
                {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.LIVE') }}
              </span>
              <span
                v-else-if="catalogStatus === 'importing'"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-amber-500/10 text-amber-700 dark:text-amber-400"
              >
                <span
                  class="size-1.5 rounded-full bg-amber-500 animate-pulse"
                />
                {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.IMPORTING') }}
              </span>
              <span
                v-else-if="catalogStatus === 'needs_reconnect'"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-ruby-500/10 text-ruby-700 dark:text-ruby-400"
              >
                <span class="size-1.5 rounded-full bg-ruby-500" />
                {{
                  $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.NEEDS_RECONNECT')
                }}
              </span>
              <span
                v-else-if="catalogStatus === 'off'"
                class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium bg-n-slate-3 text-n-slate-11"
              >
                <span class="size-1.5 rounded-full bg-n-slate-7" />
                {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.PAUSED') }}
              </span>
            </div>

            <div class="text-xs text-n-slate-11 flex items-center gap-2 mt-0.5">
              <template v-if="catalogStatus === 'on'">
                <span>
                  {{
                    $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SYNCED_COUNT', {
                      count: syncedCount,
                    })
                  }}
                </span>
                <router-link
                  v-if="failedCount > 0"
                  :to="productsFailedRoute"
                  class="font-medium text-amber-700 dark:text-amber-400 hover:underline inline-flex items-center gap-1"
                >
                  <Icon icon="i-lucide-alert-triangle" class="size-3" />
                  {{
                    $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.FAILED_ATTENTION', {
                      count: failedCount,
                    })
                  }}
                </router-link>
              </template>
              <template v-else-if="catalogStatus === 'importing'">
                <span>
                  {{
                    $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.IMPORTING_PROGRESS', {
                      synced: syncedCount,
                      total,
                      percent: importPercent,
                    })
                  }}
                </span>
              </template>
              <template v-else-if="catalogStatus === 'needs_reconnect'">
                <span class="text-n-ruby-11">
                  {{
                    $t(
                      'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.NEEDS_RECONNECT_DESCRIPTION'
                    )
                  }}
                </span>
              </template>
              <template v-else-if="catalogStatus === 'off'">
                <span>
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.PAUSED_DESCRIPTION') }}
                </span>
              </template>
              <template v-else-if="catalogStatus === 'not_connected'">
                <span>
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.TITLE') }}
                </span>
              </template>
            </div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <Button
            v-if="catalogStatus === 'off' && isAdmin"
            :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RESUME')"
            size="xs"
            variant="faded"
            color="slate"
            :is-loading="isResuming"
            @click="handleResume"
          />
          <router-link
            v-if="catalogStatus === 'not_connected' && isAdmin"
            :to="shopifySettingsRoute"
          >
            <Button
              :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BUTTON')"
              size="xs"
              variant="solid"
              color="teal"
            />
          </router-link>
          <router-link
            v-else-if="catalogStatus === 'needs_reconnect'"
            :to="shopifySettingsRoute"
          >
            <Button
              :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RECONNECT')"
              size="xs"
              variant="faded"
              color="ruby"
            />
          </router-link>
          <router-link v-else :to="shopifySettingsRoute">
            <Button
              :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS')"
              size="xs"
              variant="ghost"
              color="slate"
            />
          </router-link>
        </div>
      </div>

      <!-- Full card for Sources tab -->
      <div
        v-else
        class="w-full rounded-2xl border p-5 sm:p-6 mb-6 transition-all duration-200"
        :class="{
          'border-n-teal-6/40 bg-gradient-to-br from-n-teal-2/50 via-n-teal-1/20 to-transparent dark:from-n-teal-3/15 dark:via-n-teal-2/5 dark:to-transparent':
            catalogStatus === 'on',
          'border-n-amber-6/40 bg-gradient-to-br from-n-amber-2/40 via-n-amber-1/15 to-transparent dark:from-n-amber-3/15 dark:via-n-amber-2/5 dark:to-transparent':
            catalogStatus === 'importing',
          'border-n-ruby-8/70 bg-gradient-to-br from-n-ruby-2/40 via-n-ruby-1/15 to-transparent dark:from-n-ruby-3/15 dark:via-n-ruby-2/5 dark:to-transparent':
            catalogStatus === 'needs_reconnect',
          'border-n-weak bg-n-alpha-2 opacity-85': catalogStatus === 'off',
          'border-n-teal-6/30 bg-gradient-to-br from-n-teal-2/40 via-n-teal-1/20 to-transparent dark:from-n-teal-3/10 dark:via-n-teal-2/5 dark:to-transparent':
            catalogStatus === 'not_connected',
        }"
      >
        <!-- STATE: NOT CONNECTED (UPSELL) -->
        <template v-if="catalogStatus === 'not_connected'">
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-6"
          >
            <div class="flex flex-col gap-3 max-w-xl">
              <div class="flex items-center gap-2.5">
                <span
                  class="flex items-center justify-center size-9 rounded-xl bg-n-teal-3 text-n-teal-11 dark:bg-n-teal-4/20 dark:text-n-teal-10 shadow-xs"
                >
                  <Icon icon="i-lucide-shopping-bag" class="size-5" />
                </span>
                <h2 class="text-base sm:text-lg font-semibold text-n-slate-12">
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.TITLE') }}
                </h2>
              </div>

              <ul
                class="flex flex-col gap-2 text-xs sm:text-sm text-n-slate-11 ps-1"
              >
                <li class="flex items-center gap-2">
                  <Icon
                    icon="i-lucide-check"
                    class="size-4 text-n-teal-11 shrink-0"
                  />
                  <span>
                    {{
                      $t(
                        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.PRICES_STOCK'
                      )
                    }}
                  </span>
                </li>
                <li class="flex items-center gap-2">
                  <Icon
                    icon="i-lucide-check"
                    class="size-4 text-n-teal-11 shrink-0"
                  />
                  <span>
                    {{
                      $t(
                        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.PRODUCT_CARDS'
                      )
                    }}
                  </span>
                </li>
                <li class="flex items-center gap-2">
                  <Icon
                    icon="i-lucide-check"
                    class="size-4 text-n-teal-11 shrink-0"
                  />
                  <span>
                    {{
                      $t(
                        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.ORDER_TRACKING'
                      )
                    }}
                  </span>
                </li>
              </ul>
            </div>

            <div class="shrink-0">
              <router-link :to="shopifySettingsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BUTTON')"
                  variant="solid"
                  color="teal"
                  icon="i-lucide-arrow-right"
                  trailing-icon
                />
              </router-link>
            </div>
          </div>
        </template>

        <!-- STATE: ON -->
        <template v-else-if="catalogStatus === 'on'">
          <div class="flex flex-col gap-4">
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2.5">
                <span
                  class="flex items-center justify-center size-9 rounded-xl bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 shadow-xs"
                >
                  <Icon icon="i-lucide-shopping-bag" class="size-5" />
                </span>
                <span class="text-sm font-semibold text-n-slate-12">
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE') }}
                </span>
                <span
                  class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-emerald-500/10 text-emerald-700 dark:text-emerald-400"
                >
                  <span class="size-1.5 rounded-full bg-emerald-500" />
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.LIVE') }}
                </span>
              </div>

              <!-- Overlapping product thumbnails stack -->
              <div
                v-if="productThumbnails.length"
                class="flex items-center -space-x-2.5 rtl:space-x-reverse overflow-hidden py-1"
              >
                <img
                  v-for="(img, idx) in productThumbnails"
                  :key="idx"
                  :src="img"
                  alt="Product thumbnail"
                  loading="lazy"
                  class="size-8 rounded-full object-cover ring-2 ring-white dark:ring-n-solid-2 border border-n-weak bg-white shrink-0"
                />
              </div>
            </div>

            <div class="flex flex-col gap-1">
              <div class="flex items-baseline gap-2">
                <span
                  class="text-2xl sm:text-3xl font-bold tracking-tight text-n-slate-12"
                >
                  {{ syncedCount }}
                </span>
                <span class="text-sm font-medium text-n-slate-11">
                  {{
                    $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SYNCED_COUNT', {
                      count: syncedCount,
                    })
                  }}
                </span>
              </div>

              <p class="text-xs sm:text-sm text-n-slate-11">
                {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.ON_DESCRIPTION') }}
              </p>

              <div v-if="failedCount > 0" class="mt-1">
                <router-link
                  :to="productsFailedRoute"
                  class="inline-flex items-center gap-1 text-xs font-medium text-amber-700 dark:text-amber-400 hover:underline"
                >
                  <Icon icon="i-lucide-alert-triangle" class="size-3.5" />
                  <span>
                    {{
                      $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.FAILED_ATTENTION', {
                        count: failedCount,
                      })
                    }}
                  </span>
                </router-link>
              </div>
            </div>

            <div class="flex items-center gap-3 pt-1">
              <router-link :to="productsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.VIEW_PRODUCTS')"
                  size="sm"
                  variant="solid"
                  color="teal"
                />
              </router-link>
              <router-link :to="shopifySettingsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS')"
                  size="sm"
                  variant="ghost"
                  color="slate"
                />
              </router-link>
            </div>
          </div>
        </template>

        <!-- STATE: IMPORTING -->
        <template v-else-if="catalogStatus === 'importing'">
          <div class="flex flex-col gap-4">
            <div class="flex items-center justify-between gap-4">
              <div class="flex items-center gap-2.5">
                <span
                  class="flex items-center justify-center size-9 rounded-xl bg-amber-500/10 text-amber-600 dark:text-amber-400 shadow-xs"
                >
                  <Icon icon="i-lucide-shopping-bag" class="size-5" />
                </span>
                <span class="text-sm font-semibold text-n-slate-12">
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE') }}
                </span>
                <span
                  class="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium bg-amber-500/10 text-amber-700 dark:text-amber-400"
                >
                  <span
                    class="size-1.5 rounded-full bg-amber-500 animate-pulse"
                  />
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.IMPORTING') }}
                </span>
              </div>
            </div>

            <div class="flex flex-col gap-2">
              <div class="flex items-center gap-2">
                <span class="size-2 rounded-full bg-amber-500 animate-pulse" />
                <h3 class="text-sm font-medium text-n-slate-12">
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.IMPORTING_TITLE') }}
                </h3>
              </div>

              <!-- Progress bar -->
              <div
                class="w-full bg-n-alpha-2 rounded-full h-2 overflow-hidden border border-n-weak"
              >
                <div
                  class="bg-amber-500 h-full rounded-full transition-all duration-300"
                  :style="{ width: `${importPercent}%` }"
                />
              </div>

              <p class="text-xs text-n-slate-11">
                {{
                  $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.IMPORTING_PROGRESS', {
                    synced: syncedCount,
                    total,
                    percent: importPercent,
                  })
                }}
              </p>
            </div>

            <div class="pt-1">
              <router-link :to="shopifySettingsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS')"
                  size="sm"
                  variant="ghost"
                  color="slate"
                />
              </router-link>
            </div>
          </div>
        </template>

        <!-- STATE: NEEDS_RECONNECT -->
        <template v-else-if="catalogStatus === 'needs_reconnect'">
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-4"
          >
            <div class="flex items-start gap-3">
              <span
                class="flex items-center justify-center size-9 rounded-xl bg-ruby-500/10 text-ruby-600 dark:text-ruby-400 shrink-0 shadow-xs"
              >
                <Icon icon="i-lucide-alert-triangle" class="size-5" />
              </span>
              <div class="flex flex-col gap-0.5">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE') }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium bg-ruby-500/10 text-ruby-700 dark:text-ruby-400"
                  >
                    <span class="size-1.5 rounded-full bg-ruby-500" />
                    {{
                      $t(
                        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.NEEDS_RECONNECT'
                      )
                    }}
                  </span>
                </div>
                <p class="text-xs sm:text-sm text-n-ruby-11">
                  {{
                    $t(
                      'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.NEEDS_RECONNECT_DESCRIPTION'
                    )
                  }}
                </p>
              </div>
            </div>

            <div class="shrink-0">
              <router-link :to="shopifySettingsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RECONNECT')"
                  size="sm"
                  variant="solid"
                  color="ruby"
                />
              </router-link>
            </div>
          </div>
        </template>

        <!-- STATE: OFF (PAUSED) -->
        <template v-else-if="catalogStatus === 'off'">
          <div
            class="flex flex-col sm:flex-row sm:items-center justify-between gap-4"
          >
            <div class="flex items-center gap-3">
              <span
                class="flex items-center justify-center size-9 rounded-xl bg-n-slate-3 text-n-slate-10 shrink-0"
              >
                <Icon icon="i-lucide-shopping-bag" class="size-5" />
              </span>
              <div class="flex flex-col gap-0.5">
                <div class="flex items-center gap-2">
                  <span class="text-sm font-semibold text-n-slate-12">
                    {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE') }}
                  </span>
                  <span
                    class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-medium bg-n-slate-3 text-n-slate-11"
                  >
                    <span class="size-1.5 rounded-full bg-n-slate-7" />
                    {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.PAUSED') }}
                  </span>
                </div>
                <p class="text-xs sm:text-sm text-n-slate-11">
                  {{ $t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.PAUSED_DESCRIPTION') }}
                </p>
              </div>
            </div>

            <div class="flex items-center gap-2 shrink-0">
              <Button
                v-if="isAdmin"
                :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RESUME')"
                size="sm"
                variant="faded"
                color="slate"
                :is-loading="isResuming"
                @click="handleResume"
              />
              <router-link :to="shopifySettingsRoute">
                <Button
                  :label="$t('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS')"
                  size="sm"
                  variant="ghost"
                  color="slate"
                />
              </router-link>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>
