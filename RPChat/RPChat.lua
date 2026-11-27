-- RPChat: rewrites your outgoing chat into role-play speech.
-- Written for WoW: Forever (Interface 16001). Plain Lua 5.1, no libraries.

local ADDON = "RPChat"
RPChat = RPChat or {}
local R = RPChat

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
local DEFAULTS = {
  enabled = true,
  channels = { SAY = true, YELL = true, EMOTE = false, PARTY = true,
               INSTANCE_CHAT = true,
               RAID = false, GUILD = false, OFFICER = false,
               WHISPER = false, CHANNEL = false },
  capitalize = true,      -- capitalise the first letter
  punctuate = true,       -- add a full stop if the line has no end mark
  asteriskEmotes = true,
  flair = true,           -- now and then, start a line with a small *emote*
  flairChance = 15,       -- percent of lines that get one  -- "/s *bows deeply*" is sent as an emote
  style = "gnome",        -- the voice in use; picked from your race at login
  autoRace = true,        -- pick the voice from the character's race
  bypass = "~",           -- start a line with this to send it untouched
  custom = {},            -- user word list:  custom["hi"] = "well met"
  removed = {},           -- built-in words the user switched off
  capture = true,         -- keep a log of your own say/yell/party lines for tuning
}

-- Channels whose lines are captured (your own sent lines only).
local CAPTURE = { SAY = true, YELL = true, PARTY = true, INSTANCE_CHAT = true }
local CAPTURE_MAX = 2000

-- Chat speak that every style expands. Keys must be lower case.
local CORE = {
  words = {
    u = "you", ur = "your", r = "are", y = "why", pls = "please", plz = "please",
    ppl = "people", im = "I am", dont = "do not", cant = "cannot", wont = "will not",
    gonna = "going to", wanna = "want to", gotta = "must", btw = "by the way", imo = "in my view",
    idc = "I care not",
  },
  phrases = {},
}

-- Speech styles. Each has single words and multi-word phrases (lower case).
-- Phrases are applied first and are checked in the order listed.
local STYLES = {}

-- Human: knightly and plain-spoken. Also the base the other races build on:
-- a word Dwarf, Night Elf or Skyborne does not define comes from here.
local H_OK = { "very well", "as you say", "understood" }
local H_YES = { "aye", "indeed", "yes, friend" }
local H_NO = { "nay", "I think not" }
local H_NICE = { "well struck", "fine work", "splendid" }
local H_WOW = { "by the Light", "Light preserve us", "by my oath", "good heavens" }
local H_CURSE = { "blast", "curses", "confound it" }
local H_LAUGH = { "*chuckles*", "*laughs*", "*grins*", "*laughs heartily*" }
local H_THANKS = { "my thanks", "you have my thanks", "much obliged", "I thank you" }
local H_HI = { "well met", "greetings", "hail" }
local H_BYE = { "farewell", "until we meet again", "safe travels" }
local H_GRATS = { "well done", "congratulations", "nobly done" }
local H_FRIEND = { "friend", "comrade" }
local H_FRIENDS = { "friends", "companions", "comrades" }

STYLES.human = {
  label = "Human: well met, by the Light, my thanks",
  flair = { "*nods solemnly*", "*rests a hand on their hilt*", "*bows slightly*",
            "*straightens their tabard*", "*squares their shoulders*" },
  words = {
    k = H_OK, ok = H_OK, okay = H_OK, kk = H_OK, alright = H_OK, aight = H_OK,
    yes = H_YES, yeah = { "aye", "indeed" }, ya = H_YES, yea = H_YES, yep = "aye", yup = "aye",
    no = H_NO, nope = H_NO, nah = H_NO,
    sure = { "certainly", "gladly", "of course" }, maybe = { "perhaps", "perchance" },
    nice = H_NICE, sweet = H_NICE, cool = { "splendid", "fine" },
    awesome = { "magnificent", "glorious" }, great = { "splendid", "excellent" },
    amazing = { "remarkable", "astonishing" }, epic = { "legendary", "the stuff of ballads" },
    perfect = { "flawless", "perfect, truly" },
    wow = H_WOW, omg = H_WOW, woah = H_WOW, whoa = H_WOW,
    damn = H_CURSE, dang = H_CURSE, crap = H_CURSE,
    wtf = { "what in the Light's name", "what madness is this" },
    lol = H_LAUGH, lmao = H_LAUGH, rofl = H_LAUGH, haha = H_LAUGH, hahaha = H_LAUGH,
    hehe = H_LAUGH, lul = H_LAUGH, xd = H_LAUGH,
    thx = H_THANKS, ty = H_THANKS, thanks = H_THANKS, thnx = H_THANKS,
    tyvm = "I am in your debt", tysm = "I am in your debt",
    np = { "'tis no trouble", "think nothing of it" },
    yw = { "you are most welcome", "glad to be of service" },
    hi = H_HI, hello = H_HI, hey = { "hail", "well met" }, yo = { "hail", "well met" },
    sup = "what news", bye = H_BYE, cya = H_BYE, bb = H_BYE, ttyl = H_BYE, gn = "good night",
    gz = H_GRATS, grats = H_GRATS, gratz = H_GRATS, congrats = H_GRATS, gj = H_GRATS, wp = H_GRATS,
    gg = { "a fine battle", "well fought" },
    sorry = { "my apologies", "forgive me" }, mb = "my mistake", oops = "pardon me",
    guys = H_FRIENDS, friends = H_FRIENDS, dude = H_FRIEND, bro = H_FRIEND, buddy = H_FRIEND,
    mate = H_FRIEND, friend = H_FRIEND, noob = "squire", noobs = "squires",
    idk = { "I know not", "I cannot say" }, brb = { "I shall return shortly", "a moment, friends" },
    afk = "I must step away", gtg = "I must take my leave", g2g = "I must take my leave",
    omw = { "I am on my way", "I ride to you" }, otw = "on my way",
    sec = "moment", min = "moment", rdy = "ready", lfg = "seeking companions", inc = "incoming",
    oom = { "out of mana, I must rest", "my mana is spent" },
    lag = "a fog upon my mind", lagging = "beset by fog",
    mob = "foe", mobs = "foes", trash = "rabble", boss = { "their champion", "the warlord" },
    crit = "telling blow", crits = "telling blows",
    loot = "spoils", drop = "spoils", drops = "spoils", rez = "raise", res = "raise",
    buff = "blessing", buffs = "blessings", nerf = "weakening", op = "overpowering",
    dps = "damage", wipe = "a rout",
    stupid = "foolish", dumb = "foolish", crazy = "mad", fast = "swift", quick = "swift",
    slow = "sluggish", big = "mighty", huge = "enormous", problem = "trouble",
    plan = "strategy", idea = "notion", money = "coin", rich = "flush with coin",
    stinky = "foul", gross = "vile", weird = "strange", hard = "arduous", easy = "simple",
    fun = "good sport", tired = "weary", hungry = "in need of a hearty meal",
    ikr = { "truly", "my thoughts exactly" }, tbh = "in truth", ngl = "I'll not lie",
    fr = "truly", smh = "*shakes head*", rip = { "rest in peace", "alas" },
    ez = { "a simple task", "child's play" }, bruh = "oh, friend", u2 = "you as well",
    ty4 = "thanks for", nty = "nay, but I thank you",
    ugh = { "bah", "curses" }, yay = { "huzzah", "hurrah" }, woo = { "huzzah", "hurrah" },
    woohoo = { "huzzah", "hurrah" }, hmm = "*strokes chin thoughtfully*",
    hmmm = "*strokes chin thoughtfully*", ouch = { "ow", "that smarts" }, oof = { "oof", "blast" },
    yikes = { "Light preserve us", "good heavens" }, phew = "*wipes brow* phew",
    meh = "*shrugs*", sigh = "*sighs*",
    quest = "task", quests = "tasks", questing = "questing", healer = "cleric",
    heals = "healing", heal = "mend", aggro = "their ire", adds = "more foes",
    kite = "lead it on a chase", cc = "crowd control", gank = "ambush", ganked = "ambushed",
    corpse = "body", farm = "gather", farming = "gathering", inv = "invite", port = "portal",
    hearth = "hearthstone home",
    ding = { "Ding! I grow stronger", "Ding! Another step on the path" },
    lvl = "level", lvls = "levels", xp = "experience", exp = "experience",
    bags = "packs", vendor = "merchant", mats = "materials", luck = "fortune",
    lucky = "fortunate", unlucky = "ill-fated", gear = "arms and armour",
    upgrade = "improvement", upgrades = "improvements", weapon = "blade",
    kids = "children", kid = "child", computer = "scrying glass", computers = "scrying glasses",
    work = "labors", working = "laboring",
  },
  phrases = {
    { "thank you so much", "I am most grateful" },
    { "thank you very much", "I am most grateful" },
    { "thanks so much", "I am most grateful" },
    { "thank you", H_THANKS },
    { "no thanks", "nay, but I thank you" },
    { "no way", { "surely not", "I'll not believe it" } },
    { "no problem", { "'tis no trouble", "think nothing of it" } },
    { "how are you", "how fare you" },
    { "what's up", "what news" },
    { "whats up", "what news" },
    { "good morning", "good morrow" },
    { "good night", "rest well, friend" },
    { "see you later", "until we meet again" },
    { "see ya", "until we meet again" },
    { "i don't know", "I know not" },
    { "i dont know", "I know not" },
    { "i don't know what", "I know not what" },
    { "i'll be back", "I shall return" },
    { "ill be back", "I shall return" },
    { "all be back", "I shall return" },
    { "tabbed out of the game", "away on other business" },
    { "tabbed out", "away on other business" },
    { "i dont know what", "I know not what" },
    { "let's go", { "let us be off", "onward" } },
    { "lets go", { "let us be off", "onward" } },
    { "come on", "make haste" },
    { "never mind", "think nothing of it" },
    { "nvm", "think nothing of it" },
    { "oh no", "Light help us" },
    { "there it is", "there, at last" },
    { "got it", "it is mine" },
    { "drop rate", "fortune" },
    { "drop rates", "fortunes" },
    { "this sucks", { "this is a sorry business", "this is wretched" } },
    { "that sucks", { "that is ill fortune", "a sorry business" } },
    { "it sucks", "it is wretched" },
    { "sucks", { "is wretched", "is a sorry business" } },
    { "good job", H_GRATS },
    { "well done", H_GRATS },
    { "nice one", H_NICE },
    { "my bad", "my mistake" },
    { "one sec", "one moment" },
    { "hold on", "hold a moment" },
    { "be right back", "I shall return shortly" },
    { "on my way", "I am on my way" },
    { "heads up", "have a care, friends" },
    { "watch out", "have a care" },
    { "kill it", "strike it down" },
    { "killed it", "struck it down" },
    { "low health", "I am sorely wounded" },
    { "need heals", "I need healing" },
    { "need a heal", "I need healing" },
    { "out of mana", "my mana is spent" },
    { "i'm dead", "I have fallen" },
    { "im dead", "I have fallen" },
    { "good luck", "may the Light be with you" },
    { "gl", "may the Light be with you" },
    { "have fun", "enjoy the adventure" },
    { "thanks for the invite", "my thanks for the invitation" },
    { "thanks for the group", "my thanks for the company, friends" },
    { "thanks for the run", "a fine expedition, friends" },
    { "good run", "a fine expedition" },
    { "nice run", "a fine expedition" },
    { "good game", "well fought" },
    { "my turn", "my turn now" },
    { "brb bio", "I must step away a moment" },
    { "brb food", "a moment, I must eat" },
    { "be careful", "have a care" },
    { "follow me", "follow me, friends" },
    { "wait for me", "wait for me, friends" },
    { "wait up", "hold, friends" },
    { "hurry up", "make haste" },
    { "let me know", "send word" },
    { "sounds good", { "a fine plan", "agreed" } },
    { "makes sense", "that is sensible" },
    { "doesn't make sense", "that makes no sense" },
    { "doesnt make sense", "that makes no sense" },
    { "i'm lost", "I have lost my way" },
    { "im lost", "I have lost my way" },
    { "i'm back", "I have returned" },
    { "im back", "I have returned" },
    { "for sure", "most certainly" },
    { "of course", "but of course" },
    { "oh well", "ah well, such is fate" },
    { "too bad", "ill fortune" },
    { "bad luck", "ill fortune" },
    { "no worries", "think nothing of it" },
    { "all good", "all is well" },
    { "i'm good", "I am well" },
    { "im good", "I am well" },
    { "i'm ready", "I stand ready" },
    { "im ready", "I stand ready" },
    { "ready check", "are we ready, friends" },
    { "need mana", "I must rest and drink" },
    { "inv pls", "an invitation, if you please" },
    { "inv please", "an invitation, if you please" },
    { "the rng", "fortune" },
    { "rng", "fortune" },
    { "need to drink", "I must rest and drink" },
    { "low mana", "my mana runs low" },
    { "on me", "rally to me" },
    { "let's do it", "let us do this" },
    { "lets do it", "let us do this" },
    { "what the heck", "what in the Light's name" },
    { "oh my god", "by the Light" },
    { "oh my gosh", "by the Light" },
    { "holy crap", "Light preserve us" },
  },
}

-- Dwarf: Ironforge hearty. Words not listed here come from Human.
local D_OK = { "right then", "aye, fair enough", "righto" }
local D_YES = { "aye", "aye, lad", "och, aye" }
local D_NO = { "nae", "nae chance", "nay, lad" }
local D_NICE = { "bonnie", "grand", "braw" }
local D_WOW = { "by Muradin's beard", "by my beard", "great forge" }
local D_CURSE = { "blast", "och", "by the Titans" }
local D_LAUGH = { "*guffaws*", "*belly laughs*", "*chortles into their beard*", "*roars with laughter*" }
local D_THANKS = { "cheers, lad", "thank ye kindly", "much obliged" }
local D_HI = { "hail, lad", "well met", "ho there" }
local D_BYE = { "safe travels, lad", "off wi' ye then", "till next time" }
local D_GRATS = { "grand work", "well done", "fine work" }
local D_FRIEND = { "lad", "pal" }
local D_FRIENDS = { "lads", "lads and lasses" }

STYLES.dwarf = {
  label = "Dwarf: aye lad, by my beard, nae bother",
  base = "human",
  flair = { "*strokes beard*", "*takes a swig from a flask*", "*hefts a mug*",
            "*grunts approvingly*", "*cracks knuckles*", "*wipes foam from their beard*" },
  words = {
    k = D_OK, ok = D_OK, okay = D_OK, kk = D_OK, alright = D_OK, aight = D_OK,
    yes = D_YES, yeah = D_YES, ya = D_YES, yea = D_YES, yep = "aye", yup = "aye",
    no = D_NO, nope = D_NO, nah = D_NO, sure = { "aye, sure", "o' course" },
    maybe = "mebbe",
    nice = D_NICE, sweet = D_NICE, cool = D_NICE,
    awesome = { "grand", "mighty fine" }, great = { "grand", "mighty fine" },
    amazing = { "a sight tae behold", "mighty fine" },
    wow = D_WOW, omg = D_WOW, woah = D_WOW, whoa = D_WOW,
    damn = D_CURSE, dang = D_CURSE, crap = D_CURSE,
    wtf = { "what in Khaz Modan", "what in the blazes" },
    lol = D_LAUGH, lmao = D_LAUGH, rofl = D_LAUGH, haha = D_LAUGH, hahaha = D_LAUGH,
    hehe = D_LAUGH, lul = D_LAUGH, xd = D_LAUGH,
    thx = D_THANKS, ty = D_THANKS, thanks = D_THANKS, thnx = D_THANKS,
    tyvm = "I owe ye a pint", tysm = "I owe ye a pint",
    np = { "nae bother", "think naught of it" }, yw = { "nae bother, lad", "any time" },
    hi = D_HI, hello = D_HI, hey = { "oi", "ho there" }, yo = { "oi", "ho there" },
    sup = "what's the news, lad",
    bye = D_BYE, cya = D_BYE, bb = D_BYE, ttyl = D_BYE,
    gz = D_GRATS, grats = D_GRATS, gratz = D_GRATS, congrats = D_GRATS, gj = D_GRATS, wp = D_GRATS,
    gg = { "a grand scrap", "well fought, lads" },
    sorry = { "sorry, lad", "my mistake" }, oops = "och, whoops",
    guys = D_FRIENDS, friends = D_FRIENDS, dude = D_FRIEND, bro = D_FRIEND, buddy = D_FRIEND,
    mate = D_FRIEND, friend = D_FRIEND, noob = "beardling", noobs = "beardlings",
    -- dwarven speech
    u = "ye", you = "ye", ur = "yer", your = "yer", dont = "dinnae", ["don't"] = "dinnae",
    cant = "cannae", ["can't"] = "cannae", wont = "willnae", ["won't"] = "willnae",
    little = "wee", small = "wee", tiny = "wee", beer = "ale", my = "me",
    idk = { "I dinnae ken", "cannae say" }, brb = { "back in a jiffy", "hold yer horses, back soon" },
    afk = "off tae see a dwarf about a ram", gtg = "I'm off", g2g = "I'm off",
    omw = "on me way", otw = "on me way",
    oom = { "me mana's dry", "out o' mana" },
    mob = "beastie", mobs = "beasties", trash = "riff-raff",
    boss = { "the big one", "their chieftain" },
    stupid = "daft", dumb = "daft", crazy = "mad as a box o' gnomes",
    tired = "dead on me feet", hungry = "starvin'", money = "coin", rich = "rollin' in gold",
    gross = "boggin'", weird = "queer", hard = "tough as granite", easy = "easy as stone",
    ugh = { "och", "bah" }, yay = { "huzzah", "har har" }, hmm = "*scratches beard*",
    hmmm = "*scratches beard*", ouch = { "argh", "that'll bruise" },
    ez = { "easy as stone", "nae bother at all" }, bruh = "och, lad",
    ding = { "Ding! Stronger than a mountain ram", "Ding! Another notch on me axe" },
    weapon = "axe", gear = "kit", kids = "bairns", kid = "bairn", gotta = "hafta",
  },
  phrases = {
    { "thank you so much", "I owe ye a pint" },
    { "thank you very much", "I owe ye a pint" },
    { "thank you", D_THANKS },
    { "no problem", "nae bother" },
    { "no worries", "nae bother" },
    { "how are you", "how're ye keepin'" },
    { "what's up", "what's the news, lad" },
    { "whats up", "what's the news, lad" },
    { "good morning", "mornin'" },
    { "good night", "sleep well, lad" },
    { "see you later", "see ye later" },
    { "i don't know", "I dinnae ken" },
    { "i dont know", "I dinnae ken" },
    { "i don't know what", "I dinnae ken what" },
    { "i dont know what", "I dinnae ken what" },
    { "let's go", { "let's be off, lads", "come on then" } },
    { "lets go", { "let's be off, lads", "come on then" } },
    { "come on", "come on, then" },
    { "oh no", "och, no" },
    { "good job", { "well done, lad", "grand work", "now that's dwarven work" } },
    { "well done", { "well done, lad", "grand work" } },
    { "i'm dead", "I'm deid" },
    { "im dead", "I'm deid" },
    { "low health", "I'm bleedin' bad" },
    { "out of mana", "me mana's dry" },
    { "need mana", "need a wee drink" },
    { "need to drink", "need a wee drink" },
    { "good luck", "may yer beard grow long" },
    { "gl", "may yer beard grow long" },
    { "thanks for the group", "cheers for the company, lads" },
    { "thanks for the run", "a grand delve, lads" },
    { "good run", "a grand delve" },
    { "nice run", "a grand delve" },
    { "wait up", "hold up, lads" },
    { "wait for me", "hold up, lads" },
    { "i'm lost", "I've lost me way" },
    { "im lost", "I've lost me way" },
    { "sounds good", "aye, sounds grand" },
    { "makes sense", "aye, that makes sense" },
    { "be careful", "mind yerself" },
    { "follow me", "follow me, lads" },
    { "holy crap", "by Muradin's beard" },
    { "oh my god", "by my beard" },
    { "oh my gosh", "by my beard" },
    { "the rng", "the luck o' the dice" },
    { "rng", "the luck o' the dice" },
    { "i'm back", "I'm back, lads" },
    { "im back", "I'm back, lads" },
  },
}

