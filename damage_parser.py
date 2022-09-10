from pathlib import Path
from enum import Enum
import re

class col(Enum):
    type = 0; uid = 1; time = 2; delta = 3; source = 4; attacker = 5
    damage = 6; crit = 7; apply = 8; element = 9; reaction = 10; amp_type = 11
    amp_rate = 12; count = 13; aid = 14; mid = 15; defender = 16

path = Path(__file__).parent

# log must NOT use table format! this script is just a quick little parser anyways
# also only works with one team at a time, log files with multiple teams and rotations will be combined together
log_file = open(path / "../../latest.txt")

occurence_table = {}
reaction_table = {}

#region Reaction Correction
for line in log_file:
    line = line.strip("\n")
    row = re.split(":\s|,\s", line)
    if row[col.type.value] == "DAMAGE":
        reaction = row[col.reaction.value]
        if reaction != "None":
            attacker = row[col.attacker.value]
            damage = float(row[col.damage.value])
            if reaction not in occurence_table:
                occurence_table[reaction] = {}
            if damage not in occurence_table[reaction]:
                occurence_table[reaction][damage] = {}
            if attacker not in occurence_table[reaction][damage]:
                occurence_table[reaction][damage][attacker] = 0
            occurence_table[reaction][damage][attacker] += 1

print("Reaction Occurences:")
for reaction, damage_table in occurence_table.items():
    if reaction not in reaction_table:
        reaction_table[reaction] = {}
    for damage, occurences in damage_table.items():
        print(f"{reaction}: {damage} -> {occurences}")
        most_frequent = ""
        highest = 0
        for attacker, frequency in occurences.items():
            if frequency > highest:
                highest = frequency
                most_frequent = attacker
        reaction_table[reaction][damage] = most_frequent
#endregion

total_damage = 0
total_time = 0
damage_table = {}
ownership_table = {}

log_file.seek(0)
for line in log_file:
    line = line.strip("\n")
    row = re.split(":\s|,\s", line)
    type = row[col.type.value]
    
    if type == "TEAM UPDATE":
        for i in range(1, len(row)):
            damage_table[row[i]] = {
                "Total": 0,
                "Crit": {"true": 0, "false": 0},
                "Apply": {"true": 0, "false": 0}
            }
    
    elif type == "DAMAGE":
        attacker = row[col.attacker.value]
        damage = float(row[col.damage.value])
        damage_table[attacker]["Total"] += damage
        total_damage += damage
        total_time += int(row[col.delta.value])

        reaction = row[col.reaction.value]
        if reaction != "None":
            attacker = reaction_table[reaction][damage]
            if reaction not in damage_table[attacker]:
                damage_table[attacker][reaction] = 0
            damage_table[attacker][reaction] += damage

            if reaction not in ownership_table:
                ownership_table[reaction] = {}
            if attacker not in ownership_table[reaction]:
                ownership_table[reaction][attacker] = 0
            ownership_table[reaction][attacker] += 1
        
        else:
            damage_table[attacker]["Crit"][row[col.crit.value]] += 1
            damage_table[attacker]["Apply"][row[col.apply.value]] += 1

            source = row[col.source.value]
            if source not in damage_table[attacker]:
                damage_table[attacker][source] = 0
            damage_table[attacker][source] += damage

            amp_type = row[col.amp_type.value]
            if amp_type == "None": continue
            if amp_type not in damage_table[attacker]:
                damage_table[attacker][amp_type] = 0
            damage_table[attacker][amp_type] += damage

time = total_time / 1000
dps = total_damage / time
print(f"\nTotal Damage: {round(total_damage):,}, Time: {time}s, DPS: {round(dps):,}")

for avatar, stats in damage_table.items():
    damage = stats["Total"]
    damage_percent = (damage / total_damage) * 100
    print(f"{avatar}: {round(damage):,} ({round(damage_percent, 2)}%)")
    for stat, val in stats.items():
        if stat == "Total": continue
        if stat == "Crit" or stat == "Apply":
            rate = 0
            total_hits = val["true"] + val["false"]
            if total_hits > 0:
                rate = (val["true"] / total_hits) * 100
            print(f"\t{stat} Rate: {round(rate, 2)}%")
            continue
        print(f"\t{stat}: {round(val):,}")

print("\nReaction Ownership:")
for reaction, owners in ownership_table.items():
    print(f"{reaction}:")
    for avatar, count in owners.items():
        print(f"\t{avatar}: {count}")
            
log_file.close()