// Reveals the bubbles of one Captain reply like a person typing. The server stamps each live bubble with
// captain_reply_id and captain_reveal_offset_ms (counted from the arrival of the reply's first bubble); a bubble is
// held until its offset passed, in order, while a local typing bubble shows. Everything held is revealed at once when
// the visitor writes, another message arrives or the widget reopens. History from the API is never paced.
export const REVEAL_CAP_MS = 15000;

const pacingOf = message => {
  const attributes = message.additional_attributes || {};
  return {
    replyId: attributes.captain_reply_id,
    offset: Math.min(
      Number(attributes.captain_reveal_offset_ms) || 0,
      REVEAL_CAP_MS
    ),
  };
};

export const createReplyPacer = ({
  reveal,
  setTyping,
  now = () => Date.now(),
}) => {
  let pending = [];
  let timer = null;
  let current = null; // { replyId, startedAt }
  let typing = false;

  const showTyping = status => {
    if (typing === status) return;
    typing = status;
    setTyping(status);
  };

  const schedule = () => {
    clearTimeout(timer);
    timer = null;
    if (!pending.length) {
      showTyping(false);
      return;
    }
    showTyping(true);
    // eslint-disable-next-line no-use-before-define
    timer = setTimeout(tick, Math.max(0, pending[0].revealAt - now()));
  };

  const tick = () => {
    while (pending.length && pending[0].revealAt <= now()) {
      reveal(pending.shift().message);
    }
    schedule();
  };

  const flush = () => {
    const held = pending;
    pending = [];
    held.forEach(entry => reveal(entry.message));
    schedule();
  };

  const holds = id => pending.some(entry => entry.message.id === id);

  // A live message.created event.
  const receive = message => {
    const { replyId, offset } = pacingOf(message);
    if (!replyId || replyId !== current?.replyId) flush();
    if (!replyId) {
      current = null;
      reveal(message);
      return;
    }
    if (replyId !== current?.replyId) current = { replyId, startedAt: now() };

    const last = pending[pending.length - 1];
    const revealAt = Math.max(current.startedAt + offset, last?.revealAt || 0);
    if (!pending.length && revealAt <= now()) {
      reveal(message);
      return;
    }
    pending.push({ message, revealAt });
    schedule();
  };

  // A live message.updated event for a held bubble updates the held copy; false when the message is not held.
  const update = message => {
    const entry = pending.find(held => held.message.id === message.id);
    if (!entry) return false;
    entry.message = message;
    return true;
  };

  const clear = () => {
    pending = [];
    current = null;
    schedule();
  };

  return { receive, update, flush, holds, clear };
};
