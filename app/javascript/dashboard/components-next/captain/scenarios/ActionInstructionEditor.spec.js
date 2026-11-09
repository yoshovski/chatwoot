import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { nextTick } from 'vue';
import ActionInstructionEditor from './ActionInstructionEditor.vue';

const tools = [
  {
    id: 'faq_lookup',
    title: 'Search knowledge',
    emoji: '📚',
    description: 'Find answers in documents',
  },
  {
    id: 'handoff',
    title: 'Hand off to a person',
    emoji: '🙋',
    description: 'Transfer conversation',
  },
  {
    id: 'add_private_note',
    title: 'Add a private note',
    emoji: '📝',
    description: 'Leave an internal note',
  },
];

const store = createStore({
  modules: {
    captainTools: {
      namespaced: true,
      getters: { getRecords: () => tools },
    },
  },
});

const mountEditor = (props = {}) =>
  mount(ActionInstructionEditor, {
    props: {
      modelValue: '',
      tools,
      ...props,
    },
    global: {
      plugins: [store],
      stubs: {
        ToolPalette: true,
      },
    },
  });

describe('ActionInstructionEditor', () => {
  it('renders markdown tool links as visual chips with emojis', async () => {
    const wrapper = mountEditor({
      modelValue:
        'Ask questions with [@Search knowledge](tool://faq_lookup) and finish.',
    });
    await nextTick();

    const editorEl = wrapper.find(
      '[data-test="scenario-instruction-editor"]'
    ).element;
    const chip = editorEl.querySelector('[data-tool="faq_lookup"]');
    expect(chip).not.toBeNull();
    expect(chip.textContent).toContain('📚');
    expect(chip.textContent).toContain('Search knowledge');
  });

  it('inserts an action chip when insertTool is called', async () => {
    const wrapper = mountEditor({
      modelValue: 'Initial text ',
    });
    await nextTick();

    wrapper.vm.insertTool({
      id: 'handoff',
      title: 'Hand off to a person',
      emoji: '🙋',
    });
    await nextTick();

    const emitted = wrapper.emitted('update:modelValue');
    expect(emitted).toBeTruthy();
    expect(emitted.at(-1)[0]).toContain(
      '[@Hand off to a person](tool://handoff)'
    );
  });

  it('preserves line breaks and plain text on serialization', async () => {
    const wrapper = mountEditor({
      modelValue: 'Line 1\nLine 2',
    });
    await nextTick();

    const editorEl = wrapper.find(
      '[data-test="scenario-instruction-editor"]'
    ).element;
    expect(editorEl.innerHTML).toContain('<br>');
  });
});
