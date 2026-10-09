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

vi.mock('dashboard/composables/useAccount', () => ({
  useAccount: () => ({ isOnChatwootCloud: false }),
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
  template:
    '<div><slot name="controls" /><slot name="subHeader" /><slot name="body" /></div>',
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
});
