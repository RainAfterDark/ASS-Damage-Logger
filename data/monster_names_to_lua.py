from pathlib import Path
import json
from unittest import skip

path = Path(__file__).parent

f_monster_excel = open(path / "MonsterExcelConfigData.json")
monster_data = json.load(f_monster_excel)
f_monster_excel.close()

f_describe_excel = open(path / "MonsterDescribeExcelConfigData.json")
describe_data = json.load(f_describe_excel)
f_describe_excel.close()

f_textmap = open(path / "TextMapEN.json", "r", encoding="utf-8")
textmap_data = json.load(f_textmap)
f_textmap.close()

f_lua = open(path / "monster_names.lua", "w", encoding="utf-8")
f_lua.write("local monster_names = {\n")

describe_names = {}

for i in describe_data:
    describe_names[i["id"]] = str(i["nameTextMapHash"])

for i in monster_data:
    id = i["id"]
    
    if "describeId" in i:
        describe_id = i["describeId"]
        if describe_id in describe_names:
            describe_hash = str(describe_names[describe_id])
            if describe_hash in textmap_data:
                f_lua.write(f'\t[{id}] = "{textmap_data[describe_hash]}",\n')
                print(textmap_data[describe_hash])
                continue
    
    name_hash = str(i["nameTextMapHash"])
    if name_hash in textmap_data:
        f_lua.write(f'\t[{id}] = "{textmap_data[name_hash]}",\n')
        continue

    f_lua.write(f'\t[{id}] = "{i["monsterName"]}",\n')
    continue

f_lua.write("}\nreturn monster_names")
f_lua.close()
