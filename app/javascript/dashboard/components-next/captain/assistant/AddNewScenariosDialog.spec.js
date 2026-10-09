import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import AddNewScenariosDialog from './AddNewScenariosDialog.vue';
import { createStore } from 'vuex';
import CaptainScenarios from 'dashboard/api/captain/scenarios';

vi.mock('dashboard/components/widgets/WootWriter/Editor.vue', () => ({
  default: {
    props: ['modelValue'],
    emits: ['input'],
    template: '<textarea class="woot-editor" :value="modelValue" />',
  },
}));

const store = createStore({
  modules: {
    captainTools: { namespaced: true, getters: { getRecords: () => [] } },
  },
});

vi.mock('dashboard/api/captain/scenarios', () => ({
  default: {
    draft: vi.fn(),
  },
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { assistantId: '12' },
  }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

describe('AddNewScenariosDialog', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  const createWrapper = (props = {}) => {
    return mount(AddNewScenariosDialog, {
      props: {
        assistantId: 12,
        tools: [
          { id: 'faq_lookup', title: 'Search knowledge' },
          { id: 'handoff', title: 'Hand off to a person' },
        ],
        ...props,
      },
      global: {
        plugins: [store],
        stubs: {
          Dialog: {
            template:
              '<div class="dialog-stub" v-if="isOpen"><slot /><slot name="footer" /></div>',
            data() {
              return { isOpen: false };
            },
            methods: {
              open() {
                this.isOpen = true;
              },
              close() {
                this.isOpen = false;
              },
            },
          },
          TemplateCard: {
            props: ['template'],
            template:
              '<button class="template-card-stub" @click="$emit(\'use\', template)">{{ template.title }}</button>',
          },
        },
        mocks: {
          $t: msg => msg,
        },
      },
    });
  };

  it('renders trigger button and defaults to Describe it tab when opened', async () => {
    const wrapper = createWrapper();
    const button = wrapper.find('button');
    expect(button.exists()).toBe(true);

    await button.trigger('click');
    expect(wrapper.vm.activeChoice).toBe('describe');
    expect(wrapper.find('.dialog-stub').exists()).toBe(true);
  });

  it('fills prompt when an example prompt is clicked', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');

    const exampleButtons = wrapper
      .findAll('button[type="button"]')
      .filter(b => b.text().includes('EXAMPLE_1'));
    expect(exampleButtons.length).toBeGreaterThan(0);

    await exampleButtons[0].trigger('click');
    expect(wrapper.vm.describePrompt.length).toBeGreaterThan(0);
  });

  it('calls CaptainScenarios.draft on Build scenario and transitions to preview', async () => {
    CaptainScenarios.draft.mockResolvedValueOnce({
      data: {
        title: 'Return an item',
        description: 'Use when the customer asks to return',
        instruction:
          '1. Collect details\n2. [@Search knowledge](tool://faq_lookup)',
        tools: ['faq_lookup'],
        notes: ['A shipping label tool would help.'],
      },
    });

    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');

    wrapper.vm.describePrompt = 'Handle customer returns for damaged items';
    await wrapper.vm.generateDraft();

    expect(CaptainScenarios.draft).toHaveBeenCalledWith({
      assistantId: 12,
      description: 'Handle customer returns for damaged items',
    });

    expect(wrapper.vm.draftResult).not.toBeNull();
    expect(wrapper.vm.previewState.title).toBe('Return an item');
    expect(wrapper.vm.previewState.notes).toEqual([
      'A shipping label tool would help.',
    ]);
  });

  it('emits add when saving draft scenario from preview', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');

    wrapper.vm.draftResult = { id: 'temp' };
    wrapper.vm.previewState.title = 'AI Draft Title';
    wrapper.vm.previewState.description = 'AI Draft Description';
    wrapper.vm.previewState.instruction = 'AI Draft Instruction';
    await wrapper.vm.$nextTick();

    wrapper.vm.saveDraftScenario();

    expect(wrapper.emitted('add')).toEqual([
      [
        {
          title: 'AI Draft Title',
          description: 'AI Draft Description',
          instruction: 'AI Draft Instruction',
        },
      ],
    ]);
  });

  it('switches to template tab and emits useTemplate when a template card is clicked', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');

    wrapper.vm.setChoice('template');
    await wrapper.vm.$nextTick();

    const templateCards = wrapper.findAll('.template-card-stub');
    expect(templateCards.length).toBeGreaterThan(0);

    await templateCards[0].trigger('click');
    expect(wrapper.emitted('useTemplate')).toBeTruthy();
  });

  it('switches to manual tab and validates required fields before adding', async () => {
    const wrapper = createWrapper();
    await wrapper.find('button').trigger('click');

    wrapper.vm.setChoice('manual');
    await wrapper.vm.$nextTick();
    expect(wrapper.find('.woot-editor').exists()).toBe(true);

    // Try submit empty
    await wrapper.vm.onClickAddManual();
    expect(wrapper.emitted('add')).toBeUndefined();

    // Fill fields and submit
    wrapper.vm.manualState.title = 'Manual Scenario';
    wrapper.vm.manualState.description = 'Manual Description';
    wrapper.vm.manualState.instruction = 'Manual Instruction';
    await wrapper.vm.$nextTick();

    await wrapper.vm.onClickAddManual();
    expect(wrapper.emitted('add')).toEqual([
      [
        {
          title: 'Manual Scenario',
          description: 'Manual Description',
          instruction: 'Manual Instruction',
        },
      ],
    ]);
  });
});
