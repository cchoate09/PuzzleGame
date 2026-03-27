import json

# Load existing campaign
with open("C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/data/source/campaign.json", "r") as f:
    data = json.load(f)

old_rooms = data["rooms"]

def get_metadata(room):
    """Extract non-gameplay fields from old room"""
    meta = {}
    for key in ["id", "districtId", "title", "optional", "unlockCost", "postmarks",
                 "objective", "blurb", "intro", "outro", "hintTiers", "achievementId",
                 "requiresRooms", "secret", "routingStamps"]:
        if key in room:
            meta[key] = room[key]
    return meta

new_rooms = []

# ROOM 1: mailroom-01 "Loose Thread" - 12x12, 2 layers
r = get_metadata(old_rooms[0])
r["layers"] = [
    {"id": "front", "name": "Front Sheet", "tiles": [
        "############",
        "#..........#",
        "#.####.###.#",
        "#.#..#.....#",
        "#.#..#.###.#",
        "#....#.#.S.#",
        "#.##.#.#.#.#",
        "#....#...#.#",
        "#.####.###.#",
        "#.#........#",
        "#.#.######.#",
        "############"
    ]},
    {"id": "back", "name": "Address Sheet", "tiles": [
        "############",
        "#.###....#.#",
        "#.....##.#.#",
        "#.###.#..#.#",
        "#.#...#.##.#",
        "#.#.###.S..#",
        "#.#.....##.#",
        "#.###.#..#.#",
        "#.....#.##.#",
        "#.###.#....#",
        "#.....#..G.#",
        "############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = []
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Teach stitched layer switching through a winding dual-layer maze.", "targetDifficulty": 3, "expectedSolveMinutes": 8, "commonMisunderstanding": "Players over-search the front sheet instead of treating the stitch as required progress."}
new_rooms.append(r)

# ROOM 2: mailroom-02 "Stamped Twice" - 12x10, 2 layers, 3 parcels
r = get_metadata(old_rooms[1])
r["layers"] = [
    {"id": "front", "name": "Front Sheet", "tiles": [
        "############",
        "#....S...#.#",
        "#.####.#...#",
        "#.#......#.#",
        "#.#.##.#.#.#",
        "#......#...#",
        "#.##.###.#.#",
        "#........#.#",
        "#.####.....#",
        "############"
    ]},
    {"id": "back", "name": "Back Sheet", "tiles": [
        "############",
        "#....S.....#",
        "#.#..####..#",
        "#.#......#.#",
        "#.####.#.#.#",
        "#......#...#",
        "#.##.#.###.#",
        "#....#.....#",
        "#.####...G.#",
        "############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 8, "facing": "right"}
r["entities"] = [
    {"id": "parcel-a", "type": "parcel", "layer": 0, "x": 3, "y": 5, "pushable": True, "solid": True},
    {"id": "parcel-b", "type": "parcel", "layer": 0, "x": 7, "y": 3, "pushable": True, "solid": True},
    {"id": "parcel-c", "type": "parcel", "layer": 0, "x": 5, "y": 7, "pushable": True, "solid": True}
]
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Teach parcel transfer with three parcels blocking critical corridors.", "targetDifficulty": 4, "expectedSolveMinutes": 10, "commonMisunderstanding": "Players try to push parcels into dead ends rather than transferring them between layers."}
new_rooms.append(r)

# ROOM 3: mailroom-03 "Forwarding Fold" - 12x10, 3 layers
r = get_metadata(old_rooms[2])
r["layers"] = [
    {"id": "crease-front", "name": "Crease Front", "tiles": [
        "############",
        "#.#....#...#",
        "#...##.#.#.#",
        "#.#.#..S.#.#",
        "#.#.#.##...#",
        "#.#.S....#.#",
        "#...#.##.#.#",
        "#.#S#....#.#",
        "#.#....##..#",
        "############"
    ]},
    {"id": "crease-mid", "name": "Crease Middle", "tiles": [
        "############",
        "#.###..#...#",
        "#......#.#.#",
        "#.#.#..S.#.#",
        "#.#.#.##...#",
        "#.#.S..#.#.#",
        "#...####.#.#",
        "#.#S#....#.#",
        "#.#......#.#",
        "############"
    ]},
    {"id": "crease-back", "name": "Crease Back", "tiles": [
        "############",
        "#.#.##.#...#",
        "#......#.#.#",
        "#.###..S.#.#",
        "#.#...##...#",
        "#.#.S..#.#.#",
        "#.#.####.#.#",
        "#.#S#......#",
        "#.#..#.#..G#",
        "############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = []
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Teach players to read three layers before committing to a stitch path.", "targetDifficulty": 4, "expectedSolveMinutes": 12, "commonMisunderstanding": "Players jump at the first stitch they find and end up trapped."}
new_rooms.append(r)

# ROOM 4: mailroom-side-01 "Return Receipt" - 12x10, 3 layers
r = get_metadata(old_rooms[3])
r["layers"] = [
    {"id": "receipt-front", "name": "Receipt Front", "tiles": [
        "############",
        "#..S.....#.#",
        "#.###.##...#",
        "#.....#..#.#",
        "#.###.#.##.#",
        "#.#...S..#.#",
        "#.#.###....#",
        "#.....#.##.#",
        "#.#S#......#",
        "############"
    ]},
    {"id": "receipt-mid", "name": "Receipt Middle", "tiles": [
        "############",
        "#..S..##.#.#",
        "#.......#..#",
        "#.###.#..#.#",
        "#.#...####.#",
        "#.#...S....#",
        "#.###.#.##.#",
        "#.....#..#.#",
        "#.#S#..#...#",
        "############"
    ]},
    {"id": "receipt-back", "name": "Receipt Back", "tiles": [
        "############",
        "#..S.#...#.#",
        "#.#....#...#",
        "#.###.##.#.#",
        "#.#......#.#",
        "#.#.#.S.##.#",
        "#.....#....#",
        "#.###.####.#",
        "#.#S#.....G#",
        "############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = []
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Teach routes alternating between three sheets with stitch planning.", "targetDifficulty": 5, "expectedSolveMinutes": 12, "commonMisunderstanding": "Players reach the first stitch and assume the puzzle is solved."}
new_rooms.append(r)

# ROOM 5: mailroom-04 "Backdated Route" - 12x10, 3 layers
r = get_metadata(old_rooms[4])
r["layers"] = [
    {"id": "dated-front", "name": "Dated Front", "tiles": [
        "############",
        "#...S....#.#",
        "#.####.#...#",
        "#.#......#.#",
        "#.#.##.#.#.#",
        "#......#...#",
        "#.##.###.#.#",
        "#........#.#",
        "#.####.#...#",
        "############"
    ]},
    {"id": "dated-mid", "name": "Dated Middle", "tiles": [
        "############",
        "#...S......#",
        "#.#..####..#",
        "#.#......#.#",
        "#.####.#.#.#",
        "#......#.S.#",
        "#.##.#.###.#",
        "#....#.....#",
        "#.####.#...#",
        "############"
    ]},
    {"id": "dated-back", "name": "Dated Back", "tiles": [
        "############",
        "#...S......#",
        "#.#.####.#.#",
        "#.#......#.#",
        "#...##.#.#.#",
        "#.#..#.S...#",
        "#.####.###.#",
        "#......#...#",
        "#.##.#...G.#",
        "############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 8, "facing": "right"}
r["entities"] = [
    {"id": "parcel-a", "type": "parcel", "layer": 0, "x": 3, "y": 7, "pushable": True, "solid": True},
    {"id": "parcel-b", "type": "parcel", "layer": 0, "x": 7, "y": 3, "pushable": True, "solid": True},
    {"id": "parcel-c", "type": "parcel", "layer": 1, "x": 5, "y": 7, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "front-plate", "layer": 0, "x": 1, "y": 7},
    {"id": "mid-plate", "layer": 1, "x": 8, "y": 3},
    {"id": "back-plate", "layer": 2, "x": 5, "y": 7}
]
r["doors"] = [
    {"id": "dated-door-a", "layer": 1, "x": 9, "y": 5, "switchIds": ["front-plate", "mid-plate"]},
    {"id": "dated-door-b", "layer": 2, "x": 9, "y": 8, "switchIds": ["back-plate"]}
]
r["balance"] = {"intendedLesson": "Cap the mailroom with three-layer traversal and triple-switch door logic.", "targetDifficulty": 5, "expectedSolveMinutes": 15, "commonMisunderstanding": "Players switch too early without managing all parcels first."}
new_rooms.append(r)

# ROOM 6: market-01 "Counterweight" - 14x10, 2 layers
r = get_metadata(old_rooms[5])
r["layers"] = [
    {"id": "awnings", "name": "Awnings", "tiles": [
        "##############",
        "#....S.....#.#",
        "#.####.###...#",
        "#.#........#.#",
        "#.#.##.#.#.#.#",
        "#......#IIII.#",
        "#.##.###.#.#.#",
        "#........#.#.#",
        "#.####.#.....#",
        "##############"
    ]},
    {"id": "arcade", "name": "Arcade", "tiles": [
        "##############",
        "#....S.....#.#",
        "#.#....###...#",
        "#.#.##.....#.#",
        "#......#.#.#.#",
        "#.####.#.....#",
        "#.#..###.#.#.#",
        "#.#......#.#.#",
        "#.####.....G.#",
        "##############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 8, "facing": "right"}
r["entities"] = [
    {"id": "parcel-a", "type": "parcel", "layer": 0, "x": 4, "y": 5, "pushable": True, "solid": True},
    {"id": "parcel-b", "type": "parcel", "layer": 0, "x": 6, "y": 3, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "market-plate-a", "layer": 0, "x": 12, "y": 5},
    {"id": "market-plate-b", "layer": 1, "x": 6, "y": 3}
]
r["doors"] = [
    {"id": "market-door", "layer": 1, "x": 11, "y": 8, "switchIds": ["market-plate-a", "market-plate-b"]}
]
r["balance"] = {"intendedLesson": "Introduce ice tiles with parcel-as-blocker and dual switches.", "targetDifficulty": 5, "expectedSolveMinutes": 12, "commonMisunderstanding": "Players step onto ice without a stopping block."}
new_rooms.append(r)

# ROOM 7: market-side-01 "Stall Shortcut" - 14x10, 2 layers
r = get_metadata(old_rooms[6])
r["layers"] = [
    {"id": "stall-front", "name": "Stall Front", "tiles": [
        "##############",
        "#....S.....#.#",
        "#.####.###...#",
        "#.#........#.#",
        "#.#I##.#.#.#.#",
        "#..I...#.....#",
        "#.#I.###.#.#.#",
        "#..I.....#.#.#",
        "#.#I##.#.....#",
        "##############"
    ]},
    {"id": "stall-back", "name": "Stall Back", "tiles": [
        "##############",
        "#....S.....#.#",
        "#.####.###...#",
        "#.#........G.#",
        "#.#.##.#.#.#.#",
        "#......#.....#",
        "#.##.###.#.#.#",
        "#........#.#.#",
        "#.####.#.....#",
        "##############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = [
    {"id": "parcel-stall", "type": "parcel", "layer": 0, "x": 3, "y": 3, "pushable": True, "solid": True}
]
r["switches"] = [{"id": "stall-plate", "layer": 0, "x": 3, "y": 8}]
r["doors"] = [{"id": "stall-door", "layer": 1, "x": 11, "y": 3, "switchIds": ["stall-plate"]}]
r["balance"] = {"intendedLesson": "Reinforce ice-slide physics with precise parcel aiming.", "targetDifficulty": 5, "expectedSolveMinutes": 10, "commonMisunderstanding": "Players push the parcel sideways instead of down the ice column."}
new_rooms.append(r)

# ROOM 8: market-02 "Counter Slot" - 14x12, 3 layers
r = get_metadata(old_rooms[7])
r["layers"] = [
    {"id": "counter-front", "name": "Counter Front", "tiles": [
        "##############",
        "#...S......#.#",
        "#.####.###...#",
        "#.#........#.#",
        "#.#.##.#.#.#.#",
        "#......#IIII.#",
        "#.##.###.#.#.#",
        "#........#.#.#",
        "#.####.#.#...#",
        "#.#......#.#.#",
        "#.#.####.....#",
        "##############"
    ]},
    {"id": "counter-mid", "name": "Counter Middle", "tiles": [
        "##############",
        "#...S......#.#",
        "#.#.##.###...#",
        "#.#........#.#",
        "#.####.#.#.#.#",
        "#......#.....#",
        "#.##.###.#.#.#",
        "#........#.S.#",
        "#.####.#.#...#",
        "#.#......#.#.#",
        "#.#.####.....#",
        "##############"
    ]},
    {"id": "counter-back", "name": "Counter Back", "tiles": [
        "##############",
        "#...S......#.#",
        "#.#..####....#",
        "#.#........#.#",
        "#...##.#.#.#.#",
        "#.#..#.#.S...#",
        "#.####.###.#.#",
        "#......#.....#",
        "#.##.#...#.#.#",
        "#.#....#.#.#.#",
        "#.####.....G.#",
        "##############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "parcel-slot", "type": "parcel", "layer": 0, "x": 3, "y": 5, "pushable": True, "solid": True},
    {"id": "parcel-counter", "type": "parcel", "layer": 0, "x": 6, "y": 9, "pushable": True, "solid": True},
    {"id": "parcel-hidden", "type": "parcel", "layer": 1, "x": 8, "y": 3, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "counter-visible-plate", "layer": 0, "x": 12, "y": 5},
    {"id": "counter-mid-plate", "layer": 1, "x": 6, "y": 9},
    {"id": "counter-hidden-plate", "layer": 2, "x": 8, "y": 3}
]
r["doors"] = [
    {"id": "counter-shutter-a", "layer": 1, "x": 10, "y": 7, "switchIds": ["counter-visible-plate"]},
    {"id": "counter-shutter-b", "layer": 2, "x": 11, "y": 10, "switchIds": ["counter-mid-plate", "counter-hidden-plate"]}
]
r["balance"] = {"intendedLesson": "Combine ice sliding with cross-layer switch activation using three parcels.", "targetDifficulty": 6, "expectedSolveMinutes": 15, "commonMisunderstanding": "Players search for a walking path behind the counter."}
new_rooms.append(r)

# ROOM 9: market-side-02 "Ledger Slip" - 14x10, 2 layers, heavy ice
r = get_metadata(old_rooms[8])
r["layers"] = [
    {"id": "ledger-front", "name": "Ledger Front", "tiles": [
        "##############",
        "#III#IIIIIIII#",
        "#I#II...#I..I#",
        "#I......#I#.I#",
        "#III#I.ISI..I#",
        "#I#II..#I#..I#",
        "#I.......I#.I#",
        "#I##.#I..I..I#",
        "#I.......IIII#",
        "##############"
    ]},
    {"id": "ledger-back", "name": "Ledger Back", "tiles": [
        "##############",
        "#III#IIIIIIII#",
        "#I...#II..I.I#",
        "#I#I.....GI.I#",
        "#I.II#.ISI..I#",
        "#I.....#I...I#",
        "#I###....I#.I#",
        "#I......#I..I#",
        "#IIIIIIIIIII.#",
        "##############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = []
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Pure ice navigation puzzle requiring both layers.", "targetDifficulty": 6, "expectedSolveMinutes": 14, "commonMisunderstanding": "Players try to navigate only on one layer."}
new_rooms.append(r)

# ROOM 10: market-03 "Inventory Check" - 14x12, 3 layers
r = get_metadata(old_rooms[9])
r["layers"] = [
    {"id": "inventory-front", "name": "Inventory Front", "tiles": [
        "##############",
        "#...S......#.#",
        "#.####.###...#",
        "#.#........#.#",
        "#.#.##.#.#.#.#",
        "#......#IIII.#",
        "#.##.###.#.#.#",
        "#........#.#.#",
        "#.####.#.#...#",
        "#.#......#.#.#",
        "#.#.####.....#",
        "##############"
    ]},
    {"id": "inventory-mid", "name": "Inventory Middle", "tiles": [
        "##############",
        "#...S......#.#",
        "#.#.##.###.S.#",
        "#.#........#.#",
        "#.####.#.#.#.#",
        "#......#.....#",
        "#.##.###.#.#.#",
        "#........#...#",
        "#.####.#.#...#",
        "#.#......#.#.#",
        "#.#.####.....#",
        "##############"
    ]},
    {"id": "inventory-back", "name": "Inventory Back", "tiles": [
        "##############",
        "#..........#.#",
        "#.####.###.S.#",
        "#.#........#.#",
        "#.#.##.#.#.#.#",
        "#......#.....#",
        "#.##.###.#.#.#",
        "#........#...#",
        "#.####.#.#...#",
        "#.#......#.#.#",
        "#.#.####...G.#",
        "##############"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "parcel-visible", "type": "parcel", "layer": 0, "x": 3, "y": 5, "pushable": True, "solid": True},
    {"id": "parcel-hidden", "type": "parcel", "layer": 0, "x": 5, "y": 9, "pushable": True, "solid": True},
    {"id": "parcel-deep", "type": "parcel", "layer": 1, "x": 7, "y": 7, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "inventory-visible-plate", "layer": 0, "x": 12, "y": 5},
    {"id": "inventory-mid-plate", "layer": 1, "x": 5, "y": 9},
    {"id": "inventory-hidden-plate", "layer": 2, "x": 7, "y": 7}
]
r["doors"] = [
    {"id": "inventory-shutter-a", "layer": 1, "x": 12, "y": 2, "switchIds": ["inventory-visible-plate"]},
    {"id": "inventory-shutter-b", "layer": 2, "x": 11, "y": 10, "switchIds": ["inventory-mid-plate", "inventory-hidden-plate"]}
]
r["balance"] = {"intendedLesson": "Cap the market with three-layer parcel management and triple switch logic.", "targetDifficulty": 7, "expectedSolveMinutes": 18, "commonMisunderstanding": "Players try to solve the visible plate first."}
new_rooms.append(r)

# ROOM 11: greenhouse-01 "Paper Vines" - 16x12, 3 layers
r = get_metadata(old_rooms[10])
r["layers"] = [
    {"id": "lantern-bed", "name": "Lantern Bed", "tiles": [
        "################",
        "#....S.......#.#",
        "#.####.###.#...#",
        "#.>........#.#.#",
        "#.#.##.#.#...#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#.v......#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####......<#",
        "################"
    ]},
    {"id": "vine-mid", "name": "Vine Middle", "tiles": [
        "################",
        "#....S.......#.#",
        "#.#.##.###.#...#",
        "#.v........#.#.#",
        "#.####.#.#...#.#",
        "#......#.S.#...#",
        "#.##.###.#.#.#.#",
        "#.^......#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "vine-bed", "name": "Vine Bed", "tiles": [
        "################",
        "#............#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#~##.#.#.S.#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####......G#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "lantern-a", "type": "projector", "layer": 0, "x": 4, "y": 5, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": 0, "dy": -1}]}
]
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Introduce one-way gates alongside projector alignment across three layers.", "targetDifficulty": 6, "expectedSolveMinutes": 14, "commonMisunderstanding": "Players go through one-way gates the wrong direction."}
new_rooms.append(r)

# ROOM 12: greenhouse-side-01 "Graft Line" - 16x12, 3 layers
r = get_metadata(old_rooms[11])
r["layers"] = [
    {"id": "graft-top", "name": "Graft Top", "tiles": [
        "################",
        "#.>..S.......#.#",
        "#.#.##.###.#...#",
        "#.v........#.#.#",
        "#.#.II.#.#...#.#",
        "#.#.II.#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#.<.#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "graft-mid", "name": "Graft Middle", "tiles": [
        "################",
        "#....S.......#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#.##.#.#...#.#",
        "#.#....#.S.#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "graft-bottom", "name": "Graft Bottom", "tiles": [
        "################",
        "#............#.#",
        "#.####.###.#...#",
        "#......~...#.#.#",
        "#.#.##.#.#.S.#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#G#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "lantern-offset", "type": "projector", "layer": 0, "x": 3, "y": 4, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": 3, "dy": -1}]}
]
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Combine offset projection with ice and one-way gates across three layers.", "targetDifficulty": 6, "expectedSolveMinutes": 15, "commonMisunderstanding": "Players line the lantern up directly instead of accounting for the shifted beam."}
new_rooms.append(r)

# ROOM 13: greenhouse-02 "Overgrowth" - 16x12, 3 layers, 2 projectors
r = get_metadata(old_rooms[12])
r["layers"] = [
    {"id": "overgrowth-top", "name": "Overgrowth Top", "tiles": [
        "################",
        "#....S.......#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#.##.#.#...#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "overgrowth-middle", "name": "Overgrowth Middle", "tiles": [
        "################",
        "#....S.....#.#.#",
        "#.#.~####.#....#",
        "#.#........#.#.#",
        "#......#.#...#.#",
        "#.###.##...#...#",
        "#..........#.#.#",
        "#.####.S.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "overgrowth-bottom", "name": "Overgrowth Bottom", "tiles": [
        "################",
        "#.............#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#..~.#.#.S.#.#",
        "#.#.##.#...#...#",
        "#..........#.#.#",
        "#.####.#.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.#.####......G#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "lantern-a", "type": "projector", "layer": 0, "x": 5, "y": 3, "pushable": True, "solid": True, "projectionTargets": [{"layer": 1, "dx": -2, "dy": -1}]},
    {"id": "lantern-b", "type": "projector", "layer": 0, "x": 8, "y": 6, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -3, "dy": -2}]}
]
r["switches"] = []
r["doors"] = []
r["balance"] = {"intendedLesson": "Three-layer projection requiring two projectors with offset beams.", "targetDifficulty": 7, "expectedSolveMinutes": 16, "commonMisunderstanding": "Players align one projector and forget the second bridge."}
new_rooms.append(r)

# ROOM 14: greenhouse-03 "Misted Gate" - 16x12, 3 layers
r = get_metadata(old_rooms[13])
r["layers"] = [
    {"id": "mist-top", "name": "Mist Top", "tiles": [
        "################",
        "#...S.......#.#",
        "#.####.###.#...#",
        "#.>........#.#.#",
        "#.#.##.#.#...#.#",
        "#II....#...#...#",
        "#.##.###.#.#v#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#.<.#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "mist-middle", "name": "Mist Middle", "tiles": [
        "################",
        "#...S.......#.#",
        "#.#.####.#.#...#",
        "#..........#.#.#",
        "#.###.##.#...#.#",
        "#......#...#...#",
        "#..........#.#.#",
        "#.####.S.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "mist-bottom", "name": "Mist Bottom", "tiles": [
        "################",
        "#...........#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#~##.#.#.S.#.#",
        "#.#.##.#...#...#",
        "#..........#.#.#",
        "#.####.#.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.###.####...G.#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "parcel-mist", "type": "parcel", "layer": 0, "x": 4, "y": 5, "pushable": True, "solid": True},
    {"id": "lantern-mist", "type": "projector", "layer": 0, "x": 6, "y": 4, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -2, "dy": 0}]},
    {"id": "parcel-mist-b", "type": "parcel", "layer": 1, "x": 5, "y": 9, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "mist-plate-a", "layer": 0, "x": 1, "y": 5},
    {"id": "mist-plate-b", "layer": 1, "x": 5, "y": 9}
]
r["doors"] = [
    {"id": "mist-door-a", "layer": 2, "x": 7, "y": 10, "switchIds": ["mist-plate-a"]},
    {"id": "mist-door-b", "layer": 2, "x": 12, "y": 4, "switchIds": ["mist-plate-b"]}
]
r["balance"] = {"intendedLesson": "Combine one-way gates, ice, projection, and dual switches across three layers.", "targetDifficulty": 7, "expectedSolveMinutes": 18, "commonMisunderstanding": "Players try to solve the bridge first."}
new_rooms.append(r)

# ROOM 15: greenhouse-04 "Festival Draft" - 16x14, 3 layers
r = get_metadata(old_rooms[14])
r["layers"] = [
    {"id": "draft-roof", "name": "Draft Roof", "tiles": [
        "################",
        "#...S.........#",
        "#.########.#..#",
        "#.............#",
        "#.#..#.#.#.#..#",
        "#.#.##........#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.########.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.............#",
        "################"
    ]},
    {"id": "draft-middle", "name": "Draft Middle", "tiles": [
        "################",
        "#...S.........#",
        "#.#.######.#..#",
        "#.#..~......#.#",
        "#......#.#.#..#",
        "#.###.##......#",
        "#.............#",
        "#.####.S.#.#..#",
        "#.............#",
        "#.########.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.............#",
        "################"
    ]},
    {"id": "draft-floor", "name": "Draft Floor", "tiles": [
        "################",
        "#.............#",
        "#.########.#..#",
        "#.............#",
        "#.#..~.#.#.S.##",
        "#.#.##....#...#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.########.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.#########..G#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "parcel-draft", "type": "parcel", "layer": 0, "x": 3, "y": 12, "pushable": True, "solid": True},
    {"id": "parcel-draft-b", "type": "parcel", "layer": 0, "x": 8, "y": 6, "pushable": True, "solid": True},
    {"id": "lantern-draft-a", "type": "projector", "layer": 0, "x": 6, "y": 3, "pushable": True, "solid": True, "projectionTargets": [{"layer": 1, "dx": 0, "dy": 0}]},
    {"id": "lantern-draft-b", "type": "projector", "layer": 0, "x": 10, "y": 8, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -5, "dy": -4}]}
]
r["switches"] = [
    {"id": "draft-plate-a", "layer": 0, "x": 1, "y": 12},
    {"id": "draft-plate-b", "layer": 0, "x": 8, "y": 10}
]
r["doors"] = [
    {"id": "draft-door-a", "layer": 2, "x": 13, "y": 12, "switchIds": ["draft-plate-a"]},
    {"id": "draft-door-b", "layer": 1, "x": 12, "y": 3, "switchIds": ["draft-plate-b"]}
]
r["balance"] = {"intendedLesson": "Cap the demo slice with three-sheet traversal and dual projection.", "targetDifficulty": 8, "expectedSolveMinutes": 22, "commonMisunderstanding": "Players keep looking for the goal on the middle sheet."}
new_rooms.append(r)

# ROOM 16: clocktower-01 "One Bell Late" - 16x12, 3 layers + gravity
r = get_metadata(old_rooms[15])
r["layers"] = [
    {"id": "clock-face", "name": "Clock Face", "tiles": [
        "################",
        "#..........#...#",
        "#.####.###.#.#.#",
        "#......#...#...#",
        "#.#..#.#.#...#.#",
        "#.#.##.......#.#",
        "#..........#.#.#",
        "#.####.#.#.#...#",
        "#..........#.#.#",
        "#.####.###.....#",
        "#............G.#",
        "################"
    ]},
    {"id": "inner-works", "name": "Inner Works", "tiles": [
        "################",
        "#..........#...#",
        "#.####.###.#.#.#",
        "#..T...#...#...#",
        "#.#..#.#.#...#.#",
        "#.#.##.......#.#",
        "#..........#.#.#",
        "#.####.#.#.#.T.#",
        "#..........#.#.#",
        "#.####.###.....#",
        "#..............#",
        "################"
    ]},
    {"id": "bell-gear", "name": "Bell Gear", "tiles": [
        "################",
        "#..........#...#",
        "#.####.###.#.#.#",
        "#......#F..#...#",
        "#.#..#.#F#...#.#",
        "#.#.##..F....#.#",
        "#..........#.#.#",
        "#.####.#.#.#...#",
        "#..........#.#.#",
        "#.####.###.....#",
        "#..............#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = [
    {"id": "echo-a", "type": "echo", "layer": 1, "x": 1, "y": 9, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None}
]
r["switches"] = [{"id": "clock-plate", "layer": 1, "x": 13, "y": 7}]
r["doors"] = [{"id": "clock-door", "layer": 0, "x": 8, "y": 9, "switchIds": ["clock-plate"]}]
r["teleporters"] = [
    {"id": "tp-clock-a1", "layer": 1, "x": 3, "y": 3, "pairId": "tp-clock-a2"},
    {"id": "tp-clock-a2", "layer": 1, "x": 13, "y": 7, "pairId": "tp-clock-a1"}
]
r["balance"] = {"intendedLesson": "Teach echo timing with teleporter mechanics and gravity tiles.", "targetDifficulty": 6, "expectedSolveMinutes": 15, "commonMisunderstanding": "Players move too quickly and forget the echo delay."}
new_rooms.append(r)

# ROOM 17: clocktower-02 "Borrowed Bell" - 16x12, 3 layers
r = get_metadata(old_rooms[16])
r["layers"] = [
    {"id": "clock-borrowed-front", "name": "Borrowed Face", "tiles": [
        "################",
        "#..S.........#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#.##.#.#...#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "clock-borrowed-mid", "name": "Bell Mechanism", "tiles": [
        "################",
        "#..S.........#.#",
        "#.#.##.###.#...#",
        "#..........#.#.#",
        "#.####.#.#...#.#",
        "#......#...#.S.#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "clock-borrowed-back", "name": "Bell Frame", "tiles": [
        "################",
        "#..S.........#.#",
        "#.#..####.#....#",
        "#.#........#.G.#",
        "#...##.#.#.S.#.#",
        "#.#..#.#...#...#",
        "#.####.###.#.#.#",
        "#......#.#.#.#.#",
        "#.##.#.#.#...#.#",
        "#.#......#.#...#",
        "#.####.........#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "echo-borrowed", "type": "echo", "layer": 1, "x": 1, "y": 9, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None},
    {"id": "parcel-bell", "type": "parcel", "layer": 0, "x": 6, "y": 8, "pushable": True, "solid": True},
    {"id": "parcel-bell-b", "type": "parcel", "layer": 1, "x": 8, "y": 3, "pushable": True, "solid": True}
]
r["switches"] = [
    {"id": "clock-echo-plate", "layer": 1, "x": 5, "y": 9},
    {"id": "clock-parcel-plate", "layer": 1, "x": 12, "y": 5},
    {"id": "clock-back-plate", "layer": 2, "x": 8, "y": 3}
]
r["doors"] = [
    {"id": "clock-door-a", "layer": 0, "x": 5, "y": 3, "switchIds": ["clock-echo-plate"]},
    {"id": "clock-door-b", "layer": 1, "x": 13, "y": 5, "switchIds": ["clock-parcel-plate"]},
    {"id": "clock-door-c", "layer": 2, "x": 12, "y": 3, "switchIds": ["clock-back-plate"]}
]
r["teleporters"] = [
    {"id": "tp-bell-a1", "layer": 0, "x": 10, "y": 8, "pairId": "tp-bell-a2"},
    {"id": "tp-bell-a2", "layer": 1, "x": 12, "y": 3, "pairId": "tp-bell-a1"}
]
r["routingStamps"] = []
r["balance"] = {"intendedLesson": "Combine echo timing with dual parcel management and cross-layer teleportation.", "targetDifficulty": 7, "expectedSolveMinutes": 18, "commonMisunderstanding": "Players switch too early and forget the echo."}
new_rooms.append(r)

# ROOM 18: clocktower-03 "Stamped Exit" - 16x12, 3 layers, conveyors
r = get_metadata(old_rooms[17])
r["layers"] = [
    {"id": "clock-stamp-front", "name": "Clock Top", "tiles": [
        "################",
        "#..#.........#.#",
        "#.##.#.T.###...#",
        "#..........#.#.#",
        "#.#.##.#.#...#.#",
        "#.#RRR.#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "clock-stamp-middle", "name": "Clock Middle", "tiles": [
        "################",
        "#....#.......#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#..#.#.#...#.#",
        "#.T.##.......#.#",
        "#..........T.#.#",
        "#.####.#.#.#...#",
        "#..........#.#.#",
        "#.####.###.....#",
        "#..............#",
        "################"
    ]},
    {"id": "clock-stamp-back", "name": "Clock Bottom", "tiles": [
        "################",
        "#............#.#",
        "#.#T####.#.#...#",
        "#.#........#.#.#",
        "#...#.##.#...#.#",
        "#.#.##.......#.#",
        "#......DDD.#.#.#",
        "#.####.#.#.#...#",
        "#..........#.#.#",
        "#.####.###.....#",
        "#.............G#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 1, "facing": "right"}
r["entities"] = []
r["switches"] = []
r["doors"] = []
r["teleporters"] = [
    {"id": "tp-chain-a1", "layer": 0, "x": 7, "y": 2, "pairId": "tp-chain-a2"},
    {"id": "tp-chain-a2", "layer": 1, "x": 2, "y": 5, "pairId": "tp-chain-a1"},
    {"id": "tp-chain-b1", "layer": 1, "x": 11, "y": 6, "pairId": "tp-chain-b2"},
    {"id": "tp-chain-b2", "layer": 2, "x": 3, "y": 2, "pairId": "tp-chain-b1"}
]
r["balance"] = {"intendedLesson": "Multi-layer teleporter chains with conveyor belts.", "targetDifficulty": 7, "expectedSolveMinutes": 16, "commonMisunderstanding": "Players get disoriented across layers."}
new_rooms.append(r)

# ROOM 19: clocktower-side-01 "Pendulum Route" - 16x12, 3 layers
r = get_metadata(old_rooms[18])
r["layers"] = [
    {"id": "clock-pendulum-front", "name": "Pendulum Face", "tiles": [
        "################",
        "#...S......#..#",
        "#.####.###....#",
        "#.>..........##",
        "#.#..#..#.#.#.#",
        "#.#.##....#.#.#",
        "#.........#.#.#",
        "#.####.#....#.#",
        "#.......#.#.#.#",
        "#.####.###.<..#",
        "#.............#",
        "################"
    ]},
    {"id": "clock-pendulum-middle", "name": "Pendulum Frame", "tiles": [
        "################",
        "#...S..T.....##",
        "#.#.####.###..#",
        "#.v..........^#",
        "#......#.#..#.#",
        "#.###.##..#.#.#",
        "#.........#.#.#",
        "#.####.#....#.#",
        "#.......#.#.#.#",
        "#.####.###.S..#",
        "#.............#",
        "################"
    ]},
    {"id": "clock-pendulum-back", "name": "Bell Route", "tiles": [
        "################",
        "#............G#",
        "#.####.###.#..#",
        "#.T..........^#",
        "#.#..#..#.#.#.#",
        "#.#.##....#.#.#",
        "#.........#.#.#",
        "#.####.#....#.#",
        "#.......#.#.#.#",
        "#.####.###.S..#",
        "#.............#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "echo-pendulum", "type": "echo", "layer": 1, "x": 1, "y": 10, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None}
]
r["switches"] = [{"id": "clock-pendulum-plate", "layer": 1, "x": 12, "y": 1}]
r["doors"] = [{"id": "clock-pendulum-door", "layer": 0, "x": 7, "y": 1, "switchIds": ["clock-pendulum-plate"]}]
r["teleporters"] = [
    {"id": "tp-pend-a1", "layer": 1, "x": 7, "y": 1, "pairId": "tp-pend-a2"},
    {"id": "tp-pend-a2", "layer": 1, "x": 12, "y": 3, "pairId": "tp-pend-a1"},
    {"id": "tp-pend-b1", "layer": 1, "x": 3, "y": 8, "pairId": "tp-pend-b2"},
    {"id": "tp-pend-b2", "layer": 2, "x": 3, "y": 3, "pairId": "tp-pend-b1"}
]
r["balance"] = {"intendedLesson": "Combine echo timing with teleporter chains and one-way gates across three layers.", "targetDifficulty": 8, "expectedSolveMinutes": 20, "commonMisunderstanding": "Players forget the final climb."}
new_rooms.append(r)

# ROOM 20: theater-01 "Understudy" - 16x12, 3 layers
r = get_metadata(old_rooms[19])
r["layers"] = [
    {"id": "stage", "name": "Stage", "tiles": [
        "################",
        "#..........#...#",
        "#.####.###.#.#.#",
        "#.#......#.#...#",
        "#.#.##.#...#.#.#",
        "#......#.#...#.#",
        "#.##.###.#.#.#.#",
        "#........#.#...#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####......G#",
        "################"
    ]},
    {"id": "backdrop", "name": "Backdrop", "tiles": [
        "################",
        "#..........#...#",
        "#.#.####.#.#.#.#",
        "#.#......#.#...#",
        "#.#..#.#...#.#.#",
        "#...##.#.#...#.#",
        "#.##.###.#.#.#.#",
        "#........#.#...#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "wings", "name": "Wings", "tiles": [
        "################",
        "#II........#...#",
        "#I####.###.#.#.#",
        "#I#......#.#...#",
        "#I#.##.#...#.#.#",
        "#I.....#.#...#.#",
        "#I##.###.#.#.#.#",
        "#I.......#.#...#",
        "#I####.#.#...#.#",
        "#I#......#.#...#",
        "#I#.####.......#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 3, "y": 5, "facing": "right"}
r["entities"] = [
    {"id": "shadow-a", "type": "shadow", "layer": 1, "x": 12, "y": 5, "solid": True, "pushable": False, "mirrorAxis": "vertical"}
]
r["switches"] = [{"id": "stage-plate", "layer": 1, "x": 8, "y": 2}]
r["doors"] = [{"id": "stage-door", "layer": 0, "x": 8, "y": 5, "switchIds": ["stage-plate"]}]
r["balance"] = {"intendedLesson": "Teach mirrored shadow movement with larger maze and ice wings layer.", "targetDifficulty": 7, "expectedSolveMinutes": 15, "commonMisunderstanding": "Players track their own movement but not the shadow."}
new_rooms.append(r)

# ROOM 21: theater-02 "Latch Cue" - 16x12, 3 layers
r = get_metadata(old_rooms[20])
r["layers"] = [
    {"id": "stage-latch-front", "name": "Stage", "tiles": [
        "################",
        "#..S.........#.#",
        "#.####.###.#...#",
        "#.......II.#.#.#",
        "#.#.##.#.#...#.#",
        "#.#....#...#...#",
        "#.##.###.#.#.#.#",
        "#........#.#.#.#",
        "#.####.#.#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "stage-latch-middle", "name": "Wings", "tiles": [
        "################",
        "#..S.........#.#",
        "#.#.####.#.#...#",
        "#..........#.#.#",
        "#.####.#.#...#.#",
        "#......#...#...#",
        "#..........#.#.#",
        "#.####.S.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.#.####.......#",
        "################"
    ]},
    {"id": "stage-latch-back", "name": "Backstage", "tiles": [
        "################",
        "#...........#.#",
        "#.####.###.#...#",
        "#..........#.#.#",
        "#.#..#.#.#.S.#.#",
        "#.#.##.#...#...#",
        "#..........#.#.#",
        "#.####.#.#.#.#.#",
        "#........#...#.#",
        "#.#......#.#...#",
        "#.###.####...G.#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 10, "facing": "right"}
r["entities"] = [
    {"id": "shadow-latch", "type": "shadow", "layer": 1, "x": 14, "y": 10, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "parcel-stage", "type": "parcel", "layer": 2, "x": 6, "y": 8, "pushable": True, "solid": True}
]
r["switches"] = [{"id": "stage-latch-switch", "layer": 1, "x": 4, "y": 2, "sticky": True}]
r["doors"] = [{"id": "stage-latch-door", "layer": 2, "x": 11, "y": 10, "switchIds": ["stage-latch-switch"]}]
r["routingStamps"] = []
r["balance"] = {"intendedLesson": "Combine shadow latching with ice physics and three-layer navigation.", "targetDifficulty": 7, "expectedSolveMinutes": 18, "commonMisunderstanding": "Players assume the shadow must keep standing on the switch."}
new_rooms.append(r)

# ROOM 22: theater-03 "Marked Landing" - 16x12, 4 layers
r = get_metadata(old_rooms[21])
r["layers"] = [
    {"id": "stage-mark-front", "name": "Stage Floor", "tiles": [
        "################",
        "#...S......#..#",
        "#.>###.###....#",
        "#.#........v..#",
        "#...#.##.#..#.#",
        "#.#.##...#..#.#",
        "#......<......#",
        "#.####.###..#.#",
        "#..........#..#",
        "#.#.####......#",
        "#.............#",
        "################"
    ]},
    {"id": "stage-mark-mid", "name": "Wing Grid", "tiles": [
        "################",
        "#...S......#..#",
        "#.#.####.###..#",
        "#.............#",
        "#.....##.#..#.#",
        "#.###.....#.#.#",
        "#.............#",
        "#.####.###..#.#",
        "#..........#..#",
        "#.#.####......#",
        "#.............#",
        "################"
    ]},
    {"id": "stage-mark-back", "name": "Spotlight Grid", "tiles": [
        "################",
        "#...S......#..#",
        "#.####.###....#",
        "#.............#",
        "#.#..#.##.#.#.#",
        "#.#.##...#..#.#",
        "#.............#",
        "#.####.###..#.#",
        "#..........#..#",
        "#.#.####......#",
        "#.............#",
        "################"
    ]},
    {"id": "stage-mark-deep", "name": "Deep Stage", "tiles": [
        "################",
        "#...S........G#",
        "#.####.###.#..#",
        "#.............#",
        "#.#..#.##.#.#.#",
        "#.#.##...#..#.#",
        "#.............#",
        "#.####.###..#.#",
        "#..........#..#",
        "#.#.####......#",
        "#.............#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 3, "y": 7, "facing": "right"}
r["entities"] = [
    {"id": "shadow-mark-a", "type": "shadow", "layer": 1, "x": 12, "y": 7, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "shadow-mark-b", "type": "shadow", "layer": 2, "x": 12, "y": 7, "solid": True, "pushable": False, "mirrorAxis": "vertical"}
]
r["switches"] = [
    {"id": "stage-mark-switch-a", "layer": 1, "x": 6, "y": 3, "sticky": True},
    {"id": "stage-mark-switch-b", "layer": 2, "x": 6, "y": 3, "sticky": True}
]
r["doors"] = [
    {"id": "stage-mark-door-a", "layer": 0, "x": 8, "y": 1, "switchIds": ["stage-mark-switch-a"]},
    {"id": "stage-mark-door-b", "layer": 3, "x": 13, "y": 1, "switchIds": ["stage-mark-switch-b"]}
]
r["balance"] = {"intendedLesson": "Dual shadow coordination with one-way gates across four layers.", "targetDifficulty": 8, "expectedSolveMinutes": 22, "commonMisunderstanding": "Players plan for one shadow and forget the other."}
new_rooms.append(r)

# ROOM 23: theater-side-01 "Backstage Fold" - 16x14, 3 layers
r = get_metadata(old_rooms[22])
r["layers"] = [
    {"id": "stage-fold-front", "name": "Front Curtain", "tiles": [
        "################",
        "#...S.........#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.#..#.#.#.#..#",
        "#.#.##........#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "################"
    ]},
    {"id": "stage-fold-middle", "name": "Backstage Grid", "tiles": [
        "################",
        "#...S..T......#",
        "#.#.####.#.#..#",
        "#.............#",
        "#......#.#.#..#",
        "#.###.##......#",
        "#.T...........#",
        "#.####.S.#.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "################"
    ]},
    {"id": "stage-fold-back", "name": "Fly Loft", "tiles": [
        "################",
        "#.T...........#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.#..#.#.#.#..#",
        "#.#.##.S......#",
        "#.............#",
        "#.####.#.#.#..#",
        "#.............#",
        "#.####.###.#..#",
        "#.............#",
        "#.####.#.#.#..#",
        "#............G#",
        "################"
    ]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "shadow-fold", "type": "shadow", "layer": 1, "x": 14, "y": 12, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "echo-fold", "type": "echo", "layer": 1, "x": 1, "y": 4, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None}
]
r["switches"] = [
    {"id": "stage-fold-shadow-switch", "layer": 1, "x": 6, "y": 4, "sticky": True},
    {"id": "stage-fold-echo-switch", "layer": 1, "x": 12, "y": 1}
]
r["doors"] = [
    {"id": "stage-fold-door-a", "layer": 0, "x": 7, "y": 1, "switchIds": ["stage-fold-shadow-switch"]},
    {"id": "stage-fold-door-b", "layer": 1, "x": 13, "y": 4, "switchIds": ["stage-fold-echo-switch"]}
]
r["teleporters"] = [
    {"id": "tp-fold-a1", "layer": 1, "x": 7, "y": 1, "pairId": "tp-fold-a2"},
    {"id": "tp-fold-a2", "layer": 1, "x": 2, "y": 6, "pairId": "tp-fold-a1"},
    {"id": "tp-fold-b1", "layer": 1, "x": 5, "y": 12, "pairId": "tp-fold-b2"},
    {"id": "tp-fold-b2", "layer": 2, "x": 2, "y": 1, "pairId": "tp-fold-b1"}
]
r["balance"] = {"intendedLesson": "The ultimate theater challenge combining shadow, echo, and teleporters.", "targetDifficulty": 9, "expectedSolveMinutes": 25, "commonMisunderstanding": "Players keep searching the middle sheet for the goal."}
new_rooms.append(r)

# Rooms 24-31: rooftops + attic (keeping same structure but bigger)
# ROOM 24: rooftops-01 - 18x14, 3 layers
r = get_metadata(old_rooms[23])
r["layers"] = [
    {"id": "roofline", "name": "Roofline", "tiles": ["##################","#...S..........#.#","#.####.###.#.#...#","#.>............#.#","#.#..#.#.#.#.#.#.#","#.#IIIIII..#.....#","#.##.###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#.<.#","#.#.####.........#","##################"]},
    {"id": "gutter-mid", "name": "Gutter Middle", "tiles": ["##################","#...S..........#.#","#.#.##.###.#.#...#","#.v............^.#","#.####.#.#.#.#.#.#","#......#...#.....#","#.##.###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.S...#","#.#.####.........#","##################"]},
    {"id": "gutter", "name": "Gutter Route", "tiles": ["##################","#................#","#.####.###.#.#...#","#..............#.#","#.#~.#.#.#.#.#.#.#","#.#.##.#...#.S...#","#.##.###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#...#","#.#.####.......G.#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "parcel-d", "type": "parcel", "layer": 0, "x": 3, "y": 5, "pushable": True, "solid": True},
    {"id": "parcel-e", "type": "parcel", "layer": 0, "x": 7, "y": 10, "pushable": True, "solid": True},
    {"id": "parcel-f", "type": "parcel", "layer": 1, "x": 9, "y": 7, "pushable": True, "solid": True},
    {"id": "lantern-b", "type": "projector", "layer": 0, "x": 5, "y": 3, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -1, "dy": 1}]}
]
r["switches"] = [{"id": "roof-plate-a", "layer": 0, "x": 15, "y": 5}, {"id": "roof-plate-b", "layer": 1, "x": 7, "y": 10}, {"id": "roof-plate-c", "layer": 1, "x": 9, "y": 7}]
r["doors"] = [{"id": "roof-door-a", "layer": 2, "x": 15, "y": 12, "switchIds": ["roof-plate-a", "roof-plate-b"]}, {"id": "roof-door-b", "layer": 1, "x": 14, "y": 11, "switchIds": ["roof-plate-c"]}]
r["balance"] = {"intendedLesson": "Combine all previous mechanics.", "targetDifficulty": 8, "expectedSolveMinutes": 22, "commonMisunderstanding": "Players solve the bridge first and discover they need the door open."}
new_rooms.append(r)

# ROOM 25: rooftops-02 - 18x14
r = get_metadata(old_rooms[24])
r["layers"] = [
    {"id": "roof-forward-top", "name": "Roofline", "tiles": ["##################","#...S..........#.#","#.######.###.#...#","#..............#.#","#.#..#.#.#II.#.#.#","#.#.##.......#...#","#.##.###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#...#","#.#.####.........#","##################"]},
    {"id": "roof-forward-middle", "name": "Forwarded Middle", "tiles": ["##################","#...S..........#.#","#.#.####.###.#...#","#.T............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.S...#","#..............#.#","#.#.####.#.......#","#.#.####.........#","##################"]},
    {"id": "roof-forward-bottom", "name": "Forwarded Span", "tiles": ["##################","#................#","#.######.###.#...#","#.T............#.#","#.#..~.#.#.S.#.#.#","#.#.##.......#...#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.......G.#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "shadow-roof", "type": "shadow", "layer": 1, "x": 16, "y": 12, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "lantern-forward", "type": "projector", "layer": 0, "x": 8, "y": 4, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -3, "dy": 0}]}
]
r["switches"] = [{"id": "roof-shadow-plate", "layer": 1, "x": 7, "y": 3, "sticky": True}]
r["doors"] = [{"id": "roof-forward-door", "layer": 2, "x": 14, "y": 12, "switchIds": ["roof-shadow-plate"]}]
r["teleporters"] = [
    {"id": "tp-roof-a1", "layer": 0, "x": 15, "y": 1, "pairId": "tp-roof-a2"},
    {"id": "tp-roof-a2", "layer": 1, "x": 2, "y": 3, "pairId": "tp-roof-a1"},
    {"id": "tp-roof-b1", "layer": 1, "x": 15, "y": 9, "pairId": "tp-roof-b2"},
    {"id": "tp-roof-b2", "layer": 2, "x": 2, "y": 3, "pairId": "tp-roof-b1"}
]
r["balance"] = {"intendedLesson": "Combine shadow latching, ice-based projector placement, and teleporter chains.", "targetDifficulty": 8, "expectedSolveMinutes": 22, "commonMisunderstanding": "Players push the lantern directly under the gap."}
new_rooms.append(r)

# ROOM 26: rooftops-03 - 18x14
r = get_metadata(old_rooms[25])
r["layers"] = [
    {"id": "roof-transfer-top", "name": "Top Route", "tiles": ["##################","#...S..........#.#","#.######.###.#...#","#..............#.#","#.#..#.#.#.#.#.#.#","#.#.##.......#...#","#.##.###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#...#","#.#.####.........#","##################"]},
    {"id": "roof-transfer-middle", "name": "Middle Route", "tiles": ["##################","#...S..........#.#","#.#.####.###.#...#","#..............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#..........#.#.#.#","#.####.S.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.........#","##################"]},
    {"id": "roof-transfer-bottom", "name": "Stamped Lane", "tiles": ["##################","#................#","#.######.###.#...#","#..............#.#","#.#..#.#.#.S.#.#.#","#.#.##.......#...#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.......G.#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "parcel-stamped-a", "type": "parcel", "layer": 0, "x": 4, "y": 8, "pushable": True, "solid": True},
    {"id": "parcel-stamped-b", "type": "parcel", "layer": 0, "x": 10, "y": 3, "pushable": True, "solid": True},
    {"id": "parcel-stamped-c", "type": "parcel", "layer": 1, "x": 6, "y": 10, "pushable": True, "solid": True}
]
r["switches"] = [{"id": "roof-visible-plate", "layer": 0, "x": 15, "y": 8}, {"id": "roof-hidden-plate", "layer": 2, "x": 4, "y": 8}, {"id": "roof-mid-plate", "layer": 1, "x": 6, "y": 10}]
r["doors"] = [
    {"id": "roof-door-a", "layer": 2, "x": 14, "y": 12, "switchIds": ["roof-visible-plate"]},
    {"id": "roof-door-b", "layer": 2, "x": 15, "y": 5, "switchIds": ["roof-hidden-plate", "roof-mid-plate"]}
]
r["teleporters"] = [
    {"id": "tp-transfer-a1", "layer": 0, "x": 16, "y": 1, "pairId": "tp-transfer-a2"},
    {"id": "tp-transfer-a2", "layer": 1, "x": 2, "y": 5, "pairId": "tp-transfer-a1"},
    {"id": "tp-transfer-b1", "layer": 1, "x": 15, "y": 11, "pairId": "tp-transfer-b2"},
    {"id": "tp-transfer-b2", "layer": 2, "x": 2, "y": 3, "pairId": "tp-transfer-b1"}
]
r["balance"] = {"intendedLesson": "Triple parcel management across three layers with teleporter-assisted navigation.", "targetDifficulty": 8, "expectedSolveMinutes": 24, "commonMisunderstanding": "Players try to walk the parcel manually."}
new_rooms.append(r)

# ROOM 27: rooftops-side-01 - 18x14
r = get_metadata(old_rooms[26])
r["layers"] = [
    {"id": "sky-postscript-top", "name": "Upper Roof", "tiles": ["##################","#...S..........#.#","#.######.###.#...#","#.>............#.#","#.#..#.#.#II.#.#.#","#.#.##.......#...#","#.v..###.#.#.#.#.#","#..........#.#.#.#","#.####.<.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#...#","#.#.####.........#","##################"]},
    {"id": "sky-postscript-middle", "name": "Margin Route", "tiles": ["##################","#...S..........#.#","#.#.####.###.#...#","#..............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#..........#.#.#.#","#.####.S.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.........#","##################"]},
    {"id": "sky-postscript-bottom", "name": "Skyline Note", "tiles": ["##################","#................#","#.######.###.#...#","#..............#.#","#.#..~.#.#.S.#.#.#","#.#.##.......#...#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.......G.#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "lantern-postscript", "type": "projector", "layer": 0, "x": 7, "y": 4, "pushable": True, "solid": True, "projectionTargets": [{"layer": 2, "dx": -2, "dy": 0}]},
    {"id": "echo-sky", "type": "echo", "layer": 1, "x": 1, "y": 4, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None}
]
r["switches"] = [{"id": "sky-echo-plate", "layer": 1, "x": 14, "y": 1}]
r["doors"] = [{"id": "sky-door", "layer": 2, "x": 14, "y": 12, "switchIds": ["sky-echo-plate"]}]
r["balance"] = {"intendedLesson": "Combine projector, echo timing, ice, and one-way gates.", "targetDifficulty": 9, "expectedSolveMinutes": 25, "commonMisunderstanding": "Players forget the bridge was forwarded."}
new_rooms.append(r)

# ROOM 28: rooftops-04 - 18x16, 4 layers
r = get_metadata(old_rooms[27])
r["layers"] = [
    {"id": "festival-line-top", "name": "Festival Roof", "tiles": ["##################","#...S..........#.#","#.########.###...#","#..............#.#","#.#..#.#.#.#.#.#.#","#.#.##.........#.#","#.>...........v..#","#.####.#.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "festival-line-mid1", "name": "Carrier Fold A", "tiles": ["##################","#...S..........#.#","#.#.######.###...#","#..............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#.<...........^..#","#.####.S.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "festival-line-mid2", "name": "Carrier Fold B", "tiles": ["##################","#.T..............#","#.########.###...#","#..............#.#","#.#..#.#.#.#.#.#.#","#.#.##.........#.#","#................#","#.####.S.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "festival-line-bottom", "name": "Delivery Lane", "tiles": ["##################","#.T..............#","#.########.###...#","#..............#.#","#.#..~.#.#.S.#.#.#","#.#.##.......#...#","#................#","#.####.#.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#...............G#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 14, "facing": "right"}
r["entities"] = [
    {"id": "festival-parcel", "type": "parcel", "layer": 0, "x": 4, "y": 14, "pushable": True, "solid": True},
    {"id": "festival-parcel-b", "type": "parcel", "layer": 0, "x": 8, "y": 8, "pushable": True, "solid": True},
    {"id": "festival-lantern", "type": "projector", "layer": 0, "x": 8, "y": 3, "pushable": True, "solid": True, "projectionTargets": [{"layer": 3, "dx": -3, "dy": 1}]},
    {"id": "festival-shadow", "type": "shadow", "layer": 1, "x": 16, "y": 14, "solid": True, "pushable": False, "mirrorAxis": "vertical"}
]
r["switches"] = [{"id": "festival-parcel-plate", "layer": 0, "x": 1, "y": 14}, {"id": "festival-parcel-plate-b", "layer": 0, "x": 8, "y": 12}, {"id": "festival-shadow-plate", "layer": 1, "x": 4, "y": 4, "sticky": True}]
r["doors"] = [
    {"id": "festival-door-a", "layer": 3, "x": 15, "y": 14, "switchIds": ["festival-parcel-plate", "festival-parcel-plate-b"]},
    {"id": "festival-door-b", "layer": 3, "x": 8, "y": 3, "switchIds": ["festival-shadow-plate"]}
]
r["teleporters"] = [
    {"id": "tp-festival-a1", "layer": 1, "x": 15, "y": 1, "pairId": "tp-festival-a2"},
    {"id": "tp-festival-a2", "layer": 2, "x": 2, "y": 1, "pairId": "tp-festival-a1"},
    {"id": "tp-festival-b1", "layer": 2, "x": 15, "y": 12, "pairId": "tp-festival-b2"},
    {"id": "tp-festival-b2", "layer": 3, "x": 2, "y": 1, "pairId": "tp-festival-b1"}
]
r["balance"] = {"intendedLesson": "The ultimate mixed-mechanic challenge across four layers.", "targetDifficulty": 9, "expectedSolveMinutes": 30, "commonMisunderstanding": "Players start climbing before the parcel is parked."}
new_rooms.append(r)

# ROOM 29: attic-01 - 18x14, 4 layers + keys/locks
r = get_metadata(old_rooms[28])
r["layers"] = [
    {"id": "rafters-front", "name": "Rafters Front", "tiles": ["##################","#...S..........#.#","#.######.###.#...#","#..............#.#","#.#..#.#.#II.#.#.#","#.#.##.......#...#","#.<..###.#.#.#.#.#","#..........#.#.#.#","#.####.#.#.#...#.#","#.#........#.#...#","#.#.####.#.......#","#.#........#.#...#","#.#.####.........#","##################"]},
    {"id": "rafters-mid1", "name": "Rafters Middle A", "tiles": ["##################","#...S..T.......#.#","#.#.####.###.#...#","#..............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#.>........#.#.#.#","#.####.S.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.........#","##################"]},
    {"id": "rafters-mid2", "name": "Rafters Middle B", "tiles": ["##################","#................#","#.######.###.#...#","#..............#.#","#.#..#.#.#.S.#.#.#","#.#.##.......#...#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.........#","##################"]},
    {"id": "rafters-back", "name": "Rafters Back", "tiles": ["##################","#.T..............#","#.######.###.#...#","#..............#.#","#.#..#.#.#.S.#.#.#","#.#.##.......#...#","#..........#.#.#.#","#.####.#.#.#.#.#.#","#..........#...#.#","#.####.###.#.#...#","#..............#.#","#.#.####.#.......#","#.#.####.......G.#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 12, "facing": "right"}
r["entities"] = [
    {"id": "shadow-b", "type": "shadow", "layer": 1, "x": 16, "y": 12, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "key-red-attic", "type": "key", "layer": 2, "x": 10, "y": 3, "color": "red", "solid": False, "pushable": False}
]
r["switches"] = [{"id": "attic-latch", "layer": 1, "x": 5, "y": 3, "sticky": True}]
r["doors"] = [{"id": "attic-door", "layer": 3, "x": 14, "y": 12, "switchIds": ["attic-latch"]}]
r["teleporters"] = [
    {"id": "tp-attic-a1", "layer": 0, "x": 15, "y": 1, "pairId": "tp-attic-a2"},
    {"id": "tp-attic-a2", "layer": 1, "x": 7, "y": 1, "pairId": "tp-attic-a1"},
    {"id": "tp-attic-b1", "layer": 1, "x": 4, "y": 9, "pairId": "tp-attic-b2"},
    {"id": "tp-attic-b2", "layer": 3, "x": 2, "y": 1, "pairId": "tp-attic-b1"}
]
r["locks"] = [{"id": "lock-red-attic", "layer": 3, "x": 10, "y": 8, "color": "red"}]
r["balance"] = {"intendedLesson": "Shadow latching with ice, one-way gates, teleporters, and key/lock across four layers.", "targetDifficulty": 9, "expectedSolveMinutes": 25, "commonMisunderstanding": "Players assume the shadow must keep standing on the switch."}
new_rooms.append(r)

# ROOM 30: attic-02 - 18x16, 4 layers + gravity/conveyors/keys
r = get_metadata(old_rooms[29])
r["layers"] = [
    {"id": "attic-ledger-top", "name": "Ledger Top", "tiles": ["##################","#...S..........#.#","#.########.###...#","#..............#.#","#.#..#.#.#.#.#.#.#","#.#.##.........#.#","#.>...........v..#","#.####.#.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "attic-ledger-mid1", "name": "Ledger Fold A", "tiles": ["##################","#...S..T.......#.#","#.#.######.###...#","#..............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#.<...........^..#","#.####.S.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "attic-ledger-mid2", "name": "Ledger Fold B", "tiles": ["##################","#.T..............#","#.########.###...#","#.......RRRR..#.#","#.#..#.#.#.#.#.#.#","#.#.##.........#.#","#................#","#.####.S.#.#.#.#.#","#..........F...#.#","#.########.F##...#","#..........F...#.#","#.####.###.#.#...#","#..............#.#","#.########.###...#","#................#","##################"]},
    {"id": "attic-ledger-bottom", "name": "Ledger Back", "tiles": ["##################","#.T..............#","#.########.###...#","#..............#.#","#.#..#.#.#.#.#.#.#","#.#.##.S.......#.#","#................#","#.####.#.#.#.#.#.#","#..............#.#","#.########.###...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.########.###..G#","#................#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 14, "facing": "right"}
r["entities"] = [
    {"id": "shadow-ledger", "type": "shadow", "layer": 1, "x": 16, "y": 14, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "echo-ledger", "type": "echo", "layer": 1, "x": 1, "y": 4, "solid": True, "pushable": False, "echoDelay": 1, "queuedAction": None},
    {"id": "parcel-ledger-a", "type": "parcel", "layer": 0, "x": 6, "y": 12, "pushable": True, "solid": True},
    {"id": "parcel-ledger-b", "type": "parcel", "layer": 0, "x": 10, "y": 4, "pushable": True, "solid": True},
    {"id": "key-blue-ledger", "type": "key", "layer": 2, "x": 14, "y": 3, "color": "blue", "solid": False, "pushable": False}
]
r["switches"] = [
    {"id": "attic-ledger-shadow-latch", "layer": 1, "x": 6, "y": 4, "sticky": True},
    {"id": "attic-ledger-echo-switch", "layer": 1, "x": 14, "y": 1},
    {"id": "attic-ledger-parcel-plate", "layer": 3, "x": 6, "y": 12},
    {"id": "attic-ledger-visible-plate", "layer": 0, "x": 15, "y": 12}
]
r["doors"] = [
    {"id": "attic-ledger-door-a", "layer": 0, "x": 7, "y": 1, "switchIds": ["attic-ledger-shadow-latch"]},
    {"id": "attic-ledger-door-b", "layer": 1, "x": 14, "y": 4, "switchIds": ["attic-ledger-echo-switch"]},
    {"id": "attic-ledger-door-c", "layer": 3, "x": 15, "y": 13, "switchIds": ["attic-ledger-parcel-plate", "attic-ledger-visible-plate"]}
]
r["teleporters"] = [
    {"id": "tp-ledger-a1", "layer": 1, "x": 7, "y": 1, "pairId": "tp-ledger-a2"},
    {"id": "tp-ledger-a2", "layer": 1, "x": 14, "y": 8, "pairId": "tp-ledger-a1"},
    {"id": "tp-ledger-b1", "layer": 1, "x": 4, "y": 12, "pairId": "tp-ledger-b2"},
    {"id": "tp-ledger-b2", "layer": 2, "x": 2, "y": 1, "pairId": "tp-ledger-b1"},
    {"id": "tp-ledger-c1", "layer": 2, "x": 14, "y": 12, "pairId": "tp-ledger-c2"},
    {"id": "tp-ledger-c2", "layer": 3, "x": 2, "y": 1, "pairId": "tp-ledger-c1"}
]
r["locks"] = [{"id": "lock-blue-ledger", "layer": 3, "x": 12, "y": 10, "color": "blue"}]
r["balance"] = {"intendedLesson": "Full-mechanic challenge with gravity, conveyors, and key/lock across four layers.", "targetDifficulty": 9, "expectedSolveMinutes": 30, "commonMisunderstanding": "Players set the shadow correctly but keep searching the wrong sheet."}
new_rooms.append(r)

# ROOM 31: attic-03 "Mina's Postscript" - 18x16, 4 layers, everything
r = get_metadata(old_rooms[30])
r["layers"] = [
    {"id": "postscript-top", "name": "Postscript Front", "tiles": ["##################","#...S..........#.#","#.##########.#...#","#.>............#.#","#.#..#.#.#.#II.#.#","#.#.##.........#.#","#.v..............#","#.####.#.#.#.#.#.#","#..............#.#","#.##########.#...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.##########.#...#","#................#","##################"]},
    {"id": "postscript-mid1", "name": "Postscript Fold A", "tiles": ["##################","#...S..T.......#.#","#.#.########.#...#","#.<............#.#","#......#.#.#.#.#.#","#.###.##.......#.#","#.^..............#","#.####.S.#.#.#.#.#","#..............#.#","#.##########.#...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.##########.#...#","#................#","##################"]},
    {"id": "postscript-mid2", "name": "Postscript Fold B", "tiles": ["##################","#.T..............#","#.##########.#...#","#...DDDDDD.....#.#","#.#..#.#.#.#.#.#.#","#.#.##.........#.#","#...UUUUUU.......#","#.####.S.#.#.#.#.#","#..............#.#","#.##########.#...#","#..........F...#.#","#.####.###.F.#...#","#..........F...#.#","#.##########.#...#","#................#","##################"]},
    {"id": "postscript-back", "name": "Postscript Route", "tiles": ["##################","#.T..............#","#.##########.#...#","#..............#.#","#.#..~.#.#.S.#.#.#","#.#.##.......#...#","#................#","#.####.#.#.#.#.#.#","#..............#.#","#.##########.#...#","#..............#.#","#.####.###.#.#...#","#..............#.#","#.##########.#...#","#...............G#","##################"]}
]
r["start"] = {"layer": 0, "x": 1, "y": 14, "facing": "right"}
r["entities"] = [
    {"id": "shadow-postscript", "type": "shadow", "layer": 1, "x": 16, "y": 14, "solid": True, "pushable": False, "mirrorAxis": "vertical"},
    {"id": "lantern-postscript", "type": "projector", "layer": 0, "x": 8, "y": 4, "pushable": True, "solid": True, "projectionTargets": [{"layer": 3, "dx": -3, "dy": 0}]},
    {"id": "key-yellow-post", "type": "key", "layer": 2, "x": 14, "y": 6, "color": "yellow", "solid": False, "pushable": False},
    {"id": "key-green-post", "type": "key", "layer": 3, "x": 6, "y": 8, "color": "green", "solid": False, "pushable": False}
]
r["switches"] = [{"id": "postscript-latch", "layer": 1, "x": 6, "y": 4, "sticky": True}]
r["doors"] = [{"id": "postscript-door", "layer": 3, "x": 15, "y": 14, "switchIds": ["postscript-latch"]}]
r["teleporters"] = [
    {"id": "tp-post-a1", "layer": 1, "x": 7, "y": 1, "pairId": "tp-post-a2"},
    {"id": "tp-post-a2", "layer": 1, "x": 14, "y": 8, "pairId": "tp-post-a1"},
    {"id": "tp-post-b1", "layer": 1, "x": 4, "y": 12, "pairId": "tp-post-b2"},
    {"id": "tp-post-b2", "layer": 2, "x": 2, "y": 1, "pairId": "tp-post-b1"},
    {"id": "tp-post-c1", "layer": 2, "x": 15, "y": 12, "pairId": "tp-post-c2"},
    {"id": "tp-post-c2", "layer": 3, "x": 2, "y": 1, "pairId": "tp-post-c1"}
]
r["locks"] = [
    {"id": "lock-yellow-post", "layer": 3, "x": 10, "y": 10, "color": "yellow"},
    {"id": "lock-green-post", "layer": 3, "x": 12, "y": 12, "color": "green"}
]
r["balance"] = {"intendedLesson": "The ultimate finale combining every mechanic across four layers.", "targetDifficulty": 10, "expectedSolveMinutes": 35, "commonMisunderstanding": "Players forget the lantern bridge is being rerouted."}
new_rooms.append(r)

# Auto-fix row widths: normalize all rows to match top border width
for r in new_rooms:
    layers = r.get("layers", [])
    if not layers:
        continue
    # Target width = length of first row of first layer (the top border)
    target_w = len(layers[0]["tiles"][0])
    for layer in layers:
        fixed_tiles = []
        for ri, row in enumerate(layer["tiles"]):
            if len(row) < target_w:
                # Pad: insert '.' before the last '#' to extend interior
                if ri == 0 or ri == len(layer["tiles"]) - 1:
                    # Border row: pad with '#'
                    row = row + '#' * (target_w - len(row))
                else:
                    # Interior row: insert '.' before trailing '#'
                    deficit = target_w - len(row)
                    row = row[:-1] + '.' * deficit + row[-1]
            elif len(row) > target_w:
                # Trim: remove extra '.' from interior
                if ri == 0 or ri == len(layer["tiles"]) - 1:
                    row = '#' * target_w
                else:
                    excess = len(row) - target_w
                    # Remove dots near the middle
                    mid = len(row) // 2
                    row = row[:mid] + row[mid+excess:]
            fixed_tiles.append(row)
        layer["tiles"] = fixed_tiles

# Auto-fix stitch alignment: ensure every S appears on at least 2 layers at same (x,y)
for r in new_rooms:
    layers = r.get("layers", [])
    if len(layers) < 2:
        continue
    # Collect all stitch positions per layer
    stitch_map = {}  # (x,y) -> set of layer indices
    for li, layer in enumerate(layers):
        for y, row in enumerate(layer["tiles"]):
            for x, ch in enumerate(row):
                if ch == 'S':
                    key = (x, y)
                    if key not in stitch_map:
                        stitch_map[key] = set()
                    stitch_map[key].add(li)
    # For stitches only on one layer, add S on the adjacent layer
    for (x, y), layer_set in stitch_map.items():
        if len(layer_set) < 2:
            li = list(layer_set)[0]
            # Pick adjacent layer
            target = li + 1 if li + 1 < len(layers) else li - 1
            row = list(layers[target]["tiles"][y])
            if 0 <= x < len(row) and row[x] in ('.', '#'):
                # Only convert interior walls, never perimeter
                if x > 0 and x < len(row) - 1 and y > 0 and y < len(layers[target]["tiles"]) - 1:
                    row[x] = 'S'
                    layers[target]["tiles"][y] = ''.join(row)

# Replace rooms
data["rooms"] = new_rooms

# Validate
errors = 0
print(f"Generated {len(new_rooms)} rooms")
for r in new_rooms:
    layers = r.get("layers", [])
    if not layers:
        continue
    widths = set()
    heights = set()
    for l in layers:
        heights.add(len(l["tiles"]))
        for row in l["tiles"]:
            widths.add(len(row))
    if len(heights) > 1 or len(widths) > 1:
        print(f"  ERROR: {r['id']} has inconsistent sizes: widths={widths} heights={heights}")
        errors += 1
    h = list(heights)[0]
    w = list(widths)[0] if len(widths) == 1 else max(widths)
    print(f"  {r['id']:30s} layers={len(layers)} size={w}x{h} entities={len(r.get('entities',[]))} switches={len(r.get('switches',[]))} doors={len(r.get('doors',[]))} tp={len(r.get('teleporters',[]))}")

    # Check stitches align
    stitch_map = {}
    for li, layer in enumerate(layers):
        for y, row in enumerate(layer["tiles"]):
            for x, ch in enumerate(row):
                if ch == 'S':
                    key = (x, y)
                    if key not in stitch_map:
                        stitch_map[key] = set()
                    stitch_map[key].add(li)
    for pos, layer_set in stitch_map.items():
        if len(layer_set) < 2:
            print(f"    WARNING: Stitch at {pos} only in layer(s) {layer_set} for room {r['id']}")

    # Check goal exists
    has_goal = any('G' in row for layer in layers for row in layer["tiles"])
    if not has_goal:
        print(f"    WARNING: No goal in room {r['id']}")

    # Check perimeter walls
    for li, layer in enumerate(layers):
        tiles = layer["tiles"]
        if not all(c == '#' for c in tiles[0]):
            print(f"    WARNING: Top wall broken in layer {li} of {r['id']}")
        if not all(c == '#' for c in tiles[-1]):
            print(f"    WARNING: Bottom wall broken in layer {li} of {r['id']}")

if errors == 0:
    with open("C:/Users/cchoa/Codex_Sandbox/apps/puzzle-game/data/source/campaign.json", "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("\nDone! campaign.json updated.")
else:
    print(f"\n{errors} errors found. Not writing.")
