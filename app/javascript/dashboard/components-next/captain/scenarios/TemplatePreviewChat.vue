<script setup>
import { ref, computed, onMounted, onBeforeUnmount, watch } from 'vue';

const props = defineProps({
  demo: {
    type: Array,
    required: true,
  },
  isPlaying: {
    type: Boolean,
    default: true,
  },
});

const step = ref(0);
let timer = null;

const checkReducedMotion = () => {
  return (
    typeof window !== 'undefined' &&
    window.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches
  );
};

const prefersReducedMotion = ref(checkReducedMotion());

const visibleMessages = computed(() => {
  if (prefersReducedMotion.value) {
    return props.demo.filter(m => m.role !== 'typing');
  }
  return props.demo.slice(0, step.value + 1);
});

const advanceStep = () => {
  if (step.value >= props.demo.length - 1) {
    // Reset after showing full chat
    setTimeout(() => {
      step.value = 0;
    }, 2500);
  } else {
    step.value += 1;
  }
};

const stopPlayback = () => {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
};

const startPlayback = () => {
  if (prefersReducedMotion.value || !props.isPlaying) return;
  stopPlayback();
  timer = setInterval(advanceStep, 1800);
};

watch(
  () => props.isPlaying,
  playing => {
    if (playing) startPlayback();
    else stopPlayback();
  }
);

onMounted(() => {
  startPlayback();
});

onBeforeUnmount(() => {
  stopPlayback();
});
</script>

<template>
  <div
    class="flex flex-col gap-2 p-3 rounded-xl bg-n-alpha-1 border border-n-weak/50 h-[17rem] overflow-y-auto text-xs select-none"
  >
    <div
      v-for="(msg, idx) in visibleMessages"
      :key="idx"
      class="flex flex-col gap-1.5 transition-all duration-300"
    >
      <!-- Customer message -->
      <div
        v-if="msg.role === 'customer'"
        class="self-end max-w-[85%] bg-n-brand text-white rounded-2xl rounded-br-sm px-3 py-2 leading-relaxed shadow-sm"
      >
        {{ msg.text }}
      </div>

      <!-- Typing indicator -->
      <div
        v-else-if="msg.role === 'typing'"
        class="self-start flex items-center gap-1 px-3 py-2 rounded-2xl rounded-bl-sm bg-n-alpha-2 border border-n-weak/40 w-fit"
      >
        <span
          class="size-1.5 rounded-full bg-n-slate-9 motion-safe:animate-bounce"
        />
        <span
          class="size-1.5 rounded-full bg-n-slate-9 motion-safe:animate-bounce [animation-delay:0.15s]"
        />
        <span
          class="size-1.5 rounded-full bg-n-slate-9 motion-safe:animate-bounce [animation-delay:0.3s]"
        />
      </div>

      <!-- Assistant message -->
      <div
        v-else-if="msg.role === 'assistant'"
        class="self-start max-w-[85%] flex flex-col gap-2"
      >
        <div
          v-if="msg.text"
          class="bg-n-alpha-2 text-n-slate-12 rounded-2xl rounded-bl-sm px-3 py-2 leading-relaxed border border-n-weak/40"
        >
          {{ msg.text }}
        </div>

        <!-- Product Card mock -->
        <div
          v-if="msg.productCard"
          class="p-2.5 rounded-xl border border-n-weak bg-n-alpha-black2 flex flex-col gap-1 text-xs"
        >
          <div class="flex items-center justify-between">
            <span class="font-medium text-n-slate-12">
              {{ msg.productCard.title }}
            </span>
            <span class="font-semibold text-n-teal-11">
              {{ msg.productCard.price }}
            </span>
          </div>
          <span class="text-[11px] text-n-slate-10">
            {{ msg.productCard.feature }}
          </span>
        </div>

        <!-- Buttons mock -->
        <div v-if="msg.buttons" class="flex gap-1.5 flex-wrap">
          <span
            v-for="btn in msg.buttons"
            :key="btn"
            class="px-2.5 py-1 rounded-full border border-n-brand text-n-brand bg-n-brand/5 text-[11px] font-medium"
          >
            {{ btn }}
          </span>
        </div>

        <!-- Private note action mock -->
        <div
          v-if="msg.action"
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-n-amber-3 text-n-amber-11 border border-n-amber-4 text-[11px] font-medium"
        >
          <span aria-hidden="true">{{ '📝' }}</span>
          <span class="truncate">{{ msg.action.text }}</span>
        </div>

        <!-- Handoff pill mock -->
        <div
          v-if="msg.handoff"
          class="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-n-iris-3 text-n-iris-11 border border-n-iris-4 text-[11px] font-medium"
        >
          <span aria-hidden="true">{{ '🙋' }}</span>
          <span class="truncate">{{ msg.handoff }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
