/* eslint-disable @intlify/vue-i18n/no-dynamic-keys -- Keys come from the fixed SETTINGS_SECTIONS list. */
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useRouter } from 'vue-router';
import { useMapGetter } from 'dashboard/composables/store';
import { usePolicy } from 'dashboard/composables/usePolicy';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { SETTINGS_SECTIONS } from './settingsSections';

// The settings sections with their words filled in, keeping only the pages this user may open
// (the same route permissions and feature flags the sidebar uses).
export const useSettingsSections = () => {
  const { t } = useI18n();
  const router = useRouter();
  const { shouldShow } = usePolicy();
  const accountId = useMapGetter('getCurrentAccountId');
  const isFeatureEnabledonAccount = useMapGetter(
    'accounts/isFeatureEnabledonAccount'
  );

  const canOpen = page => {
    if (
      page.advancedAssignment &&
      !isFeatureEnabledonAccount.value(
        accountId.value,
        FEATURE_FLAGS.ADVANCED_ASSIGNMENT
      )
    ) {
      return false;
    }
    const { meta } = router.resolve({
      name: page.route,
      params: { accountId: accountId.value },
    });
    return shouldShow(
      meta.featureFlag || '',
      meta.permissions || [],
      meta.installationTypes || []
    );
  };

  return computed(() =>
    SETTINGS_SECTIONS.map(section => ({
      ...section,
      title: t(`SETTINGS_HOME.SECTIONS.${section.key}.TITLE`),
      hint: t(`SETTINGS_HOME.SECTIONS.${section.key}.HINT`),
      pages: section.pages.filter(canOpen).map(page => ({
        ...page,
        label: t(`SETTINGS_HOME.PAGES.${page.key}.LABEL`),
        hint: t(`SETTINGS_HOME.PAGES.${page.key}.HINT`),
        keywords: t(`SETTINGS_HOME.PAGES.${page.key}.KEYWORDS`),
      })),
    })).filter(section => section.pages.length)
  );
};