-- Night Elf: formal, calm and ancient. Words not listed here come from Human.
local N_OK = { "so be it", "as you wish", "very well" }
local N_YES = { "indeed", "it is so", "yes" }
local N_NO = { "I think not", "it shall not be", "no" }
local N_NICE = { "graceful", "most elegant", "well done" }
local N_WOW = { "by Elune", "Elune preserve us", "by the moon" }
local N_LAUGH = { "*laughs softly*", "*smiles serenely*", "*chuckles quietly*" }
local N_THANKS = { "my gratitude", "you honor me", "I am grateful" }
local N_HI = { "Ishnu-alah", "Elune's light upon you", "greetings" }
local N_BYE = { "Elune guide you", "may the stars guide you", "until our paths cross again" }
local N_GRATS = { "well done", "worthy work", "gracefully done" }
local N_FRIEND = { "friend", "kindred" }
local N_FRIENDS = { "friends", "kin", "companions" }

STYLES.nightelf = {
  label = "Night Elf: Ishnu-alah, by Elune, so be it",
  base = "human",
  flair = { "*gazes up at the moon*", "*ears twitch*", "*bows gracefully*",
            "*hums an ancient melody*", "*brushes back long hair*" },
  words = {
    k = N_OK, ok = N_OK, okay = N_OK, kk = N_OK, alright = N_OK, aight = N_OK,
    yes = N_YES, yeah = N_YES, ya = N_YES, yea = N_YES, yep = "indeed", yup = "indeed",
    no = N_NO, nope = N_NO, nah = N_NO, sure = { "certainly", "as you wish" },
    nice = N_NICE, sweet = N_NICE, cool = N_NICE,
    awesome = { "wondrous", "breathtaking" }, great = { "wondrous", "excellent" },
    amazing = "wondrous",
    wow = N_WOW, omg = N_WOW, woah = N_WOW, whoa = N_WOW,
    damn = { "curses", "by the shadows" }, dang = "curses", crap = "curses",
    wtf = { "what manner of madness is this", "in Elune's name, what" },
    lol = N_LAUGH, lmao = N_LAUGH, rofl = N_LAUGH, haha = N_LAUGH, hahaha = N_LAUGH,
    hehe = N_LAUGH, lul = N_LAUGH, xd = N_LAUGH,
    thx = N_THANKS, ty = N_THANKS, thanks = N_THANKS, thnx = N_THANKS,
    tyvm = "you honor me greatly", tysm = "you honor me greatly",
    np = { "it was no burden", "think nothing of it" }, yw = "it was my honor",
    hi = N_HI, hello = N_HI, hey = N_HI, yo = "greetings", sup = "what news do you bring",
    bye = N_BYE, cya = N_BYE, bb = N_BYE, ttyl = N_BYE,
    gz = N_GRATS, grats = N_GRATS, gratz = N_GRATS, congrats = N_GRATS, gj = N_GRATS, wp = N_GRATS,
    gg = "a worthy contest", sorry = "forgive me",
    guys = N_FRIENDS, friends = N_FRIENDS, dude = N_FRIEND, bro = N_FRIEND, buddy = N_FRIEND,
    mate = N_FRIEND, friend = N_FRIEND, noob = "young one", noobs = "young ones",
    idk = "that knowledge eludes me", brb = { "I shall return anon", "a moment, the night is patient" },
    afk = "I must attend to other matters", gtg = "I must depart", g2g = "I must depart",
    oom = "my power wanes", lag = "the winds of time falter", lagging = "slowed by the winds of time",
    mob = "creature", mobs = "creatures", trash = "lesser creatures", boss = "their master",
    wipe = "we have all fallen",
    stupid = "unwise", dumb = "unwise", fast = "swift as the wind", slow = "slow as stone",
    tired = "weary", hungry = "in need of nourishment", ez = "effortless", easy = "effortless",
    kids = "little ones", kid = "little one",
    ugh = "*sighs wearily*", yay = "wonderful", woo = "wonderful", woohoo = "wonderful",
    hmm = "*ponders quietly*", hmmm = "*ponders quietly*",
    ding = { "Ding! The ancient paths open further", "Ding! I grow in wisdom" },
  },
  phrases = {
    { "thank you so much", "you honor me greatly" },
    { "thank you very much", "you honor me greatly" },
    { "thank you", N_THANKS },
    { "how are you", "how fares your spirit" },
    { "what's up", "what news do you bring" },
    { "whats up", "what news do you bring" },
    { "good morning", "the sun rises upon you" },
    { "good night", "may Elune watch over your rest" },
    { "see you later", "until our paths cross again" },
    { "see ya", "until our paths cross again" },
    { "i don't know", "that knowledge eludes me" },
    { "i dont know", "that knowledge eludes me" },
    { "let's go", { "let us depart", "come, the path awaits" } },
    { "lets go", { "let us depart", "come, the path awaits" } },
    { "oh no", "Elune, no" },
    { "i'm dead", "I have fallen" },
    { "im dead", "I have fallen" },
    { "low health", "my strength wanes" },
    { "out of mana", "my power wanes" },
    { "low mana", "my power wanes" },
    { "need mana", "I must meditate" },
    { "need to drink", "I must rest and drink" },
    { "good luck", "may Elune guide your path" },
    { "gl", "may Elune guide your path" },
    { "thanks for the group", "it was an honor to travel with you" },
    { "thanks for the run", "a worthy journey, friends" },
    { "good run", "a worthy journey" },
    { "nice run", "a worthy journey" },
    { "be careful", "tread softly" },
    { "holy crap", "by Elune's light" },
    { "oh my god", "by Elune" },
    { "oh my gosh", "by Elune" },
    { "what the heck", "in Elune's name, what" },
    { "wait up", "wait for me, friends" },
    { "i'm lost", "I have strayed from the path" },
    { "im lost", "I have strayed from the path" },
    { "sounds good", "so be it" },
    { "the rng", "fate" },
    { "rng", "fate" },
    { "be right back", "I shall return anon" },
  },
}

-- Skyborne: WoW: Forever's new race, on both factions. Airy and free.
-- Words not listed here come from Human.
local S_OK = { "as the wind wills", "very well", "so it flies" }
local S_WOW = { "by the winds", "by the open sky", "storms above" }
local S_LAUGH = { "*laughs like a breeze*", "*chuckles*", "*grins skyward*" }
local S_THANKS = { "my thanks, on the wind", "the skies thank you", "many thanks" }
local S_HI = { "fair winds", "well met", "greetings" }
local S_BYE = { "fair winds", "may the sky carry you", "until the winds bring us together" }
local S_GRATS = { "soaring work", "well done", "high-flying work" }

STYLES.skyborne = {
  label = "Skyborne: fair winds, by the open sky",
  base = "human",
  flair = { "*ruffles their feathers*", "*glances at the sky*", "*lets the wind catch their hair*",
            "*stretches as if to take flight*" },
  words = {
    k = S_OK, ok = S_OK, okay = S_OK, kk = S_OK, alright = S_OK, aight = S_OK,
    wow = S_WOW, omg = S_WOW, woah = S_WOW, whoa = S_WOW,
    wtf = { "what ill wind is this", "by the storms, what" },
    lol = S_LAUGH, lmao = S_LAUGH, rofl = S_LAUGH, haha = S_LAUGH, hahaha = S_LAUGH,
    hehe = S_LAUGH, lul = S_LAUGH, xd = S_LAUGH,
    thx = S_THANKS, ty = S_THANKS, thanks = S_THANKS, thnx = S_THANKS,
    hi = S_HI, hello = S_HI, hey = "fair winds", yo = "fair winds",
    bye = S_BYE, cya = S_BYE, bb = S_BYE, ttyl = S_BYE,
    gz = S_GRATS, grats = S_GRATS, gratz = S_GRATS, congrats = S_GRATS, gj = S_GRATS, wp = S_GRATS,
    noob = "fledgling", noobs = "fledglings", kids = "fledglings", kid = "fledgling", fast = "swift as a gale", quick = "swift as a gale",
    slow = "slow as fog", tired = "wing-weary", brb = "I'll be back on the next breeze",
    gtg = "the winds call me away", g2g = "the winds call me away",
    ding = { "Ding! I soar higher", "Ding! The winds lift me higher" },
  },
  phrases = {
    { "good luck", "fair winds to you" },
    { "gl", "fair winds to you" },
    { "let's go", { "let us take flight", "onward, on the wind" } },
    { "lets go", { "let us take flight", "onward, on the wind" } },
    { "i'm dead", "I have fallen from the sky" },
    { "im dead", "I have fallen from the sky" },
    { "good night", "may the night winds be gentle" },
    { "oh my god", "by the winds" },
    { "holy crap", "storms above" },
    { "thanks for the group", "fair winds, and thanks for the company" },
    { "i'm lost", "I've lost the wind" },
    { "im lost", "I've lost the wind" },
  },
}

-- A value can be one string or a list { ... } of options; a list picks one at
-- random each time and never repeats the last pick back-to-back.
local LAUGH = { "*giggles*", "*snickers*", "*cackles gleefully*", "*chortles*",
                "*titters*", "*snorts with laughter*" }
local THANKS = { "much obliged", "ever so grateful", "many thanks",
                 "thanks a sprocketful", "my gratitude, truly" }
local NICE = { "nifty", "splendid", "most excellent", "marvellous", "top-notch" }
local YES = { "affirmative", "indeed", "quite so", "correct, by my calculations" }
local NO = { "negative", "afraid not", "most certainly not" }
local OK = { "right-o", "understood", "very good", "consider it calibrated" }
local WOW = { "by the cogs", "great sprockets", "well I'll be gear-stripped",
              "gadzooks" }
local CHUM = { "chum", "pal", "old sprocket" }
local CHUMS = { "chums", "pals", "comrades" }
local HI = { "salutations", "hullo", "greetings", "well hullo there" }
local BYE = { "toodle-oo", "cheerio", "ta-ta for now" }
local GRATS = { "congratulations", "splendid work", "bravo", "jolly good show" }

STYLES.gnome = {
  label = "Gnomish tinker: salutations, by the cogs, right-o",
  flair = { "*adjusts goggles*", "*tightens a loose bolt*", "*wipes grease from hands*",
            "*eyes sparkle with invention*", "*fiddles with a tiny wrench*",
            "*pushes goggles up*", "*pockets a stray cog*", "*taps a pocket gadget*" },
  words = {
    -- quick replies
    k = OK, ok = OK, okay = OK, kk = OK, alright = OK, aight = OK,
    yes = YES, yeah = { "indeed", "quite so", "rather" }, ya = YES, yea = YES, yep = "yup-yup", yup = "yup-yup",
    no = NO, nope = NO, nah = NO,
    sure = { "certainly", "but of course", "happily" },
    maybe = { "possibly, by my calculations", "the odds are uncertain" },
    nice = NICE, cool = { "nifty", "spiffy", "most nifty" },
    sweet = NICE, awesome = { "ingenious", "magnificent", "positively brilliant" },
    great = { "tremendous", "splendid", "first-rate" },
    amazing = { "ingenious", "astounding" }, epic = { "legendary", "monumental" },
    perfect = { "precisely calibrated", "flawless" },
    wow = WOW, omg = WOW, woah = WOW, whoa = WOW, damn = { "blast", "drat", "confound it" },
    dang = { "drat", "blast" }, crap = { "drat", "bolts and blazes" },
    wtf = { "what in Gnomeregan", "what the gearbox" },
    lol = LAUGH, lmao = LAUGH, rofl = LAUGH, haha = LAUGH, hahaha = LAUGH,
    hehe = LAUGH, lul = LAUGH, xd = LAUGH,
    thx = THANKS, ty = THANKS, tyvm = "ever so obliged", thanks = THANKS,
    np = { "no trouble at all", "think nothing of it", "happy to help" },
    yw = { "my pleasure entirely", "anytime, chum" },
    hi = HI, hello = HI, hey = { "hullo", "hey there" }, yo = { "hullo", "oi" },
    sup = "what's ticking", bye = BYE, cya = BYE, gn = "good night",
    gz = GRATS, grats = GRATS, congrats = GRATS, gj = GRATS, wp = GRATS,
    gg = { "splendid engineering", "well fought" },
    sorry = { "my apologies", "terribly sorry" }, mb = "my mistake", oops = "whoopsie-daisy",
    -- people
    guys = CHUMS, friends = CHUMS, dude = CHUM, bro = CHUM, buddy = CHUM,
    mate = CHUM, friend = CHUM, noob = "apprentice",
    -- chat shorthand
    idk = { "my calculations are inconclusive", "haven't the foggiest" },
    brb = { "back in a tick", "one moment, recalibrating" },
    afk = "stepping away from the workbench", gtg = "must dash", g2g = "must dash",
    omw = { "on my way, full steam ahead", "en route" }, otw = "en route",
    sec = "tick", min = "moment", rdy = "ready", lfg = "seeking companions",
    inc = "incoming", oom = { "out of mana, my batteries are drained", "out of mana" },
    lag = "gremlins in the works", lagging = "riddled with gremlins",
    -- adventuring
    mob = "beastie", mobs = "beasties", trash = "riff-raff",
    boss = { "big boss", "head honcho" }, crit = { "critical hit", "direct hit" },
    crits = { "critical hits", "precision strikes" },
    loot = "salvage", drop = "salvage", drops = "salvage", rez = "revive", res = "revive",
    buff = "enhancement", buffs = "enhancements", nerf = "downgrade", op = "overpowered",
    dps = "damage output", wipe = "total system failure",
    -- descriptions
    stupid = "half-baked", dumb = "half-baked", crazy = "cracked as a cog",
    broken = "in need of a tune-up", fast = "zippy", quick = "zippy", slow = "sluggish",
    big = "enormous", huge = "colossal", tiny = "gnome-sized", small = "gnome-sized",
    problem = "malfunction", plan = "schematic", idea = "brainstorm",
    money = "coin", rich = "loaded with coin",
    stinky = "pungent", gross = "positively revolting", weird = "peculiar",
    hard = "tricky", easy = "simple as a sprocket", fun = "jolly good fun",
    tired = "running low on steam", hungry = "in need of fuel",
    -- more chat shorthand
    ikr = { "precisely", "my thoughts exactly" }, tbh = "to be perfectly frank",
    ngl = "I'll be honest", fr = "truly", smh = "*shakes head*", rip = { "rest in pieces", "how tragic" },
    ez = { "simple as a sprocket", "child's play" }, bruh = "oh, chum", u2 = "you too",
    gratz = GRATS, ty4 = "thanks for", bb = BYE, ttyl = BYE,
    thnx = THANKS, tysm = "I am ever so obliged", nty = "negative, but much obliged",
    -- interjections
    ugh = { "oh, bother", "bolts and blazes" }, yay = { "hooray", "huzzah" },
    woo = { "hooray", "wahoo" }, woohoo = { "hooray", "wahoo" }, hmm = "*taps chin thoughtfully*",
    hmmm = "*taps chin thoughtfully*", ouch = { "ow, my gears", "ouch, that rattled my cogs" },
    oof = { "drat", "blast" }, yikes = { "good gravy", "jumping gyros" },
    phew = "*wipes brow* phew", meh = "*shrugs*", sigh = "*sighs*",
    -- adventuring and groups
    quest = "assignment", quests = "assignments", questing = { "adventuring", "tinkering about" },
    healer = "medic", heals = "repairs", heal = "repair",
    aggro = "unwanted attention", adds = "extra beasties", kite = "lead it on a merry chase", cc = "crowd control", gank = "ambush", ganked = "ambushed",
    corpse = "remains", farm = "harvest", farming = "harvesting",
    inv = "invite",
    port = "teleport", hearth = "hearthstone home",
    ding = { "Ding! Upgrade complete", "Ding! New level calibrated" },
    lvl = "level", lvls = "levels", xp = "experience", exp = "experience",
    bags = "storage compartments",
    vendor = "merchant", mats = "materials",
    luck = "fortune", lucky = "fortunate", unlucky = "unfortunate", noobs = "apprentices",
    gear = "equipment", upgrade = "improvement", upgrades = "improvements",
    weapon = "armament", dagger = "stabby-sprocket", daggers = "stabby-sprockets",
    kids = "little sprockets", kid = "little sprocket", computer = "thinking-engine",
    computers = "thinking-engines", work = "tinkering", working = "tinkering",
  },
  phrases = {
    { "thank you so much", "I am ever so obliged" },
    { "thank you very much", "I am ever so obliged" },
    { "thanks so much", "I am ever so obliged" },
    { "thank you", THANKS },
    { "no thanks", "negative, but much obliged" },
    { "no way", { "preposterous", "impossible, surely" } },
    { "no problem", { "no trouble at all", "think nothing of it" } },
    { "how are you", "how are your gears turning" },
    { "what's up", "what's ticking" },
    { "whats up", "what's ticking" },
    { "good morning", "top of the morning" },
    { "good night", "rest well and dream of gears" },
    { "see you later", BYE },
    { "see ya", BYE },
    { "i don't know", "my calculations are inconclusive" },
    { "i dont know", "my calculations are inconclusive" },
    { "i don't know what", "I haven't the foggiest what" },
    { "i dont know what", "I haven't the foggiest what" },
    { "let's go", { "onward", "full steam ahead" } },
    { "lets go", { "onward", "full steam ahead" } },
    { "come on", "chop chop" },
    { "never mind", "disregard that" },
    { "nvm", "disregard that" },
    { "oh no", "oh, gears and gizmos" },
    { "there it is", { "eureka", "there's the sprocket", "found it, at last" } },
    { "got it", { "eureka", "acquired" } },
    { "drop rate", "probability matrix" },
    { "drop rates", "probability matrices" },
    { "this sucks", { "this is dreadfully miscalibrated", "what rubbish engineering" } },
    { "that sucks", { "that's dreadfully miscalibrated", "rotten luck" } },
    { "it sucks", { "it's a total malfunction", "it's most inefficient" } },
    { "sucks", { "is dreadfully miscalibrated", "is a total malfunction",
                 "is a real gear-grinder", "is utter rubbish" } },
    { "good job", GRATS },
    { "well done", GRATS },
    { "nice one", NICE },
    { "my bad", "my mistake" },
    { "one sec", "one tick" },
    { "hold on", "one tick" },
    { "be right back", "back in a tick" },
    { "on my way", "on my way, full steam ahead" },
    { "heads up", "attention, chums" },
    { "watch out", "look out" },
    { "kill it", "dismantle it" },
    { "killed it", "dismantled it" },
    { "low health", "hull integrity critical" },
    { "need heals", "requesting repairs" },
    { "need a heal", "requesting repairs" },
    { "out of mana", "batteries drained" },
    { "i'm dead", "I've been decommissioned" },
    { "im dead", "I've been decommissioned" },
    { "good luck", "may your gears never grind" },
    { "gl", "may your gears never grind" },
    { "have fun", "enjoy the tinkering" },
    { "thanks for the invite", "much obliged for the invitation" },
    { "thanks for the group", "much obliged for the company, chums" },
    { "thanks for the run", "splendid expedition, chums" },
    { "good run", "splendid expedition" },
    { "nice run", "splendid expedition" },
    { "good game", "well fought" },
    { "my turn", "my turn at the controls" },
    { "brb bio", "back in a tick, nature calls" },
    { "brb food", "back in a tick, refuelling" },
    { "be careful", "mind your gears" },
    { "follow me", "follow me, chums" },
    { "wait for me", "hold the gyrocopter" },
    { "wait up", "hold the gyrocopter" },
    { "hurry up", "chop chop" },
    { "let me know", "send word" },
    { "sounds good", { "splendid plan", "agreed, by my calculations" } },
    { "makes sense", "that computes" },
    { "doesn't make sense", "that does not compute" },
    { "doesnt make sense", "that does not compute" },
    { "i'm lost", "my compass has malfunctioned" },
    { "im lost", "my compass has malfunctioned" },
    { "i'm back", { "back at the workbench", "and I'm back" } },
    { "im back", { "back at the workbench", "and I'm back" } },
    { "for sure", "most definitely" },
    { "of course", "but of course" },
    { "oh well", "ah well, back to the drawing board" },
    { "too bad", "rotten luck" },
    { "bad luck", "rotten luck" },
    { "no worries", "think nothing of it" },
    { "all good", "all systems nominal" },
    { "i'm good", "all systems nominal" },
    { "im good", "all systems nominal" },
    { "i'm ready", "ready and calibrated" },
    { "im ready", "ready and calibrated" },
    { "ready check", "systems check, chums" },
    { "need mana", "my batteries need recharging" },
    { "inv pls", { "an invitation, if you please", "invite me, if you please" } },
    { "i'll be back", "back in a tick" },
    { "ill be back", "back in a tick" },
    { "all be back", "back in a tick" },
    { "tabbed out of the game", "off at another workbench" },
    { "tabbed out", "off at another workbench" },
    { "leveling up", { "getting upgraded", "installing upgrades" } },
    { "levelling up", { "getting upgraded", "installing upgrades" } },
    { "inv please", { "an invitation, if you please", "invite me, if you please" } },
    { "the rng", "the probability engine" },
    { "rng", "the probability engine" },
    { "need to drink", "my batteries need recharging" },
    { "low mana", "batteries running low" },
    { "on me", "on me, chums" },
    { "let's do it", "let's get cracking" },
    { "lets do it", "let's get cracking" },
    { "what the heck", "what in the gearbox" },
    { "oh my god", "great sprockets" },
    { "oh my gosh", "great sprockets" },
    { "holy crap", "great galloping gears" },
    { "good night", "rest well and dream of gears" },
  },
}

