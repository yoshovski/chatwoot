import { mount } from '@vue/test-utils';
import SuggestionsFocus from './SuggestionsFocus.vue';

const gap = (id, question, extra = {}) => ({
  id,
  question,
  topic: 'Shipping',
  occurrences_count: 2,
  examples: [],
  draft_answer: null,
  ...extra,
});

const topicsWith = gaps => [
  { topic: 'Shipping', conversations_count: gaps.length, gaps },
];

const mountFocus = (gaps, props = {}) =>
  mount(SuggestionsFocus, {
    props: { topics: topicsWith(gaps), ...props },
    slots: { default: '<p class="slotted">Action requests</p>' },
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key} ${params.count ?? params.text ?? ''}` : key,
      },
      directives: { tooltip: {} },
    },
  });

const buttonWithText = (wrapper, text) =>
  wrapper.findAll('button').find(button => button.text().includes(text));

describe('SuggestionsFocus', () => {
  it('shows the suggested answer and saves it as it is', async () => {
    const wrapper = mountFocus([
      gap(1, 'Can your generator power a DJI T50?', {
        draft_answer: 'Yes, the 12 kW model.',
        examples: ['is the 12kw one enough?', 'will it keep up?'],
      }),
    ]);

    expect(wrapper.find('h2').text()).toBe(
      'Can your generator power a DJI T50?'
    );
    expect(wrapper.text()).toContain('Yes, the 12 kW model.');
    expect(wrapper.text()).toContain('is the 12kw one enough?');
    expect(wrapper.text()).not.toContain('will it keep up?');
    expect(wrapper.find('.slotted').exists()).toBe(true);

    await buttonWithText(wrapper, 'FOCUS.ADD').trigger('click');

    expect(wrapper.emitted('save')[0]).toEqual([
      expect.objectContaining({ id: 1 }),
      {
        question: 'Can your generator power a DJI T50?',
        answer: 'Yes, the 12 kW model.',
      },
    ]);
  });

  it('asks for an answer when there is no draft', async () => {
    const wrapper = mountFocus([gap(1, 'Do you ship to the Canary Islands?')]);
    const add = buttonWithText(wrapper, 'FOCUS.ADD');

    expect(add.attributes('disabled')).toBeDefined();

    await wrapper.find('textarea').setValue('Yes, in 5 to 7 days.');

    expect(add.attributes('disabled')).toBeUndefined();
  });

  it('opens a question from the overview and moves on after it is handled', async () => {
    const first = gap(1, 'First question');
    const second = gap(2, 'Second question');
    const third = gap(3, 'Third question');
    const wrapper = mountFocus([first, second, third]);

    await buttonWithText(wrapper, 'Second question').trigger('click');
    expect(wrapper.find('h2').text()).toBe('Second question');

    await buttonWithText(wrapper, 'NOT_RELEVANT').trigger('click');
    expect(wrapper.emitted('dismiss')[0]).toEqual([second]);

    // The page reloads the list without the handled question.
    await wrapper.setProps({
      topics: topicsWith([first, third]),
      handledCount: 1,
    });

    expect(wrapper.find('h2').text()).toBe('Third question');
    expect(wrapper.text()).toContain('FOCUS.LEFT 2');
  });

  it('marks several questions as not relevant at once', async () => {
    const wrapper = mountFocus([gap(1, 'One'), gap(2, 'Two'), gap(3, 'Three')]);

    await buttonWithText(wrapper, 'BULK.SELECT').trigger('click');
    const boxes = wrapper.findAll('aside input[type="checkbox"]');
    await boxes[0].setValue(true);
    await boxes[2].setValue(true);
    await buttonWithText(wrapper, 'NOT_RELEVANT_COUNT').trigger('click');

    expect(wrapper.emitted('bulkDismiss')[0]).toEqual([[1, 3]]);
  });
});
