import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CaptainAssistant',
  API: CaptainAssistantAPI,
  actions: mutationTypes => ({
    refreshMessageTranslations: async ({ commit, getters }, id) => {
      const { data } = await CaptainAssistantAPI.show(id);
      commit(mutationTypes.EDIT, {
        ...getters.getRecord(data.id),
        id: data.id,
        generated_message_translations: data.generated_message_translations,
        pending_message_translations: data.pending_message_translations,
      });
    },
    deleteAvatar: async ({ commit }, id) => {
      commit(mutationTypes.SET_UI_FLAG, { updatingItem: true });
      try {
        const response = await CaptainAssistantAPI.deleteAvatar(id);
        commit(mutationTypes.EDIT, response.data);
        return response.data;
      } finally {
        commit(mutationTypes.SET_UI_FLAG, { updatingItem: false });
      }
    },
  }),
});
