import { mount } from '@vue/test-utils';
import PresetPromptEditor from './PresetPromptEditor.vue';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const OPTIONS = [
  { id: 'friendly', label: 'Friendly' },
  { id: 'short', label: 'Direct' },
];

const options = wrapper => wrapper.findAll('[role="radio"]');
const buttonWith = (wrapper, key) =>
  wrapper.findAll('button').find(button => button.text().includes(key));

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
  it('emits a preset and shows its instruction on request', async () => {
    const wrapper = mountEditor();
    expect(wrapper.text()).not.toContain('Warm.');

    await buttonWith(wrapper, 'CUSTOM_PROMPT.VIEW').trigger('click');
    expect(wrapper.text()).toContain('Warm.');

    await options(wrapper)[1].trigger('click');
    expect(wrapper.emitted('update')[0][0]).toEqual({ tone: 'short' });
  });

  it('saves an edited preset as custom', async () => {
    const wrapper = mountEditor();
    await options(wrapper)[2].trigger('click');
    expect(wrapper.emitted('update')).toBeUndefined();

    const textarea = wrapper.find('textarea');
    expect(textarea.element.value).toBe('Warm.');
    await textarea.setValue('Warm, use emoji sparingly.');
    await buttonWith(wrapper, 'CUSTOM_PROMPT.SAVE').trigger('click');

    expect(wrapper.emitted('update')[0][0]).toEqual({
      tone: 'custom',
      tone_prompt: 'Warm, use emoji sparingly.',
    });
  });

  it('marks custom active when a custom prompt is saved', async () => {
    const wrapper = mountEditor({ selected: 'custom', customText: 'Calm.' });
    const active = options(wrapper).map(option =>
      option.attributes('aria-checked')
    );

    expect(active).toEqual(['false', 'false', 'true']);
    await buttonWith(wrapper, 'CUSTOM_PROMPT.VIEW').trigger('click');
    expect(wrapper.text()).toContain('Calm.');
  });
});
