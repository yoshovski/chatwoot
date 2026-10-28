<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useAlert } from 'dashboard/composables';
import { useAbortableRequest } from 'dashboard/composables/useAbortableRequest';
import { dynamicTime } from 'shared/helpers/timeHelper';
import CaptainKnowledgeGapsAPI from 'dashboard/api/captain/knowledgeGaps';

import Button from 'dashboard/components-next/button/Button.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';

const props = defineProps({
  gap: {
    type: Object,
    required: true,
  },
});

const emit = defineEmits(['close', 'resolved']);

const { t } = useI18n();
const router = useRouter();
const dialogRef = ref(null);
const occurrences = ref([]);
const isSaving = ref(false);
const isDismissing = ref(false);
const { run: runDetailsRequest, isPending: isFetching } = useAbortableRequest();

const state = reactive({ question: props.gap.question, answer: '' });

const isInvalid = computed(
  () => !state.question.trim() || !state.answer.trim()
);
const isBusy = computed(() => isSaving.value || isDismissing.value);

const loadOccurrences = async () => {
  try {
    const response = await runDetailsRequest(signal =>
      CaptainKnowledgeGapsAPI.show(props.gap.id, { signal })
    );
    if (response) occurrences.value = response.data.occurrences;
  } catch {
    // The conversation links are a convenience; answering works without them.
    occurrences.value = [];
  }
};

const close = () => dialogRef.value.close();

const handleSave = async () => {
  isSaving.value = true;
  try {
    await CaptainKnowledgeGapsAPI.answer(props.gap.id, {
      question: state.question.trim(),
      answer: state.answer.trim(),
    });
    useAlert(t('CAPTAIN.KNOWLEDGE_GAPS.SUCCESS.ANSWERED'));
    emit('resolved', props.gap.id);
    close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.ANSWER'));
  } finally {
    isSaving.value = false;
  }
};

const handleDismiss = async () => {
  isDismissing.value = true;
  try {
    await CaptainKnowledgeGapsAPI.dismiss(props.gap.id);
    useAlert(t('CAPTAIN.KNOWLEDGE_GAPS.SUCCESS.DISMISSED'));
    emit('resolved', props.gap.id);
    close();
  } catch (error) {
    useAlert(error?.message || t('CAPTAIN.KNOWLEDGE_GAPS.ERRORS.DISMISS'));
  } finally {
    isDismissing.value = false;
  }
};

const openConversation = displayId => {
  close();
  router.push({
    name: 'inbox_conversation',
    params: { conversation_id: displayId },
  });
};

onMounted(loadOccurrences);

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    width="2xl"
    position="top"
    :title="$t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.TITLE')"
    :description="
      $t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.DESCRIPTION', {
        count: gap.occurrences_count,
      })
    "
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="emit('close')"
  >
    <div class="flex flex-col gap-4">
      <Input
        v-model="state.question"
        :label="$t('CAPTAIN.RESPONSES.FORM.QUESTION.LABEL')"
        :placeholder="$t('CAPTAIN.RESPONSES.FORM.QUESTION.PLACEHOLDER')"
      />
      <TextArea
        v-model="state.answer"
        :label="$t('CAPTAIN.RESPONSES.FORM.ANSWER.LABEL')"
        :placeholder="$t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.ANSWER_PLACEHOLDER')"
        auto-height
        resize
        min-height="8rem"
        max-height="18rem"
        autofocus
      />
      <div class="flex flex-col gap-2">
        <span class="text-xs font-medium text-n-slate-11">
          {{ $t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.SEEN_IN') }}
        </span>
        <div v-if="isFetching" class="flex gap-2" aria-busy="true">
          <span
            v-for="n in 3"
            :key="n"
            class="h-6 w-28 animate-pulse rounded-full bg-n-alpha-2"
          />
        </div>
        <p v-else-if="!occurrences.length" class="mb-0 text-xs text-n-slate-10">
          {{ $t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.NO_CONVERSATIONS') }}
        </p>
        <div v-else class="flex flex-wrap gap-2">
          <button
            v-for="occurrence in occurrences"
            :key="occurrence.id"
            type="button"
            class="inline-flex items-center gap-1 rounded-full border border-n-weak bg-n-solid-2 px-2.5 py-1 text-xs text-n-slate-11 transition-colors hover:border-n-brand hover:text-n-blue-11"
            @click="openConversation(occurrence.conversation.display_id)"
          >
            {{
              $t('CAPTAIN.RESPONSES.DOCUMENTABLE.CONVERSATION', {
                id: occurrence.conversation.display_id,
              })
            }}
            <span class="text-n-slate-10">
              {{ dynamicTime(occurrence.created_at) }}
            </span>
          </button>
        </div>
      </div>
    </div>

    <template #footer>
      <div class="flex w-full items-center justify-between gap-3">
        <Button
          :label="$t('CAPTAIN.KNOWLEDGE_GAPS.DISMISS')"
          variant="ghost"
          color="slate"
          :is-loading="isDismissing"
          :disabled="isBusy"
          @click="handleDismiss"
        />
        <Button
          :label="$t('CAPTAIN.KNOWLEDGE_GAPS.DIALOG.SAVE')"
          icon="i-lucide-circle-check-big"
          :is-loading="isSaving"
          :disabled="isInvalid || isBusy"
          @click="handleSave"
        />
      </div>
    </template>
  </Dialog>
</template>
