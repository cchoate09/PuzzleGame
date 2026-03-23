class_name PatchworkSteamBridge
extends RefCounted

const MANIFEST_RELATIVE_PATH := "steam/input/patchwork-post-steam-input.json"

var steam_singleton: Object = null
var status: Dictionary = {
	"available": false,
	"provider": "Local Preview",
	"cloudReady": false,
	"manifestPath": MANIFEST_RELATIVE_PATH,
}

func initialize() -> Dictionary:
	if Engine.has_singleton("Steam"):
		steam_singleton = Engine.get_singleton("Steam")
		status["available"] = steam_singleton != null
		status["provider"] = "Steam Stub" if steam_singleton != null else "Local Preview"
		status["cloudReady"] = false
	else:
		steam_singleton = null
		status["available"] = false
		status["provider"] = "Local Preview"
		status["cloudReady"] = false
	return status.duplicate(true)

func get_status() -> Dictionary:
	return status.duplicate(true)

func sync_pending_achievements(profile: Dictionary) -> Array:
	return []
