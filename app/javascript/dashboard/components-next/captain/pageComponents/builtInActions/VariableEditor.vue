<script setup>
import { computed, nextTick, onMounted, ref, watch } from 'vue';

// Text field where variables show as labelled chips instead of {{ contact.name }}.
// Type @ for the variable list, drag a variable in, or call insert(key) from outside.
// The value stays the Liquid text the server renders.
const props = defineProps({
  modelValue: { type: String, default: '' },
  variables: { type: Array, default: () => [] },
  multiline: { type: Boolean, default: false },
  monospace: { type: Boolean, default: false },
  placeholder: { type: String, default: '' },
  label: { type: String, default: '' },
});

const emit = defineEmits(['update:modelValue', 'focus']);

const DRAG_TYPE = 'text/x-chatoctave-variable';
const TOKEN = /\{\{\s*([\w.]+)\s*\}\}/g;
const MENU_LIMIT = 8;
// Invisible character after each chip so the cursor can sit to its right, also at the end of a line.
const ANCHOR = '\u200B';
const CHIP_CLASS =
  'inline-flex items-center px-1.5 mx-px rounded-md bg-n-blue-3 text-n-blue-11 font-sans text-[0.8125rem] font-medium leading-5 cursor-grab select-none';

const el = ref(null);
let lastEmitted = null;
let savedRange = null;
let dragSource = null;

const escapeHtml = text =>
  text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');

const labelFor = key =>
  props.variables.find(variable => variable.key === key)?.label || key;

const chipNode = key => {
  const span = document.createElement('span');
  span.dataset.var = key;
  span.contentEditable = 'false';
  span.draggable = true;
  span.className = CHIP_CLASS;
  span.textContent = labelFor(key);
  return span;
};

const toHtml = text =>
  escapeHtml(text)
    .replace(
      TOKEN,
      (match, key) =>
        `<span data-var="${escapeHtml(key)}" contenteditable="false" draggable="true" class="${CHIP_CLASS}">${escapeHtml(labelFor(key))}</span>${ANCHOR}`
    )
    .replace(/\n/g, '<br>');

