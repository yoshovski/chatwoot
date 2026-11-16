import { flushPromises, shallowMount } from '@vue/test-utils';
import Index from './Index.vue';

const mocks = vi.hoisted(() => ({
  apiGet: vi.fn(),
  dispatch: vi.fn().mockResolvedValue([]),
  replace: vi.fn(),
  route: null,
  getterValues: null,
}));

vi.mock('dashboard/api/captain/response', () => ({
  default: { get: mocks.apiGet },
}));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  mocks.getterValues = {
    'captainResponses/getRecords': ref([]),
    'captainResponses/getMeta': ref({ totalCount: 0, page: 1 }),
    'captainFaqSuggestions/getOpenCount': ref(0),
    'captainResponses/getUIFlags': ref({
      fetchingList: false,
      updatingItem: false,
      deletingItem: false,
    }),
  };

  return {
    useStore: () => ({
      dispatch: mocks.dispatch,
      getters: {
        'captainDocuments/getRecord': id => ({ id, name: 'Refund policy' }),
      },
    }),
    useMapGetter: key => mocks.getterValues[key],
  };
});

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions: () => true }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

const translate = (key, values) => {
  if (values?.name) return `From: ${values.name}`;
  return key;
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: translate }),
}));

vi.mock('vue-router', async importOriginal => {
  const actual = await importOriginal();
  const { reactive } = await import('vue');
  mocks.route = reactive({
    params: { accountId: 1, assistantId: 2 },
    query: {},
  });

  return {
    ...actual,
    useRoute: () => mocks.route,
    useRouter: () => ({ replace: mocks.replace }),
  };
});

const PageLayoutStub = {
  props: ['isEmpty', 'isFetching'],
  template:
    '<div><slot name="controls" /><div v-if="isFetching">Loading</div><slot v-else-if="isEmpty" name="emptyState" /><slot v-else name="body" /></div>',
};

const mountPage = () =>
  shallowMount(Index, {
    global: {
      directives: { onClickaway: {} },
      mocks: { $t: translate },
      stubs: {
        PageLayout: PageLayoutStub,
        KnowledgeHeader: true,
        ResponseCard: true,
        Input: true,
        Icon: true,
        DropdownMenu: true,
        Button: true,
      },
    },
  });

describe('Captain Responses Index', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.dispatch.mockImplementation((action, payload) => {
      if (action.endsWith('/setFetchingList'))
        mocks.getterValues['captainResponses/getUIFlags'].value.fetchingList =
          payload;
      if (action === 'captainResponses/setRecords') {
        mocks.getterValues['captainResponses/getRecords'].value =
          payload.records;
      }
      return Promise.resolve([]);
    });
    mocks.route.params = { accountId: 1, assistantId: 2 };
    mocks.route.query = {};
    mocks.getterValues['captainResponses/getRecords'].value = [];
    mocks.getterValues['captainResponses/getMeta'].value = {
      totalCount: 0,
      page: 1,
    };
    mocks.apiGet.mockResolvedValue({
      data: {
        payload: [],
        meta: { total_count: 0, page: 1 },
      },
    });
  });

  it('fetches responses with documentId from route query and displays filter chip', async () => {
    mocks.route.query = { document_id: '42' };

    const wrapper = mountPage();
    await flushPromises();

    expect(mocks.apiGet).toHaveBeenCalledWith(
      expect.objectContaining({
        assistantId: 2,
        page: 1,
        documentId: 42,
      })
    );

    // Check that source filter chip is displayed
    expect(wrapper.text()).toContain('From: Refund policy');

    wrapper.unmount();
  });
  it('shows an error for HTTP 503 and retries with search and source filters intact', async () => {
    mocks.route.query = { search: 'shipping', source_type: 'file' };
    mocks.apiGet.mockRejectedValueOnce({ response: { status: 503 } });
    const wrapper = mountPage();
    await flushPromises();
    expect(
      wrapper.findComponent({ name: 'ResponsePageEmptyState' }).exists()
    ).toBe(false);
    wrapper.findComponent({ name: 'KnowledgeLoadError' }).vm.$emit('retry');
    await flushPromises();
    expect(mocks.apiGet).toHaveBeenLastCalledWith(
      expect.objectContaining({
        search: 'shipping',
        origin: 'file',
        assistantId: 2,
      })
    );
    expect(wrapper.findComponent({ name: 'KnowledgeLoadError' }).exists()).toBe(
      false
    );
    expect(wrapper.findComponent({ name: 'EmptyState' }).props('title')).toBe(
      'CAPTAIN.RESPONSES.EMPTY_STATE.FILTERED_TITLE'
    );
    wrapper.unmount();
  });

  it('retains FAQs and labels them stale after a failed refresh', async () => {
    mocks.apiGet.mockResolvedValueOnce({
      data: {
        payload: [{ id: 1, question: 'Returns?', answer: 'Within 30 days.' }],
        meta: { page: 1, total_count: 1 },
      },
    });
    const wrapper = mountPage();
    await flushPromises();
    mocks.apiGet.mockRejectedValueOnce(new Error('Unavailable'));
    await wrapper.vm.fetchResponses();
    await flushPromises();
    expect(
      wrapper.findComponent({ name: 'KnowledgeLoadError' }).props('stale')
    ).toBe(true);
    expect(wrapper.findAllComponents({ name: 'FaqRow' })).toHaveLength(1);
    expect(
      wrapper.findComponent({ name: 'KnowledgeBulkActions' }).exists()
    ).toBe(false);
    wrapper.unmount();
  });
});
