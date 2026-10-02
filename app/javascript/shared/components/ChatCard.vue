<script>
import CardButton from 'shared/components/CardButton.vue';

export default {
  components: {
    CardButton,
  },
  props: {
    title: {
      type: String,
      default: '',
    },
    description: {
      type: String,
      default: '',
    },
    mediaUrl: {
      type: String,
      default: '',
    },
    actions: {
      type: Array,
      default: () => [],
    },
  },
};
</script>

<template>
  <div
    class="card-message chat-bubble agent bg-n-background dark:bg-n-solid-3 w-56 shrink-0 snap-start flex flex-col rounded-lg overflow-hidden"
  >
    <img
      v-if="mediaUrl"
      class="w-full object-cover h-[130px] rounded-[5px]"
      :src="mediaUrl"
    />
    <div class="card-body flex flex-col flex-1">
      <h4
        class="!text-base !font-medium !mt-1 !mb-1 !leading-[1.5] text-n-slate-12"
      >
        {{ title }}
      </h4>
      <p class="!mb-1 line-clamp-3 text-n-slate-11">
        {{ description }}
      </p>
      <!-- Pinned to the bottom so the actions line up across cards of unequal text length. -->
      <div class="mt-auto pt-1">
        <CardButton
          v-for="action in actions"
          :key="action.id"
          :action="action"
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="scss">
.card-message {
  // .chat-bubble carries no padding of its own in the widget bundle, so the card sets its own
  // rather than depending on an ambient rule.
  .card-body {
    @apply px-3 pb-3 pt-1;
  }
}
</style>
