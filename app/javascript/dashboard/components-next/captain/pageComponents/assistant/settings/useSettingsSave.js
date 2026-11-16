import { ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';

export function useSettingsSave(isDirty, persist) {
  const { t } = useI18n();
  const isSaving = ref(false);
  const isSaved = ref(false);
  const saveError = ref('');

  const clearFeedback = () => {
    isSaved.value = false;
    saveError.value = '';
  };

  watch(isDirty, dirty => {
    if (dirty) isSaved.value = false;
    else saveError.value = '';
  });

  const save = async () => {
    if (!isDirty.value || isSaving.value) return;

    clearFeedback();
    isSaving.value = true;
    try {
      const result = await persist();
      isSaved.value = result === true;
      if (result === false) {
        saveError.value = t('CAPTAIN.ASSISTANTS.EDIT.ERROR_MESSAGE');
      }
    } finally {
      isSaving.value = false;
    }
  };

  return { isSaving, isSaved, saveError, save };
}
