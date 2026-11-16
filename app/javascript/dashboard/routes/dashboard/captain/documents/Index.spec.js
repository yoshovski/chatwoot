import { flushPromises, shallowMount } from '@vue/test-utils';
import Index from './Index.vue';

const mocks = vi.hoisted(() => ({
  apiGet: vi.fn(),
  dispatch: vi.fn(),
  route: null,
  getters: null,
}));
vi.mock('dashboard/components-next/captain/PageLayout.vue', () => ({
  default: { name: 'PageLayout' },
}));
vi.mock(
  'dashboard/components-next/captain/pageComponents/document/DocumentDetails.vue',
  () => ({ default: { name: 'DocumentDetails' } })
);
vi.mock(
  'dashboard/components-next/captain/pageComponents/document/CreateDocumentDialog.vue',
  () => ({ default: { name: 'CreateDocumentDialog' } })
);
vi.mock(
  'dashboard/components-next/captain/knowledge/WebsitePagesDialog.vue',
  () => ({ default: { name: 'WebsitePagesDialog' } })
);
vi.mock('dashboard/api/captain/document', () => ({
  default: { get: mocks.apiGet },
}));
vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  mocks.getters = {
    'captainDocuments/getRecords': ref([]),
    'captainDocuments/getMeta': ref({ page: 1, totalCount: 0 }),
    'captainDocuments/getUIFlags': ref({ fetchingList: false }),
  };
  return {
    useStore: () => ({ dispatch: mocks.dispatch }),
    useMapGetter: key => mocks.getters[key],
  };
});
vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions: () => true }),
}));
vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ currentAccount: { value: { features: {} } } }),
}));
vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));
vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));
vi.mock('vue-router', async importOriginal => {
  const actual = await importOriginal();
  const { reactive } = await import('vue');
  mocks.route = reactive({
    params: { accountId: 1, assistantId: 2 },
    query: {},
  });
  return { ...actual, useRoute: () => mocks.route };
});

const mountPage = () =>
  shallowMount(Index, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        DocumentFilter: false,
        PageLayout: {
          props: ['isEmpty', 'isFetching'],
          template: `<div><slot name="controls" /><div v-if="isFetching" role="status">Loading</div><slot v-else-if="isEmpty" name="emptyState" /><slot v-else name="body" /></div>`,
        },
        KnowledgeSourceBrowser: {
          template: '<div><slot /><slot name="filters" /></div>',
        },
      },
    },
  });

describe('Knowledge list load states', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.route.params.assistantId = 2;
    mocks.route.query = {};
    mocks.getters['captainDocuments/getRecords'].value = [];
    mocks.getters['captainDocuments/getMeta'].value = {
      page: 1,
      totalCount: 0,
    };
    mocks.getters['captainDocuments/getUIFlags'].value = {
      fetchingList: false,
    };
    mocks.dispatch.mockImplementation((action, payload) => {
      if (action.endsWith('/setFetchingList'))
        mocks.getters['captainDocuments/getUIFlags'].value.fetchingList =
          payload;
      if (action.endsWith('/setRecords')) {
        mocks.getters['captainDocuments/getRecords'].value = payload.records;
        mocks.getters['captainDocuments/getMeta'].value = {
          page: payload.meta.page,
          totalCount: payload.meta.total_count,
        };
      }
      return Promise.resolve();
    });
    mocks.apiGet.mockResolvedValue({
      data: { payload: [], meta: { page: 1, total_count: 0 } },
    });
  });

  it('shows failure for HTTP 503 and reaches first use only after successful retry', async () => {
    mocks.apiGet.mockRejectedValueOnce({ response: { status: 503 } });
    const wrapper = mountPage();
    expect(wrapper.text()).toContain('Loading');
    expect(
      wrapper.findComponent({ name: 'DocumentPageEmptyState' }).exists()
    ).toBe(false);
    await flushPromises();
    expect(wrapper.findComponent({ name: 'KnowledgeLoadError' }).exists()).toBe(
      true
    );
    expect(
      wrapper.findComponent({ name: 'DocumentPageEmptyState' }).exists()
    ).toBe(false);
    wrapper.findComponent({ name: 'KnowledgeLoadError' }).vm.$emit('retry');
    await flushPromises();
    expect(wrapper.findComponent({ name: 'KnowledgeLoadError' }).exists()).toBe(
      false
    );
    expect(
      wrapper.findComponent({ name: 'DocumentPageEmptyState' }).exists()
    ).toBe(true);
    wrapper.unmount();
  });

  it('preserves source, status, search, sort and page on retry', async () => {
    const wrapper = mountPage();
    await flushPromises();
    wrapper.vm.searchQuery = 'returns';
    wrapper.vm.sourceFilter = 'pdf';
    await flushPromises();
    const filter = wrapper.findComponent({ name: 'DocumentFilter' });
    const bar = filter.findComponent({ name: 'DocumentFiltersBar' });
    bar.vm.$emit('selectStatus', 'failed');
    bar.vm.$emit('selectSort', 'recently_created');
    await flushPromises();
    mocks.apiGet.mockRejectedValueOnce({ response: { status: 503 } });
    await wrapper.vm.fetchDocuments(2);
    await flushPromises();
    wrapper.findComponent({ name: 'KnowledgeLoadError' }).vm.$emit('retry');
    await flushPromises();
    expect(mocks.apiGet).toHaveBeenLastCalledWith({
      assistantId: 2,
      source: 'pdf',
      searchKey: 'returns',
      filter: 'failed',
      sort: 'recently_created',
      page: 2,
    });
    expect(wrapper.text()).toContain(
      'CAPTAIN.DOCUMENTS.EMPTY_STATE.FILTERED_TITLE'
    );
    wrapper.unmount();
  });

  it('retains and labels stale rows after refresh fails, then clears error on retry', async () => {
    const doc = {
      id: 1,
      name: 'Returns',
      external_link: 'https://example.com/returns',
      created_at: 1,
    };
    mocks.apiGet.mockResolvedValueOnce({
      data: { payload: [doc], meta: { page: 1, total_count: 1 } },
    });
    const wrapper = mountPage();
    await flushPromises();
    mocks.apiGet.mockRejectedValueOnce(new Error('Unavailable'));
    await wrapper.vm.refreshDocumentsPage();
    await flushPromises();
    expect(
      wrapper.findComponent({ name: 'KnowledgeLoadError' }).props('stale')
    ).toBe(true);
    expect(wrapper.findAllComponents({ name: 'DocumentCard' })).toHaveLength(1);
    expect(
      wrapper.findComponent({ name: 'KnowledgeBulkActions' }).exists()
    ).toBe(false);
    wrapper.findComponent({ name: 'KnowledgeLoadError' }).vm.$emit('retry');
    await flushPromises();
    expect(wrapper.findComponent({ name: 'KnowledgeLoadError' }).exists()).toBe(
      false
    );
    wrapper.unmount();
  });

  it('ignores an old assistant request failure after switching assistants', async () => {
    let rejectOld;
    mocks.apiGet.mockImplementationOnce(
      () =>
        new Promise((resolve, reject) => {
          rejectOld = reject;
        })
    );
    const wrapper = mountPage();
    mocks.route.params.assistantId = 3;
    await flushPromises();
    rejectOld(new Error('Old request'));
    await flushPromises();
    expect(wrapper.findComponent({ name: 'KnowledgeLoadError' }).exists()).toBe(
      false
    );
    expect(mocks.apiGet).toHaveBeenLastCalledWith(
      expect.objectContaining({ assistantId: 3 })
    );
    wrapper.unmount();
  });
});
