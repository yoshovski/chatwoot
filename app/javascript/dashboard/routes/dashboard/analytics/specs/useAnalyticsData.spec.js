import { effectScope, nextTick, ref } from 'vue';
import { flushPromises } from '@vue/test-utils';
import CaptainHomeAPI from 'dashboard/api/captain/home';
import ReportsAPI from 'dashboard/api/reports';
import { LOADERS, useAnalyticsData } from '../useAnalyticsData';
import { periodWindow } from '../analyticsView';

vi.mock('dashboard/api/captain/home', () => ({ default: { get: vi.fn() } }));
vi.mock('dashboard/api/reports', () => ({ default: { getSummary: vi.fn() } }));

let scope;
beforeEach(() => {
  scope = effectScope();
});
afterEach(() => {
  scope.stop();
  vi.useRealTimers();
});

it.each([7, 30, 90, 'this_week', 'last_week', 'this_month', 'last_month'])(
  'requests the selected %s range and matching report boundaries',
  async period => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-11-16T14:30:00Z'));
    CaptainHomeAPI.get.mockResolvedValue({ data: { days: [] } });
    ReportsAPI.getSummary.mockResolvedValue({
      data: { conversations_count: 0 },
    });
    scope.run(() =>
      useAnalyticsData(ref(period), {
        activity: LOADERS.activity,
        report: LOADERS.report,
      })
    );
    await flushPromises();
    const window = periodWindow(period);
    expect(CaptainHomeAPI.get).toHaveBeenCalledWith({
      range: String(period),
      timezoneOffset: expect.any(Number),
    });
    expect(ReportsAPI.getSummary).toHaveBeenCalledWith(
      window.since,
      window.until,
      'account'
    );
  }
);

it('retains successful sections and marks failed sections without inventing zeros', async () => {
  const state = scope.run(() =>
    useAnalyticsData(ref(90), {
      activity: () =>
        Promise.resolve({ data: { metrics: { rating: { value: 4.5 } } } }),
      report: () => Promise.reject(new Error('unavailable')),
    })
  );
  await flushPromises();
  expect(state.data.value.activity.metrics.rating.value).toBe(4.5);
  expect(state.data.value.report).toBeUndefined();
  expect(state.failures.value).toEqual({ activity: false, report: true });
  expect(state.hasError.value).toBe(false);
});

it('does not let an older range overwrite a newer range', async () => {
  let finishOld;
  const period = ref(7);
  const state = scope.run(() =>
    useAnalyticsData(period, {
      report: ({ period: requested }) =>
        requested === 7
          ? new Promise(resolve => {
              finishOld = resolve;
            })
          : Promise.resolve({ data: { period: requested } }),
    })
  );
  period.value = 90;
  await nextTick();
  await flushPromises();
  finishOld({ data: { period: 7 } });
  await flushPromises();
  expect(state.data.value.report.period).toBe(90);
});

it('clears old-period data while loading and retries a full failure', async () => {
  const loader = vi
    .fn()
    .mockRejectedValueOnce(new Error('offline'))
    .mockResolvedValue({ data: { value: 0 } });
  const state = scope.run(() =>
    useAnalyticsData(ref(30), { activity: loader })
  );
  await flushPromises();
  expect(state.hasError.value).toBe(true);
  await state.reload();
  expect(state.hasError.value).toBe(false);
  expect(state.data.value.activity.value).toBe(0);
});
