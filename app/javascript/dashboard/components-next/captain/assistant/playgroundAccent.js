import { getWidgetForegroundColor } from 'shared/helpers/colorHelper';

// Without an inbox the playground falls back to the dashboard's own brand colour.
const BRAND_ACCENT = { class: 'bg-n-brand text-white' };

// Attributes for anything the widget fills with its colour (customer bubbles, buttons, the header bar).
export const accentAttrs = (widgetColor, widgetTextColor) => {
  if (!widgetColor) return BRAND_ACCENT;

  return {
    style: {
      backgroundColor: widgetColor,
      color: widgetTextColor || getWidgetForegroundColor(widgetColor),
    },
  };
};

export const demoUrl = inbox =>
  `${window.location.origin}/demo/${inbox.demo_slug || inbox.website_token}`;
