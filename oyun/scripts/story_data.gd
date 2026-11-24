class_name StoryData
## Hikâye diyalogları (oyun içi dil: İngilizce). Kaynak: docs/hikaye.md
## Her konuşma bir diyalog ağacıdır (bkz. DialogueBox.run).
## Yardım NPC'lerinin ağacı duruma göre değişir: tree_for(id, state, ctx).
##   state: "" (karar yok), "accepted", "helped", "skipped"
##   ctx:   {"helped": int (şimdiye kadar yardım sayısı), "items": Dictionary}
## Eylemler (action): accept, skip, use_rope, light_fire → test_rooms.gd hikâye kontrolcüsü işler.

const HELP_TOTAL := 3


# =====================================================================
# Prolog: meleğin açılış konuşması (seçenekli)
# =====================================================================

const INTRO := {
	"start": {
		"lines": [
			["ANGEL", "...A mortal. Of course. Is this what the heavens think I deserve?"],
			["ANGEL", "What are you staring at? Never seen an angel before? No, I suppose you haven't."],
		],
		"ask": ["ANGEL", "Listen. I... lost my way. I need to get home."],
		"options": [
			{"text": "Who are you?", "next": "who"},
			{"text": "What happened to you?", "next": "what"},
			{"text": "I'll help you.", "next": "go"},
		],
	},
	"who": {
		"lines": [["ANGEL", "Someone far above your station. That is all you need to know."]],
		"next": "deal",
	},
	"what": {
		"lines": [["ANGEL", "A... wind. A strong wind blew me off course. Yes. A wind."]],
		"next": "deal",
	},
	"deal": {
		"ask": ["ANGEL", "So. Will you help me or not?"],
		"options": [
			{"text": "What's in it for me?", "next": "reward"},
			{"text": "Alright, let's go.", "next": "go"},
		],
	},
	"reward": {
		"lines": [["ANGEL", "Hmm. I'll put in a good word for you at the Gate of Heaven. That's no small thing."]],
		"next": "go",
	},
	"go": {
		"lines": [
			["ANGEL", "Your tales speak of a stairway to the sky, on top of the mountain. Take me there."],
			["ANGEL", "And try to keep up."],
		],
	},
}


# =====================================================================
# Hikâye NPC'leri (yardım seçimi yok, ama sohbet seçenekleri var)
# =====================================================================

const GRANNY := {
	"start": {
		"lines": [
			["GRANNY", "Well, well... who's that with you, dear? That hair shines like the morning."],
			["ANGEL", "(whispering) Don't talk to her. Old people see too much."],
		],
		"next": "menu",
	},
	"menu": {
		"ask": ["GRANNY", "Where are you two headed?"],
		"options": [
			{"text": "To the mountain.", "next": "stairway"},
			{"text": "What do you know about angels?", "next": "angels"},
			{"text": "Goodbye.", "next": "bye"},
		],
	},
	"stairway": {
		"lines": [
			["GRANNY", "The Stairway to the Sky? My grandmother used to say:"],
			["GRANNY", "\"The Gate doesn't look at the stars. It looks at hearts. If a pure heart comes, it lets in whoever walks beside it.\""],
			["ANGEL", "(a short silence) ...Just a fairy tale. Let's go."],
		],
		"next": "more",
	},
	"angels": {
		"lines": [
			["GRANNY", "Angels? They say nothing falls from heaven by accident, dear."],
			["ANGEL", "Ridiculous."],
		],
		"next": "more",
	},
	"more": {
		"ask": ["GRANNY", "Anything else, dear?"],
		"options": [
			{"text": "Tell me about the stairway.", "next": "stairway"},
			{"text": "What do you know about angels?", "next": "angels"},
			{"text": "Goodbye.", "next": "bye"},
		],
	},
	"bye": {
		"lines": [["GRANNY", "Mind the old well on your way, dear. Things fall into it."]],
	},
}

const MONK := {
	"start": {
		"lines": [
			["MONK", "I know those who fall from the sky. Every one of them says they fell."],
			["MONK", "But some don't fall. They are pushed."],
			["ANGEL", "Old man, save your nonsense for the wind."],
		],
		"next": "menu",
	},
	"menu": {
		"ask": ["MONK", "(to you) Traveler. What would you ask?"],
		"options": [
			{"text": "Pushed? What do you mean?", "next": "pushed"},
			{"text": "What's at the top?", "next": "top"},
			{"text": "We should go.", "next": "bye"},
		],
	},
	"pushed": {
		"lines": [
			["MONK", "Heaven does not lose its children. It sends away the ones who would not share its light."],
			["ANGEL", "..."],
		],
		"next": "menu",
	},
	"top": {
		"lines": [["MONK", "The Stairway. And beyond it, the Gate. It will weigh your heart, not your steps."]],
		"next": "menu",
	},
	"bye": {
		"lines": [["MONK", "A key does not know whose door it opens. You should know."]],
	},
}

