<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import ToolPalette from './ToolPalette.vue';
import {
  groupTools,
  toolGroupLabel,
  needsFixedParams,
  parseToolReference,
} from './builtInActions';

const props = defineProps({
  modelValue: { type: String, default: '' },
  tools: { type: Array, default: null },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  message: { type: String, default: '' },
  messageType: {
    type: String,
    default: 'info',
    validator: value => ['info', 'error', 'success'].includes(value),
  },
  showToolPalette: { type: Boolean, default: true },
  disabled: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue', 'focus', 'blur']);

const { t } = useI18n();
const storeCaptainTools = useMapGetter('captainTools/getRecords');

const DRAG_TYPE = 'text/x-chatoctave-scenario-tool';
const TOKEN = /\[@?([^\]]*)\]\(tool:\/\/([^)]+)\)/g;
const MENU_LIMIT = 12;
// Zero-width space placed after each chip so the cursor can sit to its right.
const ANCHOR = '\u200B';
const CHIP_CLASS =
  'inline-flex items-center gap-1 px-2 py-0.5 mx-0.5 rounded-full text-xs font-medium align-middle bg-n-iris-3 text-n-iris-11 border border-n-iris-4 select-none cursor-grab hover:bg-n-iris-4 transition-colors';

const el = ref(null);
const toolPaletteRef = ref(null);
const isFocused = ref(false);
let lastEmitted = null;
let savedRange = null;
let dragSource = null;
let pendingAtRange = null;

const availableTools = computed(() => {
  return props.tools || storeCaptainTools.value || [];
});

const escapeHtml = text =>
  String(text || '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const findTool = refId => {
  const { id } = parseToolReference(refId);
  return availableTools.value.find(tool => tool.id === id);
};

const titleFor = (refId, explicitTitle) => {
  if (explicitTitle) return explicitTitle.replace(/^@/, '');
  const tool = findTool(refId);
  if (tool?.title) return tool.title;
  const { id } = parseToolReference(refId);
  return id;
};

const emojiFor = refId => {
  return findTool(refId)?.emoji || '';
};

const chipNode = (refId, explicitTitle) => {
  const span = document.createElement('span');
  span.dataset.tool = refId;
  const title = titleFor(refId, explicitTitle);
  span.dataset.title = title;
  span.contentEditable = 'false';
  span.draggable = true;
  span.className = CHIP_CLASS;

  const emoji = emojiFor(refId);
  if (emoji) {
    const emSpan = document.createElement('span');
    emSpan.className = 'tool-emoji leading-none text-xs';
    emSpan.textContent = emoji;
    span.appendChild(emSpan);
  }

  const titleSpan = document.createElement('span');
  titleSpan.className = 'tool-title';
  titleSpan.textContent = title;
  span.appendChild(titleSpan);

  return span;
};

const toHtml = markdown =>
  escapeHtml(markdown)
    .replace(TOKEN, (match, title, refId) => {
      const toolRef = escapeHtml(refId);
      const toolTitle = escapeHtml(titleFor(refId, title));
      const emoji = emojiFor(refId);
      const emojiHtml = emoji
        ? `<span class="tool-emoji leading-none text-xs">${escapeHtml(emoji)}</span>`
        : '';
      return `<span data-tool="${toolRef}" data-title="${toolTitle}" contenteditable="false" draggable="true" class="${CHIP_CLASS}">${emojiHtml}<span class="tool-title">${toolTitle}</span></span>${ANCHOR}`;
    })
    .replace(/\n/g, '<br>');

