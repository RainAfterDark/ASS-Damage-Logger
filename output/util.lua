local util = {}

local theme = require("output.theme")
local gradient = require("output.gradient")

local log_file

--#region String manipulation
function util.trim(str, len)
	if str:len() <= len or str:len() < 2 then
		return str 
	end
	
	if(str:len() > len) then
		str = str:sub(1, len - 1)
		str = str .. "-"
	else
		str = str:sub(1, len)
	end

	return str
end

function util.pad(str, len)
	str = util.trim(str, len)
	while str:len() < len do
		str = str .. " " 
	end
	return str
end
--#endregion

--#region Colors
function util.color_bg(n)
	io.write("\27[48;5;" .. n .. "m")
end

function util.color_fg(n)
	io.write("\27[38;5;" .. n .. "m")
end

function util.reset_style()
	io.write("\27[0m\27[38;5;255m")
end

local thresholds = {1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377}

local function damage_color(damage)
	if type(damage) ~= "number" then return 255 end
	for i, v in ipairs(thresholds) do
		if damage < (v * 1000) then
			return theme.damage[i]
		end
	end
	return theme.damage[#thresholds]
end
--#endregion

--#region Time
function util.convert_time(ms)
	local msms = ms % (60 * 60 * 1000) --minutes seconds millis
	local now = os.time() * 1000
	local hours_ms = now - (now % (60 * 60 * 1000))
	return hours_ms + msms
end

function util.format_time(ms)
	return os.date("%H:%M:%S", math.floor(ms / 1000))
end

local last_time = 0

function util.delta_time(ms)
	local delta = ms - last_time
	if last_time == 0 then delta = 0 end
	last_time = ms
	return delta
end

function util.reset_last_time()
	last_time = 0
end
--#endregion

--#region Output
function util.log_file(...)
	if log_file then
		log_file:write(...)
		log_file:flush()
	end
end

function util.write(...)
	io.write(...)
	if FILE_LOGGING then
		util.log_file(...)
	end
end

function util.write_line(len)
	if not TABLE_FORMAT then
		return
	end
	local line = ""
	while line:len() < len do
		line = line .. "-"
	end
	util.write(line, "\n")
end

local odd_row = true
local odd_col = true

local function write_col(str, len, c, last)
	if str == nil then
		if not TABLE_FORMAT then return end
		str = "-"
	end
	str = tostring(str)

	if TABLE_FORMAT then
		if c then util.color_fg(c) end
		util.color_bg(theme.col[odd_row][odd_col])
		util.write(" ", util.pad(str, len), " ")
		util.reset_style()
		odd_col = last and true or not odd_col

	else util.write(str, last and "" or ", ") end
end

function util.write_row(type, uid, time, delta, source, attacker, 
	damage, crit, apply, element, reaction, amp_type, amp_rate, count, aid, mid, defender)

	write_col(type, 6)
	write_col(uid, 6)
	write_col(time, 8)
	write_col(delta, 7)
	write_col(source, 40)
	write_col(attacker, 9, theme.avatar[attacker])

	write_col(damage, 15, damage_color(damage))
	write_col(crit, 5, theme.bool[crit])
	write_col(apply, 5, theme.bool[apply])
	write_col(element, 8, theme.element[element])
	write_col(reaction, 15, reaction ~= "None" and theme.element[element])
	write_col(amp_type, 9, amp_type ~= "None" and theme.element[element])
	write_col(amp_rate, 13)

	write_col(count, 2)
	write_col(aid, 3)
	write_col(mid, 3)
	write_col(defender, 40, nil, true)

	util.reset_style()
	util.write("\n")
	odd_row = not odd_row
end

function util.write_header(team_text, offsets_text)
	if not TABLE_FORMAT then
		util.write(team_text, "\n")
		util.write(offsets_text, "\n")
		return
	end

	util.color_bg(240)
	util.write(" ", util.pad(team_text, 227), "\n")
	util.color_bg(239)
	util.write(" ", util.pad(offsets_text, 227), "\n")
	util.reset_style()
	util.write_row("Type", "UID", "Time", "Delta", "Source (Gadget / Ability)", "Attacker", 
	"Damage", "Crit", "Apply", "Element", "Reaction", "Amp Type", "Amp Rate", "C", "AID", "MID", "Defender")
end
--#endregion

function util.init()
	os.execute("cls")
	util.reset_style()
	io.write("\27[4m", gradient.generate(" ASS Damage ", {255, 100, 255}, {100, 255, 255}))
	io.write(gradient.generate("Logger v" .. GAME_VERSION, {100, 255, 255}, {100, 255, 100}))
	util.reset_style()
	io.write(" by Ame\n\n")

	if FILE_LOGGING then
		log_file = assert(io.open("latest.txt", FILE_OPEN_MODE))
	end
end

return util