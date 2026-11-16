# cro/x tester checklist (per build)

Copy this into a pinned message for each new build and change the version. Testers reply with what they could and couldn't do.

**Build: 0.60-beta**

Install: close the game, delete the old `Interface\AddOns\CROX` folder, unzip so the path is `Interface\AddOns\CROX\CROX.toc`, then log in. The login line should say `cro_x 0.60-beta loaded`.

## Quick pass (10 minutes)

- [ ] Logged in with no red error text. (If you saw one: `/x bug`.)
- [ ] Splash page showed, and closed by itself.
- [ ] `/x` opens the window. Character section lines up (labels left, menus in a column).
- [ ] Changed temperament and homeland; the choices stuck after `/reload`.
- [ ] Fought at least three mobs. cro/x spoke or emoted on some abilities, not all of them.
- [ ] Chatty Quiet, Normal and Lively felt different.
- [ ] `/x test` after a quiet press gave a plain reason.
- [ ] `/x flag` after a fight listed the lines; marking one worked.
- [ ] `/x bug` built a report that fits in one Discord message.

## Group pass (needs two people with cro/x)

- [ ] Both saw each other's names in the group tab, no errors.
- [ ] A cure, heal or rez call got a reply from the other player, and not every time.
- [ ] Neither of you spoke over the other more than a couple of times a minute.

## Look and feel

- [ ] Art: `/x art`; which picks looked best? Which squares were blank?
- [ ] Anything that looked un-Blizzard-like in the window?

## Please report

Any error text, any line that felt awkward or wrong for your character, any press that stayed quiet when it shouldn't have. `/x bug` covers all three.
