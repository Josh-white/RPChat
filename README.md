# RPChat

A World of Warcraft: Forever add-on that turns what you type in chat into role-play speech before it is sent.

It picks a voice from your character's race when you log in: **Human** (knightly), **Dwarf** ("aye, lad"), **Night Elf** (formal and ancient), **Gnome** (tinker) or **Skyborne** ("fair winds"). Your class adds its own flavour on top. Horde characters use the Human voice for now.

| You type | Others see |
|---|---|
| `hi guys whats up` | `Salutations chums what's ticking.` |
| `lol thank you so much u r awesome` | `*giggles* I am ever so obliged you are ingenious.` |
| `/y hello there` | `SALUTATIONS THERE!` |
| `*bows deeply*` (in /say) | sent as the emote `YourName bows deeply` |
| `~lol raw text` | `lol raw text` (start a line with `~` to send it untouched) |

Item links, raid markers like `{star}` and web links are never changed.

## Install

1. Download **[RPChat.zip](https://github.com/Josh-white/RPChat/raw/main/RPChat.zip)**.
2. Close the game.
3. Unzip it. You get a folder called `RPChat`.
4. Copy that `RPChat` folder into
   `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\`
   (create `Interface\AddOns` if it isn't there yet).
   The final path should be `...\AddOns\RPChat\RPChat.toc`, not `...\AddOns\RPChat\RPChat\RPChat.toc`.
5. Start the game. On the character screen click **AddOns** and make sure **RPChat** is ticked.
6. Log in. You'll see `RPChat: loaded` in chat. Try `/rp test hi guys` to preview without sending anything.

If the game is already running, `/reload` after copying the folder works too.

## Updating

Download the newest [RPChat.zip](https://github.com/Josh-white/RPChat/raw/main/RPChat.zip) the same way, close the game, and copy the new `RPChat` folder over the old one. Keep your own `CustomWords.lua` if you've edited it (copy everything else, or put your file back afterwards). Your settings are kept.

## Commands

- `/rp` turns it on or off. `/rp status` shows your voice, class and channels.
- `/rp test <text>` previews a line without sending it.
- `/rp style` lists the voices. `/rp style dwarf` (or human, nightelf, gnome, skyborne) uses that voice on this character. `/rp style auto` goes back to your race's voice.
- `/rp channel <name>` toggles a channel: say, yell, emote, party, instance, raid, guild, officer, whisper or channel. Say, yell, party and instance are on at first.
- `/rp banter` says a random in-character line, good for campfires and idle moments. About a third are for your class. `/rp banter class` always picks a class line. Add `party`, `yell` or `instance` to say it there (`/rp banter party`). Tip: put `/rp banter` in a macro.
- `/rp add hi = well met, friend` adds your own swap for a word or phrase.
- `/rp remove <word>` stops changing a built-in word.
- `/rp list` shows your own swaps. `/rp export` gives them to you in `CustomWords.lua` format to copy.
- `/rp flair` toggles the occasional emote at the start of a line. `/rp flair 30` sets how often, in percent (15 by default).
- `/rp caps`, `/rp punct`, `/rp stars` toggle the automatic capital letter, full stop, and `*emote*` lines.
- `/rp reset` restores the defaults.
- `/rp help` lists everything in game.

## Your own words

Swaps you add with `/rp add` are saved with your game settings. To keep them in a file you can copy between computers, use `RPChat\CustomWords.lua`:

1. In game, type `/rp export`, then press **Ctrl+C**.
2. Open `Interface\AddOns\RPChat\CustomWords.lua` in Notepad, select everything, paste, and save.
3. `/reload` in game.

You can also edit that file by hand; the instructions are at the top of it. If a word is in both places, the one added in game wins.

## Chat capture

RPChat keeps a log of your own say, yell, party and instance lines (what you typed and what was sent) in your own `WTF\...\SavedVariables\RPChat.lua`, newest 2,000 lines. It's there to help tune the word list. It never leaves your computer, nothing other people say is recorded, and lines starting with `~` are skipped. Turn it off with `/rp capture off`, or empty it with `/rp capture clear`.

## Good to know

- Many words have several possible replacements, picked at random.
- If a rewritten line would go over the 255 character limit, your original line is sent instead.
- If a line ever fails to send in a dungeon or in combat, type `/rp off` and let us know.
