import { getters } from '../../conversation/getters';

describe('#getters', () => {
  it('getConversation', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
      },
    };
    expect(getters.getConversation(state)).toEqual({
      1: {
        content: 'hello',
      },
    });
  });

  it('getIsCreating', () => {
    const state = { uiFlags: { isCreating: true } };
    expect(getters.getIsCreating(state)).toEqual(true);
  });

  it('getConversationSize', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
      },
    };
    expect(getters.getConversationSize(state)).toEqual(1);
  });

  it('getEarliestMessage', () => {
    const state = {
      conversations: {
        1: {
          content: 'hello',
        },
        2: {
          content: 'hello1',
        },
      },
    };
    expect(getters.getEarliestMessage(state)).toEqual({
      content: 'hello',
    });
  });

  it('uiFlags', () => {
    const state = {
      uiFlags: {
        allMessagesLoaded: false,
        isFetchingList: false,
        isAgentTyping: false,
      },
    };
    expect(getters.getAllMessagesLoaded(state)).toEqual(false);
    expect(getters.getIsFetchingList(state)).toEqual(false);
    expect(getters.getIsAgentTyping(state)).toEqual(false);
  });

  it('getGroupedConversation', () => {
    expect(
      getters.getGroupedConversation({
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 0,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
          3: {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            message_type: 1,
          },
          4: {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
          },
          5: {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
          },
        },
      })
    ).toEqual([
      {
        date: 'Nov 18, 2019',
        messages: [
          {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            showAvatar: false,
            message_type: 0,
          },
          {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 0,
          },
          {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 1,
          },
        ],
      },
      {
        date: 'Dec 14, 2019',
        messages: [
          {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
            showAvatar: false,
          },
          {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            showAvatar: true,
          },
        ],
      },
    ]);

    expect(
      getters.getGroupedConversation({
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 0,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
          3: {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            message_type: 1,
          },
          4: {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
          },
          5: {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
          },
          6: {
            id: 6,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
          },
          7: {
            id: 7,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
          },
        },
      })
    ).toEqual([
      {
        date: 'Nov 18, 2019',
        messages: [
          {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            showAvatar: false,
            message_type: 0,
          },
          {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 0,
          },
          {
            id: 3,
            content: 'Hey',
            created_at: 1574092218,
            showAvatar: true,
            message_type: 1,
          },
        ],
      },
      {
        date: 'Dec 14, 2019',
        messages: [
          {
            id: 4,
            content: 'Hey',
            created_at: 1576340623,
            showAvatar: true,
          },
          {
            id: 5,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },
            showAvatar: false,
          },
          {
            id: 6,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            showAvatar: true,
          },
          {
            id: 7,
            content: 'How may I help you',
            created_at: 1576340626,
            message_type: 2,
            content_type: 'form',
            content_attributes: {
              submitted_values: [{ name: 'text', value: 'sample text' }],
            },

            showAvatar: false,
          },
        ],
      },
    ]);
  });

  describe('getUnreadMessageCount returns', () => {
    it('0 if there are no messages and last seen is undefined', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: undefined,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });

    it('0 if there are no messages and last seen is present', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: Date.now(),
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });

    it('unread count if there are messages and last seen is before messages created-at', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 1,
          },
        },
        meta: {
          userLastSeenAt: 1474075964,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(2);
    });

    it('unread count if there are messages and last seen is after messages created-at', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
          2: {
            id: 2,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 1,
          },
          3: {
            id: 3,
            content: 'Yes, It makes sense',
            created_at: 1574092218,
            message_type: 0,
          },
        },
        meta: {
          userLastSeenAt: 1674075964,
        },
      };
      expect(getters.getUnreadMessageCount(state)).toEqual(0);
    });
  });

  describe('getUnreadTextMessages returns', () => {
    it('no messages if there are no messages and last seen is undefined', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: undefined,
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 0 })
      ).toEqual([]);
    });

    it('0 if there are no messages and last seen is present', () => {
      const state = {
        conversations: {},
        meta: {
          userLastSeenAt: Date.now(),
        },
      };
      expect(
        getters.getUnreadTextMessages(state, { getUnreadMessageCount: 0 })
      ).toEqual([]);
    });

    it('one card for a reply split into bubbles, previewing its question', () => {
      const reply = { captain_reply_id: 'r1' };
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Which battery?',
            created_at: 10,
            message_type: 0,
          },
          2: {
            id: 2,
            content: 'The X2 takes the 5000 mAh pack.',
            created_at: 11,
            message_type: 1,
            additional_attributes: reply,
          },
          3: {
            id: 3,
            content: 'X2 Battery',
            content_type: 'cards',
            created_at: 12,
            message_type: 1,
            additional_attributes: reply,
          },
          4: {
            id: 4,
            content: 'Need add-on modules too?',
            created_at: 13,
            message_type: 1,
            additional_attributes: {
              ...reply,
              captain_segment_kinds: ['question'],
            },
          },
          5: {
            id: 5,
            content: '',
            content_type: 'input_select',
            content_attributes: {
              items: [
                { title: 'Batteries' },
                { title: 'Modules' },
                { title: 'Both' },
              ],
            },
            created_at: 14,
            message_type: 1,
            additional_attributes: reply,
          },
        },
        meta: { userLastSeenAt: 10 },
      };

      const [card, ...rest] = getters.getUnreadTextMessages(state);

      expect(rest).toEqual([]);
      expect(card).toMatchObject({
        id: 4,
        content: 'Need add-on modules too?',
        previewKey: 'undefined:r1',
        choiceMessageId: 5,
        suggestedResponses: [
          { title: 'Batteries' },
          { title: 'Modules' },
          { title: 'Both' },
        ],
      });
      expect(getters.getUnreadMessageCount(state)).toEqual(1);
    });

    it('nothing once the reply was seen', () => {
      const state = {
        conversations: {
          1: {
            id: 1,
            content: 'Thanks for the help',
            created_at: 1574075964,
            message_type: 1,
          },
        },
        meta: { userLastSeenAt: 1674075964 },
      };

      expect(getters.getUnreadTextMessages(state)).toEqual([]);
    });
  });

  it('getMessageCount', () => {
    const state = {
      conversations: {
        1: {
          content: 'hey, how are you?',
        },
      },
    };
    expect(getters.getMessageCount(state)).toEqual(1);
  });

  it('getLastMessage', () => {
    const state = {
      conversations: {
        1: {
          id: 1,
          content: 'Thanks for the help',
          created_at: 1574075964,
          message_type: 1,
        },
        2: {
          id: 2,
          content: 'Yes, It makes sense',
          created_at: 1574092218,
          message_type: 1,
        },
        3: {
          id: 3,
          content: 'Yes, It makes sense',
          created_at: 1574092218,
          message_type: 0,
        },
      },
      meta: {
        userLastSeenAt: 1674075964,
      },
    };
    expect(getters.getLastMessage(state).id).toEqual(3);
  });
});
