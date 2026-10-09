import { shallowMount } from '@vue/test-utils';
import DocumentCard from './DocumentCard.vue';

const { checkPermissions } = vi.hoisted(() => ({
  checkPermissions: vi.fn(() => true),
}));

vi.mock('dashboard/composables/usePolicy', () => ({
  usePolicy: () => ({ checkPermissions }),
}));

vi.mock('vue-router', () => ({
  useRoute: () => ({
    params: { accountId: '1', assistantId: '2' },
  }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, { n } = {}) => {
      if (key === 'CAPTAIN.DOCUMENTS.FAQ_COUNT') return `${n} FAQs`;
      if (key === 'CAPTAIN.DOCUMENTS.USED_IN_CONVERSATIONS') {
        return `Used in ${n} conversations`;
      }
      return key;
    },
    locale: { value: 'en' },
  }),
}));

const ButtonStub = {
  inheritAttrs: false,
  props: ['label', 'disabled'],
  emits: ['click'],
  template:
    '<button v-bind="$attrs" :disabled="disabled" @click="$emit(\'click\', $event)">{{ label }}</button>',
};

const SwitchStub = {
  name: 'Switch',
  props: ['modelValue'],
  emits: ['update:modelValue', 'change'],
  template:
    '<button type="button" @click="$emit(\'update:modelValue\', !modelValue)">switch</button>',
};

const mountCard = (props = {}) =>
  shallowMount(DocumentCard, {
    props: {
      id: 42,
      name: 'Returns and refunds',
      assistant: { name: 'Acme assistant' },
      externalLink:
        'https://example.com/help/articles/refund-and-return-policy-for-online-orders',
      createdAt: 1_700_000_000,
      status: 'available',
      responsesCount: 12,
      enabled: true,
      ...props,
    },
    global: {
      directives: { onClickaway: {} },
      stubs: {
        Button: ButtonStub,
        Switch: SwitchStub,
        Policy: { template: '<div><slot /></div>' },
        CardLayout: { template: '<div><slot /></div>' },
        DocumentSyncStatus: true,
        DropdownMenu: true,
        Checkbox: true,
        Icon: true,
        'router-link': true,
      },
    },
  });

describe('DocumentCard', () => {
  beforeEach(() => {
    checkPermissions.mockReturnValue(true);
  });

  it('keeps the source URL flexible and the metadata row on one line', () => {
    const wrapper = mountCard();
    const sourceLink = wrapper.get('a[href^="https://example.com"]');
    const metadataRow = sourceLink.element.parentElement;

    expect(sourceLink.classes()).toContain('flex-1');
    expect(sourceLink.classes()).toContain('truncate');
    expect(metadataRow.classList).not.toContain('flex-wrap');
  });

  it('keeps conversation usage out of the document card', () => {
    const wrapper = mountCard();

    expect(wrapper.find('[aria-label^="Used in"]').exists()).toBe(false);
  });

  it('opens details from the document title without a separate action', async () => {
    const wrapper = mountCard();
    const titleButton = wrapper
      .findAll('button')
      .find(button => button.text() === 'Returns and refunds');

    expect(titleButton).toBeDefined();
    expect(wrapper.text()).not.toContain('View details');
    await titleButton.trigger('click');

    expect(wrapper.emitted('action')).toEqual([
      [{ action: 'viewDetails', id: 42 }],
    ]);
  });

  it('renders Markdown uploads as non-syncable files', () => {
    const wrapper = mountCard({
      name: 'playground-knowledge.md',
      externalLink: 'MARKDOWN: playground-knowledge_abcd1234.md',
      markdownDocument: true,
      syncable: false,
    });

    expect(wrapper.text()).toContain('playground-knowledge.md');
    expect(wrapper.find('a').exists()).toBe(false);
    expect(wrapper.find('document-sync-status-stub').exists()).toBe(false);
  });

  it('shows the paused state when enabled is false', () => {
    const wrapper = mountCard({ enabled: false });

    expect(wrapper.text()).toContain('CAPTAIN.DOCUMENTS.STATUS.PAUSED');
  });

  it('emits toggle event when switch is toggled', async () => {
    const wrapper = mountCard({ enabled: true });
    const switchComp = wrapper.findComponent({ name: 'Switch' });

    expect(switchComp.exists()).toBe(true);
    await switchComp.vm.$emit('update:modelValue', false);

    expect(wrapper.emitted('toggle')).toEqual([[{ id: 42, enabled: false }]]);
  });
});
