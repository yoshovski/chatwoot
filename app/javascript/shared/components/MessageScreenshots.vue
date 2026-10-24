<script setup>
defineProps({ screenshots: { type: Array, default: () => [] } });
</script>

<!-- eslint-disable-next-line vue/no-root-v-if -->
<template>
  <div v-if="screenshots.length" class="mt-3 flex flex-col gap-3">
    <figure v-for="image in screenshots" :key="image.url" class="m-0">
      <a :href="image.url" target="_blank" rel="noopener noreferrer nofollow">
        <img
          :src="image.url"
          :alt="image.caption"
          loading="lazy"
          referrerpolicy="no-referrer"
          class="h-auto max-h-80 w-full rounded-xl border border-solid border-n-weak object-contain"
        />
      </a>
      <figcaption class="mt-1 text-xs text-n-slate-11">
        {{ image.caption }}
      </figcaption>
    </figure>
  </div>
</template>
