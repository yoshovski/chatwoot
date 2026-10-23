import { extractVideo, parseVideoUrl } from '../videoLinks';

describe('videoLinks', () => {
  it('plays a YouTube link through the privacy-friendly player', () => {
    expect(
      parseVideoUrl('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
    ).toEqual({
      provider: 'youtube',
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      embedUrl: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?autoplay=1',
      thumbnail: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
    });
  });

  it('ignores links to pages that are not videos', () => {
    expect(parseVideoUrl('https://support.example.com/articles/1')).toBeNull();
  });

  it('moves a video link on its own line out of the text', () => {
    const text =
      'Clear your cache.\n\n[Watch: Clear cache](https://fast.wistia.net/embed/iframe/qnyqws7m7j)\n';

    const { video, text: rest } = extractVideo(text);

    expect(video).toMatchObject({
      provider: 'wistia',
      label: 'Watch: Clear cache',
      embedUrl: 'https://fast.wistia.net/embed/iframe/qnyqws7m7j?autoplay=1',
    });
    expect(rest).toBe('Clear your cache.');
  });

  it('keeps a video link that sits inside a sentence', () => {
    const text = 'See [this video](https://vimeo.com/123456) for the steps.';

    expect(extractVideo(text)).toEqual({ video: null, text });
  });
});
