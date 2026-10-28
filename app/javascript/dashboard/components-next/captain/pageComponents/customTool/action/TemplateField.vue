<script setup>
import { onMounted, ref, watch } from 'vue';
import VariablePicker from './VariablePicker.vue';
import { templateParts } from './actionForm';

// A text field that shows each {{ variable }} as a tag with a remove button. The value stays a plain template
// string; the { } button inserts a variable at the cursor.
const props = defineProps({
  variables: { type: Object, required: true },
  label: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  multiline: { type: Boolean, default: false },
});

const model = defineModel({ type: String, default: '' });

const editor = ref(null);
let lastValue = null;
let savedRange = null;

const TAG_CLASS =
  'inline-flex items-center gap-0.5 ps-1.5 pe-0.5 mx-0.5 rounded-md bg-n-blue-3 text-n-blue-11 font-sans text-xs leading-5 align-baseline select-none';
const REMOVE_CLASS =
  'i-lucide-x size-3 cursor-pointer opacity-60 hover:opacity-100';

const tagNode = ({ variable, raw }) => {
  const tag = document.createElement('span');
  tag.className = TAG_CLASS;
  tag.contentEditable = 'false';
  tag.dataset.raw = raw;
  tag.append(document.createTextNode(variable.replace(/^outputs\./, '')));
  const remove = document.createElement('span');
  remove.className = REMOVE_CLASS;
  remove.dataset.remove = 'true';
  tag.append(remove);
  return tag;
};

const render = () => {
  const nodes = templateParts(model.value).map(part =>
    part.variable ? tagNode(part) : document.createTextNode(part.text)
  );
  editor.value.replaceChildren(...nodes);
  lastValue = model.value;
};

const serialize = node =>
  [...node.childNodes]
    .map((child, index) => {
      if (child.nodeType === Node.TEXT_NODE) return child.nodeValue;
      if (child.dataset?.raw) return child.dataset.raw;
      if (child.nodeName === 'BR') return '\n';
      const prefix = index > 0 ? '\n' : '';
      return `${prefix}${serialize(child)}`;
    })
    .join('')
    .replace(/\u00a0/g, ' ');

const emitValue = () => {
  const value = serialize(editor.value);
  lastValue = value;
  model.value = value;
  if (!value) editor.value.replaceChildren();
};

const saveRange = () => {
  const selection = window.getSelection();
  if (selection.rangeCount && editor.value.contains(selection.anchorNode)) {
    savedRange = selection.getRangeAt(0).cloneRange();
  }
};

// Typed or pasted {{ }} become tags once the field loses focus, so the cursor never jumps while typing.
const onBlur = () => {
  saveRange();
  if (editor.value.textContent.includes('{{')) render();
};

const onClick = event => {
  if (!event.target.dataset.remove) return;
  event.target.parentElement.remove();
  emitValue();
};

const onKeydown = event => {
  if (event.key === 'Enter' && !props.multiline) event.preventDefault();
};

const onPaste = event => {
  event.preventDefault();
  const text = event.clipboardData.getData('text/plain');
  document.execCommand(
    'insertText',
    false,
    props.multiline ? text : text.replace(/\s*\n\s*/g, ' ')
  );
};

const insert = text => {
  const [part] = templateParts(text);
  const node = tagNode(part);
  if (savedRange && editor.value.contains(savedRange.startContainer)) {
    savedRange.deleteContents();
    savedRange.insertNode(node);
  } else {
    editor.value.append(node);
  }
  // Keep typing right after the new tag.
  const after = document.createRange();
  after.setStartAfter(node);
  after.collapse(true);
  editor.value.focus();
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(after);
  savedRange = after.cloneRange();
  emitValue();
};

watch(model, value => {
  if (value !== lastValue) render();
});
onMounted(render);
</script>

<template>
  <div class="flex flex-col gap-1 min-w-0">
    <span v-if="label" class="mb-0.5 text-heading-3 text-n-slate-12">
      {{ label }}
    </span>
    <div class="relative">
      <div
        ref="editor"
        contenteditable="plaintext-only"
        role="textbox"
        :aria-multiline="multiline"
        :aria-label="label || placeholder"
        :data-placeholder="placeholder"
        class="w-full py-2 text-sm font-mono rounded-lg outline outline-1 outline-offset-[-1px] outline-n-weak bg-n-alpha-black2 text-n-slate-12 whitespace-pre-wrap break-words ps-3 pe-11 focus:outline-n-brand empty:before:content-[attr(data-placeholder)] empty:before:text-n-slate-10"
        :class="multiline ? 'min-h-24' : 'min-h-10 leading-6'"
        data-test="template-field"
        @input="emitValue"
        @keyup="saveRange"
        @mouseup="saveRange"
        @blur="onBlur"
        @click="onClick"
        @keydown="onKeydown"
        @paste="onPaste"
      />
      <div class="absolute top-1.5 end-1.5">
        <VariablePicker :variables="variables" @insert="insert" />
      </div>
    </div>
  </div>
</template>
