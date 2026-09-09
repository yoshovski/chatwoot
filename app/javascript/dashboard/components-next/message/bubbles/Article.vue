<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';

const { contentAttributes } = useMessageContext();

const items = computed(() => contentAttributes.value?.items ?? []);
</script>

<template>
  <BaseBubble class="px-4 py-3" data-bubble-name="article">
    <ul class="flex flex-col gap-3 m-0 list-none">
      <li v-for="item in items" :key="item.title" class="flex flex-col gap-0.5">
        <a
          v-if="item.link"
          :href="item.link"
          target="_blank"
          rel="noopener noreferrer"
          class="font-medium underline text-n-slate-12 decoration-n-slate-8 underline-offset-2"
        >
          {{ item.title }}
        </a>
        <span v-else class="font-medium text-n-slate-12">{{ item.title }}</span>
        <span v-if="item.description" class="text-n-slate-11">
          {{ item.description }}
        </span>
      </li>
    </ul>
  </BaseBubble>
</template>
