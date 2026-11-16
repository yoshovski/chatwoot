import { flushPromises, shallowMount } from '@vue/test-utils';
import CreateResponseDialog from './CreateResponseDialog.vue';

const mocks = vi.hoisted(() => ({ dispatch: vi.fn(), close: vi.fn() }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: mocks.dispatch }),
  useMapGetter: () => ({ value: { creatingItem: false, updatingItem: false } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { assistantId: 2 } }),
}));

describe('FAQ edit failure', () => {
  it('keeps edited question, answer and audience after failure and retries the same values', async () => {
    mocks.dispatch.mockRejectedValueOnce(new Error('Unavailable'));
    const wrapper = shallowMount(CreateResponseDialog, {
      props: {
        type: 'edit',
        selectedResponse: {
          id: 10,
          question: 'Old question',
          answer: 'Old answer',
          agents_only: true,
        },
      },
      global: {
        mocks: { $t: key => key },
        stubs: {
          SidePanel: {
            template: '<div><slot /></div>',
            methods: { close: mocks.close },
          },
          ResponseForm: false,
        },
      },
    });
    const form = wrapper.findComponent({ name: 'ResponseForm' });
    form
      .findComponent({ name: 'Input' })
      .vm.$emit('update:modelValue', 'Updated question');
    form
      .findComponent({ name: 'Editor' })
      .vm.$emit('update:modelValue', 'Updated answer');
    await form.find('select').setValue(false);
    await form.find('form').trigger('submit');
    await flushPromises();
    expect(mocks.close).not.toHaveBeenCalled();
    expect(form.findComponent({ name: 'Input' }).props('modelValue')).toBe(
      'Updated question'
    );
    expect(form.findComponent({ name: 'Editor' }).props('modelValue')).toBe(
      'Updated answer'
    );
    mocks.dispatch.mockResolvedValueOnce({});
    await form.find('form').trigger('submit');
    await flushPromises();
    expect(mocks.dispatch).toHaveBeenNthCalledWith(
      2,
      'captainResponses/update',
      {
        id: 10,
        assistant_id: 2,
        question: 'Updated question',
        answer: 'Updated answer',
        agents_only: false,
      }
    );
    expect(mocks.close).toHaveBeenCalledOnce();
    wrapper.unmount();
  });
});
