import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { aiPauseReasonText } from './aiPauseReason';

const DAY = 24 * 60 * 60 * 1000;
// The pace forecast needs a few days and some conversations before it means anything.
const FORECAST_MIN_DAYS = 3;
const FORECAST_MIN_USED = 10;
// A projected limit this many days or more before the reset is a warning; closer than that it is only a note.
const FORECAST_WARN_DAYS = 3;
const TRIAL_ENDING_DAYS = 3;

// Everything the Billing page shows, derived from the subscription JSON alone.
export const useBillingView = billing => {
  const { t, locale } = useI18n();
  const b = () => billing.value;

  const money = (cents, currency = b().currency) =>
    new Intl.NumberFormat(locale.value, {
      style: 'currency',
      currency,
      minimumFractionDigits: cents % 100 ? 2 : 0,
    }).format(cents / 100);
  const date = (value, year = false) =>
    new Date(value).toLocaleDateString(locale.value, {
      day: 'numeric',
      month: 'short',
      ...(year ? { year: 'numeric' } : {}),
    });

  const plan = computed(() => b().plan);
  const trial = computed(() => Boolean(b().trial_enabled));
  const details = computed(() => b().stripe_details || {});
  const ended = computed(() =>
    ['canceled', 'incomplete_expired'].includes(b().payment_status)
  );
  const liveSubscription = computed(
    () => Boolean(b().has_subscription) && !ended.value
  );
  const canceling = computed(
    () =>
      liveSubscription.value &&
      Boolean(details.value.cancel_at_period_end || details.value.cancel_at)
  );
  const endsAt = computed(() =>
    details.value.cancel_at
      ? new Date(details.value.cancel_at * 1000).toISOString()
      : b().period_ends_at
  );
  const pastDue = computed(() => b().payment_status === 'past_due');
  const free = computed(
    () => !trial.value && !liveSubscription.value && !b().monthly_price_cents
  );
  const trialDaysLeft = computed(() =>
    Math.max(0, Math.ceil((new Date(b().trial_ends_at) - Date.now()) / DAY))
  );

  // What the account pays: the live Stripe price (a founder or custom price can differ from the plan's list price),
  // else the account's own saved price, else the plan's.
  const interval = computed(
    () => details.value.interval || b().billing_interval || 'month'
  );
  const priceCents = computed(() => {
    if (liveSubscription.value && details.value.amount_cents != null)
      return details.value.amount_cents * (details.value.quantity ?? 1);
    const yearly = interval.value === 'year';
    if (b().monthly_price_cents)
      return yearly ? b().annual_price_cents : b().monthly_price_cents;
    if (!plan.value) return 0;
    return yearly
      ? plan.value.annual_price_cents
      : plan.value.monthly_price_cents;
  });
  const price = computed(() =>
    money(priceCents.value, details.value.currency || b().currency)
  );
  const cadence = computed(() =>
    interval.value === 'year'
      ? t('BILLING_PAGE.PER_YEAR')
      : t('BILLING_PAGE.PER_MONTH')
  );
  const planName = computed(
    () => plan.value?.name || t('BILLING_PAGE.CUSTOM_PLAN')
  );
  const card = computed(() => {
    const value = details.value.card;
    if (!value) return '';
    return t('BILLING_PAGE.CARD_ENDING', {
      brand: value.brand.charAt(0).toUpperCase() + value.brand.slice(1),
      last4: value.last4,
    });
  });
  const pending = computed(() => b().pending_plan_change);

  const usage = computed(() => b().products || {});
  const ai = computed(() => usage.value.ai_conversations || {});
  const included = computed(() => ai.value.limit ?? 0);
  const used = computed(() => ai.value.used ?? 0);
  const extraLeft = computed(() => b().extra_left || 0);
  const noAi = computed(
    () => !trial.value && included.value === 0 && !extraLeft.value
  );
  const status = computed(() => {
    if (pastDue.value)
      return { tone: 'limit', label: t('BILLING_PAGE.STATUS.PAST_DUE') };
    if (trial.value)
      return {
        tone:
          trialDaysLeft.value <= TRIAL_ENDING_DAYS ? 'attention' : 'learning',
        label: t(
          'BILLING_PAGE.STATUS.TRIAL',
          { count: trialDaysLeft.value },
          trialDaysLeft.value
        ),
      };
    if (b().payment_status === 'paused')
      return { tone: 'paused', label: t('BILLING_PAGE.STATUS.PAUSED') };
    // A running plan needs no badge: only states that ask for attention get one.
    return null;
  });

  const planLine = computed(() => {
    const parts = [];
    if (trial.value)
      parts.push(
        t('BILLING_PAGE.TRIAL_THEN_FREE', { date: date(b().trial_ends_at) })
      );
    else if (canceling.value)
      parts.push(t('BILLING_PAGE.ENDS_ON', { date: date(endsAt.value) }));
    else if (liveSubscription.value && b().period_ends_at)
      parts.push(
        t('BILLING_PAGE.RENEWS_ON', { date: date(b().period_ends_at) })
      );
    else if (noAi.value) parts.push(t('BILLING_PAGE.NO_AI'));
    return parts.join(' · ');
  });

  const usedPercent = computed(() =>
    included.value
      ? Math.min(100, Math.round((used.value / included.value) * 100))
      : 100
  );
  const atLimit = computed(
    () => included.value > 0 && used.value >= included.value
  );
  const periodEnd = computed(() =>
    trial.value ? b().trial_ends_at : b().quota_resets_at
  );
  const periodLabel = computed(() =>
    trial.value
      ? t('BILLING_PAGE.TRIAL_ENDS', { date: date(b().trial_ends_at) })
      : t('BILLING_PAGE.RESETS_ON', { date: date(b().quota_resets_at) })
  );
  const extraExpiresAt = computed(() => {
    const dates = (b().top_up?.history || [])
      .filter(entry => entry.reason === 'purchase' && entry.remaining > 0)
      .map(entry => entry.expires_at)
      .filter(Boolean)
      .sort();
    return dates[0] || null;
  });

  // One short line under the bar, or nothing while there is too little data to say anything.
  const pace = computed(() => {
    if (noAi.value || !included.value) return null;
    if (atLimit.value)
      return extraLeft.value
        ? {
            tone: 'slate',
            icon: 'i-lucide-layers',
            text: t('BILLING_PAGE.PACE.ON_EXTRA', { count: extraLeft.value }),
          }
        : {
            tone: 'ruby',
            icon: 'i-lucide-circle-pause',
            text: t('BILLING_PAGE.PACE.REACHED'),
          };
    const start = new Date(b().quota_started_at).getTime();
    const end = new Date(periodEnd.value).getTime();
    const elapsedDays = (Date.now() - start) / DAY;
    if (elapsedDays < FORECAST_MIN_DAYS || used.value < FORECAST_MIN_USED)
      return null;
    const reachAt =
      Date.now() +
      ((included.value - used.value) / used.value) * elapsedDays * DAY;
    if (reachAt >= end) return null;
    return {
      tone:
        !extraLeft.value && end - reachAt >= FORECAST_WARN_DAYS * DAY
          ? 'amber'
          : 'slate',
      icon: 'i-lucide-trending-up',
      text: t('BILLING_PAGE.PACE.PROJECTED', {
        limit: included.value,
        date: date(reachAt),
      }),
    };
  });

  const pack = computed(() => b().top_up?.pack);
  const packLabel = computed(() =>
    pack.value
      ? t('BILLING_PAGE.BUY_PACK', {
          count: pack.value.conversations,
          price: money(pack.value.amount_cents, pack.value.currency),
        })
      : ''
  );

  // The one alert at the top, most urgent first. `action` names what its button does.
  const alert = computed(() => {
    if (b().billing_sync_failed)
      return {
        tone: 'amber',
        icon: 'i-lucide-refresh-cw-off',
        text: t('BILLING_PAGE.ALERT.SYNC_FAILED'),
        action: 'retry',
        label: t('BILLING_PAGE.RETRY'),
      };
    if (pastDue.value)
      return {
        tone: 'ruby',
        icon: 'i-lucide-credit-card',
        text: b().ai_pauses_at
          ? t('BILLING_PAGE.ALERT.PAST_DUE', { date: date(b().ai_pauses_at) })
          : t('BILLING_PAGE.ALERT.PAST_DUE_NO_DATE'),
        action: 'portal',
        label: t('BILLING_PAGE.UPDATE_PAYMENT'),
      };
    const reason = b().ai_replies_paused ? b().ai_pause_reason : null;
    if (reason === 'limit_reached' && trial.value)
      return {
        tone: 'amber',
        icon: 'i-lucide-circle-pause',
        text: t('BILLING_PAGE.ALERT.TRIAL_LIMIT'),
        action: 'plans',
        label: t('BILLING_PAGE.CHOOSE_PLAN'),
      };
    if (reason === 'limit_reached')
      return {
        tone: 'amber',
        icon: 'i-lucide-circle-pause',
        text: t('BILLING_PAGE.ALERT.LIMIT', {
          date: date(b().quota_resets_at),
        }),
        action: b().top_up?.available ? 'buy' : null,
        label: packLabel.value,
      };
    if (reason === 'trial_ended')
      return {
        tone: 'amber',
        icon: 'i-lucide-circle-pause',
        text: t('BILLING_PAGE.ALERT.TRIAL_ENDED'),
        action: 'plans',
        label: t('BILLING_PAGE.CHOOSE_PLAN'),
      };
    if (reason && reason !== 'no_plan')
      return {
        tone: 'amber',
        icon: 'i-lucide-circle-pause',
        text: `${t('ACCOUNT_SUBSCRIPTION.AI_PAUSED.TITLE')}: ${aiPauseReasonText(t, reason)}`,
        action: null,
      };
    if (canceling.value)
      return {
        tone: 'slate',
        icon: 'i-lucide-calendar-x',
        text: t('BILLING_PAGE.ALERT.CANCELS', { date: date(endsAt.value) }),
        action: 'portal',
        label: t('BILLING_PAGE.RESUME'),
      };
    return null;
  });

  return {
    money,
    date,
    plan,
    planName,
    trial,
    free,
    liveSubscription,
    canceling,
    pastDue,
    price,
    priceCents,
    cadence,
    interval,
    status,
    planLine,
    pending,
    included,
    used,
    extraLeft,
    extraExpiresAt,
    noAi,
    usedPercent,
    atLimit,
    periodLabel,
    pace,
    card,
    pack,
    packLabel,
    alert,
  };
};
