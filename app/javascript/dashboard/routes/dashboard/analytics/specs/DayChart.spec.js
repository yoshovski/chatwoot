import { mount } from '@vue/test-utils';
import DayChart from '../components/DayChart.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en-US' },
  }),
}));

const series = [
  { label: 'AI agent', total: 'AI agent replied' },
  { label: 'Your team', total: 'Your team replied' },
];
const week = [
  { date: '2026-11-14', values: [10, 3] },
  { date: '2026-11-15', values: [7, 2] },
];

const mountChart = props =>
  mount(DayChart, {
    props: { series, period: 7, emptyText: 'Nothing yet', ...props },
    global: {
      stubs: { EmptyState: { template: '<p>{{ $attrs.title }}</p>' } },
    },
  });

describe('DayChart', () => {
  it('shows each series total and every day in words for screen readers', () => {
    const wrapper = mountChart({ days: week });

    expect(wrapper.findAll('dd').map(node => node.text())).toEqual(['17', '5']);
    const day = wrapper.findAll('li')[0];
    expect(day.attributes('tabindex')).toBe('0');
    expect(day.attributes('aria-label')).toContain('AI agent 10, Your team 3');
  });

  it('puts the day total above the bar for a week, not for a month', () => {
    expect(mountChart({ days: week }).findAll('li')[0].text()).toContain('13');
    const month = mountChart({ days: week, period: 30 });
    expect(month.findAll('li')[0].find('.mb-1').exists()).toBe(false);
  });

  it('says so when the period is empty', () => {
    const wrapper = mountChart({
      days: [{ date: '2026-11-15', values: [0, 0] }],
    });

    expect(wrapper.text()).toContain('Nothing yet');
  });
});
