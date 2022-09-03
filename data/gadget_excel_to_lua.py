from pathlib import Path
import json

path = Path(__file__).parent

f_gadget_excel = open(path / "GadgetExcelConfigData.json")
gadget_data = json.load(f_gadget_excel)
f_gadget_excel.close()

f_lua = open(path / "gadget_names.lua", "w")
f_lua.write("local gadget_names = {\n")

skips = 0
passed = 0
total_len = 0
longest = ""

for i in gadget_data:
    if not i["jsonName"]:
        print(f'skipped {i["id"]}')
        skips += 1
        continue

    name = i["jsonName"]
    total_len += len(name)
    passed += 1
    if len(name) > len(longest):
        longest = name

    f_lua.write(f'\t[{i["id"]}] = "{name}",\n')

f_lua.write("}\nreturn gadget_names")
f_lua.close()

print(f'skipped total: {skips}')
print(f'average length: {total_len / passed}')
print(f'longest: {longest}')