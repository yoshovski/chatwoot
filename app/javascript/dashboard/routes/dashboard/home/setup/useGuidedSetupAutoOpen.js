import { onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useAdmin } from 'dashboard/composables/useAdmin';
import { useUISettings } from 'dashboard/composables/useUISettings';
import GuidedSetupAPI from 'dashboard/api/captain/guidedSetup';
import { GUIDED_SHOWN_SETTING } from '../homeSetup';

// Routes where opening the guided setup would interrupt something the user is already doing.
const KEEP_ROUTES = ['account_home_setup'];

// A new workspace (an administrator, no AI agent yet) starts in the guided setup. It opens once per user; after
// that the Home checklist reopens it.
export function useGuidedSetupAutoOpen() {
  const route = useRoute();
  const router = useRouter();
  const { isAdmin } = useAdmin();
  const { uiSettings, updateUISettings } = useUISettings();

  onMounted(async () => {
    if (!isAdmin.value || uiSettings.value[GUIDED_SHOWN_SETTING]) return;
    if (KEEP_ROUTES.includes(route.name)) return;
    try {
      const { data } = await GuidedSetupAPI.get();
      updateUISettings({ [GUIDED_SHOWN_SETTING]: true });
      if (!data.assistant_id) router.push({ name: 'account_home_setup' });
    } catch {
      // Without the Captain API there is no guided setup to open.
    }
  });
}