const BIRD := {
	"start": {
		"lines": [["BIRD", "Tweet! The last angel to cross these clouds was alone. Now someone walks along. Tweet!"]],
		"ask": ["BIRD", "Want to hear a secret? Tweet!"],
		"options": [
			{"text": "Tell me.", "next": "secret"},
			{"text": "Who are you?", "next": "who"},
			{"text": "Not now.", "next": "bye"},
		],
	},
	"secret": {
		"lines": [
			["BIRD", "The Gate keeps count! Who helped, who walked past. Tweet!"],
			["ANGEL", "(shooing the bird) Go on. Fly away."],
		],
	},
	"who": {
		"lines": [["BIRD", "I watch the clouds! Nobody asks the bird anything. Tweet!"]],
		"next": "start",
	},
	"bye": {
		"lines": [["BIRD", "Suit yourself! Tweet!"]],
	},
}


# =====================================================================
# Yardım NPC'leri: ağaç duruma ve şimdiye kadarki yardımlara göre değişir
# =====================================================================

static func tree_for(id: String, state: String, ctx: Dictionary) -> Dictionary:
	match id:
		"child":
			return _child(state, ctx)
		"climber":
			return _climber(state, ctx)
		"spirit":
			return _spirit(state, ctx)
	return {}


## Melek başta yardıma karşı çıkar; oyuncu yardım ettikçe yumuşar
static func _angel_push(ctx: Dictionary, harsh: String, soft: String) -> Array:
	return ["ANGEL", soft if ctx.get("helped", 0) > 0 else harsh]


static func _child(state: String, ctx: Dictionary) -> Dictionary:
	match state:
		"":
			return {
				"start": {
					"lines": [
						["CHILD", "(from the bottom of the well) Help! I fell in while chasing my lamb!"],
						_angel_push(ctx,
							"A child and a well. How touching. We don't have time, we must reach the mountain before dark.",
							"...Another one? (sigh) Fine. But be quick."),
					],
					"next": "ask",
				},
				"ask": {
					"ask": ["CHILD", "Please! There was a rope up there somewhere!"],
					"options": [
						{"text": "I'll get you out.", "action": "accept", "next": "accepted"},
						{"text": "How did you fall?", "next": "how"},
						{"text": "Sorry, I have to go.", "action": "skip", "next": "skipped"},
					],
				},
				"how": {
					"lines": [["CHILD", "The lamb ran past the old tree and I slipped... The rope is on that tree's branch!"]],
					"next": "ask",
				},
				"accepted": {
					"lines": [["ANGEL", "(sighs) Fine. The rope should be on the old tree's branch."]],
				},
				"skipped": {
					"lines": [["ANGEL", "Wise. Someone will find the kid. Someone always does, right?"]],
				},
			}
		"accepted":
			if ctx.get("items", {}).get("rope", 0) > 0:
				return {
					"start": {
						"ask": ["CHILD", "Is that a rope?!"],
						"options": [
							{"text": "Lower the rope.", "action": "use_rope"},
							{"text": "In a moment.", "next": ""},
						],
					},
				}
			return {"start": {"lines": [["CHILD", "The rope! It's on the old tree's branch!"]]}}
		"helped":
			return {"start": {"lines": [["CHILD", "I'm going to find my lamb now. Thank you!"]]}}
	return {"start": {"lines": [["CHILD", "(faintly, from the well) ...help..."]]}}


static func _climber(state: String, ctx: Dictionary) -> Dictionary:
	match state:
		"":
			return {
				"start": {
					"lines": [
						["CLIMBER", "My fire went out... my firewood... the wind blew it all down the slope..."],
						_angel_push(ctx,
							"Don't look at him. The mountain picks the weak. Keep climbing.",
							"...Again? (sigh) Fine, but be quick."),
					],
					"next": "ask",
				},
				"ask": {
					"ask": ["CLIMBER", "Could you... spare a moment?"],
					"options": [
						{"text": "I'll find your wood.", "action": "accept", "next": "accepted"},
						{"text": "What are you doing up here?", "next": "why"},
						{"text": "I can't, sorry.", "action": "skip", "next": "skipped"},
					],
				},
				"why": {
					"lines": [["CLIMBER", "I wanted to see the stairway with my own eyes. Foolish, I know."]],
					"next": "ask",
				},
				"accepted": {
					"lines": [["CLIMBER", "Three logs... they rolled down onto the rocks below."]],
				},
				"skipped": {
					"lines": [["ANGEL", "Good choice. Everyone lights their own fire."]],
				},
			}
		"accepted":
			var wood: int = ctx.get("items", {}).get("wood", 0)
			if wood >= 3:
				return {
					"start": {
						"ask": ["CLIMBER", "You found them!"],
						"options": [
							{"text": "Light the fire.", "action": "light_fire", "next": "lit"},
							{"text": "In a moment.", "next": ""},
						],
					},
					"lit": {
						"lines": [
							["CLIMBER", "Warm... Thank you, stranger. Take my lantern. It's dark up there."],
							["ANGEL", "(staring at the fire, quietly) Fire doesn't get smaller when you share it. Strange."],
						],
					},
				}
			return {"start": {"lines": [["CLIMBER", "Three logs... You have %d so far." % wood]]}}
		"helped":
			return {"start": {"lines": [["CLIMBER", "Safe travels, stranger. Keep that lantern lit."]]}}
	return {"start": {"lines": [["CLIMBER", "(shivering) ..."]]}}


