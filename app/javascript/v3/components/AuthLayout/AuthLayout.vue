<script setup>
import AuthLogo from './AuthLogo.vue';
import WidgetPreview from './WidgetPreview.vue';

// Every sign-up and log-in screen: the logo, title and form on the left; on wide screens a Bright panel with a copy
// of the chat widget on the right. The sign-up screen adds a heading to the panel.
defineProps({
  title: { type: String, default: '' },
  description: { type: String, default: '' },
  panelTitle: { type: String, default: '' },
  panelDescription: { type: String, default: '' },
});
</script>

<template>
  <div class="grid min-h-screen w-full bg-n-solid-1 lg:grid-cols-2">
    <main class="flex items-center justify-center px-4 py-10 sm:px-12">
      <div class="w-full max-w-[26rem]">
        <AuthLogo />
        <div v-if="title" class="mt-10 flex flex-col items-start gap-3">
          <slot name="beforeTitle" />
          <h1
            class="mb-0 font-display text-3xl font-semibold tracking-display text-n-slate-12"
          >
            {{ title }}
          </h1>
          <p v-if="description" class="mb-0 text-sm text-n-slate-11">
            {{ description }}
          </p>
        </div>
        <div class="mt-8">
          <slot />
        </div>
      </div>
    </main>
    <aside
      class="hidden items-center justify-center bg-[image:var(--co-hero-bg)] p-12 lg:flex"
    >
      <div class="flex w-full max-w-[22.5rem] flex-col gap-8">
        <div v-if="panelTitle" class="text-center">
          <h2
            class="mb-0 font-display text-2xl font-semibold tracking-display text-white"
          >
            {{ panelTitle }}
          </h2>
          <p class="mt-2 mb-0 text-sm text-white/85">
            {{ panelDescription }}
          </p>
        </div>
        <WidgetPreview />
      </div>
    </aside>
  </div>
</template>
