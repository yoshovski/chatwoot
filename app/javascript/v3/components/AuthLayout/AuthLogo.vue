<script setup>
import { computed } from 'vue';
import { useStore } from 'vuex';

// The installation logo; `onBrand` uses the dark-mode logo, for the blue gradient band.
defineProps({ onBrand: { type: Boolean, default: false } });

const store = useStore();
const globalConfig = computed(() => store.getters['globalConfig/get']);
</script>

<template>
  <div>
    <img
      v-if="onBrand && globalConfig.logoDark"
      :src="globalConfig.logoDark"
      :alt="globalConfig.installationName"
      class="block h-7 w-auto"
    />
    <template v-else>
      <img
        :src="globalConfig.logo"
        :alt="globalConfig.installationName"
        class="block h-7 w-auto dark:hidden"
      />
      <img
        v-if="globalConfig.logoDark"
        :src="globalConfig.logoDark"
        :alt="globalConfig.installationName"
        class="hidden h-7 w-auto dark:block"
      />
    </template>
  </div>
</template>
