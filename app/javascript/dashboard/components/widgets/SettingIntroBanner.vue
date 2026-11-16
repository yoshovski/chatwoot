<script setup>
defineProps({
  headerTitle: {
    type: String,
    default: '',
  },
  headerIdentifier: {
    type: String,
    default: '',
  },
  headerContent: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div class="border-b border-solid border-n-weak/60">
    <div class="w-full pt-2 pb-0 px-0">
      <h2 class="text-2xl text-n-slate-12 mb-1 font-medium min-w-0">
        <span :title="headerTitle" class="block truncate">
          {{ headerTitle }}
        </span>
      </h2>
      <p
        v-if="headerIdentifier"
        :title="headerIdentifier"
        class="w-full truncate text-n-slate-9 text-sm mb-2"
      >
        <bdi dir="auto">{{ headerIdentifier }}</bdi>
      </p>
      <p v-if="headerContent" class="w-full text-n-slate-11 text-sm mb-2">
        {{ headerContent }}
      </p>
      <slot />
    </div>
  </div>
</template>
