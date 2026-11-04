const TOOL_ID_REGEX = /\(tool:\/\/([^)]+)\)/g;
const TOOL_LINK_REGEX = /\[@?([^\]]*)\]\(tool:\/\/([^)]+)\)/g;

// Each distinct reference, with its fixed parameters: "update_contact_attribute?key=company_size".
export const getToolIdsFromInstruction = instruction => [
  ...new Set(
    [...(instruction?.matchAll(TOOL_ID_REGEX) ?? [])].map(match => match[1])
  ),
];

// The link text the editor shows for each reference, e.g. "Save Company size".
export const getToolTitlesFromInstruction = instruction =>
  Object.fromEntries(
    [...(instruction?.matchAll(TOOL_LINK_REGEX) ?? [])].map(match => [
      match[2],
      match[1],
    ])
  );

// Turns every link to the tool back into its plain title so the step still reads well.
export const unlinkTool = (instruction, toolId) =>
  instruction.replace(TOOL_LINK_REGEX, (link, title, id) =>
    id === toolId ? title : link
  );
