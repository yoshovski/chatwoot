import { computed } from 'vue';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  buildSetupProgress,
  FINISHED_SETTING,
  SKIPPED_SETTING,
} from './homeSetup';

export const useHomeSetupProgress = summary => {
  const { uiSettings, updateUISettings } = useUISettings();
  const skipped = computed(() => uiSettings.value[SKIPPED_SETTING] || []);
  const progress = computed(() =>
    buildSetupProgress(
      summary.value?.setup,
      skipped.value,
      uiSettings.value[FINISHED_SETTING] || []
    )
  );
  const skip = key =>
    updateUISettings({ [SKIPPED_SETTING]: [...skipped.value, key] });
  const unskip = key =>
    updateUISettings({
      [SKIPPED_SETTING]: skipped.value.filter(step => step !== key),
    });

  return { progress, skip, unskip };
};
