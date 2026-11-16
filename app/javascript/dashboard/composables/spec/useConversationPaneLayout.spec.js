import { getConversationPaneLayout } from '../useConversationPaneLayout';

// Available widths are the conversation area in rem (px / 16), after the
// navigation rail and section panel, as measured at the audited viewports.
describe('getConversationPaneLayout', () => {
  it.each([
    ['1024 px with section panel', 44, true, false],
    ['768 px with panel hidden', 42, true, false],
    ['1024 px with panel hidden', 58, false, false],
    ['1280 px with section panel', 60, false, false],
    ['1440 px with section panel', 70, false, false],
    ['1920 px with section panel', 100, false, true],
  ])('%s', (_, availableRem, isSinglePane, canDockDetails) => {
    expect(
      getConversationPaneLayout({ availableRem, isOnExpandedLayout: false })
    ).toEqual({ isSinglePane, canDockDetails });
  });

  it('never leaves the thread under the readable width beside docked panes', () => {
    for (let availableRem = 25; availableRem <= 120; availableRem += 0.5) {
      const { isSinglePane, canDockDetails } = getConversationPaneLayout({
        availableRem,
        isOnExpandedLayout: false,
      });
      const thread =
        availableRem - (isSinglePane ? 0 : 22.5) - (canDockDetails ? 22.75 : 0);
      expect(thread).toBeGreaterThanOrEqual(25);
    }
  });

  it('keeps one pane in the expanded layout and docks details only when they fit', () => {
    expect(
      getConversationPaneLayout({ availableRem: 100, isOnExpandedLayout: true })
    ).toEqual({ isSinglePane: true, canDockDetails: true });
    expect(
      getConversationPaneLayout({ availableRem: 40, isOnExpandedLayout: true })
    ).toEqual({ isSinglePane: true, canDockDetails: false });
  });

  it('keeps the list and floats details before the width is measured', () => {
    expect(
      getConversationPaneLayout({ availableRem: 0, isOnExpandedLayout: false })
    ).toEqual({ isSinglePane: false, canDockDetails: false });
  });
});
