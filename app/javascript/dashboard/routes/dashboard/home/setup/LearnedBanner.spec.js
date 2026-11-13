import { mount } from '@vue/test-utils';
import LearnedBanner from './LearnedBanner.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({ t: (key, values) => `${key} ${JSON.stringify(values)}` }),
}));

const render = props =>
  mount(LearnedBanner, {
    props,
    global: { mocks: { $t: key => key }, stubs: { Icon: true } },
  });

describe('LearnedBanner', () => {
  it('says it is reading before the first page is learned', () => {
    const wrapper = render({ learned: 0, total: 0, reading: true });
    expect(wrapper.text()).toContain('HOME.GUIDED.FINDING');
  });

  it('counts against the chosen pages while they are read', () => {
    const wrapper = render({ learned: 6, total: 40 });
    expect(wrapper.text()).toContain(
      'HOME.GUIDED.LEARNED {"learned":6,"total":40}'
    );
    expect(wrapper.text()).toContain('HOME.GUIDED.LEARNING_MORE');
  });

  it('says "so far" while the pages to import are still being found', () => {
    const wrapper = render({ learned: 3, total: 3, reading: true });
    expect(wrapper.text()).toContain('HOME.GUIDED.LEARNED_SO_FAR');
    expect(wrapper.text()).toContain('HOME.GUIDED.LEARNING_MORE');
  });

  it('drops the background line once everything is read', () => {
    const wrapper = render({ learned: 12, total: 12 });
    expect(wrapper.text()).toContain('HOME.GUIDED.LEARNED_ALL');
    expect(wrapper.text()).not.toContain('HOME.GUIDED.LEARNING_MORE');
  });
});
