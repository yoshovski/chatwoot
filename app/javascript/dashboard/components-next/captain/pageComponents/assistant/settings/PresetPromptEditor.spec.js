import { mount } from '@vue/test-utils';
import PresetPromptEditor from './PresetPromptEditor.vue';
import ChoiceCard from './ChoiceCard.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const OPTIONS = [
  { id: 'friendly', label: 'Friendly' },
  { id: 'short', label: 'Direct' },
];

const mountEditor = props =>
  mount(PresetPromptEditor, {
    props: {
      name: 'tone',
      title: 'Tone',
      options: OPTIONS,
      selected: 'friendly',
      presetTexts: { friendly: 'Warm.', short: 'Skip pleasantries.' },
      field: 'tone',
      promptField: 'tone_prompt',
      ...props,
    },
  });

describe('PresetPromptEditor', () => {
  it('emits a preset and shows its instruction', () => {
    const wrapper = mountEditor();
    expect(wrapper.text()).toContain('Warm.');

    wrapper.findAllComponents(ChoiceCard)[1].vm.$emit('select');
    expect(wrapper.emitted('update')[0][0]).toEqual({ tone: 'short' });
  });

  it('saves an edited preset as custom', async () => {
    const wrapper = mountEditor();
    await wrapper.findAllComponents(ChoiceCard)[2].vm.$emit('select');
    expect(wrapper.emitted('update')).toBeUndefined();

    const textarea = wrapper.find('textarea');
    expect(textarea.element.value).toBe('Warm.');
    await textarea.setValue('Warm, use emoji sparingly.');
    const save = wrapper
      .findAll('button')
      .find(button => button.text().includes('CUSTOM_PROMPT.SAVE'));
    await save.trigger('click');

    expect(wrapper.emitted('update')[0][0]).toEqual({
      tone: 'custom',
      tone_prompt: 'Warm, use emoji sparingly.',
    });
  });

  it('marks custom active when a custom prompt is saved', () => {
    const wrapper = mountEditor({ selected: 'custom', customText: 'Calm.' });
    const active = wrapper
      .findAllComponents(ChoiceCard)
      .map(card => card.props('isActive'));

    expect(active).toEqual([false, false, true]);
    expect(wrapper.text()).toContain('Calm.');
  });
});
