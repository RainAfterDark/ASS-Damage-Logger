local resolver = {}

local util = require("output.util")

--#region Names
local avatar_names = require("data.avatar_names")
local ability_hashes = require("data.ability_hashes")
local monster_names = require("data.monster_names")
local gadget_names = require("data.gadget_names")
local skill_names = require("data.skill_names")

local id_types = {
    [1000] = "AvatarID",
    [1006] = "Equip",
    [1509] = "Team",
    [1677] = "Avatar", [1678] = "Avatar", [1679] = "Avatar",
    [1845] = "World",
    [3271] = "Reaction",
	[3455] = "GUID",
    [3355] = "Monster", [3356] = "Monster", [3357] = "Monster",
    [6710] = "SceneObj", [6711] = "SceneObj", [6712] = "SceneObj",
    [8808] = "Gadget"
}

local element_names = {
	[0] = "Physical", [1] = "Pyro", [2] = "Hydro", [3] = "Dendro",
    [4] = "Electro", [5] = "Cryo", [6] = "Frozen", [7] = "Anemo",
    [8] = "Geo", [9] = "AntiFire", [10] = "VehicleMuteIce",
	[11] = "Mushroom", [12] = "Overdose", [13] = "Wood",
	[14] = "COUNT"
}

local amp_type_names = {
	[0] = "None", [2] = "Vaporize", [7] = "Melt", [34] = "Aggravate", [35] = "Spread"
}

local reaction_names = { --AID = reaction??
	[6] = "Burning", [10] = "Overload", [14] = "ElectroCharged", [19] = "Superconduct", 
	[20] = "SwirlPyro", [21] = "SwirlElectro", [22] = "SwirlHydro", [23] = "SwirlCryo",
	[31] = "Shatter", [37] = "Burgeon"
}

local base_reaction_ids = {
	["Burning"] = 3, ["Overload"] = 1, ["ElectroCharged"] = 14, ["Superconduct"] = 16,
	["SwirlPyro"] = 17, ["SwirlElectro"] = 19, ["SwirlHydro"] = 18, ["SwirlCryo"] = 20,
	["Shatter"] = 31, ["Burgeon"] = 36
}
--#endregion

--#region Data Tables
local guids = {}
local avatar_ids = {}
local avatar_abilities = {}
local unresolved_ids = {}

local gadget_owner_ids = {}
local gadget_config_ids = {}

local base_reaction_dmg = {}
local last_reaction_dmg = {}

local monster_ids = {}
local monster_count = {}
local monster_affix = {}
local monster_letter = 0
--#endregion

--#region Getting Data
function resolver.id_type(id)
	return id_types[tonumber(tostring(id):sub(1, 4))] or "Unknown"
end

function resolver.get_root(id)
	id = tonumber(id)
	local type = resolver.id_type(id)

	if type == "GUID" then
		local resolved = resolver.get_root(guids[id])
		return resolved
	
	elseif type == "AvatarID" then
		return avatar_names[id] or id

	elseif type == "Avatar" then
		local resolved = resolver.get_root(avatar_ids[id])
		if not resolved then
			if not unresolved_ids[id] then
				io.write("Warning: cannot resolve ID for ", id, ", please make sure you've captured SceneTeamUpdateNotify (change scene/team)\n")
				unresolved_ids[id] = true
			end
			return id
		end
		return resolved

	elseif type == "Monster" then
		local resolved = monster_ids[id]
		if not resolved then
			if not unresolved_ids[id] then
				io.write("Warning: cannot resolve ID for ", id, ", SceneEntityAppearNotify for this monster must not have been captured\n")
				unresolved_ids[id] = true
			end
			return id
		end
		return resolved

	elseif type == "Gadget" then
		local resolved = resolver.get_root(gadget_owner_ids[id])
		return resolved
	
	elseif type == "World" or type == "Team" then
		return type
	end

	return id or "Unknown"
end

function resolver.get_element(id)
	return element_names[id] or id
end

function resolver.get_amp_type(id)
	return amp_type_names[id] or id
end

