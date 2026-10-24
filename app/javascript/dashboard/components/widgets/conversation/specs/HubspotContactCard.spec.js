import { mount, flushPromises } from '@vue/test-utils';
import HubspotContactCard from '../HubspotContactCard.vue';
import HubspotAPI from 'dashboard/api/hubspot';

vi.mock('dashboard/api/hubspot', () => ({
  default: { getContact: vi.fn() },
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: key => key }),
}));

vi.mock('dashboard/composables/store', () => ({
  useStoreGetters: () => ({ getCurrentAccountId: { value: 1 } }),
}));

const mountCard = () =>
  mount(HubspotContactCard, {
    props: { contactId: 7 },
    global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
  });

describe('HubspotContactCard', () => {
  beforeEach(() => {
    HubspotAPI.getContact.mockReset();
  });

  it('shows a spinner while loading', () => {
    HubspotAPI.getContact.mockReturnValue(new Promise(() => {}));

    const wrapper = mountCard();

    expect(wrapper.attributes('data-state')).toBe('loading');
    expect(HubspotAPI.getContact).toHaveBeenCalledWith(7, {
      signal: expect.any(AbortSignal),
    });
  });

  it('shows the HubSpot contact with a link that opens in a new tab', async () => {
    HubspotAPI.getContact.mockResolvedValue({
      data: {
        found: true,
        id: '901',
        url: 'https://app.hubspot.com/contacts/1/record/0-1/901',
        name: 'Jane Doe',
        email: 'jane@example.com',
        phone: '+15550100',
        lifecyclestage: 'Lead',
        hs_lead_status: 'New',
        owner_name: 'Sam Owner',
      },
    });

    const wrapper = mountCard();
    await flushPromises();

    expect(wrapper.attributes('data-state')).toBe('found');
    ['Jane Doe', 'jane@example.com', '+15550100', 'Lead', 'New'].forEach(
      value => expect(wrapper.text()).toContain(value)
    );
    expect(wrapper.text()).toContain('Sam Owner');
    const link = wrapper.find('a[target="_blank"]');
    expect(link.attributes('href')).toBe(
      'https://app.hubspot.com/contacts/1/record/0-1/901'
    );
    expect(link.attributes('rel')).toContain('noopener');
  });

  it('shows the empty state when the contact is not in HubSpot', async () => {
    HubspotAPI.getContact.mockResolvedValue({ data: { found: false } });

    const wrapper = mountCard();
    await flushPromises();

    expect(wrapper.attributes('data-state')).toBe('not_found');
    expect(wrapper.text()).toContain('CONVERSATION_SIDEBAR.HUBSPOT.NOT_FOUND');
  });

  it('links to the integration page when HubSpot must be reconnected', async () => {
    HubspotAPI.getContact.mockResolvedValue({
      data: { error: 'reauthorize' },
    });

    const wrapper = mountCard();
    await flushPromises();

    expect(wrapper.attributes('data-state')).toBe('reauthorize');
    expect(wrapper.text()).toContain(
      'CONVERSATION_SIDEBAR.HUBSPOT.REAUTHORIZE'
    );
    expect(wrapper.text()).toContain(
      'CONVERSATION_SIDEBAR.HUBSPOT.OPEN_SETTINGS'
    );
  });

  it('shows an error when the request fails', async () => {
    HubspotAPI.getContact.mockRejectedValue(new Error('network'));

    const wrapper = mountCard();
    await flushPromises();

    expect(wrapper.attributes('data-state')).toBe('error');
  });
});
