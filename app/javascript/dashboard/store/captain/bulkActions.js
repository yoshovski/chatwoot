import CaptainBulkActionsAPI from 'dashboard/api/captain/bulkActions';
import { createStore } from '../storeFactory';
import { throwErrorMessage } from 'dashboard/store/utils/api';

// `target` is either { ids } or { select_all: true, filters } for "all matching".
export default createStore({
  name: 'CaptainBulkAction',
  API: CaptainBulkActionsAPI,
  actions: mutations => ({
    processBulkAction: async function processBulkAction(
      { commit },
      { type, actionType, target }
    ) {
      commit(mutations.SET_UI_FLAG, { isUpdating: true });
      try {
        const response = await CaptainBulkActionsAPI.create({
          type,
          ...target,
          fields: { status: actionType },
        });
        return response.data;
      } catch (error) {
        return throwErrorMessage(error);
      } finally {
        commit(mutations.SET_UI_FLAG, { isUpdating: false });
      }
    },

    handleBulkDelete: async function handleBulkDelete(
      { dispatch },
      { type = 'AssistantResponse', target }
    ) {
      const response = await dispatch('processBulkAction', {
        type,
        actionType: 'delete',
        target,
      });
      if (!target.ids) return response;

      if (type === 'AssistantResponse') {
        await dispatch('captainResponses/removeBulkResponses', target.ids, {
          root: true,
        });
      } else if (type === 'AssistantDocument') {
        await dispatch('captainDocuments/removeBulkRecords', target.ids, {
          root: true,
        });
      }
      return response;
    },

    handleBulkSync: async function handleBulkSync({ dispatch }, { target }) {
      const response = await dispatch('processBulkAction', {
        type: 'AssistantDocument',
        actionType: 'sync',
        target,
      });

      await dispatch('captainDocuments/markSyncing', response.ids || [], {
        root: true,
      });
      return response;
    },

    setEnabled: async function setEnabled(
      { dispatch },
      { type, target, enabled }
    ) {
      return dispatch('processBulkAction', {
        type,
        actionType: enabled ? 'enable' : 'disable',
        target,
      });
    },
  }),
});
