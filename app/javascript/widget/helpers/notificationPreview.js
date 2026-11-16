import { publicMessages, replyKey } from './attentionPolicy';

export const unreadReplies = (messages, lastSeen) => {
  const all = publicMessages(messages).filter(
    message => message.message_type === 1
  );
  const unread = all.filter(
    message => !lastSeen || message.created_at > lastSeen
  );
  const keys = new Set(unread.map(replyKey));
  return {
    count: keys.size,
    messages: all.filter(message => keys.has(replyKey(message))),
  };
};

export const notificationPreview = (messages, lastSeen) => {
  const unread = unreadReplies(messages, lastSeen).messages;
  const last = unread.at(-1);
  if (!last) return [];
  const reply = unread.filter(message => replyKey(message) === replyKey(last));
  const prose = reply.filter(
    message =>
      ['text', 'input_select', undefined, null].includes(
        message.content_type
      ) && message.content
  );
  const selected =
    prose.findLast(message =>
      message.additional_attributes?.captain_segment_kinds?.includes('question')
    ) || prose[0];
  // No product titles, attachments, private order details or form fields outside the chat.
  const choices = reply.findLast(
    message => message.content_type === 'input_select'
  );
  return [
    {
      ...(selected || last),
      content: selected?.content || '',
      previewKey: replyKey(last),
      suggestedResponses: (choices?.content_attributes?.items || []).slice(
        0,
        3
      ),
      choiceMessageId: choices?.id,
    },
  ];
};

const CAPTAIN_AVATAR = '/assets/images/dashboard/captain/ai-agent-avatar.svg';
const BOT_AVATAR = '/assets/images/chatwoot_bot.png';

// Who the closed-chat card is from: the agent or AI assistant, else the inbox.
export const previewSender = (sender, channelConfig, botLabel) => {
  const useInboxAvatar = channelConfig.enabledFeatures?.includes(
    'use_inbox_avatar_for_bot'
  );
  const fallbackAvatar = useInboxAvatar ? channelConfig.avatarUrl : BOT_AVATAR;
  if (!sender || !Object.keys(sender).length) {
    return {
      name: useInboxAvatar ? channelConfig.websiteName : botLabel,
      avatarUrl: fallbackAvatar,
    };
  }
  const defaultAvatar =
    sender.type === 'captain_assistant' ? CAPTAIN_AVATAR : fallbackAvatar;
  return {
    name: sender.available_name || sender.name || '',
    avatarUrl: sender.avatar_url || defaultAvatar,
  };
};
