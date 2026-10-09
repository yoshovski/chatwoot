import { describe, it, expect } from 'vitest';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';
import { formatInstructionWithToolChips } from './instructionFormatter';

describe('formatInstructionWithToolChips', () => {
  const { formatMessage } = useMessageFormatter();

  const mockTools = [
    {
      id: 'add_private_note',
      emoji: '📝',
      title: 'Add a private note',
      description: 'Leaves a note only your team can see',
    },
    {
      id: 'handoff',
      emoji: '🙋',
      title: 'Hand off to a person',
      description: 'Passes the chat to your team',
    },
  ];

  it('renders a numbered list containing two tools while keeping the list intact', () => {
    const instruction =
      '1. Step one: record notes using [@Add Private Note](tool://add_private_note) for the team.\n' +
      '2. Step two: then [@Handoff to Human](tool://handoff) to assign.';

    const result = formatInstructionWithToolChips(instruction, mockTools, {
      formatMessage,
    });

    // List structure is preserved
    expect(result).toContain('<ol>');
    expect(result).toContain('</ol>');
    expect(result).toContain('<li>');
    expect(result).toContain('</li>');

    // Both tools are rendered as chips
    expect(result).toContain('data-tool-id="add_private_note"');
    expect(result).toContain('data-tool-id="handoff"');

    // Titles and emojis come from the tool definition, not the link text
    expect(result).toContain('Add a private note');
    expect(result).toContain('📝');
    expect(result).toContain('Hand off to a person');
    expect(result).toContain('🙋');

    // Tooltips are populated from descriptions
    expect(result).toContain('Leaves a note only your team can see');
    expect(result).toContain('Passes the chat to your team');
  });

  it('renders an unknown tool as a muted chip with the raw id and unavailable tooltip', () => {
    const instruction = 'Call the unknown tool [@Old](tool://shopify_unknown).';

    const result = formatInstructionWithToolChips(instruction, mockTools, {
      formatMessage,
      unavailableText: "This tool isn't available for this assistant",
    });

    expect(result).toContain('data-tool-id="shopify_unknown"');
    expect(result).toContain('shopify_unknown');
    expect(result).toContain(
      'This tool isn&#039;t available for this assistant'
    );
    expect(result).toContain('bg-n-alpha-2');
  });

  it('handles empty or blank instruction', () => {
    expect(formatInstructionWithToolChips('', mockTools)).toBe('');
    expect(formatInstructionWithToolChips(null, mockTools)).toBe('');
  });
});
