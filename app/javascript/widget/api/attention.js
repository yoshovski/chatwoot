import { API } from 'widget/helpers/axios';

export const requestAttention = async (kind, { messageId, eventId } = {}) => {
  const { data } = await API.post(
    `/api/v1/widget/attention${window.location.search}`,
    { kind, message_id: messageId, event_id: eventId }
  );
  return data || null;
};
