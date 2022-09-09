from pathlib import Path
import json
import re
import numpy

path = Path(__file__).parent

hashes = {}

def ability_hash (st):
    v7 = 0
    v8 = 0
    while (v8 < len(st)):
        v7 = numpy.uint32(ord(st[v8]) + 131 * v7)
        v8 += 1
    return v7

def add_hash(name):
    hash = ability_hash(name)
    if hash in hashes and name != hashes[hash]:
        print(f"dupe conflict! {hash[name]} against {name}") # never occurs thankfully
    hashes[hash] = name

# tbh a lot of these are redundant but i just want to hash as much as I can so we're covering everything

defaults = ["Default", "Avatar_DefaultAbility_VisionReplaceDieInvincible", "Avatar_DefaultAbility_AvartarInShaderChange", "Avatar_SprintBS_Invincible",
        "Avatar_Freeze_Duration_Reducer", "Avatar_Attack_ReviveEnergy", "Avatar_Component_Initializer", "Avatar_FallAnthem_Achievement_Listener"]

for i in defaults:
    add_hash(i)

resonances = ["TeamResonance_Fire_Lv2", "TeamResonance_Water_Lv2", "TeamResonance_Grass_Lv2", "TeamResonance_Electric_Lv2", "TeamResonance_Ice_Lv2",
        "TeamResonance_Wind_Lv2", "TeamResonance_Rock_Lv2", "TeamResonance_AllDifferent"]

for i in resonances:
    add_hash(i)

skips = 0

f_player = open(path / "AbilityGroup_Other_PlayerElementAbility.json")
player_data = json.load(f_player)
f_player.close()

for k in player_data:
    for a in player_data[k]["targetAbilities"]:
        if a["abilityID"] != a["abilityName"] and a["abilityID"]:
            add_hash(a["abilityID"])
        if a["abilityName"]:
            add_hash(a["abilityName"])

f_skill_excel = open(path / "AvatarSkillExcelConfigData.json")
skill_data = json.load(f_skill_excel)
f_skill_excel.close()

for i in skill_data:
    if not i["abilityName"]:
        continue
    add_hash(i["abilityName"])

avatar_list = Path(path / "Avatar").glob('*')
for i in avatar_list:
    f = open(i)
    name = re.search("ConfigAvatar_(.*).json", i.name).group(1)
    data = json.load(f)
    if "abilities" not in data or not data["abilities"]:
        print(f"skipped: {name}")
        skips += 1
        continue

    for a in data["abilities"]:
        if a["abilityID"] != a["abilityName"] and a["abilityID"]:
            add_hash(a["abilityID"])
        if a["abilityName"]:
            add_hash(a["abilityName"])

    f.close()

f_abilitypath = open(path / "AbilityPathData.json")
ability_data = json.load(f_abilitypath)
f_abilitypath.close()

for _, v in ability_data["abilityPaths"].items():
    for ability in v:
        add_hash(ability)

f_lua = open(path / "ability_hashes.lua", "w")
f_lua.write("local ability_hashes = {\n")

for k, v in sorted(hashes.items(), key=lambda x:x[1]):
    f_lua.write(f'\t[{k}] = "{v}",\n')

f_lua.write("}\nreturn ability_hashes")
f_lua.close()

print(f"skips: {skips}")