static func _spirit(state: String, ctx: Dictionary) -> Dictionary:
	match state:
		"":
			return {
				"start": {
					"lines": [
						["SPIRIT", "I forgot the way... I keep sinking down... If only someone walked with me..."],
						_angel_push(ctx,
							"A spirit. Let it find its own way. We won't drag burdens to the Gate.",
							"(quietly) ...It looks lighter than it is."),
					],
					"next": "ask",
				},
				"ask": {
					"ask": ["SPIRIT", "Will you walk with me?"],
					"options": [
						{"text": "Come with me.", "action": "accept", "next": "accepted"},
						{"text": "Who are you?", "next": "who"},
						{"text": "I can't.", "action": "skip", "next": "skipped"},
					],
				},
				"who": {
					"lines": [["SPIRIT", "I don't remember. Only that I was going up."]],
					"next": "ask",
				},
				"accepted": {
					"lines": [["SPIRIT", "Thank you... I'll follow your light."]],
				},
				"skipped": {
					"lines": [["ANGEL", "One spirit more, one spirit less. Heaven is crowded anyway."]],
				},
			}
		"accepted":
			return {"start": {"lines": [["SPIRIT", "Lead the way... to the Gate."]]}}
	return {"start": {"lines": [["SPIRIT", "..."]]}}


# =====================================================================
# Bölgeden yardım etmeden çıkınca meleğin yorumu (seçim kesinleşir)
# =====================================================================

const LEFT_BEHIND := {
	"child": [["ANGEL", "The kid's voice is fading. Good. It was getting on my nerves."]],
	"climber": [["ANGEL", "His fire is out for good now. Not our problem."]],
	"spirit": [["ANGEL", "The spirit is sinking behind us. Don't look back."]],
}

const CHILD_RESCUED := [
	["CHILD", "I'm out! Thank you! Here, I made this for you!"],
	["CHILD", "(hands over a little daisy crown)"],
	["ANGEL", "A flower. What use is that? (puts it on when no one is looking)"],
]

const SPIRIT_ASCENDS := [
	["SPIRIT", "Light... at last. I'll remember you."],
	["ANGEL", "(a long silence) Did I shine like that, once?"],
]


# =====================================================================
# Kapı ve sonlar
# =====================================================================

const GATE_OPENING := [
	["GATEKEEPER", "Aurel. The exile. You return."],
	["GATEKEEPER", "And a mortal beside you. Clever. The Gate does not turn away one who walks beside a pure heart."],
	["GATEKEEPER", "Let us see how pure this heart is."],
]

const ENDING_GOOD := [
	["GATEKEEPER", "The Gate opens. All the way."],
	["ANGEL", "Gatekeeper... before I go in, I must say something."],
	["ANGEL", "(to you) I lied to you. I didn't fall. I was cast out. I hid heaven's light for myself... and I used you like a key."],
	["ANGEL", "But you... you stopped. Every time. Even when no one was watching."],
	["ANGEL", "Light doesn't fade when you share it. I learned that from a mortal."],
	["GATEKEEPER", "Remorse is the oldest key to this Gate. Enter, Aurel."],
]

const ENDING_NORMAL := [
	["GATEKEEPER", "Your heart is... half pure. The Gate will open for one."],
	["ANGEL", "(laughing) Half. That's enough."],
	["ANGEL", "Shall I tell you something, mortal? I didn't fall. I was cast out."],
	["ANGEL", "You were never a traveler. You were a key. And the key's work is done."],
	["ANGEL", "I will walk through that door."],
]

const ENDING_BAD := [
	["GATEKEEPER", "You never stopped. Not once. Not for anyone."],
	["ANGEL", "No... no! This mortal's heart was supposed to be pure! Did I... choose the wrong one?"],
	["GATEKEEPER", "You did not choose the wrong one, Aurel. You chose one like yourself."],
	["GATEKEEPER", "Those who do not share the light go where there is none."],
]


## Yardım sayısına göre: [satırlar, başlık, alt yazı]
static func ending(helped: int) -> Array:
	if helped >= HELP_TOTAL:
		return [ENDING_GOOD, "GOOD ENDING: Wings", "The angel learns what kindness is worth."]
	if helped > 0:
		return [ENDING_NORMAL, "NORMAL ENDING: Betrayal", "A boss fight with the angel starts here."]
	return [ENDING_BAD, "BAD ENDING: The Fall", "Both of you are cast into hell. The game starts over."]
