# Attention Indicators

Attention indicators notify you when a terminal pane needs your attention, even when you're focused on a different pane or group. They're primarily driven by Claude Code integration but also respond to terminal bell events.

## Attention Kinds

There are two kinds of attention, each with a distinct color:

| Kind | Color | Meaning |
|------|-------|---------|
| **Idle** | Green | Claude Code has finished and is awaiting your next prompt. |
| **Input** | Yellow | Claude Code needs your input — a permission approval, a question, or similar. |

Input takes visual priority over idle when multiple panes in the same group have attention.

## Where Indicators Appear

### Tab bar

- The tab's status dot changes to a **bell icon** in the attention color.
- An **animated colored border** sweeps around the tab's edges.
- If the attention tab is selected, the animated border extends from the tab down to the terminal content, creating a connected visual.

### Sidebar

- **Pane group rows** show an animated border when an unfocused pane within the group has attention.
- **Workspace rows** show an animated border when the workspace is collapsed and contains unfocused panes with attention.
- **Focused pane rows** show a solid accent border instead of the animated attention border.

## Clearing Attention

Attention clears automatically when you focus the pane that needs attention:

- **Clicking the tab** in the tab bar selects the pane and clears its attention.
- **Clicking the pane row** in the sidebar focuses it and clears the attention.
- **Focusing the pane group** clears attention on the group's selected pane.

Attention is only set on panes that are not currently focused. If you're already looking at a pane, it won't show attention indicators.

## Details

- The animated border is a sweeping segment that travels around the element's perimeter, creating a subtle motion effect.
- Attention state is not persisted — it resets on app restart.
- Attention aggregates hierarchically: pane → group (most urgent) → workspace (unfocused groups only).
