<script setup>
import { ref, nextTick, onMounted } from 'vue';
import ChatCard from 'shared/components/ChatCard.vue';

defineProps({
  items: {
    type: Array,
    default: () => [],
  },
});

const CARD_GAP = 8;

const rail = ref(null);
const atStart = ref(true);
const atEnd = ref(true);

const syncEdges = () => {
  const el = rail.value;
  if (!el) return;

  // A pixel of slack: fractional widths otherwise leave an arrow showing with nowhere to go.
  atStart.value = el.scrollLeft <= 1;
  atEnd.value = el.scrollLeft + el.clientWidth >= el.scrollWidth - 1;
};

const scrollCards = direction => {
  const el = rail.value;
  if (!el) return;

  const card = el.firstElementChild;
  const step = card ? card.offsetWidth + CARD_GAP : el.clientWidth;
  el.scrollBy({ left: direction * step, behavior: 'smooth' });
};

onMounted(() => nextTick(syncEdges));
</script>

<template>
  <div class="relative">
    <div
      ref="rail"
      class="card-rail flex items-stretch gap-2 overflow-x-auto snap-x snap-mandatory pb-1"
      @scroll.passive="syncEdges"
    >
      <ChatCard
        v-for="item in items"
        :key="item.title"
        :media-url="item.media_url"
        :title="item.title"
        :description="item.description"
        :actions="item.actions"
      />
    </div>
    <button
      v-if="!atStart"
      type="button"
      class="card-nav ltr:left-1 rtl:right-1"
      :aria-label="$t('COMPONENTS.CARD_CAROUSEL.PREVIOUS')"
      @click="scrollCards(-1)"
    >
      <i class="i-lucide-chevron-left size-4" />
    </button>
    <button
      v-if="!atEnd"
      type="button"
      class="card-nav ltr:right-1 rtl:left-1"
      :aria-label="$t('COMPONENTS.CARD_CAROUSEL.NEXT')"
      @click="scrollCards(1)"
    >
      <i class="i-lucide-chevron-right size-4" />
    </button>
  </div>
</template>

<style scoped lang="scss">
.card-rail {
  // The arrows are the affordance here, so the native bar only adds noise inside a bubble.
  scrollbar-width: none;

  &::-webkit-scrollbar {
    display: none;
  }
}

.card-nav {
  @apply absolute top-1/2 z-10 grid -translate-y-1/2 place-items-center size-7 rounded-full border border-solid border-n-weak bg-n-background text-n-slate-12 shadow-md cursor-pointer transition-colors;

  &:hover {
    @apply bg-n-slate-3 border-n-slate-8;
  }
}
</style>
