class_name QuestLog
extends Node
## Bir level'daki questlerin durumu. HUD bu sinyalleri dinleyip quest listesini ve bildirimleri gösterir.
##
## Kullanım:
##   quests.start("lamb", "The Runaway Lamb", "Catch the lamb in the meadow")
##   quests.set_objective("lamb", "Bring the lamb to the shepherd")
##   quests.set_progress("stones", 2, 3)
##   quests.complete("lamb")      # ya da quests.fail("lamb")

signal changed              ## Liste yeniden çizilmeli
signal notify(text: String) ## Kısa bildirim ("Quest started: ...")

const ACTIVE := "active"
const DONE := "done"
const FAILED := "failed"

## id -> {"title", "objective", "state", "count", "total", "order"}
var quests := {}
var _order := 0


func start(id: String, title: String, objective: String, total := 0) -> void:
	if quests.has(id):
		return
	_order += 1
	quests[id] = {"title": title, "objective": objective, "state": ACTIVE, "count": 0,
			"total": total, "order": _order}
	notify.emit("New quest: " + title)
	changed.emit()


func has(id: String) -> bool:
	return quests.has(id)


func state(id: String) -> String:
	return quests[id]["state"] if quests.has(id) else ""


func is_active(id: String) -> bool:
	return state(id) == ACTIVE


func set_objective(id: String, objective: String) -> void:
	if not is_active(id) or quests[id]["objective"] == objective:
		return
	quests[id]["objective"] = objective
	changed.emit()


func set_progress(id: String, count: int, total := -1) -> void:
	if not is_active(id):
		return
	quests[id]["count"] = count
	if total >= 0:
		quests[id]["total"] = total
	changed.emit()


func complete(id: String) -> void:
	if not is_active(id):
		return
	quests[id]["state"] = DONE
	notify.emit("Quest complete: " + quests[id]["title"])
	changed.emit()


func fail(id: String) -> void:
	if not is_active(id):
		return
	quests[id]["state"] = FAILED
	changed.emit()


## HUD için: aktif questler, başlama sırasına göre
func active_list() -> Array:
	var out := []
	for id in quests:
		if quests[id]["state"] == ACTIVE:
			out.append(quests[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["order"] < b["order"])
	return out
