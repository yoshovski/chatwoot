import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import AssistantForm from './AssistantForm.vue';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: getter =>
    ref(getter === 'getCurrentAccount' ? { name: 'Acme' } : {}),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key}:${params.accountName}` : key),
  }),
}));

const mountForm = props =>
  mount(AssistantForm, {
    props,
    global: { stubs: { Editor: true, Button: true } },
  });

describe('AssistantForm', () => {
  it('prefills the name from the account name when creating', () => {
    const wrapper = mountForm({ mode: 'create' });

    expect(wrapper.find('input').element.value).toBe(
      'CAPTAIN.ASSISTANTS.FORM.NAME.DEFAULT:Acme'
    );
    expect(wrapper.text()).toContain('CAPTAIN.ASSISTANTS.FORM.NAME.HELP_TEXT');
  });

  it('keeps the assistant name when editing', () => {
    const wrapper = mountForm({
      mode: 'edit',
      assistant: {
        name: 'Luna',
        description: 'Helps',
        config: { product_name: 'Acme' },
      },
    });

    expect(wrapper.find('input').element.value).toBe('Luna');
  });
});
