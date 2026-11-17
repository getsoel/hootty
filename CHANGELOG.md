# Changelog

## [0.2.1](https://github.com/getsoel/hootty/compare/v0.2.0...v0.2.1) (2026-11-17)


### Features

* add in-app update check for Homebrew releases ([438b7e8](https://github.com/getsoel/hootty/commit/438b7e875bfd38d9c4935e0fa4b4546fb3feb6b9))
* drive Claude pane presence from hooks, not just title glyphs ([d0c60ab](https://github.com/getsoel/hootty/commit/d0c60ab5d057d452cd9465ae928ee9765f0be143))
* give "blocked on the user" its own attention state ([2b494f0](https://github.com/getsoel/hootty/commit/2b494f0b8827ac6e39c78a56b038bd461181292f))
* **links:** open Cmd-clicked links through ghostty's untrusted-URL policy ([f6d82df](https://github.com/getsoel/hootty/commit/f6d82df803f3bfbe92c31923ee9798ee3c245a86))
* per-surface occlusion tracking for background workspaces ([cd9de83](https://github.com/getsoel/hootty/commit/cd9de83245f677796139e043606afb0fb0fe320c))
* **presence:** compute pane indicators from a per-source presence model ([dbea6b0](https://github.com/getsoel/hootty/commit/dbea6b0d9c9546aba4ac573ea9b27848d6823d73))
* recover Claude sessions after a crash via resume UUID ([f066756](https://github.com/getsoel/hootty/commit/f066756d788bc369f40d6735453d6d1174ad9b58))
* show agent and program state from OSC 7501 program status ([4f990bd](https://github.com/getsoel/hootty/commit/4f990bda95a6279543274eac4c12a82421a266a7))
* **sidebar:** keep pane rows one line; status text in badge, tooltip and tab bar ([855a3f4](https://github.com/getsoel/hootty/commit/855a3f40d7cbb9a1abd5ce1106ee41afe6204ae4))
* **sidebar:** show the Jira ticket key from a branch name ([8de883f](https://github.com/getsoel/hootty/commit/8de883f6181904a09f8add035e235e29897cbbe4))
* **sounds:** play Submarine for blocked panes by default ([f310e7f](https://github.com/getsoel/hootty/commit/f310e7f7d714d63a08df409432b7e03dd768ac99))


### Bug Fixes

* **agents:** revert pane styling when agent exits ([9a224b6](https://github.com/getsoel/hootty/commit/9a224b6e73cb1c575beae9727ee21813f959638d))
* **clipboard:** ask before unsafe pastes and clipboard reads ([aa1dfa0](https://github.com/getsoel/hootty/commit/aa1dfa06eaa52392b1ac4e942c790f3da5467ed2))
* **config:** keep scrollback, copy-on-select and middle-click paste under ghostty 1.4 ([70befa5](https://github.com/getsoel/hootty/commit/70befa50fa59c365de9e47b10cea2333fe72d6ed))
* **drop:** refuse dropped files with control characters in the name ([be5378f](https://github.com/getsoel/hootty/commit/be5378fc90b48b08910320384670a548666f0d7b))
* **hooks:** stop the pre-commit test check from flaking or passing failures ([11cbb10](https://github.com/getsoel/hootty/commit/11cbb10e174a4bfc42dd480e1c004bf80a2e2ab6))
* resolve clipboard paste drops and sticky sidebar drop indicator ([9554e20](https://github.com/getsoel/hootty/commit/9554e20d886a2089249e92992a880d463874a554))
* restore Claude Code presence detection across three breaks ([0bd6def](https://github.com/getsoel/hootty/commit/0bd6def73c0ffb4bb2e3aa4c35239d798a52258b))


### Miscellaneous

* close inapp-update-check ([7bc86a4](https://github.com/getsoel/hootty/commit/7bc86a402238daaeee9aa759be05da6f9b9e9d3a))
* close surface-occlusion ([ba2c6a1](https://github.com/getsoel/hootty/commit/ba2c6a1966d3ded099b816139ea37839da54a42c))
* disable swiftformat 0.64 rules that fight the codebase style ([7b5d1af](https://github.com/getsoel/hootty/commit/7b5d1afdc7daa0fdb09ef99bb5a29f86d3ac18e2))
* gitignore .claude/scheduled_tasks.lock ([71e1327](https://github.com/getsoel/hootty/commit/71e132789f496016ba063917dddce169fc72b72e))
* sync release-please manifest to 0.2.0 ([961f90b](https://github.com/getsoel/hootty/commit/961f90b3a663644999cadc21b21b9ed19bd361f9))
