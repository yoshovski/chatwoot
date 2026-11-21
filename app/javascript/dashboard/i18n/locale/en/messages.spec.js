import { createI18n } from 'vue-i18n';
import dashboardMessages from './index';
import italianMessages from '../it';
import spanishMessages from '../es';
import frenchMessages from '../fr';
import widgetMessages from 'widget/i18n/locale/en.json';
import italianWidgetMessages from 'widget/i18n/locale/it.json';
import spanishWidgetMessages from 'widget/i18n/locale/es.json';
import frenchWidgetMessages from 'widget/i18n/locale/fr.json';
import surveyMessages from 'survey/i18n/locale/en.json';

// vue-i18n only warns about a broken message in development but throws in a
// production build, which takes the whole rendering component down with it.
// Compile every English string the way production does.
const flattenKeys = (messages, prefix = '') =>
  Object.entries(messages).flatMap(([key, value]) => {
    const path = prefix ? `${prefix}.${key}` : key;
    return typeof value === 'string' ? [path] : flattenKeys(value, path);
  });

const brokenKeys = (messages, locale = 'en') => {
  const i18n = createI18n({
    legacy: false,
    locale,
    messages: { [locale]: messages },
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

describe('Locale messages', () => {
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

  it.each([
    ['fr', frenchMessages],
    ['it', italianMessages],
    ['es', spanishMessages],
  ])(
    'loads all %s AI Agent controls without English fallback',
    (locale, messages) => {
      const copy = messages.CAPTAIN.AGENT_UX;
      const englishKeys = flattenKeys(dashboardMessages.CAPTAIN.AGENT_UX);
      expect(flattenKeys(copy).sort()).toEqual(englishKeys.sort());
      expect(brokenKeys(copy, locale)).toEqual([]);
    }
  );

  it.each([
    ['it', italianMessages],
    ['es', spanishMessages],
  ])('compiles the full dashboard in %s', (locale, messages) => {
    expect(brokenKeys(messages, locale)).toEqual([]);
  });

  it.each([
    ['fr', frenchWidgetMessages],
    ['it', italianWidgetMessages],
    ['es', spanishWidgetMessages],
  ])('loads every widget message in %s', (locale, messages) => {
    expect(flattenKeys(messages)).toEqual(
      expect.arrayContaining(flattenKeys(widgetMessages))
    );
    expect(brokenKeys(messages, locale)).toEqual([]);
  });
});
