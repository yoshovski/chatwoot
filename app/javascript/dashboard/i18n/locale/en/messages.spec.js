import { createI18n } from 'vue-i18n';
import dashboardMessages from './index';
import widgetMessages from 'widget/i18n/locale/en.json';
import surveyMessages from 'survey/i18n/locale/en.json';

// vue-i18n only warns about a broken message in development but throws in a
// production build, which takes the whole rendering component down with it.
// Compile every English string the way production does.
const flattenKeys = (messages, prefix = '') =>
  Object.entries(messages).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    return typeof value === 'string' ? [path] : flattenKeys(value, path);
  });

const brokenKeys = messages => {
  const i18n = createI18n({
    legacy: false,
    locale: 'en',
    messages: { en: messages },
  });
  return flattenKeys(messages).filter(key => {
    try {
      i18n.global.t(key);
      return false;
    } catch {
      return true;
    }
  });
};

describe('English locale messages', () => {
  const originalEnv = process.env.NODE_ENV;

  beforeEach(() => {
    process.env.NODE_ENV = 'production';
  });

  afterEach(() => {
    process.env.NODE_ENV = originalEnv;
  });

  it.each([
    ['dashboard', dashboardMessages],
    ['widget', widgetMessages],
    ['survey', surveyMessages],
  ])('compiles every %s message', (_name, messages) => {
    expect(brokenKeys(messages)).toEqual([]);
  });
});
