local gradient = {}

--stolen from https://stackoverflow.com/questions/38045839/lua-xterm-256-colors-gradient-scripting
local levels = {[0] = 0x00, 0x5f, 0x87, 0xaf, 0xd7, 0xff}

local function index_0_5(value) -- value = color component 0..255
   return math.floor(math.max((value - 35) / 40, value / 58))
end

local function nearest_16_231(r, g, b)   -- r, g, b = 0..255
   -- returns color_index_from_16_to_231, appr_r, appr_g, appr_b
   r, g, b = index_0_5(r), index_0_5(g), index_0_5(b)
   return 16 + 36 * r + 6 * g + b, levels[r], levels[g], levels[b]
end

local function nearest_232_255(r, g, b)  -- r, g, b = 0..255
   local gray = (3 * r + 10 * g + b) / 14
   -- this is a rational approximation for well-known formula
   -- gray = 0.2126 * r + 0.7152 * g + 0.0722 * b
   local index = math.min(23, math.max(0, math.floor((gray - 3) / 10)))
   gray = 8 + index * 10
   return 232 + index, gray, gray, gray
end

local function color_distance(r1, g1, b1, r2, g2, b2)
   return math.abs(r1 - r2) + math.abs(g1 - g2) + math.abs(b1 - b2)
end

local function nearest_term256_color_index(r, g, b)   -- r, g, b = 0..255
   local idx1, r1, g1, b1 = nearest_16_231(r, g, b)
   local idx2, r2, g2, b2 = nearest_232_255(r, g, b)
   local dist1 = color_distance(r, g, b, r1, g1, b1)
   local dist2 = color_distance(r, g, b, r2, g2, b2)
   return dist1 < dist2 and idx1 or idx2
end

local function convert_color_to_table(rrggbb)
   if type(rrggbb) == "string" then
      local r, g, b = rrggbb:match"(%x%x)(%x%x)(%x%x)"
      return {tonumber(r, 16), tonumber(g, 16), tonumber(b, 16)}
   else
      return rrggbb
   end
end

local function round(x)
   return math.floor(x + 0.5)
end

function gradient.generate(text, first_color, last_color)
   local r, g, b = table.unpack(convert_color_to_table(first_color))
   local dr, dg, db = table.unpack(convert_color_to_table(last_color))
   local char_pattern = "[^\128-\191][\128-\191]*"
   local n = math.max(1, select(2, text:gsub(char_pattern, "")) - 1)
   dr, dg, db = (dr - r)/n, (dg - g)/n, (db - b)/n
   local result = ""
   for c in text:gmatch(char_pattern) do
      --print(nearest_term256_color_index(round(r), round(g), round(b)))
      result = result..("\27[38;5;%03dm"):format(nearest_term256_color_index(
         round(r), round(g), round(b)))..c
      r, g, b = r + dr, g + dg, b + db
   end
   return result
end

return gradient