---------------------------------------------------------------------------
-- More words (v0.9): extra shorthand, questing, dungeon and group talk.
-- Added only where a style does not already have that word or phrase.
---------------------------------------------------------------------------
local function addMore(name, words, phrases)
  local st = STYLES[name]
  if not st then return end
  for k, v in pairs(words or {}) do
    if st.words[k] == nil then st.words[k] = v end
  end
  local have = {}
  for _, p in ipairs(st.phrases) do have[p[1]] = true end
  for _, p in ipairs(phrases or {}) do
    if not have[p[1]] then st.phrases[#st.phrases + 1] = p; have[p[1]] = true end
  end
end

-- Plain chat shorthand every voice expands.
for k, v in pairs({
  rn = "right now", atm = "at the moment", tho = "though", thru = "through",
  prob = "probably", probs = "probably", bc = "because", cuz = "because", coz = "because",
  w8 = "wait", ofc = "of course", obv = "obviously", obvs = "obviously", msg = "message",
  yall = "you all", ["y'all"] = "you all", lemme = "let me", gimme = "give me",
  kinda = "kind of", sorta = "sort of", dunno = "I do not know", ive = "I have",
  thats = "that is", whats = "what is", isnt = "is not", didnt = "did not",
  doesnt = "does not", wasnt = "was not", couldnt = "could not", wouldnt = "would not",
  shouldnt = "should not", havent = "have not", youre = "you are", theyre = "they are",
  alot = "a lot", teh = "the", nm = "not much", ppl = "people", srsly = "seriously",
}) do
  if CORE.words[k] == nil then CORE.words[k] = v end
end

local G_LAUGH = { "*giggles*", "*snickers*", "*cackles gleefully*", "*chortles*",
                  "*titters*", "*snorts with laughter*" }
local G_WOW = { "by the cogs", "great sprockets", "well I'll be gear-stripped", "gadzooks" }

addMore("gnome", {
  wb = { "welcome back, chum", "welcome back to the workshop" }, gm = "top of the morning",
  lfm = "seeking more companions", lf1m = "seeking one more companion",
  lf2m = "seeking two more companions", lf = "seeking",
  tank = "bulwark", tanks = "bulwarks", tanking = "holding the line",
  pull = "lure", pulling = "luring", pulled = "lured", pat = "patrol", pats = "patrols",
  rare = "rare specimen", elite = "elite brute", respawn = "reassembly", respawns = "reassemblies",
  aoe = "area blast", hp = "hull integrity", cd = "cooldown", cds = "cooldowns",
  ah = "auction house", mount = "trusty steed", bis = "best-in-slot gizmo",
  ninja = "pilferer", ninjaed = "pilfered", lmk = "send word", imo = "by my estimation",
  imho = "by my humble estimation", btw = "incidentally", fyi = "for your information, chum",
  nw = "no worries", tyty = "much obliged, much obliged", hf = "enjoy the tinkering",
  glhf = "good luck and happy tinkering", ffs = "for gear's sake",
  jk = "only jesting", jkjk = "only jesting", lolol = G_LAUGH, lmfao = G_LAUGH, kek = G_LAUGH,
  ha = "*chuckles*", heh = "*chuckles*", omfg = G_WOW, wth = "what the gearbox",
  argh = "argh, my gears", grr = "*grumbles*", ew = "eww, positively revolting",
  eww = "eww, positively revolting", pog = "spectacular", poggers = "spectacular",
  cringe = "positively mortifying", bet = "consider it calibrated", sus = "suspicious",
  noo = "nooo, my gears", nooo = "nooo, my gears", aww = "*beams*",
  sry = "terribly sorry", srry = "terribly sorry", soz = "terribly sorry",
  thnks = THANKS, plz = "please", hiya = "hullo", howdy = "hullo there", wassup = "what's ticking",
  idc = "I couldn't care a cog", instance = "expedition", wiped = "had a total system failure",
  wiping = "malfunctioning repeatedly", ress = "revive", drinking = "recharging",
  grind = "tinker away at", grinding = "tinkering away at", pvp = "duelling",
  dc = "disconnected by gremlins", dced = "got disconnected by gremlins", ["dc'd"] = "got disconnected by gremlins", relog = "reboot",
  bug = "glitch", bugged = "glitched", food = "fuel", eat = "refuel", coffee = "bean brew",
  beer = "ale", dinner = "supper", lunch = "midday fuel", phone = "pocket gadget",
  internet = "the aether-net", wifi = "the aether-net", irl = "outside the workshop",
  car = "mechanical carriage",
}, {
  { "going to bed", "powering down for the night" },
  { "going to sleep", "powering down for the night" },
  { "gotta go", "must dash" },
  { "got to go", "must dash" },
  { "have to go", "must dash" },
  { "see you tomorrow", "until tomorrow's tinkering" },
  { "welcome back", "welcome back to the workshop" },
  { "how's it going", "how are your gears turning" },
  { "hows it going", "how are your gears turning" },
  { "what are you doing", "what are you tinkering with" },
  { "what are you up to", "what are you tinkering on" },
  { "nice to meet you", "a pleasure to make your acquaintance" },
  { "thanks for the help", "much obliged for the assistance" },
  { "thanks for the heals", "much obliged for the repairs" },
  { "need a tank", "seeking a bulwark" },
  { "brb going to bed", "powering down for the night" },
  { "need a healer", "seeking a medic" },
  { "need dps", "seeking more firepower" },
  { "looking for group", "seeking companions" },
  { "looking for more", "seeking more companions" },
  { "turn in", "hand in" },
  { "almost done", "nearly finished" },
  { "almost there", "nearly there" },
  { "let's go again", "once more, chums" },
  { "lets go again", "once more, chums" },
  { "run it back", "once more, chums" },
  { "i'm out", "I'm off" },
  { "im out", "I'm off" },
  { "ready to go", "ready and calibrated" },
  { "wait a sec", "one tick" },
  { "give me a sec", "one tick" },
  { "gimme a sec", "one tick" },
  { "be right there", "on my way, full steam ahead" },
  { "no idea", "haven't the foggiest" },
  { "i agree", "my thoughts exactly" },
  { "me too", "likewise" },
  { "same here", "likewise" },
  { "for real", "truly" },
  { "not bad", "not bad at all, by my calculations" },
  { "love it", "marvellous" },
  { "so cool", "most nifty" },
  { "that was close", "that was a near thing" },
  { "that was fun", "that was jolly good fun" },
  { "gg wp", "splendid engineering, well fought" },
  { "good fight", "well fought" },
  { "nice pull", "splendid lure" },
  { "bad pull", "a miscalculated lure" },
  { "watch aggro", "mind the unwanted attention" },
  { "i got aggro", "they've targeted me" },
  { "run away", "retreat, retreat" },
  { "drink up", "recharge your batteries" },
  { "mana break", "battery break" },
  { "full mana", "fully charged" },
  { "full health", "hull fully repaired" },
  { "on cooldown", "recharging" },
  { "level up", "upgrade" },
  { "leveled up", "got upgraded" },
  { "dinged", "got upgraded" },
})

local HL = { "*chuckles*", "*laughs*", "*grins*", "*laughs heartily*" }
local HW = { "by the Light", "Light preserve us", "by my oath", "good heavens" }

addMore("human", {
  wb = "welcome back, friend", gm = "good morrow", lfm = "seeking more companions",
  lf1m = "seeking one more companion", lf2m = "seeking two more companions", lf = "seeking",
  tank = "shieldbearer", tanks = "shieldbearers", tanking = "holding the line",
  pull = "draw", pulling = "drawing them", pulled = "drew", pat = "patrol", pats = "patrols",
  rare = "rare beast", elite = "elite foe", respawn = "return", respawns = "returns",
  aoe = "sweeping strike", hp = "vigor", cd = "cooldown", cds = "cooldowns",
  ah = "auction house", mount = "steed", bis = "the finest gear", ninja = "thief",
  ninjaed = "stole", lmk = "send word", imho = "in my humble view", fyi = "mark this",
  nw = "no worries", tyty = "many thanks", hf = "fare well", glhf = "good fortune and good sport",
  ffs = "for pity's sake", jk = "I jest", jkjk = "I jest", lolol = HL, lmfao = HL, kek = HL,
  ha = "*chuckles*", heh = "*chuckles*", omfg = HW, wth = "what in the Light's name",
  argh = "argh", grr = "*growls*", ew = "how foul", eww = "how foul", pog = "glorious",
  poggers = "glorious", cringe = "most embarrassing", bet = "agreed", sus = "suspicious",
  noo = "nooo", nooo = "nooo", aww = "*smiles warmly*", sry = "my apologies",
  srry = "my apologies", soz = "my apologies", thnks = "my thanks", plz = "please",
  hiya = "well met", howdy = "well met", wassup = "what news", instance = "dungeon",
  wiped = "were routed", wiping = "being routed", ress = "raise", drinking = "resting",
  grind = "labor at", grinding = "laboring at", pvp = "honorable combat", dc = "lost to the fog", dced = "was lost to the fog", ["dc'd"] = "was lost to the fog",
  dced = "lost to the fog", relog = "return anew", bug = "curse", bugged = "cursed",
  food = "provisions", eat = "sup", coffee = "a hot drink", beer = "ale", dinner = "supper",
  lunch = "midday meal", phone = "message stone", internet = "the far-speaking",
  wifi = "the far-speaking", irl = "in the waking world", car = "carriage",
}, {
  { "going to bed", "off to my bedroll" },
  { "going to sleep", "off to my bedroll" },
  { "gotta go", "I must take my leave" },
  { "got to go", "I must take my leave" },
  { "have to go", "I must take my leave" },
  { "see you tomorrow", "until the morrow" },
  { "welcome back", "welcome back, friend" },
  { "how's it going", "how fare you" },
  { "hows it going", "how fare you" },
  { "what are you doing", "what are you about" },
  { "what are you up to", "what are you about" },
  { "nice to meet you", "well met, and a pleasure" },
  { "thanks for the help", "my thanks for your aid" },
  { "thanks for the heals", "my thanks for the healing" },
  { "need a tank", "we need a shieldbearer" },
  { "brb going to bed", "off to my bedroll" },
  { "need a healer", "we need a cleric" },
  { "need dps", "we need more blades" },
  { "looking for group", "seeking companions" },
  { "looking for more", "seeking more companions" },
  { "turn in", "report back" },
  { "almost done", "nearly finished" },
  { "almost there", "nearly there" },
  { "let's go again", "once more, friends" },
  { "lets go again", "once more, friends" },
  { "run it back", "once more, friends" },
  { "i'm out", "I take my leave" },
  { "im out", "I take my leave" },
  { "ready to go", "ready to ride" },
  { "wait a sec", "hold a moment" },
  { "give me a sec", "give me a moment" },
  { "gimme a sec", "give me a moment" },
  { "be right there", "I come at once" },
  { "no idea", "I know not" },
  { "i agree", "I agree, friend" },
  { "me too", "as do I" },
  { "same here", "as do I" },
  { "for real", "truly" },
  { "not bad", "not bad at all" },
  { "love it", "splendid" },
  { "so cool", "truly splendid" },
  { "that was close", "that was a near thing" },
  { "that was fun", "that was fine sport" },
  { "gg wp", "a fine battle, well fought" },
  { "good fight", "well fought" },
  { "nice pull", "well drawn" },
  { "bad pull", "an ill-judged pull" },
  { "watch aggro", "mind their ire" },
  { "i got aggro", "they come for me" },
  { "run away", "fall back" },
  { "drink up", "rest and drink" },
  { "mana break", "a moment's rest for mana" },
  { "full mana", "brimming with mana" },
  { "full health", "I am whole again" },
  { "on cooldown", "not yet ready" },
  { "level up", "grow stronger" },
  { "leveled up", "grew stronger" },
  { "dinged", "grew stronger" },
})

addMore("dwarf", {
  wb = "welcome back, lad", tank = "big shield", tanks = "big shields",
  hf = "have a grand time", ffs = "fer pity's sake", jk = "only jokin'", jkjk = "only jokin'",
  food = "grub", eat = "get some grub", coffee = "a strong brew", drinking = "havin' a wee drink",
  noo = "och, nae", nooo = "och, nae", ew = "boggin'", eww = "boggin'",
  aww = "*grins through their beard*", sry = "sorry, lad", srry = "sorry, lad", soz = "sorry, lad",
  hiya = "ho there", howdy = "ho there", wassup = "what's the news",
  grind = "graft at", grinding = "graftin' at", bug = "gremlin", bugged = "banjaxed",
  dunno = "I dinnae ken", isnt = "isnae", didnt = "didnae", doesnt = "doesnae", wasnt = "wasnae",
  couldnt = "couldnae", wouldnt = "wouldnae", shouldnt = "shouldnae", havent = "havnae",
}, {
  { "going to bed", "off tae bed" },
  { "going to sleep", "off tae bed" },
  { "gotta go", "I'm off, lads" },
  { "have to go", "I'm off, lads" },
  { "welcome back", "welcome back, lad" },
  { "how's it going", "how're ye keepin'" },
  { "hows it going", "how're ye keepin'" },
  { "nice to meet you", "pleased tae meet ye" },
  { "thanks for the help", "cheers fer the help, lad" },
  { "no idea", "nae idea" },
  { "need a tank", "we need a big shield" },
  { "brb going to bed", "off tae bed" },
  { "that was fun", "that was a grand laugh" },
  { "that was close", "that was a close one, lad" },
  { "not bad", "no' bad at all" },
  { "let's go again", "again, lads" },
  { "lets go again", "again, lads" },
  { "i'm out", "I'm off" },
  { "im out", "I'm off" },
})

addMore("nightelf", {
  wb = "welcome back, friend", tank = "guardian", tanks = "guardians", hf = "may joy find you",
  jk = "I jest", food = "nourishment", eat = "take nourishment", sry = "forgive me",
  srry = "forgive me", soz = "forgive me", aww = "*smiles softly*", ew = "most unpleasant",
  eww = "most unpleasant", hiya = "Ishnu-alah", howdy = "Ishnu-alah", grinding = "hunting endlessly",
}, {
  { "going to bed", "I go to rest beneath the stars" },
  { "going to sleep", "I go to rest beneath the stars" },
  { "gotta go", "I must depart" },
  { "have to go", "I must depart" },
  { "welcome back", "welcome back, friend" },
  { "how's it going", "how fares your path" },
  { "hows it going", "how fares your path" },
  { "nice to meet you", "it is an honor to meet you" },
  { "thanks for the help", "you have my gratitude for your aid" },
  { "no idea", "I cannot say" },
  { "need a tank", "we need a guardian" },
  { "brb going to bed", "I go to rest beneath the stars" },
  { "that was fun", "that was a joyful hunt" },
  { "that was close", "that was too close, even for an elf" },
  { "let's go again", "once more, friends" },
  { "lets go again", "once more, friends" },
})

addMore("skyborne", {
  wb = "welcome back on the wind", tank = "windbreak", tanks = "windbreaks",
  hf = "enjoy the open sky", hiya = "fair winds", howdy = "fair winds",
  aww = "*fluffs feathers happily*", ew = "foul as a swamp breeze", eww = "foul as a swamp breeze",
}, {
  { "going to bed", "time to roost" },
  { "need a tank", "we need a windbreak" },
  { "brb going to bed", "time to roost" },
  { "going to sleep", "time to roost" },
  { "gotta go", "the winds call me away" },
  { "have to go", "the winds call me away" },
  { "welcome back", "welcome back on the wind" },
  { "how's it going", "how are the winds treating you" },
  { "hows it going", "how are the winds treating you" },
  { "nice to meet you", "well met under open sky" },
  { "thanks for the help", "my thanks, you were a fair wind" },
  { "that was fun", "what a fine flight that was" },
  { "that was close", "that was a near fall" },
  { "let's go again", "once more into the wind" },
  { "lets go again", "once more into the wind" },
})

-- Other names people may type for a style.
-- v0.9.1: tuned from the laptop capture (2026-11-20)
addMore("gnome", {
  discord = "the chatter-relay", addon = "contraption", addons = "contraptions",
  school = "the academy", sleepy = "running low on steam", tired = "running low on steam",
  bedtime = "time to power down",
}, {
  { "its not", "it is not" },
  { "its a", "it is a" },
  { "its the", "it is the" },
  { "its getting", "it is getting" },
  { "its fine", "it is fine" },
  { "its ok", "it is all right" },
  { "its okay", "it is all right" },
  { "its been", "it has been" },
  { "its so", "it is so" },
  { "its just", "it is just" },
  { "its all", "it is all" },
  { "its time", "it is time" },
  { "its too", "it is too" },
  { "its only", "it is only" },
  { "not sure", "uncertain" },
  { "getting sleepy", "running low on steam" },
  { "make sure", "double-check" },
  { "sure thing", "consider it engineered" },
  { "how come", "why is it" },
  { "hey there", "hullo there" },
})
addMore("human", {
  discord = "the sending stones", addon = "enchantment", addons = "enchantments",
  school = "the schoolhouse", sleepy = "weary", bedtime = "the hour of rest",
}, {
  { "its not", "it is not" },
  { "its a", "it is a" },
  { "its the", "it is the" },
  { "its getting", "it is getting" },
  { "its fine", "it is fine" },
  { "its ok", "it is all right" },
  { "its okay", "it is all right" },
  { "its been", "it has been" },
  { "its so", "it is so" },
  { "its just", "it is just" },
  { "its all", "it is all" },
  { "its time", "it is time" },
  { "its too", "it is too" },
  { "its only", "it is only" },
  { "not sure", "uncertain" },
  { "getting sleepy", "growing weary" },
  { "you loot", "you claim the spoils" },
  { "loot it", "claim the spoils" },
  { "loot the", "plunder the" },
  { "make sure", "make certain" },
  { "sure thing", "it shall be done" },
  { "how come", "why is it" },
  { "hey there", "well met" },
})
addMore("dwarf", { school = "the schoolhouse", sleepy = "fair knackered" }, {
  { "not sure", "nae sure" },
  { "getting sleepy", "gettin' fair knackered" },
})
addMore("nightelf", { sleepy = "ready for the dreaming", discord = "the whispering stones" }, {})
addMore("skyborne", { sleepy = "ready to roost", discord = "the wind-whispers" }, {})

-- v0.11: words JJ is likely to type (from project chat and captures)
for k, v in pairs({
  -- common typos and no-apostrophe spellings: fixed in every voice
  lets = "let us", wierd = "weird", definately = "definitely", definatly = "definitely",
  probly = "probably", tommorow = "tomorrow", tomorow = "tomorrow", tommorrow = "tomorrow",
  tonite = "tonight", thier = "their", becuase = "because", becasue = "because",
  realy = "really", jsut = "just", waht = "what", hte = "the", adn = "and", untill = "until",
  recieve = "receive", seperate = "separate", percise = "precise", sytem = "system",
  sytems = "systems", wouldve = "would have", couldve = "could have", shouldve = "should have",
  arent = "are not", werent = "were not", hasnt = "has not", hadnt = "had not",
  theres = "there is", heres = "here is", wheres = "where is", whos = "who is",
  thatll = "that will", itll = "it will", youll = "you will", theyll = "they will",
  youve = "you have", weve = "we have", theyve = "they have", uh = "er", um = "er", ill = "I'll", youd = "you would",
}) do
  if CORE.words[k] == nil then CORE.words[k] = v end
end

addMore("gnome", {
  probably = "in all likelihood", prolly = "in all likelihood", tonight = "this evening shift",
  tomorrow = "on the morrow's shift", upstairs = "up to the upper deck", downstairs = "down to the lower workshop",
  wife = "better half", husband = "better half", laptop = "portable calculating engine",
  desktop = "grand calculating engine", pc = "calculating engine", game = "grand simulation",
  bugs = "gremlins", fix = "recalibrate", crash = "catastrophic malfunction", laggy = "running on rusty gears",
  dead = "decommissioned", died = "went kaput", heck = "gears and sprockets", whoops = "oopsie-cog",
  job = "day shift", dog = "loyal hound", cat = "mouser", bbl = "back after some tinkering",
}, {
  { "steam deck", "pocket steam engine" },
  { "a fix", "a tune-up" },
  { "its probably", "it is probably" },
  { "its kinda", "it is kind of" },
  { "its really", "it is really" },
  { "its pretty", "it is pretty" },
  { "its gonna", "it is going to" },
  { "its going", "it is going" },
  { "its weird", "it is weird" },
  { "its cool", "it is fine" },
  { "jumped on", "fired up the boilers on" },
  { "give me a sec", "one tick of the clock" },
  { "gimme a sec", "one tick of the clock" },
  { "one sec", "one tick of the clock" },
  { "hold on", "hold your cogs" },
  { "i think", "by my calculations" },
  { "let me check", "let me run a diagnostic" },
  { "lemme check", "let me run a diagnostic" },
  { "be right back", "back in a tick" },
  { "going upstairs", "heading to the upper deck" },
  { "going downstairs", "heading down to the workshop" },
  { "my wife", "my better half" },
  { "the kids", "the little sprockets" },
  { "my kids", "my little sprockets" },
  { "that's weird", "how peculiar" },
  { "thats weird", "how peculiar" },
  { "so weird", "most peculiar" },
  { "i'm dead", "I've been decommissioned" },
  { "im dead", "I've been decommissioned" },
  { "found a bug", "found a gremlin in the works" },
  { "see you later", "until the next shift" },
  { "see ya later", "until the next shift" },
  { "later guys", "until the next shift, chums" },
  { "what level", "what model number" },
})
addMore("human", {
  probably = "most likely", prolly = "most likely", tonight = "this night", tomorrow = "on the morrow",
  upstairs = "to the upper floor", downstairs = "to the lower floor", wife = "good wife",
  husband = "good husband", laptop = "travelling tome", desktop = "great tome", pc = "tome",
  game = "realm", bugs = "curses", fix = "mend", crash = "calamity", laggy = "sluggish as a mule",
  dead = "slain", died = "fell", heck = "blast it", whoops = "a misstep", job = "trade",
  dog = "hound", cat = "mouser", bbl = "I shall return anon",
}, {
  { "steam deck", "pocket tome" },
  { "a fix", "mending" },
  { "its probably", "it is probably" },
  { "its kinda", "it is kind of" },
  { "its really", "it is really" },
  { "its pretty", "it is pretty" },
  { "its gonna", "it is going to" },
  { "its going", "it is going" },
  { "its weird", "it is weird" },
  { "its cool", "it is fine" },
  { "jumped on", "took up" },
  { "give me a sec", "a moment, if you please" },
  { "gimme a sec", "a moment, if you please" },
  { "one sec", "a moment" },
  { "hold on", "hold fast" },
  { "i think", "methinks" },
  { "let me check", "let me see" },
  { "lemme check", "let me see" },
  { "be right back", "I shall return shortly" },
  { "going upstairs", "away to the upper floor" },
  { "going downstairs", "away to the lower floor" },
  { "my wife", "my lady wife" },
  { "my kids", "my children" },
  { "that's weird", "how strange" },
  { "thats weird", "how strange" },
  { "so weird", "most strange" },
  { "i'm dead", "I have fallen" },
  { "im dead", "I have fallen" },
  { "found a bug", "found a curse upon it" },
  { "see you later", "until we meet again" },
  { "see ya later", "until we meet again" },
  { "later guys", "farewell, friends" },
})
addMore("dwarf", {
  probably = "likely as not", prolly = "likely as not", tonight = "the night", tomorrow = "the morra",
  wife = "missus", husband = "auld man", bugs = "gremlins", fix = "hammer out", crash = "cave-in",
  dead = "deid", died = "snuffed it", heck = "by me beard", whoops = "och", job = "graft",
  dog = "mutt", laggy = "slow as a stubborn mule",
}, {
  { "i think", "I reckon" },
  { "hold on", "haud on" },
  { "give me a sec", "gie us a tick" },
  { "gimme a sec", "gie us a tick" },
  { "my wife", "the missus" },
  { "that's weird", "that's a rum one" },
  { "thats weird", "that's a rum one" },
  { "i'm dead", "I'm deid" },
  { "im dead", "I'm deid" },
  { "see you later", "see ye after" },
  { "later guys", "cheerio, lads" },
})
addMore("nightelf", {
  tonight = "beneath tonight's moon", tomorrow = "when the sun returns", wife = "beloved",
  husband = "beloved", bugs = "blights", fix = "heal", dead = "returned to the earth", died = "fell",
  heck = "by Elune", whoops = "forgive my clumsiness",
}, {
  { "i think", "I sense" },
  { "hold on", "be still a moment" },
  { "that's weird", "how curious" },
  { "thats weird", "how curious" },
  { "see you later", "until the moon rises again" },
  { "later guys", "Ishnu-dal-dieb, friends" },
})
addMore("skyborne", {
  tonight = "under tonight's sky", tomorrow = "on tomorrow's wind", upstairs = "up to the high perch",
  downstairs = "down to the low roost", bugs = "storm-gremlins", dead = "grounded for good",
  died = "fell from the sky", heck = "by feather and gale", whoops = "a wing-slip",
}, {
  { "i think", "the wind tells me" },
  { "hold on", "hold your feathers" },
  { "that's weird", "how strange the winds blow" },
  { "thats weird", "how strange the winds blow" },
  { "see you later", "fair winds till we meet" },
  { "later guys", "fair winds, friends" },
  { "going upstairs", "flying up to the high perch" },
})

-- v0.13: from the 2026-11-21 capture
-- misspellings that should read like the real word, in every voice
local SAME_AS = { awsome = "awesome", awsum = "awesome", awesom = "awesome", naw = "nah", nahh = "nah" }
local function copySame(words)
  for k, real in pairs(SAME_AS) do
    if words[k] == nil and words[real] ~= nil then words[k] = words[real] end
  end
end
copySame(CORE.words)
for _, st in pairs(STYLES) do copySame(st.words) end

-- "brb" and friends start a sentence, so they end with a comma:
-- "brb gotta feed the dogs" -> "Back in a tick, must feed the dogs."
local LEADS = { "brb", "bbl", "afk", "gtg", "g2g" }
local function addComma(v)
  if type(v) == "string" then
    if v:find("[%w']$") then return v .. "," end
    return v
  end
  local out = {}
  for i, x in ipairs(v) do out[i] = addComma(x) end
  return out
end
local function commaLeads(words)
  for _, k in ipairs(LEADS) do
    if words[k] ~= nil then words[k] = addComma(words[k]) end
  end
end
commaLeads(CORE.words)
for _, st in pairs(STYLES) do commaLeads(st.words) end

-- "quest" as something you do, not a thing you're given
local function questVerbs(go)
  return {
    { "i quest", "I " .. go }, { "we quest", "we " .. go }, { "you quest", "you " .. go },
    { "can quest", "can " .. go }, { "lets quest", "let's " .. go }, { "let's quest", "let's " .. go },
    { "need to quest", "need to " .. go }, { "want to quest", "want to " .. go },
    { "wanna quest", "want to " .. go }, { "go quest", go }, { "gonna quest", "going " .. go:gsub("^go ", "") },
    { "going to quest", "going " .. go:gsub("^go ", "") }, { "ill quest", "I'll " .. go },
    { "i'll quest", "I'll " .. go }, { "will quest", "will " .. go },
  }
end
addMore("gnome", nil, questVerbs("go adventuring"))
addMore("human", nil, questVerbs("go adventuring"))
addMore("dwarf", nil, questVerbs("go adventurin'"))
addMore("nightelf", nil, questVerbs("go wandering"))
addMore("skyborne", nil, questVerbs("go adventuring"))

-- v0.15: from the 2026-11-21 late capture
addMore("gnome", { hopefully = "with any luck" }, { { "i have no idea", "I haven't the foggiest" }, { "i got no idea", "I haven't the foggiest" } })
addMore("human", { hopefully = "God willing" }, { { "i have no idea", "I know not" } })
addMore("dwarf", { hopefully = "wi' any luck" }, { { "i have no idea", "I've nae idea" } })
addMore("nightelf", { hopefully = "Elune willing" }, { { "i have no idea", "that knowledge eludes me" } })
addMore("skyborne", { hopefully = "winds willing" }, { { "i have no idea", "the winds haven't told me" } })

-- v0.18: from the 2026-11-22 desktop capture. setPhrase replaces a phrase
-- a voice already has (addMore only adds new ones).
local function setPhrase(name, from, to)
  local st = STYLES[name]
  if not st then return end
  for _, p in ipairs(st.phrases) do
    if p[1] == from then p[2] = to return end
  end
  st.phrases[#st.phrases + 1] = { from, to }
end
local function setPhrases(name, list)
  for _, p in ipairs(list) do setPhrase(name, p[1], p[2]) end
end
-- "good luck" mid-sentence ("good luck on your adventures") is good fortune
for _, name in ipairs({ "gnome", "human", "dwarf", "nightelf", "skyborne" }) do
  setPhrases(name, {
    { "good luck on", "good fortune on" }, { "good luck with", "good fortune with" },
    { "good luck in", "good fortune in" }, { "good luck to", "good fortune to" },
    { "best of luck", "good fortune" },
  })
end
setPhrases("gnome", {
  { "im ready", "I'm ready and calibrated" }, { "i'm ready", "I'm ready and calibrated" },
  { "im sorry", "I'm terribly sorry" }, { "i'm sorry", "I'm terribly sorry" },
  { "heck yeah", "gears and sprockets, yes" }, { "heck yes", "gears and sprockets, yes" },
  { "real quick", "in a jiffy" }, { "get tired", "start running low on steam" },
})
setPhrases("human", {
  { "im sorry", "forgive me" }, { "i'm sorry", "forgive me" },
  { "heck yeah", "aye, by the Light" }, { "heck yes", "aye, by the Light" },
  { "real quick", "with haste" }, { "get tired", "grow weary" },
})
setPhrases("dwarf", {
  { "im sorry", "I'm right sorry" }, { "i'm sorry", "I'm right sorry" },
  { "heck yeah", "och, aye" }, { "heck yes", "och, aye" }, { "real quick", "quick as ye like" },
  { "get tired", "get dead on me feet" },
})
setPhrases("nightelf", {
  { "im sorry", "I beg your pardon" }, { "i'm sorry", "I beg your pardon" },
  { "heck yeah", "indeed, by Elune" }, { "heck yes", "indeed, by Elune" },
})
setPhrases("skyborne", {
  { "im sorry", "I'm sorry, truly" }, { "i'm sorry", "I'm sorry, truly" },
  { "heck yeah", "by feather and gale, yes" }, { "heck yes", "by feather and gale, yes" },
  { "get tired", "grow wing-weary" },
})
SAME_AS.upstiars = "upstairs"; SAME_AS.upstars = "upstairs"; SAME_AS.downstiars = "downstairs"
copySame(CORE.words)
for _, st in pairs(STYLES) do copySame(st.words) end

-- v0.19: from a friend's human paladin capture
for k, v in pairs({ beleive = "believe", belive = "believe", firends = "friends", freinds = "friends",
  ["letr's"] = "let's" }) do
  if CORE.words[k] == nil then CORE.words[k] = v end
end
SAME_AS.firends = "friends"; SAME_AS.freinds = "friends"; SAME_AS.frend = "friend"
SAME_AS.beleive = "believe"; SAME_AS.belive = "believe"
copySame(CORE.words)
for _, st in pairs(STYLES) do copySame(st.words) end
local CIAO = { human = "farewell", gnome = "toodle-oo", dwarf = "cheerio", nightelf = "farewell",
  skyborne = "fly safe" }
local NICE_WORK = { human = "fine work", gnome = "splendid work", dwarf = "braw work",
  nightelf = "well done", skyborne = "lovely work" }
for name, w in pairs(NICE_WORK) do
  setPhrases(name, { { "nice work", w }, { "nice job", w } })
end
for name, bye in pairs(CIAO) do
  addMore(name, { ciao = bye }, nil)
  setPhrases(name, { { "here here", "hear, hear" }, { "what up", (function()
    for _, p in ipairs(STYLES[name].phrases) do if p[1] == "whats up" then return p[2] end end
    return "what news"
  end)() }, { "got cha", "understood" } })
end

-- v0.21: from the Loch Modan run. Oaths that read as one thought, and a few typos.
for name, s in pairs({
  human = { yes = "aye, by the Light", no = "by the Light, no", it = "confound it", what = "what in the Light's name" },
  gnome = { yes = "gears and sprockets, yes", no = "gears and sprockets, no", it = "blast it",
    what = "what in the name of all gears" },
  dwarf = { yes = "och, aye", no = "nae chance", it = "och, blast it", what = "what in the Titans' name" },
  nightelf = { yes = "indeed, by Elune", no = "never, by Elune", it = "curses", what = "what by Elune's light" },
  skyborne = { yes = "by feather and gale, yes", no = "by feather and gale, no", it = "storms take it",
    what = "what in the storms" },
}) do
  local list = {}
  for _, a in ipairs({ "hell", "heck" }) do
    for _, b in ipairs({ "yeah", "yes", "yea", "ya", "yah" }) do list[#list + 1] = { a .. " " .. b, s.yes } end
    list[#list + 1] = { a .. " no", s.no }; list[#list + 1] = { a .. " nah", s.no }
    list[#list + 1] = { "what the " .. a, s.what }
  end
  for _, d in ipairs({ "damn it", "dammit", "damnit", "dang it", "darn it", "crap it" }) do
    list[#list + 1] = { d, s.it }
  end
  setPhrases(name, list)
  local st = STYLES[name]
  if st and st.words.shit == nil then st.words.shit = st.words.crap or st.words.damn end
end
for _, name in ipairs({ "gnome", "human", "dwarf", "nightelf", "skyborne" }) do
  local st = STYLES[name]
  if st then
    for _, p in ipairs(st.phrases) do
      if p[1] == "holy crap" then setPhrase(name, "holy shit", p[2]) break end
    end
  end
end
-- "well shit okay" -> "Well, blast. Very well."
for name, w in pairs({ human = { "well, blast", "very well" }, gnome = { "well, drat", "right-o" },
  dwarf = { "well, och", "aye, fair enough" }, nightelf = { "well, curses", "so be it" },
  skyborne = { "well, storms take it", "as the wind wills" } }) do
  local list = {}
  for _, c in ipairs({ "shit", "damn", "crap", "dang", "heck", "hell" }) do
    list[#list + 1] = { "well " .. c, w[1] }
    for _, ok in ipairs({ "okay", "ok", "alright", "fine" }) do
      list[#list + 1] = { "well " .. c .. " " .. ok, w[1] .. ". " .. w[2] }
    end
  end
  setPhrases(name, list)
end
for k, v in pairs({ naye = "nay", alredy = "already", alreday = "already", allready = "already",
  thoguht = "thought", thougt = "thought", thoght = "thought", thougth = "thought" }) do
  if CORE.words[k] == nil then CORE.words[k] = v end
end
for k, v in pairs({ alredy = "already", alreday = "already", allready = "already", thoguht = "thought",
  thougt = "thought", thoght = "thought", thougth = "thought" }) do SAME_AS[k] = v end
copySame(CORE.words)
for _, st in pairs(STYLES) do copySame(st.words) end

-- v0.22: from the 2026-11-22 laptop capture
-- "tired" has to work as a plain adjective: "getting tired", "hey there tired man"
STYLES.gnome.words.tired = "weary"; STYLES.gnome.words.sleepy = "weary"
STYLES.dwarf.words.tired = "knackered"
setPhrases("gnome", { { "get tired", "start winding down" }, { "drop rate", "drop odds" },
  { "getting tired", "winding down" }, { "i think", "I reckon" }, { "working on", "tinkering away at" } })
setPhrases("dwarf", { { "get tired", "get knackered" } })
-- "okay so ..." is a sentence start, not an answer
for name, w in pairs({ human = "well then, so", gnome = "right, so", dwarf = "right then, so",
  nightelf = "very well, so", skyborne = "alright, so" }) do
  setPhrases(name, { { "okay so", w }, { "ok so", w }, { "alright so", w } })
end
-- "thank you friend" -> "My gratitude, old sprocket" (with the comma)
local function styleWord(st, key)
  local v = st.words[key]
  if v == nil and st.base and STYLES[st.base] then v = STYLES[st.base].words[key] end
  return v
end
local function stylePhrase(st, key)
  for _, p in ipairs(st.phrases) do if p[1] == key then return p[2] end end
  local b = st.base and STYLES[st.base]
  if b then for _, p in ipairs(b.phrases) do if p[1] == key then return p[2] end end end
end
local function asList(v) if type(v) == "table" then return v elseif v then return { v } end return {} end
for _, name in ipairs({ "gnome", "human", "dwarf", "nightelf", "skyborne" }) do
  local st = STYLES[name]
  local thanks = asList(stylePhrase(st, "thank you"))
  if st and #thanks > 0 then
    local list = {}
    for _, who in ipairs({ "friend", "bro", "buddy", "dude", "man", "mate", "pal", "guys", "friends" }) do
      local reps = {}
      for _, t in ipairs(thanks) do
        local f = asList(styleWord(st, who))
        local fw = f[1] or who
        -- dwarf "cheers, lad" already names them: no "cheers, lad, lad"
        local last = (t:match("([%a']+)$") or ""):lower()
        local named = last == fw:lower() or last == "lad" or last == "lass" or last == "friend" or last == "chum"
        for _, x in ipairs(f) do if last == x:lower() then named = true end end
        if not t:find("^%*") then reps[#reps + 1] = (named and t or (t .. ", " .. fw)) .. "\003" end
      end
      if #reps > 0 then
        for _, th in ipairs({ "thank you", "thanks", "thx", "ty" }) do list[#list + 1] = { th .. " " .. who, reps } end
      end
    end
    setPhrases(name, list)
  end
end
for k, v in pairs({ finsihed = "finished", finshed = "finished", finised = "finished", finsih = "finish",
  evertually = "eventually", eventualy = "eventually", evntually = "eventually", talan = "talon" }) do
  if CORE.words[k] == nil then CORE.words[k] = v end
end

-- v0.23: "thank you kind sir" keeps the sir and drops the "lad"
for name, t in pairs({ human = "my thanks", gnome = "many thanks", dwarf = "cheers",
  nightelf = "I am grateful", skyborne = "my thanks" }) do
  local list = {}
  for _, th in ipairs({ "thank you", "thanks", "ty", "thx" }) do
    for _, who in ipairs({ "kind sir", "good sir", "sir", "kind lady", "my lady", "lady", "ma'am", "maam",
      "madam", "miss" }) do
      local out = who
      if who == "maam" then out = "ma'am" end
      list[#list + 1] = { th .. " " .. who, t .. ", " .. out .. "\003" }
    end
  end
  setPhrases(name, list)
end

-- v0.24: "better then engineering" -> "better than engineering"
for _, name in ipairs({ "gnome", "human", "dwarf", "nightelf", "skyborne" }) do
  local list = {}
  for _, w in ipairs({ "better", "worse", "more", "less", "rather", "faster", "slower", "bigger",
    "smaller", "higher", "lower", "older", "younger", "easier", "harder", "stronger", "other" }) do
    list[#list + 1] = { w .. " then", w .. " than" }
  end
  setPhrases(name, list)
end

local ALIAS = { medieval = "human", knight = "human", nelf = "nightelf", elf = "nightelf",
                kaldorei = "nightelf", nightelves = "nightelf", dwarves = "dwarf", gnomes = "gnome",
                humans = "human", sky = "skyborne" }
local STYLE_ORDER = { "human", "dwarf", "nightelf", "gnome", "skyborne" }

-- UnitRace("player") gives a race token like "NightElf"; this picks the voice.
-- Races without their own voice use the closest one, or Human.
-- WoW: Forever's Alliance races; Horde characters use Human for now.
local RACE_STYLE = {
  Human = "human", Dwarf = "dwarf", NightElf = "nightelf", Gnome = "gnome",
}

-- A style with `base` borrows every word and phrase it does not define itself.
for _, st in pairs(STYLES) do
  local base = st.base and STYLES[st.base]
  if base then
    for k, v in pairs(base.words) do
      if st.words[k] == nil then st.words[k] = v end
    end
    local have = {}
    for _, p in ipairs(st.phrases) do have[p[1]] = true end
    for _, p in ipairs(base.phrases) do
      if not have[p[1]] then st.phrases[#st.phrases + 1] = p end
    end
    st.flair = st.flair or base.flair
  end
end

-- Longer phrases first, so "thank you so much" wins over "thank you"
-- whichever list it came from.
for _, st in pairs(STYLES) do
  for i, p in ipairs(st.phrases) do p.order = i end
  table.sort(st.phrases, function(a, b)
    if #a[1] ~= #b[1] then return #a[1] > #b[1] end
    return a.order < b.order
  end)
end

local function styleName(name)
  if type(name) ~= "string" then return nil end
  name = name:lower():gsub("[%s_%-']", "")
  name = ALIAS[name] or name
  if STYLES[name] then return name end
end

local function raceStyle()
  if not UnitRace then return nil, nil end
  local ok, localized, token = pcall(UnitRace, "player")
  if not ok or not token then return nil, nil end
  -- Skyborne appear on both factions; match the token loosely in case it is
  -- something like "SkyborneHighOrder"
  if token:lower():find("skyborne") or (localized and localized:lower():find("skyborne")) then
    return "skyborne", localized
  end
  return RACE_STYLE[token] or "human", localized
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------
local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-- "thank you" -> "[tT][hH][aA][nN][kK] [yY][oO][uU]" (case-insensitive pattern)
local function ciPattern(s)
  s = s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
  return (s:gsub("%a", function(c)
    return "[" .. c:lower() .. c:upper() .. "]"
  end))
end

-- Keep the capitalisation style of the original word.
local function matchCase(original, replacement)
  if replacement:sub(1, 1) == "*" then return replacement end
  if #original > 1 and original == original:upper() and original:find("%a") then
    return replacement:upper()
  end
  if original:sub(1, 1):match("%u") then
    return replacement:sub(1, 1):upper() .. replacement:sub(2)
  end
  return replacement
end

-- A replacement is a string or a list of strings. Lists pick at random,
-- avoiding the option used last time for the same word.
local lastPick = {}
local function pick(key, v)
  if type(v) ~= "table" then return v end
  local n = #v
  if n == 0 then return nil end
  if n == 1 then return v[1] end
  local i = math.random(n)
  if i == lastPick[key] then i = i % n + 1 end
  lastPick[key] = i
  return v[i]
end

-- Swaps from CustomWords.lua (keys lower-cased when the add-on loads).
local fileWords = {}
local function loadFileWords()
  fileWords = {}
  local src = RPChat_CustomWords
  if type(src) ~= "table" then return 0 end
  local n = 0
  for k, v in pairs(src) do
    if type(k) == "string" and (type(v) == "string" or type(v) == "table") then
      fileWords[k:lower()] = v
      n = n + 1
    end
  end
  return n
end

---------------------------------------------------------------------------
-- Class flavour (v0.12): picked from UnitClass("player").
-- words/phrases are swapped before your voice's own; banter lines join
-- /rp banter. Per-voice lists cover the race/class pairs Forever allows.
---------------------------------------------------------------------------
local CLASS = {
  WARRIOR = {
    words = { rage = "fury" },
    phrases = {
      { "i'll tank", "I'll hold the line" }, { "ill tank", "I'll hold the line" },
      { "i can tank", "I can hold the line" }, { "out of rage", "my fury is spent" },
    },
    banter = {
      any = {
        "A dull blade is a dead warrior's blade. Sharpen yours tonight.",
        "Stay behind me. That's all I ask.",
        "Every scar has a story. Most of mine are about poor decisions.",
        "*rolls stiff shoulders and checks the straps on a shield*",
        "Rest now. Tomorrow I'll need all my fury.",
      },
      human = { "My old drill sergeant would weep to see my footwork now. With pride, I hope.",
                "Stormwind steel never fails. The arm swinging it sometimes does." },
      dwarf = { "Give me a good axe an' a narrow pass, an' I'll hold it till the mountains crumble.",
                "Ach, me shield's got more dents than a Thunderbrew keg." },
      nightelf = { "The Sentinels taught me patience. The battlefield taught me the rest.",
                   "My glaive has sung in these woods for longer than you have been alive." },
      gnome = { "People laugh at a gnome warrior. Then they look down. Way down. Too late.",
                "I've reinforced my armor with a few springs. For bounce, you understand." },
      skyborne = { "The wind at my back, a blade in my talons. What else does a warrior need?",
                   "I fight on the ground, but my heart still dives like a falcon." },
    },
  },
  PALADIN = {
    words = { bubble = "divine shield", bubbled = "shielded by the Light" },
    phrases = { { "i'll heal", "the Light will mend you" }, { "ill heal", "the Light will mend you" },
                { "need a heal", "need the Light's mending" } },
    banter = {
      any = {
        "May the Light guide our steps tomorrow, as it did today.",
        "*kneels by the fire in silent prayer*",
        "Justice is a heavy hammer. I am grateful for strong arms.",
        "The Light asks little of us. Courage, mercy, and a clean blade.",
        "I sense no evil here tonight. Rest easy, friends.",
      },
      human = { "I took my oaths in the Cathedral of Light. I mean to keep every one.",
                "The Silver Hand stands for all who cannot stand for themselves." },
      dwarf = { "The Light an' a good hammer. Never met a problem that couldnae fix.",
                "Me grandda was a priest. Me da was a smith. So I hit things holy." },
    },
  },
  HUNTER = {
    words = { pet = "companion", pets = "companions", ammo = "arrows" },
    phrases = { { "my pet", "my loyal companion" }, { "feed my pet", "tend my companion" },
                { "out of ammo", "my quiver is empty" } },
    banter = {
      any = {
        "*scratches a loyal companion behind the ears*",
        "Tracks are fresh. Something big came through here at dusk.",
        "Quiet now. The forest tells you everything if you stop talking.",
        "My companion eats better than I do. As it should be.",
        "A true hunter takes only what is needed. And maybe a nice pelt.",
      },
      human = { "Elwynn's woods taught me to track. Its wolves taught me to run.",
                "Not many folk from Stormwind take up the bow. More fool them." },
      dwarf = { "Ye've never lived till ye've tracked a ram across Dun Morogh in a blizzard.",
                "Me rifle an' me beast. Best two companions a dwarf could ask for." },
      nightelf = { "My nightsaber and I have shared ten thousand moonlit hunts.",
                   "Elune guides the arrow. I simply let it go." },
      skyborne = { "From above, every rabbit is a target. From down here, they're just cute.",
                   "My hawk sees farther than any spyglass. Don't you, beautiful?" },
    },
  },
  ROGUE = {
    words = { stealth = "the shadows", stealthed = "hidden in shadow", stealthing = "slipping through the shadows" },
    phrases = { { "going in", "slipping into the shadows" }, { "i'll sap", "I'll quietly sap" },
                { "ill sap", "I'll quietly sap" }, { "picked a lock", "persuaded a lock" },
                { "pick the lock", "persuade the lock" }, { "pick pocket", "relieve them of a purse" },
                { "pickpocket", "relieve them of a purse" } },
    banter = {
      any = {
        "*idly spins a dagger between two fingers*",
        "Nobody ever looks up. Or down. Or behind them. Honestly, it's too easy.",
        "I didn't take it. It fell into my pocket. Repeatedly.",
        "Keep your voice down. Shadows have ears, and I'm usually one of them.",
        "A locked door is just a polite suggestion.",
        "*counts a small pile of coins, then counts them again*",
      },
      human = { "SI:7 never officially hired me. That's what makes me so good.",
                "Stormwind's alleys taught me more than any schoolmaster ever did." },
      dwarf = { "Aye, a dwarf rogue. Ye'd be amazed what ye can hide in a beard.",
                "Light on me feet? Lad, I'm stone-silent when I need tae be." },
      nightelf = { "In the dark, I am home. You are merely visiting.",
                   "The moon hides me well. Elune has a sense of humor." },
      gnome = { "Small, quiet, and very, very pointy. The perfect design.",
                "I've built a lockpick that picks the lock and leaves a polite note.",
                "Most folk never see me coming. Most folk never see me at all, frankly." },
      skyborne = { "I drop from the clouds. Nobody watches the clouds.",
                   "My feathers make no sound. Shame about my laughing." },
    },
  },
  PRIEST = {
    words = { heals = "mending", heal = "mend", healer = "mender" },
    phrases = { { "i'll heal", "I shall tend your wounds" }, { "ill heal", "I shall tend your wounds" },
                { "need heals", "need mending" }, { "oom", "my spirit is spent" } },
    banter = {
      any = {
        "*bows head and murmurs a quiet blessing over the group*",
        "Every wound I mend reminds me how fragile we all are.",
        "Faith is the light you carry when you can't see the road.",
        "Please, stand in front of me. Not because I'm afraid. Mostly.",
        "Bring me your bruises. I've had worse days than yours.",
      },
      human = { "The Cathedral bells will ring tonight. I hear them even out here.",
                "The Light is in all of us. Some just keep it better hidden." },
      dwarf = { "The Light shines even deep under the mountain, lad.",
                "I'll heal ye, but ye're payin' for the ale." },
      nightelf = { "The Sisters of Elune say every star is a soul at rest.",
                   "Moonlight heals what steel has broken." },
      gnome = { "A gnome priest! Yes, yes, we exist. The Light needed someone to fix its gears.",
                "I've calibrated my prayers for maximum efficiency. Mostly." },
    },
  },
  SHAMAN = {
    words = { totem = "spirit totem", totems = "spirit totems" },
    phrases = { { "drop totems", "call upon the totems" }, { "i'll heal", "the spirits will mend you" },
                { "ill heal", "the spirits will mend you" } },
    banter = {
      any = {
        "*presses one palm to the earth and listens*",
        "The elements are restless tonight. Can you feel it?",
        "Fire, water, earth and air. Respect them, and they'll answer.",
        "The spirits speak of friends around a fire. That's a good omen.",
      },
      dwarf = { "Earth's in me blood. Always has been. The spirits just took a while tae say hello.",
                "Stone remembers everything, lad. Ye just have tae ask it nicely." },
    },
  },
  MAGE = {
    words = { port = "portal", ports = "portals", sheep = "polymorph", sheeped = "polymorphed" },
    phrases = { { "need water", "shall I conjure water" }, { "want water", "shall I conjure water" },
                { "i'll sheep", "I'll turn one into a sheep" }, { "ill sheep", "I'll turn one into a sheep" },
                { "out of mana", "my arcane reserves are spent" } },
    banter = {
      any = {
        "*conjures a small flame and lets it dance across the knuckles*",
        "Anyone need water? I'm practically a fountain.",
        "The arcane is all mathematics. Very angry mathematics.",
        "I could warm this camp with a thought. But a real fire has charm.",
        "Don't touch the glowing book. Please.",
      },
      human = { "Dalaran's libraries hold more secrets than any vault.",
                "I studied six years to make a sheep out of a man. Worth every hour." },
      gnome = { "Arcane plus engineering equals results. Occasionally on fire.",
                "I once polymorphed my own toolbox. It's still a very nice sheep." },
      skyborne = { "Magic is like the wind. You can't hold it, only shape where it blows.",
                   "I'd teleport us home, but flying is half the fun." },
    },
  },
  WARLOCK = {
    words = { pet = "demon", pets = "demons", shards = "soul shards", shard = "soul shard" },
    phrases = { { "my pet", "my bound demon" }, { "i'll summon", "I shall open the summoning circle" },
                { "ill summon", "I shall open the summoning circle" }, { "need summons", "need the ritual" } },
    banter = {
      any = {
        "*whispers to a small, glowing shard that seems to whisper back*",
        "Don't mind my imp. He bites, but only people I don't like.",
        "Power has a price. I always read the fine print.",
        "Yes, the fire is green. No, I won't explain.",
        "Everyone fears the dark until they need someone who understands it.",
      },
      human = { "Stormwind frowns on my studies. Stormwind also lets me summon its stragglers.",
                "I keep my soul shards in alphabetical order. Don't ask how." },
      gnome = { "A warlock is just an engineer whose parts complain.",
                "My felhunter keeps chewing my wrenches. Bad demon. Bad." },
    },
  },
  DRUID = {
    words = {},
    phrases = { { "cat form", "feline form" }, { "bear form", "ursine form" },
                { "travel form", "stag form" }, { "i'll heal", "nature will mend you" },
                { "ill heal", "nature will mend you" } },
    banter = {
      any = {
        "*runs fingers through the grass, then sniffs the air*",
        "The forest is healthy here. That's rare these days.",
        "Sometimes I sleep better as a bear. Don't take it personally.",
        "Balance in all things. Including dinner portions.",
      },
      nightelf = { "Cenarius taught us that every tree is a promise kept.",
                   "I dreamt of the Emerald Dream again. The colors never fade." },
      skyborne = { "Bird form? Please. I was a bird before it was a form.",
                   "Nature and sky are one song. I just hum the high notes." },
    },
  },
}

-- The player's class token (WARRIOR, ROGUE, ...), set at login.
R.playerClass = nil
local function classData() return R.playerClass and CLASS[R.playerClass] end
for _, cd in pairs(CLASS) do
  table.sort(cd.phrases, function(a, b) return #a[1] > #b[1] end)
end

local function lookup(db, key)
  if db.custom[key] ~= nil then return db.custom[key] end
  if fileWords[key] ~= nil then return fileWords[key] end
  if db.removed[key] then return nil end
  local cd = classData()
  if cd and cd.words[key] ~= nil then return cd.words[key] end
  local st = STYLES[db.style] or STYLES.gnome
  return st.words[key] or CORE.words[key]
end

---------------------------------------------------------------------------
-- The transform
---------------------------------------------------------------------------
-- Item links, colour codes and icons must reach the server byte-for-byte,
-- so they are swapped out for placeholders while words are rewritten.
local PROTECT = {
  "|c.-|r",                   -- coloured text / item links (|cffRRGGBB and the new |cnIQ4: style)
  "|H.-|h.-|h",               -- bare hyperlinks
  "|T.-|t",                   -- textures
  "|A.-|a",                   -- atlas icons (e.g. crafting quality)
  "|K.-|k",                   -- Battle.net names
  "|%a",                      -- any other escape code left on its own
  "{[^}]+}",                  -- raid markers like {star}
  "https?://%S+",             -- web links
}

-- v0.15: answers that only make sense at the start of a sentence
-- ("no" in "they were no help" stays "no"), and openers that take a comma.
local START_ONLY = { no = true, nope = true, nah = true, naw = true, nahh = true,
  k = true, kk = true, ok = true, okay = true, alright = true, aight = true }
-- v0.20: short forms that are also ordinary words
local PLACE_ONLY = { ah = true }
local PLACE_BEFORE = { the = true, to = true, at = true, on = true, ["in"] = true, from = true,
  by = true, via = true, near = true, outside = true, inside = true }
-- v0.19: "nice" before a noun is an adjective, not an exclamation
local NICE_ADJ = { nice = true }
local NICE_ADJ_BY_STYLE = { human = "fine", gnome = "splendid", dwarf = "braw", nightelf = "graceful",
  skyborne = "lovely" }
local NOT_NOUN = { to = true, as = true, of = true, but = true, ["if"] = true,
  when = true, now = true, though = true, too = true, guys = true, everyone = true, all = true, man = true }
local OPENERS = { sry = true, srry = true, soz = true, sorry = true }
-- a line that starts with one of these is a question, even without the "?"
local QUESTION = { how = true, what = true, where = true, why = true, who = true, whos = true,
  when = true, which = true, is = true, are = true, can = true, could = true, does = true,
  did = true, would = true, should = true, was = true, were = true, wanna = true }

-- v0.21: "do you need help" is a question too, but "do it" and "have fun" are not
local QUESTION_IF_WHO = { ["do"] = true, have = true, has = true, will = true, shall = true, am = true,
  may = true, might = true, dont = true, ["don't"] = true, cant = true, ["can't"] = true, wont = true,
  ["won't"] = true, isnt = true, ["isn't"] = true, arent = true, ["aren't"] = true, doesnt = true,
  ["doesn't"] = true, didnt = true, ["didn't"] = true }
-- "care to group?", "want to duel?", "anyone up for stocks?"
-- v0.24: "hey team how goes the evening" asks a question after the greeting
local QUESTION_ANYWHERE = { "how goes", "how are you", "how are ya", "how are u", "how r u", "how's it",
  "hows it", "how is it", "how have you", "how was your", "how was the", "how you doing", "how ya doing",
  "what's up", "whats up", "wanna group", "want to group", "you there", "you around" }
-- v0.24: capitalised short forms for places ("fly to IF") are only expanded in capitals
local CAPS_PLACE = { IF = "Ironforge", SW = "Stormwind", BB = "Booty Bay", SFK = "Shadowfang Keep",
  RFC = "Ragefire Chasm", WC = "Wailing Caverns", BFD = "Blackfathom Deeps", SM = "Scarlet Monastery",
  STV = "Stranglethorn Vale", RFK = "Razorfen Kraul", RFD = "Razorfen Downs", ZF = "Zul'Farrak",
  BRD = "Blackrock Depths", UBRS = "Upper Blackrock Spire", LBRS = "Lower Blackrock Spire",
  ST = "the Sunken Temple", ULD = "Uldaman", GNOMER = "Gnomeregan" }
local QUESTION_IF_TO = { care = true, want = true, wanna = true }
local QUESTION_ALWAYS = { anyone = true, anybody = true }
local WANT_NEXT = { to = true, some = true, any = true, a = true, an = true, me = true, this = true, that = true }
local WHO = { you = true, u = true, ya = true, ye = true, we = true, i = true, they = true, he = true,
  she = true, anyone = true, anybody = true, someone = true, everyone = true, yall = true, ["y'all"] = true }
local ITS_IS = { super = true, so = true, ["not"] = true, ok = true, okay = true, fine = true, all = true,
  just = true, really = true, still = true, too = true, very = true, getting = true, gonna = true,
  ["in"] = true, on = true, over = true, up = true, here = true, there = true, late = true, fun = true,
  hard = true, easy = true, kinda = true, pretty = true, only = true, always = true, never = true,
  been = true, almost = true, like = true, about = true, worth = true, cool = true, weird = true }
-- v0.21: place names are never rewritten ("the Great Forge" is not "the Splendid Forge"),
-- typed in any case. Two Capitalised words in a row mid-sentence are treated as a name too.
local PLACES = { "great forge", "booty bay", "loch modan", "dun modr", "dun morogh", "dun algaz",
  "deeprun tram", "elwynn forest", "redridge mountains", "menethil harbor", "thandol span",
  "grim batol", "stonewrought dam", "molten core", "burning steppes", "searing gorge", "blasted lands",
  "swamp of sorrows", "thousand needles", "dark portal", "scarlet monastery", "shadowfang keep",
  "ragefire chasm", "wailing caverns", "blackfathom deeps", "razorfen kraul", "razorfen downs",
  "sunken temple", "dire maul", "blackrock depths", "blackrock spire", "blackrock mountain",
  "lion's pride inn", "sentinel hill", "darkmoon faire", "trade district", "dwarven district",
  "mystic ward", "military ward", "hall of explorers", "tinker town", "old town", "cathedral square",
  "mage quarter", "valley of heroes", "valley of trials", "throne of the tides", "eastern kingdoms",
  "twilight grove", "the great sea", "stormwind", "ironforge", "darnassus", "deadmines", "stockade",
  "wetlands", "westfall", "duskwood", "goldshire", "lakeshire", "thelsamar", "kharanos", "gnomeregan",
  "uldaman", "hinterlands", "badlands", "stranglethorn", "darkshore", "ashenvale", "stonetalon",
  "teldrassil", "auberdine", "astranaar", "feralas", "tanaris", "silithus", "winterspring",
  "felwood", "azshara", "desolace", "dustwallow", "southshore", "hillsbrad", "arathi", "alterac" }
table.sort(PLACES, function(a, b) return #a > #b end)
-- v0.23: places people often type as two words or misspell
local PLACE_FIX = { { "stone talan", "Stonetalon" }, { "stone talon", "Stonetalon" },
  { "stonetalan", "Stonetalon" }, { "loch modon", "Loch Modan" }, { "iron forge", "Ironforge" },
  { "storm wind", "Stormwind" }, { "wet lands", "Wetlands" }, { "dun morough", "Dun Morogh" },
  { "dun moroh", "Dun Morogh" }, { "darnasus", "Darnassus" }, { "gnomergan", "Gnomeregan" } }

function R.Transform(text, db, chatType)
  db = db or RPChatDB
  local opening = (text:match("^%s*([%a']+)") or ""):lower()
  local second = (text:match("^%s*[%a']+%s+([%a']+)") or ""):lower()
  local askedAnywhere = false
  do
    local low = " " .. text:lower():gsub("[^%w' ]", " ") .. " "
    for _, q in ipairs(QUESTION_ANYWHERE) do
      if low:find(" " .. q .. " ", 1, true) then askedAnywhere = true break end
    end
  end
  local saidWhatA = text:lower():find("^%s*what%s+an?%s") ~= nil   -- "what a fight" is no question
  local saved = {}
  local function stash(chunk)
    saved[#saved + 1] = chunk
    return "\001" .. #saved .. "\002"
  end
  for _, pat in ipairs(PROTECT) do
    text = text:gsub(pat, stash)
  end
  -- caps lock is not shouting outside /yell: "BRB GETTING BEER" reads as "brb getting beer"
  local allCaps = chatType ~= "YELL" and text:find("%a") and text == text:upper()
    and #(text:gsub("[^%a]", "")) > 1
  if allCaps then
    -- "SELLING ON AH" keeps its AH; "SFK" stays a dungeon
    text = text:gsub("[%a']+", function(w)
      if PLACE_ONLY[w:lower()] or (CAPS_PLACE[w] and w ~= "IF") then return w end
      return w:lower()
    end)
    if opening ~= "" then opening = opening:lower() end
  end
  for _, fix in ipairs(PLACE_FIX) do
    if text:lower():find(fix[1], 1, true) then
      text = text:gsub("%f[%w']" .. ciPattern(fix[1]) .. "%f[^%w']", function() return stash(fix[2]) end)
    end
  end
  for _, place in ipairs(PLACES) do
    if text:lower():find(place, 1, true) then
      text = text:gsub("%f[%w']" .. ciPattern(place) .. "%f[^%w']", function(m)
        -- "booty bay" -> "Booty Bay"; anything typed with capitals stays as typed
        if m == m:lower() then
          m = m:gsub("(%a)([%w']*)", function(a, b)
            if b == "of" or (a == "o" and b == "f") then return a .. b end
            return a:upper() .. b
          end)
          m = m:gsub("^The ", "the "):gsub(" Of ", " of "):gsub(" The ", " the ")
        end
        return stash(m)
      end)
    end
  end

  -- phrases (user phrases with spaces count too)
  local function doPhrase(from, to)
    if db.removed[from] then return end
    -- the result is stashed so the word pass below cannot rewrite it again
    text = text:gsub("%f[%w']" .. ciPattern(from) .. "%f[^%w']", function(m)
      local rep = pick(from, to)
      if not rep then return nil end
      return stash(matchCase(m, rep))
    end)
  end
  local st = STYLES[db.style] or STYLES.gnome
  local cd = classData()
  if cd then
    for _, p in ipairs(cd.phrases) do
      if db.custom[p[1]] == nil and fileWords[p[1]] == nil then doPhrase(p[1], p[2]) end
    end
  end
  for _, p in ipairs(st.phrases) do
    if db.custom[p[1]] == nil and fileWords[p[1]] == nil then doPhrase(p[1], p[2]) end
  end
  for from, to in pairs(db.custom) do
    if from:find(" ") then doPhrase(from, to) end
  end
  for from, to in pairs(fileWords) do
    if from:find(" ") and db.custom[from] == nil then doPhrase(from, to) end
  end

  -- single words
  text = text:gsub("()%f[%w']([%w']+)%f[^%w']()", function(pos, word, after)
    local key = word:lower()
    if CAPS_PLACE[word] then return CAPS_PLACE[word] end
    local first = START_ONLY[key] or OPENERS[key]
    -- "The Great Forge", "Booty Bay": a Capitalised word beside another mid-sentence is a name
    if word:find("^%u%l") then
      local before = text:sub(1, pos - 1)
      local midSentence = before:find("%S") and not before:find("[%.!%?]%s*$") and not before:find("^%s*%*[^%*]*%*%s*$")
      if midSentence then
        local nextWord = text:sub(after):match("^%s+([%w']+)")
        local prevWord = before:match("([%w']+)%s+$")
        local prevMid = prevWord and before:sub(1, #before - #(before:match("[%w']+%s+$"))):find("%S")
        if (nextWord and nextWord:find("^%u%l")) or (prevWord and prevWord:find("^%u%l") and prevMid) then
          return nil
        end
      end
    end
    local atStart, more
    if first then
      local before = text:sub(1, pos - 1)
      atStart = before:find("^%s*$") or before:find("[%.!%?,;:]%s*$")
      more = text:sub(after):find("^%s*[%w\001]")
      -- "they were no help" keeps its "no"; "no, thanks" and a lone "no" still change
      if START_ONLY[key] and not atStart and (more or before:find("%w")) then return nil end
    end
    -- "ah, you did it" stays "Ah"; "AH" or "the ah" is the auction house
    if PLACE_ONLY[key] and word ~= word:upper() then
      local prev = text:sub(1, pos - 1):match("([%a']+)%s*$")
      if not (prev and PLACE_BEFORE[prev:lower()]) then return nil end
    end
    -- "its super long" -> "it's super long"; "its turn" keeps "its"
    if key == "its" then
      local nextWord = text:sub(after):match("^%s+([%w']+)")
      if nextWord and ITS_IS[nextWord:lower()] then return matchCase(word, "it's") end
    end
    local rep
    if NICE_ADJ[key] and db.custom[key] == nil and fileWords[key] == nil and not db.removed[key] then
      -- "nice recovery" -> "fine recovery"; a lone "nice" stays an exclamation
      local nextWord = text:sub(after):match("^%s+([%w']+)")
      if nextWord and not NOT_NOUN[nextWord:lower()] then
        local st = STYLES[db.style] or STYLES.gnome
        rep = NICE_ADJ_BY_STYLE[db.style] or NICE_ADJ_BY_STYLE[st.base or ""] or "fine"
      end
    end
    rep = rep or pick(key, lookup(db, key))
    if not rep then return nil end
    if PLACE_ONLY[key] and word == word:upper() then
      -- "AH" is an abbreviation, not shouting: "Auction House"
      rep = rep:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end)
    else
      rep = matchCase(word, rep)
    end
    -- "sry tank is drinking" -> "Terribly sorry, bulwark is recharging", "nope not today" -> "Negative, not today"
    if first and atStart and more and rep:find("[%w']$") then rep = rep .. "," end
    return rep
  end)

  -- tidy up
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  -- a lone lower-case " i " becomes " I "
  text = text:gsub("%f[%w']i%f[^%w']", "I")
  -- restore links and phrases
  text = text:gsub("\001(%d+)\002", function(n) return saved[tonumber(n)] end)
  -- "thanks friend warmest I've ever been" -> "Much obliged, lad, warmest I've ever been"
  text = text:gsub("\003(%s+)([%w\"'])", ",%1%2"):gsub("\003", "")
  -- a line that ends on "brb," loses the comma
  text = text:gsub(",+%s*$", "")

  -- emotes read "Name waves.", so their first letter stays lower case
  if db.capitalize and chatType ~= "EMOTE" then
    text = text:gsub("^(%l)", string.upper)
    -- "*cackles* you still like it" -> "*cackles* You still like it"
    text = text:gsub("^(%*[^%*]+%*%s+)(%l)", function(a, b) return a .. b:upper() end)
    text = text:gsub("([%.!%?]%s+)(%l)", function(a, b) return a .. b:upper() end)
  end
  if db.punctuate and text:find("%a") and not text:find("[%.!%?%*%)\"']$")
     and not text:find("|[rhtak]$") then
    local exclaim = opening == "what" and saidWhatA
    if exclaim then text = text .. "!"
    elseif QUESTION[opening] or (QUESTION_IF_WHO[opening] and WHO[second]) or QUESTION_ALWAYS[opening]
      or askedAnywhere
      or (QUESTION_IF_TO[opening] and WANT_NEXT[second]) then text = text .. "?"
    else text = text .. (chatType == "YELL" and "!" or ".") end
  end
  return text
end

---------------------------------------------------------------------------
-- Hook outgoing chat
---------------------------------------------------------------------------
local MAXLEN = 255
local busy = false   -- stops a line being rewritten twice

-- Returns the text and chat type that should really be sent.
-- Lines other add-ons send for you, like "{rt1} Questie: 5/5 ..." or "[DBM] Pull in 5",
-- are left exactly as they are and aren't captured.
local function fromAddon(msg)
  return msg:find("^%s*{[^}]+}%s*[%w%-_ ]+:") or msg:find("^%s*%[[%w%-_ ]+%]")
    or msg:find("^%s*<[%w%-_ ]+>") or msg:find("^%s*[%w%-_]+:%s*%d+/%d+")
end
R.FromAddon = fromAddon

local function rewrite(msg, chatType)
  local db = RPChatDB
  R.lastError = nil
  if busy or not db or not db.enabled or type(msg) ~= "string" or msg == "" then
    return msg, chatType
  end
  if fromAddon(msg) then return msg, chatType end
  local ct = type(chatType) == "string" and chatType:upper() or "SAY"
  local bp = db.bypass
  if bp and bp ~= "" and msg:sub(1, #bp) == bp then
    return msg:sub(#bp + 1), chatType
  end
  if not db.channels[ct] then return msg, chatType end
  -- "/s *bows deeply*" -> emote "bows deeply"
  if db.asteriskEmotes and (ct == "SAY" or ct == "YELL") then
    local inner = msg:match("^%s*%*([^%*]+)%*%s*$")
    if inner then return inner, "EMOTE" end
  end
  local ok, out = pcall(R.Transform, msg, db, ct)
  R.lastError = (not ok) and tostring(out) or nil
  if ok and type(out) == "string" and db.flair and ct ~= "EMOTE" and not out:find("^%*")
     and math.random(100) <= (db.flairChance or 15) then
    local st = STYLES[db.style]
    local f = st and st.flair and pick("__flair", st.flair)
    if f and #f + 1 + #out <= MAXLEN then out = f .. " " .. out end
  end
  if ok and type(out) == "string" and out ~= "" and #out <= MAXLEN then
    return out, chatType
  end
  return msg, chatType   -- on any problem, send what was typed
end

-- Wrap a send function so every line passes through rewrite() once.
-- Saves what you typed and what was sent, so the word list can be tuned later.
-- Kept in RPChatLog (its own saved variable) so /rp reset does not wipe it.
local function capture(typed, sent, chatType)
  local db = RPChatDB
  if not db or not db.capture or type(typed) ~= "string" or typed == "" then return end
  if fromAddon(typed) then return end
  local ct = type(chatType) == "string" and chatType:upper() or "SAY"
  if not CAPTURE[ct] then return end
  local bp = db.bypass
  if bp and bp ~= "" and typed:sub(1, #bp) == bp then return end  -- ~ lines stay private
  if type(RPChatLog) ~= "table" then RPChatLog = {} end
  if type(RPChatLog.lines) ~= "table" then RPChatLog.lines = {} end
  local lines = RPChatLog.lines
  lines[#lines + 1] = { t = time and time() or 0, c = ct, o = typed, s = sent, v = db.style,
    off = (not db.enabled or not db.channels[ct]) or nil, err = R.lastError }
  while #lines > CAPTURE_MAX do table.remove(lines, 1) end
end

local function wrap(orig)
  return function(msg, chatType, ...)
    if busy then return orig(msg, chatType, ...) end
    local typed, typedType = msg, chatType
    msg, chatType = rewrite(msg, chatType)
    pcall(capture, typed, msg, typedType)
    busy = true
    local ok, a, b, c = pcall(orig, msg, chatType, ...)
    busy = false
    if not ok then error(a, 2) end
    return a, b, c
  end
end

local function installHooks()
  -- Modern clients send through C_ChatInfo.SendChatMessage; older code and
  -- macros still call the global. Both are wrapped, guarded by `busy`.
  if C_ChatInfo and type(C_ChatInfo.SendChatMessage) == "function" then
    C_ChatInfo.SendChatMessage = wrap(C_ChatInfo.SendChatMessage)
  end
  if type(SendChatMessage) == "function" then
    SendChatMessage = wrap(SendChatMessage)
  end
end

---------------------------------------------------------------------------
-- Slash command
---------------------------------------------------------------------------
local function say(s)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017RPChat:|r " .. s)
end

local function onoff(b) return b and "|cff40ff40on|r" or "|cffff4040off|r" end

local function status()
  local db = RPChatDB
  say("RP speech is " .. onoff(db.enabled) .. ", voice " .. R.StyleSource() .. ".")
  local list = {}
  for ch, v in pairs(db.channels) do
    list[#list + 1] = ch:lower() .. " " .. onoff(v)
  end
  table.sort(list)
  say("Channels: " .. table.concat(list, ", "))
  say("Start a line with " .. db.bypass .. " to send it untouched.")
  local n = type(RPChatLog) == "table" and type(RPChatLog.lines) == "table" and #RPChatLog.lines or 0
  say("Capture is " .. onoff(db.capture) .. " (" .. n .. " lines saved).")
end

---------------------------------------------------------------------------
-- Banter: /rp banter says a random in-character line in your voice.
-- Lines starting with * are sent as an emote when the channel is say.
---------------------------------------------------------------------------
local BANTER = {
  gnome = {
    "Did anyone else hear that rattle? No? Must be my left boot again.",
    "If we had a proper steam engine, this fire would be twice as warm and half as smoky.",
    "I once built a toaster that could fly. Briefly. Very briefly.",
    "Tell me, has anyone seen a small brass gear? About yay big? Rather important.",
    "Nothing like a campfire to dry out one's goggles.",
    "Gnomeregan will rise again, mark my words. Probably with better ventilation this time.",
    "I've calculated a seventy-three percent chance of rain. Or wolves. Possibly both.",
    "Rest your feet, friends. The road is long and my legs are short.",
    "*polishes a tiny wrench by the firelight*",
    "*sketches a contraption in the dirt with a stick, then frowns and rubs it out*",
    "Who's hungry? I have rations, and a gadget that only slightly burns them.",
    "A good adventurer always carries three things: a map, a snack, and spare bolts.",
    "I'm told the stars are just very distant lanterns. I intend to check.",
    "Do you suppose the murlocs ever sit around fires and tell stories about us?",
    "If anything explodes tonight, I want it noted that it wasn't my fault. Probably.",
    "Fascinating flames. Orange at the base, yellow on top. Copper salts would make them green.",
    "*taps a pocket watch, shakes it, and holds it to one ear*",
    "Ah, the open road! Fresh air, fine company, and only a few things trying to eat us.",
    "I've named my backpack. Her name is Cogsworth, and she is doing her best.",
    "Mind the sparks, chum. Beards and fuses both catch faster than you'd think.",
    "Next town, I'm buying the biggest mug of something hot they've got.",
    "*hums a cheerful tune and tightens a bolt on each boot*",
    "Someday I'll invent a bedroll that unrolls itself. Today is not that day.",
    "Anyone need anything repaired? Bracers, buckles, broken hearts? I'm mostly good with the first two.",
    "What a splendid night for tinkering, if only the light would hold still.",
  },
  human = {
    "Fair night, friends. May the Light keep watch while we rest.",
    "A warm fire and good company. A soldier could ask for little more.",
    "Has anyone news from Stormwind? The roads have been quiet of late.",
    "*warms both hands over the fire and sighs contentedly*",
    "I miss a proper bed, I'll admit it. And a proper tavern stew.",
    "Keep your blade close tonight. The wilds have ears.",
    "My grandfather used to say the best stories are told by firelight.",
    "Tomorrow we ride. Tonight, we rest and mend what's broken.",
    "*tosses another log onto the fire*",
    "Every road leads somewhere. I've just never been sure where this one goes.",
    "To fallen friends, and to the ones still walking beside us.",
    "There's a farm back home with my name carved in the fence post. I wonder if it's still there.",
    "Anyone for a game of cards? I promise to lose at least once.",
    "The stars are bright tonight. A good omen, I'd wager.",
    "*leans back against a pack and gazes up at the sky*",
    "If you hear wolves, don't panic. Panic later, once we've counted them.",
    "Sharpen your steel and rest your bones. Dawn comes early.",
    "Have I told you the tale of the gnoll and the cabbage cart? No? Settle in.",
    "A hearth is a hearth, whether stone or campfire. Welcome to mine.",
    "Glad to share the road with you all. Truly.",
  },
  dwarf = {
    "Ach, a fire! Now all we're missin' is a keg o' Thunderbrew.",
    "Pull up a rock, lads. Best seat in the house.",
    "*strokes beard thoughtfully and stares into the flames*",
    "In Ironforge the forges never go cold. Out here ye have tae make do.",
    "I could eat a whole boar. Tusks an' all.",
    "Did I ever tell ye about the time I wrestled a bear? He started it.",
    "Mountains are fine, but nothin' beats a stone roof over yer head.",
    "Somebody pass the ale. And if there's nae ale, pass the stories.",
    "*hums an old dwarven drinking song, slightly off-key*",
    "Mind yer fingers near the fire. Took me a week tae grow me eyebrows back last time.",
    "A good axe, a good mate, and a good meal. That's all a dwarf needs.",
    "Rest yer legs. Tomorrow we dig, or we fight, or both.",
    "Me da always said, never trust a gnome with a lit fuse. Wise man, me da.",
    "*polishes a hammer until it gleams in the firelight*",
    "If any o' ye snore, I'm sleepin' downwind.",
    "Ye know what this fire needs? More fire.",
    "Here's tae us! Wha's like us? Gey few, an' they're a' deid.",
    "Dinnae fret about tomorrow. Tomorrow's got its own worries.",
    "I'll take first watch. Me eyes are as sharp as me axe.",
    "Smells like rain. Or wet dog. Hopefully rain.",
  },
  nightelf = {
    "Elune's light is gentle tonight. Rest easy, friends.",
    "*gazes up at the moon in quiet reverence*",
    "The forest speaks, if you are patient enough to listen.",
    "I have seen ten thousand nights like this. Each one is still a gift.",
    "Tread softly. The creatures here have watched us since we arrived.",
    "The fire is warm, but nothing warms the spirit like starlight.",
    "*sits cross-legged and closes both eyes, breathing slowly*",
    "Ishnu-alah. May good fortune follow you into the dreaming.",
    "The trees remember the old wars. I would rather they remember tonight.",
    "Rest. I do not need much sleep. I will keep watch.",
    "There is a stillness here that the cities have forgotten.",
    "Do you hear the owl? She hunts well tonight.",
    "*traces a crescent moon in the ash with one finger*",
    "In time, all wounds heal. The forest teaches us that.",
    "Our people once knew magic that could level mountains. I prefer the quiet.",
    "Even the smallest flame can hold back the dark.",
    "Hunt with purpose, rest with gratitude.",
    "The wind carries the scent of moonwell water. We are close to something old.",
  },
  skyborne = {
    "Feel that breeze? The winds are restless tonight.",
    "*ruffles feathers and settles closer to the fire*",
    "From up high, campfires look like little stars that fell and decided to stay.",
    "I prefer a perch to a bedroll, but I'll make an exception for good company.",
    "Fair winds, friends. May tomorrow's skies be clear.",
    "The ground is so very still. I don't know how you walkers bear it.",
    "*preens a wing absent-mindedly while watching the sparks rise*",
    "Storm's coming from the west. I can feel it in my pinions.",
    "Every sunrise looks better from a mountaintop. Remind me to show you one.",
    "The sparks fly so freely. I envy them a little.",
    "Rest well. If anything stirs, I'll hear it on the wind.",
    "My grandmother could read the clouds like a book. I'm still on the first page.",
    "*tilts head, listening to something far off on the breeze*",
    "Nothing tastes better than a meal cooked under an open sky.",
    "Have you ever ridden a thermal at dawn? There's nothing like it.",
    "The air is thin and clean here. Good for thinking.",
    "Some say the sky has no edge. I mean to find out.",
    "Warm wings and a full belly. A fine end to the day.",
  },
}

-- v0.16: themed banter. /rp camp uses BANTER above (plus class lines),
-- /rp silly and /rp party use these.
local SILLY = {
  gnome = {
    "I've invented a device that detects danger. It's been beeping since we left town.",
    "Why did the gnome cross the road? To recalibrate the road.",
    "My hat has a hat. For emergencies.",
    "Someone stole my step stool. I'm going to have to look into it. From down here.",
    "I tried to build a perpetual motion machine. It's been perpetually broken.",
    "*accidentally sets off a tiny firework from a coat pocket*",
    "If I stand on your shoulders, I'm technically the tallest one here.",
    "I put a cog in my soup for extra iron. Do not recommend.",
    "My last invention was so advanced it went back in time and uninvented itself.",
    "Pop quiz! How many gnomes does it take to fix a lamp? Trick question. We'd build a sun.",
    "*sneezes, and something mechanical inside the backpack starts whirring*",
    "Why yes, these are my second-best goggles. The best ones are on my other face.",
  },
  human = {
    "I once fought a kobold over a candle. The candle won.",
    "My horse is smarter than me. She just lets me think otherwise.",
    "Is it brave to charge in first, or just poor planning? Asking for myself.",
    "*trips over a perfectly flat patch of ground and pretends it was a lunge*",
    "My mother said I'd never amount to anything. Now I'm unemployed in five different zones.",
    "Who keeps putting wolves in the forest? Honestly, every single time.",
    "I'd tell you a joke about Westfall, but it's still being harvested.",
    "My armor squeaks. I've decided it's a battle cry.",
    "I have a strict rule: never trust a murloc who says 'mrrgl' twice.",
    "*attempts a heroic pose, and the cape gets caught on a branch*",
  },
  dwarf = {
    "Me beard's got a beard. Third generation, that one.",
    "I tried bein' sober once. Worst four minutes o' me life.",
    "Did ye hear about the dwarf who fell in the ale vat? Took him three days tae drown. He kept gettin' out tae use the privy.",
    "*hiccups loudly and looks around for whoever did that*",
    "Some say I'm short. I say the rest o' ye are needlessly tall.",
    "I named me axe Gertrude. She's the only lass who's never left me.",
    "If it moves, I hit it. If it doesnae move, I hit it until it does.",
    "Ach, I left me hammer in the last tavern. Or the one before. Or the barmaid has it.",
    "Mountains are just hills that got proper ambitious.",
    "*attempts tae juggle three mugs and catches only the full one*",
  },
  nightelf = {
    "I have been alive for ten thousand years and I still cannot whistle.",
    "Do not mind me. I am simply brooding majestically.",
    "*glows faintly, then seems embarrassed about it*",
    "The trees told me a secret. It was mostly about squirrels.",
    "I once waited a century for a kettle to boil. It was worth it.",
    "Elune watches over us. She is probably laughing at you specifically.",
    "Short-lived races are always in such a hurry. It is adorable.",
    "My hair is not purple. It is 'twilight violet'. There is a difference.",
    "*does a flawless backflip for no reason whatsoever*",
    "Yes, my ears can hear that. Yes, all of it. Please stop.",
  },
  skyborne = {
    "Has anyone seen my other feather? It was right here. On my body.",
    "Walking is just very slow, very boring falling.",
    "I tried to hold a cup with my wings once. Do not ask about the tavern.",
    "*preens a ruffled wing, sneezes, and loses three feathers*",
    "Humans ask if I can fly. I ask if they can stop asking.",
    "Some birds sing at dawn. I prefer to sing at you.",
    "I'm not lost. I'm simply exploring the wrong direction with great confidence.",
    "Never challenge a Skyborne to a staring contest. We have spare eyelids.",
    "*hops onto a crate to be taller, then looks very pleased about it*",
    "If anyone needs me, I'll be on top of the nearest roof. As usual.",
  },
}

local PARTYTALK = {
  gnome = {
    "Right then, team! Tanks to the front, squishies to the back, gnomes wherever the loot is.",
    "Quick reminder: if I start glowing, that's normal. Mostly.",
    "Who's pulling? Not me. My arms are too short to reach that far.",
    "Excellent teamwork, chums! I've only been knocked over twice.",
    "Everyone ready? Goggles on, gears greased, snacks distributed?",
    "Let's do this efficiently. I've drawn a diagram. It's mostly arrows.",
    "If I go down, avenge me. If I get back up, pretend it was planned.",
    "*hands out tiny cogs to the group as good-luck charms*",
    "Splendid group, this. Nobody's stepped on me yet.",
    "Healer, I'll try not to need you. I'll fail, but I'll try.",
  },
  human = {
    "Form up, friends! We go in together and we come out together.",
    "Shields up, blades out, and someone please watch my back.",
    "A fine company, this. I'd follow any of you into the Deadmines.",
    "Steady now. We take them one pack at a time.",
    "Well fought, all! The Light smiles on this group tonight.",
    "Everyone have water? Food? A clear head? Two out of three will do.",
    "If we wipe, we regroup. No shame in it, only lessons.",
    "*raises a sword in salute to the group*",
    "Healer, my thanks in advance. I suspect I'll need it.",
    "Onward! Glory awaits, and possibly a decent pair of boots.",
  },
  dwarf = {
    "Right, lads and lasses! Let's go break some heads an' take their shinies!",
    "Stick close an' keep yer shields up. Nae heroics till I say so.",
    "That's the spirit! Fight like ye've got a keg waitin' at the end!",
    "Tank's in front, I'm right behind, an' the ale's on whoever dies first.",
    "Och, grand fightin' there. Me grandda would've wept wi' pride.",
    "Everyone mended up? Good. Let's go find somethin' that needs hittin'.",
    "If we fall, we fall together. Then we get up an' do it again.",
    "*bangs a hammer on a shield tae rally the group*",
    "Healer, keep me alive an' I'll buy the first round. Maybe the second.",
    "Nae rest for the bearded! Onward!",
  },
  nightelf = {
    "Move as one, friends. The forest rewards patience and punishes haste.",
    "Elune guide our blades and guard our healer.",
    "Well done. Your ancestors would be proud, briefly, before they forgot.",
    "Step lightly. The shadows here are listening.",
    "We are a fine company. I have seen worse in ten thousand years. Not many.",
    "Breathe, regroup, and let the moonlight mend you.",
    "Stay together. Alone, we are prey. Together, we are the hunt.",
    "*bows gracefully to the group before the next pull*",
    "Healer, you have my gratitude, now and for the next few centuries.",
    "Onward, beneath the stars.",
  },
  skyborne = {
    "Wings together, everyone! Well, arms. Whatever you've got.",
    "I'll scout ahead. From above. Where it's safe. For me.",
    "Fine flying, all! Erm, fine walking. You know what I mean.",
    "Stay close. If you get lost, look up. I'll be the one circling.",
    "Good fight! My feathers are only slightly singed.",
    "Ready when you are. The wind is in our favor today.",
    "If anyone falls, I'll swoop in. Metaphorically. I can't carry you.",
    "*fluffs up feathers and nods to each member of the group*",
    "Healer, thank you. My plumage owes you its life.",
    "Onward and upward! Mostly onward. Upward is just me.",
  },
}

local lastBanter = {}
local BANTER_CHAN = { s = "SAY", say = "SAY", p = "PARTY", party = "PARTY", y = "YELL", yell = "YELL",
  i = "INSTANCE_CHAT", instance = "INSTANCE_CHAT", g = "GUILD", guild = "GUILD", r = "RAID", raid = "RAID",
  e = "EMOTE", emote = "EMOTE" }

-- The class lines for this voice: its own list plus the shared ones.
local function classBanter(style)
  local cd = classData()
  if not cd then return nil end
  local pool = {}
  for _, v in ipairs(cd.banter.any or {}) do pool[#pool + 1] = v end
  for _, v in ipairs(cd.banter[style] or {}) do pool[#pool + 1] = v end
  return #pool > 0 and pool or nil
end

local THEMES = { camp = BANTER, silly = SILLY, party = PARTYTALK }
local function themePool(set, style)
  return set[style] or set[(STYLES[style] and STYLES[style].base) or "human"] or set.human
end

-- Picks a line from a theme ("camp", "silly", "party", or nil for any),
-- avoiding the last few used. Camp lines are about a third class lines;
-- theme "class" forces one.
function R.Banter(style, theme)
  if theme == true then theme = "class" end
  if not theme then
    local names = { "camp", "silly", "party" }
    theme = names[math.random(#names)]
  end
  local pool = themePool(THEMES[theme] or BANTER, style)
  local cpool = classBanter(style)
  local key = style .. ":" .. theme
  if cpool and (theme == "class" or (theme == "camp" and math.random(100) <= 35)) then
    pool, key = cpool, style .. ":class"
  end
  local recent = lastBanter[key] or {}
  local line, tries = nil, 0
  repeat
    line = pool[math.random(#pool)]
    tries = tries + 1
    local seen = false
    for _, v in ipairs(recent) do if v == line then seen = true break end end
    if not seen then break end
  until tries > 20
  recent[#recent + 1] = line
  while #recent > math.min(8, #pool - 1) do table.remove(recent, 1) end
  lastBanter[key] = recent
  return line
end

local HELP = {
  "/rp  - toggle on or off",
  "/rp on | off | status",
  "/rp style  - show the voices; your race picks one automatically",
  "/rp style <human|dwarf|nightelf|gnome|skyborne>  - use another voice on this character",
  "/rp style auto  - go back to the voice for your race",
  "/rp channel <say|yell|emote|party|instance|raid|guild|officer|whisper|channel>  - toggle a channel",
  "/rp add <word or phrase> = <replacement>   e.g. /rp add hi = well met, friend",
  "/rp remove <word>  - stop changing a word",
  "/rp list  - show your custom words",
  "/rp export  - copy all your swaps in CustomWords.lua format",
  "/rp test <text>  - preview without sending",
  "/rp caps | punct | stars  - toggle capitals, full stops, *emote* lines",
  "/rp flair [0-100]  - toggle the occasional *emote*, or set how often (percent)",
  "/rp camp | silly | party  - say a random in-character line: campfire talk, a joke, or group talk",
  "    add a channel to send it elsewhere: /rp silly party, /rp camp yell (party talk goes to your group)",
  "/rp banter [class]  - a line from any theme, or one for your class",
  "/rp share  - show your recent typed and sent lines, ready to copy and send to someone",
  "/rp capture [on|off|clear]  - log your say/yell/party lines so the word list can be tuned",
  "/rp reset  - restore all defaults",
}

local function showValue(v)
  if type(v) == "table" then return "{ " .. table.concat(v, " | ") .. " }" end
  return tostring(v)
end

-- Builds a complete CustomWords.lua from the file's swaps plus in-game ones.
function R.ExportText(db)
  local merged = {}
  for k, v in pairs(fileWords) do merged[k] = v end
  for k, v in pairs(db.custom) do merged[k] = v end
  local keys = {}
  for k in pairs(merged) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {
    "-- RPChat custom words. Exported with /rp export.",
    "-- One swap per line. Lists { ... } pick one at random. /reload after editing.",
    "",
    "RPChat_CustomWords = {",
  }
  for _, k in ipairs(keys) do
    local v = merged[k]
    local val
    if type(v) == "table" then
      local parts = {}
      for _, item in ipairs(v) do parts[#parts + 1] = string.format("%q", item) end
      val = "{ " .. table.concat(parts, ", ") .. " }"
    else
      val = string.format("%q", v)
    end
    out[#out + 1] = string.format("  [%q] = %s,", k, val)
  end
  out[#out + 1] = "}"
  return table.concat(out, "\n")
end

-- A small window holding the export text, selected and ready for Ctrl+C.
local exportFrame
function R.ShowExport(text, heading)
  if not exportFrame then
    local f = CreateFrame("Frame", "RPChatExportFrame", UIParent, "BackdropTemplate")
    f:SetSize(520, 360)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
      f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
      })
    end
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", 0, -16)
    f.title = title

    local scroll = CreateFrame("ScrollFrame", "RPChatExportScroll", f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 20, -40)
    scroll:SetPoint("BOTTOMRIGHT", -40, 50)

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(true)
    edit:SetFontObject(ChatFontNormal)
    edit:SetWidth(440)
    edit:SetScript("OnEscapePressed", function() f:Hide() end)
    scroll:SetScrollChild(edit)
    f.edit = edit

    local close = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    close:SetSize(100, 24)
    close:SetPoint("BOTTOM", 0, 16)
    close:SetText("Close")
    close:SetScript("OnClick", function() f:Hide() end)
    exportFrame = f
  end
  exportFrame.title:SetText(heading or "RPChat export: press Ctrl+C, then paste over CustomWords.lua")
  exportFrame.edit:SetText(text)
  exportFrame:Show()
  exportFrame.edit:SetFocus()
  exportFrame.edit:HighlightText()
end

-- Recent capture lines as plain text, for sharing.
function R.ShareText(max)
  local lines = type(RPChatLog) == "table" and RPChatLog.lines or {}
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ver = meta and meta(ADDON, "Version") or "?"
  local out = { "RPChat " .. tostring(ver) .. " capture, " .. #lines .. " lines saved. Newest last.", "" }
  local first = math.max(1, #lines - (max or 300) + 1)
  for i = first, #lines do
    local e = lines[i]
    if type(e) == "table" then
      local when = (date and e.t) and date("%Y-%m-%d %H:%M", e.t) or tostring(e.t or "")
      local extra = (e.off and " (rp off)" or "") .. (e.err and (" (error: " .. tostring(e.err) .. ")") or "")
      out[#out + 1] = string.format("%s %s %s | %s => %s%s", when, tostring(e.c or ""):lower(),
        tostring(e.v or ""), tostring(e.o or ""), tostring(e.s or ""), extra)
    end
  end
  if #lines == 0 then out[#out + 1] = "(nothing captured yet: chat a bit with /rp capture on)" end
  return table.concat(out, "\n")
end

local function slash(input)
  local db = RPChatDB
  input = (input or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, rest = input:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()

  if cmd == "" then
    db.enabled = not db.enabled
    say("RP speech is " .. onoff(db.enabled) .. ".")
  elseif cmd == "on" or cmd == "off" then
    db.enabled = (cmd == "on")
    say("RP speech is " .. onoff(db.enabled) .. ".")
  elseif cmd == "status" then
    status()
  elseif cmd == "channel" or cmd == "chan" then
    local ch = rest:upper()
    if ch == "S" then ch = "SAY" elseif ch == "Y" then ch = "YELL"
    elseif ch == "E" or ch == "EM" then ch = "EMOTE" elseif ch == "P" then ch = "PARTY"
    elseif ch == "G" then ch = "GUILD"
    elseif ch == "I" or ch == "INSTANCE" then ch = "INSTANCE_CHAT" elseif ch == "W" then ch = "WHISPER" end
    if db.channels[ch] == nil then
      say("Unknown channel. Try say, yell, emote, party, instance, raid, guild, officer, whisper or channel.")
    else
      db.channels[ch] = not db.channels[ch]
      say(ch:lower() .. " is now " .. onoff(db.channels[ch]) .. ".")
    end
  elseif cmd == "add" then
    local from, to = rest:match("^(.-)%s*=%s*(.+)$")
    if not from or from == "" then
      say("Usage: /rp add <word> = <replacement>")
    else
      from = from:lower()
      db.custom[from] = to
      db.removed[from] = nil
      say('"' .. from .. '" will become "' .. to .. '".')
    end
  elseif cmd == "remove" or cmd == "del" then
    local w = rest:lower()
    if w == "" then say("Usage: /rp remove <word>") return end
    db.custom[w] = nil
    db.removed[w] = true
    say('"' .. w .. '" will no longer be changed.')
  elseif cmd == "list" then
    local n = 0
    for k, v in pairs(db.custom) do say(k .. " = " .. showValue(v) .. " |cffaaaaaa(in game)|r") n = n + 1 end
    for k, v in pairs(fileWords) do
      if db.custom[k] == nil then say(k .. " = " .. showValue(v) .. " |cffaaaaaa(CustomWords.lua)|r") n = n + 1 end
    end
    if n == 0 then say("No custom words yet. Add one with /rp add or in CustomWords.lua.") end
  elseif cmd == "export" then
    R.ShowExport(R.ExportText(db))
  elseif cmd == "share" then
    R.ShowExport(R.ShareText(300), "RPChat capture: press Ctrl+C, then paste it in a message")
  elseif cmd == "test" then
    say("|cffaaaaaa" .. rest .. "|r")
    say(R.Transform(rest, db))
  elseif cmd == "style" or cmd == "voice" or cmd == "race" then
    local arg = rest:lower():gsub("%s+", "")
    if arg == "auto" or arg == "race" then
      RPChatCharDB.style = nil
      R.ApplyStyle()
      say("Voice is now " .. R.StyleSource() .. ".")
    elseif styleName(arg) then
      RPChatCharDB.style = styleName(arg)
      R.ApplyStyle()
      say("Voice is now " .. R.StyleSource() .. ". /rp style auto goes back to your race.")
    else
      if arg ~= "" then say("No voice called \"" .. rest .. "\".") end
      for _, k in ipairs(STYLE_ORDER) do
        local v = STYLES[k]
        say((k == db.style and "|cff40ff40> |r" or "  ") .. k .. " - " .. v.label)
      end
      say("Now using " .. R.StyleSource() .. ". Change with /rp style <name>, or /rp style auto.")
    end
  elseif cmd == "caps" then
    db.capitalize = not db.capitalize
    say("Capitalising is " .. onoff(db.capitalize) .. ".")
  elseif cmd == "punct" then
    db.punctuate = not db.punctuate
    say("Auto full stop is " .. onoff(db.punctuate) .. ".")
  elseif cmd == "flair" then
    local n = tonumber(rest)
    if n then
      db.flairChance = math.max(0, math.min(100, math.floor(n)))
      db.flair = db.flairChance > 0
    else
      db.flair = not db.flair
      if db.flair and (db.flairChance or 0) <= 0 then db.flairChance = 15 end
    end
    say("Flair is " .. onoff(db.flair) .. " (" .. (db.flairChance or 15) .. "% of lines).")
  elseif cmd == "stars" then
    db.asteriskEmotes = not db.asteriskEmotes
    say("*Emote* lines are " .. onoff(db.asteriskEmotes) .. ".")
  elseif cmd == "banter" or cmd == "chatter" or cmd == "camp" or cmd == "silly" or cmd == "party" then
    local a = rest:lower()
    local theme = (cmd == "camp" or cmd == "silly" or cmd == "party") and cmd or nil
    local w1, w2 = a:match("^(%S+)%s*(.*)$")
    if w1 == "class" or (THEMES[w1 or ""] and not theme) then theme, a = w1, w2 or "" end
    if theme == "class" and not classData() then say("No class lines yet. Your class isn't known until you're logged in.") return end
    -- party talk goes to your group by default; the rest to /say
    local ct = BANTER_CHAN[a]
    if not ct then
      if theme == "party" then
        if IsInGroup and LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then ct = "INSTANCE_CHAT"
        elseif IsInRaid and IsInRaid() then ct = "RAID"
        elseif IsInGroup and IsInGroup() then ct = "PARTY"
        else ct = "SAY" end
      else
        ct = "SAY"
      end
    end
    if a ~= "" and not BANTER_CHAN[a] then say("Unknown channel '" .. a .. "'. Try say, party, yell or instance.") return end
    local line = R.Banter(db.style, theme)
    local emote = line:match("^%*(.+)%*$")
    if emote and (ct == "SAY" or ct == "EMOTE") then line, ct = emote, "EMOTE"
    elseif ct == "EMOTE" then ct = "SAY" end
    busy = true   -- already in voice; send it as written
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
    local ok, err = pcall(send, line, ct)
    busy = false
    if not ok then say("Couldn't send banter: " .. tostring(err)) end
  elseif cmd == "capture" or cmd == "log" then
    local a = rest:lower()
    if a == "clear" then
      RPChatLog = { lines = {} }
      say("Capture log cleared.")
    else
      if a == "on" then db.capture = true elseif a == "off" then db.capture = false
      elseif a == "" then db.capture = not db.capture end
      local n = type(RPChatLog) == "table" and type(RPChatLog.lines) == "table" and #RPChatLog.lines or 0
      say("Capture is " .. onoff(db.capture) .. " (" .. n .. " lines saved, newest " .. CAPTURE_MAX .. " kept).")
    end
  elseif cmd == "reset" then
    RPChatDB = {}
    copyDefaults(DEFAULTS, RPChatDB)
    RPChatDB.dbVersion = 4
    R.ApplyStyle()
    say("Settings reset. Voice: " .. R.StyleSource() .. ".")
  else
    for _, line in ipairs(HELP) do say(line) end
  end
end

---------------------------------------------------------------------------
-- Start up
---------------------------------------------------------------------------
-- Works out which voice to use: a choice made on this character with
-- /rp style, otherwise the one for the character's race.
local raceName, className
function R.ApplyStyle()
  local db = RPChatDB
  if UnitClass then
    local loc, token = UnitClass("player")
    if token and CLASS[token] then R.playerClass, className = token, loc end
  end
  local chosen = type(RPChatCharDB) == "table" and styleName(RPChatCharDB.style)
  if chosen then
    db.style = chosen
    return
  end
  local st, localized = raceStyle()
  if st then
    db.style = st
    raceName = localized
  elseif not STYLES[db.style] then
    db.style = styleName(db.style) or "gnome"
  end
end

function R.StyleSource()
  local db = RPChatDB
  local chosen = type(RPChatCharDB) == "table" and styleName(RPChatCharDB.style)
  local cls = className and (" " .. className:lower()) or ""
  if chosen then return db.style .. cls .. " (chosen for this character)" end
  if raceName then return db.style .. cls .. " (from your race, " .. raceName .. ")" end
  return tostring(db.style) .. cls
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
  if event == "PLAYER_LOGIN" then
    -- the character's race is certain to be known by now
    if RPChatDB then R.ApplyStyle() end
    return
  end
  if name ~= ADDON then return end
  if type(RPChatDB) ~= "table" then RPChatDB = {} end
  if type(RPChatCharDB) ~= "table" then RPChatCharDB = {} end
  if type(RPChatLog) ~= "table" then RPChatLog = {} end
  if type(RPChatLog.lines) ~= "table" then RPChatLog.lines = {} end
  copyDefaults(DEFAULTS, RPChatDB)
  -- v0.3: party (and dungeon-finder party chat) is on by default
  if (RPChatDB.dbVersion or 0) < 3 then
    RPChatDB.channels.PARTY = true
    RPChatDB.channels.INSTANCE_CHAT = true
    RPChatDB.dbVersion = 3
  end
  -- v0.8: "medieval" is now the Human voice, and the voice follows your race
  if RPChatDB.dbVersion < 4 then
    if RPChatDB.style == "medieval" then RPChatDB.style = "human" end
    RPChatDB.dbVersion = 4
  end
  R.ApplyStyle()

  local n = loadFileWords()
  installHooks()

  SLASH_RPCHAT1 = "/rp"
  SLASH_RPCHAT2 = "/rpchat"
  SlashCmdList["RPCHAT"] = slash

  say("loaded. RP speech is " .. onoff(RPChatDB.enabled) .. ", " .. n ..
      " swaps from CustomWords.lua. Type /rp help.")
  say("Voice: " .. R.StyleSource() .. ".")
  -- v0.17: say so when a new version was installed since last time
  local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ver = meta and meta(ADDON, "Version")
  if ver then
    if RPChatDB.lastVersion and RPChatDB.lastVersion ~= ver then
      say("|cff40ff40Updated to " .. ver .. "|r (was " .. tostring(RPChatDB.lastVersion) .. ").")
    end
    RPChatDB.lastVersion = ver
  end
  self:UnregisterEvent("ADDON_LOADED")
end)
