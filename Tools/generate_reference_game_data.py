#!/usr/bin/env python3
"""Builds ClashAttackLabMac/GameData/ReferenceGameData.json.

Source: the `clash-of-clans-data` npm package, a structured export of the
game's per-level statistics. Only the entities the simulator models are
kept, normalized into one flat schema expressed in game units (tiles,
seconds, in-game movement speed). The Swift loader converts those units
into simulator world units.

Usage:
    python3 Tools/generate_reference_game_data.py [path/to/package]

Without a path the script downloads the pinned package version with
`npm pack` into a temporary directory.
"""

import json
import os
import subprocess
import sys
import tarfile
import tempfile

PACKAGE = "clash-of-clans-data"
VERSION = "0.18.0"
OUTPUT = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "..",
    "ClashAttackLabMac",
    "GameData",
    "ReferenceGameData.json",
)

# Simulator entity key -> package file.
UNITS = {
    "giant": "troops/giant.json",
    "barbarian": "troops/barbarian.json",
    "archer": "troops/archer.json",
    "wallBreaker": "troops/wall-breaker.json",
    "wizard": "troops/wizard.json",
    "balloon": "troops/balloon.json",
    "dragon": "troops/dragon.json",
    "barbarianKing": "heroes/barbarian-king.json",
    "archerQueen": "heroes/archer-queen.json",
    "wallWrecker": "siege-machines/wall-wrecker.json",
    "stoneSlammer": "siege-machines/stone-slammer.json",
    "cannon": "defenses/cannon.json",
    "archerTower": "defenses/archer-tower.json",
    "mortar": "defenses/mortar.json",
    "wizardTower": "defenses/wizard-tower.json",
    "infernoTower": "defenses/inferno-tower.json",
    "bombTower": "defenses/bomb-tower.json",
    "hiddenTesla": "defenses/hidden-tesla.json",
    "giantBomb": "traps/giant-bomb.json",
    "airBomb": "traps/air-bomb.json",
    "airSweeper": "defenses/air-sweeper.json",
    "airDefense": "defenses/air-defense.json",
    "townHall": "town-hall/town-hall.json",
    "goldStorage": "resource-buildings/gold-storage.json",
    "wall": "walls/wall.json",
    "goldMine": "resource-buildings/gold-mine.json",
    "elixirCollector": "resource-buildings/elixir-collector.json",
    "darkElixirDrill": "resource-buildings/dark-elixir-drill.json",
    "elixirStorage": "resource-buildings/elixir-storage.json",
    "darkElixirStorage": "resource-buildings/dark-elixir-storage.json",
    "clanCastle": "resource-buildings/clan-castle.json",
    "armyCamp": "army-buildings/army-camp.json",
    "barracks": "army-buildings/barracks.json",
    "darkBarracks": "army-buildings/dark-barracks.json",
    "laboratory": "army-buildings/laboratory.json",
    "spellFactory": "army-buildings/spell-factory.json",
    "darkSpellFactory": "army-buildings/dark-spell-factory.json",
    "workshop": "army-buildings/workshop.json",
    "heroHall": "army-buildings/hero-hall.json",
    "petHouse": "army-buildings/pet-house.json",
    "blacksmith": "army-buildings/blacksmith.json",
    "builderHut": "defenses/builders-hut.json",
    "helperHut": "other/helper-hut.json",
    "xBow": "defenses/x-bow.json",
    "eagleArtillery": "defenses/eagle-artillery.json",
    "scattershot": "defenses/scattershot.json",
    "spellTower": "defenses/spell-tower.json",
    "monolith": "defenses/monolith.json",
    "bomb": "traps/bomb.json",
    "springTrap": "traps/spring-trap.json",
    "seekingAirMine": "traps/seeking-air-mine.json",
}

# Defenses with several firing modes use the named one instead of "normal".
# The X-Bow is modeled in its air-and-ground setting.
MODES = {
    "xBow": "airAndGround",
}

