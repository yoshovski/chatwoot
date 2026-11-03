import {
  createReplyPacer,
  REVEAL_CAP_MS,
} from '../../conversation/replyPacing';

const bubble = (id, offset, replyId = 'reply-1') => ({
  id,
  content: `bubble ${id}`,
  additional_attributes: {
    captain_reply_id: replyId,
    captain_reveal_offset_ms: offset,
  },
});

describe('createReplyPacer', () => {
  let revealed;
  let setTyping;
  let pacer;

  beforeEach(() => {
    vi.useFakeTimers();
    revealed = [];
    setTyping = vi.fn();
    pacer = createReplyPacer({
      reveal: message => revealed.push(message.id),
      setTyping,
    });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('reveals the bubbles of a reply in order after their offsets, with typing while held', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 1100));
    pacer.receive(bubble(3, 1100));
    pacer.receive(bubble(4, 2000));

    expect(revealed).toEqual([1]);
    expect(setTyping).toHaveBeenLastCalledWith(true);

    vi.advanceTimersByTime(1099);
    expect(revealed).toEqual([1]);
    vi.advanceTimersByTime(1);
    expect(revealed).toEqual([1, 2, 3]);
    expect(setTyping).toHaveBeenLastCalledWith(true);

    vi.advanceTimersByTime(900);
    expect(revealed).toEqual([1, 2, 3, 4]);
    expect(setTyping).toHaveBeenLastCalledWith(false);
  });

  it('counts the offset from the arrival of the first bubble', () => {
    pacer.receive(bubble(1, 0));
    vi.advanceTimersByTime(400);
    pacer.receive(bubble(2, 1000));

    vi.advanceTimersByTime(599);
    expect(revealed).toEqual([1]);
    vi.advanceTimersByTime(1);
    expect(revealed).toEqual([1, 2]);
  });

  it('caps the wait', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 60000));

    vi.advanceTimersByTime(REVEAL_CAP_MS);
    expect(revealed).toEqual([1, 2]);
  });

  it('reveals everything held when the visitor writes or the widget reopens', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 2000));
    pacer.flush();

    expect(revealed).toEqual([1, 2]);
    expect(setTyping).toHaveBeenLastCalledWith(false);
    vi.runAllTimers();
    expect(revealed).toEqual([1, 2]);
  });

  it('reveals held bubbles before a message from someone else, which shows at once', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 2000));
    pacer.receive({ id: 3, content: 'Hi, this is Ana', sender_type: 'User' });

    expect(revealed).toEqual([1, 2, 3]);
  });

  it('reveals held bubbles of an earlier reply when a new reply starts', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 2000));
    pacer.receive(bubble(3, 0, 'reply-2'));

    expect(revealed).toEqual([1, 2, 3]);
  });

  it('holds the first bubble for the rest of the minimum typing time', () => {
    pacer.receive(bubble(1, 600));

    expect(revealed).toEqual([]);
    expect(setTyping).toHaveBeenCalledWith(true);
    vi.advanceTimersByTime(600);
    expect(revealed).toEqual([1]);
  });

  it('updates a held bubble instead of showing it early', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 2000));

    expect(pacer.update({ ...bubble(2, 2000), content: 'edited' })).toBe(true);
    expect(pacer.update(bubble(1, 0))).toBe(false);
    expect(revealed).toEqual([1]);
  });

  it('drops held bubbles when the conversation is cleared', () => {
    pacer.receive(bubble(1, 0));
    pacer.receive(bubble(2, 2000));
    pacer.clear();
    vi.runAllTimers();

    expect(revealed).toEqual([1]);
    expect(setTyping).toHaveBeenLastCalledWith(false);
  });
});
