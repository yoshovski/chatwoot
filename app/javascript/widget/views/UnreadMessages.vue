<script>
import { mapGetters } from 'vuex';
import { emitter } from 'shared/helpers/mitt';
import UnreadMessageList from '../components/UnreadMessageList.vue';

export default {
  name: 'UnreadMessages',
  components: {
    UnreadMessageList,
  },
  computed: {
    ...mapGetters({
      messages: 'conversation/getUnreadTextMessages',
    }),
  },
  methods: {
    closeFullView() {
      emitter.emit('hide-preview-card');
    },
  },
};
</script>

<template>
  <UnreadMessageList :messages="messages" @close="closeFullView" />
</template>
