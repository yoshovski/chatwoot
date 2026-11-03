const post = vi.fn(() => Promise.resolve());
vi.mock('widget/helpers/axios', () => ({ API: { post } }));

describe('websiteActivity', () => {
  let activity;
  const API = { post };

  beforeEach(async () => {
    vi.resetModules();
    post.mockClear();
    window.WOOT_WIDGET = { $root: { $i18n: { locale: 'en' } } };
    window.sessionStorage.clear();
    window.referrerURL = 'https://shop.example.com/plans?utm_campaign=spring';
    window.referrerPageTitle = 'Plans';
    activity = await import('../websiteActivity');
  });

  afterEach(() => {
    window.referrerURL = undefined;
  });

  it('posts the page without its query, with the arrival and time zone', async () => {
    activity.setArrival({
      referrer_host: 'www.google.com',
      utm_campaign: 'spring',
    });
    await activity.recordWebsiteActivity();

    const [url, body] = API.post.mock.calls[0];
    expect(url).toContain('/api/v1/widget/website_activity');
    expect(body.page).toEqual({
      url: 'https://shop.example.com/plans',
      title: 'Plans',
    });
    expect(body.visit).toEqual({
      referrer_host: 'www.google.com',
      utm_campaign: 'spring',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
    });
  });

  it('keeps the landing arrival when a later page has none', async () => {
    activity.setArrival({ utm_source: 'newsletter' });
    activity.setArrival(null);
    vi.resetModules();
    const reloaded = await import('../websiteActivity');

    expect(reloaded.visitParams().utm_source).toEqual('newsletter');
  });

  it('sends the visit once after the first message of the page load', async () => {
    await activity.recordVisitAfterFirstMessage();
    await activity.recordVisitAfterFirstMessage();

    expect(API.post).toHaveBeenCalledTimes(1);
  });
});
