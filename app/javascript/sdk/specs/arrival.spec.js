import { readArrival, UTM_LIMIT } from '../arrival';

describe('readArrival', () => {
  const host = 'shop.example.com';

  it('keeps only the referrer host and the UTM values', () => {
    expect(
      readArrival({
        referrer: 'https://www.google.com/search?q=private',
        search: '?utm_source=google&utm_campaign=spring-sale&email=a%40b.c',
        host,
      })
    ).toEqual({
      referrer_host: 'www.google.com',
      utm_source: 'google',
      utm_campaign: 'spring-sale',
    });
  });

  it('cuts each UTM value to the limit', () => {
    const arrival = readArrival({
      referrer: '',
      search: `?utm_medium=${'a'.repeat(150)}`,
      host,
    });
    expect(arrival.utm_medium).toHaveLength(UTM_LIMIT);
  });

  it('ignores internal navigation and unparsable referrers', () => {
    expect(
      readArrival({ referrer: `https://${host}/plans`, search: '', host })
    ).toBeNull();
    expect(readArrival({ referrer: 'not a url', search: '', host })).toBeNull();
  });
});
