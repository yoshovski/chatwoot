import { mount } from '@vue/test-utils';
import McpServerCard from './McpServerCard.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const server = {
  id: 3,
  name: 'Billing',
  endpoint_url: 'https://example.com/mcp',
  auth_type: 'bearer',
  status: 'connected',
  synced_at: null,
  tools: [
    { name: 'refund', title: 'Refund', enabled: true },
    { name: 'invoice', title: 'Invoice', enabled: false },
  ],
};

const mountCard = () =>
  mount(McpServerCard, {
    props: { server },
    global: {
      stubs: { Policy: { template: '<div><slot /></div>' } },
      directives: { onClickaway: {}, tooltip: {} },
    },
  });

describe('McpServerCard', () => {
  it('summarises enabled tools and lists them on request', async () => {
    const wrapper = mountCard();

    expect(wrapper.text()).toContain('{"enabled":1,"total":2}');
    expect(wrapper.findAllComponents(Switch)).toHaveLength(0);

    await wrapper.find('button[aria-expanded]').trigger('click');
    wrapper.findAllComponents(Switch)[1].vm.$emit('update:modelValue', true);

    expect(wrapper.emitted('toggleTool')[0][0]).toMatchObject({
      tool: { name: 'invoice' },
      enabled: true,
    });
  });
});
