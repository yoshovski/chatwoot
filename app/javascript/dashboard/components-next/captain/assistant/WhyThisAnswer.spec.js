import { mount } from '@vue/test-utils';
import WhyThisAnswer from './WhyThisAnswer.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, values) => (values ? `${key} ${JSON.stringify(values)}` : key),
  }),
}));

const reply = {
  id: 1,
  question: 'Where is my order?',
  answer: 'Use the tracking link.',
  sources: [
    { kind: 'faq', title: 'Delivery and tracking' },
    { kind: 'product', title: 'Blue mug', url: 'https://shop.example.com/mug' },
  ],
  runDetails: {
    handler: { title: 'Order status' },
    events: [{ type: 'tool', name: 'Look up order', status: 'completed' }],
    duration_ms: 2140,
  },
  handoff: null,
};

const mountCard = props =>
  mount(WhyThisAnswer, {
    props: { reply, ...props },
    global: {
      stubs: { NextButton: { template: '<button><slot /></button>' } },
    },
  });

describe('WhyThisAnswer', () => {
  it('shows who answered, the sources, the actions and the time', () => {
    const text = mountCard().text();

    expect(text).toContain('Where is my order?');
    expect(text).toContain('Order status');
    expect(text).toContain('Delivery and tracking');
    expect(text).toContain('Look up order');
    expect(text).toContain('{"seconds":"2.1"}');
  });

  it('links a source that has a page', () => {
    const link = mountCard().find('a');

    expect(link.attributes('href')).toBe('https://shop.example.com/mug');
    expect(link.text()).toBe('Blue mug');
  });

  it('says when nothing was used', () => {
    const text = mountCard({
      reply: {
        ...reply,
        sources: [],
        runDetails: { events: [], duration_ms: 500 },
      },
    }).text();

    expect(text).toContain('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.MAIN_AGENT');
    expect(text).toContain('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.NO_SOURCES');
    expect(text).toContain('CAPTAIN.PLAYGROUND.WIDGET_TEST.WHY.NO_ACTIONS');
  });

  it('explains a handoff', () => {
    const text = mountCard({
      reply: {
        ...reply,
        handoff: { source: 'tool', reason: 'asked for a person' },
      },
    }).text();

    expect(text).toContain('CAPTAIN.PLAYGROUND.CUSTOMER_VIEW.HANDOFF');
    expect(text).toContain('{"reason":"asked for a person"}');
  });

  it('shows the error of a failed run without a fix button', () => {
    const wrapper = mountCard({
      reply: {
        id: 2,
        question: 'Hello',
        sources: [],
        error: 'model unavailable',
      },
    });

    expect(wrapper.find('[role="alert"]').text()).toBe('model unavailable');
    expect(wrapper.find('[data-test="why-fix"]').exists()).toBe(false);
  });

  it('asks to fix the answer, and shows when a fix was saved', async () => {
    const wrapper = mountCard();
    await wrapper.find('[data-test="why-fix"]').trigger('click');
    expect(wrapper.emitted('fix')).toEqual([[reply]]);

    await wrapper.setProps({ fixed: true });
    expect(wrapper.find('[data-test="why-fix"]').exists()).toBe(false);
    expect(wrapper.find('[data-test="why-fixed"]').exists()).toBe(true);
  });
});
