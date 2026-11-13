import { CONVERSATION_STATE, conversationState } from '../conversationState';

const incoming = { id: 1, message_type: 0 };
const outgoing = { id: 2, message_type: 1 };
const build = (attrs = {}) => ({
  id: 1,
  status: 'open',
  labels: [],
  messages: [],
  meta: {},
  ...attrs,
});

describe('conversationState', () => {
  it('reads resolved as solved and snoozed as waiting', () => {
    expect(conversationState(build({ status: 'resolved' }))).toBe(
      CONVERSATION_STATE.SOLVED
    );
    expect(conversationState(build({ status: 'snoozed' }))).toBe(
      CONVERSATION_STATE.WAITING
    );
  });

  it('reads pending or an AI assignee as AI is handling', () => {
    expect(conversationState(build({ status: 'pending' }))).toBe(
      CONVERSATION_STATE.AI_HANDLING
    );
    expect(
      conversationState(
        build({
          meta: { assignee_type: 'Captain::Assistant' },
          messages: [incoming],
        })
      )
    ).toBe(CONVERSATION_STATE.AI_HANDLING);
  });

  it('reads a handover as needs you until a person replies', () => {
    const handedOff = build({
      labels: ['needs-human'],
      meta: { assignee_type: 'Captain::Assistant' },
      messages: [incoming],
    });
    expect(conversationState(handedOff)).toBe(CONVERSATION_STATE.NEEDS_YOU);
    expect(conversationState({ ...handedOff, messages: [outgoing] })).toBe(
      CONVERSATION_STATE.WAITING
    );
    expect(
      conversationState(
        build({
          additional_attributes: {
            captain_summary: { status: 'handed_off', wants: 'A refund' },
          },
          messages: [incoming],
        })
      )
    ).toBe(CONVERSATION_STATE.NEEDS_YOU);
  });

  it('reads who spoke last for open conversations a person owns', () => {
    expect(conversationState(build({ messages: [incoming] }))).toBe(
      CONVERSATION_STATE.NEEDS_YOU
    );
    expect(conversationState(build({ messages: [outgoing] }))).toBe(
      CONVERSATION_STATE.WAITING
    );
  });

  it('skips private notes and activity when finding the last message', () => {
    const note = { id: 3, message_type: 1, private: true };
    const activity = { id: 4, message_type: 2 };
    expect(
      conversationState(build({ messages: [incoming, note, activity] }))
    ).toBe(CONVERSATION_STATE.NEEDS_YOU);
  });

  it('falls back to the last message from the API', () => {
    expect(
      conversationState(build({ last_non_activity_message: outgoing }))
    ).toBe(CONVERSATION_STATE.WAITING);
  });
});
