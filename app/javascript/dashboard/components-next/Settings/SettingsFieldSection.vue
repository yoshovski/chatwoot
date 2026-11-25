<script setup>
defineProps({
  stacked: { type: Boolean, default: false },
  label: {
    type: String,
    required: true,
  },
  helpText: {
    type: String,
    default: '',
  },
});
</script>

<template>
  <div
    class="w-full min-w-0 [interpolate-size:allow-keywords]"
    :class="{ 'py-2 mb-2': !stacked }"
  >
    <div
      class="grid grid-cols-1 gap-1.5 items-start"
      :class="{ 'lg:grid-cols-8 lg:gap-4 lg:items-center': !stacked }"
    >
      <label
        class="text-heading-3 text-n-slate-12 col-span-1"
        :class="{ 'lg:col-span-2': !stacked }"
      >
        {{ label }}
      </label>
      <div class="col-span-1 min-w-0" :class="{ 'lg:col-span-6': !stacked }">
        <slot />
      </div>
    </div>
    <div
      v-if="helpText"
      class="grid grid-cols-1"
      :class="{ 'lg:grid-cols-8': !stacked }"
    >
      <div v-if="!stacked" class="col-span-1 lg:col-span-2 invisible" />
      <p
        class="mt-1.5 col-span-1 text-label-small text-n-slate-11"
        :class="{ 'lg:col-span-6 ltr:ml-1 rtl:mr-1': !stacked }"
      >
        {{ helpText }}
      </p>
    </div>
    <slot name="extra" />
  </div>
</template>
