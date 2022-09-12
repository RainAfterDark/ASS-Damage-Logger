local theme = {
    --refer: https://en.wikipedia.org/wiki/ANSI_escape_code#8-bit
    damage = {83, 84, 85, 86, 87, 123, 117, 153, 147, 183, 177, 213, 207},
    col = {
        [true] = {
            [true] = 237,
            [false] = 238
        },
        [false] = {
            [true] = 235,
            [false] = 236
        } 
    },
    bool = {
        [true] = 147,
        [false] = 218
    },
    element = {
        ["Pyro"] = 209,
        ["Hydro"] = 117,
        ["Dendro"] = 118,
        ["Electro"] = 219,
        ["Cryo"] = 159,
        ["Anemo"] = 50,
        ["Geo"] = 184
    },
    avatar = {
        --Other
        ["Kate"] = 255,
        ["Traveler"] = 230,
        --Pyro
        ["Diluc"] = 196,
        ["Amber"] = 217,
        ["Xiangling"] = 209,
        ["Klee"] = 9,
        ["Bennett"] = 216,
        ["Xinyan"] = 197,
        ["Hu Tao"] = 203,
        ["Yanfei"] = 209,
        ["Yoimiya"] = 215,
        ["Thoma"] = 222,
        --Electro
        ["Lisa"] = 177,
        ["Razor"] = 105,
        ["Beidou"] = 141,
        ["Fischl"] = 212,
        ["Keqing"] = 219,
        ["Raiden"] = 147,
        ["Sara"] = 183,
        ["Yae Miko"] = 218,
        ["Shinobu"] = 146,
        ["Dori"] = 211,
        ["Cyno"] = 182,
        --Hydro
        ["Barbara"] = 117,
        ["Xingqiu"] = 38,
        ["Tartaglia"] = 39,
        ["Mona"] = 111,
        ["Kokomi"] = 153,
        ["Yelan"] = 75,
        ["Ayato"] = 45,
        ["Nilou"] = 74,
        ["Candace"] = 116,
        --Cryo
        ["Ayaka"] = 123,
        ["Kaeya"] = 189,
        ["Qiqi"] = 152,
        ["Chongyun"] = 159,
        ["Ganyu"] = 153,
        ["Diona"] = 225,
        ["Rosaria"] = 224,
        ["Eula"] = 195,
        ["Aloy"] = 231,
        ["Shenhe"] = 81,
        --Anemo
        ["Jean"] = 84,
        ["Venti"] = 85,
        ["Xiao"] = 48,
        ["Sucrose"] = 49,
        ["Kazuha"] = 122,
        ["Sayu"] = 121,
        ["Heizou"] = 157,
        --Geo
        ["Ningguang"] = 221,
        ["Zhongli"] = 220,    
        ["Noelle"] = 227,
        ["Albedo"] = 228,
        ["Gorou"] = 226,
        ["Itto"] = 214,
        ["Yun Jin"] = 222,
        --Dendro
        ["Collei"] = 155,
	    ["Tighnari"] = 154,
    }
}

return theme