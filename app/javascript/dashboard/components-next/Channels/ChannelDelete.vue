<script setup>
import { computed, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import Button from 'next/button/Button.vue';

const props = defineProps({ inbox: { type: Object, required: true } });
const store = useStore();
const router = useRouter();
const { t } = useI18n();
const show = ref(false);
const deleting = ref(false);
const message = computed(
  () => `${t('INBOX_MGMT.DELETE.CONFIRM.MESSAGE')} ${props.inbox.name}?`
);
const remove = async () => {
  if (deleting.value) return;
  deleting.value = true;
  show.value = false;
  try {
    await store.dispatch('inboxes/delete', props.inbox.id);
    useAlert(t('INBOX_MGMT.DELETE.API.SUCCESS_MESSAGE'));
    show.value = false;
    router.push({ name: 'settings_inbox_list' });
  } catch {
    useAlert(t('INBOX_MGMT.DELETE.API.ERROR_MESSAGE'));
  } finally {
    deleting.value = false;
  }
};
</script>

<template>
  <div class="border-t border-n-weak pt-5">
    <Button
      :label="t('CHANNELS.DELETE')"
      :disabled="deleting"
      :is-loading="deleting"
      color="ruby"
      variant="ghost"
      size="sm"
      @click="show = true"
    />
    <woot-confirm-delete-modal
      v-if="show"
      v-model:show="show"
      :title="t('INBOX_MGMT.DELETE.CONFIRM.TITLE')"
      :message="message"
      :confirm-text="t('INBOX_MGMT.DELETE.CONFIRM.YES')"
      :reject-text="t('INBOX_MGMT.DELETE.CONFIRM.NO')"
      :confirm-value="inbox.name"
      :confirm-place-holder-text="
        t('INBOX_MGMT.DELETE.CONFIRM.PLACE_HOLDER', { inboxName: inbox.name })
      "
      @on-confirm="remove"
      @on-close="show = false"
    />
  </div>
</template>
