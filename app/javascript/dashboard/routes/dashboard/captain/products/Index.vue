<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute } from 'vue-router';
import { debounce } from '@chatwoot/utils';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { dynamicTime } from 'shared/helpers/timeHelper';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import PageLayout from 'dashboard/components-next/captain/PageLayout.vue';
import CaptainPaywall from 'dashboard/components-next/captain/pageComponents/Paywall.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';
import Icon from 'dashboard/components-next/icon/Icon.vue';

const PAGE_SIZE = 50;
const THUMBNAIL_WIDTH = 96;
const STATUSES = ['synced', 'pending', 'failed'];
const STATUS_CLASSES = {
  synced: 'bg-n-teal-3 text-n-teal-11',
  pending: 'bg-n-amber-3 text-n-amber-11',
  failed: 'bg-n-ruby-3 text-n-ruby-11',
};

const { t } = useI18n();
const route = useRoute();

const products = ref([]);
const counts = ref({});
const total = ref(0);
const currentPage = ref(1);
const statusFilter = ref(null);
const searchQuery = ref('');
const isFetching = ref(false);
const errorMessage = ref('');

const statusLabels = computed(() => ({
  synced: t('CAPTAIN.PRODUCTS.STATUS.SYNCED'),
  pending: t('CAPTAIN.PRODUCTS.STATUS.PENDING'),
  failed: t('CAPTAIN.PRODUCTS.STATUS.FAILED'),
}));

const tabs = computed(() => {
  const allCount = STATUSES.reduce(
    (sum, status) => sum + (counts.value[status] || 0),
    0
  );
  return [
    { key: null, label: t('CAPTAIN.PRODUCTS.FILTERS.ALL'), count: allCount },
    ...STATUSES.map(status => ({
      key: status,
      label: statusLabels.value[status],
      count: counts.value[status] || 0,
    })),
  ];
});
const activeTabIndex = computed(() =>
  tabs.value.findIndex(tab => tab.key === statusFilter.value)
);
const documentsRoute = computed(() => ({
  name: 'captain_assistants_documents_index',
  params: route.params,
}));

// Shopify's CDN resizes on the fly, so the list never downloads full-size images.
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

const fetchProducts = async (page = 1) => {
  isFetching.value = true;
  try {
    const { data } = await shopifyAPI.getCatalogProducts({
      status: statusFilter.value,
      q: searchQuery.value.trim(),
      page,
    });
    products.value = data.items;
    counts.value = data.counts;
    total.value = data.total;
    currentPage.value = data.page;
    errorMessage.value = '';
  } catch (error) {
    products.value = [];
    total.value = 0;
    errorMessage.value =
      error.response?.data?.error || t('CAPTAIN.PRODUCTS.LOAD_ERROR');
  } finally {
    isFetching.value = false;
  }
};

const debouncedSearch = debounce(() => fetchProducts(1), 300);

const onTabChanged = tab => {
  statusFilter.value = tab.key;
  fetchProducts(1);
};

onMounted(() => fetchProducts(1));
</script>

<template>
  <PageLayout
    :header-title="$t('CAPTAIN.PRODUCTS.HEADER')"
    :back-url="documentsRoute"
    :feature-flag="FEATURE_FLAGS.CAPTAIN"
    :total-count="total"
    :items-per-page="PAGE_SIZE"
    :current-page="currentPage"
    :show-pagination-footer="!isFetching && !!products.length"
    :is-fetching="isFetching"
    :show-know-more="false"
    @update:current-page="fetchProducts"
  >
    <template #search>
      <Input
        v-model="searchQuery"
        :placeholder="$t('CAPTAIN.PRODUCTS.SEARCH_PLACEHOLDER')"
        class="max-w-64 min-w-0 w-full"
        size="sm"
        type="search"
        @input="debouncedSearch"
      />
    </template>

    <template #paywall>
      <CaptainPaywall />
    </template>

    <template #controls>
      <p class="mb-3 text-sm text-n-slate-11">
        {{ $t('CAPTAIN.PRODUCTS.DESCRIPTION') }}
      </p>
      <TabBar
        :tabs="tabs"
        :initial-active-tab="activeTabIndex"
        class="mb-4"
        @tab-changed="onTabChanged"
      />
    </template>

    <template #body>
      <p v-if="errorMessage" class="py-10 text-sm text-center text-n-ruby-11">
        {{ errorMessage }}
      </p>
      <p
        v-else-if="!products.length"
        class="py-10 text-sm text-center text-n-slate-11"
      >
        {{ $t('CAPTAIN.PRODUCTS.EMPTY') }}
      </p>
      <ul
        v-else
        class="flex flex-col divide-y divide-n-weak rounded-xl border border-n-weak"
      >
        <li
          v-for="product in products"
          :key="product.shopify_product_id"
          class="flex items-center gap-3 px-4 py-3"
        >
          <img
            v-if="thumbnailUrl(product.image_url)"
            :src="thumbnailUrl(product.image_url)"
            :alt="product.title || product.handle"
            loading="lazy"
            class="object-cover rounded-md size-12 shrink-0 bg-n-alpha-2"
          />
          <span
            v-else
            class="flex items-center justify-center rounded-md size-12 shrink-0 bg-n-alpha-2 text-n-slate-10"
          >
            <Icon icon="i-lucide-package" class="size-5" />
          </span>
          <div class="flex flex-col min-w-0 flex-1 gap-0.5">
            <span class="text-sm font-medium truncate text-n-slate-12">
              {{ product.title || product.handle }}
            </span>
            <span class="text-xs truncate text-n-slate-11">
              {{ product.handle }}
            </span>
            <span
              v-if="product.last_error && product.status !== 'synced'"
              class="text-xs text-n-ruby-11"
            >
              {{ product.last_error }}
            </span>
          </div>
          <span
            v-if="product.last_synced_at"
            class="hidden text-xs sm:block shrink-0 text-n-slate-11"
          >
            {{ dynamicTime(new Date(product.last_synced_at).getTime() / 1000) }}
          </span>
          <span
            class="px-2 py-0.5 text-xs font-medium rounded-md shrink-0"
            :class="STATUS_CLASSES[product.status]"
          >
            {{ statusLabels[product.status] }}
          </span>
        </li>
      </ul>
    </template>
  </PageLayout>
</template>