SPELLS = {
    "heal": "spells/healing-spell.json",
    "rage": "spells/rage-spell.json",
    "freeze": "spells/freeze-spell.json",
    "lightning": "spells/lightning-spell.json",
    "earthquake": "spells/earthquake-spell.json",
}


def load(root, relative):
    with open(os.path.join(root, "data", "home", relative)) as handle:
        return json.load(handle)


def regular_levels(data):
    """Drops supercharge entries, which restart their level numbering."""
    return [level for level in data["levels"] if not level.get("supercharge")]


def hero_hall_town_halls(root):
    hall = load(root, "army-buildings/hero-hall.json")
    return {
        level["level"]: level["townHallRequired"]
        for level in hall["levels"]
    }


def compact(values):
    return {key: value for key, value in values.items() if value is not None}


MAX_TOWN_HALL = 18


def footprint(size):
    """'3x3' -> 3 tiles per side."""
    if not size:
        return None
    return int(size.split("x")[0])


def counts_by_town_hall(data):
    """Buildings allowed at Town Hall 1...MAX_TOWN_HALL, index = TH - 1."""
    available = data.get("availablePerTownHall")
    if not available:
        return None
    counts = {entry["townHallLevel"]: entry["count"] for entry in available}
    return [counts.get(level, 0) for level in range(1, MAX_TOWN_HALL + 1)]


def highest_level_value(levels, town_hall, key):
    unlocked = [
        level[key] for level in levels
        if level.get("townHallRequired", 1) <= town_hall and key in level
    ]
    return max(unlocked) if unlocked else 0


def army_capacity(root):
    """Troop and spell housing available at each Town Hall."""
    camp = load(root, "army-buildings/army-camp.json")
    spell_factory = load(root, "army-buildings/spell-factory.json")
    dark_factory = load(root, "army-buildings/dark-spell-factory.json")
    camp_counts = counts_by_town_hall(camp)
    troops, spells = [], []
    for town_hall in range(1, MAX_TOWN_HALL + 1):
        troops.append(
            camp_counts[town_hall - 1] *
            highest_level_value(camp["levels"], town_hall, "housingSpace")
        )
        spells.append(
            highest_level_value(
                spell_factory["levels"], town_hall, "spellStorageCapacity"
            ) +
            highest_level_value(
                dark_factory["levels"], town_hall, "spellStorageCapacity"
            )
        )
    return {"troopCapacity": troops, "spellCapacity": spells}


