import { mount } from '@vue/test-utils';
import { withFullI18n } from 'test-i18n';
import AssistantMessageTranslations from './AssistantMessageTranslations.vue';

withFullI18n();

describe('AssistantMessageTranslations', () => {
  it('edits one locale while preserving the other languages', async () => {
    const wrapper = mount(AssistantMessageTranslations, {
      props: {
        config: {
          auto_translate_messages: true,
          localized_messages: {
            handoff_form_message: { en: 'Leave your contact details.' },
          },
        },
        generated: {
          handoff_form_message: { it: 'Lascia i tuoi recapiti.' },
        },
        languages: [
          { value: 'en', label: 'English' },
          { value: 'it', label: 'Italiano' },
        ],
      },
    });

    await wrapper.get('select').setValue('it');
    expect(wrapper.text()).toContain('Lascia i tuoi recapiti.');
    const formCopy = wrapper
      .findAll('label')
      .find(label => label.text().includes('Handoff contact form message'));
    await formCopy.get('textarea').setValue('Dove possiamo contattarti?');

    expect(wrapper.emitted('change').at(-1)).toEqual([
      {
        localized_messages: {
          handoff_form_message: {
            en: 'Leave your contact details.',
            it: 'Dove possiamo contattarti?',
          },
        },
      },
    ]);
  });
});
