import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import EmailTemplatesSection from './EmailTemplatesSection.vue';

const dispatch = vi.fn();
const templates = {
  demo: { name: 'New demo request', subject: 'Demo', body: 'Hi' },
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: '4' } }),
}));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({
    dispatch,
    getters: {
      'captainAssistants/getRecord': () => ({
        config: { email_templates: templates },
      }),
    },
  }),
}));
vi.mock('dashboard/components-next/side-panel/SidePanel.vue', () => ({
  default: {
    methods: { open() {}, close() {} },
    template: '<div><slot /><slot name="footer" /></div>',
  },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const mountSection = () =>
  mount(EmailTemplatesSection, { global: { plugins: [i18n] } });

describe('EmailTemplatesSection', () => {
  beforeEach(() => dispatch.mockResolvedValue({}));

  it('lists the agent templates', () => {
    const wrapper = mountSection();

    expect(wrapper.findAll('[data-test="email-template-row"]')).toHaveLength(1);
    expect(wrapper.text()).toContain('New demo request');
  });

  it('adds a template with a key from its name and previews variables', async () => {
    const wrapper = mountSection();
    const form = wrapper.find('[data-test="email-template-form"]');
    const inputs = form.findAll('input');

    await inputs[0].setValue('Pricing sheet');
    await inputs[2].setValue('Plans for {{ contact.first_name }}');
    await form.find('textarea').setValue('Hi {{ contact.first_name }}');

    expect(inputs[1].element.value).toBe('pricing_sheet');
    expect(
      wrapper.find('[data-test="email-template-preview"]').text()
    ).toContain('Plans for Jamie');

    await wrapper.find('[data-test="email-template-save"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('captainAssistants/update', {
      id: 4,
      config: {
        email_templates: {
          ...templates,
          pricing_sheet: {
            name: 'Pricing sheet',
            subject: 'Plans for {{ contact.first_name }}',
            body: 'Hi {{ contact.first_name }}',
          },
        },
      },
    });
  });
});
