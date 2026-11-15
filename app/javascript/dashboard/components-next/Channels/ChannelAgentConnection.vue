<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useStore } from 'dashboard/composables/store';
import { useAlert } from 'dashboard/composables';
import AssistantsAPI from 'dashboard/api/captain/assistant';
import CaptainInboxesAPI from 'dashboard/api/captain/inboxes';
import Button from 'next/button/Button.vue';
import SectionCard from 'next/kit/SectionCard.vue';

const props = defineProps({ inbox: { type: Object, required: true } });
const { t } = useI18n();
const store = useStore();
const assistants = ref([]);
const selectedId = ref('');
const loading = ref(false);
const error = ref(false);
const saving = ref(false);
const current = computed(() => props.inbox.captain_assistant);
const load = async () => {
  loading.value = true;
  error.value = false;
  try {
    const { data } = await AssistantsAPI.get();
    assistants.value = data.payload;
  } catch {
    error.value = true;
  } finally {
    loading.value = false;
  }
};
const save = async () => {
  if (saving.value || (!current.value?.id && !selectedId.value)) return;
  saving.value = true;
  try {
    let updatedInbox;
    if (current.value?.id) {
      await CaptainInboxesAPI.delete({
        assistantId: current.value.id,
        inboxId: props.inbox.id,
      });
      updatedInbox = { ...props.inbox, captain_assistant: null };
    } else {
      const { data } = await CaptainInboxesAPI.create({
        assistantId: Number(selectedId.value),
        inboxId: props.inbox.id,
      });
      updatedInbox = data;
    }
    store.commit('inboxes/EDIT_INBOXES', updatedInbox);
    selectedId.value = '';
    useAlert(t('CHANNELS.AGENT_SAVED'));
  } catch {
    await store.dispatch('inboxes/get');
    useAlert(t('CHANNELS.AGENT_ERROR'));
  } finally {
    saving.value = false;
  }
};
onMounted(load);
</script>

<template>
  <SectionCard :title="t('CHANNELS.AI_AGENT')">
    <p class="m-0 text-sm text-n-slate-11">{{ t('CHANNELS.AGENT_HELP') }}</p>
    <p v-if="loading" class="m-0 text-sm text-n-slate-11" role="status">
      {{ t('CHANNELS.LOADING_AGENTS') }}
    </p>
    <div
      v-else-if="error"
      class="flex flex-wrap items-center gap-3"
      role="alert"
    >
      <p class="m-0 text-sm text-n-ruby-11">
        {{ t('CHANNELS.AGENT_LOAD_ERROR') }}
      </p>
      <Button :label="t('CHANNELS.RETRY')" size="sm" @click="load" />
    </div>
    <div v-else-if="current?.id" class="flex flex-wrap items-center gap-3">
      <span class="me-auto text-sm font-medium text-n-slate-12">{{
        current.name
      }}</span>
      <Button
        :label="t('CHANNELS.DISCONNECT')"
        color="ruby"
        variant="faded"
        size="sm"
        :is-loading="saving"
        :disabled="saving"
        @click="save"
      />
    </div>
    <form
      v-else-if="assistants.length"
      class="flex flex-col items-stretch gap-3 sm:flex-row sm:items-end"
      @submit.prevent="save"
    >
      <label
        class="m-0 flex min-w-0 flex-1 flex-col gap-2 text-sm text-n-slate-12"
      >
        {{ t('CHANNELS.AI_AGENT') }}
        <select v-model="selectedId" class="!mb-0" :disabled="saving">
          <option value="">{{ t('CHANNELS.SELECT_AGENT') }}</option>
          <option
            v-for="assistant in assistants"
            :key="assistant.id"
            :value="assistant.id"
          >
            {{ assistant.name }}
          </option>
        </select>
      </label>
      <Button
        type="submit"
        class="self-start sm:self-auto"
        :label="t('CHANNELS.CONNECT')"
        size="sm"
        :disabled="!selectedId || saving"
        :is-loading="saving"
      />
    </form>
    <p v-else class="m-0 text-sm text-n-slate-11">
      {{ t('CHANNELS.NO_AGENTS') }}
    </p>
  </SectionCard>
</template>
