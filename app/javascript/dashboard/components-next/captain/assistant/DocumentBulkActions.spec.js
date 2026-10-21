import { shallowMount, flushPromises } from '@vue/test-utils';
import DocumentBulkActions from './DocumentBulkActions.vue';

const { update } = vi.hoisted(() => ({ update: vi.fn() }));
vi.mock('dashboard/api/captain/document', () => ({ default: { update } }));
vi.mock('dashboard/composables/store', () => ({
  useStore: () => ({ dispatch: vi.fn() }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

describe('DocumentBulkActions', () => {
  it('disables only the selected visible documents and keeps failed updates selected', async () => {
    update.mockImplementation(id =>
      id === 2 ? Promise.reject(new Error('failed')) : Promise.resolve({})
    );
    const wrapper = shallowMount(DocumentBulkActions, {
      props: {
        selectedIds: new Set([1, 2]),
        documents: [{ id: 1 }, { id: 2 }, { id: 3 }],
      },
      global: {
        mocks: { $t: key => key },
        stubs: {
          BulkSelectBar: {
            template: '<div><slot name="secondaryActions" /></div>',
          },
          Button: {
            props: ['label'],
            template: '<button>{{ label }}</button>',
          },
        },
      },
    });
    const disable = wrapper
      .findAll('button')
      .find(button => button.text() === 'PLATFORM_NAV.DISABLE_AI');
    await disable.trigger('click');
    await flushPromises();
    expect(update).toHaveBeenCalledTimes(2);
    expect(update).toHaveBeenCalledWith(1, { document: { enabled: false } });
    expect(wrapper.emitted('update:selectedIds').at(-1)).toEqual([
      new Set([2]),
    ]);
    expect(wrapper.emitted('bulkUpdated')).toHaveLength(1);
  });
});
