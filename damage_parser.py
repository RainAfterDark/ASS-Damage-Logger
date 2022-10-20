import sys
import re

# only works with one team at a time, log files with multiple teams and rotations will be combined together
# also accounts all damage occurences in the log (including damage done to avatars), so please filter beforehand
log_file = open(sys.argv[1]) # open("path_to_file")

col = {}
labels = ("type", "uid", "time", "delta", "source", "attacker", "damage", "crit", "eda",
          "element", "reaction", "amp_type", "amp_rate", "count", "aid", "mid", "defender")
for i in range(len(labels)):
    col[labels[i]] = i

occurence_table = {}
reaction_table = {}

#region Reaction Correction
for line in log_file:
    line = line.strip("\n")
    row = re.split(",", line)
    if row[col["type"]] == "DAMAGE":
        damage = float(row[col["damage"]])
        if damage == 0: continue
        reaction = row[col["reaction"]]
        if reaction != "None":
            attacker = row[col["attacker"]]
            occurence_table.setdefault(reaction, {}).setdefault(damage, {}).setdefault(attacker, 0)
            occurence_table[reaction][damage][attacker] += 1

print("Reaction Occurences:")
for reaction, damage_table in occurence_table.items():
    reaction_table.setdefault(reaction, {})
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
    row = re.split(",", line)
    type = row[col["type"]]
    
    if type == "DAMAGE":
        damage = float(row[col["damage"]])
        if damage == 0: continue

        attacker = row[col["attacker"]]
        damage_table.setdefault(attacker, {
            "Total": 0,
            "Crit": {"true": 0, "false": 0}
        })
        
        damage_table[attacker]["Total"] += damage
        total_damage += damage
        total_time += int(row[col["delta"]])

        reaction = row[col["reaction"]]
        if reaction != "None":
            corrected = reaction_table[reaction][damage]
            if attacker != corrected:
                uid = row[col["uid"]]
                print(f"Resolved: {uid}, {attacker} -> {corrected}")
                attacker = corrected
            damage_table[attacker].setdefault(reaction, 0)
            damage_table[attacker][reaction] += damage

            ownership_table.setdefault(reaction, {}).setdefault(attacker, 0)
            ownership_table[reaction][attacker] += 1
        
        else:
            damage_table[attacker]["Crit"][row[col["crit"]]] += 1

            source = row[col["source"]]
            damage_table[attacker].setdefault(source, 0)
            damage_table[attacker][source] += damage

            amp_type = row[col["amp_type"]]
            if amp_type == "None": continue
            damage_table[attacker].setdefault(amp_type, 0)
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
        if stat == "Crit":
            hits = val["true"]
            total_hits = hits + val["false"]
            rate = val["true"] / total_hits * 100 if total_hits > 0 else 0
            print(f"\t{stat} Rate: {hits}/{total_hits} ({round(rate, 2)}%)")
            continue
        print(f"\t{stat}: {round(val):,} ({round(val / damage * 100, 2)}%)")

print("\nReaction Ownership:")
for reaction, owners in ownership_table.items():
    print(f"{reaction}:")
    for avatar, count in owners.items():
        print(f"\t{avatar}: {count}")
            
log_file.close()