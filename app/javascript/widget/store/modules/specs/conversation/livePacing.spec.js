import { actions } from '../../conversation/actions';
import { getters } from '../../conversation/getters';

vi.mock('widget/helpers/axios');

const captainBubble = (id, offset) => ({
  id,
  message_type: 1,
  content: `bubble ${id}`,
  content_attributes: {},
  additional_attributes: {
    captain_reply_id: 'reply-live',
    captain_reveal_offset_ms: offset,
  },
});

describe('live Captain reply pacing in the widget store', () => {
  const shown = [];
  const commit = vi.fn((name, payload) => {
    if (name === 'pushMessageToConversation') shown.push(payload.id);
  });
  const dispatch = vi.fn((action, message) => {
    if (action === 'addOrUpdateMessage') shown.push(message.id);
    return Promise.resolve();
  });
  const context = { commit, dispatch };

  beforeEach(() => {
    vi.useFakeTimers();
    shown.length = 0;
    commit.mockClear();
    dispatch.mockClear();
    actions.clearConversations(context);
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('shows the typing bubble while a bubble is held and the bubble after its pause', () => {
    actions.receiveLiveMessage(context, captainBubble(1, 0));
    actions.receiveLiveMessage(context, captainBubble(2, 1500));

    expect(shown).toEqual([1]);
    expect(commit).toHaveBeenCalledWith('setReplyRevealing', true);
    expect(
      getters.getIsAgentTyping({
        uiFlags: { isAgentTyping: false, isRevealingReply: true },
      })
    ).toBe(true);

    vi.advanceTimersByTime(1500);
    expect(shown).toEqual([1, 2]);
    expect(commit).toHaveBeenLastCalledWith('setReplyRevealing', false);
  });

  it('reveals the held bubble before the visitor message is pushed', () => {
    actions.receiveLiveMessage(context, captainBubble(1, 0));
    actions.receiveLiveMessage(context, captainBubble(2, 2000));
    actions.sendMessageWithData(context, {
      message: { id: 'temp', content: 'wait', message_type: 0 },
    });

    expect(shown.slice(0, 3)).toEqual([1, 2, 'temp']);
  });

  it('reveals held bubbles when the widget reopens', () => {
    actions.receiveLiveMessage(context, captainBubble(1, 0));
    actions.receiveLiveMessage(context, captainBubble(2, 2000));
    actions.revealPacedReplies(context);

    expect(shown).toEqual([1, 2]);
  });

  it('shows history and messages without pacing attributes at once', () => {
    actions.receiveLiveMessage(context, {
      id: 5,
      message_type: 1,
      content: 'A human reply',
      sender_type: 'User',
    });

    expect(shown).toEqual([5]);
    expect(commit).not.toHaveBeenCalledWith('setReplyRevealing', true);
  });

  it('keeps an updated held bubble waiting', () => {
    actions.receiveLiveMessage(context, captainBubble(1, 0));
    actions.receiveLiveMessage(context, captainBubble(2, 2000));
    actions.updateLiveMessage(context, {
      ...captainBubble(2, 2000),
      content: 'edited',
    });

    expect(shown).toEqual([1]);
    vi.advanceTimersByTime(2000);
    expect(shown).toEqual([1, 2]);
  });
});
