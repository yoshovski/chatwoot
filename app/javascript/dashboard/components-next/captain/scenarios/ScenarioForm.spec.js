import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ScenarioForm from './ScenarioForm.vue';

vi.mock('dashboard/components/widgets/WootWriter/Editor.vue', () => ({
  default: {
    props: ['modelValue'],
    emits: ['input'],
    template:
      '<textarea class="woot-editor" :value="modelValue" @input="$emit(\'input\', $event.target.value)" />',
  },
}));

const tools = [
  { id: 'faq_lookup', title: 'Search knowledge', emoji: '📚' },
  { id: 'handoff', title: 'Hand off to a person', emoji: '🙋' },
];

const store = createStore({
  modules: {
    captainTools: {
      namespaced: true,
      getters: { getRecords: () => tools },
    },
  },
});

const mountForm = props =>
  mount(ScenarioForm, {
    props: {
      title: 'Request a quote',
      description: 'Use when the customer asks for a quote.',
      instruction: '',
      ...props,
    },
    global: { plugins: [store] },
  });

describe('ScenarioForm', () => {
  it('shows the name, trigger and steps fields with the tool palette', () => {
    const wrapper = mountForm();

    expect(wrapper.find('input').element.value).toBe('Request a quote');
    expect(wrapper.find('textarea:not(.woot-editor)').element.value).toBe(
      'Use when the customer asks for a quote.'
    );
    expect(wrapper.find('.woot-editor').exists()).toBe(true);
    expect(wrapper.text()).toContain(
      'CAPTAIN.ASSISTANTS.SCENARIOS.PALETTE.TITLE'
    );
    expect(wrapper.find('[data-test="scenario-form-tools"]').text()).toContain(
      'CAPTAIN.ASSISTANTS.SCENARIOS.FORM.TOOLS.NONE'
    );
  });

  it('lists the linked tools and unlinks one while keeping its title as text', async () => {
    const wrapper = mountForm({
      instruction:
        '1. Check [@Search knowledge](tool://faq_lookup).\n2. Use [@Hand off to a person](tool://handoff).',
    });

    const toolsRow = wrapper.find('[data-test="scenario-form-tools"]');
    expect(toolsRow.text()).toContain('Search knowledge');
    expect(toolsRow.text()).toContain('Hand off to a person');

    await toolsRow.findAll('button')[0].trigger('click');

    expect(wrapper.emitted('update:instruction').at(-1)).toEqual([
      '1. Check Search knowledge.\n2. Use [@Hand off to a person](tool://handoff).',
    ]);
  });

  it('fails validation without steps', () => {
    const wrapper = mountForm();

    expect(wrapper.vm.validate()).toBe(false);
  });

  it('passes validation when every field is filled', () => {
    const wrapper = mountForm({ instruction: '1. Ask for the products.' });

    expect(wrapper.vm.validate()).toBe(true);
  });
});
