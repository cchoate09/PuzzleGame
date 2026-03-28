class_name PatchworkSteamAchievements
extends RefCounted

# Maps in-game achievement IDs to Steam API stat names.
# Steam API names follow Valve's recommended UPPER_SNAKE convention.
const ACHIEVEMENT_MAP: Dictionary = {
	"first-stamp":    "FIRST_STAMP",
	"side-route":     "SIDE_ROUTE",
	"careful-hands":  "CAREFUL_HANDS",
	"demo-complete":  "DEMO_COMPLETE",
	"stage-route":    "STAGE_ROUTE",
	"festival-line":  "FESTIVAL_LINE",
	"secret-line":    "SECRET_LINE",
	"archivist":      "ARCHIVIST",
	"explorer":       "EXPLORER",
}

# All known game-side achievement IDs.
const ALL_IDS: Array = [
	"first-stamp",
	"side-route",
	"careful-hands",
	"demo-complete",
	"stage-route",
	"festival-line",
	"secret-line",
	"archivist",
	"explorer",
]


static func get_steam_name(achievement_id: String) -> String:
	if achievement_id.is_empty():
		return ""
	return ACHIEVEMENT_MAP.get(achievement_id, "")


static func is_known(achievement_id: String) -> bool:
	return ACHIEVEMENT_MAP.has(achievement_id)


## Check whether an achievement is already unlocked in the profile. If not,
## attempt to grant it through the Steam bridge. Returns true when the
## achievement was newly granted during this call.
static func check_and_grant(
	profile: Dictionary,
	steam_bridge,
	achievement_id: String,
) -> bool:
	if achievement_id.is_empty():
		return false
	if not is_known(achievement_id):
		return false
	if profile == null or not (profile is Dictionary):
		return false

	# Already unlocked locally -- nothing to do.
	var achievements: Dictionary = profile.get("achievements", {})
	if not achievements.has(achievement_id):
		return false

	# Already synced to Steam -- nothing to do.
	var synced: Dictionary = profile.get("steam", {}).get("syncedAchievements", {})
	if synced.has(achievement_id):
		return false

	# No bridge available -- cannot grant right now.
	if steam_bridge == null:
		return false

	var steam_name := get_steam_name(achievement_id)
	if steam_name.is_empty():
		return false

	if not steam_bridge.has_method("set_achievement"):
		return false

	return steam_bridge.set_achievement(steam_name)
