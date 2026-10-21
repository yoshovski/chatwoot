import { effectScope } from 'vue';
import { flushPromises } from '@vue/test-utils';
import { useShopifyIntegration } from '../useShopifyIntegration';

const mocks = vi.hoisted(() => ({
  getStatus: vi.fn(),
  account: null,
  accountId: null,
}));
vi.mock('dashboard/api/integrations/shopify', () => ({
  default: { getStatus: mocks.getStatus },
}));
vi.mock('dashboard/composables/useAccount', async () => {
  const { ref } = await import('vue');
  mocks.account = ref({ features: {} });
  mocks.accountId = ref(1);
  return {
    useAccount: () => ({
      currentAccount: mocks.account,
      accountId: mocks.accountId,
    }),
  };
});

describe('useShopifyIntegration', () => {
  let scope;
  beforeEach(() => {
    mocks.account.value = { features: {} };
    scope = effectScope();
  });
  afterEach(() => scope.stop());

  it('makes no status request when Shopify is disabled for the account', async () => {
    const integration = scope.run(() => useShopifyIntegration());
    await flushPromises();
    expect(mocks.getStatus).not.toHaveBeenCalled();
    expect(integration.isConnected.value).toBe(false);
  });

  it('distinguishes an enabled connection request from a connected store and clears it when disabled', async () => {
    mocks.account.value = { features: { shopify_integration: true } };
    mocks.getStatus.mockResolvedValue({
      data: { id: 2, state: 'requested', catalog_status: 'off' },
    });
    const integration = scope.run(() => useShopifyIntegration());
    await flushPromises();
    expect(integration.isConnected.value).toBe(false);

    mocks.getStatus.mockResolvedValue({
      data: { id: 2, state: 'connected', catalog_status: 'on' },
    });
    await integration.refresh();
    expect(integration.isConnected.value).toBe(true);

    mocks.account.value = { features: { shopify_integration: false } };
    await flushPromises();
    expect(integration.isConnected.value).toBe(false);
    expect(integration.hook.value).toBeNull();
    expect(mocks.getStatus).toHaveBeenCalledTimes(2);
  });
});
