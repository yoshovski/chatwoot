import { reactive } from 'vue';

export const attentionState = reactive({
  draft: false,
  composing: false,
  hostVisible: !document.hidden,
  hostFormActive: false,
  muted: false,
  audioReady: false,
  offer: null,
  snoozed: false,
  previewDismissedKey: null,
});
