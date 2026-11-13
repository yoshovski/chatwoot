import { flushPromises, shallowMount } from '@vue/test-utils';
import FaqSuggestions from './FaqSuggestions.vue';

const mocks = vi.hoisted(() => ({
  apiGet: vi.fn(),
  topics: vi.fn(),
  actionRequests: vi.fn(),
  answer: vi.fn(),
  dispatch: vi.fn(),
  replace: vi.fn(),
  route: null,
  getterValues: null,
}));

vi.mock('dashboard/api/captain/faqSuggestions', () => ({
  default: { get: mocks.apiGet },
}));

vi.mock('dashboard/api/captain/knowledgeGaps', () => ({
  default: {
    topics: mocks.topics,
    actionRequests: mocks.actionRequests,
    answer: mocks.answer,
  },
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

// Renders every question and lets a test answer the first one, as the focus card does.
const SuggestionsFocusStub = {
  props: ['topics'],
  emits: ['save'],
  template: `<div>
    <p v-for="group in topics" :key="group.topic">
      <span v-for="gap in group.gaps" :key="gap.id">{{ gap.question }}</span>
    </p>
    <button class="save-first" @click="$emit('save', topics[0].gaps[0], { question: 'Q', answer: 'A' })" />
    <slot />
  </div>`,
};

const EmptyStateStub = {
  props: ['title'],
  template: '<div>{{ title }}<slot /></div>',
};

const ActionRequestsCardStub = {
  props: ['requests'],
  template: '<div>{{ requests.map(request => request.intent).join() }}</div>',
};

const mountPage = () =>
  shallowMount(FaqSuggestions, {
    global: {
      mocks: { $t: key => key },
      stubs: {
        PageLayout: PageLayoutStub,
        FaqSuggestionCard: FaqSuggestionCardStub,
        SuggestionsFocus: SuggestionsFocusStub,
        KitEmptyState: EmptyStateStub,
        ActionRequestsCard: ActionRequestsCardStub,
        Button: { template: '<button class="retry" />' },
      },
    },
  });

const payloadResponse = payload => ({ data: { payload } });
const topic = (name, gaps) => ({
  topic: name,
  conversations_count: gaps.length,
  gaps,
});

describe('FaqSuggestions', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mocks.route.params.assistantId = 1;
    mocks.route.query = {};
    mocks.topics.mockResolvedValue(payloadResponse([]));
    mocks.actionRequests.mockResolvedValue(payloadResponse([]));
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

  it('opens on the unanswered questions grouped by topic', async () => {
    mocks.topics.mockResolvedValue(
      payloadResponse([
        topic('Shipping', [{ id: 7, question: 'Do you ship to Spain?' }]),
      ])
    );
    mocks.actionRequests.mockResolvedValue(
      payloadResponse([{ intent: 'order_status', conversations_count: 9 }])
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
    expect(wrapper.text()).toContain('order_status');
    expect(mocks.topics).toHaveBeenCalledWith(
      expect.objectContaining({ assistantId: 1 })
    );
    expect(mocks.actionRequests).toHaveBeenCalledWith(
      expect.objectContaining({ assistantId: 1 })
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

  it('shows the action requests on their own when no question is waiting', async () => {
    mocks.actionRequests.mockResolvedValue(
      payloadResponse([{ intent: 'return', conversations_count: 4 }])
    );

    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain(
      'CAPTAIN.SUGGESTIONS.EMPTY_STATE.ONLY_ACTIONS'
    );
    expect(wrapper.text()).toContain('return');

    wrapper.unmount();
  });

  it('shows an error with a retry when the list cannot load', async () => {
    mocks.topics.mockRejectedValueOnce(new Error('boom'));

    const wrapper = mountPage();
    await flushPromises();

    expect(wrapper.text()).toContain('CAPTAIN.SUGGESTIONS.ERROR.TITLE');

    await wrapper.find('button.retry').trigger('click');
    await flushPromises();

    expect(mocks.topics).toHaveBeenCalledTimes(2);
    expect(wrapper.text()).not.toContain('CAPTAIN.SUGGESTIONS.ERROR.TITLE');

    wrapper.unmount();
  });

  it('saves an answer and says so once the last question is handled', async () => {
    mocks.topics
      .mockResolvedValueOnce(
        payloadResponse([
          topic('Shipping', [{ id: 7, question: 'Do you ship to Spain?' }]),
        ])
      )
      .mockResolvedValue(payloadResponse([]));
    mocks.answer.mockResolvedValue({});

    const wrapper = mountPage();
    await flushPromises();
    await wrapper.find('button.save-first').trigger('click');
    await flushPromises();

    expect(mocks.answer).toHaveBeenCalledWith(7, {
      question: 'Q',
      answer: 'A',
    });
    expect(wrapper.text()).toContain('CAPTAIN.SUGGESTIONS.DONE.TITLE');

    wrapper.unmount();
  });
});
