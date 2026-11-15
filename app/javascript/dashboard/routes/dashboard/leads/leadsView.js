import { dynamicTime } from 'shared/helpers/timeHelper';

export const STATUSES = ['new', 'contacted', 'won', 'lost'];

export const STATUS_TONES = {
  new: { pill: 'bg-n-blue-3 text-n-blue-11', dot: 'bg-n-blue-9' },
  contacted: { pill: 'bg-n-amber-3 text-n-amber-11', dot: 'bg-n-amber-9' },
  won: { pill: 'bg-n-teal-3 text-n-teal-11', dot: 'bg-n-teal-9' },
  lost: { pill: 'bg-n-alpha-2 text-n-slate-11', dot: 'bg-n-slate-9' },
};

export const HUBSPOT_STATES = {
  synced: { icon: 'i-lucide-circle-check', tone: 'text-n-teal-11' },
  pending: { icon: 'i-lucide-loader-circle', tone: 'text-n-slate-11' },
  failed: { icon: 'i-lucide-circle-alert', tone: 'text-n-ruby-11' },
  not_synced: { icon: 'i-lucide-circle-dashed', tone: 'text-n-slate-11' },
  off: { icon: 'i-lucide-minus', tone: 'text-n-slate-10' },
};

export const capturedAgo = iso => dynamicTime(Date.parse(iso) / 1000);
