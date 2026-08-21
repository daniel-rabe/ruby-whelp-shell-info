# Ruby Whelp Shell Info

A small World of Warcraft addon that shows the training progress of the trinket
[Ruby Whelp Shell](https://www.wowhead.com/item=193757/ruby-whelp-shell) directly in its tooltip.

Instead of typing

```
/run for i=2148,2153,1 do V=C_CurrencyInfo.GetCurrencyInfo(i); print(V.name.." - discovered:",tostring(V.discovered)..", quantity:",tostring(V.quantity)) end
```

every time you want to know how your whelp is trained, just hover the trinket.

## What it shows

```
Ruby Whelp Shell
...
Ruby Whelp Shell Training              6/6 trained
 [icon] Lobbing Fire Nova       ▮▮▮▯▯▯  3/6
 [icon] Fire Shot               ▮▮▯▯▯▯  2/6
 [icon] Mending Breath          ▮▯▯▯▯▯  1/6
 [icon] Curing Whiff            ▯▯▯▯▯▯  0/6
 [icon] Sleepy Ruby Warmth      ▯▯▯▯▯▯  0/6
 [icon] Under Red Wings         ▯▯▯▯▯▯  0/6
```

* Every whelp ability with its current rank, sorted by rank (highest first).
* Total trainings spent, and how many are left (training is a daily cooldown, six in total).
* A maxed ability (6/6) is shown in green, untrained ones are greyed out.
* The same info is added to the tooltip of the trinket's on-use spell.

The ability names and icons are read from the game client at runtime (via the six hidden
currencies `2148`–`2153`, which is exactly what the macro above prints), so the addon works
in every locale and does not rely on a hardcoded ability list.

## Installation

Copy the folder `RubyWhelpShellInfo` into

```
World of Warcraft/_retail_/Interface/AddOns/
```

so that `Interface/AddOns/RubyWhelpShellInfo/RubyWhelpShellInfo.toc` exists, then restart the
game (or `/reload`).

If your client reports the addon as out of date, either enable "Load out of date AddOns" or
bump the `## Interface:` number in the `.toc` to your client's value (`/run print((select(4, GetBuildInfo())))`).

## Slash commands

| Command | Effect |
| --- | --- |
| `/rws` | print the training progress to chat (name, rank, currency id, discovered) |
| `/rws toggle` | turn the tooltip info on/off |
| `/rws compact` | show a single summary line instead of the full list |
| `/rws bars` | toggle the rank bars |
| `/rws icons` | toggle the ability icons |
| `/rws hideempty` | hide abilities that have no rank yet |
| `/rws modifier none\|shift\|ctrl\|alt` | only show the info while that key is held |

`/rubywhelp` works as an alias. Settings are saved per account in `RubyWhelpShellInfoDB`.

## Notes

* The whelp has six possible abilities: **Fire Shot** and **Lobbing Fire Nova** (damage),
  **Under Red Wings** (haste) and **Sleepy Ruby Warmth** (crit), **Mending Breath** (AoE heal)
  and **Curing Whiff** (single target heal). Each can be trained up to rank 6, and you have
  six trainings in total — one per day.
* `discovered = false` on a currency simply means the client has not flagged it for display
  yet; the rank is still reported correctly, so untrained abilities are listed as `0/6`.
