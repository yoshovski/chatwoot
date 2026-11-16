import {
  attentionCandidate,
  createAttentionTimer,
  CHECK_IN_DELAY_MS,
  QUESTION_DELAY_MS,
} from '../attentionPolicy';

const NOW = 1_800_000_000_000;
const at = secondsAgo => NOW / 1000 - secondsAgo;
const bubble = (id, attributes = {}, extra = {}) => ({
  id,
  conversation_id: 7,
  message_type: 1,
  content: 'The X2 takes the 5000 mAh pack.',
  created_at: at(5),
  ...extra,
  additional_attributes: { captain_reply_id: 'r1', ...attributes },
});
const reply = (intent, extraBubbles = []) => ({
  1: {
    id: 1,
    conversation_id: 7,
    message_type: 0,
    content: 'Which battery?',
    created_at: at(10),
  },
  2: bubble(2),
  ...Object.fromEntries(extraBubbles.map(message => [message.id, message])),
  9: bubble(9, { captain_reply_final: true, captain_attention_intent: intent }),
});

describe('attentionCandidate', () => {
  it('offers the check-in after a complete answer, even with optional buttons', () => {
    const buttons = bubble(
      3,
      {},
      {
        content: '',
        content_type: 'input_select',
        content_attributes: {
          items: [
            { title: 'Batteries' },
            { title: 'Modules' },
            { title: 'Both' },
          ],
        },
      }
    );

    expect(
      attentionCandidate(reply('answer_complete', [buttons]), NOW)
    ).toMatchObject({
      kind: 'check_in',
      key: '7:r1',
      messageId: 9,
      delay: CHECK_IN_DELAY_MS,
      suggestions: [
        { title: 'Batteries' },
        { title: 'Modules' },
        { title: 'Both' },
      ],
    });
  });

  it('asks for a question cue when an answer is needed', () => {
    const question = bubble(
      4,
      { captain_segment_kinds: ['question'] },
      { content: 'Which drone?' }
    );

    expect(
      attentionCandidate(reply('awaiting_answer', [question]), NOW)
    ).toMatchObject({
      kind: 'question',
      delay: QUESTION_DELAY_MS,
    });
  });

  it('stays quiet for unknown intent, an unfinished reply or a visitor message', () => {
    expect(attentionCandidate(reply('none'), NOW)).toBeNull();
    expect(attentionCandidate({ 2: bubble(2) }, NOW)).toBeNull();
    expect(
      attentionCandidate(
        {
          ...reply('answer_complete'),
          10: { id: 10, message_type: 0, created_at: at(1) },
        },
        NOW
      )
    ).toBeNull();
  });

  it('uses the stamped delays and adds reading time for long replies', () => {
    const messages = reply('answer_complete');
    messages[9].additional_attributes.captain_attention_delays = {
      check_in: 30000,
    };
    messages[2].content = 'word '.repeat(140);

    expect(attentionCandidate(messages, NOW).delay).toBe(30000 + 20000);
  });
});

describe('createAttentionTimer', () => {
  const candidate = {
    key: '7:r1',
    messageId: 9,
    kind: 'check_in',
    delay: 35000,
  };
  let claim;
  let present;
  let discard;
  let timer;

  beforeEach(() => {
    vi.useFakeTimers();
    claim = vi.fn().mockResolvedValue({ event_id: 1 });
    present = vi.fn();
    discard = vi.fn();
    timer = createAttentionTimer({ claim, present, discard });
  });

  afterEach(() => vi.useRealTimers());

  it('presents once after the quiet time', async () => {
    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(34999);
    expect(claim).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(1);
    expect(present).toHaveBeenCalledWith(candidate, { event_id: 1 });
  });

  it('restarts the clock when the visitor interacts', async () => {
    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(30000);
    timer.activity();
    await vi.advanceTimersByTimeAsync(30000);
    expect(claim).not.toHaveBeenCalled();

    await vi.advanceTimersByTimeAsync(5000);
    expect(present).toHaveBeenCalledTimes(1);
  });

  it('waits while the visitor has a draft, then starts over', async () => {
    timer.update(candidate, true);
    await vi.advanceTimersByTimeAsync(120000);
    expect(claim).not.toHaveBeenCalled();

    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(35000);
    expect(present).toHaveBeenCalledTimes(1);
  });

  it('never tries the same reply twice, however often the visitor goes quiet', async () => {
    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(35000);
    for (let pause = 0; pause < 5; pause += 1) {
      timer.update(candidate, true);
      timer.update(candidate, false);
      timer.activity();
      // eslint-disable-next-line no-await-in-loop
      await vi.advanceTimersByTimeAsync(60000);
    }

    expect(claim).toHaveBeenCalledTimes(1);
    expect(present).toHaveBeenCalledTimes(1);
  });

  it('drops a grant that arrives after the visitor started typing', async () => {
    let resolveClaim;
    claim.mockReturnValue(
      new Promise(resolve => {
        resolveClaim = resolve;
      })
    );
    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(35000);
    timer.update(candidate, true);
    resolveClaim({ event_id: 1 });
    await vi.advanceTimersByTimeAsync(0);

    expect(present).not.toHaveBeenCalled();
    expect(discard).toHaveBeenCalledWith({ event_id: 1 });
  });

  it('presents nothing when the server refuses', async () => {
    claim.mockResolvedValue(null);
    timer.update(candidate, false);
    await vi.advanceTimersByTimeAsync(35000);

    expect(present).not.toHaveBeenCalled();
  });
});
