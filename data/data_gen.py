from pathlib import Path
import json, numpy

data_path = Path(__file__).parent
resource_path = Path("") # provide resources directory path here
bin_path = resource_path / "BinOutput\\"
excel_path = resource_path / "ExcelBinOutput\\"
textmap_path = resource_path / "TextMap\\TextMapEN.json"

with open(textmap_path, encoding="utf-8") as f:
    textmap_data = json.load(f)

def gen_ability_hashes():
    print("Generating ability hashes...")
    hashes = {}

    def ability_hash(s):
        v7 = 0
        v8 = 0
        while (v8 < len(s)):
            v7 = numpy.uint32(ord(s[v8]) + 131 * v7)
            v8 += 1
        return v7

    def add_hash(name):
        if not name: return
        hash = ability_hash(name)
        if hash in hashes and name != hashes[hash]:
            input(f"dupe conflict! {hashes[hash]} against {name}")
        hashes[hash] = name

    def find_names(obj):
        if type(obj) == list:
            for i in obj: find_names(i)
        elif type(obj) == dict:
            for v in obj.values(): find_names(v)
            for f in ("abilityID", "abilityName", "modifierName", "effectName"):
                name = obj.get(f)
                if type(name) == str: add_hash(name)
                elif type(name) == list:
                    for n in name: add_hash(n)
            if "modifiers" in obj:
                for m in obj["modifiers"].keys(): add_hash(m)   
            if "abilities" in obj:
                for a in obj["abilities"]:
                    if type(a) == str: add_hash(a)

    def find_in_file(path):
        with open(path, encoding="utf-8") as f:
            find_names(json.load(f))

    def find_in_dir(path):
        flist = Path(path).rglob("*.json")
        for f in flist: find_in_file(f)

    find_in_file(excel_path / "AvatarSkillExcelConfigData.json")
    find_in_dir(bin_path / "Avatar")
    find_in_dir(bin_path / "AbilityGroup")
    find_in_dir(bin_path / "Ability\\Temp")
    find_in_dir(bin_path / "Gadget")
    add_hash("TeamResonance_Grass_Lv2")

    with open(data_path / "ability_hashes.lua", "w") as f:
        f.write("local ability_hashes = {\n")
        for k, v in sorted(hashes.items(), key=lambda x:x[1]):
            f.write(f'\t[{k}] = "{v}",\n')
        f.write("}\nreturn ability_hashes")

    print(f"Generated {len(hashes.keys())} ability hashes")

def gen_skill_names():
    print("Generating skill names...")
    skills, skips = {}, []

    with open(excel_path / "AvatarSkillExcelConfigData.json") as f:
        for skill in json.load(f):
            id = skill.get("id")
            hash = str(skill.get("nameTextMapHash"))
            textmap_name = textmap_data.get(hash)
            ability_name = skill.get("abilityName")
            skill_icon = skill.get("skillIcon")
            final_name = textmap_name or ability_name or skill_icon
            if final_name: skills[id] = final_name
            else: skips.append(id)

    with open(data_path / "skill_names.lua", "w", encoding="utf-8") as f:
        f.write("local skill_names = {\n")
        for id, name in skills.items():
            f.write(f'\t[{id}] = "{name}",\n')
        f.write("}\nreturn skill_names")

    print(f"Generated {len(skills)} skill names (skipped {len(skips)})")

def gen_gadget_names():
    print("Generating gadget names...")
    gadgets, skips = {}, []

    with open(excel_path / "GadgetExcelConfigData.json") as f:
        for gadget in json.load(f):
            id = gadget.get("id")
            name = gadget.get("jsonName")
            if name: gadgets[id] = name
            else: skips.append(id)

    with open(data_path / "gadget_names.lua", "w") as f:
        f.write("local gadget_names = {\n")
        for id, name in gadgets.items():
            f.write(f'\t[{id}] = "{name}",\n')
        f.write("}\nreturn gadget_names")

    print(f"Generated {len(gadgets)} gadget names (skipped {len(skips)})")

def gen_monster_names():
    print("Generating monster names...")
    describes = {}
    monsters = {}

    with open(excel_path / "MonsterDescribeExcelConfigData.json") as f:
        for i in json.load(f): describes[i["id"]] = str(i["nameTextMapHash"])

    with open(excel_path / "MonsterExcelConfigData.json") as f:
        for monster in json.load(f):
            id = monster.get("id")
            describe_id = monster.get("describeId")
            describe_hash = str(describes.get(describe_id))
            describe_name = textmap_data.get(describe_hash)

            name_hash = str(monster.get("nameTextMapHash"))
            textmap_name = textmap_data.get(name_hash)
            monster_name = monster.get("monsterName")

            final_name = describe_name or textmap_name or monster_name
            monsters[id] = final_name

    with open(data_path / "monster_names.lua", "w", encoding="utf-8") as f:
        f.write("local monster_names = {\n")
        for id, name in monsters.items():
            f.write(f'\t[{id}] = "{name}",\n')
        f.write("}\nreturn monster_names")
    
    print(f"Generated {len(monsters)} monster names")

if __name__ == "__main__":
    gen_ability_hashes()
    gen_skill_names()
    gen_gadget_names()
    gen_monster_names()