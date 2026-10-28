import { mount } from '@vue/test-utils';
import SetupProgressCard from './SetupProgressCard.vue';
import { buildSetupProgress } from '../homeSetup';

vi.mock('vue-i18n', () => ({ useI18n: () => ({ t: key => key }) }));

const render = progress =>
  mount(SetupProgressCard, {
    props: { progress, stepRoute: () => '/' },
    global: {
      mocks: { $t: key => key },
      stubs: {
        HomeCard: { template: '<div><slot /></div>' },
        Icon: { props: ['icon'], template: '<i :data-icon="icon" />' },
        RouterLink: { template: '<a><slot /></a>' },
        Button: {
          props: ['label'],
          emits: ['click'],
          template: '<button @click="$emit(\'click\')">{{ label }}</button>',
        },
      },
    },
  });

describe('SetupProgressCard', () => {
  it('lists done, skipped and open steps', async () => {
    const wrapper = render(
      buildSetupProgress({ knowledge: true }, ['test_agent'])
    );

    expect(wrapper.findAll('li')).toHaveLength(6);
    expect(wrapper.find('li').text()).toContain('HOME.SETUP.DONE');
    expect(wrapper.find('[data-icon="i-lucide-circle-check"]').exists()).toBe(
      true
    );

    const skipped = wrapper.findAll('li')[1];
    expect(skipped.text()).toContain('HOME.SETUP.SKIPPED');
    await skipped.find('button').trigger('click');
    expect(wrapper.emitted('unskip')).toEqual([['test_agent']]);

    const open = wrapper.findAll('li')[2];
    expect(open.text()).toContain('HOME.SETUP.STEPS.AGENT_INBOX.HINT');
    await open.find('button').trigger('click');
    expect(wrapper.emitted('skip')).toEqual([['agent_inbox']]);
  });
});
