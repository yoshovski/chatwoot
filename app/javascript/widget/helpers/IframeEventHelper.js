export const loadedEventConfig = () => {
  return {
    event: 'loaded',
    config: {
      authToken: window.authToken,
      channelConfig: window.chatwootWebChannel,
    },
  };
};

// The closed-chat preview is one card; the frame is exactly as tall as it.
export const getExtraSpaceToScroll = () => {
  const preview = document.querySelector('[data-notification-preview]');
  return preview ? Math.ceil(preview.getBoundingClientRect().height) : 0;
};

export const shouldTriggerMessageUpdateEvent = message => {
  const { previous_changes: previousChanges } = message;

  if (!previousChanges) {
    return false;
  }
  const hasNotifiableAttributeChanges =
    Object.keys(previousChanges).includes('content_attributes');
  if (!hasNotifiableAttributeChanges) {
    return false;
  }

  const hasSubmittedValueChanges = Object.keys(
    previousChanges.content_attributes[1] || {}
  ).includes('submitted_values');

  return hasSubmittedValueChanges;
};
