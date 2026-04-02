# Attention Sounds Command

## Overview

An `AppCommand` entry that opens the attention sounds modal from the command palette and menu bar.

## Behavior

### Command Definition

- MUST add `attentionSounds` case to `AppCommand`.
- The command title MUST be "Attention Sounds...".
- The command MAY have no keyboard shortcut hint (no default shortcut).

### Registration

- MUST register the command handler in `HoottyApp.registerCommands()`.
- The handler MUST set `appModel.modalState` to `.attentionSounds`.
- The command MUST appear in the command palette automatically (via `CommandRegistry.paletteCommands`).

### Modal State

- ADDED: `AppModel.ModalState.attentionSounds` case.
- The modal state MUST be handled in `ContentView` overlay rendering.