const serialize = node =>
  Array.from(node.childNodes)
    .map((child, index) => {
      if (child.nodeType === Node.TEXT_NODE)
        return child.nodeValue.replace(/\u00a0/g, ' ').replace(/\u200B/g, '');
      if (child.dataset?.var) return `{{ ${child.dataset.var} }}`;
      if (child.nodeName === 'BR')
        return index === node.childNodes.length - 1 ? '' : '\n';
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
  lastEmitted = serialize(el.value);
  emit('update:modelValue', lastEmitted);
};

watch(
  () => props.modelValue,
  value => {
    if (value !== lastEmitted) render();
  }
);
watch(() => props.variables, render);
onMounted(render);

const saveRange = () => {
  const selection = window.getSelection();
  if (selection.rangeCount && el.value.contains(selection.anchorNode)) {
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

const insertAt = (range, key) => {
  range.deleteContents();
  const chip = chipNode(key);
  const space = document.createTextNode(`${ANCHOR} `);
  range.insertNode(space);
  range.insertNode(chip);
  placeCaretAfter(space);
  update();
};

// The chip right before (or after) a collapsed cursor, skipping the invisible anchors.
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
  return node?.dataset?.var ? node : null;
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

// Clicking a chip puts the cursor on the side you clicked.
const onClick = event => {
  const chip = event.target.closest?.('[data-var]');
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

// @ menu
const menu = ref(null); // { query, node, start, end, top, left }
const activeIndex = ref(0);
const menuItems = computed(() => {
  if (!menu.value) return [];
  const query = menu.value.query.trim().toLowerCase();
  return props.variables
    .filter(
      variable =>
        !query ||
        variable.label.toLowerCase().includes(query) ||
        variable.key.toLowerCase().includes(query)
    )
    .slice(0, MENU_LIMIT);
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
    top: caret.bottom - box.top + 4,
    left: Math.max(0, caret.left - box.left),
  };
  activeIndex.value = 0;
};

const pick = variable => {
  const { node, start, end } = menu.value;
  const range = document.createRange();
  range.setStart(node, start);
  range.setEnd(node, end);
  closeMenu();
  insertAt(range, variable.key);
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
    if (props.multiline) {
      document.execCommand('insertLineBreak');
      update();
    }
  }
};

const onPaste = event => {
  event.preventDefault();
  const text = event.clipboardData.getData('text/plain');
  document.execCommand(
    'insertText',
    false,
    props.multiline ? text : text.replace(/\n/g, ' ')
  );
};

// Drag and drop: variables from the list, or chips moved inside the field.
const rangeFromPoint = (x, y) => {
  if (document.caretRangeFromPoint) return document.caretRangeFromPoint(x, y);
  const position = document.caretPositionFromPoint?.(x, y);
  if (!position) return null;
  const range = document.createRange();
  range.setStart(position.offsetNode, position.offset);
  return range;
};

const onDragStart = event => {
  const key = event.target?.dataset?.var;
  if (!key) return;
  dragSource = event.target;
  event.dataTransfer.setData(DRAG_TYPE, key);
  event.dataTransfer.effectAllowed = 'copyMove';
};

const isDragOver = ref(false);
const hasVariable = event =>
  Array.from(event.dataTransfer?.types || []).includes(DRAG_TYPE);

// The browser only drops where dragover says it may.
const onDragOver = event => {
  if (!hasVariable(event)) return;
  event.preventDefault();
  event.dataTransfer.dropEffect = dragSource ? 'move' : 'copy';
  isDragOver.value = true;
};

const onDragLeave = event => {
  if (!el.value.contains(event.relatedTarget)) isDragOver.value = false;
};

const onDrop = event => {
  isDragOver.value = false;
  const key = event.dataTransfer.getData(DRAG_TYPE);
  if (!key) return;
  event.preventDefault();
  let range = rangeFromPoint(event.clientX, event.clientY);
  if (!range || !el.value.contains(range.startContainer)) {
    range = document.createRange();
    range.selectNodeContents(el.value);
    range.collapse(false);
  }
  // Dropped on a chip: go after it, never inside it.
  const chip = range.startContainer.parentElement?.closest('[data-var]');
  if (chip && el.value.contains(chip)) {
    range.setStartAfter(chip);
    range.collapse(true);
  }
  if (dragSource && el.value.contains(dragSource) && dragSource !== chip) {
    dragSource.remove();
  }
  dragSource = null;
  el.value.focus();
  insertAt(range, key);
};

const onDragEnd = () => {
  dragSource = null;
  isDragOver.value = false;
};

const insert = key => {
  el.value.focus();
  const range = savedRange || document.createRange();
  if (!savedRange) {
    range.selectNodeContents(el.value);
    range.collapse(false);
  }
  insertAt(range, key);
};

const onBlur = () => {
  saveRange();
  setTimeout(closeMenu, 150);
};

defineExpose({ insert, dragType: DRAG_TYPE });

nextTick(render);
</script>

<template>
  <div class="relative">
    <div
      ref="el"
      contenteditable="true"
      role="textbox"
      :aria-label="label"
      :aria-multiline="multiline"
      class="w-full px-3 py-2 text-sm break-words whitespace-pre-wrap border rounded-lg outline-none border-n-weak bg-n-alpha-1 text-n-slate-12 focus:border-n-brand"
      :class="[
        multiline ? 'min-h-64 leading-7' : 'leading-6',
        monospace ? 'font-mono text-xs' : '',
        isDragOver ? '!border-n-brand ring-2 ring-n-brand/30' : '',
      ]"
      @input="onInput"
      @keydown="onKeydown"
      @keyup="saveRange"
      @mouseup="saveRange"
      @click="onClick"
      @focus="emit('focus')"
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
      class="absolute pointer-events-none top-2 start-3 text-sm text-n-slate-10"
    >
      {{ placeholder }}
    </span>
    <ul
      v-if="menu && menuItems.length"
      class="absolute z-50 flex flex-col w-64 p-1 m-0 overflow-y-auto list-none border shadow-lg max-h-72 rounded-xl border-n-weak bg-n-solid-2"
      :style="{ top: `${menu.top}px`, left: `${menu.left}px` }"
      role="listbox"
    >
      <li
        v-for="(variable, index) in menuItems"
        :key="variable.key"
        role="option"
        :aria-selected="index === activeIndex"
        class="flex flex-col px-2.5 py-1.5 rounded-lg cursor-pointer"
        :class="index === activeIndex ? 'bg-n-alpha-2' : 'hover:bg-n-alpha-1'"
        @mousedown.prevent="pick(variable)"
      >
        <span class="text-sm text-n-slate-12">{{ variable.label }}</span>
        <span v-if="variable.group" class="text-xs text-n-slate-10">
          {{ variable.group }}
        </span>
      </li>
    </ul>
  </div>
</template>
