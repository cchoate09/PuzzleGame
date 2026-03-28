class_name PatchworkSteamBridge
extends RefCounted

const MANIFEST_RELATIVE_PATH := "steam/input/patchwork-post-steam-input.json"
const CLOUD_FILE_PREFIX := "patchwork_"
const CLOUD_FILE_SUFFIX := ".json"

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
		status["cloudReady"] = is_cloud_enabled()
	else:
		steam_singleton = null
		status["available"] = false
		status["provider"] = "Local Preview"
		status["cloudReady"] = false
	return status.duplicate(true)

func get_status() -> Dictionary:
	return status.duplicate(true)

func sync_pending_achievements(profile: Dictionary) -> Array:
	if steam_singleton == null:
		return []
	if not (profile is Dictionary):
		return []

	var pending: Array = profile.get("steam", {}).get("pendingAchievements", [])
	var synced: Array = []
	for achievement_id in pending:
		if set_achievement(String(achievement_id)):
			synced.append(achievement_id)
	return synced


# ---------------------------------------------------------------------------
# Achievements
# ---------------------------------------------------------------------------

func set_achievement(achievement_id: String) -> bool:
	if steam_singleton == null:
		return false
	if achievement_id.is_empty():
		return false
	# GodotSteam exposes setAchievement(name: String) -> bool
	if not steam_singleton.has_method("setAchievement"):
		return false
	var ok: bool = steam_singleton.call("setAchievement", achievement_id)
	if ok and steam_singleton.has_method("storeStats"):
		steam_singleton.call("storeStats")
	return ok

func clear_achievement(achievement_id: String) -> bool:
	if steam_singleton == null:
		return false
	if achievement_id.is_empty():
		return false
	if not steam_singleton.has_method("clearAchievement"):
		return false
	var ok: bool = steam_singleton.call("clearAchievement", achievement_id)
	if ok and steam_singleton.has_method("storeStats"):
		steam_singleton.call("storeStats")
	return ok


# ---------------------------------------------------------------------------
# Stats
# ---------------------------------------------------------------------------

func get_stat(stat_name: String) -> int:
	if steam_singleton == null:
		return 0
	if stat_name.is_empty():
		return 0
	if not steam_singleton.has_method("getStatInt"):
		return 0
	return int(steam_singleton.call("getStatInt", stat_name))

func set_stat(stat_name: String, value: int) -> bool:
	if steam_singleton == null:
		return false
	if stat_name.is_empty():
		return false
	if not steam_singleton.has_method("setStatInt"):
		return false
	var ok: bool = steam_singleton.call("setStatInt", stat_name, value)
	if ok and steam_singleton.has_method("storeStats"):
		steam_singleton.call("storeStats")
	return ok


# ---------------------------------------------------------------------------
# Cloud / Remote Storage
# ---------------------------------------------------------------------------

func is_cloud_enabled() -> bool:
	if steam_singleton == null:
		return false
	if not steam_singleton.has_method("isCloudEnabledForAccount"):
		return false
	return bool(steam_singleton.call("isCloudEnabledForAccount"))

func _cloud_filename(slot: String) -> String:
	return CLOUD_FILE_PREFIX + slot + CLOUD_FILE_SUFFIX

func upload_save(slot: String, data: String) -> bool:
	if steam_singleton == null:
		return false
	if slot.is_empty() or data.is_empty():
		return false
	if not is_cloud_enabled():
		return false
	if not steam_singleton.has_method("fileWrite"):
		return false
	var filename := _cloud_filename(slot)
	var bytes := data.to_utf8_buffer()
	return bool(steam_singleton.call("fileWrite", filename, bytes, bytes.size()))

func download_save(slot: String) -> String:
	if steam_singleton == null:
		return ""
	if slot.is_empty():
		return ""
	if not is_cloud_enabled():
		return ""
	var filename := _cloud_filename(slot)
	if not steam_singleton.has_method("fileExists"):
		return ""
	if not bool(steam_singleton.call("fileExists", filename)):
		return ""
	if not steam_singleton.has_method("getFileSize"):
		return ""
	var size: int = int(steam_singleton.call("getFileSize", filename))
	if size <= 0:
		return ""
	if not steam_singleton.has_method("fileRead"):
		return ""
	var raw_data = steam_singleton.call("fileRead", filename, size)
	if raw_data == null:
		return ""
	if raw_data is PackedByteArray:
		return (raw_data as PackedByteArray).get_string_from_utf8()
	return String(raw_data)


# ---------------------------------------------------------------------------
# Locale
# ---------------------------------------------------------------------------

func get_current_language() -> String:
	if steam_singleton == null:
		return ""
	if not steam_singleton.has_method("getCurrentGameLanguage"):
		return ""
	var lang = steam_singleton.call("getCurrentGameLanguage")
	if lang == null:
		return ""
	return String(lang)
