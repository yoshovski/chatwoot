import { flushPromises, mount } from '@vue/test-utils';
import McpServersSection from './McpServersSection.vue';
import McpServerForm from './McpServerForm.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

const mocks = vi.hoisted(() => ({
  get: vi.fn(),
  create: vi.fn(),
  update: vi.fn(),
  alert: vi.fn(),
}));

vi.mock('dashboard/api/captain/mcpServers', () => ({
  default: {
    get: mocks.get,
    create: mocks.create,
    update: mocks.update,
    sync: vi.fn(),
    delete: vi.fn(),
  },
}));
vi.mock('dashboard/composables', () => ({ useAlert: mocks.alert }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const server = {
  id: 3,
  name: 'Billing',
  endpoint_url: 'https://example.com/mcp',
  status: 'connected',
  tools: [
    { name: 'refund', title: 'Refund', enabled: false },
    { name: 'invoice', title: 'Invoice', enabled: true },
  ],
};

const mountSection = () =>
  mount(McpServersSection, {
    global: {
      stubs: { Dialog: true },
      directives: { tooltip: {} },
    },
  });

describe('McpServersSection', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.get.mockResolvedValue({ data: { payload: [server] } });
  });

  it('enables a tool while keeping the other enabled tools', async () => {
    mocks.update.mockResolvedValue({
      data: {
        ...server,
        tools: server.tools.map(tool => ({ ...tool, enabled: true })),
      },
    });
    const wrapper = mountSection();
    await flushPromises();

    wrapper.findAllComponents(Switch)[0].vm.$emit('update:modelValue', true);
    await flushPromises();

    expect(mocks.update).toHaveBeenCalledWith(3, {
      enabled_tool_names: ['refund', 'invoice'],
    });
    expect(
      wrapper.findAllComponents(Switch).map(item => item.props('modelValue'))
    ).toEqual([true, true]);
  });

  it('connects a new server and shows its tools', async () => {
    mocks.get.mockResolvedValue({ data: { payload: [] } });
    mocks.create.mockResolvedValue({ data: server });
    const wrapper = mountSection();
    await flushPromises();

    await wrapper
      .findAll('button')
      .find(button => button.text().includes('CAPTAIN.MCP_SERVERS.ADD'))
      .trigger('click');
    wrapper
      .findComponent(McpServerForm)
      .vm.$emit('submit', { name: 'Billing' });
    await flushPromises();

    expect(mocks.create).toHaveBeenCalledWith({ name: 'Billing' });
    expect(wrapper.text()).toContain('Refund');
    expect(wrapper.findComponent(McpServerForm).exists()).toBe(false);
  });
});
