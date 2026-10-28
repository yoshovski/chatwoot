import { flushPromises, shallowMount } from '@vue/test-utils';
import FaqSuggestions from './FaqSuggestions.vue';

const mocks = vi.hoisted(() => ({
  apiGet: vi.fn(),
  gapsGet: vi.fn(),
  dispatch: vi.fn(),
  replace: vi.fn(),
  route: null,
  getterValues: null,
}));

vi.mock('dashboard/api/captain/faqSuggestions', () => ({
  default: { get: mocks.apiGet },
}));

vi.mock('dashboard/api/captain/knowledgeGaps', () => ({
  default: { get: mocks.gapsGet },
}));

vi.mock('dashboard/composables/store', async () => {
  const { ref } = await import('vue');
  mocks.getterValues = {
    'captainFaqSuggestions/getRecords': ref([]),
    'captainFaqSuggestions/getMeta': ref({ totalCount: 0, page: 1 }),
    'captainFaqSuggestions/getUIFlags': ref({
      fetchingList: false,
      updatingItem: false,
      deletingItem: false,
    }),
  };

  return {
    useStore: () => ({ dispatch: mocks.dispatch }),
    useMapGetter: key => mocks.getterValues[key],
  };
});

vi.mock('dashboard/composables', () => ({ useAlert: vi.fn() }));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('vue-router', async importOriginal => {
  const actual = await importOriginal();
  const { reactive } = await import('vue');
  mocks.route = reactive({
    params: { accountId: 1, assistantId: 1 },
    query: {},
  });

  return {
    ...actual,
    useRoute: () => mocks.route,
    useRouter: () => ({ replace: mocks.replace }),
  };
});

const deferred = () => {
  let resolve;
  let reject;
  const promise = new Promise((resolvePromise, rejectPromise) => {
    resolve = resolvePromise;
    reject = rejectPromise;
  });
  return { promise, resolve, reject };
};

const PageLayoutStub = {
  template: '<div><slot name="body" /></div>',
};

const FaqSuggestionCardStub = {
  props: ['suggestion'],
  template: '<div>{{ suggestion.question }}</div>',
};

const KnowledgeGapCardStub = {
  props: ['gap'],
  template: '<div>{{ gap.question }}</div>',
};

const mountPage = () =>
  shallowMount(FaqSuggestions, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        PageLayout: PageLayoutStub,
        FaqSuggestionCard: FaqSuggestionCardStub,
        KnowledgeGapCard: KnowledgeGapCardStub,
      },
    },
  });

const gapsResponse = payload => ({
  data: { payload, meta: { page: 1, total_count: payload.length } },
});

describe('FaqSuggestions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.route.params.assistantId = 1;
    mocks.route.query = {};
    mocks.gapsGet.mockResolvedValue(gapsResponse([]));
    mocks.getterValues['captainFaqSuggestions/getRecords'].value = [];
    mocks.getterValues['captainFaqSuggestions/getMeta'].value = {
      totalCount: 0,
      page: 1,
    };
    mocks.dispatch.mockImplementation((action, payload) => {
      if (action !== 'captainFaqSuggestions/setRecords') return;

      mocks.getterValues['captainFaqSuggestions/getRecords'].value =
        payload.records;
      mocks.getterValues['captainFaqSuggestions/getMeta'].value = {
        totalCount: payload.meta.total_count,
        page: payload.meta.page,
      };
    });
  });

  it('opens on the unanswered questions', async () => {
    mocks.gapsGet.mockResolvedValue(
      gapsResponse([{ id: 7, question: 'Do you ship to Spain?' }])
    );
    mocks.apiGet.mockResolvedValue({
      data: {
        payload: [{ id: 1, question: 'Agent answer' }],
        meta: { page: 1, total_count: 1 },
      },
    });

    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('Do you ship to Spain?');
    expect(wrapper.text()).not.toContain('Agent answer');
    expect(mocks.gapsGet).toHaveBeenCalledWith(
      expect.objectContaining({ assistantId: 1, page: 1 })
    );
    expect(mocks.replace).toHaveBeenCalledWith({
      query: { tab: 'unanswered', page: 1 },
    });

    wrapper.unmount();
  });

  it('keeps the latest assistant results when an older request is superseded', async () => {
    // The agent-resolved list moved to the second tab when unanswered questions became the default.
    mocks.route.query = { tab: 'answered' };
    const firstRequest = deferred();
    const secondRequest = deferred();
    const queued = [firstRequest, secondRequest];

    mocks.apiGet.mockImplementation(({ signal }) => {
      const request = queued.shift();
      signal.addEventListener('abort', () => {
        const error = new Error('canceled');
        error.name = 'CanceledError';
        request.reject(error);
      });
      return request.promise;
    });

    const wrapper = shallowMount(FaqSuggestions, {
      global: {
        mocks: { $t: key => key },
        stubs: {
          PageLayout: PageLayoutStub,
          FaqSuggestionCard: FaqSuggestionCardStub,
        },
      },
    });

    await flushPromises();
    // Switching assistants aborts the first request before it resolves.
    mocks.route.params.assistantId = 2;
    await flushPromises();

    secondRequest.resolve({
      data: {
        payload: [{ id: 2, question: 'Current assistant' }],
        meta: { page: 1, total_count: 1 },
      },
    });
    await flushPromises();

    expect(wrapper.text()).toContain('Current assistant');
    expect(wrapper.text()).not.toContain('Previous assistant');

    wrapper.unmount();
  });
});
