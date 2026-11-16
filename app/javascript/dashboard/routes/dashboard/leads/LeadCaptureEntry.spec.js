import { ref } from 'vue';
import { createMemoryHistory, createRouter } from 'vue-router';
import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import AssistantsAPI from 'dashboard/api/captain/assistant';
import { routes } from '../captain/captain.routes';
import LeadCaptureEntry from './LeadCaptureEntry.vue';

const admin = ref(true);
const paywall = ref(false);
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ shouldShowPaywall: () => paywall.value }),
}));
vi.mock('dashboard/routes', () => ({ default: {}, initalizeRouter: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables/useAdmin', () => ({
  useAdmin: () => ({ isAdmin: admin }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({
    accountScopedRoute: (name, params) => ({
      name,
      params: { accountId: '7', ...params },
    }),
  }),
}));
vi.mock('dashboard/api/captain/assistant', () => ({
  default: { get: vi.fn() },
}));

let router;
beforeEach(async () => {
  admin.value = true;
  paywall.value = false;
  AssistantsAPI.get.mockResolvedValue({ data: { payload: [] } });
  // Real route definitions catch missing required parameters and route-name regressions.
  router = createRouter({
    history: createMemoryHistory(),
    routes: [
      ...routes,
      {
        path: '/app/accounts/:accountId/leads',
        component: { template: '<div />' },
      },
    ],
  });
  await router.push('/app/accounts/7/leads');
});
const mount = () =>
  shallowMount(LeadCaptureEntry, { global: { plugins: [router] } });

describe('Lead capture entry', () => {
  it('opens the only agent directly in capture settings using the real route', async () => {
    AssistantsAPI.get.mockResolvedValue({
      data: {
        payload: [
          { id: 3, name: 'Shop', config: { lead_types: [{ name: 'sales' }] } },
        ],
      },
    });
    const wrapper = mount();
    await flushPromises();
    expect(wrapper.text()).toContain('LEADS.CAPTURE.PAUSED');
    await wrapper.findComponent({ name: 'Button' }).trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.path).toBe(
      '/app/accounts/7/captain/3/settings/leads'
    );
    wrapper.unmount();
  });

  it('requires an explicit choice when several agents exist', async () => {
    AssistantsAPI.get.mockResolvedValue({
      data: {
        payload: [
          { id: 3, name: 'One' },
          { id: 4, name: 'Two', config: { leads_enabled: true } },
        ],
      },
    });
    const wrapper = mount();
    await flushPromises();
    expect(wrapper.find('button-stub').attributes('disabled')).toBe('true');
    await wrapper.find('select').setValue('4');
    expect(wrapper.text()).toContain('LEADS.CAPTURE.ENABLED');
    await wrapper.find('button-stub').trigger('click');
    await flushPromises();
    expect(router.currentRoute.value.path).toBe(
      '/app/accounts/7/captain/4/settings/leads'
    );
    wrapper.unmount();
  });

  it('returns a newly created agent directly to lead setup', async () => {
    const wrapper = mount();
    await flushPromises();
    expect(wrapper.text()).toContain('LEADS.CAPTURE.CREATE_HELP');
    wrapper
      .findComponent({ name: 'CreateAssistantDialog' })
      .vm.$emit('created', { id: 5 });
    await flushPromises();
    expect(router.currentRoute.value.path).toBe(
      '/app/accounts/7/captain/5/settings/leads'
    );
    wrapper.unmount();
  });

  it('explains restricted access without fetching configuration or offering edits', async () => {
    admin.value = false;
    const wrapper = mount();
    await flushPromises();
    expect(AssistantsAPI.get).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('LEADS.CAPTURE.NO_ACCESS');
    expect(wrapper.find('button-stub').exists()).toBe(false);
    wrapper.unmount();
  });

  it('distinguishes failed configuration lookup from unconfigured capture and retries', async () => {
    AssistantsAPI.get.mockRejectedValueOnce(new Error('offline'));
    const wrapper = mount();
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toContain(
      'LEADS.CAPTURE.ERROR'
    );
    expect(wrapper.text()).not.toContain('LEADS.CAPTURE.UNCONFIGURED');
    await wrapper.find('button-stub').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('LEADS.CAPTURE.CREATE_HELP');
    wrapper.unmount();
  });
  it('preserves the existing AI agent paywall before offering creation', async () => {
    paywall.value = true;
    const wrapper = mount();
    await flushPromises();
    expect(AssistantsAPI.get).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('LEADS.CAPTURE.UNAVAILABLE');
    expect(wrapper.find('button-stub').exists()).toBe(false);
    wrapper.unmount();
  });
});
