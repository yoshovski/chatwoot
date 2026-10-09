import { mount } from '@vue/test-utils';
import VerticalTabs from './VerticalTabs.vue';

const tabs = [
  { id: 'identity', label: 'Identity', group: 'Who Luna is' },
  { id: 'behavior', label: 'Behavior', group: 'Who Luna is' },
  { id: 'hours', label: 'Working hours', group: 'When and for whom' },
];

describe('VerticalTabs', () => {
  it('shows each group caption once, before its first tab', () => {
    const wrapper = mount(VerticalTabs, {
      props: { tabs, modelValue: 'identity' },
      global: { stubs: { Icon: true } },
    });
    const navText = wrapper
      .find('nav')
      .findAll('span.md\\:block')
      .map(caption => caption.text());

    expect(navText).toEqual(['Who Luna is', 'When and for whom']);
  });

  it('renders no captions when tabs have no group', () => {
    const wrapper = mount(VerticalTabs, {
      props: {
        tabs: tabs.map(({ id, label }) => ({ id, label })),
        modelValue: 'identity',
      },
      global: { stubs: { Icon: true } },
    });

    expect(wrapper.find('nav').findAll('span.md\\:block')).toHaveLength(0);
  });
});