const serialize = node =>
  Array.from(node.childNodes)
    .map((child, index) => {
      if (child.nodeType === Node.TEXT_NODE) {
        return child.nodeValue.replace(/\u00a0/g, ' ').replace(/\u200B/g, '');
      }
      if (child.dataset?.tool) {
        const refId = child.dataset.tool.replace(/^tool:\/\//, '');
        const title = child.dataset.title || titleFor(refId);
        return `[@${title}](tool://${refId})`;
      }
      if (child.nodeName === 'BR') {
        return index === node.childNodes.length - 1 ? '' : '\n';
      }
      const inner = serialize(child);
      return ['DIV', 'P'].includes(child.nodeName) && index > 0
        ? `\n${inner}`
        : inner;
    })
    .join('');

const render = () => {
  if (!el.value) return;
  el.value.innerHTML = toHtml(props.modelValue);
};

const update = () => {
  if (!el.value) return;
  lastEmitted = serialize(el.value);
  emit('update:modelValue', lastEmitted);
};

watch(
  () => props.modelValue,
  value => {
    if (value !== lastEmitted) render();
  }
);
watch(availableTools, render);
onMounted(render);

const saveRange = () => {
  const selection = window.getSelection();
  if (selection.rangeCount && el.value?.contains(selection.anchorNode)) {
    savedRange = selection.getRangeAt(0).cloneRange();
  }
};

const placeCaretAfter = node => {
  const range = document.createRange();
  range.setStartAfter(node);
  range.collapse(true);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  savedRange = range.cloneRange();
};

const insertAt = (range, refId, title) => {
  range.deleteContents();
  const chip = chipNode(refId, title);
  const space = document.createTextNode(`${ANCHOR} `);
  range.insertNode(space);
  range.insertNode(chip);
  placeCaretAfter(space);
  update();
};

const isAnchorOnly = node =>
  node?.nodeType === Node.TEXT_NODE && !node.nodeValue.replace(/\u200B/g, '');

const chipNextToCaret = direction => {
  const selection = window.getSelection();
  if (!selection.rangeCount || !selection.isCollapsed) return null;
  const { startContainer: container, startOffset: offset } =
    selection.getRangeAt(0);
  let node;
  if (container.nodeType === Node.TEXT_NODE) {
    const side =
      direction === 'before'
        ? container.nodeValue.slice(0, offset)
        : container.nodeValue.slice(offset);
    if (side.replace(/\u200B/g, '')) return null;
    node =
      direction === 'before'
        ? container.previousSibling
        : container.nextSibling;
  } else {
    node =
      direction === 'before'
        ? container.childNodes[offset - 1]
        : container.childNodes[offset];
  }
  while (isAnchorOnly(node)) {
    node = direction === 'before' ? node.previousSibling : node.nextSibling;
  }
  return node?.dataset?.tool ? node : null;
};

const removeChip = chip => {
  const after = chip.nextSibling;
  if (
    after?.nodeType === Node.TEXT_NODE &&
    after.nodeValue.startsWith(ANCHOR)
  ) {
    after.nodeValue = after.nodeValue.slice(1);
  }
  const range = document.createRange();
  range.setStartBefore(chip);
  range.collapse(true);
  chip.remove();
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  update();
};

const onClick = event => {
  const chip = event.target.closest?.('[data-tool]');
  if (!chip || !el.value.contains(chip)) return;
  const box = chip.getBoundingClientRect();
  const range = document.createRange();
  if (event.clientX > box.left + box.width / 2) {
    const after = chip.nextSibling;
    if (
      after?.nodeType === Node.TEXT_NODE &&
      after.nodeValue.startsWith(ANCHOR)
    ) {
      range.setStart(after, 1);
    } else {
      range.setStartAfter(chip);
    }
  } else {
    range.setStartBefore(chip);
  }
  range.collapse(true);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
  savedRange = range.cloneRange();
};

// @ autocomplete menu
const menu = ref(null);
const activeIndex = ref(0);

const menuItems = computed(() => {
  if (!menu.value) return [];
  const query = menu.value.query.trim().toLowerCase();
  const matches = availableTools.value.filter(tool => {
    if (!query) return true;
    return (
      tool.title?.toLowerCase().includes(query) ||
      tool.id?.toLowerCase().includes(query) ||
      tool.description?.toLowerCase().includes(query)
    );
  });
  const grouped = groupTools(matches, group => toolGroupLabel(group, t));
  return grouped.slice(0, MENU_LIMIT);
});

const closeMenu = () => {
  menu.value = null;
};

const checkMention = () => {
  const selection = window.getSelection();
  const node = selection.anchorNode;
  if (!selection.isCollapsed || node?.nodeType !== Node.TEXT_NODE) {
    closeMenu();
    return;
  }
  const before = node.nodeValue.slice(0, selection.anchorOffset);
  const match = before.match(/(?:^|\s)@([^\s@]{0,24})$/);
  if (!match) {
    closeMenu();
    return;
  }
  const caret = selection.getRangeAt(0).getBoundingClientRect();
  const box = el.value.getBoundingClientRect();
  menu.value = {
    query: match[1],
    node,
    start: selection.anchorOffset - match[1].length - 1,
    end: selection.anchorOffset,
    top: caret.bottom - box.top + 6,
    left: Math.max(0, caret.left - box.left),
  };
  activeIndex.value = 0;
};

const pick = tool => {
  const { node, start, end } = menu.value;
  const range = document.createRange();
  range.setStart(node, start);
  range.setEnd(node, end);

  if (needsFixedParams(tool)) {
    pendingAtRange = range.cloneRange();
    closeMenu();
    toolPaletteRef.value?.configure(tool);
    return;
  }

  closeMenu();
  insertAt(range, tool.id, tool.title);
};

const onInput = () => {
  update();
  checkMention();
};

const onKeydown = event => {
  if (menu.value && menuItems.value.length) {
    if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
      event.preventDefault();
      const step = event.key === 'ArrowDown' ? 1 : -1;
      activeIndex.value =
        (activeIndex.value + step + menuItems.value.length) %
        menuItems.value.length;
      return;
    }
    if (event.key === 'Enter' || event.key === 'Tab') {
      event.preventDefault();
      pick(menuItems.value[activeIndex.value]);
      return;
    }
  }
  if (event.key === 'Backspace' || event.key === 'Delete') {
    const chip = chipNextToCaret(
      event.key === 'Backspace' ? 'before' : 'after'
    );
    if (chip) {
      event.preventDefault();
      removeChip(chip);
      return;
    }
  }
  if (event.key === 'Escape') closeMenu();
  if (event.key === 'Enter') {
    event.preventDefault();
    document.execCommand('insertLineBreak');
    update();
  }
};

