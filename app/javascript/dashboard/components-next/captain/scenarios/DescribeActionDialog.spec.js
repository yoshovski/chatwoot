import { mount, flushPromises } from '@vue/test-utils';
import { createStore } from 'vuex';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import CaptainScenariosAPI from 'dashboard/api/captain/scenarios';
import DescribeActionDialog from './DescribeActionDialog.vue';

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: '4' } }),
}));
vi.mock('dashboard/api/captain/scenarios', () => ({
  default: { suggestAction: vi.fn() },
}));
vi.mock('dashboard/components-next/dialog/Dialog.vue', () => ({
  default: {
    methods: { open() {}, close() {} },
    template: '<div><slot /></div>',
  },
}));

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });
const createAttribute = vi.fn();
const store = createStore({
  modules: {
    captainTools: {
      namespaced: true,
      getters: {
        getRecords: () => [
          { id: 'update_contact_attribute', title: 'Update', emoji: '🪪' },
        ],
      },
    },
    attributes: {
      namespaced: true,
      getters: { getAttributes: () => [] },
      actions: { create: (_ctx, payload) => createAttribute(payload) },
    },
    teams: { namespaced: true, getters: { getTeams: () => [] } },
    agents: { namespaced: true, getters: { getAgents: () => [] } },
    captainAssistants: {
      namespaced: true,
      getters: { getRecord: () => () => null },
    },
  },
});

const suggestFor = async payload => {
  CaptainScenariosAPI.suggestAction.mockResolvedValue({
    data: { suggestion: payload },
  });
  const wrapper = mount(DescribeActionDialog, {
    global: { plugins: [store, i18n] },
  });
  wrapper.vm.open();
  await wrapper.find('textarea').setValue('remember their plan');
  await wrapper.find('[data-test="describe-suggest"]').trigger('click');
  await flushPromises();
  return wrapper;
};

describe('DescribeActionDialog', () => {
  it('asks before creating a missing attribute, then inserts the chip', async () => {
    const wrapper = await suggestFor({
      tool_id: 'update_contact_attribute',
      params: { key: 'interested_plan' },
      missing: {
        attribute: {
          key: 'interested_plan',
          label: 'Interested plan',
          type: 'text',
        },
      },
    });

    expect(CaptainScenariosAPI.suggestAction).toHaveBeenCalledWith({
      assistantId: '4',
      description: 'remember their plan',
    });
    expect(wrapper.find('[data-test="describe-missing"]').text()).toBe(
      'Create attribute interested_plan (text)?'
    );
    expect(wrapper.find('[data-test="describe-chip"]').text()).toContain(
      'Save Interested plan'
    );
    expect(createAttribute).not.toHaveBeenCalled();
    expect(wrapper.emitted('insert')).toBeUndefined();

    await wrapper.find('[data-test="describe-create"]').trigger('click');
    await flushPromises();

    expect(createAttribute).toHaveBeenCalledWith({
      attribute_display_name: 'Interested plan',
      attribute_key: 'interested_plan',
      attribute_display_type: 'text',
      attribute_model: 'contact_attribute',
    });
    expect(wrapper.emitted('insert')[0][0]).toEqual({
      id: 'update_contact_attribute?key=interested_plan',
      title: 'Save Interested plan',
      emoji: '🪪',
    });
  });

  it('says so when nothing fits', async () => {
    const wrapper = await suggestFor(null);

    expect(wrapper.text()).toContain('No built-in action fits');
    expect(wrapper.find('[data-test="describe-insert"]').exists()).toBe(false);
  });
});
