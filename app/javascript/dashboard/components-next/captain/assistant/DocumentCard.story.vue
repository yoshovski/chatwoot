<script setup>
import DocumentCard from './DocumentCard.vue';
import { documentsList } from 'dashboard/components-next/captain/pageComponents/emptyStates/captainEmptyStateContent.js';
</script>

<template>
  <Story
    title="Captain/Assistant/DocumentCard"
    :layout="{ type: 'grid', width: '700px' }"
  >
    <Variant title="Document Card">
      <div
        v-for="(doc, index) in documentsList"
        :key="index"
        class="px-20 py-4 bg-n-background"
      >
        <DocumentCard
          :id="doc.id"
          :name="doc.name"
          :external-link="doc.external_link"
          :assistant="doc.assistant"
          :created-at="doc.created_at"
        />
      </div>
    </Variant>
    <Variant title="Dify knowledge index">
      <div
        v-for="state in ['searchable', 'indexing', 'not_searchable', 'paused']"
        :key="state"
        class="px-20 py-4 bg-n-background"
      >
        <DocumentCard
          :id="documentsList[0].id"
          :name="documentsList[0].name"
          :external-link="documentsList[0].external_link"
          :assistant="documentsList[0].assistant"
          :created-at="documentsList[0].created_at"
          :knowledge-state="state"
          :responses-count="state === 'searchable' ? 3 : 0"
        />
      </div>
    </Variant>
  </Story>
</template>
