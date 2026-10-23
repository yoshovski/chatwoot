import { flushPromises, mount } from '@vue/test-utils';
import ConnectMcpServerDialog from './ConnectMcpServerDialog.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import Switch from 'dashboard/components-next/switch/Switch.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

const DialogStub = {
  props: ['confirmButtonLabel', 'disableConfirmButton'],
  emits: ['confirm', 'close'],
  setup(_, { expose }) {
    expose({ open: vi.fn(), close: vi.fn() });
  },
  template:
    '<div><slot /><button data-test="confirm" @click="$emit(\'confirm\')">{{ confirmButtonLabel }}</button></div>',
};

const connected = {
  id: 9,
  name: 'Billing',
  status: 'connected',
  has_auth_token: false,
  tools: [
    { name: 'refund', title: 'Refund', enabled: false },
    { name: 'invoice', title: 'Invoice', enabled: false },
  ],
};

const mountDialog = props =>
  mount(ConnectMcpServerDialog, {
    props: { save: vi.fn(), setEnabledTools: vi.fn(), ...props },
    global: { stubs: { Dialog: DialogStub } },
  });

const fillConnection = async wrapper => {
  const [name, url] = wrapper.findAllComponents(Input);
  name.vm.$emit('update:modelValue', 'Billing');
  url.vm.$emit('update:modelValue', 'https://example.com/mcp');
  await flushPromises();
};

describe('ConnectMcpServerDialog', () => {
  it('connects, then saves only the chosen tools', async () => {
    const save = vi.fn().mockResolvedValue(connected);
    const setEnabledTools = vi.fn().mockResolvedValue(connected);
    const wrapper = mountDialog({ save, setEnabledTools });
    await fillConnection(wrapper);

    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();

    expect(save).toHaveBeenCalledWith(undefined, {
      name: 'Billing',
      endpoint_url: 'https://example.com/mcp',
      auth_type: 'none',
      auth_header_name: null,
      auth_token: '',
    });
    wrapper.findAllComponents(Switch)[1].vm.$emit('update:modelValue', true);
    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();

    expect(setEnabledTools).toHaveBeenCalledWith(9, ['invoice']);
  });

  it('stays on the connection step after a failure and retries the saved server', async () => {
    const save = vi
      .fn()
      .mockResolvedValueOnce({
        ...connected,
        status: 'failed',
        last_error: 'timeout',
      })
      .mockResolvedValueOnce(connected);
    const wrapper = mountDialog({ save });
    await fillConnection(wrapper);

    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('timeout');
    expect(wrapper.findAllComponents(Switch)).toHaveLength(0);

    await wrapper.find('[data-test="confirm"]').trigger('click');
    await flushPromises();

    expect(save.mock.calls[1][0]).toBe(9);
    expect(wrapper.findAllComponents(Switch)).toHaveLength(2);
  });
});
