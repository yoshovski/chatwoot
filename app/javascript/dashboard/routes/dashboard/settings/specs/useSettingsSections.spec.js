import { ref } from 'vue';
import { createMemoryHistory, createRouter } from 'vue-router';
import { useSettingsSections } from '../useSettingsSections';
import { SETTINGS_SECTIONS, findSettingsPage } from '../settingsSections';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import translations from 'dashboard/i18n/locale/en/settings.json';

const accountId = ref(42);
const administrator = ref(true);
const enabled = ref(true);
const advancedAssignment = ref(true);
let router;

vi.mock('vue-router', async importOriginal => ({
  ...(await importOriginal()),
  useRouter: () => router,
}));
vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: key => key.split('.').reduce((value, part) => value[part], translations),
  }),
}));
vi.mock('dashboard/composables/store', () => ({
  useMapGetter: key =>
    key === 'getCurrentAccountId'
      ? accountId
      : ref((id, feature) =>
          feature === FEATURE_FLAGS.ADVANCED_ASSIGNMENT
            ? advancedAssignment.value
            : enabled.value
        ),
}));
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({
    shouldShow: (flag, permissions) =>
      (!permissions.includes('administrator') || administrator.value) &&
      (!flag || enabled.value),
  }),
}));

describe('Settings navigation and search registry', () => {
  beforeEach(() => {
    accountId.value = 42;
    administrator.value = true;
    enabled.value = true;
    advancedAssignment.value = true;
    router = createRouter({
      history: createMemoryHistory(),
      routes: SETTINGS_SECTIONS.flatMap(section => section.pages).map(page => ({
        path: `/accounts/:accountId/${page.route}`,
        name: page.route,
        component: { template: '<div />' },
        meta: {
          permissions: page.key === 'PROFILE' ? [] : ['administrator'],
          featureFlag: page.key === 'CHANNELS' ? 'inbox_management' : '',
        },
      })),
    });
  });

  it('keeps all five groups and every admin destination, including external bots', () => {
    const sections = useSettingsSections();
    expect(sections.value.map(section => section.key)).toEqual([
      'TEAM',
      'REPLIES',
      'AUTOMATION',
      'ACCOUNT',
      'INTEGRATIONS',
    ]);
    const pages = sections.value.flatMap(section => section.pages);
    ['BILLING', 'USAGE', 'CHANNELS', 'BOTS'].forEach(key => {
      expect(pages.find(page => page.key === key)).toBeDefined();
    });
    pages.forEach(page => {
      expect(router.resolve(page.to).params.accountId).toBe('42');
      expect(page.to.name).toBe(page.route);
    });
  });

  it('provides discoverable aliases and explicit parameters after switching accounts', () => {
    const sections = useSettingsSections();
    accountId.value = 77;
    const pages = sections.value.flatMap(section => section.pages);
    const billing = pages.find(page => page.key === 'BILLING');
    const channels = pages.find(page => page.key === 'CHANNELS');
    expect(billing.keywords).toContain('subscription');
    expect(billing.keywords).toContain('invoices');
    expect(channels.keywords).toContain('inbox');
    expect(channels.keywords).toContain('connection');
    expect(billing.to.params.accountId).toBe(77);
    expect(channels.to.params.accountId).toBe(77);
  });

  it('removes restricted destinations before either navigation or search sees them', () => {
    const sections = useSettingsSections();
    administrator.value = false;
    expect(
      sections.value.flatMap(section => section.pages).map(page => page.key)
    ).toEqual(['PROFILE']);
  });

  it('reacts to channel and assignment flags without removing unrelated settings', () => {
    const sections = useSettingsSections();
    enabled.value = false;
    advancedAssignment.value = false;
    let pages = sections.value.flatMap(section => section.pages);
    expect(pages.some(page => page.key === 'CHANNELS')).toBe(false);
    expect(pages.some(page => page.key === 'ASSIGNMENT')).toBe(false);
    expect(pages.some(page => page.key === 'BILLING')).toBe(true);
    enabled.value = true;
    advancedAssignment.value = true;
    pages = sections.value.flatMap(section => section.pages);
    expect(pages.some(page => page.key === 'CHANNELS')).toBe(true);
    expect(pages.some(page => page.key === 'ASSIGNMENT')).toBe(true);
  });

  it.each([
    'settings_inbox_show',
    'settings_inboxes_add_agents',
    'settings_inbox_finish',
  ])('maps %s back to the workspace channel list', name => {
    expect(findSettingsPage(name).route).toBe('settings_inbox_list');
  });
});
