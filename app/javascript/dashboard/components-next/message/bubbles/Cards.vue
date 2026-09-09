<script setup>
import { computed } from 'vue';
import BaseBubble from './Base.vue';
import { useMessageContext } from '../provider.js';

const { contentAttributes } = useMessageContext();

const items = computed(() => contentAttributes.value?.items ?? []);

// A postback button does something inside the visitor's widget, so there is nothing for an agent
// to follow. It is still drawn, because what matters here is seeing what the visitor was offered.
const isLink = action => action.type === 'link' && !!action.uri;
</script>

<template>
  <BaseBubble class="p-3" data-bubble-name="cards">
    <div class="flex items-stretch gap-2 pb-1 overflow-x-auto">
      <div
        v-for="item in items"
        :key="item.title"
        class="flex flex-col overflow-hidden rounded-lg w-44 shrink-0 bg-n-background"
      >
        <img
          v-if="item.mediaUrl"
          :src="item.mediaUrl"
          alt=""
          class="object-cover w-full h-24"
        />
        <div class="flex flex-col flex-1 gap-1 p-2">
          <span class="font-medium text-n-slate-12">{{ item.title }}</span>
          <span v-if="item.description" class="line-clamp-3 text-n-slate-11">
            {{ item.description }}
          </span>
          <div class="flex flex-col gap-1 pt-1 mt-auto">
            <template
              v-for="action in item.actions ?? []"
              :key="action.uri ?? action.text"
            >
              <a
                v-if="isLink(action)"
                :href="action.uri"
                target="_blank"
                rel="noopener noreferrer"
                class="px-2 py-1 text-center rounded-md text-n-slate-12 bg-n-alpha-2 hover:bg-n-alpha-3"
              >
                {{ action.text }}
              </a>
              <span
                v-else
                class="px-2 py-1 text-center rounded-md text-n-slate-11 bg-n-alpha-1"
              >
                {{ action.text }}
              </span>
            </template>
          </div>
        </div>
      </div>
    </div>
  </BaseBubble>
</template>
