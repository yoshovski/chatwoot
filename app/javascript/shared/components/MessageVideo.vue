<script setup>
import { ref } from 'vue';

// A video from an AI agent answer. Nothing loads from the video host until the customer presses play.
defineProps({
  video: { type: Object, required: true },
  playLabel: { type: String, required: true },
});

const playing = ref(false);
</script>

<template>
  <div
    class="relative w-full mt-3 overflow-hidden rounded-xl aspect-video bg-n-slate-12"
  >
    <video
      v-if="playing && video.provider === 'file'"
      :src="video.embedUrl"
      class="absolute inset-0 size-full"
      controls
      autoplay
    />
    <iframe
      v-else-if="playing"
      :src="video.embedUrl"
      :title="video.label"
      class="absolute inset-0 border-0 size-full"
      allow="autoplay; fullscreen; picture-in-picture"
      allowfullscreen
      referrerpolicy="strict-origin-when-cross-origin"
    />
    <button
      v-else
      type="button"
      class="absolute inset-0 flex flex-col items-center justify-center gap-2 p-4 text-white group size-full"
      :aria-label="`${playLabel}: ${video.label}`"
      @click="playing = true"
    >
      <img
        v-if="video.thumbnail"
        :src="video.thumbnail"
        alt=""
        class="absolute inset-0 object-cover size-full opacity-80"
      />
      <span
        class="relative flex items-center justify-center transition-transform rounded-full shadow-lg size-12 bg-white/90 text-n-slate-12 group-hover:scale-105"
      >
        <span class="i-lucide-play size-5 ms-0.5" aria-hidden="true" />
      </span>
      <span
        class="relative max-w-full text-sm font-medium truncate drop-shadow"
      >
        {{ video.label }}
      </span>
    </button>
  </div>
</template>
