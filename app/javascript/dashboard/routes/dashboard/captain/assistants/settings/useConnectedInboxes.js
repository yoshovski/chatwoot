import { ref, watch } from 'vue';
import CaptainInboxes from 'dashboard/api/captain/inboxes';

export function useConnectedInboxes(assistantId) {
  const inboxes = ref([]);
  const status = ref('loading');
  const retryCount = ref(0);

  watch(
    [assistantId, retryCount],
    async ([id], _previous, onCleanup) => {
      let current = true;
      onCleanup(() => {
        current = false;
      });
      status.value = 'loading';
      inboxes.value = [];
      try {
        const { data } = await CaptainInboxes.get({ assistantId: id });
        if (current) {
          inboxes.value = data.payload;
          status.value = 'ready';
        }
      } catch {
        if (current) status.value = 'error';
      }
    },
    { immediate: true }
  );

  const retry = () => {
    retryCount.value += 1;
  };

  return { inboxes, status, retry };
}
