import { mount, flushPromises } from '@vue/test-utils';
import { ref } from 'vue';
import CancelPlanDialog from '../components/CancelPlanDialog.vue';
import api from 'dashboard/api/accountSubscription';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key, locale: ref('en') }),
}));
vi.mock('dashboard/api/accountSubscription', () => ({
  default: {
    startCancellation: vi.fn(),
    cancelPlan: vi.fn(),
    acceptRetention: vi.fn(),
    dismissCancellation: vi.fn(),
  },
}));
const dialogStub = {
  template: '<div><slot /></div>',
  setup(_, { expose }) {
    expose({ open: vi.fn(), close: vi.fn() });
  },
};
const billing = { currency: 'eur', period_ends_at: '2026-12-15T00:00:00Z' };
const offer = {
  id: 1,
  discount_available: true,
  pause_available: true,
  smaller_plans: [],
};
const render = () =>
  mount(CancelPlanDialog, {
    props: { billing },
    global: { stubs: { Dialog: dialogStub } },
  });
const button = (wrapper, label) =>
  wrapper.findAll('button').find(b => b.text().includes(label));

beforeEach(() => {
  vi.clearAllMocks();
  api.dismissCancellation.mockResolvedValue({ data: { status: 'kept' } });
  api.startCancellation.mockResolvedValue({ data: offer });
  api.cancelPlan.mockResolvedValue({ data: { status: 'canceled' } });
  api.acceptRetention.mockResolvedValue({ data: { status: 'discounted' } });
});

it('cancels with three clicks including opening the dialog and selecting a reason', async () => {
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'REASONS.expensive').trigger('click');
  await button(wrapper, 'CANCEL_FLOW.CANCEL').trigger('click');
  await flushPromises();
  expect(api.cancelPlan).toHaveBeenCalledWith(
    1,
    expect.objectContaining({ reason: 'expensive' })
  );
  expect(wrapper.text()).toContain('CANCEL_FLOW.SUCCESS_TITLE');
  expect(wrapper.emitted('changed')).toHaveLength(1);
});

it('lets the customer skip the reason', async () => {
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'CANCEL_FLOW.CANCEL').trigger('click');
  await flushPromises();
  expect(api.cancelPlan).toHaveBeenCalledWith(
    1,
    expect.objectContaining({ reason: 'other' })
  );
});

it('sends the discount decision and shows the actual result', async () => {
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'REASONS.expensive').trigger('click');
  await button(wrapper, 'OFFERS.expensive.ACTION').trigger('click');
  await flushPromises();
  expect(api.acceptRetention).toHaveBeenCalledWith(
    1,
    expect.objectContaining({ reason: 'expensive' })
  );
  expect(wrapper.text()).toContain('CANCEL_FLOW.DISCOUNTED');
});

it('keeps cancellation available when the one-time offer is ineligible', async () => {
  api.startCancellation.mockResolvedValue({
    data: { ...offer, discount_available: false },
  });
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'REASONS.expensive').trigger('click');
  expect(button(wrapper, 'OFFERS.expensive.ACTION')).toBeUndefined();
  expect(button(wrapper, 'CANCEL_FLOW.CANCEL')).toBeDefined();
  expect(wrapper.text()).toContain('CANCEL_FLOW.UNAVAILABLE');
});

it('sends the selected pause duration', async () => {
  api.acceptRetention.mockResolvedValue({ data: { status: 'paused' } });
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'REASONS.unused').trigger('click');
  await wrapper.find('select').setValue(2);
  await button(wrapper, 'OFFERS.unused.ACTION').trigger('click');
  await flushPromises();
  expect(api.acceptRetention).toHaveBeenCalledWith(
    1,
    expect.objectContaining({ reason: 'unused', months: 2 })
  );
  expect(wrapper.text()).toContain('CANCEL_FLOW.PAUSED');
});

it('shows errors and lets the same cancellation be retried', async () => {
  api.cancelPlan.mockRejectedValueOnce(new Error('offline'));
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'CANCEL_FLOW.CANCEL').trigger('click');
  await flushPromises();
  expect(wrapper.find('[role="alert"]').exists()).toBe(true);
  expect(wrapper.text()).not.toContain('CANCEL_FLOW.SUCCESS_TITLE');
  await button(wrapper, 'CANCEL_FLOW.CANCEL').trigger('click');
  await flushPromises();
  expect(api.cancelPlan).toHaveBeenCalledTimes(2);
  expect(wrapper.text()).toContain('CANCEL_FLOW.SUCCESS_TITLE');
});

it('offers a retry when the initial request fails', async () => {
  api.startCancellation.mockRejectedValueOnce(new Error('offline'));
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  expect(wrapper.find('[role="alert"]').exists()).toBe(true);
  await button(wrapper, 'BILLING_PAGE.RETRY').trigger('click');
  await flushPromises();
  expect(button(wrapper, 'CANCEL_FLOW.CANCEL')).toBeDefined();
});

it('prevents duplicate mutations while a decision is pending', async () => {
  api.cancelPlan.mockReturnValue(new Promise(() => {}));
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'CANCEL_FLOW.CANCEL').trigger('click');
  expect(
    button(wrapper, 'CANCEL_FLOW.CANCEL').attributes('disabled')
  ).toBeDefined();
  expect(
    button(wrapper, 'REASONS.expensive').attributes('disabled')
  ).toBeDefined();
});

it('records the selected reason when the customer keeps their plan', async () => {
  const wrapper = render();
  wrapper.vm.open();
  await flushPromises();
  await button(wrapper, 'REASONS.feature').trigger('click');
  await wrapper.find('textarea').setValue('Better reports');
  await button(wrapper, 'CANCEL_FLOW.KEEP').trigger('click');
  await flushPromises();
  expect(api.dismissCancellation).toHaveBeenCalledWith(1, {
    reason: 'feature',
    feature: 'Better reports',
  });
});
