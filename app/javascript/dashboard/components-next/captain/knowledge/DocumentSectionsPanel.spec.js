import { shallowMount, flushPromises } from '@vue/test-utils';
import DocumentSectionsPanel from './DocumentSectionsPanel.vue';

const { sections, sectionAction, useAlert } = vi.hoisted(() => ({
  sections: vi.fn(),
  sectionAction: vi.fn(),
  useAlert: vi.fn(),
}));

vi.mock('dashboard/api/captain/knowledgeSources', () => ({
  default: { sections, sectionAction },
}));
vi.mock('dashboard/composables', () => ({ useAlert }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const ButtonStub = {
  props: ['label', 'disabled', 'isLoading'],
  emits: ['click'],
  template:
    '<button type="button" :data-label="label" @click="$emit(\'click\')">{{ label }}</button>',
};
const CheckboxStub = {
  props: ['modelValue'],
  emits: ['update:modelValue'],
  template:
    '<input type="checkbox" :checked="modelValue" @change="$emit(\'update:modelValue\', !modelValue)" />',
};

const groups = [
  {
    key: 'example.com/resources',
    count: 14,
    ready: 12,
    syncing: 0,
    failed: 2,
    paused: 0,
  },
  { key: 'files', count: 3, ready: 3, syncing: 0, failed: 0, paused: 0 },
];

const mountPanel = () =>
  shallowMount(DocumentSectionsPanel, {
    props: { assistantId: 4 },
    global: {
      mocks: { $t: key => key },
      stubs: { Button: ButtonStub, Checkbox: CheckboxStub, Dialog: true },
    },
  });

describe('DocumentSectionsPanel', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    sections.mockResolvedValue({ data: { sections: groups } });
    sectionAction.mockResolvedValue({ data: { count: 14 } });
  });

  it('pauses every selected section in one request and asks the page to refresh', async () => {
    const wrapper = mountPanel();
    await flushPromises();
    await wrapper.get('button[aria-expanded]').trigger('click');

    await wrapper.findAll('input[type="checkbox"]')[0].trigger('change');
    await wrapper
      .get('[data-label="CAPTAIN.DOCUMENT_SECTIONS.ACTIONS.PAUSE"]')
      .trigger('click');
    await flushPromises();

    expect(sectionAction).toHaveBeenCalledWith(
      4,
      ['example.com/resources'],
      'pause'
    );
    expect(wrapper.emitted('changed')).toHaveLength(1);
  });

  it('filters the list to a section and back', async () => {
    const wrapper = mountPanel();
    await flushPromises();
    await wrapper.get('button[aria-expanded]').trigger('click');

    await wrapper
      .findAll('[data-label="CAPTAIN.DOCUMENT_SECTIONS.SHOW"]')[0]
      .trigger('click');

    expect(wrapper.emitted('update:activeSection')).toEqual([
      ['example.com/resources'],
    ]);
  });

  it('stays hidden for a small library', async () => {
    sections.mockResolvedValue({ data: { sections: [groups[1]] } });
    const wrapper = mountPanel();
    await flushPromises();

    expect(wrapper.find('section').exists()).toBe(false);
  });
});
