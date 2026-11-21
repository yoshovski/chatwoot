import { mount } from '@vue/test-utils';
import { createStore } from 'vuex';
import ChatForm from '../ChatForm.vue';

const store = createStore({
  modules: {
    appConfig: {
      namespaced: true,
      getters: {
        getWidgetColor: () => '#007aff',
        getWidgetTextColor: () => '#fff',
      },
    },
  },
});

describe('ChatForm', () => {
  it.each([
    ['it', 'Indirizzo email', 'Controlla questo campo.'],
    ['es', 'Correo electrónico', 'Revisa este campo.'],
  ])(
    'uses inline form validation in %s and blocks invalid submission',
    async (language, label, error) => {
      const wrapper = mount(ChatForm, {
        props: {
          language,
          items: [
            {
              name: 'email',
              type: 'email',
              required: true,
              label,
              pattern_error: error,
            },
          ],
        },
        global: { plugins: [store] },
      });

      const form = wrapper.get('form');
      const field = wrapper.get('input');
      expect(form.element.noValidate).toBe(true);
      expect(wrapper.get('label').attributes('for')).toBe(
        field.attributes('id')
      );

      await field.setValue('invalid email');
      await form.trigger('submit');
      expect(wrapper.get('.has-submitted .error-message').text()).toBe(error);
      expect(wrapper.emitted('submit')).toBeUndefined();

      await field.setValue('ada@example.com');
      await form.trigger('submit');
      expect(wrapper.emitted('submit')).toEqual([
        [{ email: 'ada@example.com' }],
      ]);
    }
  );
});
