import { mount, flushPromises } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import EmailTemplatesSection from './EmailTemplatesSection.vue';
import VariableEditor from './VariableEditor.vue';

const dispatch = vi.fn();
const templates = {
  demo: { name: 'New demo request', subject: 'Demo', body: 'Hi' },
};

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: '4' } }),
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  return {
    useMapGetter: () => ref([]),
    useStore: () => ({
      dispatch,
      getters: {
        'captainAssistants/getRecord': () => ({
          config: { email_templates: templates },
        }),
      },
    }),
  };
});
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

  it('shows variables as named chips instead of {{ }}', () => {
    const wrapper = mountSection();
    const subject = wrapper.findAllComponents(VariableEditor)[0];

    subject.vm.$emit('update:modelValue', 'Plans for {{ contact.first_name }}');
    return wrapper.vm.$nextTick().then(() => {
      const chip = subject.find('[data-var="contact.first_name"]');
      expect(chip.text()).toBe('First name');
      expect(subject.text()).not.toContain('{{');
    });
  });

  it('adds a template with an automatic reference and previews variables', async () => {
    const wrapper = mountSection();
    const form = wrapper.find('[data-test="email-template-form"]');
    const [subject, body] = form.findAllComponents(VariableEditor);

    await form.find('input').setValue('New demo request');
    subject.vm.$emit('update:modelValue', 'Plans for {{ contact.first_name }}');
    body.vm.$emit('update:modelValue', 'Hi {{ contact.first_name }}');
    await wrapper.vm.$nextTick();

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
          new_demo_request: {
            name: 'New demo request',
            subject: 'Plans for {{ contact.first_name }}',
            body: 'Hi {{ contact.first_name }}',
            format: 'text',
          },
        },
      },
    });
  });
});
