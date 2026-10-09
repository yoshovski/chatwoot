const TOOL_ID_REGEX = /\(tool:\/\/([^)]+)\)/g;
const TOOL_LINK_REGEX = /\[@?([^\]]*)\]\(tool:\/\/([^)]+)\)/g;

export const getToolIdsFromInstruction = instruction => [
  ...new Set(
    [...(instruction?.matchAll(TOOL_ID_REGEX) ?? [])].map(match => match[1])
  ),
];

// Turns every link to the tool back into its plain title so the step still reads well.
export const unlinkTool = (instruction, toolId) =>
  instruction.replace(TOOL_LINK_REGEX, (link, title, id) =>
    id === toolId ? title : link
  );
