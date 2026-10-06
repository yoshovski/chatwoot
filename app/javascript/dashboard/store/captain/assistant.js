import CaptainAssistantAPI from 'dashboard/api/captain/assistant';
import { createStore } from '../storeFactory';

export default createStore({
  name: 'CaptainAssistant',
  API: CaptainAssistantAPI,
  actions: mutationTypes => ({
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
