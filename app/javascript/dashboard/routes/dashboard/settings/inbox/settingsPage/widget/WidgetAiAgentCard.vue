<script setup>
import Avatar from 'next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';

// The AI agent's behaviour is fixed by the product and tuned on its own pages, not on the inbox.
defineProps({
  assistant: { type: Object, required: true },
});
</script>

<template>
  <section
    class="flex flex-wrap items-center gap-4 rounded-xl bg-n-solid-1 p-5 outline outline-1 -outline-offset-1 outline-n-weak"
  >
    <Avatar
      :src="assistant.avatar_url"
      :name="assistant.name"
      :size="40"
      rounded-full
    />
    <div class="flex flex-col flex-1 min-w-0 gap-1">
      <h3 class="mb-0 flex flex-wrap gap-x-2 text-heading-2 text-n-slate-12">
        {{ $t('INBOX_MGMT.WIDGET_SETTINGS.AI_AGENT.TITLE') }}
        <span class="text-n-slate-11">{{ assistant.name }}</span>
      </h3>
      <p class="mb-0 text-body-main text-n-slate-11">
        {{ $t('INBOX_MGMT.WIDGET_SETTINGS.AI_AGENT.DESCRIPTION') }}
      </p>
    </div>
    <router-link
      :to="{
        name: 'captain_assistants_guidelines_index',
        params: { assistantId: assistant.id },
      }"
    >
      <Button
        :label="$t('INBOX_MGMT.WIDGET_SETTINGS.AI_AGENT.LINK')"
        icon="i-lucide-scan-text"
        size="sm"
        variant="faded"
        color="slate"
      />
    </router-link>
  </section>
</template>
