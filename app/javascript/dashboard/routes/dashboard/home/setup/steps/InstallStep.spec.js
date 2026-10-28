import { flushPromises, mount } from '@vue/test-utils';
import InstallStep from './InstallStep.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (key, values) => `${key} ${values?.site || ''}` }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('shared/helpers/clipboard', () => ({ copyTextToClipboard: vi.fn() }));

const render = guided =>
  mount(InstallStep, {
    props: { guided },
    global: {
      mocks: { $t: key => key },
      stubs: {
        Icon: true,
        RouterLink: { template: '<a><slot /></a>' },
        Button: {
          props: ['label'],
          emits: ['click'],
          template:
            '<button :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

const inbox = {
  id: 3,
  name: 'Website',
  website_url: 'https://www.example.com',
  web_widget_script: '\n    <script>\n      token\n    </script>\n  ',
};

describe('InstallStep', () => {
  it('asks to turn the agent on when there is no website chat', async () => {
    const wrapper = render({ state: { widget_inbox: null }, setup: {} });

    expect(wrapper.text()).toContain('HOME.GUIDED.INSTALL.NO_INBOX');
    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('open')).toEqual([['agent_inbox']]);
  });

  it('shows the snippet and explains the check result', async () => {
    const checkInstallation = vi.fn().mockResolvedValue('not_found');
    const wrapper = render({
      state: { widget_inbox: inbox },
      setup: {},
      checkInstallation,
    });

    expect(wrapper.find('code').text()).toBe('<script>\n  token\n</script>');
    await wrapper
      .find('button[data-label="HOME.GUIDED.INSTALL.CHECK"]')
      .trigger('click');
    await flushPromises();

    expect(wrapper.text()).toContain(
      'HOME.GUIDED.INSTALL.RESULT.NOT_FOUND example.com'
    );
  });
});
