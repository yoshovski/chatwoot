import { flushPromises, shallowMount } from '@vue/test-utils';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import LeadsAPI from 'dashboard/api/captain/leads';
import AgentsAPI from 'dashboard/api/agents';
import { useAlert } from 'dashboard/composables';
import Index from './Index.vue';
import LeadsTable from './LeadsTable.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({ useRouter: () => ({ push: vi.fn() }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/api/captain/leads', () => ({
  default: { get: vi.fn(), update: vi.fn(), export: vi.fn() },
}));
vi.mock('dashboard/api/agents', () => ({ default: { get: vi.fn() } }));

const lead = {
  id: 4,
  conversation_id: 4,
  name: 'Sample visitor',
  status: 'new',
  owner: null,
};
const response = {
  data: {
    payload: [lead],
    meta: {
      counts: { new: 1, won: 0, contacted: 0, lost: 0 },
      page: 1,
      total: 1,
    },
  },
};
const options = {
  global: {
    stubs: {
      PageFrame: { template: '<div><slot name="header" /><slot /></div>' },
    },
  },
};

beforeEach(() => {
  vi.clearAllMocks();
  LeadsAPI.get.mockResolvedValue(structuredClone(response));
  AgentsAPI.get.mockResolvedValue({
    data: [{ id: 2, name: 'Sample teammate' }],
  });
});

describe('Leads', () => {
  it('loads real leads and members and applies status filters on the server', async () => {
    const wrapper = shallowMount(Index, options);
    await flushPromises();
    expect(wrapper.findComponent(LeadsTable).props('leads')).toEqual([lead]);
    expect(wrapper.findComponent(LeadsTable).props('agents')).toHaveLength(1);
    await wrapper.findAll('button')[3].trigger('click');
    await flushPromises();
    expect(LeadsAPI.get).toHaveBeenLastCalledWith(
      { status: 'won', page: 1 },
      expect.any(AbortSignal)
    );
    wrapper.unmount();
  });

  it('shows an error and retries without presenting stale data', async () => {
    LeadsAPI.get.mockRejectedValueOnce(new Error('offline'));
    const wrapper = shallowMount(Index, options);
    await flushPromises();
    expect(wrapper.find('[role="alert"]').text()).toContain('LEADS.LOAD_ERROR');
    expect(wrapper.findComponent(LeadsTable).exists()).toBe(false);
    wrapper.find('[role="alert"] button-stub').trigger('click');
    await flushPromises();
    expect(wrapper.findComponent(LeadsTable).exists()).toBe(true);
    wrapper.unmount();
  });

  it('keeps the saved status when an update fails', async () => {
    LeadsAPI.update.mockRejectedValueOnce(new Error('offline'));
    const wrapper = shallowMount(Index, options);
    await flushPromises();
    wrapper
      .findComponent(LeadsTable)
      .vm.$emit(
        'status',
        wrapper.findComponent(LeadsTable).props('leads')[0],
        'won'
      );
    await flushPromises();
    expect(LeadsAPI.update).toHaveBeenCalledWith(4, { status: 'won' });
    expect(wrapper.findComponent(LeadsTable).props('leads')[0].status).toBe(
      'new'
    );
    expect(useAlert).toHaveBeenCalledWith('LEADS.SAVE_ERROR');
    wrapper.unmount();
  });

  it('saves and clears the owner independently of status', async () => {
    LeadsAPI.update.mockResolvedValueOnce({
      data: { ...lead, owner: { id: 2, name: 'Sample teammate' } },
    });
    const wrapper = shallowMount(Index, options);
    await flushPromises();
    const row = wrapper.findComponent(LeadsTable).props('leads')[0];
    wrapper.findComponent(LeadsTable).vm.$emit('owner', row, 2);
    await flushPromises();
    expect(row.owner.id).toBe(2);
    LeadsAPI.update.mockResolvedValueOnce({ data: lead });
    wrapper.findComponent(LeadsTable).vm.$emit('owner', row, null);
    await flushPromises();
    expect(LeadsAPI.update).toHaveBeenLastCalledWith(4, { owner_id: null });
    expect(row.owner).toBeNull();
    wrapper.unmount();
  });
  it('updates status without remounting the unfiltered list or refetching its rows', async () => {
    LeadsAPI.update.mockResolvedValueOnce({ data: { ...lead, status: 'won' } });
    const wrapper = shallowMount(Index, options);
    await flushPromises();
    const table = wrapper.findComponent(LeadsTable);
    const row = table.props('leads')[0];
    table.vm.$emit('status', row, 'won');
    await flushPromises();
    expect(LeadsAPI.get).toHaveBeenCalledTimes(1);
    expect(wrapper.findComponent(LeadsTable).vm).toBe(table.vm);
    expect(row.status).toBe('won');
    wrapper.unmount();
  });
});
