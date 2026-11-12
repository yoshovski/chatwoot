import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { emitter } from 'shared/helpers/mitt';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { ICON_MESSAGE_CIRCLE } from 'dashboard/helper/commandbar/icons';

export function useComposeHotKeys() {
  const { t } = useI18n();

  const composeHotKeys = computed(() => [
    {
      id: 'new_message',
      section: t('COMMAND_BAR.SECTIONS.GENERAL'),
      title: t('COMMAND_BAR.COMMANDS.NEW_MESSAGE'),
      icon: ICON_MESSAGE_CIRCLE,
      handler: () => emitter.emit(BUS_EVENTS.OPEN_COMPOSE),
    },
  ]);

  return { composeHotKeys };
}
