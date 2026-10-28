import { flushPromises, mount } from '@vue/test-utils';
import WebsiteStep from './WebsiteStep.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const render = guided =>
  mount(WebsiteStep, {
    props: { guided: { importError: '', source: null, ...guided } },
    global: {
      mocks: { $t: (key, values) => `${key} ${JSON.stringify(values || {})}` },
      stubs: {
        Icon: true,
        Spinner: { template: '<span data-spinner />' },
        RouterLink: { template: '<a><slot /></a>' },
        Input: {
          props: ['modelValue', 'message'],
          emits: ['update:modelValue'],
          template:
            '<div><input :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" /><p>{{ message }}</p></div>',
        },
        Button: {
          props: ['label'],
          template: '<button>{{ label }}</button>',
        },
      },
    },
  });

describe('WebsiteStep', () => {
  it('checks the address before starting the import', async () => {
    const startWebsite = vi.fn().mockResolvedValue({ ok: true });
    const wrapper = render({ progress: { phase: 'idle' }, startWebsite });

    await wrapper.find('input').setValue('not a site');
    await wrapper.find('form').trigger('submit');
    expect(startWebsite).not.toHaveBeenCalled();
    expect(wrapper.text()).toContain('HOME.GUIDED.WEBSITE.INVALID');

    await wrapper.find('input').setValue('example.com');
    await wrapper.find('form').trigger('submit');
    await flushPromises();
    expect(startWebsite).toHaveBeenCalledWith('example.com');
  });

  it('shows the import progress while pages are read', () => {
    const wrapper = render({
      source: { url: 'https://www.example.com' },
      progress: { phase: 'reading', found: 9, total: 4, ready: 1, failed: 0 },
    });

    expect(wrapper.find('form').exists()).toBe(false);
    expect(wrapper.text()).toContain('example.com');
    expect(wrapper.text()).toContain('HOME.GUIDED.WEBSITE.READING');
    expect(wrapper.findAll('[data-spinner]')).toHaveLength(1);
  });

  it('offers a retry when the website could not be read', () => {
    const wrapper = render({
      source: { url: 'https://www.example.com' },
      progress: { phase: 'failed' },
    });

    expect(wrapper.find('[role="alert"]').text()).toContain(
      'HOME.GUIDED.WEBSITE.FAILED_TITLE'
    );
  });
});
