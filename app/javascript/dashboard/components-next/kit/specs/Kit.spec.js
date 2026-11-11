import { mount } from '@vue/test-utils';
import DayBars from '../DayBars.vue';
import EmptyState from '../EmptyState.vue';
import ListRow from '../ListRow.vue';
import MetricTile from '../MetricTile.vue';
import PageFrame from '../PageFrame.vue';
import PageHeader from '../PageHeader.vue';
import SectionCard from '../SectionCard.vue';
import Sparkline from '../Sparkline.vue';
import StatusPill from '../StatusPill.vue';
import Stepper from '../Stepper.vue';
import UsageMeter from '../UsageMeter.vue';

const global = {
  stubs: {
    Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
    RouterLink: { props: ['to'], template: '<a><slot /></a>' },
    Button: {
      props: ['label'],
      emits: ['click'],
      template: '<button @click="$emit(\'click\')">{{ label }}</button>',
    },
  },
};

describe('PageFrame and PageHeader', () => {
  it('puts the header first and the action on the right', () => {
    const wrapper = mount(PageFrame, {
      global,
      slots: {
        header: {
          components: { PageHeader },
          template:
            '<PageHeader title="Channels" description="Where customers reach you"><template #action><button>Add</button></template></PageHeader>',
        },
        default: '<p>Body</p>',
      },
    });

    expect(wrapper.find('h1').text()).toBe('Channels');
    expect(wrapper.text()).toContain('Where customers reach you');
    expect(wrapper.find('button').text()).toBe('Add');
    expect(wrapper.html().indexOf('h1')).toBeLessThan(
      wrapper.html().indexOf('Body')
    );
  });

  it('draws the welcome band with white text', () => {
    const wrapper = mount(PageHeader, {
      props: { title: 'Welcome', band: true },
    });

    expect(wrapper.classes()).toContain('bg-[image:var(--co-hero-bg)]');
    expect(wrapper.find('h1').classes()).toContain('text-white');
  });
});

describe('SectionCard', () => {
  it('shows the title, the link and the body', () => {
    const wrapper = mount(SectionCard, {
      global,
      props: { title: 'Usage', linkLabel: 'Billing', to: '/billing' },
      slots: { default: '<p>Meters</p>' },
    });

    expect(wrapper.find('h2').text()).toBe('Usage');
    expect(wrapper.find('a').text()).toContain('Billing');
    expect(wrapper.text()).toContain('Meters');
  });

  it('has no header without a title', () => {
    const wrapper = mount(SectionCard, { global, slots: { default: 'x' } });

    expect(wrapper.find('header').exists()).toBe(false);
  });
});

describe('MetricTile', () => {
  it('shows the value, the change and a trend line', () => {
    const wrapper = mount(MetricTile, {
      global,
      props: {
        label: 'AI conversations',
        value: 186,
        icon: 'i-lucide-bot',
        change: '+12%',
        changeTone: 'good',
        points: [1, 3, 2],
      },
    });

    expect(wrapper.text()).toContain('186');
    expect(wrapper.text()).toContain('+12%');
    expect(wrapper.find('svg').exists()).toBe(true);
  });

  it('shows a placeholder while loading', () => {
    const wrapper = mount(MetricTile, {
      global,
      props: { label: 'Leads', value: 3, icon: 'i-x', isLoading: true },
    });

    expect(wrapper.text()).not.toContain('3');
    expect(wrapper.find('.animate-pulse').exists()).toBe(true);
  });
});

describe('Sparkline', () => {
  it('draws one point per value and survives a flat line', () => {
    const wrapper = mount(Sparkline, { props: { points: [5, 5, 5, 5] } });
    const points = wrapper.find('polyline').attributes('points').split(' ');

    expect(points).toHaveLength(4);
    expect(points.every(point => !point.includes('NaN'))).toBe(true);
  });
});

describe('DayBars', () => {
  it('draws two bars per day and the legend', () => {
    const wrapper = mount(DayBars, {
      props: {
        days: [
          { label: 'Mon', ai: 4, team: 1 },
          { label: 'Tue', ai: 0, team: 0 },
        ],
        label: 'Conversations per day',
        aiLabel: 'AI agent',
        teamLabel: 'Your team',
      },
    });

    expect(wrapper.findAll('rect')).toHaveLength(4);
    expect(wrapper.find('svg').attributes('aria-label')).toBe(
      'Conversations per day'
    );
    expect(wrapper.text()).toContain('Your team');
  });
});

