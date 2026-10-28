import { mount } from '@vue/test-utils';
import UsageCard from './UsageCard.vue';

vi.mock('vue-i18n', () => ({
  useI18n: () => ({
    t: (key, params) => (params ? `${key} ${JSON.stringify(params)}` : key),
    locale: { value: 'en' },
  }),
}));

const DAY = 24 * 60 * 60;
const now = () => Math.floor(Date.now() / 1000);

const usage = (plan = {}, aiLimit = null) => ({
  plan: {
    billing_enabled: true,
    trial: false,
    trial_ends_at: null,
    ai_replies_paused: false,
    quota_resets_at: now() + 10 * DAY,
    ...plan,
  },
  ai_conversations: { used: 40, limit: aiLimit },
  agents: { used: 2, limit: 3 },
  inboxes: { used: 1, limit: null },
  documents: { used: 0, limit: 0 },
});

const render = props =>
  mount(UsageCard, {
    props,
    global: {
      mocks: {
        $t: (key, params) =>
          params ? `${key} ${JSON.stringify(params)}` : key,
      },
      stubs: { HomeCard: { template: '<div><slot /></div>' }, Icon: true },
    },
  });

describe('UsageCard', () => {
  it('shows the Super Admin limits and says when none is set', () => {
    const text = render({ usage: usage({}, 100) }).text();

    expect(text).toContain('HOME.USAGE.OF_LIMIT {"used":40,"limit":100}');
    expect(text).toContain('HOME.USAGE.OF_LIMIT {"used":2,"limit":3}');
    expect(text).toContain('HOME.USAGE.OF_LIMIT {"used":0,"limit":0}');
    expect(text).toContain('HOME.USAGE.NO_LIMIT_SET');
    expect(text).not.toContain('HOME.USAGE.TRIAL');
  });

  it('shows the trial end date while the trial runs', () => {
    const text = render({
      usage: usage({ trial: true, trial_ends_at: now() + 5 * DAY }, 50),
    }).text();

    expect(text).toContain('HOME.USAGE.TRIAL_ENDS');
    expect(text).not.toContain('HOME.USAGE.PAUSED');
  });

  it('shows an ended trial and paused AI replies', () => {
    const text = render({
      usage: usage({
        trial: true,
        trial_ends_at: now() - DAY,
        ai_replies_paused: true,
      }),
    }).text();

    expect(text).toContain('HOME.USAGE.TRIAL_ENDED');
    expect(text).toContain('HOME.USAGE.PAUSED');
  });
});
