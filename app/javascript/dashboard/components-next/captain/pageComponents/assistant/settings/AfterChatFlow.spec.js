import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import AfterChatFlow from './AfterChatFlow.vue';
import FlowSteps from './FlowSteps.vue';

vi.mock('vue-router', () => ({
  useRoute: () => ({ params: { accountId: '1' } }),
}));

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
  }),
}));

const mountFlow = props =>
  mount(AfterChatFlow, {
    props: { name: 'Nova', ...props },
    global: { stubs: { RouterLink: { template: '<a><slot /></a>' } } },
  });

const steps = wrapper => wrapper.findComponent(FlowSteps).props('steps');
const step = (wrapper, key) => steps(wrapper).find(item => item.key === key);

describe('AfterChatFlow', () => {
  it.each([
    [60, '30 min'],
    [15, '5 min'],
    [5, '5 min'],
    [45, '20 min'],
    [240, '30 min'],
  ])('checks in after half of %i minutes, rounded down', (minutes, label) => {
    const wrapper = mountFlow({ mode: 'evaluated', minutes });

    expect(step(wrapper, 'check-in').title).toContain(
      `"duration":"CAPTAIN.ASSISTANTS.SETTINGS.AFTER_CHAT.FLOW.MINUTES {\\"count\\":${parseInt(label, 10)}}"`
    );
  });

  it('checks in after 15 minutes when auto-resolve is off and keeps the conversation open', () => {
    const wrapper = mountFlow({ mode: 'disabled', minutes: 60 });

    expect(steps(wrapper).map(item => item.key)).toEqual([
      'quiet',
      'check-in',
      'open',
    ]);
    expect(step(wrapper, 'check-in').title).toContain('{\\"count\\":15}');
  });

  it('shows quiet, check-in, quiet again and the review in order', () => {
    const wrapper = mountFlow({ mode: 'evaluated', minutes: 60 });

    expect(steps(wrapper).map(item => item.key)).toEqual([
      'quiet',
      'check-in',
      'wait',
      'review',
    ]);
  });

  it('adds the lead offer for prospects when business leads are on', () => {
    const wrapper = mountFlow({
      mode: 'legacy',
      minutes: 60,
      leadsEnabled: true,
    });

    expect(steps(wrapper).map(item => item.key)).toEqual([
      'quiet',
      'check-in',
      'lead-offer',
      'wait',
      'close',
    ]);
  });

  it('hints at email continuity with a link when a website inbox has it off', () => {
    const wrapper = mountFlow({
      mode: 'evaluated',
      minutes: 60,
      continuityOffInbox: { id: 7, name: 'Website' },
    });

    const hint = wrapper.find('[data-test="continuity-hint"]');
    expect(hint.text()).toContain('CONTINUITY_HINT {"inbox":"Website"}');
    expect(hint.text()).toContain('CONTINUITY_LINK');
  });

  it('shows no hint when continuity is on everywhere', () => {
    const wrapper = mountFlow({ mode: 'evaluated', minutes: 60 });

    expect(wrapper.find('[data-test="continuity-hint"]').exists()).toBe(false);
  });
});
