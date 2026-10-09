<script setup>
import { computed, ref, watch, onMounted } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRoute, useRouter } from 'vue-router';
import CaptainAssistant from 'dashboard/api/captain/assistant';
import shopifyAPI from 'dashboard/api/integrations/shopify';
import TabBar from 'dashboard/components-next/tabbar/TabBar.vue';

const props = defineProps({
  activeTab: {
    type: String,
    default: null,
  },
  faqStats: {
    type: Object,
    default: null,
  },
  shopifyHook: {
    type: Object,
    default: null,
  },
  syncedProductsCount: {
    type: Number,
    default: null,
  },
});

const { t } = useI18n();
const route = useRoute();
const router = useRouter();

const internalFaqStats = ref({
  documents: 0,
  approved: 0,
  suggestions: 0,
});
const internalShopifyHook = ref(null);
const internalSyncedProductsCount = ref(null);

const currentAssistantId = computed(() => Number(route.params.assistantId));

const effectiveFaqStats = computed(() => {
  return props.faqStats || internalFaqStats.value;
});

const effectiveShopifyHook = computed(() => {
  return props.shopifyHook !== null
    ? props.shopifyHook
    : internalShopifyHook.value;
});

const isShopifyConnected = computed(() => {
  const hook = effectiveShopifyHook.value;
  return Boolean(
    hook &&
      (hook.state === 'connected' || hook.connected || hook.catalog_status)
  );
});

const isShopifyCatalogOn = computed(() => {
  return effectiveShopifyHook.value?.catalog_status === 'on';
});

const effectiveSyncedProductsCount = computed(() => {
  if (props.syncedProductsCount !== null) {
    return props.syncedProductsCount;
  }
  return internalSyncedProductsCount.value;
});

const tabs = computed(() => {
  const tabList = [
    {
      key: 'sources',
      label: t('CAPTAIN.KNOWLEDGE.TABS.SOURCES'),
    },
    {
      key: 'faqs',
      label: t('CAPTAIN.KNOWLEDGE.TABS.FAQS'),
      count:
        effectiveFaqStats.value.suggestions > 0
          ? effectiveFaqStats.value.suggestions
          : undefined,
    },
  ];

  if (isShopifyConnected.value) {
    tabList.push({
      key: 'products',
      label: t('CAPTAIN.KNOWLEDGE.TABS.PRODUCTS'),
    });
  }

  return tabList;
});

const currentTabKey = computed(() => {
  if (props.activeTab) return props.activeTab;
  if (route.name === 'captain_assistants_responses_index') return 'faqs';
  if (route.name === 'captain_assistants_products_index') return 'products';
  return 'sources';
});

const activeTabIndex = computed(() => {
  const index = tabs.value.findIndex(tab => tab.key === currentTabKey.value);
  return index >= 0 ? index : 0;
});

const fetchStats = async () => {
  if (!currentAssistantId.value) return;

  try {
    const { data } = await CaptainAssistant.getFaqStats({
      assistantId: currentAssistantId.value,
    });
    internalFaqStats.value = {
      documents: Number(data.documents) || 0,
      approved: Number(data.approved) || 0,
      suggestions: Number(data.suggestions) || 0,
    };
  } catch {
    // Keep last known counts if API request fails
  }
};

const fetchShopify = async () => {
  try {
    const { data } = await shopifyAPI.getStatus();
    const hook = data.hook || data;
    internalShopifyHook.value = hook;

    if (hook?.catalog_status === 'on') {
      try {
        const productsResponse = await shopifyAPI.getCatalogProducts({
          page: 1,
        });
        internalSyncedProductsCount.value =
          productsResponse.data.counts?.synced ?? 0;
      } catch {
        internalSyncedProductsCount.value = null;
      }
    }
  } catch {
    internalShopifyHook.value = null;
  }
};

const onTabChanged = tab => {
  if (tab.key === currentTabKey.value) return;

  const targetRoutes = {
    sources: 'captain_assistants_documents_index',
    faqs: 'captain_assistants_responses_index',
    products: 'captain_assistants_products_index',
  };

  const routeName = targetRoutes[tab.key];
  if (routeName) {
    router.push({
      name: routeName,
      params: route.params,
    });
  }
};

watch(currentAssistantId, () => {
  if (props.faqStats === null) {
    fetchStats();
  }
});

onMounted(() => {
  if (props.faqStats === null) {
    fetchStats();
  }
  if (props.shopifyHook === null) {
    fetchShopify();
  }
});
</script>

<template>
  <div class="flex flex-col gap-4 mb-6">
    <div class="flex flex-col gap-1">
      <h1 class="text-xl font-semibold text-n-slate-12">
        {{ $t('CAPTAIN.KNOWLEDGE.TITLE') }}
      </h1>
      <p class="text-sm text-n-slate-11">
        {{ $t('CAPTAIN.KNOWLEDGE.SUBTITLE') }}
      </p>
      <div class="flex items-center gap-2 mt-1 text-xs text-n-slate-11">
        <span>
          {{
            $t('CAPTAIN.KNOWLEDGE.STATS.SOURCES', {
              count: effectiveFaqStats.documents,
            })
          }}
        </span>
        <span>·</span>
        <span>
          {{
            $t('CAPTAIN.KNOWLEDGE.STATS.FAQS', {
              count: effectiveFaqStats.approved,
            })
          }}
        </span>
        <template
          v-if="isShopifyCatalogOn && effectiveSyncedProductsCount !== null"
        >
          <span>·</span>
          <span>
            {{
              $t('CAPTAIN.KNOWLEDGE.STATS.PRODUCTS', {
                count: effectiveSyncedProductsCount,
              })
            }}
          </span>
        </template>
      </div>
    </div>
    <TabBar
      :tabs="tabs"
      :initial-active-tab="activeTabIndex"
      @tab-changed="onTabChanged"
    />
  </div>
</template>
