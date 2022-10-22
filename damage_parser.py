# -------------------------------------------------------------------------------------- #
# Simple damage parser py script by Ame                                                  #
#                                                                                        #
# Usage: Provide a log file path either in the script args or in the console input.      #
#        Alternatively, you can just directly paste logs into the console.               #
#                                                                                        #
# Script args: <log file path> <use reaction correction>                                 #
#               str, required   Y/N, default N                                           #
# -------------------------------------------------------------------------------------- #
#   Basically just outputs a damage breakdown and reaction counts for a specified log.   #
# Reaction correction has varying levels of accuracy, as it really only does frequency   #
# counting and using those numbers to associate damage values to the "correct" char. It  #
# should NOT be used if chars have similar EM / levels, as that would just make the the  #
# algorithm very confused and will produce totally wrong reaction ownerships and counts. #
# Overall this was moreso made for live server logs, to get a good idea of how damage    #
# might be spread out in a team. But I guess this can be pretty useful for PS logs too.  #
#                                                                                        #
# P.S: Amp reactions in the breakdown only indicate the amount of damage the respective  #
# character amplified, and thus doesn't count towards their total damage number.         #
# -------------------------------------------------------------------------------------- #

import sys, re, traceback, logging
from collections import defaultdict

class col:
    type, uid, time, delta, source, attacker, damage, crit, eda, \
    element, reaction, amp_type, amp_rate, count, aid, mid, defender = range(17)

# we ignore blooms as they're already directly associated to the source
reaction_blacklist = ("None", "Bloom", "BountifulBloom", "Hyperbloom")

args = sys.argv[1:]

def arg(i, default = None):
    return args[i] if len(args) > i else default

def str2bool(str):
    return str.lower() in ("true", "t", "yes", "y", "1")

def try_open(path):
    try:
        with open(path) as file:
            lines = [line.strip() for line in file]
            return lines, None
    except Exception as e:
        return [], e

def nested_dd(depth, default_factory):
    return defaultdict(default_factory if depth < 1
    else lambda: nested_dd(depth - 1, default_factory))

def damage_check(row):
    return (row[col.type] == "DAMAGE" and float(row[col.damage]) > 0
    # this naming convention should be exclusive to monsters
    and re.search(r"[A-Z]+\d+", row[col.defender].split(" ")[0]))

def parse_log(lines, use_correction):
    occurence_table = nested_dd(2, int) # reaction (str): damage (float): attacker (str): frequency (int)

    if use_correction:
        for line in lines:
            row = line.split(",")
            if not damage_check(row): continue

            reaction = row[col.reaction]
            if reaction in reaction_blacklist: continue

            damage = float(row[col.damage])
            attacker = row[col.attacker]
            occurence_table[reaction][damage][attacker] += 1

        print("\n\tReaction Occurences:")
        for reaction, damage_table in occurence_table.items():
            for damage, occurences in damage_table.items():
                print(f"\t{reaction}: {damage} -> {dict(occurences)}")

    total_damage, total_time = 0, -1
    damage_table = nested_dd(2, int) # attacker (str): stat (str): defaultdict(int)
    ownership_table = nested_dd(1, int) # reaction (str): avatar (str): count (int)

    for line in lines:
        row = line.split(",")
        if row[col.type] == "TEAM": continue
        # this makes it so we ignore the very first delta value so as to not offset total_time
        total_time += int(row[col.delta]) if total_time > -1 else 1
        if not damage_check(row): continue

        attacker = row[col.attacker]
        damage = float(row[col.damage])
        damage_table[attacker]["Total"]["dmg"] += damage
        total_damage += damage

        reaction = row[col.reaction]
        if reaction != "None":
            if use_correction and reaction not in reaction_blacklist:
                rdmg = occurence_table[reaction][damage]
                corrected = max(rdmg, key=rdmg.get)

                if attacker != corrected:
                    uid = row[col.uid]
                    print(f"\t[UID {uid}] Corrected {reaction} source: {attacker} -> {corrected}")
                    attacker = corrected
            
            damage_table[attacker][reaction]["dmg"] += damage
            ownership_table[reaction][attacker] += 1
        
        else:
            damage_table[attacker]["Crit"][row[col.crit]] += 1
            source = row[col.source]
            damage_table[attacker][source]["dmg"] += damage

            amp_type = row[col.amp_type]
            if amp_type == "None": continue
            damage_table[attacker][amp_type]["dmg"] += damage

    time = total_time / 1000
    dps = total_damage / time if time > 0 else 0
    print(f"\n\tTotal Damage: {round(total_damage):,}, Time: {time}s, DPS: {round(dps):,}")

    for avatar, stats in damage_table.items():
        avatar_dmg = stats["Total"]["dmg"] 
        print(f"\t{avatar}: {round(avatar_dmg):,} ({round(avatar_dmg / total_damage * 100, 2)}%)")
        
        for stat, val in stats.items():   
            match stat:
                case "Total": continue
                case "Crit":
                    hits = val["true"]
                    total = hits + val["false"]
                    rate = hits / total * 100 if total > 0 else 0
                    print(f"\t\t{stat} Rate: {hits}/{total} ({round(rate, 2)}%)")
                    continue        
                case _:
                    dmg = val["dmg"]
                    print(f"\t\t{stat}: {round(dmg):,} ({round(dmg / avatar_dmg * 100, 2)}%)")

    print("\n\tReaction Ownership:")
    for reaction, owners in ownership_table.items():
        print(f"\t{reaction}:")
        for avatar, count in owners.items():
            print(f"\t\t{avatar}: {count}")

def main():
    lines, e = try_open(arg(0)) # try to open log from provided arg

    if not lines: # try to open log from input if no/invalid first arg
        if arg(0): print(e) # print error if arg was provided
        first_line = input("\nEnter log file path or paste logs directly:\n")
        lines, e = try_open(first_line)

        if not lines: # try to determine if input was a path or a pasted log
            # there should be a better way to do this but logs will never contain slashes anyway
            if re.search(r"\/|\\", first_line):
                print(e) # print error if input was path
                return # start over
                
            lines.append(first_line) # (assumed pasted log at this point) append first line of paste
            while True: # handle pasted newlines, break loop and start processing after empty input
                line = input()
                if not line: break
                lines.append(line.strip())

    use_correction = str2bool(arg(1) or input("\nUse reaction correction? (Y/N, default N): "))

    team_idxs = [i for i, v in enumerate(lines) if v.startswith("TEAM")]
    idxa, idxb = [0] + team_idxs, team_idxs + [len(lines)]
    rotations = [lines[a:b] for a, b in zip(idxa, idxb) if b - a > 1]

    for i, rot in enumerate(rotations):
        team = (rot[0][5:].replace(",", ", ")
                if rot[0].startswith("TEAM")
                else "(no team header)")
        print(f"\nRotation {i}: {team}")
        try: parse_log(rot, use_correction)
        except Exception: logging.error(traceback.format_exc())

while __name__ == "__main__": main(); args.clear()