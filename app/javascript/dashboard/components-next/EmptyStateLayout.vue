<script setup>
import EmptyState from './kit/EmptyState.vue';
import Policy from 'dashboard/components/policy.vue';

defineProps({
  title: {
    type: String,
    required: true,
  },
  subtitle: {
    type: String,
    required: true,
  },
  actionPerms: {
    type: Array,
    default: () => [],
  },
  state: {
    type: String,
    default: '',
    validator: value =>
      ['', 'first-use', 'filtered', 'unavailable', 'error'].includes(value),
  },
  showBackdrop: {
    type: Boolean,
    default: true,
  },
});
</script>

<template>
  <EmptyState
    v-if="state"
    :state="state"
    :title="title"
    :description="subtitle"
  >
    <template v-if="$slots.actions" #default>
      <Policy :permissions="actionPerms">
        <slot name="actions" />
      </Policy>
    </template>
    <template v-if="$slots.secondary" #secondary>
      <Policy :permissions="actionPerms">
        <slot name="secondary" />
      </Policy>
    </template>
    <template v-if="$slots.decorative" #decorative>
      <slot name="decorative" />
    </template>
  </EmptyState>
  <section
    v-else
    class="relative flex flex-col items-center justify-center w-full h-full overflow-hidden"
  >
    <div
      class="relative w-full max-w-5xl mx-auto overflow-hidden h-full max-h-[28rem]"
    >
      <div
        v-if="showBackdrop"
        inert
        aria-hidden="true"
        class="w-full h-full space-y-4 overflow-y-hidden opacity-50 pointer-events-none"
      >
        <slot name="empty-state-item" />
      </div>
      <div
        class="flex flex-col items-center justify-end w-full h-full pb-20"
        :class="{
          'absolute inset-x-0 bottom-0 bg-gradient-to-t from-n-surface-1 from-25% to-transparent':
            showBackdrop,
        }"
      >
        <div
          class="flex flex-col items-center justify-center gap-6"
          :class="{
            'mt-48': !showBackdrop,
          }"
        >
          <div class="flex flex-col items-center justify-center gap-3">
            <h2 class="text-3xl font-medium text-center text-n-slate-12">
              {{ title }}
            </h2>
            <p
              v-if="subtitle"
              class="max-w-xl text-base text-center text-n-slate-11 tracking-[0.3px]"
            >
              {{ subtitle }}
            </p>
          </div>
          <Policy :permissions="actionPerms">
            <slot name="actions" />
          </Policy>
        </div>
      </div>
    </div>
  </section>
</template>