def unit_entry(key, data, hero_halls):
    normal_mode = data.get("modes", {}).get(MODES.get(key, "normal"), {})
    entry = compact({
        "name": data["name"],
        "range": data.get("range", normal_mode.get("range")),
        "attackInterval": data.get(
            "attackSpeed", normal_mode.get("attackSpeed")
        ),
        "movementSpeed": data.get("movementSpeed"),
        "splashRadius": normal_mode.get("splashRadius"),
        "triggerRadius": data.get(
            "triggerRadius", normal_mode.get("triggerRange")
        ),
        "damageRadius": data.get("damageRadius"),
        "minimumRange": normal_mode.get("minRange"),
        "shotsPerBurst": normal_mode.get("shotsPerBurst"),
        "timeBetweenBursts": normal_mode.get("timeBetweenBursts"),
        "activationHousingSpace": normal_mode.get("activationHousingSpace"),
        "size": footprint(data.get("size")),
        "housingSpace": data.get("housingSpace"),
        "countByTownHall": counts_by_town_hall(data),
    })

    levels = []
    for level in regular_levels(data):
        stats = level.get("stats", {}).get("normal", {})
        if "heroHallLevelRequired" in level:
            town_hall = hero_halls[level["heroHallLevelRequired"]]
        elif key == "townHall":
            town_hall = level["level"]
        else:
            town_hall = level.get("townHallRequired", 1)

        damage_per_hit = level.get(
            "damagePerHit",
            stats.get("damagePerShot", level.get("damage")),
        )
        wall_damage = level.get("damageVsWalls")
        death_damage = level.get("deathDamage", stats.get("deathDamage"))
        if key == "stoneSlammer":
            death_damage = level.get("damageWhenDestroyedHitbox2")

        ramp = None
        if "dpsInitial" in stats:
            interval = entry["attackInterval"]
            ramp = [
                round(stats["dpsInitial"] * interval, 4),
                round(stats["dpsAfter1p5s"] * interval, 4),
                round(stats["dps"] * interval, 4),
            ]

        levels.append(compact({
            "level": level["level"],
            "townHall": town_hall,
            "hitpoints": level.get("hitpoints"),
            "damagePerHit": damage_per_hit,
            "wallDamageMultiplier": (
                round(wall_damage / damage_per_hit, 4)
                if wall_damage and damage_per_hit else None
            ),
            "deathDamage": death_damage,
            "damageRadius": level.get("damageRadius"),
            "pushStrength": stats.get("pushStrength"),
            "abilityHealing": level.get("healthRecovery"),
            "bonusDamagePercent": stats.get("bonusDamagePercent"),
            "springCapacity": level.get("springCapacity"),
            "rampDamagePerHit": ramp,
        }))

    entry["levels"] = levels
    return entry


def spell_entry(key, data):
    levels = []
    for level in regular_levels(data):
        values = {
            "level": level["level"],
            "townHall": level.get("townHallRequired", 1),
            "radius": level.get("radius", data.get("radius")),
        }
        if key == "heal":
            interval = data["timeBetweenPulses"]
            values["duration"] = round(data["numberOfPulses"] * interval, 4)
            values["healingPerSecond"] = round(
                level["healingPerPulse"] / interval, 4
            )
        elif key == "rage":
            values["duration"] = round(
                data["numberOfPulses"] * data["timeBetweenPulses"], 4
            )
            values["damageIncreasePercent"] = level["damageIncrease"]
            values["speedIncrease"] = level["speedIncrease"]
        elif key == "freeze":
            values["duration"] = level["spellDuration"]
        elif key == "lightning":
            values["damage"] = level["damage"]
        elif key == "earthquake":
            values["buildingDamagePercent"] = level["buildingDamagePercent"]
        levels.append(compact(values))

    return {
        "name": data["name"],
        "housingSpace": data.get("housingSpace"),
        "levels": levels,
    }


def download_package(directory):
    subprocess.run(
        ["npm", "pack", f"{PACKAGE}@{VERSION}", "--silent"],
        cwd=directory,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    archive = os.path.join(directory, f"{PACKAGE}-{VERSION}.tgz")
    with tarfile.open(archive) as tar:
        tar.extractall(directory)
    return os.path.join(directory, "package")


def build(root):
    hero_halls = hero_hall_town_halls(root)
    return {
        "source": {
            "package": PACKAGE,
            "version": VERSION,
            "units": {
                "distance": "tiles",
                "time": "seconds",
                "movementSpeed": "in-game speed (8 = 1 tile per second)",
            },
        },
        "units": {
            key: unit_entry(key, load(root, path), hero_halls)
            for key, path in UNITS.items()
        },
        "spells": {
            key: spell_entry(key, load(root, path))
            for key, path in SPELLS.items()
        },
        "army": army_capacity(root),
    }


def main():
    if len(sys.argv) > 1:
        catalog = build(sys.argv[1])
    else:
        with tempfile.TemporaryDirectory() as directory:
            catalog = build(download_package(directory))

    with open(OUTPUT, "w") as handle:
        json.dump(catalog, handle, indent=1, sort_keys=True)
        handle.write("\n")
    print(f"Wrote {os.path.normpath(OUTPUT)}")


if __name__ == "__main__":
    main()