describe('StatusPill', () => {
  it.each([
    ['live', 'bg-n-teal-3'],
    ['learning', 'bg-n-blue-3'],
    ['paused', 'bg-n-alpha-2'],
    ['limit', 'bg-n-ruby-3'],
    ['attention', 'bg-n-amber-3'],
  ])('colours %s', (status, pill) => {
    const wrapper = mount(StatusPill, { props: { status, label: status } });

    expect(wrapper.classes()).toContain(pill);
    expect(wrapper.text()).toBe(status);
  });

  it('turns white on the band', () => {
    const wrapper = mount(StatusPill, {
      props: { status: 'live', label: 'Live', inverted: true },
    });

    expect(wrapper.classes()).toContain('text-white');
  });
});

describe('ListRow', () => {
  it('emits its one action', async () => {
    const wrapper = mount(ListRow, {
      global,
      props: {
        title: '2 chats wait',
        hint: 'Nobody assigned',
        actionLabel: 'Open',
      },
    });

    await wrapper.find('button').trigger('click');
    expect(wrapper.emitted('action')).toHaveLength(1);
    expect(wrapper.text()).toContain('Nobody assigned');
  });

  it('shows the meta text when there is no action', () => {
    const wrapper = mount(ListRow, {
      global,
      props: { title: 'Chat widget', meta: 'Installed', tone: 'teal' },
    });

    expect(wrapper.find('button').exists()).toBe(false);
    expect(wrapper.text()).toContain('Installed');
  });
});

describe('EmptyState', () => {
  it('announces errors and shows the action', () => {
    const wrapper = mount(EmptyState, {
      global,
      props: { title: 'Could not load', tone: 'error' },
      slots: { default: '<button>Retry</button>' },
    });

    expect(wrapper.attributes('role')).toBe('alert');
    expect(wrapper.find('button').text()).toBe('Retry');
  });

  it('is quiet when there is just nothing', () => {
    const wrapper = mount(EmptyState, { global, props: { title: 'Nothing' } });

    expect(wrapper.attributes('role')).toBeUndefined();
  });
});

describe('Stepper', () => {
  it('shows each state and the hint of open steps only', () => {
    const wrapper = mount(Stepper, {
      global,
      props: {
        steps: [
          { key: 'a', title: 'Add knowledge', hint: 'h1', state: 'done' },
          { key: 'b', title: 'Test', hint: 'h2', state: 'skipped' },
          { key: 'c', title: 'Go live', hint: 'h3', state: 'open' },
        ],
      },
      slots: {
        actions: '<template #actions="{ step }">{{ step.key }}!</template>',
      },
    });
    const rows = wrapper.findAll('li');

    expect(rows[0].find('[data-icon="i-lucide-circle-check"]').exists()).toBe(
      true
    );
    expect(rows[1].find('[data-icon="i-lucide-circle-minus"]').exists()).toBe(
      true
    );
    expect(wrapper.text()).not.toContain('h1');
    expect(wrapper.text()).toContain('h3');
    expect(rows[2].text()).toContain('c!');
  });
});

describe('UsageMeter', () => {
  const bar = wrapper => wrapper.find('[role="progressbar"]');

  it('fills the bar and turns red near the limit', () => {
    const wrapper = mount(UsageMeter, {
      props: { label: 'AI', used: 140, limit: 150, valueLabel: '140 / 150' },
    });

    expect(bar(wrapper).attributes('aria-valuenow')).toBe('93');
    expect(bar(wrapper).find('div').classes()).toContain('bg-n-ruby-9');
    expect(wrapper.text()).toContain('140 / 150');
  });

  it('treats 0 as a full limit and null as no limit', () => {
    const full = mount(UsageMeter, {
      props: { label: 'D', used: 0, limit: 0 },
    });
    const none = mount(UsageMeter, {
      props: { label: 'D', used: 7, hint: 'No limit set' },
    });

    expect(bar(full).attributes('aria-valuenow')).toBe('100');
    expect(bar(none).exists()).toBe(false);
    expect(none.text()).toContain('7');
    expect(none.text()).toContain('No limit set');
  });
});
