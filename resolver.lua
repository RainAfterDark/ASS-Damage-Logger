local resolver = {}

--#region Names
local gadget_names = require("data.gadget_names")
local avatar_names = require("data.avatar_names")
local skill_names = require("data.skill_names")
local ability_hashes = require("data.ability_hashes")

local id_types = {
    [1000] = "AvatarID",
    [1006] = "Equip",
    [1509] = "Team",
    [1677] = "Avatar",
    [1678] = "Avatar",
    [1845] = "World",
    [3271] = "Reaction",
    [3355] = "Monster",
    [3356] = "Monster",
    [6710] = "SceneObj",
    [6711] = "SceneObj",
    [8808] = "Gadget"
}

local element_names = {
	[0] = "Physical", [1] = "Pyro", [2] = "Hydro", [3] = "Dendro",
    [4] = "Electro", [6] = "Unknown6", [5] = "Cryo", [7] = "Anemo",
    [8] = "Geo", [9] = "Unknown9" 
}

local amp_type_names = {
	[0] = "None", [2] = "Vaporize", [7] = "Melt", [34] = "Aggravate", [35] = "Spread"
}

local reaction_names = { --AID = reaction??
	[1] = "Bloom",
	[10] = "Overload", [14] = "Electro-Charged", [19] = "Superconduct", 
	[20] = "Swirl (Pyro)", [21] = "Swirl (Electro)", [22] = "Swirl (Hydro)", [23] = "Swirl (Cryo)",
	[31] = "Shatter", [37] = "Burgeon"
}
--#endregion

local avatar_ids = {}
local avatar_abilities = {}
local gadget_owner_ids = {}
local gadget_config_ids = {}
local unresolved_ids = {}
local ability_map = {}
local monster_ids = {}
local monster_count = 0

function resolver.id_type(id)
	return id_types[tonumber(tostring(id):sub(1, 4))] or "Unknown"
end

function resolver.get_id(id)
	id = tonumber(id)
	local type = resolver.id_type(id)
	
	if type == "AvatarID" then
		if SHOULD_RESOLVE_NAMES then
			return avatar_names[id]
		end
		return id

	elseif type == "Avatar" then
		local resolved = resolver.get_id(avatar_ids[id])
		if not resolved then
			if not unresolved_ids[id] then
				io.write("Warning: cannot resolve ID for ", id, ", please make sure you've captured SceneTeamUpdateNotify (change scene/team)\n")
				unresolved_ids[id] = true
			end
			return id
		end
		return resolved

	elseif type == "Monster" then
		if not monster_ids[id] then
            monster_count = monster_count + 1
			monster_ids[id] = "Monster" .. monster_count
		end
		return monster_ids[id]

	elseif type == "Gadget" then
		local resolved = resolver.get_id(gadget_owner_ids[id])
		return resolved
	
	elseif type == "World" or type == "Team" then
		return type --would be odd if this is Team but eh
	end

	return id
end

function resolver.get_apply(a)
	if a == 1 then
		return true
	elseif a == 0 then
		return false
	end
	return a
end

function resolver.get_element(id)
	return element_names[id] or id
end

function resolver.get_amp_type(id)
	return amp_type_names[id] or id
end

function resolver.get_attacker(attacker, aid, mid, defender)
	local type = resolver.id_type(attacker)
	if type == "Reaction" or (type == "Monster" and attacker == defender) then
		if ability_map[aid] then
			if ability_map[aid][mid] then
				if ability_map[aid][mid][defender] then
					return resolver.get_id(ability_map[aid][mid][defender])
				end
			end
		end
	end
	return resolver.get_id(attacker)
end

function resolver.get_source(attacker, aid)
	local type = resolver.id_type(attacker)

    if type == "Gadget" then
		if SHOULD_RESOLVE_NAMES then
			return "(G) " .. gadget_names[gadget_config_ids[attacker]]
		end
        return gadget_config_ids[attacker]

    elseif type == "Avatar" then
		if avatar_abilities[attacker][aid] then
			return "(A) " .. avatar_abilities[attacker][aid]
		end
		return "Direct"
	end

	return type
end

function resolver.get_reaction(aid, element, amp_type)

	local amp = amp_type_names[amp_type]
	if amp ~= "None" then return amp end

	local reaction = reaction_names[aid]
	if reaction then
        element = resolver.get_element(element)
        if(reaction == "Overload" and element ~= "Pyro") or
          (reaction == "Electro-Charged" and element ~= "Electro") or
          (reaction == "Superconduct" and element ~= "Cryo") or
		  (reaction == "Shatter" and element ~= "Physical") or
		  ((reaction == "Burgeon" or reaction == "Bloom") and element ~= "Dendro") then
            return "None"
        end
        return reaction
	end
	return "None"
end

function resolver.get_skill(id)
	if SHOULD_RESOLVE_NAMES then
		return skill_names[id] or id
	end
	return id
end

function resolver.add_avatar(entity_id, avatar_id)
    avatar_ids[entity_id] = avatar_id
end

function resolver.add_ability_hash(avatar_id, aid, hash)
	if ability_hashes[hash] then
		if not avatar_abilities[avatar_id] then
			avatar_abilities[avatar_id] = {}
		end
		avatar_abilities[avatar_id][aid] = ability_hashes[hash]
	end
end

function resolver.add_gadget(entity_id, owner_id, config_id)
    gadget_owner_ids[entity_id] = owner_id
    gadget_config_ids[entity_id] = config_id
end

function resolver.add_ability_invoke(aid, mid, entity_id, apply_id)
    if not ability_map[aid] then ability_map[aid] = {} end
    if not ability_map[aid][mid] then ability_map[aid][mid] = {} end
    --[[if ability_map[aid][mid][entity_id] then
        print("Found dupe of " .. aid .. 
        " / " .. mid .. 
        " / oldID: " .. resolver.get_id(ability_map[aid][mid][entity_id]) .. 
        " / newID: " .. resolver.get_id(apply_id) .. 
        " / " .. resolver.get_id(entity_id))
    end]]
    ability_map[aid][mid][entity_id] = apply_id
end

function resolver.reset_ids()
    for k in pairs(avatar_ids) do avatar_ids[k] = nil end
    for k in pairs(unresolved_ids) do unresolved_ids[k] = nil end

	for avatar_id in pairs(avatar_abilities) do
		for aid in pairs(avatar_abilities[avatar_id]) do
			avatar_abilities[avatar_id][aid] = nil
		end
		avatar_abilities[avatar_id] = nil
	end

    for aid in pairs(ability_map) do 
        for mid in pairs(ability_map[aid]) do
            for entity_id in pairs(ability_map[aid][mid]) do
                ability_map[aid][mid][entity_id] = nil
            end
            ability_map[aid][mid] = nil 
        end
        ability_map[aid] = nil
    end
end

return resolver