function resolver.get_attacker(attacker, caster, aid, damage)
	if resolver.id_type(attacker) == "Reaction" or resolver.id_type(caster) == "Reaction" then

		local candidate = resolver.get_root(base_reaction_dmg[base_reaction_ids[reaction_names[aid]]])
		if not USE_REACTION_CORRECTION or damage == 0 then
			return candidate
		end

		if not last_reaction_dmg[aid] then
			last_reaction_dmg[aid] = {}
		end

		if not last_reaction_dmg[aid][candidate] then
			last_reaction_dmg[aid][candidate] = {0}
		end

		for avatar, dmg_table in pairs(last_reaction_dmg[aid]) do
			for _, dmg in ipairs(dmg_table) do
				if dmg == damage and avatar ~= candidate then
					print("Resolved reaction source: " .. reaction_names[aid] .. 
					" " .. candidate .. " -> " .. avatar)
					return avatar
				end
			end
		end

		local dmg_table = last_reaction_dmg[aid][candidate]
		--if damage > dmg_table[#dmg_table] then --there are instances where this condition might be useful or does nothing
			table.insert(dmg_table, damage)
		--end

		return candidate
	end
	return resolver.get_root(attacker)
end

function resolver.get_source(attacker, caster, element, aid, defender)
	local type = resolver.id_type(attacker)

	if type == "Reaction" or resolver.id_type(caster) == "Reaction" then
		return "Reaction"
	end

	if attacker == defender then
		if element == "Physical" then
			return "Fall Damage"
		end
		return "Self-Inflicted"
	end

    if type == "Gadget" then
		local gadget = gadget_names[gadget_config_ids[attacker]] 
		or "Gadget_" .. gadget_config_ids[attacker]
		return gadget

    elseif type == "Avatar" then
		if avatar_abilities[attacker] 
		and avatar_abilities[attacker][aid] then
			return avatar_abilities[attacker][aid]
		end
		return "Direct"
	end

	return type
end

function resolver.get_reaction(aid, mid, element, attacker)
	if element == "Dendro" then
		if aid == 2 then
			if mid == 5 then return "Bloom"
			elseif mid == 4 then return "BountifulBloom" end
		elseif aid == 1 and mid == 2
		and resolver.get_root(attacker) ~= "Collei" then --holy cope conditions but whatever
			return "Hyperbloom"
		end
	end

	local reaction = reaction_names[aid]
	if reaction then
        if(reaction == "Burning" and element ~= "Pyro") or
		  (reaction == "Overload" and element ~= "Pyro") or
          (reaction == "ElectroCharged" and element ~= "Electro") or
          (reaction == "Superconduct" and element ~= "Cryo") or
		  (reaction == "Shatter" and element ~= "Physical") or
		  (reaction == "Burgeon" and element ~= "Dendro") or
		  (reaction == "SwirlPyro" and element ~= "Pyro") or
		  (reaction == "SwirlHydro" and element ~= "Hydro") or
		  (reaction == "SwirlElectro" and element ~= "Electro") or
		  (reaction == "SwirlCryo" and element ~= "Cryo") then
            return "None"
        end
        return reaction
	end
	return "None"
end

function resolver.get_skill(id)
	return skill_names[id] or id
end
--#endregion

--#region Updating Data
function resolver.add_avatar(guid, entity_id, avatar_id)
	guids[guid] = avatar_id
    avatar_ids[entity_id] = avatar_id
end

function resolver.add_ability_hash(avatar_id, aid, hash)
	if not avatar_abilities[avatar_id] then
		avatar_abilities[avatar_id] = {}
	end
	avatar_abilities[avatar_id][aid] = ability_hashes[hash] or ("Ability_" .. hash)
end

function resolver.add_monster(entity_id, monster_id)
	local name = monster_names[monster_id] or ("Unknown " .. monster_id)
	if not monster_count[monster_id] then
		monster_affix[monster_id] = util.base26(monster_letter)
		monster_count[monster_id] = 1
		monster_letter = monster_letter + 1
	end

	monster_ids[entity_id] = monster_affix[monster_id] .. monster_count[monster_id] .. " " .. name
	monster_count[monster_id] = monster_count[monster_id] + 1
end

function resolver.add_gadget(entity_id, owner_id, config_id)
    gadget_owner_ids[entity_id] = owner_id
    gadget_config_ids[entity_id] = config_id
end

function resolver.update_reaction(reaction, source_id, entity_id)
	--if resolver.id_type(entity_id) ~= "Monster" then
		--return
	--end
	base_reaction_dmg[reaction] = source_id
end

function resolver.reset_ids()
	for k in pairs(guids) do guids[k] = nil end
    for k in pairs(avatar_ids) do avatar_ids[k] = nil end
    for k in pairs(unresolved_ids) do unresolved_ids[k] = nil end

	for k in pairs(base_reaction_dmg) do base_reaction_dmg[k] = nil end
	for aid in pairs(last_reaction_dmg) do
		for avatar in pairs(last_reaction_dmg[aid]) do
			last_reaction_dmg[aid][avatar] = nil
		end
		last_reaction_dmg[aid] = nil
	end

	for avatar_id in pairs(avatar_abilities) do
		for aid in pairs(avatar_abilities[avatar_id]) do
			avatar_abilities[avatar_id][aid] = nil
		end
		avatar_abilities[avatar_id] = nil
	end
end
--#endregion

return resolver