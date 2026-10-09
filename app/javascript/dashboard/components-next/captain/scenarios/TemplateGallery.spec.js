import { ref } from 'vue';
import { mount } from '@vue/test-utils';
import TemplateGallery from './TemplateGallery.vue';

const uiSettings = ref({});
const updateUISettings = vi.fn();

vi.mock('dashboard/composables/useUISettings', () => ({
  useUISettings: () => ({ uiSettings, updateUISettings }),
}));

const tools = [
  { id: 'faq_lookup', title: 'Search knowledge', emoji: '📚' },
  { id: 'handoff', title: 'Hand off to a person', emoji: '🙋' },
  { id: 'add_private_note', title: 'Add a private note', emoji: '📝' },
  { id: 'add_label_to_conversation', title: 'Add a label', emoji: '🏷️' },
];

const mountGallery = props =>
  mount(TemplateGallery, { props: { tools, ...props } });

describe('TemplateGallery', () => {
  beforeEach(() => {
    uiSettings.value = {};
  });

  it('shows five templates and the describe tile', () => {
    const wrapper = mountGallery();

    expect(wrapper.findAll('[data-test^="template-"]')).toHaveLength(6);
    expect(wrapper.text()).not.toContain('CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY_TOOLTIP');
  });

  it('emits the chosen template', async () => {
    const wrapper = mountGallery();

    await wrapper.find('[data-test="template-request_a_quote"]').trigger('click');

    expect(wrapper.emitted('useTemplate')[0][0].id).toBe('request_a_quote');
  });

  it('does not start a template whose required tool is missing', async () => {
    const wrapper = mountGallery();
    const productFinder = wrapper.find('[data-test="template-product_finder"]');

    await productFinder.trigger('click');

    expect(productFinder.attributes('aria-disabled')).toBe('true');
    expect(productFinder.text()).toContain(
      'CAPTAIN.ASSISTANTS.SCENARIOS.TEMPLATES.NEEDS_SHOPIFY'
    );
    expect(wrapper.emitted('useTemplate')).toBeUndefined();
  });

  it('opens the builder from the describe tile', async () => {
    const wrapper = mountGallery();

    await wrapper.find('[data-test="template-describe"]').trigger('click');

    expect(wrapper.emitted('describe')).toHaveLength(1);
  });

  it('starts collapsed once the assistant has scenarios', () => {
    const wrapper = mountGallery({ hasScenarios: true });

    expect(wrapper.find('[data-test^="template-"]').exists()).toBe(false);
  });

  it('respects the saved choice over the default', () => {
    uiSettings.value = { show_scenarios_suggestions: true };
    const wrapper = mountGallery({ hasScenarios: true });

    expect(wrapper.find('[data-test^="template-"]').exists()).toBe(true);
  });
});
