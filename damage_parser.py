#!/usr/bin/env python3
# -------------------------------------------------------------------------------------- #
# Simple damage parser py script by Ame                                                  #
# Usage: Provide a log file path or directly paste logs into the console input.          #
# Optional flags: -rc Y/N                                                                #
#                 sets global setting for using reaction correction (stops prompts)      #
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

import argparse, re, traceback, logging
from collections import defaultdict
from enum import IntEnum

class col(IntEnum):
    type, uid, time, delta, source, attacker, damage, crit, eda, \
    element, reaction, amp_type, amp_rate, count, aid, mid, defender \
    = range(17)

# we ignore blooms as they're already directly associated to the source
reaction_blacklist = ("None", "Bloom", "BountifulBloom", "Hyperbloom")

def str2bool(str):
    return str.lower() in ("true", "t", "yes", "y", "1")

def dict2str(d):
    return ", ".join((f"{k}: {d[k]}" for k in sorted(d, key=d.get, reverse=True)))

def try_open(path):
    lines, err = [], None
    try:
        with open(path, "r") as file:
            lines = file.read().splitlines()
    except Exception as e: err = e
    fname = re.split(r"\/|\\", path)[-1] if path else None
    return fname, lines, err

def nested_dd(depth, default_factory):
    return defaultdict(default_factory if depth < 1
    else lambda: nested_dd(depth - 1, default_factory))

def damage_check(row):
    return (row[col.type] == "DAMAGE" and float(row[col.damage]) > 0
    # this naming convention should be exclusive to monsters
    and re.search(r"[A-Z]+\d+", row[col.defender].split(" ")[0]))

def parse_log(lines, use_correction):
    frequency_table = nested_dd(2, int) # reaction → damage → attacker → frequency
    for line in lines:
        row = line.split(",")
        if not damage_check(row): continue

        reaction = row[col.reaction]
        if reaction in reaction_blacklist: continue

        damage = float(row[col.damage])
        attacker = row[col.attacker]
        frequency_table[reaction][damage][attacker] += 1

    if frequency_table:
        print("\nReaction Frequency:")
        print("\n".join(f"{reaction} {damage} = {dict2str(frequency)}"
        for reaction, damage_table in frequency_table.items()
        for damage, frequency in damage_table.items()))

    total_damage, total_time = 0, -1
    damage_table = nested_dd(2, int) # attacker → stat → defaultdict(int)
    ownership_table = nested_dd(1, int) # reaction → avatar → owned_count (int)
    corrected = False

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

        def add2dt(stat):
            damage_table[attacker][stat]["dmg"] += damage
            damage_table[attacker][stat]["count"] += 1

        reaction = row[col.reaction]
        if reaction != "None":
            if use_correction and reaction not in reaction_blacklist:
                rdmg = frequency_table[reaction][damage]
                corrected = max(rdmg, key = rdmg.get)

                if attacker != corrected:
                    print(f"[UID {row[col.uid]}] Corrected {reaction} source: {attacker} → {corrected}")
                    attacker = corrected
                    corrected = True
            
            ownership_table[reaction][attacker] += 1
            add2dt(reaction)
        
        else:
            damage_table[attacker]["Crit"][row[col.crit]] += 1
            if row[col.amp_type] != "None": add2dt(row[col.amp_type])
            add2dt(row[col.source])

    if ownership_table:
        corrected_str = " (Corrected)" if corrected else ""
        print(f"\nReaction Ownership:{corrected_str}") # redundant but this is just for better visibility
        print("\n".join(f"{reaction} = {dict2str(owners)}" for reaction, owners in ownership_table.items()))

    time = total_time / 1000
    dps = total_damage / time if time > 0 else 0
    print(f"\nTotal Damage: {round(total_damage):,}, Time: {time}s, DPS: {round(dps):,}")

    for avatar, stats in damage_table.items():
        avatar_dmg = stats["Total"]["dmg"] 
        print(f"\n{avatar}: {round(avatar_dmg):,} ({round(avatar_dmg / total_damage * 100, 2)}%)")
        
        for stat, val in stats.items():   
            match stat:
                case "Total": continue
                case "Crit":
                    hits = val["true"]
                    total = hits + val["false"]
                    rate = hits / total * 100 if total > 0 else 0
                    print(f"{stat} Rate: {hits}/{total} ({round(rate, 2)}%)")
                    continue        
                case _:
                    dmg, count = val["dmg"], val["count"]
                    dmg_ratio = dmg / avatar_dmg * 100
                    print(f"{count} {stat}: {round(dmg):,} ({round(dmg_ratio, 2)}%)")

def main():
    global rot_n
    first_line = input("\nEnter log file path or paste logs directly:\n")
    fname, lines, err = try_open(first_line)

    if not lines: # try to determine if input was a path or a pasted log
        # there should be a better way to do this but logs should never contain slashes anyway
        if re.search(r"\/|\\", first_line):
            print(err) # print error if input was path
            return # start over
            
        fname = "pasted log"
        lines.append(first_line) # (assumed pasted log at this point) append first line of paste
        while True: # handle pasted newlines, break loop and start processing after empty input
            line = input()
            if not line: break
            lines.append(line.strip())

    # group lines into smaller lists if multiple teams are present to handle multi-rotation logs
    team_idxs = [i for i, v in enumerate(lines) if v.startswith("TEAM")]
    idxa, idxb = [0] + team_idxs, team_idxs + [len(lines)]
    rotations = [lines[a:b] for a, b in zip(idxa, idxb) if b - a > 1]

    for i, rot in enumerate(rotations):
        team = (rot[0][5:].replace(",", ", ")
                if rot[0].startswith("TEAM")
                else "(no team header)")
        print("\n" + "-" * 69 + f"\nRotation {i + rot_n}: {team}")
        ask_rc_str = "Use reaction correction? (Y/N, default N): "
        try: parse_log(rot, str2bool(args.rc or input(ask_rc_str)))
        except Exception: logging.error(traceback.format_exc())
    
    if rotations:
        rot_n += len(rotations)
        print(f"\nFinished parsing {fname}.")
    else:
        print("Insufficient input.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    rc_desc = "sets global setting for using reaction correction (stops prompts)"
    parser.add_argument("-rc", metavar="Y/N", help=rc_desc)
    rot_n, args = 0, parser.parse_args()
    while True: main()