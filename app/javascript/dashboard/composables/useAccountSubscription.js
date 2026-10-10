import { ref, watch } from 'vue';
import { createSharedComposable, useTimeoutPoll } from '@vueuse/core';
import { useAccount } from 'dashboard/composables/useAccount';
import api from 'dashboard/api/accountSubscription';

const REFRESH_INTERVAL = 30000;

export const useAccountSubscription = createSharedComposable(() => {
  const { accountId } = useAccount();
  const billing = ref(null);
  const loading = ref(true);
  const loadFailed = ref(false);
  let generation = 0;

  const refresh = async () => {
    const token = generation;
    try {
      const { data } = await api.get();
      if (token !== generation) return;
      billing.value = data;
      loadFailed.value = false;
    } catch {
      if (token === generation) loadFailed.value = true;
    } finally {
      if (token === generation) loading.value = false;
    }
  };

  watch(
    accountId,
    () => {
      generation += 1;
      billing.value = null;
      loading.value = true;
      loadFailed.value = false;
      refresh();
    },
    { immediate: true }
  );
  useTimeoutPoll(refresh, REFRESH_INTERVAL, { immediate: true });

  return { billing, loading, loadFailed, refresh };
});
