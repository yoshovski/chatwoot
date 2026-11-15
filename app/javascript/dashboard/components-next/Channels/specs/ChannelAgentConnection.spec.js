import { flushPromises, mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ChannelAgentConnection from '../ChannelAgentConnection.vue';
import AssistantsAPI from 'dashboard/api/captain/assistant';
import CaptainInboxesAPI from 'dashboard/api/captain/inboxes';
import { useAlert } from 'dashboard/composables';

vi.mock('dashboard/api/captain/assistant', () => ({
  default: { get: vi.fn() },
}));
vi.mock('dashboard/api/captain/inboxes', () => ({
  default: { create: vi.fn(), delete: vi.fn() },
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const global = {
  stubs: {
    SectionCard: { template: '<section><slot /></section>' },
    Button: {
      props: ['label', 'disabled', 'type'],
      template:
        '<button :disabled="disabled" :type="type || \'button\'">{{ label }}</button>',
    },
  },
};

describe('channel AI connection', () => {
  beforeEach(() => {
    AssistantsAPI.get.mockResolvedValue({
      data: { payload: [{ id: 7, name: 'Shop assistant' }] },
    });
  });

  it('connects the selected account agent to this channel and stores the server response', async () => {
    const commit = vi.fn();
    const store = createStore({
      mutations: { 'inboxes/EDIT_INBOXES': commit },
    });
    const inbox = { id: 3 };
    const updated = {
      id: 3,
      captain_assistant: { id: 7, name: 'Shop assistant' },
    };
    CaptainInboxesAPI.create.mockResolvedValue({ data: updated });
    const wrapper = mount(ChannelAgentConnection, {
      props: { inbox },
      global: { ...global, plugins: [store] },
    });
    await flushPromises();
    expect(wrapper.get('button').attributes('disabled')).toBeDefined();
    await wrapper.get('select').setValue(7);
    await wrapper.get('form').trigger('submit');
    await flushPromises();
    expect(CaptainInboxesAPI.create).toHaveBeenCalledWith({
      assistantId: 7,
      inboxId: 3,
    });
    expect(CaptainInboxesAPI.delete).not.toHaveBeenCalled();
    expect(commit.mock.calls[0][1]).toEqual(updated);
  });

  it('disconnects only the current channel association before offering a replacement', async () => {
    const commit = vi.fn();
    const store = createStore({
      mutations: { 'inboxes/EDIT_INBOXES': commit },
    });
    const inbox = {
      id: 3,
      captain_assistant: { id: 7, name: 'Shop assistant' },
    };
    CaptainInboxesAPI.delete.mockResolvedValue({});
    const wrapper = mount(ChannelAgentConnection, {
      props: { inbox },
      global: { ...global, plugins: [store] },
    });
    await flushPromises();
    expect(wrapper.find('select').exists()).toBe(false);
    await wrapper.get('button').trigger('click');
    await flushPromises();
    expect(CaptainInboxesAPI.delete).toHaveBeenCalledWith({
      assistantId: 7,
      inboxId: 3,
    });
    expect(CaptainInboxesAPI.create).not.toHaveBeenCalled();
    expect(commit.mock.calls[0][1].captain_assistant).toBeNull();
  });

  it('retains the current agent on a failed disconnect', async () => {
    const commit = vi.fn();
    const refresh = vi.fn();
    const store = createStore({
      mutations: { 'inboxes/EDIT_INBOXES': commit },
      actions: { 'inboxes/get': refresh },
    });
    CaptainInboxesAPI.delete.mockRejectedValue(new Error('Request failed'));
    const wrapper = mount(ChannelAgentConnection, {
      props: {
        inbox: { id: 3, captain_assistant: { id: 7, name: 'Shop assistant' } },
      },
      global: { ...global, plugins: [store] },
    });
    await flushPromises();
    await wrapper.get('button').trigger('click');
    await flushPromises();
    expect(commit).not.toHaveBeenCalled();
    expect(useAlert).toHaveBeenCalledWith('CHANNELS.AGENT_ERROR');
    expect(wrapper.text()).toContain('Shop assistant');
  });

  it('shows a retry instead of a connection form when loading agents fails', async () => {
    AssistantsAPI.get.mockRejectedValue(new Error('Unavailable'));
    const wrapper = mount(ChannelAgentConnection, {
      props: { inbox: { id: 3 } },
      global: { ...global, plugins: [createStore({})] },
    });
    await flushPromises();
    expect(wrapper.get('[role="alert"]').text()).toContain(
      'CHANNELS.AGENT_LOAD_ERROR'
    );
    expect(wrapper.find('select').exists()).toBe(false);
    expect(CaptainInboxesAPI.create).not.toHaveBeenCalled();
  });
});
