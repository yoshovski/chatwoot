import { describe, it, expect, afterEach, vi } from 'vitest';
import { nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import { Selection } from '@chatwoot/prosemirror-schema';
import Editor from './Editor.vue';

let view = null;

vi.mock('@chatwoot/prosemirror-schema', async importOriginal => {
  const actual = await importOriginal();
  class TrackedEditorView extends actual.EditorView {
    constructor(...args) {
      super(...args);
      view = this;
    }
  }
  return { ...actual, EditorView: TrackedEditorView };
});

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

vi.mock('dashboard/composables/useCaptain', () => ({
  useCaptain: () => ({
    isCaptainEnabled: { value: false },
    captainTasksEnabled: { value: false },
  }),
}));

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({
    isEditorHotKeyEnabled: () => false,
    fetchSignatureFlagFromUISettings: () => false,
  }),
}));

vi.mock('dashboard/composables', () => ({
  useTrack: vi.fn(),
  useAlert: vi.fn(),
}));

const zeroRect = { top: 0, bottom: 0, left: 0, right: 0, width: 0, height: 0 };
Range.prototype.getClientRects = () => [zeroRect];
Range.prototype.getBoundingClientRect = () => zeroRect;
Element.prototype.scrollIntoView = () => {};

describe('EditorTools', () => {
  let wrapper;
  const sampleTools = [
    {
      id: 'faq_lookup',
      emoji: '📚',
      title: 'Search knowledge',
      description: 'Finds answers',
    },
    {
      id: 'catalog_product_search',
      emoji: '🛍️',
      title: 'Find products',
      description: 'Searches catalog',
    },
  ];

  const store = createStore({
    getters: {
      'captainTools/getRecords': () => sampleTools,
    },
  });

  const mountEditor = (props = {}) => {
    wrapper = mount(Editor, {
      props: {
        modelValue: '',
        enableCaptainTools: true,
        ...props,
      },
      global: {
        plugins: [store],
        mocks: {
          $t: msg => msg,
        },
      },
      attachTo: document.body,
    });
    return wrapper;
  };

  afterEach(() => {
    if (wrapper) wrapper.unmount();
    view = null;
  });

  const typeWithRules = text => {
    [...text].forEach(character => {
      const { from, to } = view.state.selection;
      const handled = view.someProp('handleTextInput', rule =>
        rule(view, from, to, character)
      );
      if (!handled)
        view.dispatch(view.state.tr.insertText(character, from, to));
    });
  };

  it('opens tools menu when @ is typed after "use " in a paragraph', async () => {
    mountEditor();
    typeWithRules('use @');
    await nextTick();

    expect(wrapper.findComponent({ name: 'TagTools' }).exists()).toBe(true);
  });

  it('opens tools menu when @ is typed inside a list item', async () => {
    mountEditor({
      modelValue: '1. Step one\n2. Step two',
    });

    const endPos = Selection.atEnd(view.state.doc).from;
    view.dispatch(
      view.state.tr.setSelection(Selection.near(view.state.doc.resolve(endPos)))
    );

    typeWithRules(' use @');
    await nextTick();

    expect(wrapper.findComponent({ name: 'TagTools' }).exists()).toBe(true);
  });

  it('inserts tool node at caret with trailing space via insertTool', async () => {
    mountEditor({
      modelValue: 'Please check ',
    });

    const endPos = Selection.atEnd(view.state.doc).from;
    view.dispatch(
      view.state.tr.setSelection(Selection.near(view.state.doc.resolve(endPos)))
    );
    view.focus();

    wrapper.vm.insertTool(sampleTools[0]);
    await nextTick();

    const emitted = wrapper.emitted('update:modelValue');
    expect(emitted).toBeTruthy();
    const lastEmitted = emitted[emitted.length - 1][0];
    expect(lastEmitted).toContain('[@Search knowledge](tool://faq_lookup)');
  });

  it('inserts tool node at end of document if editor is not focused', async () => {
    mountEditor({
      modelValue: 'Initial text.',
    });

    wrapper.vm.insertTool(sampleTools[1]);
    await nextTick();

    const emitted = wrapper.emitted('update:modelValue');
    expect(emitted).toBeTruthy();
    const lastEmitted = emitted[emitted.length - 1][0];
    expect(lastEmitted).toContain(
      '[@Find products](tool://catalog_product_search)'
    );
  });
});
