import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import AssistantForm from './AssistantForm.vue';

vi.mock('dashboard/composables/store', () => ({
  useMapGetter: getter =>
    ref(getter === 'globalConfig/get' ? { captainBrandName: 'Tony' } : {}),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

const mountForm = props =>
  mount(AssistantForm, {
    props,
    global: { stubs: { Editor: true, Button: true } },
  });

describe('AssistantForm', () => {
  it('prefills the name with the brand name when creating', () => {
    const wrapper = mountForm({ mode: 'create' });

    expect(wrapper.find('input').element.value).toBe('Tony');
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
