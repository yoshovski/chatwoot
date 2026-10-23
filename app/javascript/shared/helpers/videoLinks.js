// Video links an AI agent copies from knowledge pages. The widget and playground show them as a click-to-play
// card; other channels keep the plain link. Keep the providers in sync with Captain::Knowledge::VideoLink.
const PROVIDERS = [
  {
    provider: 'youtube',
    pattern: /^https:\/\/www\.youtube\.com\/watch\?v=([\w-]{6,})/,
    embed: id => `https://www.youtube-nocookie.com/embed/${id}?autoplay=1`,
    thumbnail: id => `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
  },
  {
    provider: 'vimeo',
    pattern: /^https:\/\/vimeo\.com\/(\d+)/,
    embed: id => `https://player.vimeo.com/video/${id}?autoplay=1&dnt=1`,
  },
  {
    provider: 'wistia',
    pattern: /^https:\/\/fast\.wistia\.net\/embed\/iframe\/(\w+)/,
    embed: id => `https://fast.wistia.net/embed/iframe/${id}?autoplay=1`,
  },
  {
    provider: 'loom',
    pattern: /^https:\/\/www\.loom\.com\/share\/(\w+)/,
    embed: id => `https://www.loom.com/embed/${id}?autoplay=1`,
  },
];
const VIDEO_FILE = /^https:\/\/[^\s?#]+\.(?:mp4|webm)(?:[?#]\S*)?$/i;
// A markdown link alone on its line, the form the AI agent is told to use.
const LINK_LINE = /^[ \t]*\[([^\]\n]+)\]\((https:\/\/[^\s)]+)\)[ \t]*$/gm;

export const parseVideoUrl = url => {
  if (VIDEO_FILE.test(url)) return { provider: 'file', url, embedUrl: url };

  const match = PROVIDERS.map(item => ({
    item,
    id: url.match(item.pattern)?.[1],
  })).find(({ id }) => id);
  if (!match) return null;

  const { item, id } = match;
  return {
    provider: item.provider,
    url,
    embedUrl: item.embed(id),
    thumbnail: item.thumbnail?.(id) || '',
  };
};

// The first video link on its own line, with the text minus that line.
export const extractVideo = (text = '') => {
  const found = [...(text || '').matchAll(LINK_LINE)]
    .map(([line, label, url]) => ({ line, label, video: parseVideoUrl(url) }))
    .find(({ video }) => video);
  if (!found) return { video: null, text };

  return {
    video: { ...found.video, label: found.label },
    text: text
      .replace(found.line, '')
      .replace(/\n{3,}/g, '\n\n')
      .trim(),
  };
};
