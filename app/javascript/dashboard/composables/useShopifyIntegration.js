import { computed, ref, watch } from 'vue';
import { useAccount } from './useAccount';
import { useAbortableRequest } from './useAbortableRequest';
import shopifyAPI from 'dashboard/api/integrations/shopify';

export function useShopifyIntegration() {
  const { accountId, currentAccount } = useAccount();
  const enabled = computed(() =>
    Boolean(currentAccount.value?.features?.shopify_integration)
  );
  const hook = ref(null);
  const request = useAbortableRequest();
  const isConnected = computed(
    () =>
      enabled.value &&
      ['connected', 'needs_reconnect', 'importing'].includes(hook.value?.state)
  );
  const refresh = async () => {
    request.abort();
    hook.value = null;
    if (!enabled.value) return;
    try {
      const response = await request.run(signal =>
        shopifyAPI.getStatus({ signal })
      );
      if (response) hook.value = response.data.hook || response.data;
    } catch {
      hook.value = null;
    }
  };
  watch([accountId, enabled], refresh, { immediate: true });
  return { enabled, hook, isConnected, refresh };
}
