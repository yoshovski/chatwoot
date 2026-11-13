// Why the AI agent is not replying, from `ai_pause_reason` in the subscription JSON
// (AccountSubscription#ai_pause_reason). Shared by Billing and Home.
export const aiPauseReasonText = (t, reason) =>
  ({
    limit_reached: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.LIMIT_REACHED'),
    trial_ended: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.TRIAL_ENDED'),
    payment_failed: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.PAYMENT_FAILED'),
    paused: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.PAUSED'),
    no_plan: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.NO_PLAN'),
    email_unconfirmed: t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.EMAIL_UNCONFIRMED'),
  })[reason] || '';
