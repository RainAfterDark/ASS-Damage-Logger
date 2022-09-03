from pathlib import Path
import json

path = Path(__file__).parent

f_skill_excel = open(path / "AvatarSkillExcelConfigData.json")
skill_data = json.load(f_skill_excel)
f_skill_excel.close()

f_textmap = open(path / "TextMapEN.json", "r", encoding="utf-8")
textmap_data = json.load(f_textmap)
f_textmap.close()

f_lua = open(path / "skill_names.lua", "w", encoding="utf-8")
f_lua.write("local skill_names = {\n")

skips = 0

for i in skill_data:
    hash = str(i["nameTextMapHash"])
    if hash not in textmap_data:
        if not i["abilityName"]:
            if not i["skillIcon"]:
                print(f'skipped {i["id"]}')
                skips += 1
                continue
            f_lua.write(f'\t[{i["id"]}] = "{i["skillIcon"]}",\n')
            continue
        f_lua.write(f'\t[{i["id"]}] = "{i["abilityName"]}",\n')
        continue
    f_lua.write(f'\t[{i["id"]}] = "{textmap_data[hash]}",\n')

f_lua.write("}\nreturn skill_names")
f_lua.close()

print(f'skipped total: {skips}')