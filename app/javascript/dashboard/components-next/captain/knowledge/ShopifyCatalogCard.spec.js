import { shallowMount, flushPromises } from '@vue/test-utils';
import ShopifyCatalogCard from './ShopifyCatalogCard.vue';

const { getStatus, getCatalogProducts, resumeCatalog, checkPermissions } =
  vi.hoisted(() => ({
    getStatus: vi.fn(),
    getCatalogProducts: vi.fn(),
    resumeCatalog: vi.fn(),
    checkPermissions: vi.fn(() => true),
  }));

vi.mock('dashboard/api/integrations/shopify', () => ({
  default: { getStatus, getCatalogProducts, resumeCatalog },
}));

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions }),
}));

vi.mock('dashboard/composables', () => ({
  useAlert: vi.fn(),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    name: 'captain_assistants_documents_index',
    params: { accountId: '1', assistantId: '2' },
  }),
  useRouter: () => ({ push: vi.fn() }),
}));

const translate = (key, options = {}) => {
  if (key === 'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SYNCED_COUNT') {
    return `${options.count} products synced`;
  }
  if (key === 'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SYNCED_LABEL') {
    return 'products synced';
  }
  if (key === 'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.FAILED_ATTENTION') {
    return `${options.count} need attention`;
  }
  if (key === 'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.IMPORTING_PROGRESS') {
    return `${options.synced} of ${options.total} products (${options.percent}%)`;
  }
  return key;
};

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: translate,
  }),
}));

const ButtonStub = {
  name: 'Button',
  props: ['label', 'disabled', 'isLoading'],
  emits: ['click'],
  template:
    '<button type="button" @click="$emit(\'click\', $event)">{{ label }}</button>',
};

const mountCard = (props = {}) =>
  shallowMount(ShopifyCatalogCard, {
    props,
    global: {
      mocks: {
        $t: translate,
      },
      stubs: {
        Button: ButtonStub,
        Icon: true,
        'router-link': {
          props: ['to'],
          template: '<a :data-to="JSON.stringify(to)"><slot /></a>',
        },
      },
    },
  });

describe('ShopifyCatalogCard', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    checkPermissions.mockReturnValue(true);
  });

  describe('state: on', () => {
    it('renders synced count, failed attention count, thumbnails, and action buttons', async () => {
      getStatus.mockResolvedValue({
        data: {
          hook: { id: 1, state: 'connected', catalog_status: 'on' },
        },
      });
      getCatalogProducts.mockResolvedValue({
        data: {
          counts: { synced: 279, failed: 3 },
          total: 282,
          items: [
            { id: 'p1', image_url: 'https://cdn.shopify.com/img1.jpg' },
            { id: 'p2', image_url: 'https://cdn.shopify.com/img2.jpg' },
          ],
        },
      });

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toContain('279');
      expect(wrapper.text().match(/279/g)).toHaveLength(1);
      expect(wrapper.text()).toContain('products synced');
      expect(wrapper.text()).toContain('3 need attention');
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.ON_DESCRIPTION'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.LIVE'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.VIEW_PRODUCTS'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS'
      );

      const images = wrapper.findAll('img');
      expect(images).toHaveLength(2);
      expect(images[0].attributes('src')).toContain('width=96');
    });
  });

  describe('state: importing', () => {
    it('renders progress bar and syncing status', async () => {
      getStatus.mockResolvedValue({
        data: {
          hook: { id: 1, state: 'connected', catalog_status: 'importing' },
        },
      });
      getCatalogProducts.mockResolvedValue({
        data: {
          counts: { synced: 50, failed: 0 },
          total: 100,
          items: [],
        },
      });

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.IMPORTING'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.IMPORTING_TITLE'
      );
      expect(wrapper.text()).toContain('50 of 100 products (50%)');
    });
  });

  describe('state: needs_reconnect', () => {
    it('renders reconnect alert and action button', async () => {
      getStatus.mockResolvedValue({
        data: {
          hook: {
            id: 1,
            state: 'needs_reconnect',
            catalog_status: 'needs_reconnect',
          },
        },
      });

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.NEEDS_RECONNECT'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.NEEDS_RECONNECT_DESCRIPTION'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RECONNECT'
      );
    });
  });

  describe('state: off (paused)', () => {
    it('renders paused sync status and allows admins to resume', async () => {
      getStatus.mockResolvedValue({
        data: {
          hook: { id: 1, state: 'connected', catalog_status: 'off' },
        },
      });
      resumeCatalog.mockResolvedValue({
        data: {
          hook: { id: 1, state: 'connected', catalog_status: 'on' },
        },
      });
      getCatalogProducts.mockResolvedValue({
        data: { counts: { synced: 279 }, total: 279, items: [] },
      });

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.STATUS.PAUSED'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.PAUSED_DESCRIPTION'
      );

      const resumeBtn = wrapper
        .findAll('button')
        .find(b => b.text().includes('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.RESUME'));
      expect(resumeBtn).toBeDefined();

      await resumeBtn.trigger('click');
      await flushPromises();

      expect(resumeCatalog).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('resumed')).toHaveLength(1);
    });
  });

  describe('state: not connected (upsell)', () => {
    it('renders upsell with 3 benefits for administrators', async () => {
      getStatus.mockResolvedValue({
        data: { hook: null },
      });
      checkPermissions.mockReturnValue(true);

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.TITLE'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.PRICES_STOCK'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.PRODUCT_CARDS'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BENEFITS.ORDER_TRACKING'
      );
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.UPSELL.BUTTON'
      );
    });

    it('renders nothing for non-admin agents when not connected', async () => {
      getStatus.mockResolvedValue({
        data: { hook: null },
      });
      checkPermissions.mockReturnValue(false);

      const wrapper = mountCard();
      await flushPromises();

      expect(wrapper.text()).toBe('');
    });
  });

  describe('compact layout', () => {
    it('renders compact header on products tab', async () => {
      getStatus.mockResolvedValue({
        data: {
          hook: { id: 1, state: 'connected', catalog_status: 'on' },
        },
      });
      getCatalogProducts.mockResolvedValue({
        data: {
          counts: { synced: 142, failed: 0 },
          total: 142,
          items: [],
        },
      });

      const wrapper = mountCard({ compact: true });
      await flushPromises();

      expect(wrapper.text()).toContain('142 products synced');
      expect(wrapper.text()).toContain('CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.TITLE');
      expect(wrapper.text()).toContain(
        'CAPTAIN.KNOWLEDGE.SHOPIFY_CARD.SETTINGS'
      );
    });
  });
});
