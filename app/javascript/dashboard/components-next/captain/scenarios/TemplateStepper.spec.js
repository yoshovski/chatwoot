import { config, mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import FloatingVue from 'floating-vue';
import en from 'dashboard/i18n/locale/en';
import TemplateStepper from './TemplateStepper.vue';
import { getTemplateById } from './scenarioTemplates';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

// The duplicate check compares against the translated field labels.
config.global.plugins = [
  createI18n({ legacy: false, locale: 'en', messages: { en } }),
  FloatingVue,
];

const tools = [
  { id: 'faq_lookup', title: 'Search knowledge' },
  { id: 'handoff', title: 'Hand off to a person' },
  { id: 'add_private_note', title: 'Add a private note' },
  { id: 'add_label_to_conversation', title: 'Add a label' },
];

const createLabel = vi.fn();
const updateAssistant = vi.fn();

const store = createStore({
  modules: {
    labels: {
      namespaced: true,
      getters: { getLabels: () => [{ id: 1, title: 'quote', color: '#000' }] },
      actions: { create: (_ctx, payload) => createLabel(payload) },
    },
    captainAssistants: {
      namespaced: true,
      actions: { update: (_ctx, payload) => updateAssistant(payload) },
    },
  },
});

const mountStepper = (templateId, assistant = {}) =>
  mount(TemplateStepper, {
    props: {
      template: getTemplateById(templateId),
      tools,
      assistant: {
        id: 4,
        link_allowlist: ['https://store.example/'],
        ...assistant,
      },
    },
    global: {
      plugins: [store],
      stubs: {
        ScenarioForm: {
          props: ['instruction'],
          template: '<div class="scenario-form">{{ instruction }}</div>',
          methods: { validate: () => true },
        },
      },
    },
  });

const goToPreview = async wrapper => {
  const steps = wrapper.props('template').questions.length;
  for (let i = wrapper.vm.currentStep; i < steps; i += 1) wrapper.vm.goToNext();
  await wrapper.vm.$nextTick();
};

describe('TemplateStepper', () => {
  beforeEach(() => {
    createLabel.mockResolvedValue({});
    updateAssistant.mockResolvedValue({});
  });

  it('adds a custom field to the grouped chips and writes it into the steps', async () => {
    const wrapper = mountStepper('request_a_quote');
    wrapper.vm.goToNext();
    await wrapper.vm.$nextTick();

    expect(
      wrapper
        .find('[data-test="chip-name_and_email"]')
        .attributes('aria-pressed')
    ).toBe('true');

    await wrapper
      .find('input[data-test="custom-entry-input"]')
      .setValue('Site access hours');
    await wrapper.find('[data-test="custom-entry-add"]').trigger('click');

    expect(wrapper.findAll('[data-test="custom-entry"]')).toHaveLength(1);

    await goToPreview(wrapper);
    expect(wrapper.find('.scenario-form').text()).toContain(
      'Site access hours'
    );
  });

  it('rejects a custom field that repeats an option', async () => {
    const wrapper = mountStepper('request_a_quote');
    wrapper.vm.goToNext();
    await wrapper.vm.$nextTick();

    await wrapper
      .find('input[data-test="custom-entry-input"]')
      .setValue('budget OR target price');

    expect(
      wrapper.find('[data-test="custom-entry-add"]').attributes('disabled')
    ).toBeDefined();
  });

  it('adds the scenario straight away when the label exists', async () => {
    const wrapper = mountStepper('request_a_quote');
    await goToPreview(wrapper);

    wrapper.vm.saveScenario();
    await flushPromises();

    expect(createLabel).not.toHaveBeenCalled();
    expect(wrapper.emitted('add')[0][0].title).toBe('Request a quote');
  });

  it('creates a missing label before adding the scenario', async () => {
    const wrapper = mountStepper('returns_and_warranty');
    await goToPreview(wrapper);

    wrapper.vm.saveScenario();
    await flushPromises();

    expect(createLabel).toHaveBeenCalledWith(
      expect.objectContaining({ title: 'return' })
    );
    expect(wrapper.emitted('add')).toHaveLength(1);
  });

  it('keeps the dialog open when the label cannot be created', async () => {
    createLabel.mockRejectedValue(new Error('Title is invalid'));
    const wrapper = mountStepper('returns_and_warranty');
    await goToPreview(wrapper);

    wrapper.vm.saveScenario();
    await flushPromises();

    expect(wrapper.emitted('add')).toBeUndefined();
  });

  it('asks to allow an unknown booking site and saves its origin', async () => {
    const wrapper = mountStepper('book_a_call');
    wrapper.vm.answers.booking_url = 'https://cal.com/acme/intro';
    await goToPreview(wrapper);

    wrapper.vm.saveScenario();
    await wrapper.vm.$nextTick();
    expect(wrapper.vm.showAllowlistConfirm).toBe(true);
    expect(wrapper.emitted('add')).toBeUndefined();

    wrapper.vm.finishSave({ allowLink: true });
    await flushPromises();

    expect(updateAssistant).toHaveBeenCalledWith({
      id: 4,
      config: {
        link_allowlist: ['https://store.example/', 'https://cal.com/'],
      },
    });
    expect(wrapper.emitted('add')).toHaveLength(1);
  });

  it('does not ask when the booking site is already allowed', async () => {
    const wrapper = mountStepper('book_a_call', {
      link_allowlist: ['https://cal.com/'],
    });
    wrapper.vm.answers.booking_url = 'https://cal.com/acme/intro';
    await goToPreview(wrapper);

    wrapper.vm.saveScenario();
    await flushPromises();

    expect(wrapper.vm.showAllowlistConfirm).toBe(false);
    expect(updateAssistant).not.toHaveBeenCalled();
    expect(wrapper.emitted('add')).toHaveLength(1);
  });

  it('blocks a booking link without https', async () => {
    const wrapper = mountStepper('book_a_call');
    wrapper.vm.answers.booking_url = 'cal.com/acme';
    await wrapper.vm.$nextTick();

    expect(
      wrapper.find('[data-test="stepper-next"]').attributes('disabled')
    ).toBeDefined();
  });
});
