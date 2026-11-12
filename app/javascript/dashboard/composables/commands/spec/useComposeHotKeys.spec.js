import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { useComposeHotKeys } from '../useComposeHotKeys';

vi.mock('vue-i18n');
vi.mock('shared/helpers/mitt', () => ({ emitter: { emit: vi.fn() } }));

describe('useComposeHotKeys', () => {
  beforeEach(() => {
    useI18n.mockReturnValue({ t: key => key });
  });

  it('offers a new message command that opens the composer', () => {
    const { composeHotKeys } = useComposeHotKeys();
    const [command] = composeHotKeys.value;

    expect(command.title).toBe('COMMAND_BAR.COMMANDS.NEW_MESSAGE');
    command.handler();
    expect(emitter.emit).toHaveBeenCalledWith(BUS_EVENTS.OPEN_COMPOSE);
  });
});
