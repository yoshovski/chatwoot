import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import ActionParamsDialog from './ActionParamsDialog.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: '4' } }),
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    props: ['title', 'disableConfirmButton'],
    emits: ['confirm'],
    methods: { open() {}, close() {} },
    template:
      '<div><slot /><button data-test="confirm" :disabled="disableConfirmButton" @click="$emit(\'confirm\')" /></div>',
  },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const attributes = [
  {
    attribute_key: 'company_size',
    attribute_display_name: 'Company size',
    attribute_model: 'contact_attribute',
  },
];
const createAttribute = vi.fn(async (_ctx, payload) =>
  attributes.push(payload)
);

const store = createStore({
  modules: {
    attributes: {
      namespaced: true,
      getters: {
        getAttributesByModel: () => model =>
          attributes.filter(attribute => attribute.attribute_model === model),
      },
      actions: { get: vi.fn(), create: createAttribute },
    },
    teams: {
      namespaced: true,
      getters: { getTeams: () => [{ id: 3, name: 'Sales' }] },
      actions: { get: vi.fn() },
    },
    agents: {
      namespaced: true,
      getters: { getAgents: () => [] },
      actions: { get: vi.fn() },
    },
    captainAssistants: {
      namespaced: true,
      getters: {
        getRecord: () => () => ({
          config: {
            email_templates: { demo: { name: 'New demo request' } },
          },
        }),
      },
    },
  },
});

const mountDialog = () =>
  mount(ActionParamsDialog, { global: { plugins: [store, i18n] } });

const updateContactAttribute = {
  id: 'update_contact_attribute',
  title: 'Update contact attribute',
  emoji: '🪪',
  built_in_action: true,
};

describe('ActionParamsDialog', () => {
  it('asks for the attribute and inserts the parameterised reference', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(updateContactAttribute);
    await flushPromises();

    expect(
      wrapper.find('[data-test="confirm"]').attributes('disabled')
    ).toBeDefined();
    await wrapper
      .find('[data-test="attribute-select"] select')
      .setValue('company_size');
    await wrapper.find('[data-test="confirm"]').trigger('click');

    expect(wrapper.emitted('insert')[0][0]).toEqual({
      id: 'update_contact_attribute?key=company_size',
      title: 'Save Company size',
      emoji: '🪪',
    });
  });

  it('creates a missing attribute and selects it', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open(updateContactAttribute);
    await flushPromises();

    await wrapper.find('[data-test="create-attribute"]').trigger('click');
    const form = wrapper.find('[data-test="create-attribute-form"]');
    await form.find('input').setValue('Interested plan');
    await wrapper.find('[data-test="save-attribute"]').trigger('click');
    await flushPromises();

    expect(createAttribute.mock.calls[0][1]).toEqual({
      attribute_display_name: 'Interested plan',
      attribute_key: 'interested_plan',
      attribute_display_type: 'text',
      attribute_model: 'contact_attribute',
    });
    await wrapper.find('[data-test="confirm"]').trigger('click');
    expect(wrapper.emitted('insert')[0][0].id).toBe(
      'update_contact_attribute?key=interested_plan'
    );
  });

  it('inserts a follow-up with its delay and instructions', async () => {
    const wrapper = mountDialog();
    wrapper.vm.open({ id: 'schedule_follow_up', built_in_action: true });
    await flushPromises();

    await wrapper.find('textarea').setValue('Ask if the comparison helped');
    await wrapper.find('[data-test="confirm"]').trigger('click');

    expect(wrapper.emitted('insert')[0][0]).toMatchObject({
      id: 'schedule_follow_up?after=60&kind=message&instructions=Ask+if+the+comparison+helped',
      title: 'Follow up after 1 hour',
    });
  });
});
