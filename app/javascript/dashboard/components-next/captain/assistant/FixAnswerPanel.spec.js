import { flushPromises, mount } from '@vue/test-utils';
import { useAlert } from 'dashboard/composables';
import FixAnswerPanel from './FixAnswerPanel.vue';

const dispatch = vi.fn();

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch }),
}));

const SidePanel = {
  template: '<div><slot /><slot name="footer" /></div>',
  methods: { open() {}, close: vi.fn() },
};

const reply = {
  id: 1,
  question: 'How do returns work?',
  answer: 'Returns take 14 days.',
};

const mountPanel = async () => {
  const wrapper = mount(FixAnswerPanel, {
    props: { assistantId: 4 },
    global: {
      stubs: {
        SidePanel,
        Input: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<input data-test="question" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        TextArea: {
          props: ['modelValue'],
          emits: ['update:modelValue'],
          template:
            '<textarea data-test="text" :value="modelValue" @input="$emit(\'update:modelValue\', $event.target.value)" />',
        },
        NextButton: {
          props: ['disabled'],
          template: '<button data-test="save" :disabled="disabled" />',
        },
      },
    },
  });
  wrapper.vm.open(reply);
  await flushPromises();
  return wrapper;
};

describe('FixAnswerPanel', () => {
  beforeEach(() => {
    dispatch.mockReset();
    useAlert.mockReset();
  });

  it('saves the corrected answer as an FAQ for the question asked', async () => {
    dispatch.mockResolvedValue({});
    const wrapper = await mountPanel();

    expect(wrapper.find('[data-test="question"]').element.value).toBe(
      'How do returns work?'
    );
    await wrapper
      .find('[data-test="text"]')
      .setValue('Returns are free within 30 days.');
    await wrapper.find('[data-test="save"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('captainResponses/create', {
      question: 'How do returns work?',
      answer: 'Returns are free within 30 days.',
      assistant_id: 4,
    });
    expect(useAlert).toHaveBeenCalledWith(
      'CAPTAIN.PLAYGROUND.WIDGET_TEST.FIX.SAVED'
    );
    expect(wrapper.emitted('saved')).toEqual([[reply]]);
  });

  it('adds a rule after the rules already saved', async () => {
    dispatch.mockImplementation(action =>
      Promise.resolve(
        action === 'captainAssistants/show'
          ? { response_guidelines: ['Be brief'] }
          : {}
      )
    );
    const wrapper = await mountPanel();

    await wrapper.findAll('[role="group"] button')[1].trigger('click');
    expect(
      wrapper.find('[data-test="save"]').attributes('disabled')
    ).toBeDefined();
    await wrapper
      .find('[data-test="text"]')
      .setValue('Mention the free return label.');
    await wrapper.find('[data-test="save"]').trigger('click');
    await flushPromises();

    expect(dispatch).toHaveBeenCalledWith('captainAssistants/update', {
      id: 4,
      assistant: {
        response_guidelines: ['Be brief', 'Mention the free return label.'],
      },
    });
    expect(wrapper.emitted('saved')).toEqual([[reply]]);
  });

  it('keeps the panel open and says why when saving fails', async () => {
    dispatch.mockRejectedValue(new Error('Question has already been taken'));
    const wrapper = await mountPanel();

    await wrapper.find('[data-test="save"]').trigger('click');
    await flushPromises();

    expect(useAlert).toHaveBeenCalledWith('Question has already been taken');
    expect(wrapper.emitted('saved')).toBeUndefined();
  });
});
