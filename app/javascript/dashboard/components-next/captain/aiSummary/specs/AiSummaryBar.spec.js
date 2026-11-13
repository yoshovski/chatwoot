import { mount } from '@vue/test-utils';
import { createI18n } from 'vue-i18n';
import en from 'dashboard/i18n/locale/en';
import AiSummaryBar from '../AiSummaryBar.vue';
import { readSummary, summaryHeadline } from '../aiSummary';

const i18n = createI18n({ legacy: false, locale: 'en', messages: { en } });

const handoff = {
  status: 'handed_off',
  wants: 'Club price for 40 boots',
  details: 'Sizes 38-46',
  next_step: 'Send a quote today',
  lead: { type: 'Bulk order', summary: 'Hiking club, 40 pairs' },
  actions: [{ title: 'Change delivery address', outcome: 'succeeded' }],
};

const mountBar = summary =>
  mount(AiSummaryBar, { props: { summary }, global: { plugins: [i18n] } });

describe('aiSummary', () => {
  it('reads a known summary from the conversation and ignores anything else', () => {
    expect(
      readSummary({ additional_attributes: { captain_summary: handoff } })
    ).toEqual(handoff);
    expect(
      readSummary({
        additional_attributes: { captain_summary: { status: 'x' } },
      })
    ).toBeNull();
    expect(readSummary({ additional_attributes: {} })).toBeNull();
  });

  it('leads with what the customer wants, then the handoff reason, then the lead', () => {
    expect(summaryHeadline(handoff)).toBe('Club price for 40 boots');
    expect(summaryHeadline({ reason: 'Refund needs a person' })).toBe(
      'Refund needs a person'
    );
    expect(summaryHeadline({ lead: { summary: 'Hotel, 25 staff' } })).toBe(
      'Hotel, 25 staff'
    );
  });
});

describe('AiSummaryBar', () => {
  it('shows one sentence and the next step while closed', () => {
    const wrapper = mountBar(handoff);

    expect(wrapper.text()).toContain('Club price for 40 boots');
    expect(wrapper.text()).toContain('Send a quote today');
    expect(wrapper.find('button').attributes('aria-expanded')).toBe('false');
  });

  it('opens on click with the details, the lead and the actions done', async () => {
    const wrapper = mountBar(handoff);

    await wrapper.find('button').trigger('click');

    expect(wrapper.find('button').attributes('aria-expanded')).toBe('true');
    expect(wrapper.text()).toContain('Sizes 38-46');
    expect(wrapper.text()).toContain('Lead saved: Bulk order');
    expect(wrapper.text()).toContain('Change delivery address');
  });

  it('does not open when there is nothing more to show', async () => {
    const wrapper = mountBar({
      status: 'handed_off',
      reason: 'Refund needs a person',
    });

    await wrapper.find('button').trigger('click');

    expect(wrapper.find('button').attributes('aria-expanded')).toBe('false');
  });
});