const onPaste = event => {
  event.preventDefault();
  const text = event.clipboardData.getData('text/plain');
  document.execCommand('insertText', false, text);
};

// Drag and drop
const rangeFromPoint = (x, y) => {
  if (document.caretRangeFromPoint) return document.caretRangeFromPoint(x, y);
  const position = document.caretPositionFromPoint?.(x, y);
  if (!position) return null;
  const range = document.createRange();
  range.setStart(position.offsetNode, position.offset);
  return range;
};

const onDragStart = event => {
  const chip = event.target?.closest?.('[data-tool]');
  if (!chip) return;
  dragSource = chip;
  const payload = JSON.stringify({
    ref: chip.dataset.tool,
    title: chip.dataset.title,
  });
  event.dataTransfer.setData(DRAG_TYPE, payload);
  event.dataTransfer.effectAllowed = 'copyMove';
};

const isDragOver = ref(false);
const hasToolData = event =>
  Array.from(event.dataTransfer?.types || []).includes(DRAG_TYPE);

const onDragOver = event => {
  if (!hasToolData(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = dragSource ? 'move' : 'copy';
  isDragOver.value = true;
};

const onDragLeave = event => {
  if (!el.value.contains(event.relatedTarget)) isDragOver.value = false;
};

const onDrop = event => {
  isDragOver.value = false;
  const raw = event.dataTransfer.getData(DRAG_TYPE);
  if (!raw) return;
  event.preventDefault();
  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    data = { ref: raw, title: '' };
  }

  let range = rangeFromPoint(event.clientX, event.clientY);
  if (!range || !el.value.contains(range.startContainer)) {
    range = document.createRange();
    range.selectNodeContents(el.value);
    range.collapse(false);
  }

  const chip = range.startContainer.parentElement?.closest('[data-tool]');
  if (chip && el.value.contains(chip)) {
    range.setStartAfter(chip);
    range.collapse(true);
  }
  if (dragSource && el.value.contains(dragSource) && dragSource !== chip) {
    dragSource.remove();
  }
  dragSource = null;
  el.value.focus();
  insertAt(range, data.ref, data.title);
};

const onDragEnd = () => {
  dragSource = null;
  isDragOver.value = false;
};

// Insert from external tool palette
const insertTool = tool => {
  el.value?.focus();
  const range = pendingAtRange || savedRange || document.createRange();
  if (!pendingAtRange && !savedRange && el.value) {
    range.selectNodeContents(el.value);
    range.collapse(false);
  }
  pendingAtRange = null;
  const refId = (tool.id || '').replace(/^tool:\/\//, '');
  const title = tool.title || titleFor(refId);
  insertAt(range, refId, title);
};

const insertText = text => {
  el.value?.focus();
  const range = pendingAtRange || savedRange || document.createRange();
  if (!pendingAtRange && !savedRange && el.value) {
    range.selectNodeContents(el.value);
    range.collapse(false);
  }
  pendingAtRange = null;
  range.deleteContents();
  const textNode = document.createTextNode(text);
  range.insertNode(textNode);
  placeCaretAfter(textNode);
  update();
};

const onFocus = () => {
  if (props.disabled) return;
  isFocused.value = true;
  emit('focus');
};

const onBlur = () => {
  saveRange();
  isFocused.value = false;
  emit('blur');
  setTimeout(closeMenu, 150);
};

const messageClass = computed(() => {
  switch (props.messageType) {
    case 'error':
      return 'text-n-ruby-9 dark:text-n-ruby-9';
    case 'success':
      return 'text-n-teal-10 dark:text-n-teal-10';
    default:
      return 'text-n-slate-11 dark:text-n-slate-11';
  }
});

defineExpose({ insertTool, insertText });
nextTick(render);
</script>

<template>
  <div class="relative flex flex-col min-w-0 gap-1 w-full">
    <label v-if="label" class="mb-0.5 text-sm font-medium text-n-slate-12">
      {{ label }}
    </label>

    <ToolPalette
      v-if="showToolPalette"
      ref="toolPaletteRef"
      :tools="availableTools"
      class="mb-1"
      @insert-tool="insertTool"
      @insert-text="insertText"
    />

    <div class="relative w-full">
      <div
        ref="el"
        contenteditable="true"
        role="textbox"
        :aria-label="label"
        aria-multiline="true"
        data-test="scenario-instruction-editor"
        class="w-full px-3.5 py-2.5 text-sm break-words whitespace-pre-wrap border rounded-xl outline-none border-n-weak bg-n-alpha-black2 text-n-slate-12 min-h-48 max-h-96 overflow-y-auto leading-6 transition-colors duration-150"
        :class="[
          disabled ? 'cursor-not-allowed opacity-50 pointer-events-none' : '',
          isFocused ? '!border-n-brand ring-1 ring-n-brand/30' : '',
          !isFocused && messageType !== 'error' ? 'hover:border-n-slate-6' : '',
          messageType === 'error' && !isFocused
            ? '!border-n-ruby-8 hover:border-n-ruby-9'
            : '',
          isDragOver ? '!border-n-brand ring-2 ring-n-brand/40' : '',
        ]"
        @input="onInput"
        @keydown="onKeydown"
        @keyup="saveRange"
        @mouseup="saveRange"
        @click="onClick"
        @focus="onFocus"
        @blur="onBlur"
        @paste="onPaste"
        @dragstart="onDragStart"
        @dragend="onDragEnd"
        @dragenter="onDragOver"
        @dragover="onDragOver"
        @dragleave="onDragLeave"
        @drop="onDrop"
      />

      <span
        v-if="!modelValue && placeholder"
        class="absolute pointer-events-none top-2.5 start-3.5 text-sm text-n-slate-10 select-none"
      >
        {{ placeholder }}
      </span>

      <!-- Autocomplete popup for @ -->
      <ul
        v-if="menu && menuItems.length"
        class="absolute z-50 flex flex-col w-72 p-1.5 m-0 overflow-y-auto list-none border shadow-xl max-h-72 rounded-xl border-n-weak bg-n-solid-2 backdrop-blur-md"
        :style="{ top: `${menu.top}px`, left: `${menu.left}px` }"
        role="listbox"
      >
        <template v-for="(item, index) in menuItems" :key="item.id || index">
          <li
            v-if="item.groupLabel"
            class="px-2.5 pt-2 pb-1 text-[11px] font-semibold uppercase tracking-wider text-n-slate-10 select-none"
            role="presentation"
          >
            {{ item.groupLabel }}
          </li>
          <li
            role="option"
            :aria-selected="index === activeIndex"
            class="flex items-center gap-2 px-2.5 py-1.5 rounded-lg cursor-pointer transition-colors text-start"
            :class="
              index === activeIndex
                ? 'bg-n-alpha-2 text-n-slate-12'
                : 'hover:bg-n-alpha-1 text-n-slate-12'
            "
            @mousedown.prevent="pick(item)"
          >
            <span
              v-if="item.emoji"
              class="text-base size-5 flex items-center justify-center shrink-0 leading-none"
            >
              {{ item.emoji }}
            </span>
            <div class="flex flex-col min-w-0 flex-1">
              <span class="text-sm font-medium truncate text-n-slate-12">
                {{ item.title }}
              </span>
              <span
                v-if="item.description"
                class="text-xs text-n-slate-10 truncate"
              >
                {{ item.description }}
              </span>
            </div>
          </li>
        </template>
      </ul>
    </div>

    <p
      v-if="message"
      class="min-w-0 mt-1 mb-0 text-xs truncate transition-colors duration-150"
      :class="messageClass"
    >
      {{ message }}
    </p>
  </div>
</template>
