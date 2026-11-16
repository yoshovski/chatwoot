export const QUESTION_DELAY_MS = 20000;
export const CHECK_IN_DELAY_MS = 35000;
export const REPLY_LIFETIME_MS = 5 * 60 * 1000;

export const replyKey = message =>
  `${message.conversation_id}:${message.additional_attributes?.captain_reply_id || message.id}`;

export const publicMessages = messages =>
  Object.values(messages)
    .filter(
      message =>
        [0, 1].includes(message.message_type) &&
        !message.private &&
        !message.content_attributes?.deleted
    )
    .sort((a, b) => a.created_at - b.created_at || Number(a.id) - Number(b.id));

export const latestReply = messages => {
  const all = publicMessages(messages);
  const last = all.at(-1);
  if (!last || last.message_type !== 1) return [];
  return all.filter(
    message =>
      message.message_type === 1 && replyKey(message) === replyKey(last)
  );
};

export const attentionCandidate = (messages, now = Date.now()) => {
  const reply = latestReply(messages);
  const last = reply.at(-1);
  if (!last || now - last.created_at * 1000 > REPLY_LIFETIME_MS) return null;
  if (last.content_attributes?.submitted_values?.length) return null;
  const attributes = last.additional_attributes || {};
  if (!attributes.captain_reply_final) return null;
  const kind = {
    awaiting_answer: 'question',
    answer_complete: 'check_in',
  }[attributes.captain_attention_intent];
  if (!kind) return null;

  const words = reply
    .map(message => message.content || '')
    .join(' ')
    .trim()
    .split(/\s+/).length;
  const readingTime = Math.min(20000, Math.max(0, (words - 80) / 3) * 1000);
  const defaultDelay =
    kind === 'question' ? QUESTION_DELAY_MS : CHECK_IN_DELAY_MS;
  const delay = attributes.captain_attention_delays?.[kind] || defaultDelay;
  const choices = reply.findLast(
    message => message.content_attributes?.items?.length
  );
  return {
    key: replyKey(last),
    messageId: last.id,
    kind,
    delay: delay + readingTime,
    suggestions: (choices?.content_attributes?.items || []).slice(0, 3),
  };
};

// A deadline belongs to one exact reply and activity revision. Async grants arriving after
// typing, navigation or a newer message are consumed without being displayed or replayed.
export const createAttentionTimer = ({
  claim,
  present,
  discard = () => {},
}) => {
  let timer;
  let revision = 0;
  let current = null;
  let blocked = true;
  const attempted = new Set();

  const cancel = () => {
    revision += 1;
    clearTimeout(timer);
  };
  const schedule = () => {
    cancel();
    if (blocked || !current || attempted.has(current.key)) return;
    const candidate = current;
    const generation = revision;
    timer = setTimeout(async () => {
      attempted.add(candidate.key);
      try {
        const grant = await claim(candidate);
        if (!grant) return;
        if (generation !== revision || blocked) {
          discard(grant);
          return;
        }
        present(candidate, grant);
      } catch {
        // No retry: reconnects and late network responses must not turn into surprise cues.
      }
    }, candidate.delay);
  };
  return {
    update(candidate, isBlocked) {
      const changed =
        current?.key !== candidate?.key ||
        current?.messageId !== candidate?.messageId ||
        blocked !== isBlocked;
      current = candidate;
      blocked = isBlocked;
      if (changed) schedule();
    },
    activity: schedule,
    stop: cancel,
  };
};
