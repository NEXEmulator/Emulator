--!native
--!optimize 2

local pairs = pairs
local tostring = tostring
local error = error
local pcall = pcall
local print = print

local string_format = string.format
local string_rep = string.rep
local string_lower = string.lower
local string_byte = string.byte
local string_sub = string.sub
local string_char = string.char

local table_insert = table.insert
local table_create = table.create
local table_concat = table.concat
local bit32_band = bit32.band
local bit32_rshift = bit32.rshift
local bit32_lshift = bit32.lshift
local bit32_bor = bit32.bor

local math_floor = math.floor
local math_min   = math.min
local os_clock = os.clock

local buffer_readu8 = buffer.readu8
local buffer_readu32 = buffer.readu32
local buffer_readi32 = buffer.readi32
local buffer_readf32 = buffer.readf32
local buffer_readf64 = buffer.readf64
local buffer_readstring = buffer.readstring
local buffer_fromstring = buffer.fromstring
local buffer_len = buffer.len

local function SafeQuoteStr(s)
	if type(s) ~= "string" then return '"?"' end
	local pattern_finder = s.find
	if not pattern_finder(s, "[\0-\31\127-\255]") then
		return string_format("%q", s)
	end
	local out = table_create(#s)
	local len  = #s
	for i = 1, len do
		local b = string_byte(s, i)
		if     b == 0  then
			local nb = (i < len) and string_byte(s, i + 1) or nil
			out[#out + 1] = (nb and nb >= 48 and nb <= 57) and "\\000" or "\\0"
		elseif b == 7  then out[#out + 1] = "\\a"
		elseif b == 8  then out[#out + 1] = "\\b"
		elseif b == 9  then out[#out + 1] = "\\t"
		elseif b == 10 then out[#out + 1] = "\\n"
		elseif b == 11 then out[#out + 1] = "\\v"
		elseif b == 12 then out[#out + 1] = "\\f"
		elseif b == 13 then out[#out + 1] = "\\r"
		elseif b == 34 then out[#out + 1] = '\\"'
		elseif b == 92 then out[#out + 1] = "\\\\"
		elseif b < 32 or b == 127 then
			local nb = (i < len) and string_byte(s, i + 1) or nil
			if nb and nb >= 48 and nb <= 57 then
				out[#out + 1] = string_format("\\%03d", b)
			else
				out[#out + 1] = string_format("\\%d", b)
			end
		elseif b >= 128 then
			out[#out + 1] = string_format("\\%d", b)
		else
			out[#out + 1] = string_char(b)
		end
	end
	return '"' .. table_concat(out) .. '"'
end

local NewOpcode = function(Name, Type, Number, Aux)
	return {
		Name = Name,
		Type = Type,
		Number = Number,
		Aux = Aux or false,
	}
end

local OpTableV5 = {}
local OpTableV6 = {
	NewOpcode("NOP", "none", 0x00),
	NewOpcode("BREAK", "none", 0xE3),

	NewOpcode("LOADNIL", "iA", 0xC6),

	NewOpcode("LOADB", "iABC", 0xA9),

	NewOpcode("LOADN", "iABx", 0x8C),

	NewOpcode("LOADK", "iABx", 0x6F),

	NewOpcode("MOVE", "iAB", 0x52),

	NewOpcode("GETGLOBAL", "iAC", 0x35, true),

	NewOpcode("SETGLOBAL", "iAC", 0x18, true),

	NewOpcode("GETUPVAL", "iAB", 0xFB),

	NewOpcode("SETUPVAL", "iAB", 0xDE),

	NewOpcode("CLOSEUPVALS", "iA", 0xC1),

	NewOpcode("GETIMPORT", "iABx", 0xA4, true),

	NewOpcode("GETTABLE", "iABC", 0x87),

	NewOpcode("SETTABLE", "iABC", 0x6A),

	NewOpcode("GETTABLEKS", "iABC", 0x4D, true),

	NewOpcode("SETTABLEKS", "iABC", 0x30, true),

	NewOpcode("GETTABLEN", "iABC", 0x13),

	NewOpcode("SETTABLEN", "iABC", 0xF6),

	NewOpcode("NEWCLOSURE", "iABx", 0xD9),

	NewOpcode("NAMECALL", "iABC", 0xBC, true),

	NewOpcode("CALL", "iABC", 0x9F),

	NewOpcode("RETURN", "iAB", 0x82),

	NewOpcode("JUMP", "isBx", 0x65),

	NewOpcode("JUMPBACK", "isBx", 0x48),

	NewOpcode("JUMPIF", "iAsBx", 0x2B),

	NewOpcode("JUMPIFNOT", "iAsBx", 0x0E),

	NewOpcode("JUMPIFEQ", "iAsBx", 0xF1, true),
	NewOpcode("JUMPIFLE", "iAsBx", 0xD4, true),
	NewOpcode("JUMPIFLT", "iAsBx", 0xB7, true),
	NewOpcode("JUMPIFNOTEQ", "iAsBx", 0x9A, true),
	NewOpcode("JUMPIFNOTLE", "iAsBx", 0x7D, true),
	NewOpcode("JUMPIFNOTLT", "iAsBx", 0x60, true),

	NewOpcode("ADD", "iABC", 0x43),
	NewOpcode("SUB", "iABC", 0x26),
	NewOpcode("MUL", "iABC", 0x09),
	NewOpcode("DIV", "iABC", 0xEC),
	NewOpcode("MOD", "iABC", 0xCF),
	NewOpcode("POW", "iABC", 0xB2),

	NewOpcode("ADDK", "iABC", 0x95),
	NewOpcode("SUBK", "iABC", 0x78),
	NewOpcode("MULK", "iABC", 0x5B),
	NewOpcode("DIVK", "iABC", 0x3E),
	NewOpcode("MODK", "iABC", 0x21),
	NewOpcode("POWK", "iABC", 0x04),

	NewOpcode("AND", "iABC", 0xE7),
	NewOpcode("OR", "iABC", 0xCA),

	NewOpcode("ANDK", "iABC", 0xAD),
	NewOpcode("ORK", "iABC", 0x90),

	NewOpcode("CONCAT", "iABC", 0x73),

	NewOpcode("NOT", "iAB", 0x56),
	NewOpcode("MINUS", "iAB", 0x39),
	NewOpcode("LENGTH", "iAB", 0x1C),

	NewOpcode("NEWTABLE", "iAB", 0xFF, true),

	NewOpcode("DUPTABLE", "iABx", 0xE2),

	NewOpcode("SETLIST", "iABC", 0xC5, true),

	NewOpcode("FORNPREP", "iABx", 0xA8),

	NewOpcode("FORNLOOP", "iABx", 0x8B),

	NewOpcode("FORGLOOP", "iABx", 0x6E, true),

	NewOpcode("FORGPREP_INEXT", "iAsBx", 0x51),

	NewOpcode("FORGPREP_NEXT", "iAsBx", 0x17),

	NewOpcode("NATIVECALL", "none", 0xFA),

	NewOpcode("GETVARARGS", "iAB", 0xDD),

	NewOpcode("DUPCLOSURE", "iABx", 0xC0),

	NewOpcode("PREPVARARGS", "iA", 0xA3),

	NewOpcode("LOADKX", "iA", 0x86, true),

	NewOpcode("JUMPX", "isAx", 0x69),

	NewOpcode("FASTCALL", "iAC", 0x4C),

	NewOpcode("COVERAGE", "isAx", 0x2F),

	NewOpcode("CAPTURE", "iAB", 0x12),

	NewOpcode("SUBRK", "iABC", 0xF5),
	NewOpcode("DIVRK", "iABC", 0xD8),

	NewOpcode("FASTCALL1", "iABC", 0xBB),

	NewOpcode("FASTCALL2", "iABC", 0x9E, true),

	NewOpcode("FASTCALL2K", "iABC", 0x81, true),

	NewOpcode("FASTCALL3", "iABC", 0x34, true),

	NewOpcode("FORGPREP", "iAB", 0x64),

	NewOpcode("JUMPXEQKNIL", "iAsBx", 0x47, true),
	NewOpcode("JUMPXEQKB", "iAsBx", 0x2A, true),

	NewOpcode("JUMPXEQKN", "iAsBx", 0x0D, true),
	NewOpcode("JUMPXEQKS", "iAsBx", 0xF0, true),

	NewOpcode("IDIV", "iABC", 0xD3),

	NewOpcode("IDIVK", "iABC", 0xB6),
}

local BuiltInFunctionsMap = {
	[0] = "none",
	[1] = "assert",
	[2] = "math.abs",
	[3] = "math.acos",
	[4] = "math.asin",
	[5] = "math.atan2",
	[6] = "math.atan",
	[7] = "math.ceil",
	[8] = "math.cosh",
	[9] = "math.cos",
	[10] = "math.deg",
	[11] = "math.exp",
	[12] = "math.floor",
	[13] = "math.fmod",
	[14] = "math.frexp",
	[15] = "math.ldexp",
	[16] = "math.log10",
	[17] = "math.log",
	[18] = "math.max",
	[19] = "math.min",
	[20] = "math.modf",
	[21] = "math.pow",
	[22] = "math.rad",
	[23] = "math.sinh",
	[24] = "math.sin",
	[25] = "math.sqrt",
	[26] = "math.tanh",
	[27] = "math.tan",
	[28] = "bit32.arshift",
	[29] = "bit32.band",
	[30] = "bit32.bnot",
	[31] = "bit32.bor",
	[32] = "bit32.bxor",
	[33] = "bit32.btest",
	[34] = "bit32.extract",
	[35] = "bit32.lrotate",
	[36] = "bit32.lshift",
	[37] = "bit32.replace",
	[38] = "bit32.rrotate",
	[39] = "bit32.rshift",
	[40] = "type",
	[41] = "string.byte",
	[42] = "string.char",
	[43] = "string.len",
	[44] = "typeof",
	[45] = "string.sub",
	[46] = "math.clamp",
	[47] = "math.sign",
	[48] = "math.round",
	[49] = "rawset",
	[50] = "rawget",
	[51] = "rawequal",
	[52] = "table.insert",
	[53] = "table.unpack",
	[54] = "vector",
	[55] = "bit32.countlz",
	[56] = "bit32.countrz",
	[57] = "select",
	[58] = "rawlen",
	[59] = "bit32.extractk",
	[60] = "getmetatable",
	[61] = "setmetatable",
	[62] = "tonumber",
	[63] = "tostring",
	[64] = "bit32.byteswap",
	[65] = "buffer.readi8",
	[66] = "buffer.readu8",
	[67] = "buffer.writeu8",
	[68] = "buffer.readi16",
	[69] = "buffer.readu16",
	[70] = "buffer.writeu16",
	[71] = "buffer.readi32",
	[72] = "buffer.readu32",
	[73] = "buffer.writeu32",
	[74] = "buffer.readf32",
	[75] = "buffer.writef32",
	[76] = "buffer.readf64",
	[77] = "buffer.writef64",
	[78] = "vector.magnitude",
	[79] = "vector.normalize",
	[80] = "vector.cross",
	[81] = "vector.dot",
	[82] = "vector.floor",
	[83] = "vector.ceil",
	[84] = "vector.abs",
	[85] = "vector.sign",
	[86] = "vector.clamp",
	[87] = "vector.min",
	[88] = "vector.max",
	[89] = "math.lerp",
	[90] = "vector.lerp",
	[91] = "math.isnan",
	[92] = "math.isinf",
	[93] = "math.isfinite",
	[94]  = "integer.create",
	[95]  = "integer.tonumber",
	[96]  = "integer.neg",
	[97]  = "integer.add",
	[98]  = "integer.sub",
	[99]  = "integer.mul",
	[100] = "integer.div",
	[101] = "integer.min",
	[102] = "integer.max",
	[103] = "integer.rem",
	[104] = "integer.idiv",
	[105] = "integer.udiv",
	[106] = "integer.urem",
	[107] = "integer.mod",
	[108] = "integer.clamp",
	[109] = "integer.band",
	[110] = "integer.bor",
	[111] = "integer.bnot",
	[112] = "integer.bxor",
	[113] = "integer.lt",
	[114] = "integer.le",
	[115] = "integer.ult",
	[116] = "integer.ule",
	[117] = "integer.gt",
	[118] = "integer.ge",
	[119] = "integer.ugt",
	[120] = "integer.uge",
	[121] = "integer.lshift",
	[122] = "integer.rshift",
	[123] = "integer.arshift",
	[124] = "integer.lrotate",
	[125] = "integer.rrotate",
	[126] = "integer.extract",
	[127] = "integer.btest",
	[128] = "integer.countrz",
	[129] = "integer.countlz",
	[130] = "integer.bswap",
	[131] = "buffer.readinteger",
	[132] = "buffer.writeinteger",
}

local LbcConstantBoolean = 1
local LbcConstantNumber = 2
local LbcConstantString = 3
local LbcConstantImport = 4
local LbcConstantTable = 5
local LbcConstantClosure = 6
local LbcConstantVector = 7
local LbcConstantTableWithConstants = 8
local LbcConstantInteger = 9
local LbcConstantClassShape = 10
local LbcConstantVectorDouble = 11

local LbcVersionMin = 3
local LbcVersionMax = 14
local LbcVersionClasses = 100

for i = 1, #OpTableV6 do
	local Opcode = OpTableV6[i]
	if Opcode.Name ~= "FASTCALL3" then
		table_insert(OpTableV5, Opcode)
	end
end

local OpTableV7 = OpTableV6

local OpTableV9 = {}
for _, op in ipairs(OpTableV7) do OpTableV9[#OpTableV9+1] = op end
OpTableV9[#OpTableV9+1] = NewOpcode("GETUDATAKS",    "iABC", 0x99, true)
OpTableV9[#OpTableV9+1] = NewOpcode("SETUDATAKS",    "iABC", 0x7C, true)
OpTableV9[#OpTableV9+1] = NewOpcode("NAMECALLUDATA", "iABC", 0x5F, true)
local OpTableV8 = OpTableV9

local function CopyOpcodeTableWithout(Source, Excluded)
	local Result = {}
	for _, op in ipairs(Source) do
		if not Excluded[op.Name] then
			Result[#Result + 1] = op
		end
	end
	return Result
end

local OpTableV4 = CopyOpcodeTableWithout(OpTableV5, {
	SUBRK = true, DIVRK = true,
})

local OpTableV3 = CopyOpcodeTableWithout(OpTableV4, {
	IDIV = true, IDIVK = true,
})

local OpTableV10 = {}
for _, op in ipairs(OpTableV9) do OpTableV10[#OpTableV10 + 1] = op end
OpTableV10[#OpTableV10 + 1] = NewOpcode("NEWCLASSMEMBER", "iABC", 0x42, true)

local OpTableV11 = {}
for _, op in ipairs(OpTableV10) do OpTableV11[#OpTableV11 + 1] = op end
OpTableV11[#OpTableV11 + 1] = NewOpcode("CALLFB", "iABC", 0x25, true)
OpTableV11[#OpTableV11 + 1] = NewOpcode("CMPPROTO", "iAsBx", 0x08, true)

local OpTableV12 = OpTableV11
local OpTableV13 = OpTableV12

local OpTableV14 = {}
for _, op in ipairs(OpTableV13) do OpTableV14[#OpTableV14 + 1] = op end
OpTableV14[#OpTableV14 + 1] = NewOpcode("FASTPCALL", "iAC", 0xEB)

local OpTableV100 = {}
for _, op in ipairs(OpTableV14) do OpTableV100[#OpTableV100 + 1] = op end
OpTableV100[#OpTableV100 + 1] = NewOpcode("NEWCLASS", "iABC", 0xCE, true)

local OpInfoMaps = {}
local OpTableVersionMap = {
	[100] = OpTableV100,
	[14] = OpTableV14,
	[13] = OpTableV13,
	[12] = OpTableV12,
	[11] = OpTableV11,
	[10] = OpTableV10,
	[9] = OpTableV9,
	[8] = OpTableV8,
	[7] = OpTableV7,
	[6] = OpTableV6,
	[5] = OpTableV5,
	[4] = OpTableV4,
	[3] = OpTableV3,
}

for Version, OpTable in pairs(OpTableVersionMap) do
	local Map = {}

	for i = 1, #OpTable do
		local Info = OpTable[i]

		if Map[Info.Number] then
			error(string_format(
				"Duplicate opcode byte 0x%02X for %s and %s in version %d",
				Info.Number,
				Map[Info.Number].Name,
				Info.Name,
				Version
			))
		end
		Map[Info.Number] = Info
	end

	OpInfoMaps[Version] = Map
end

local _INV_SRC  = "Invalid source index"
local _ANON_FN  = "anonymous_function_"
local _INV_PART = "InvalidImportPart"

local OpcodeHandlerMaps = {}
do
	local Handlers = {}

	local KToStr = function(K)
		if not K then return "Invalid" end

		local Value = K.Value

		if K.Type == 3 then
			return SafeQuoteStr(Value)
		end

		if K.Type == LbcConstantInteger then
			return string_format("%d", Value)
		end

		if K.Type == LbcConstantTableWithConstants then
			return "{...}"
		end

		if K.Type == LbcConstantClassShape then
			return "{-- class shape}"
		end

		if K.Type == LbcConstantVector or K.Type == LbcConstantVectorDouble then
			local V = K.Value
			return string_format("Vector3.new(%s, %s, %s)", tostring(V[1]), tostring(V[2]), tostring(V[3]))
		end

		return tostring(Value)
	end

	Handlers.NOP = function(I) return "", "-- do nothing (no-op / NOP)" end

	Handlers.BREAK = function(I) return "", "-- break" end

	Handlers.PREPVARARGS = function(Instruction)
		local A = Instruction.A

		if A > 0 then
			return A, "-- Prepare for " .. tostring(A - 1) .. " variables as ..."
		end

		return A, "-- Prepare for any number (top) of variables as ..."
	end

	Handlers.GETVARARGS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		if B == 0 then
			return string_format("%d, %d", A, B), string_format("var%d, ... = ... -- Load all remaining variables", A)
		end

		local VariableCount = B - 1

		if VariableCount == 0 then
			return string_format("%d, %d", A, B), "-- GETVARARGS (0 variables)"
		end

		local VarList = table_create(VariableCount)

		for i = 0, VariableCount - 1 do
			VarList[#VarList+1] = "var" .. tostring(A + i)
		end

		local VarString = table_concat(VarList, ", ")
		local Plural = VariableCount == 1 and "" or "s"

		return string_format("%d, %d", A, B), string_format("%s = ... -- Load %d variable%s", VarString, VariableCount, Plural)
	end

	Handlers.LOADNIL = function(Instruction)
		local A = Instruction.A

		return A, string_format("var%d = nil", A)
	end

	Handlers.LOADB = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local CodeIndex = Instruction.CodeIndex
		local Comment = string_format("var%d = %s", A, tostring(B ~= 0))

		if C ~= 0 then
			Comment = Comment .. " -- goto [" .. tostring(CodeIndex + 1 + C) .. "]"
		end

		return string_format("%d, %d, %d", A, B, C), Comment
	end

	Handlers.LOADN = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx
		local signedBx = Bx >= 0x8000 and Bx - 0x10000 or Bx

		return string_format("%d, %d", A, signedBx), string_format("var%d = %d", A, signedBx)
	end

	Handlers.LOADK = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx
		local K = Instruction.KTable[Bx + 1]

		return string_format("%d, %d", A, Bx), string_format("var%d = %s", A, KToStr(K))
	end

	Handlers.LOADKX = function(Instruction)
		local A = Instruction.A
		local Aux = Instruction.Aux
		local K = Instruction.KTable[Aux + 1]

		return A, string_format("var%d = %s", A, KToStr(K))
	end

	Handlers.MOVE = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("var%d = var%d", A, B)
	end

	Handlers.GETGLOBAL = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local Aux = Instruction.Aux
		local NameK = Instruction.KTable[Aux + 1]
		local Name = NameK and NameK.Type == LbcConstantString and NameK.Value or "Invalid"

		return string_format("%d, %d [%d]", A, C, Aux), string_format("var%d = %s", A, Name)
	end

	Handlers.SETGLOBAL = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local Aux = Instruction.Aux
		local NameK = Instruction.KTable[Aux + 1]
		local Name = NameK and NameK.Type == LbcConstantString and NameK.Value or "Invalid"

		return string_format("%d, %d [%d]", A, C, Aux), string_format("%s = var%d", Name, A)
	end

	Handlers.GETUPVAL = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("var%d = up%d", A, B)
	end

	Handlers.SETUPVAL = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("up%d = var%d", B, A)
	end

	Handlers.CLOSEUPVALS = function(Instruction)
		local A = Instruction.A

		return A, string_format("move_upvalues_to_heap(var%d->...)", A)
	end

	Handlers.GETTABLE = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C

		return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d[var%d]", A, B, C)
	end

	Handlers.SETTABLE = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C

		return string_format("%d, %d, %d", A, B, C), string_format("var%d[var%d] = var%d", B, C, A)
	end

	Handlers.GETTABLEKS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local K = Instruction.KTable[Aux + 1]
		local Name = KToStr(K)

		return string_format("%d, %d, %d [%d]", A, B, C, Aux), string_format("var%d = var%d[%s]", A, B, Name)
	end

	Handlers.SETTABLEKS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local K = Instruction.KTable[Aux + 1] or "Invalid"
		local Name = KToStr(K)

		return string_format("%d, %d, %d [%d]", A, B, C, Aux), string_format("var%d[%s] = var%d", B, Name, A)
	end

	Handlers.GETTABLEN = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C

		return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d[%d]", A, B, C + 1)
	end

	Handlers.SETTABLEN = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C

		return string_format("%d, %d, %d", A, B, C), string_format("var%d[%d] = var%d", B, C + 1, A)
	end

	Handlers.NEWCLOSURE = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx
		local ChildProto = Instruction.ChildProto
		local FuncName

		if ChildProto and ChildProto.Source and ChildProto.Source ~= _INV_SRC and #ChildProto.Source > 0 and #ChildProto.Source < 500 then
			FuncName = ChildProto.Source
		else
			local ProtoIndex = (ChildProto and ChildProto.ProtoIndex) or Bx
			FuncName = _ANON_FN .. ProtoIndex
		end

		return string_format("%d, %d", A, Bx), string_format("var%d = %s", A, FuncName)
	end

	Handlers.NAMECALL = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local K = Instruction.KTable[Aux + 1]
		local MethodName = KToStr(K)
		local Comment = string_format("var%d = var%d; var%d = var%d.%s -- Invokes __namecall", A + 1, B, A, B, MethodName)

		return string_format("%d, %d, %d [%d]", A, B, C, Aux), Comment
	end

	Handlers.GETUDATAKS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = bit32_band(Instruction.Aux or 0, 0xFFFF)
		local K = Instruction.KTable[Aux + 1]
		local Name = KToStr(K)
		return string_format("%d, %d, %d [%d]", A, B, C, Aux), string_format("var%d = var%d[%s]", A, B, Name)
	end
	Handlers.SETUDATAKS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = bit32_band(Instruction.Aux or 0, 0xFFFF)
		local K = Instruction.KTable[Aux + 1] or "Invalid"
		local Name = KToStr(K)
		return string_format("%d, %d, %d [%d]", A, B, C, Aux), string_format("var%d[%s] = var%d", B, Name, A)
	end
	Handlers.NAMECALLUDATA = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = bit32_band(Instruction.Aux or 0, 0xFFFF)
		local K = Instruction.KTable[Aux + 1]
		local MethodName = KToStr(K)
		local Comment = string_format("var%d = var%d; var%d = var%d.%s -- Invokes __namecall", A + 1, B, A, B, MethodName)
		return string_format("%d, %d, %d [%d]", A, B, C, Aux), Comment
	end

	Handlers.NEWCLASSMEMBER = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local Aux = Instruction.Aux or 0
		local K = Instruction.KTable[Aux + 1]
		return string_format("%d, %d, %d [%d]", A, Instruction.B, C, Aux),
			string_format("var%d[%s] = class member", A, KToStr(K))
	end

	Handlers.CALLFB = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		return string_format("%d, %d, %d", A, B, C),
			string_format("var%d(...) -- CALL with feedback", A)
	end

	Handlers.CMPPROTO = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex
		return string_format("%d, %d", A, SBx),
			string_format("if var%d ~= prototype then goto [%d] end", A, CodeIndex + 1 + SBx)
	end

	Handlers.FASTPCALL = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local CodeIndex = Instruction.CodeIndex
		return string_format("%d, %d", A, C),
			string_format("-- fast protected call; fallback at [%d]", CodeIndex + 1 + C)
	end

	Handlers.NEWCLASS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux or 0
		local K = Instruction.KTable[Aux + 1]
		return string_format("%d, %d, %d [%d]", A, B, C, Aux),
			string_format("var%d = class(%s)", A, KToStr(K))
	end

	Handlers.CALL = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local ArgCount = B - 1
		local RetCount = C - 1
		local Args

		if B == 0 then
			Args = "var" .. (A + 1) .. "->(top)"
		elseif ArgCount == 0 then
			Args = ""
		elseif ArgCount == 1 then
			Args = "var" .. (A + 1)
		elseif ArgCount == 2 then
			Args = "var" .. (A + 1) .. ", var" .. (A + 2)
		elseif ArgCount == 3 then
			Args = "var" .. (A + 1) .. ", var" .. (A + 2) .. ", var" .. (A + 3)
		else
			local ArgList = table_create(ArgCount)
			for J = 1, ArgCount do ArgList[J] = "var" .. (A + J) end
			Args = table_concat(ArgList, ", ")
		end

		local Rets
		if C == 0 then
			Rets = "var" .. A .. "->(top)"
		elseif RetCount == 0 then
			Rets = ""
		elseif RetCount == 1 then
			Rets = "var" .. A
		elseif RetCount == 2 then
			Rets = "var" .. A .. ", var" .. (A + 1)
		elseif RetCount == 3 then
			Rets = "var" .. A .. ", var" .. (A + 1) .. ", var" .. (A + 2)
		else
			local RetList = table_create(RetCount)
			for J = 0, RetCount - 1 do RetList[J + 1] = "var" .. (A + J) end
			Rets = table_concat(RetList, ", ")
		end

		local CallStr = string_format("var%d(%s)", A, Args)
		if Rets ~= "" then CallStr = Rets .. " = " .. CallStr end
		return string_format("%d, %d, %d", A, B, C), CallStr
	end

	Handlers.RETURN = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local RetStr
		if B == 0 then
			RetStr = "return var" .. A .. "->(top)"
		elseif B == 1 then
			RetStr = "return"
		elseif B == 2 then
			RetStr = "return var" .. A
		elseif B == 3 then
			RetStr = "return var" .. A .. ", var" .. (A + 1)
		else
			local Rets = table_create(B - 1)
			for J = 0, B - 2 do Rets[J + 1] = "var" .. (A + J) end
			RetStr = "return " .. table_concat(Rets, ", ")
		end
		return string_format("%d, %d", A, B), RetStr
	end

		Handlers.JUMP = function(Instruction)
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex

		return SBx, string_format("-- goto [%d]", CodeIndex + 1 + SBx)
	end

	Handlers.JUMPBACK = function(Instruction)
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex

		return SBx, string_format("-- goto [%d] (likely while/repeat loop)", CodeIndex + 1 + SBx)
	end

	Handlers.JUMPX = function(Instruction)
		local SAx = Instruction.SAx
		local CodeIndex = Instruction.CodeIndex

		return SAx, string_format("-- goto [%d]", CodeIndex + 1 + SAx)
	end

	Handlers.FORNPREP = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx
		local CodeIndex = Instruction.CodeIndex
		local Comment = string_format("for var%d = var%d, var%d, var%d do -- If loop shouldn't start (var%d > var%d) then goto [%d]", A + 3, A + 2, A, A + 1, A + 2, A, CodeIndex + 1 + Bx)

		return string_format("%d, %d", A, Bx), Comment
	end

	Handlers.FORNLOOP = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex
		local Comment = string_format("var%d += var%d; if var%d <= var%d then goto [%d] end", A + 2, A + 1, A + 2, A, CodeIndex + 1 + SBx)

		return string_format("%d, %d", A, SBx), Comment
	end

	Handlers.FORGPREP = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex
		local Comment = string_format("for var%d->... in var%d, var%d, var%d do -- If loop shouldn't start then goto [%d]", A + 3, A, A + 1, A + 2, CodeIndex + 1 + SBx)

		return string_format("%d, %d", A, SBx), Comment
	end

	Handlers.FORGPREP_INEXT = Handlers.FORGPREP
	Handlers.FORGPREP_NEXT = Handlers.FORGPREP
	Handlers.FORGLOOP = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local Aux = Instruction.Aux or 0
		local CodeIndex = Instruction.CodeIndex
		local C = bit32_band(Aux, 0xFF)
		local ReturnVarsStr
		if C == 0 then
			ReturnVarsStr = ""
		elseif C == 1 then
			ReturnVarsStr = "var" .. (A + 3)
		elseif C == 2 then
			ReturnVarsStr = "var" .. (A + 3) .. ", var" .. (A + 4)
		else
			local Rets = table_create(C)
			for J = 0, C - 1 do Rets[J + 1] = "var" .. (A + 3 + J) end
			ReturnVarsStr = table_concat(Rets, ", ")
		end
		return string_format("%d, %d [0x%08X]", A, SBx, Aux),
		       string_format("%s = var%d(var%d, var%d); if var%d ~= nil then goto [%d] end",
		                     ReturnVarsStr, A, A+1, A+2, A+3, CodeIndex + 1 + SBx)
	end

	Handlers.MINUS = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("var%d = -var%d", A, B)
	end

	Handlers.LENGTH = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("var%d = #var%d", A, B)
	end

	Handlers.NEWTABLE = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local Aux = Instruction.Aux or 0
		local Comment

		if Aux == 0 then
			Comment = "{}"
		else
			Comment = "table.create(" .. Aux .. ")"
		end

		return string_format("%d, %d [%d]", A, B, Aux), string_format("var%d = %s", A, Comment)
	end

	Handlers.DUPTABLE = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx

		return string_format("%d, %d", A, Bx), string_format("var%d = {} -- from template %d", A, Bx)
	end

	Handlers.SETLIST = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local Count = C - 1
		local StartIndex = Aux
		local EndIndex = StartIndex + Count - 1
		local SourceVars = {}

		for J = 1, Count do
			SourceVars[#SourceVars+1] = "var" .. (B + J - 1)
		end

		local Comment = string_format("var%d[%d->%d] = %s", A, StartIndex, EndIndex, table_concat(SourceVars, "->"))

		return string_format("%d, %d, %d [%d]", A, B, C, Aux), Comment
	end

	Handlers.CONCAT = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C

		return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d .. var%d", A, B, C)
	end

	Handlers.NOT = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B

		return string_format("%d, %d", A, B), string_format("var%d = not var%d", A, B)
	end

	Handlers.DUPCLOSURE = function(Instruction)
		local A = Instruction.A
		local Bx = Instruction.Bx
		local K = Instruction.KTable[Bx + 1]
		local ProtoIndex = K.Value
		local TargetProtoData

		if Instruction.AllProtos then
			TargetProtoData = Instruction.AllProtos[ProtoIndex + 1]
		end

		local FuncName

		if TargetProtoData and TargetProtoData.RawProto.Source and TargetProtoData.RawProto.Source ~= _INV_SRC and #TargetProtoData.RawProto.Source < 500 then
			FuncName = TargetProtoData.RawProto.Source
		else
			FuncName = _ANON_FN .. ProtoIndex
		end

		return string_format("%d, %d", A, Bx), string_format("var%d = %s", A, FuncName)
	end

	Handlers.GETIMPORT = function(Instruction)
		local A   = Instruction.A
		local Bx  = Instruction.Bx
		local Aux = Instruction.Aux or 0
		local KT  = Instruction.KTable
		local ImportKonstant = KT[Bx + 1]

		if not ImportKonstant or ImportKonstant.Type ~= 4 then
			return string_format("%d, %d", A, Bx), string_format("var%d = --[[ Invalid Import Constant at K%d ]]", A, Bx)
		end

		local ImportId = ImportKonstant.Value
		local Count    = bit32_rshift(ImportId, 30)
		local ImportedPath

		if Count == 1 then
			local k1 = KT[bit32_band(bit32_rshift(ImportId, 20), 1023) + 1]
			ImportedPath = (k1 and k1.Type == 3 and k1.Value) or _INV_PART
		elseif Count == 2 then
			local k1 = KT[bit32_band(bit32_rshift(ImportId, 20), 1023) + 1]
			local k2 = KT[bit32_band(bit32_rshift(ImportId, 10), 1023) + 1]
			local p1 = (k1 and k1.Type == 3 and k1.Value) or _INV_PART
			local p2 = (k2 and k2.Type == 3 and k2.Value) or _INV_PART
			ImportedPath = p1 .. "." .. p2
		elseif Count == 3 then
			local k1 = KT[bit32_band(bit32_rshift(ImportId, 20), 1023) + 1]
			local k2 = KT[bit32_band(bit32_rshift(ImportId, 10), 1023) + 1]
			local k3 = KT[bit32_band(ImportId, 1023) + 1]
			local p1 = (k1 and k1.Type == 3 and k1.Value) or _INV_PART
			local p2 = (k2 and k2.Type == 3 and k2.Value) or _INV_PART
			local p3 = (k3 and k3.Type == 3 and k3.Value) or _INV_PART
			ImportedPath = p1 .. "." .. p2 .. "." .. p3
		else
			ImportedPath = "unknown_import"
		end

		return string_format("%d, %d [0x%X]", A, Bx, Aux), string_format("var%d = %s", A, ImportedPath)
	end

	local _CaptureTypes = { [0] = "Readable", [1] = "Readable and writable", [2] = "Upvalue" }
	Handlers.CAPTURE = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local UpvalIndex = Instruction.UpvalIndex
		return string_format("%d, %d", A, B), string_format("up%d = var%d -- %s", UpvalIndex, B, _CaptureTypes[A] or "UNKNOWN")
	end

	local function MakeJumpHandler(Op, Sym, NotOp)
		return function(Instruction)
			local A = Instruction.A
			local C = Instruction.C
			local AuxIsK = Instruction.AuxIsK
			local Proto = Instruction.Proto
			local CodeIndex = Instruction.CodeIndex
			local SBx = Instruction.SBx
			local KStr = AuxIsK and KToStr(Proto.KTable[C + 1]) or ("var" .. C)
			local Condition = string_format("var%d %s %s", A, Sym, KStr)

			if NotOp then Condition = "not (" .. Condition .. ")" end

			local Comment = string_format("if %s then goto [%d] end", Condition, CodeIndex + 1 + SBx)

			return string_format("%d, %d [%d]", A, C, Instruction.Aux), Comment
		end
	end

	local JumpOps = { EQ = "==", LE = "<=", LT = "<" }

	for Op, Sym in pairs(JumpOps) do
		Handlers["JUMPIF" .. Op] = MakeJumpHandler(Op, Sym, false)
		Handlers["JUMPIFNOT" .. Op] = MakeJumpHandler(Op, Sym, true)
	end

	Handlers["JUMPIFEQ"] = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local Aux = Instruction.Aux
		local CodeIndex = Instruction.CodeIndex
		local SBx = Instruction.SBx

		return string_format("%d, %d [%d]", A, C, Aux), string_format("if var%d == var%d then goto [%d] end", A, C, CodeIndex + 1 + SBx)
	end

	Handlers["JUMPIFNOTEQ"] = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local Aux = Instruction.Aux
		local CodeIndex = Instruction.CodeIndex
		local SBx = Instruction.SBx

		return string_format("%d, %d [%d]", A, C, Aux), string_format("if var%d ~= var%d then goto [%d] end", A, C, CodeIndex + 1 + SBx)
	end

	Handlers["JUMPIF"] = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex

		return string_format("%d, %d", A, SBx), string_format("if var%d then goto [%d] end", A, CodeIndex + 1 + SBx)
	end

	Handlers["JUMPIFNOT"] = function(Instruction)
		local A = Instruction.A
		local SBx = Instruction.SBx
		local CodeIndex = Instruction.CodeIndex

		return string_format("%d, %d", A, SBx), string_format("if not var%d then goto [%d] end", A, CodeIndex + 1 + SBx)
	end

	local function MakeJUMPXEQKHandler(ConstType)
		return function(Instruction)
			local A = Instruction.A
			local C = Instruction.C
			local Aux = Instruction.Aux
			local SBx = Instruction.SBx
			local CodeIndex = Instruction.CodeIndex
			local IsNot = bit32_band(Aux, 0x80000000) ~= 0
			local OpSym = IsNot and "~=" or "=="
			local ConstData = bit32_band(Aux, 0x7FFFFFFF)
			local TargetPc = CodeIndex + 1 + SBx
			local ConstStr = "???"

			if ConstType == "NIL" then
				ConstStr = "nil"
			elseif ConstType == "B" then
				ConstStr = (ConstData == 1) and "true" or "false"
			elseif ConstType == "N" or ConstType == "S" then
				local K = Instruction.KTable[ConstData + 1]
				ConstStr = KToStr(K)
			end

			local OperandsStr = string_format("%d, %d [0x%08X]", A, C, Aux)
			local CommentStr = string_format("if var%d %s %s then goto [%d] end", A, OpSym, ConstStr, TargetPc)

			return OperandsStr, CommentStr
		end
	end

	Handlers["JUMPXEQKNIL"] = MakeJUMPXEQKHandler("NIL")
	Handlers["JUMPXEQKB"] = MakeJUMPXEQKHandler("B")
	Handlers["JUMPXEQKN"] = MakeJUMPXEQKHandler("N")
	Handlers["JUMPXEQKS"] = MakeJUMPXEQKHandler("S")

	local MathOps = { ADD = "+", SUB = "-", MUL = "*", DIV = "/", IDIV = "//", MOD = "%", POW = "^" }

	for Op, Sym in pairs(MathOps) do
		Handlers[Op] = function(Instruction)
			local A = Instruction.A
			local B = Instruction.B
			local C = Instruction.C

			return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d %s var%d", A, B, Sym, C)
		end

		Handlers[Op .. "K"] = function(Instruction)
			local A = Instruction.A
			local B = Instruction.B
			local C = Instruction.C
			local K = Instruction.KTable[C + 1]

			return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d %s %s", A, B, Sym, KToStr(K))
		end
	end

	Handlers["SUBRK"] = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local K = Instruction.KTable[B + 1]

		return string_format("%d, %d, %d", A, B, C), string_format("var%d = %s - var%d", A, KToStr(K), C)
	end

	Handlers["DIVRK"] = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local K = Instruction.KTable[B + 1]

		return string_format("%d, %d, %d", A, B, C), string_format("var%d = %s / var%d", A, KToStr(K), C)
	end

	local AndOrOps = {"AND", "OR"}

	for i = 1, #AndOrOps do
		local Op = AndOrOps[i]
		local Sym = string_lower(Op)

		Handlers[Op] = function(Instruction)
			local A = Instruction.A
			local B = Instruction.B
			local C = Instruction.C

			return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d %s var%d", A, B, Sym, C)
		end

		Handlers[Op .. "K"] = function(Instruction)
			local A = Instruction.A
			local B = Instruction.B
			local C = Instruction.C
			local K = Instruction.KTable[C + 1]

			return string_format("%d, %d, %d", A, B, C), string_format("var%d = var%d %s %s", A, B, Sym, KToStr(K))
		end
	end

	local function GetBuiltinName(Id)
		return BuiltInFunctionsMap[Id] or "unknown_function"
	end

	Handlers.FASTCALL = function(Instruction)
		local A = Instruction.A
		local C = Instruction.C
		local FuncName = GetBuiltinName(A)

		return string_format("%d, %d", A, C), string_format("... = %s(...)", FuncName)
	end

	Handlers.FASTCALL1 = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local FuncName = GetBuiltinName(A)

		return string_format("%d, %d, %d", A, B, C), string_format("... = %s(var%d)", FuncName, B)
	end

	Handlers.FASTCALL2 = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local FuncName = GetBuiltinName(A)
		local Arg2 = bit32_band(Aux, 0xFF)

		return string_format("%d, %d, %d [0x%X]", A, B, C, Aux), string_format("... = %s(var%d, var%d)", FuncName, B, Arg2)
	end

	Handlers.FASTCALL2K = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local Proto = Instruction.Proto
		local FuncName = GetBuiltinName(A)
		local K = Proto.KTable[Aux + 1]

		return string_format("%d, %d, %d [0x%X]", A, B, C, Aux), string_format("... = %s(var%d, %s)", FuncName, B, KToStr(K))
	end

	Handlers.FASTCALL3 = function(Instruction)
		local A = Instruction.A
		local B = Instruction.B
		local C = Instruction.C
		local Aux = Instruction.Aux
		local FuncName = GetBuiltinName(A)
		local Arg2 = bit32_band(Aux, 0xFF)
		local Arg3 = bit32_band(bit32_rshift(Aux, 8), 0xFF)

		return string_format("%d, %d, %d [0x%X]", A, B, C, Aux), string_format("... = %s(var%d, var%d, var%d)", FuncName, B, Arg2, Arg3)
	end

	OpcodeHandlerMaps[5] = Handlers
	OpcodeHandlerMaps[6] = Handlers
	OpcodeHandlerMaps[7] = Handlers
	OpcodeHandlerMaps[8] = Handlers
	OpcodeHandlerMaps[9] = Handlers
	OpcodeHandlerMaps[10] = Handlers
	OpcodeHandlerMaps[11] = Handlers
	OpcodeHandlerMaps[12] = Handlers
	OpcodeHandlerMaps[13] = Handlers
	OpcodeHandlerMaps[14] = Handlers
	OpcodeHandlerMaps[100] = Handlers
	OpcodeHandlerMaps[3] = Handlers
	OpcodeHandlerMaps[4] = Handlers
end

local ReadProto
local Deserialize

local Disassembler = {}

local function CreateEmptyProto()
	return {
		CodeTable = {},
		KTable = {},
		PTable = {},
		SmallLineInfo = {},
		LargeLineInfo = {},
		LineInfoCompKey = 0,
		Locals = {},
		UpvalNames = {},
	}
end

local Buf, Offset, CurrentBufferLen

local function NextByte()
	if Offset >= CurrentBufferLen then
		error("Attempted to read 1 byte at position " .. Offset .. ", buffer length " .. CurrentBufferLen)
	end
	local Value = buffer_readu8(Buf, Offset)
	Offset = Offset + 1
	return Value
end

local function NextUint32()
	if Offset + 3 >= CurrentBufferLen then
		error("Attempted to read 4 bytes at position " .. Offset)
	end
	local Value = buffer_readu32(Buf, Offset)
	Offset = Offset + 4
	return Value
end

local function NextInt()
	if Offset + 3 >= CurrentBufferLen then
		error("Attempted to read 4 bytes (int32) at position " .. Offset)
	end
	local Value = buffer_readi32(Buf, Offset)
	Offset = Offset + 4
	return Value
end

local function NextFloat()
	if Offset + 3 >= CurrentBufferLen then
		error("Attempted to read 4 bytes (float32) at position " .. Offset)
	end
	local Value = buffer_readf32(Buf, Offset)
	Offset = Offset + 4
	return Value
end

local function NextDouble()
	if Offset + 7 >= CurrentBufferLen then
		error("Attempted to read 8 bytes (float64) at position " .. Offset)
	end
	local Value = buffer_readf64(Buf, Offset)
	Offset = Offset + 8
	return Value
end

local function NextVarInt()
	local Result = 0
	local Shift  = 0
	while true do
		if Offset >= CurrentBufferLen then error("Truncated varint at " .. Offset) end
		local B = buffer_readu8(Buf, Offset)
		Offset = Offset + 1
		Result = bit32_bor(Result, bit32_lshift(bit32_band(B, 0x7F), Shift))
		if bit32_band(B, 0x80) == 0 then break end
		Shift = Shift + 7
	end
	return Result
end

local function NextVarInt64()
	local result = 0
	local mult   = 1
	while true do
		if Offset >= CurrentBufferLen then error("Truncated varint64 at " .. Offset) end
		local B = buffer_readu8(Buf, Offset)
		Offset = Offset + 1
		result = result + bit32_band(B, 0x7F) * mult
		if bit32_band(B, 0x80) == 0 then break end
		mult = mult * 128
	end
	return result
end

local function NextString()
	local Length = NextVarInt()
	if Length == 0 then return "" end
	if Offset + Length > CurrentBufferLen then
		error(("Attempted to read string of length %d at position %d"):format(Length, Offset))
	end
	local Result = buffer_readstring(Buf, Offset, Length)
	Offset = Offset + Length
	return Result
end

function Disassembler.ReadConstant(StringTable)
	local Type = NextByte()

	if Type == LbcConstantString then
		local Index = NextVarInt()
		return { Type = Type, Value = StringTable[Index] or "Invalid string index" }
	elseif Type == LbcConstantNumber then
		return { Type = Type, Value = NextDouble() }
	elseif Type == LbcConstantImport then
		return { Type = Type, Value = NextUint32() }
	elseif Type == LbcConstantBoolean then
		return { Type = Type, Value = NextByte() == 1 }
	elseif Type == LbcConstantTable then
		local SizeKey = NextVarInt()
		local Keys = table_create(SizeKey)

		for I = 1, SizeKey do
			Keys[I] = NextVarInt() + 1
		end

		return { Type = Type, Value = { Size = SizeKey, Ids = Keys } }
	elseif Type == LbcConstantClosure then
		return { Type = Type, Value = NextVarInt() }
	elseif Type == LbcConstantVector then
		local Vec = table_create(4)

		for I = 1, 4 do
			Vec[I] = NextFloat()
		end

		return { Type = Type, Value = Vec }
	elseif Type == LbcConstantVectorDouble then
		local Vec = table_create(4)

		for I = 1, 4 do
			Vec[I] = NextDouble()
		end

		return { Type = Type, Value = Vec }
	elseif Type == LbcConstantTableWithConstants then
		local SizeKey        = NextVarInt()
		local Keys           = table_create(SizeKey)
		local ConstantIndices = table_create(SizeKey)

		for I = 1, SizeKey do
			Keys[I]            = NextVarInt() + 1
			ConstantIndices[I] = NextInt()
		end

		return { Type = Type, Value = { Size = SizeKey, Ids = Keys, ConstantIndices = ConstantIndices } }
	elseif Type == LbcConstantInteger then
		local IsNeg    = NextByte() ~= 0
		local Magnitude = NextVarInt64()
		return { Type = Type, Value = IsNeg and -Magnitude or Magnitude }
	elseif Type == LbcConstantClassShape then
		local ClassName = NextVarInt()
		local PrivateFieldCount = NextByte()
		local PrivateMethodCount = NextByte()
		local PropertyCount = NextVarInt()
		local MethodCount = NextVarInt()
		local MemberCount = PropertyCount - PrivateFieldCount + MethodCount - PrivateMethodCount
		local Members = table_create(MemberCount)

		for I = 1, MemberCount do
			Members[I] = NextVarInt()
		end

		return {
			Type = Type,
			Value = {
				ClassName = ClassName,
				PrivateFieldCount = PrivateFieldCount,
				PrivateMethodCount = PrivateMethodCount,
				PropertyCount = PropertyCount,
				MethodCount = MethodCount,
				Members = Members,
			},
		}
	elseif Type ~= 0 then
		error("Unrecognized constant type: " .. tostring(Type))
	end

	return { Type = Type }
end

local function ReadProtoSource(StringTable)
	local ProtoSourceId = NextVarInt()

	return StringTable[ProtoSourceId] or _INV_SRC
end

local function ReadLineInfo(Proto)
	Proto.LineInfoCompKey = NextByte()

	local LineInterval = 2 ^ Proto.LineInfoCompKey
	local SizeCode2    = Proto.SizeCode
	local SmallLineInfo = table_create(SizeCode2)
	local LastOffset = 0

	if Offset + SizeCode2 > CurrentBufferLen then
		error("Truncated SmallLineInfo at " .. Offset)
	end
	for I = 1, SizeCode2 do
		LastOffset = bit32_band(LastOffset + buffer_readu8(Buf, Offset), 0xFF)
		Offset = Offset + 1
		SmallLineInfo[I] = LastOffset
	end

	local Intervals = math_floor((SizeCode2 - 1) / LineInterval) + 1
	local LargeLineInfo = table_create(Intervals)
	local LastLine = 0

	if Offset + Intervals * 4 > CurrentBufferLen then
		error("Truncated LargeLineInfo at " .. Offset)
	end
	for I = 1, Intervals do
		LastLine = LastLine + buffer_readi32(Buf, Offset)
		Offset = Offset + 4
		LargeLineInfo[I] = LastLine
	end

	Proto.InstructionLines = table_create(Proto.SizeCode)

	for Pc = 1, Proto.SizeCode do
		local IntervalIndex = math_floor((Pc - 1) / LineInterval) + 1
		Proto.InstructionLines[Pc] = LargeLineInfo[IntervalIndex] + SmallLineInfo[Pc]
	end
end

local function SkipLineInfo(Proto)
	Proto.LineInfoCompKey = NextByte()

	local LineInterval = 2 ^ Proto.LineInfoCompKey
	local SizeCode2    = Proto.SizeCode

	if Offset + SizeCode2 > CurrentBufferLen then
		error("Truncated SmallLineInfo at " .. Offset)
	end
	Offset = Offset + SizeCode2

	local Intervals = math_floor((SizeCode2 - 1) / LineInterval) + 1
	if Offset + Intervals * 4 > CurrentBufferLen then
		error("Truncated LargeLineInfo at " .. Offset)
	end
	Offset = Offset + Intervals * 4

	Proto.InstructionLines = nil
end

local function ReadProtoData(Proto, StringTable, ProtoTableRef, Version, Lean)
	local ProtoStartOffset
	local SerializedProtoSize
	if Version >= 12 then
		SerializedProtoSize = NextVarInt()
		ProtoStartOffset = Offset
		Proto.SerializedSize = SerializedProtoSize
	end

	Proto.MaxStackSize = NextByte()
	Proto.NumParams = NextByte()
	Proto.NumUpvalues = NextByte()
	Proto.IsVarArg = NextByte() ~= 0
Proto.Flags = 0
Proto.TypeInfo = {}

if Version >= 4 then
	Proto.Flags = NextByte()
	local TypeSize = NextVarInt()
	Proto.TypeInfo = TypeSize > 0 and table_create(TypeSize) or {}
	for I = 1, TypeSize do
		Proto.TypeInfo[I] = NextByte()
	end
	end

	Proto.SizeCode = NextVarInt()
	local SizeCode = Proto.SizeCode
	Proto.CodeTable = table_create(SizeCode)

	local needed = SizeCode * 4
	if Offset + needed > CurrentBufferLen then
		error("Truncated code table: need " .. needed .. " bytes at " .. Offset)
	end
	local ct = Proto.CodeTable
	for I = 1, SizeCode do
		ct[I] = buffer_readu32(Buf, Offset)
		Offset = Offset + 4
	end

	Proto.SizeConsts = NextVarInt()
	Proto.KTable = table_create(Proto.SizeConsts)

	for I = 1, Proto.SizeConsts do
		Proto.KTable[I] = Disassembler.ReadConstant(StringTable)
	end

	Proto.SizeProtos = NextVarInt()
	Proto.PTable = Proto.SizeProtos > 0 and table_create(Proto.SizeProtos) or {}

	for I = 1, Proto.SizeProtos do
		Proto.PTable[I] = ProtoTableRef[NextVarInt() + 1]
	end

	Proto.LineDefined = NextVarInt()
	Proto.Source = ReadProtoSource(StringTable)

	if NextByte() == 1 then
		if Lean then SkipLineInfo(Proto) else ReadLineInfo(Proto) end
	else
		Proto.InstructionLines = nil
	end

	if NextByte() == 1 then
		local SizeLocals = NextVarInt()
		local _locs = SizeLocals > 0 and table_create(SizeLocals) or {}
		Proto.Locals = _locs
		for i = 1, SizeLocals do
			_locs[i] = {
				Name = StringTable[NextVarInt()] or "invalid_local_name",
				StartPC = NextVarInt(),
				EndPC = NextVarInt(),
				Register = NextByte(),
			}
		end
		local SizeUpvals = NextVarInt()
		local _upvs = SizeUpvals > 0 and table_create(SizeUpvals) or {}
		Proto.UpvalNames = _upvs
		for i = 1, SizeUpvals do
			_upvs[i] = StringTable[NextVarInt()] or "invalid_upval_name"
		end
	end

	if Version >= 11 then
		local FeedbackSize = NextVarInt()
		Proto.Feedback = FeedbackSize > 0 and table_create(FeedbackSize) or {}
		for I = 1, FeedbackSize do
			Proto.Feedback[I] = {
				Type = NextByte(),
				Pc = NextVarInt(),
			}
		end
	end

	if Version >= 12 and ProtoStartOffset then
		local ProtoEndOffset = ProtoStartOffset + SerializedProtoSize
		if ProtoEndOffset > CurrentBufferLen then
			error("Serialized proto exceeds bytecode buffer")
		end
		if Offset > ProtoEndOffset then
			error("Serialized proto was read past its size prefix")
		end
		Offset = ProtoEndOffset
	end
end

local _ValidTypesVersions = {[0]=true,[1]=true,[2]=true,[3]=true}

local function DeserializeInternal(Version, Lean)
	local TypesVersion = 0
	if Version >= 4 then
		TypesVersion = NextByte()
	end

	if not _ValidTypesVersions[TypesVersion] then
		error("Invalid types version (types version: " .. tostring(TypesVersion) .. ")")
	end

	local SizeStrings = NextVarInt()
	local StringTable = table_create(SizeStrings)

	for I = 1, SizeStrings do
		StringTable[I] = NextString()
	end

if TypesVersion == 3 then
		while NextByte() ~= 0 do end
	end

	local SizeProtos = NextVarInt()
	local ProtoTable = table_create(SizeProtos)

	for I = 1, SizeProtos do
		ProtoTable[I] = CreateEmptyProto()
		ProtoTable[I].ProtoIndex = I - 1
	end

	for I = 1, SizeProtos do
		ReadProtoData(ProtoTable[I], StringTable, ProtoTable, Version, Lean)
	end

	local MainProtoId = NextVarInt() + 1

	if MainProtoId > #ProtoTable then
		error("Index " .. MainProtoId .. " out of range for ProtoTable with length " .. #ProtoTable)
	end

	return ProtoTable[MainProtoId], ProtoTable, StringTable, Version, TypesVersion
end

Deserialize = function(InputBytecode, Lean)
	Buf = buffer_fromstring(InputBytecode)
	Offset = 0
	CurrentBufferLen = buffer_len(Buf)

	local Version = NextByte()

	if (Version >= LbcVersionMin and Version <= LbcVersionMax) or Version == LbcVersionClasses then
		return DeserializeInternal(Version, Lean)
	else
		return error("Unsupported bytecode version: " .. tostring(Version))
	end
end

local OPID, OP_UNSUP = {}, 0
do
	local names = {
		"MOVE", "LOADK", "CALL", "CALLFB", "LOADN", "GETIMPORT", "GETTABLEKS", "GETUDATAKS", "GETUPVAL", "LOADB",
		"SETTABLEKS", "SETUDATAKS", "GETGLOBAL", "SETGLOBAL", "RETURN", "CAPTURE", "SETTABLE", "GETTABLE", "NAMECALL",
		"NAMECALLUDATA", "GETTABLEN", "SETTABLEN", "SETUPVAL", "NEWTABLE", "DUPTABLE", "NEWCLOSURE", "DUPCLOSURE",
		"LOADNIL", "LOADKX", "CLOSEUPVALS", "GETVARARGS", "SETLIST", "CONCAT", "NOT", "MINUS", "LENGTH", "AND", "OR",
		"ANDK", "ORK",
		"ADD", "SUB", "MUL", "DIV", "MOD", "POW", "IDIV", "ADDK", "SUBK", "MULK", "DIVK", "MODK", "POWK", "IDIVK",
		"SUBRK", "DIVRK",
		"JUMP", "JUMPBACK", "JUMPX", "JUMPIF", "JUMPIFNOT", "JUMPIFEQ", "JUMPIFNOTEQ", "JUMPIFLE", "JUMPIFNOTLE",
		"JUMPIFLT", "JUMPIFNOTLT", "JUMPXEQKNIL", "JUMPXEQKB", "JUMPXEQKN", "JUMPXEQKS",
		"FORNPREP", "FORNLOOP", "FORGPREP", "FORGPREP_NEXT", "FORGPREP_INEXT", "FORGLOOP",
		"FASTCALL", "FASTCALL1", "FASTCALL2", "FASTCALL2K", "FASTCALL3", "FASTPCALL",
		"NOP", "BREAK", "COVERAGE", "PREPVARARGS", "CMPPROTO", "NATIVECALL",
	}
	for id = 1, #names do OPID[names[id]] = id end
	OP_UNSUP = #names + 1
end

local OpLowCache = {}
local function GetOpLow(LuauVersion, IsFromRoblox)
	local key = IsFromRoblox and (LuauVersion + 1000) or LuauVersion
	local c = OpLowCache[key]
	if c then return c[1], c[2], c[3] end
	local Map = OpInfoMaps[LuauVersion]
	local names, aux, ids = table_create(256), table_create(256, false), table_create(256)
	for low = 0, 255 do
		local num = IsFromRoblox and low or ((low * 227) % 256)
		local Info = Map[num]
		local name = Info and Info.Name or "UNKNOWN"
		names[low + 1] = name
		ids[low + 1] = OPID[name] or OP_UNSUP
		aux[low + 1] = (Info and Info.Aux) and true or false
	end
	OpLowCache[key] = { names, aux, ids }
	return names, aux, ids
end

local function BuildInstructionRecords(P)
	local Lines = P.RawProto.InstructionLines
	local Count = P.OpCount
	local out = table_create(Count)
	local names, pcs, words, auxs = P.OpNames, P.OpPcs, P.OpWords, P.OpAux
	local IsFromRoblox = P.FromRoblox
	for i = 1, Count do
		local raw = words[i]
		local pc = pcs[i]
		local OpcodeNum = IsFromRoblox and bit32_band(raw, 0xFF) or bit32_band(raw * 227, 0xFF)
		local Bx_v = bit32_rshift(raw, 16)
		local Rec = {
			Name   = names[i],
			Opcode = OpcodeNum,
			A      = bit32_band(bit32_rshift(raw, 8),  0xFF),
			B      = bit32_band(bit32_rshift(raw, 16), 0xFF),
			C      = bit32_band(bit32_rshift(raw, 24), 0xFF),
			Bx     = Bx_v,
			SBx    = Bx_v >= 0x8000 and Bx_v - 0x10000 or Bx_v,
			SAx    = bit32_rshift(raw, 8),
			Line   = Lines and Lines[pc] or -1,
			Pc     = pc,
		}
		local Aux = auxs[i]
		if Aux ~= nil then Rec.Aux = Aux end
		out[i] = Rec
	end
	return out
end

ReadProto = function(Proto, Depth, ProtoTable, StringTable, LuauVersion, IsFromRoblox, Cache)
	if Cache then
		local Hit = Cache[Proto]
		if Hit then return Hit end
	end
	if not OpInfoMaps[LuauVersion] then
		error("Unsupported Luau version for disassembly: " .. tostring(LuauVersion))
	end

	local ProtoIndex = Proto.ProtoIndex

	local names, auxFlags, idsByLow = GetOpLow(LuauVersion, IsFromRoblox)
	local CodeTable = Proto.CodeTable
	local CodeTableLen = #CodeTable
	local OpNames, OpPcs, OpWords = table_create(CodeTableLen), table_create(CodeTableLen), table_create(CodeTableLen)
	local OpAux, OpIds = table_create(CodeTableLen), table_create(CodeTableLen)
	local Count = 0
	local CurrentPc = 1
	while CurrentPc <= CodeTableLen do
		local raw = CodeTable[CurrentPc]
		local low = raw % 256 + 1
		Count = Count + 1
		OpNames[Count] = names[low]
		OpIds[Count] = idsByLow[low]
		OpPcs[Count] = CurrentPc
		OpWords[Count] = raw
		if auxFlags[low] then
			CurrentPc = CurrentPc + 1
			OpAux[Count] = CurrentPc <= CodeTableLen and CodeTable[CurrentPc] or "Missing AUX value"
		end
		CurrentPc = CurrentPc + 1
	end

	local ProtoOutput = {
		ProtoIndex = ProtoIndex,
		Flags = Proto.Flags,
		LineDefined = Proto.LineDefined,
		Source = Proto.Source,
		NumParams = Proto.NumParams,
		IsVarArg = Proto.IsVarArg,
		MaxStackSize = Proto.MaxStackSize,
		Constants = Proto.KTable,
		Protos = {},
		RawProto = Proto,
		OpNames = OpNames,
		OpIds = OpIds,
		OpPcs = OpPcs,
		OpWords = OpWords,
		OpAux = OpAux,
		OpCount = Count,
		FromRoblox = IsFromRoblox,
	}
	if Cache then Cache[Proto] = ProtoOutput end

	local PTable = Proto.PTable
	local PTableLen = #PTable
	local ProtoOut = ProtoOutput.Protos
	for i = 1, PTableLen do
		ProtoOut[i] = ReadProto(PTable[i], Depth + 1, ProtoTable, StringTable, LuauVersion, IsFromRoblox, Cache)
	end

	return ProtoOutput
end

local function isSimpleMetadataName(name)
return type(name) == "string" and name:match("^[%a_][%w_]*$") ~= nil
end

local function BuildNativeFunctionNames(NativeProtoIndices, MainProto, ProtoTable, DisassembledProtos)
local parentNames = {}
if #NativeProtoIndices > 0 then
for _, Parent in ipairs(DisassembledProtos or {}) do
local Raw = Parent.RawProto
local OpNames, OpWords, OpPcs = Parent.OpNames, Parent.OpWords, Parent.OpPcs
for ii = 1, Parent.OpCount do
local Name = OpNames[ii]
local Word = OpWords[ii]
local ChildIndex
if Name == "NEWCLOSURE" then
local Child = Raw.PTable and Raw.PTable[(Word // 65536) + 1]
ChildIndex = Child and Child.ProtoIndex
elseif Name == "DUPCLOSURE" then
local Constant = Raw.KTable and Raw.KTable[(Word // 65536) + 1]
if Constant and Constant.Type == LbcConstantClosure then
ChildIndex = Constant.Value
end
end
if ChildIndex ~= nil and Raw.Locals then
local InstrA, InstrPc = (Word // 256) % 256, OpPcs[ii]
for i = #Raw.Locals, 1, -1 do
local Local = Raw.Locals[i]
if Local.Register == InstrA
and Local.StartPC <= InstrPc and InstrPc <= Local.EndPC
and isSimpleMetadataName(Local.Name) then
parentNames[ChildIndex] = {
Name = Local.Name,
NameSource = "parent debug local",
ParentProtoIndex = Parent.ProtoIndex,
}
break
end
end
end
end
end
end

local Names = {}
for _, ProtoIndex in ipairs(NativeProtoIndices) do
local Proto = ProtoTable[ProtoIndex + 1]
local Name, NameSource, ParentProtoIndex
if Proto and isSimpleMetadataName(Proto.Source) then
Name, NameSource = Proto.Source, "prototype source name"
elseif parentNames[ProtoIndex] then
local ParentName = parentNames[ProtoIndex]
Name, NameSource = ParentName.Name, ParentName.NameSource
ParentProtoIndex = ParentName.ParentProtoIndex
elseif Proto and Proto == MainProto then
Name, NameSource = "main", "main prototype"
else
Name, NameSource = "anonymous_function_" .. tostring(ProtoIndex), "fallback"
end
Names[#Names + 1] = {
ProtoIndex = ProtoIndex,
FunctionName = Name,
NameSource = NameSource,
ParentProtoIndex = ParentProtoIndex,
}
end
return Names
end

local function BuildNativeInfo(MainProto, ProtoTable, LuauVersion, DisassembledProtos)
local LPF_NATIVE_MODULE = 1
local LPF_NATIVE_COLD = 2
local LPF_NATIVE_FUNCTION = 4
local LPF_INLINABLE = 8
local FlagsAvailable = LuauVersion >= 4
local IsNativeModule, HasNativeFunction
local NativeFunctionProtoIndices, NativeColdProtoIndices, InlinableProtoIndices = {}, {}, {}
if FlagsAvailable then
local MainFlags = MainProto and MainProto.Flags or 0
IsNativeModule = bit32_band(MainFlags, LPF_NATIVE_MODULE) ~= 0
HasNativeFunction = bit32_band(MainFlags, LPF_NATIVE_FUNCTION) ~= 0
for i = 1, #ProtoTable do
local Proto = ProtoTable[i]
local Flags = Proto.Flags or 0
if bit32_band(Flags, LPF_NATIVE_FUNCTION) ~= 0 then
NativeFunctionProtoIndices[#NativeFunctionProtoIndices + 1] = Proto.ProtoIndex
HasNativeFunction = true
end
if bit32_band(Flags, LPF_NATIVE_COLD) ~= 0 then
NativeColdProtoIndices[#NativeColdProtoIndices + 1] = Proto.ProtoIndex
end
if bit32_band(Flags, LPF_INLINABLE) ~= 0 then
InlinableProtoIndices[#InlinableProtoIndices + 1] = Proto.ProtoIndex
end
end
end
return {
BytecodeVersion = LuauVersion,
FlagsAvailable = FlagsAvailable,
IsNativeModule = IsNativeModule,
HasNativeFunction = HasNativeFunction,
NativeFunctionProtoIndices = NativeFunctionProtoIndices,
NativeFunctionProtoNames = BuildNativeFunctionNames(NativeFunctionProtoIndices, MainProto, ProtoTable, DisassembledProtos),
NativeColdProtoIndices = NativeColdProtoIndices,
InlinableProtoIndices = InlinableProtoIndices,
RuntimeNativeCodeStatus = "not encoded in bytecode flags",
}
end

local OptimizationDefaultLevel = 2

local OptimizationOpEvidence = {
	GETIMPORT = "GETIMPORT",
	DUPCLOSURE = "DUPCLOSURE",
	FASTCALL = "FASTCALL", FASTCALL1 = "FASTCALL", FASTCALL2 = "FASTCALL",
	FASTCALL2K = "FASTCALL", FASTCALL3 = "FASTCALL",
	FORGPREP_NEXT = "FORGPREP_NEXT",
	FORGPREP_INEXT = "FORGPREP_INEXT",
	ADDK = "ConstantOperand", SUBK = "ConstantOperand", MULK = "ConstantOperand",
	DIVK = "ConstantOperand", MODK = "ConstantOperand", POWK = "ConstantOperand",
	IDIVK = "ConstantOperand", SUBRK = "ConstantOperand", DIVRK = "ConstantOperand",
	ANDK = "ConstantOperand", ORK = "ConstantOperand",
	JUMPXEQKNIL = "JUMPXEQK", JUMPXEQKB = "JUMPXEQK",
	JUMPXEQKN = "JUMPXEQK", JUMPXEQKS = "JUMPXEQK",
}

local OptimizationJumpOps = {
	JUMP = true, JUMPBACK = true, JUMPIF = true, JUMPIFNOT = true,
	JUMPIFEQ = true, JUMPIFLE = true, JUMPIFLT = true,
	JUMPIFNOTEQ = true, JUMPIFNOTLE = true, JUMPIFNOTLT = true,
	JUMPXEQKNIL = true, JUMPXEQKB = true, JUMPXEQKN = true, JUMPXEQKS = true,
	FORNPREP = true, FORNLOOP = true, FORGPREP = true,
	FORGPREP_NEXT = true, FORGPREP_INEXT = true, FORGLOOP = true,
}

local OptimizationFoldedJumpOps = {
	JUMP = true, JUMPIF = true, JUMPIFNOT = true,
	JUMPIFEQ = true, JUMPIFLE = true, JUMPIFLT = true,
	JUMPIFNOTEQ = true, JUMPIFNOTLE = true, JUMPIFNOTLT = true,
	JUMPXEQKNIL = true, JUMPXEQKB = true, JUMPXEQKN = true, JUMPXEQKS = true,
}

local FoldableBuiltinArity = {
	["math.abs"] = {1, 1}, ["math.acos"] = {1, 1}, ["math.asin"] = {1, 1},
	["math.atan"] = {1, 1}, ["math.ceil"] = {1, 1}, ["math.cosh"] = {1, 1},
	["math.cos"] = {1, 1}, ["math.deg"] = {1, 1}, ["math.exp"] = {1, 1},
	["math.floor"] = {1, 1}, ["math.log10"] = {1, 1}, ["math.rad"] = {1, 1},
	["math.sinh"] = {1, 1}, ["math.sin"] = {1, 1}, ["math.sqrt"] = {1, 1},
	["math.tanh"] = {1, 1}, ["math.tan"] = {1, 1}, ["math.sign"] = {1, 1},
	["math.round"] = {1, 1}, ["math.isnan"] = {1, 1}, ["math.isinf"] = {1, 1},
	["math.isfinite"] = {1, 1},
	["math.atan2"] = {2, 2}, ["math.fmod"] = {2, 2}, ["math.pow"] = {2, 2},
	["math.log"] = {1, 2},
	["math.max"] = {1, 3}, ["math.min"] = {1, 3},
	["vector"] = {2, 3},
}

local FoldedMathConstants = { pi = true, huge = true }

local function OptimizationLoadsNumber(Proto, Constants, Index, Register)
	local Name = Proto.OpNames[Index]
	if not Name then
		return false
	end
	local Word = Proto.OpWords[Index]
	if (Word // 256) % 256 ~= Register then
		return false
	end
	if Name == "LOADN" then
		return true
	end
	if Name == "LOADK" then
		local K = Constants[(Word // 65536) + 1]
		return K ~= nil and K.Type == LbcConstantNumber
	end
	return false
end

local function OptimizationFoldableCall(Proto, Constants, Index, IsJumpTarget)
	local OpNames, OpWords, OpPcs = Proto.OpNames, Proto.OpWords, Proto.OpPcs
	local Name = OpNames[Index]
	local Aux = Proto.OpAux[Index]
	local Word = OpWords[Index]
	local InstrA = (Word // 256) % 256
	local InstrB = (Word // 65536) % 256
	local Registers
	local ArgumentCount
	if Name == "FASTCALL1" then
		Registers = { InstrB }
		ArgumentCount = 1
	elseif type(Aux) ~= "number" then
		return nil
	elseif Name == "FASTCALL2" then
		Registers = { InstrB, bit32_band(Aux, 0xFF) }
		ArgumentCount = 2
	elseif Name == "FASTCALL2K" then
		local K = Constants[Aux + 1]
		if not (K and K.Type == LbcConstantNumber) then
			return nil
		end
		Registers = { InstrB }
		ArgumentCount = 2
	elseif Name == "FASTCALL3" then
		Registers = { InstrB, bit32_band(Aux, 0xFF), bit32_band(bit32_rshift(Aux, 8), 0xFF) }
		ArgumentCount = 3
	else
		return nil
	end

	local BuiltinName = BuiltInFunctionsMap[InstrA]
	local Arity = BuiltinName and FoldableBuiltinArity[BuiltinName]
	if not Arity or ArgumentCount < Arity[1] or ArgumentCount > Arity[2] then
		return nil
	end

	local First = Registers[1]
	local FallbackIndex = Index + 1
	if Name == "FASTCALL2K" then
		local ReloadName = OpNames[FallbackIndex]
		if not ReloadName or (ReloadName ~= "LOADK" and ReloadName ~= "LOADN")
			or (OpWords[FallbackIndex] // 256) % 256 ~= First + 1 then
			return nil
		end
		FallbackIndex = FallbackIndex + 1
	end
	local FallbackName = OpNames[FallbackIndex]
	if First < 1 or not FallbackName or (OpWords[FallbackIndex] // 256) % 256 ~= First - 1
		or IsJumpTarget[OpPcs[Index]] then
		return nil
	end
	for Position = 1, #Registers do
		if Registers[Position] ~= First + Position - 1 then
			return nil
		end
		local LoadIndex = Index - #Registers + Position - 1
		if not OptimizationLoadsNumber(Proto, Constants, LoadIndex, Registers[Position]) then
			return nil
		end
		if Position > 1 and IsJumpTarget[OpPcs[LoadIndex]] then
			return nil
		end
	end
	return BuiltinName
end

local function OptimizationReadTypeInfoHeader(Bytes)
	local Size = #Bytes
	if Size == 0 then
		return nil
	end
	local Position = 1
	local function ReadVarInt()
		local Result, Shift = 0, 0
		while true do
			local Byte = Bytes[Position]
			if Byte == nil then
				return nil
			end
			Position = Position + 1
			Result = bit32_bor(Result, bit32_lshift(bit32_band(Byte, 0x7F), Shift))
			if Byte < 0x80 then
				return Result
			end
			Shift = Shift + 7
			if Shift > 28 then
				return nil
			end
		end
	end
	local FunctionBytes = ReadVarInt()
	local UpvalueCount = FunctionBytes and ReadVarInt()
	local LocalCount = UpvalueCount and ReadVarInt()
	if not LocalCount or Position - 1 + FunctionBytes + UpvalueCount > Size then
		return nil
	end
	return FunctionBytes, UpvalueCount, LocalCount
end

local function OptimizationScanProto(Proto, Acc, TypesVersion)
	local OpNames, OpPcs, OpWords, OpAux = Proto.OpNames, Proto.OpPcs, Proto.OpWords, Proto.OpAux
	local Constants = Proto.Constants or {}
	local Count = Proto.OpCount

	for _, K in ipairs(Constants) do
		if K.Type == LbcConstantString then
			if K.Value == "getfenv" or K.Value == "setfenv" then
				Acc.FenvNamesPresent = true
			end
		elseif K.Type == LbcConstantVector or K.Type == LbcConstantVectorDouble then
			Acc.VectorConstants = Acc.VectorConstants + 1
		elseif K.Type == LbcConstantImport and type(K.Value) == "number" then
			if bit32_rshift(K.Value, 30) == 2 then
				local Root = Constants[bit32_band(bit32_rshift(K.Value, 20), 1023) + 1]
				local Member = Constants[bit32_band(bit32_rshift(K.Value, 10), 1023) + 1]
				if Root and Member and Root.Type == LbcConstantString and Member.Type == LbcConstantString
					and Root.Value == "math" and FoldedMathConstants[Member.Value] then
					Acc.UnfoldedMathConstants[Member.Value] = true
				end
			end
		end
	end

	local RawProto = Proto.RawProto
	if RawProto and TypesVersion and TypesVersion >= 3 then
		local FunctionBytes, UpvalueTypes = OptimizationReadTypeInfoHeader(RawProto.TypeInfo or {})
		if FunctionBytes and FunctionBytes > 0 then
			Acc.FunctionTypeProtos = Acc.FunctionTypeProtos + 1
		end
		if (RawProto.NumUpvalues or 0) > 0 then
			if UpvalueTypes and UpvalueTypes > 0 then
				Acc.UpvalueProtosTyped = Acc.UpvalueProtosTyped + 1
			else
				Acc.UpvalueProtosUntyped = Acc.UpvalueProtosUntyped + 1
			end
		end
	end

	local IndexByPc = table_create(Count > 0 and (OpPcs[Count] + 2) or 0)
	local IsJumpTarget, HasLongJump = {}, false
	for Index = 1, Count do
		local Name = OpNames[Index]
		local Pc = OpPcs[Index]
		IndexByPc[Pc] = Index
		if Name == "JUMPX" then
			HasLongJump = true
		end
		if OptimizationJumpOps[Name] then
			local Bx = OpWords[Index] // 65536
			IsJumpTarget[Pc + 1 + (Bx >= 0x8000 and Bx - 0x10000 or Bx)] = true
		end
	end
	if HasLongJump then
		Acc.LongJumpProtosSkipped = Acc.LongJumpProtosSkipped + 1
	end

	for Index = 1, Count do
		local Name = OpNames[Index]

		local Kind = OptimizationOpEvidence[Name]
		if Kind then
			Acc[Kind] = Acc[Kind] + 1
		end

		if Name == "GETGLOBAL" or Name == "SETGLOBAL" then
			local Aux = OpAux[Index]
			local K = type(Aux) == "number" and Constants[Aux + 1]
			if K and K.Type == LbcConstantString then
				if Name == "SETGLOBAL" then
					Acc.GlobalWrites[K.Value] = true
				elseif Aux < 1024 and #Constants < 32768 then
					Acc.GlobalReads[K.Value] = (Acc.GlobalReads[K.Value] or 0) + 1
				end
			end
		elseif Name == "MINUS" and Index > 1 and (OpWords[Index] // 65536) % 256 > (OpWords[Index] // 256) % 256
			and not IsJumpTarget[OpPcs[Index]]
			and OptimizationLoadsNumber(Proto, Constants, Index - 1, (OpWords[Index] // 65536) % 256) then
			Acc.NegatedLiteral = Acc.NegatedLiteral + 1
		elseif not HasLongJump and OptimizationFoldedJumpOps[Name] then
			local Bx = OpWords[Index] // 65536
			local TargetIndex = IndexByPc[OpPcs[Index] + 1 + (Bx >= 0x8000 and Bx - 0x10000 or Bx)]
			local TargetName = TargetIndex and OpNames[TargetIndex]
			if TargetName then
				if TargetName == "JUMP" and OpWords[TargetIndex] // 65536 < 0x8000 then
					Acc.UnfoldedJumpChains = Acc.UnfoldedJumpChains + 1
				elseif Name == "JUMP" and TargetName == "RETURN" then
					Acc.JumpToReturn = Acc.JumpToReturn + 1
				end
			end
		elseif Name == "FASTCALL1" or Name == "FASTCALL2" or Name == "FASTCALL2K" or Name == "FASTCALL3" then
			if not HasLongJump then
				local Folded = OptimizationFoldableCall(Proto, Constants, Index, IsJumpTarget)
				if Folded then
					Acc.SurvivingFoldableBuiltins[Folded] = (Acc.SurvivingFoldableBuiltins[Folded] or 0) + 1
				end
			end
		end
	end
end

local function OptimizationSortedKeys(Set)
	local Keys = {}
	for Key in pairs(Set) do
		Keys[#Keys + 1] = Key
	end
	table.sort(Keys)
	return Keys
end

local function OptimizationSafeNames(Names)
	local Safe = {}
	for Index, Name in ipairs(Names) do
		Safe[Index] = isSimpleMetadataName(Name) and Name or "?"
	end
	return Safe
end

local function OptimizationNameList(Names, Limit)
	Limit = Limit or 8
	if #Names <= Limit then
		return table.concat(Names, ", ")
	end
	return table.concat(Names, ", ", 1, Limit) .. string.format(", ... (+%d more)", #Names - Limit)
end

local function OptimizationCountText(Pairs)
	local Parts = {}
	for _, Pair in ipairs(Pairs) do
		if Pair[2] > 0 then
			Parts[#Parts + 1] = Pair[1] .. "=" .. tostring(Pair[2])
		end
	end
	return table.concat(Parts, ", ")
end

local function BuildOptimizationInfo(DisassembledProtos, LuauVersion, NativeInfo, TypesVersion)
	local Acc = {
		GETIMPORT = 0, DUPCLOSURE = 0, FASTCALL = 0,
		FORGPREP_NEXT = 0, FORGPREP_INEXT = 0,
		ConstantOperand = 0, JUMPXEQK = 0,
		UnfoldedJumpChains = 0, JumpToReturn = 0, NegatedLiteral = 0,
		VectorConstants = 0, FenvNamesPresent = false,
		FunctionTypeProtos = 0, UpvalueProtosTyped = 0, UpvalueProtosUntyped = 0,
		LongJumpProtosSkipped = 0,
		SurvivingFoldableBuiltins = {}, UnfoldedMathConstants = {},
		GlobalReads = {}, GlobalWrites = {},
	}
	for _, Proto in ipairs(DisassembledProtos or {}) do
		OptimizationScanProto(Proto, Acc, TypesVersion)
	end

	local UnwrittenGlobals = {}
	for Name in pairs(Acc.GlobalReads) do
		if not Acc.GlobalWrites[Name] then
			UnwrittenGlobals[Name] = true
		end
	end
	local UnwrittenNames = OptimizationSortedKeys(UnwrittenGlobals)
	local FoldableNames = OptimizationSortedKeys(Acc.SurvivingFoldableBuiltins)
	local FoldableTotal = 0
	for _, Count in pairs(Acc.SurvivingFoldableBuiltins) do
		FoldableTotal = FoldableTotal + Count
	end
	local MathConstantNames = OptimizationSortedKeys(Acc.UnfoldedMathConstants)

	local IsNativeModule = NativeInfo and NativeInfo.IsNativeModule == true
	local HasNativeFunction = NativeInfo and NativeInfo.HasNativeFunction == true

	local Reasons = {}
	local function AddReason(Constraint, Strength, Text)
		Reasons[#Reasons + 1] = { Constraint = Constraint, Strength = Strength, Text = Text }
	end

	local Lower, Upper = 0, OptimizationDefaultLevel

	if not Acc.FenvNamesPresent then
		if FoldableTotal > 0 then
			Upper = math.min(Upper, 1)
			AddReason("<=1", "proof", string.format(
				"constant-argument builtin call(s) still use FASTCALL (%s); level 2 folds them",
				OptimizationNameList(FoldableNames)))
		end
		if #MathConstantNames > 0 then
			Upper = math.min(Upper, 1)
			AddReason("<=1", "proof", "GETIMPORT math." .. table.concat(MathConstantNames, ", math.")
				.. " is not folded to a constant; level 2 folds library constants")
		end
	end

	if Acc.UnfoldedJumpChains > 0 or Acc.JumpToReturn > 0 then
		Upper = 0
		AddReason("==0", "proof", string.format(
			"unfolded jumps (%d jump-to-JUMP, %d JUMP-to-RETURN); foldJumps() only runs at level >= 1",
			Acc.UnfoldedJumpChains, Acc.JumpToReturn))
	end

	if #UnwrittenNames >= 2 then
		Upper = 0
		AddReason("==0", "proof", string.format(
			"GETGLOBAL of never-assigned globals (%s); level >= 1 imports them with GETIMPORT",
			OptimizationNameList(OptimizationSafeNames(UnwrittenNames))))
	end

	local LevelOneText = OptimizationCountText({
		{ "GETIMPORT", Acc.GETIMPORT }, { "DUPCLOSURE", Acc.DUPCLOSURE },
		{ "FASTCALL", Acc.FASTCALL }, { "FORGPREP_NEXT", Acc.FORGPREP_NEXT },
		{ "FORGPREP_INEXT", Acc.FORGPREP_INEXT },
		{ "ConstantOperand", Acc.ConstantOperand }, { "JUMPXEQK", Acc.JUMPXEQK },
	})
	if LevelOneText ~= "" then
		Lower = 1
		if Upper < OptimizationDefaultLevel then
			AddReason(">=1", "proof", LevelOneText .. " are emitted only when optimizationLevel >= 1")
		end
	end

	local DefaultFacts = {}
	if HasNativeFunction then
		Lower = OptimizationDefaultLevel
		DefaultFacts[#DefaultFacts + 1] = "@native function flag: the compiler forces level 2 after reading hot comments"
	end
	if Acc.FunctionTypeProtos > 0 and Acc.UpvalueProtosUntyped > 0 and Acc.UpvalueProtosTyped == 0 then
		Lower = OptimizationDefaultLevel
		DefaultFacts[#DefaultFacts + 1] = "function type info is present but no upvalue types are serialized"
			.. " (typeInfoLevel 0), so buildTypeMap only ran because level >= 2"
	end
	if Lower > Upper then
		for _, Fact in ipairs(DefaultFacts) do
			AddReason("==" .. tostring(OptimizationDefaultLevel), "proof", Fact)
		end
	end

	local StrongZero = Lower == 0 and (#UnwrittenNames == 1 or Acc.NegatedLiteral > 0)
	local StrongTwo = Upper == OptimizationDefaultLevel and (IsNativeModule or Acc.VectorConstants > 0)
	if StrongZero and #UnwrittenNames == 1 then
		AddReason("==0", "strong", "GETGLOBAL of never-assigned global "
			.. OptimizationSafeNames(UnwrittenNames)[1] .. "; level >= 1 would import it")
	end
	if StrongZero and Acc.NegatedLiteral > 0 then
		AddReason("==0", "strong", string.format(
			"%d negated numeric literal(s) left as LOAD + MINUS; level >= 1 folds them", Acc.NegatedLiteral))
	end
	if StrongZero and StrongTwo then
		if IsNativeModule then
			AddReason("note", "note", "--!native module flag implies level 2 unless a later --!optimize lowered it;"
				.. " that disagrees with the level-0 hint, so the default is kept")
		end
		if Acc.VectorConstants > 0 then
			AddReason("note", "note", string.format("%d vector constant(s) are a level 2 pass; that disagrees"
				.. " with the level-0 hint, so the default is kept", Acc.VectorConstants))
		end
	end
	if IsNativeModule and Upper < OptimizationDefaultLevel and Lower <= Upper then
		AddReason("note", "note", "--!native flag is present but the code was compiled at level "
			.. tostring(Upper) .. ", so a later --!optimize " .. tostring(Upper) .. " overrides it")
	end

	local Conflict = Lower > Upper
	local Exact, BestGuess, Confidence
	if not Conflict then
		if Lower == Upper then
			Exact, BestGuess, Confidence = Lower, Lower, "exact"
		elseif StrongZero and not StrongTwo then
			BestGuess, Confidence = 0, "high"
		elseif Upper < OptimizationDefaultLevel then
			BestGuess, Confidence = Upper, "medium"
		else
			BestGuess, Confidence = OptimizationDefaultLevel, "default"
		end
	else
		Confidence = "conflict"
	end

	local function NeededDirective(Level)
		if Level ~= OptimizationDefaultLevel then
			return "--!optimize " .. tostring(Level)
		end
		return nil
	end
	local Directive, GuessDirective
	if Exact ~= nil then
		Directive = NeededDirective(Exact)
	elseif BestGuess ~= nil and not Conflict then
		GuessDirective = NeededDirective(BestGuess)
	end

	return {
		BytecodeVersion = LuauVersion,
		InferenceAvailable = true,
		DefaultOptimizationLevel = OptimizationDefaultLevel,
		MinimumOptimizationLevel = Lower > 0 and Lower or nil,
		MaximumOptimizationLevel = Upper < OptimizationDefaultLevel and Upper or nil,
		ExactOptimizationLevel = Exact,
		BestGuessOptimizationLevel = BestGuess,
		Confidence = Confidence,
		Conflict = Conflict,
		Directive = Directive,
		GuessDirective = GuessDirective,
		Reasons = Reasons,
		Evidence = {
			FORGPREP_NEXT = Acc.FORGPREP_NEXT,
			FORGPREP_INEXT = Acc.FORGPREP_INEXT,
			GETIMPORT = Acc.GETIMPORT,
			DUPCLOSURE = Acc.DUPCLOSURE,
			FASTCALL = Acc.FASTCALL,
			ConstantOperand = Acc.ConstantOperand,
			JUMPXEQK = Acc.JUMPXEQK,
			UnfoldedJumpChains = Acc.UnfoldedJumpChains,
			JumpToReturn = Acc.JumpToReturn,
			NegatedLiteral = Acc.NegatedLiteral,
			UnwrittenGlobalNames = UnwrittenNames,
			SurvivingFoldableBuiltins = FoldableNames,
			UnfoldedMathConstants = MathConstantNames,
			VectorConstants = Acc.VectorConstants,
			FunctionTypeProtos = Acc.FunctionTypeProtos,
			UpvalueProtosTyped = Acc.UpvalueProtosTyped,
			UpvalueProtosUntyped = Acc.UpvalueProtosUntyped,
			FenvNamesPresent = Acc.FenvNamesPresent,
			LongJumpProtosSkipped = Acc.LongJumpProtosSkipped,
			IsNativeModule = IsNativeModule,
			HasNativeFunction = HasNativeFunction,
		},
		InferenceRule = "default level 2 unless compiler-gated code generation proves a lower level: see the rule list above the optimization scan",
	}
end

local function DisassembleCore(Bytecode, IsFromRoblox, Lean)
	if string_byte(Bytecode, 1) == 0 then
		local sourceOutput = {{
			type = "source",
			content = string_sub(Bytecode, 2),
		}}

		return sourceOutput, 0, -1, -1
	end

	local Ok, MainProto, ProtoTable, StringTable, LuauVersion, TypesVersion = pcall(Deserialize, Bytecode, Lean)

	if not Ok then
		error("Failed to deserialize bytecode: " .. tostring(MainProto))
	end

	local DisassembledProtos = table_create(#ProtoTable)
	local MainProtoData
	local ProtoTableLen = #ProtoTable
	local ReadCache = {}

	for i = 1, ProtoTableLen do
		local Proto = ProtoTable[i]
		local ProcessedProto = ReadProto(Proto, 1, ProtoTable, StringTable, LuauVersion, IsFromRoblox, ReadCache)
		DisassembledProtos[i] = ProcessedProto

		if Proto == MainProto then
			MainProtoData = ProcessedProto
		end
	end

	if not Lean then
		for i = 1, ProtoTableLen do
			local P = DisassembledProtos[i]
			P.Instructions = BuildInstructionRecords(P)
		end
	end

local NativeInfo = BuildNativeInfo(MainProto, ProtoTable, LuauVersion, DisassembledProtos)
local OptimizationInfo = BuildOptimizationInfo(DisassembledProtos, LuauVersion, NativeInfo, TypesVersion)
	return {
		MainProto = MainProtoData,
		Protos = DisassembledProtos,
		ProtoCount = #ProtoTable,
		LuauVersion = LuauVersion,
		TypesVersion = TypesVersion,
StringTable = StringTable,
NativeInfo = NativeInfo,
OptimizationInfo = OptimizationInfo,
	}
end

function Disassembler.Disassemble(Bytecode, IsFromRoblox)
	return DisassembleCore(Bytecode, IsFromRoblox, false)
end

function Disassembler.GetNativeInfo(Bytecode, IsFromRoblox)
assert(type(Bytecode) == "string",
"Disassembler.GetNativeInfo: expected string, got " .. type(Bytecode))
local Metadata = DisassembleCore(Bytecode, IsFromRoblox == true, true)
if Metadata.NativeInfo then return Metadata.NativeInfo end
return {
FlagsAvailable = false,
IsNativeModule = nil,
HasNativeFunction = nil,
NativeFunctionProtoIndices = {},
NativeFunctionProtoNames = {},
NativeColdProtoIndices = {},
InlinableProtoIndices = {},
RuntimeNativeCodeStatus = "not encoded in bytecode flags",
SourceOnlyInput = true,
}
end

function Disassembler.GetOptimizationInfo(Bytecode, IsFromRoblox)
	assert(type(Bytecode) == "string",
		"Disassembler.GetOptimizationInfo: expected string, got " .. type(Bytecode))
	local Metadata = DisassembleCore(Bytecode, IsFromRoblox == true, true)
	if type(Metadata) == "table" and Metadata.OptimizationInfo then
		return Metadata.OptimizationInfo
	end
	return {
		BytecodeVersion = nil,
		InferenceAvailable = false,
		DefaultOptimizationLevel = OptimizationDefaultLevel,
		MinimumOptimizationLevel = nil,
		ExactOptimizationLevel = nil,
		BestGuessOptimizationLevel = nil,
		Confidence = "none",
		Conflict = false,
		Reasons = {},
		Evidence = { FORGPREP_NEXT = 0, FORGPREP_INEXT = 0 },
		InferenceRule = "no instruction stream available",
		SourceOnlyInput = true,
	}
end

function Disassembler.FancyDisassemble(Bytecode, ShoveIntoOneString, IsFromRoblox)
	ShoveIntoOneString = ShoveIntoOneString or false
	local OutputParts = {}

	local function PrintOrConcat(Text)
		if ShoveIntoOneString then
			OutputParts[#OutputParts+1] = Text
		else
			print(Text)
		end
	end

	local StartBenchmark = os_clock()
	local Result = { pcall(Disassembler.Disassemble, Bytecode, IsFromRoblox) }
	local EndBenchmark = os_clock() - StartBenchmark

	if not Result[1] then
		PrintOrConcat("Disassembly failed: " .. tostring(Result[2]))

		if ShoveIntoOneString then
			return table_concat(OutputParts, "\n")
		end

		return
	end

	local Metadata = Result[2]
	local DisassembledProtos = Metadata.Protos
	local ProtosCount = Metadata.ProtoCount
	local LuauVersion = Metadata.LuauVersion
	local TypesVersion = Metadata.TypesVersion
	local StringTable = Metadata.StringTable

	PrintOrConcat("-- Disassembled with 0x1437's disassembler")
	PrintOrConcat("-- https://github.com/0x1437/Luau-Bytecode-Diassembler")
	PrintOrConcat("-- Inspired by @plusgiant5's Konstant Disassembler")
	PrintOrConcat("-- Disassembled on " .. os.date("%Y-%m-%d %H:%M:%S", os.time()))
	PrintOrConcat("-- Luau version " .. tostring(LuauVersion) .. ", Types version " .. tostring(TypesVersion))
if Metadata.NativeInfo and Metadata.NativeInfo.FlagsAvailable then
local NativeInfo = Metadata.NativeInfo
PrintOrConcat(string_format(
"-- Native flags: module --!native=%s, native function protos=%d, cold protos=%d (compiler metadata only)",
tostring(NativeInfo.IsNativeModule),
#NativeInfo.NativeFunctionProtoIndices,
#NativeInfo.NativeColdProtoIndices
))
else
PrintOrConcat("-- Native flags: unavailable in this bytecode version")
end
	PrintOrConcat("-- Time taken: " .. string_format("%.8fs", EndBenchmark))
	PrintOrConcat("")

	if ProtosCount == 0 and DisassembledProtos and #DisassembledProtos > 0 and DisassembledProtos[1].type == "source" then
		PrintOrConcat(DisassembledProtos[1].content)

		if ShoveIntoOneString then
			return table_concat(OutputParts, "\n")
		end

		return
	end

	if not DisassembledProtos then
		PrintOrConcat("Disassembly failed.")

		if ShoveIntoOneString then
			return table_concat(OutputParts, "\n")
		end

		return
	end

	local PrintedProtos = {}
	local function PrintProtoRecursive(ProtoData, Depth, IsMain, AllProtos)
		local TabSpace      = string_rep("    ", Depth)
		local RawProto      = ProtoData.RawProto
		local CodeTable     = RawProto.CodeTable
		local CodeTableLen  = #CodeTable
		local KTable        = RawProto.KTable
		local PTable        = RawProto.PTable
		local ProtoLines    = RawProto.InstructionLines
		local OpInfoMap_v   = OpInfoMaps[LuauVersion]
		local Handlers_v    = OpcodeHandlerMaps[LuauVersion]
		local InnerTabSpace = string_rep("    ", Depth + (IsMain and 0 or 1))

		if not IsMain then
			local FuncName
			if RawProto.Source and RawProto.Source ~= "Invalid source index" and #RawProto.Source > 0 and #RawProto.Source < 500 then
				FuncName = RawProto.Source
			else
				FuncName = "anonymous_function_" .. ProtoData.ProtoIndex
			end

			local ParamNames = table_create(ProtoData.NumParams)
			for i = 1, ProtoData.NumParams do ParamNames[i] = "var" .. (i - 1) end

			if RawProto.Locals then
				local locs = RawProto.Locals
				for i = 1, #locs do
					local L = locs[i]
					if L.StartPC == 0 and L.Register < ProtoData.NumParams then
						ParamNames[L.Register + 1] = L.Name
					end
				end
			end

			local Params = table_create(ProtoData.NumParams + (ProtoData.IsVarArg and 1 or 0))
			for i = 1, ProtoData.NumParams do Params[#Params+1] = ParamNames[i] end
			if ProtoData.IsVarArg then Params[#Params+1] = "..." end

			local Sig = FuncName .. "(" .. table_concat(Params, ", ") .. ")"
			if ProtoData.LineDefined > 0 then
				Sig = Sig .. string_format(" -- Line %d", ProtoData.LineDefined)
			end
			local InfoCmt = string_format("-- %d parameters, %d upvalues, %d constants, %d functions",
				RawProto.NumParams, RawProto.NumUpvalues, RawProto.SizeConsts, RawProto.SizeProtos)

			if not ShoveIntoOneString then
				print(TabSpace .. "")
				PrintOrConcat(TabSpace .. InfoCmt)
			else
				PrintOrConcat("\n" .. TabSpace .. InfoCmt)
			end
			PrintOrConcat(TabSpace .. "local function " .. Sig)
		end

		local JumpTargets = {}
		do
			local pc = 1
			while pc <= CodeTableLen do
				local instr = CodeTable[pc]
				local op    = OpInfoMap_v[IsFromRoblox and bit32_band(instr, 0xFF) or bit32_band(instr * 227, 0xFF)]
				if op then
					if op.Type:find("sBx") then
						local Bx  = bit32_rshift(instr, 16)
						local SBx = Bx >= 0x8000 and Bx - 0x10000 or Bx
						local tgt = pc + 1 + SBx
						JumpTargets[tgt] = (JumpTargets[tgt] or "") .. "::" .. pc .. "::, "
					elseif op.Name == "JUMPBACK" then
						local tgt = pc + 1 - bit32_rshift(instr, 16)
						JumpTargets[tgt] = (JumpTargets[tgt] or "") .. "::" .. pc .. "::, "
					end
					if op.Aux then pc = pc + 1 end
				end
				pc = pc + 1
			end
		end

		local IArgs = {
			Proto = RawProto,
			KTable = KTable,
			StringTable = StringTable,
			AllProtos = AllProtos,
		}

		local UpvalueCounter = 0
		local CurrentPc = 1

		while CurrentPc <= CodeTableLen do
			if JumpTargets[CurrentPc] then
				PrintOrConcat(InnerTabSpace .. JumpTargets[CurrentPc]:sub(1, -3))
			end

			local Instruction = CodeTable[CurrentPc]
			local OpcodeNum   = IsFromRoblox and bit32_band(Instruction, 0xFF) or bit32_band(Instruction * 227, 0xFF)
			local OpInfo      = OpInfoMap_v[OpcodeNum]
			local Opname      = OpInfo and OpInfo.Name or "UNKNOWN"

			local A   = bit32_band(bit32_rshift(Instruction, 8),  0xFF)
			local Bx  = bit32_rshift(Instruction, 16)
			local B   = bit32_band(Bx, 0xFF)
			local C   = bit32_band(bit32_rshift(Instruction, 24), 0xFF)
			local SBx = Bx >= 0x8000 and Bx - 0x10000 or Bx

			if Opname == "NEWCLOSURE" then
				local ChildProtoData = ProtoData.Protos[Bx + 1]
				if ChildProtoData and not PrintedProtos[ChildProtoData.ProtoIndex] then
					PrintedProtos[ChildProtoData.ProtoIndex] = true
					PrintProtoRecursive(ChildProtoData, Depth + (IsMain and 0 or 1), false, AllProtos)
				end
			elseif Opname == "DUPCLOSURE" then
				local K = KTable[Bx + 1]
				local pi = K and K.Value
				local tpd = pi and AllProtos[pi + 1]
				if tpd and not PrintedProtos[pi] then
					PrintedProtos[pi] = true
					PrintProtoRecursive(tpd, Depth + (IsMain and 0 or 1), false, AllProtos)
				end
			end

			IArgs.A          = A
			IArgs.B          = B
			IArgs.C          = C
			IArgs.Bx         = Bx
			IArgs.SBx        = SBx
			IArgs.SAx        = bit32_rshift(Instruction, 8)
			IArgs.CodeIndex  = CurrentPc - 1
			IArgs.Aux        = nil
			IArgs.UpvalIndex = nil
			IArgs.ChildProto = nil

			if Opname == "NEWCLOSURE" then
				IArgs.ChildProto = PTable[Bx + 1]
			end

			local InstrPc = CurrentPc
			if OpInfo and OpInfo.Aux then
				CurrentPc = CurrentPc + 1
				IArgs.Aux = CodeTable[CurrentPc]
			end

			local Handler = Handlers_v[Opname]
			local OperandsStr, CommentStr = "", ""
			if Handler then
				if Opname == "CAPTURE" then
					IArgs.UpvalIndex = UpvalueCounter
					UpvalueCounter = UpvalueCounter + 1
				end
				OperandsStr, CommentStr = Handler(IArgs)
			else
				CommentStr = "Unimplemented Opcode: " .. Opname
			end

			local OpAndOperands = (OperandsStr and OperandsStr ~= "")
				and (Opname .. " " .. tostring(OperandsStr))
				or  Opname
			local LineNumber = ProtoLines and ProtoLines[InstrPc] or "?"
			PrintOrConcat(string_format("%s[Line %s] [%d] [0x%08X]        %-40s; %s",
				InnerTabSpace, tostring(LineNumber), InstrPc - 1, Instruction,
				OpAndOperands, CommentStr))

			CurrentPc = CurrentPc + 1
		end

		if not IsMain then
			if not ShoveIntoOneString then
				PrintOrConcat(TabSpace .. "end")
				print(TabSpace .. "")
			else
				PrintOrConcat(TabSpace .. "end\n")
			end
		end
	end

	local MainProto
	local LastProtoIndex = #DisassembledProtos

	for i = 1, #DisassembledProtos do
		local Proto = DisassembledProtos[i]

		if Proto.ProtoIndex == LastProtoIndex - 1 then
			MainProto = Proto

			break
		end
	end

	if MainProto then
		PrintProtoRecursive(MainProto, 0, true, DisassembledProtos)
	end

	PrintOrConcat(string_format("[END OF DISASSEMBLY]"))

	if ShoveIntoOneString then
		return table_concat(OutputParts, "\n")
	end

	return nil
end

local function ReadVarIntStr(s, offset)
	local result, shift = 0, 0
	while true do
		local byte = string_byte(s, offset)
		offset = offset + 1
		result = bit32_bor(result, bit32_lshift(bit32_band(byte, 0x7F), shift))
		if bit32_band(byte, 0x80) == 0 then break end
		shift = shift + 7
	end
	return result, offset
end

local function TransformBytecodeOpcodes(bytecode, isEncoding)
	local src = buffer_fromstring(bytecode)
	local srcLen = buffer_len(src)
	local out = buffer.create(srcLen)
	buffer.copy(out, 0, src, 0, srcLen)

	local mult = isEncoding and 227 or 203

	local s = bytecode
	local offset = 1

	local function nextU8()
		local v = string_byte(s, offset)
		offset = offset + 1
		return v
	end

	local function skipN(n)
		offset = offset + n
	end

	local function nextVarInt()
		local v
		v, offset = ReadVarIntStr(s, offset)
		return v
	end

	local version = nextU8()
	if not ((version >= LbcVersionMin and version <= LbcVersionMax) or version == LbcVersionClasses) then
		error(string_format("TransformBytecodeOpcodes: unsupported bytecode version %d", version))
	end

local auxMap = {}
local versionOpTable = OpTableVersionMap[version]
for _, op in ipairs(versionOpTable) do
	if op.Aux then
		auxMap[(op.Number * 203) % 256] = true
	end
end

local typesVersion = 0
if version >= 4 then
	typesVersion = nextU8()
end

	local nStrings = nextVarInt()
	for _ = 1, nStrings do
		local slen = nextVarInt()
		if slen > 0 then skipN(slen) end
	end

if typesVersion == 3 then
		while nextU8() ~= 0 do end
	end

	local nProtos = nextVarInt()

	for _ = 1, nProtos do
		local protoEndOffset
		if version >= 12 then
			local protoSize = nextVarInt()
			protoEndOffset = offset + protoSize
		end

if version >= 4 then
	skipN(5)
	local typeInfoSize = nextVarInt()
	skipN(typeInfoSize)
else
	skipN(4)
end

		local sizeCode = nextVarInt()

		local codeStartBuf = offset - 1

		local skipNextAsAux = false

		for i = 0, sizeCode - 1 do
			local wBufOff = codeStartBuf + i * 4
			local instr = buffer_readu32(out, wBufOff)

			if skipNextAsAux then
				skipNextAsAux = false
			else
				local rawOp = bit32_band(instr, 0xFF)

				local seqOp
				if isEncoding then
					seqOp = rawOp
				else
					seqOp = (rawOp * 203) % 256
				end

				local newOp    = (rawOp * mult) % 256
				local newInstr = bit32_bor(bit32_band(instr, 0xFFFFFF00), newOp)
				buffer.writeu32(out, wBufOff, newInstr)

				if auxMap[seqOp] then
					skipNextAsAux = true
				end
			end
		end

		skipN(sizeCode * 4)

		local sizeConsts = nextVarInt()

		local skipConstant
		skipConstant = function()
			local kType = nextU8()
			if     kType == LbcConstantBoolean           then skipN(1)
			elseif kType == LbcConstantNumber            then skipN(8)
			elseif kType == LbcConstantString            then nextVarInt()
			elseif kType == LbcConstantImport            then skipN(4)
			elseif kType == LbcConstantTable             then
				local sz = nextVarInt()
				for _ = 1, sz do nextVarInt() end
			elseif kType == LbcConstantClosure           then nextVarInt()
			elseif kType == LbcConstantVector            then skipN(16)
			elseif kType == LbcConstantTableWithConstants then
				local sz = nextVarInt()
				for _ = 1, sz do
					nextVarInt()
					skipN(4)
				end
			elseif kType == LbcConstantInteger           then
				skipN(1)
				while bit32_band(nextU8(), 0x80) ~= 0 do end
			elseif kType == LbcConstantClassShape          then
				nextVarInt()
				local privateFields = nextU8()
				local privateMethods = nextU8()
				local properties = nextVarInt()
				local methods = nextVarInt()
				for _ = 1, properties - privateFields + methods - privateMethods do nextVarInt() end
			elseif kType == LbcConstantVectorDouble       then
				skipN(32)
			end
		end

		for _ = 1, sizeConsts do
			skipConstant()
		end

		local sizeProtoRefs = nextVarInt()
		for _ = 1, sizeProtoRefs do nextVarInt() end

		nextVarInt()
		nextVarInt()

		if nextU8() == 1 then
			local compKey      = nextU8()
			local lineInterval = 2 ^ compKey
			skipN(sizeCode)
			local intervals = math_floor((sizeCode - 1) / lineInterval) + 1
			skipN(intervals * 4)
		end

		if nextU8() == 1 then
			local nLocals = nextVarInt()
			for _ = 1, nLocals do
				nextVarInt()
				nextVarInt()
				nextVarInt()
				nextU8()
			end
			local nUpvals = nextVarInt()
			for _ = 1, nUpvals do nextVarInt() end
		end

if version >= 11 then
	local feedbackSize = nextVarInt()
	for _ = 1, feedbackSize do
		nextU8()
		nextVarInt()
	end
end

if protoEndOffset then
	if offset > protoEndOffset then
		error("TransformBytecodeOpcodes: proto data exceeds its size prefix")
	end
	offset = protoEndOffset
end
	end

	return buffer.tostring(out)
end

function Disassembler.Assemble(luauBytecode)
	assert(type(luauBytecode) == "string",
		"Disassembler.Assemble: expected string, got " .. type(luauBytecode))

	if string_byte(luauBytecode, 1) == 0 then
		return luauBytecode
	end

	local ok, result = pcall(TransformBytecodeOpcodes, luauBytecode, true)
	if not ok then
		error("Disassembler.Assemble failed: " .. tostring(result))
	end
	return result
end

function Disassembler.Decode(machineBytecode)
	assert(type(machineBytecode) == "string",
		"Disassembler.Decode: expected string, got " .. type(machineBytecode))

	if string_byte(machineBytecode, 1) == 0 then
		return machineBytecode
	end

	local ok, result = pcall(TransformBytecodeOpcodes, machineBytecode, false)
	if not ok then
		error("Disassembler.Decode failed: " .. tostring(result))
	end
	return result
end

function Disassembler.CompileLuau(source, options)
	assert(type(source) == "string",
		"Disassembler.CompileLuau: expected string, got " .. type(source))
	local bytecode = Disassembler.Compiler.compile(source, options)
	if string_byte(bytecode, 1) == 0 then
		error("Disassembler.CompileLuau: " .. string.sub(bytecode, 2), 0)
	end
	return bytecode
end

Disassembler.Compiler = (function()
local bor = bit32.bor
local Lexer = (function()
local Lexer = {}
Lexer.__index = Lexer

local KEYWORDS = {}
for w in ("and break do else elseif end false for function if in local nil not or repeat return then true until while"):gmatch("%a+") do
	KEYWORDS[w] = true
end

local function fail(line, msg)
	error(string.format(":%d: %s", line, msg), 0)
end

function Lexer.new(src)
	local self = setmetatable({}, Lexer)
	self.src = src
	self.pos = 1
	self.line = 1
	self.braceStack = {}
	self.hotcomments = {}
	self.sawCode = false
	self.queue = {}
	return self
end

local byte, sub, find = string.byte, string.sub, string.find

function Lexer:newline(p)
	local c = byte(self.src, p)
	if c == 13 and byte(self.src, p + 1) == 10 then
		self.line += 1
		return p + 2
	end
	self.line += 1
	return p + 1
end

function Lexer:skipLongBracket(p)
	local src = self.src
	local lvl = 0
	local q = p + 1
	while byte(src, q) == 61 do
		lvl += 1
		q += 1
	end
	if byte(src, q) ~= 91 then
		return nil
	end
	return lvl, q + 1
end

function Lexer:readLongString(p, lvl, startLine)
	local src = self.src
	local close = "]" .. string.rep("=", lvl) .. "]"
	local c = byte(src, p)
	if c == 13 then
		p = self:newline(p)
	elseif c == 10 then
		p = self:newline(p)
	end
	local out = {}
	while true do
		local e = find(src, close, p, true)
		local nl = find(src, "[\r\n]", p)
		if not e then
			fail(startLine, "unfinished long string")
		end
		if nl and nl < e then
			out[#out + 1] = sub(src, p, nl - 1)
			local np = self:newline(nl)
			out[#out + 1] = "\n"
			p = np
		else
			out[#out + 1] = sub(src, p, e - 1)
			return table.concat(out), e + #close
		end
	end
end

local ESC = { n = "\n", t = "\t", r = "\r", a = "\a", b = "\b", f = "\f", v = "\v", ["\\"] = "\\", ['"'] = '"', ["'"] = "'", ["`"] = "`", ["{"] = "{" }

function Lexer:readQuoted(p, quote, interp)
	local src = self.src
	local startLine = self.line
	local out = {}
	while true do
		local c = byte(src, p)
		if not c then
			fail(startLine, "unfinished string")
		end
		if interp then
			if c == 96 then
				return table.concat(out), p + 1, "end"
			elseif c == 123 then
				if byte(src, p + 1) == 123 then
					fail(self.line, "double braces are not permitted within interpolated strings; did you mean '\\{'?")
				end
				return table.concat(out), p + 1, "expr"
			end
		elseif c == quote then
			return table.concat(out), p + 1
		end
		if c == 10 or c == 13 then
			if interp then
				out[#out + 1] = "\n"
				p = self:newline(p)
			else
				fail(startLine, "unfinished string")
			end
		elseif c == 92 then
			local n = sub(src, p + 1, p + 1)
			if n == "x" then
				local h = sub(src, p + 2, p + 3)
				if not h:match("^%x%x$") then
					fail(self.line, "hexadecimal escape sequence must have two hex digits")
				end
				out[#out + 1] = string.char(tonumber(h, 16))
				p += 4
			elseif n == "z" then
				p += 2
				while true do
					local w = byte(src, p)
					if w == 10 or w == 13 then
						p = self:newline(p)
					elseif w == 32 or w == 9 or w == 11 or w == 12 then
						p += 1
					else
						break
					end
				end
			elseif n == "u" then
				local h, e = src:match("^{(%x+)}()", p + 2)
				if not h then
					fail(self.line, "unicode escape must be of the form \\u{XXX}")
				end
				local cp = tonumber(h, 16)
				if cp > 0x10FFFF then
					fail(self.line, "unicode codepoint too large")
				end
				out[#out + 1] = utf8.char(cp)
				p = e
			elseif n == "\r" or n == "\n" then
				out[#out + 1] = "\n"
				p = self:newline(p + 1)
			elseif n:match("%d") then
				local d = src:match("^%d%d?%d?", p + 1)
				local v = tonumber(d)
				if v > 255 then
					fail(self.line, "decimal escape too large")
				end
				out[#out + 1] = string.char(v)
				p += 1 + #d
			elseif ESC[n] then
				out[#out + 1] = ESC[n]
				p += 2
			elseif interp then
				out[#out + 1] = n
				p += 2
			else
				fail(self.line, "invalid escape sequence '\\" .. n .. "'")
			end
		else
			local stop = p
			while true do
				local d = byte(src, stop)
				if not d or d == 92 or d == 10 or d == 13 or (interp and (d == 96 or d == 123)) or (not interp and d == quote) then
					break
				end
				stop += 1
			end
			if stop == p then
				stop = p + 1
			end
			out[#out + 1] = sub(src, p, stop - 1)
			p = stop
		end
	end
end

local function parseInteger(s, line)
	local base, digits = 10, s
	if s:match("^0[xX]") then
		base, digits = 16, s:sub(3)
	elseif s:match("^0[bB]") then
		base, digits = 2, s:sub(3)
	end
	if digits == "" then
		fail(line, "malformed number")
	end
	local hi, lo = 0, 0
	for ch in digits:gmatch(".") do
		local d = tonumber(ch, base)
		if not d then
			fail(line, "malformed number")
		end
		local x = lo * base + d
		lo = x % 4294967296
		hi = (hi * base + math.floor(x / 4294967296)) % 4294967296
	end
	return { hi = hi, lo = lo }
end

local function parseNumber(text, line)
	local s = text:gsub("_", "")
	if s:sub(-1) == "i" and #s > 1 then
		return parseInteger(s:sub(1, -2), line), true
	end
	local v
	if s:match("^0[xX]") then
		if s:match("^0[xX]%x+$") then
			v = 0
			for d in s:sub(3):gmatch(".") do
				v = v * 16 + tonumber(d, 16)
			end
		else
			v = tonumber(s)
		end
	elseif s:match("^0[bB]") then
		if s:match("^0[bB][01]+$") then
			v = 0
			for d in s:sub(3):gmatch(".") do
				v = v * 2 + tonumber(d)
			end
		end
	else
		if s:match("^[%d%.]+[eE]?[%+%-]?%d*$") or s:match("^%.?%d") then
			v = tonumber(s)
		end
	end
	if v == nil then
		fail(line, "malformed number")
	end
	return v
end

local OPS3 = { ["..."] = true, ["//="] = true, ["..="] = true }
local OPS2 = {
	["=="] = true, ["~="] = true, ["<="] = true, [">="] = true, [".."] = true, ["+="] = true, ["-="] = true,
	["*="] = true, ["/="] = true, ["%="] = true, ["^="] = true, ["//"] = true, ["->"] = true, ["::"] = true,
}

function Lexer:lexRaw()
	local src = self.src
	local p = self.pos
	while true do
		local c = byte(src, p)
		if c == 10 or c == 13 then
			p = self:newline(p)
		elseif c == 32 or c == 9 or c == 11 or c == 12 then
			p += 1
		elseif c == 45 and byte(src, p + 1) == 45 then
			local startLine = self.line
			local q = p + 2
			local lvl, after
			if byte(src, q) == 91 then
				lvl, after = self:skipLongBracket(q)
			end
			if lvl then
				local _, np = self:readLongString(after, lvl, startLine)
				p = np
			else
				local e = find(src, "[\r\n]", q) or #src + 1
				if not self.sawCode and byte(src, q) == 33 then
					self.hotcomments[#self.hotcomments + 1] = sub(src, q + 1, e - 1):match("^%s*(.-)%s*$")
				end
				p = e
			end
		else
			break
		end
	end
	local line = self.line
	local c = byte(src, p)
	if not c then
		self.pos = p
		return { t = "eof", line = line, eline = line }
	end
	self.sawCode = true
	local tok
	if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95 then
		local e = select(2, find(src, "^[%w_]+", p))
		local word = sub(src, p, e)
		self.pos = e + 1
		if KEYWORDS[word] then
			return { t = word, v = word, line = line, eline = line }
		end
		return { t = "name", v = word, line = line, eline = line }
	elseif (c >= 48 and c <= 57) or (c == 46 and (byte(src, p + 1) or 0) >= 48 and (byte(src, p + 1) or 0) <= 57) then
		local q = p
		while true do
			local d = byte(src, q)
			if not d then
				break
			end
			if (d >= 48 and d <= 57) or (d >= 65 and d <= 90) or (d >= 97 and d <= 122) or d == 46 or d == 95 then
				local isHex = sub(src, p, p + 1):match("^0[xX]") ~= nil
				if (not isHex and (d == 101 or d == 69)) or (isHex and (d == 112 or d == 80)) then
					local n = byte(src, q + 1)
					if n == 43 or n == 45 then
						q += 1
					end
				end
				q += 1
			else
				break
			end
		end
		local text = sub(src, p, q - 1)
		self.pos = q
		local v, isInt = parseNumber(text, line)
		return { t = isInt and "integer" or "number", v = v, line = line, eline = line }
	elseif c == 34 or c == 39 then
		local s, np = self:readQuoted(p + 1, c, false)
		self.pos = np
		return { t = "string", v = s, line = line, eline = self.line }
	elseif c == 96 then
		local s, np, kind = self:readQuoted(p + 1, 96, true)
		self.pos = np
		if kind == "end" then
			return { t = "interpsimple", v = s, line = line, eline = self.line }
		end
		self.braceStack[#self.braceStack + 1] = "interp"
		return { t = "interpbegin", v = s, line = line, eline = self.line }
	elseif c == 91 then
		local lvl, after = self:skipLongBracket(p)
		if lvl then
			local s, np = self:readLongString(after, lvl, line)
			self.pos = np
			return { t = "string", v = s, line = line, eline = self.line }
		end
	elseif c == 123 then
		self.braceStack[#self.braceStack + 1] = "normal"
		self.pos = p + 1
		return { t = "{", line = line, eline = line }
	elseif c == 125 then
		local top = self.braceStack[#self.braceStack]
		if top == "interp" then
			self.braceStack[#self.braceStack] = nil
			local s, np, kind = self:readQuoted(p + 1, 96, true)
			self.pos = np
			if kind == "end" then
				return { t = "interpend", v = s, line = line, eline = self.line }
			end
			self.braceStack[#self.braceStack + 1] = "interp"
			return { t = "interpmid", v = s, line = line, eline = self.line }
		end
		if top then
			self.braceStack[#self.braceStack] = nil
		end
		self.pos = p + 1
		return { t = "}", line = line, eline = line }
	end
	local s3, s2 = sub(src, p, p + 2), sub(src, p, p + 1)
	if OPS3[s3] then
		self.pos = p + 3
		return { t = s3, line = line, eline = line }
	elseif OPS2[s2] then
		self.pos = p + 2
		return { t = s2, line = line, eline = line }
	end
	local s1 = sub(src, p, p)
	if find("+-*/%^#<>=(),;:.[]@?|&~", s1, 1, true) then
		self.pos = p + 1
		return { t = s1, line = line, eline = line }
	end
	fail(line, "unexpected character '" .. s1 .. "'")
end

function Lexer:next()
	local q = self.queue
	if #q > 0 then
		return table.remove(q, 1)
	end
	return self:lexRaw()
end

function Lexer:peek(n)
	local q = self.queue
	while #q < n do
		q[#q + 1] = self:lexRaw()
	end
	return q[n]
end

return Lexer
end)()
local Parser = (function()
local Parser = {}
Parser.__index = Parser

local function fail(line, msg)
	error(string.format(":%d: %s", line, msg), 0)
end

local BINPRI = {
	["+"] = { 6, 6, "Add" }, ["-"] = { 6, 6, "Sub" }, ["*"] = { 7, 7, "Mul" }, ["/"] = { 7, 7, "Div" },
	["//"] = { 7, 7, "FloorDiv" }, ["%"] = { 7, 7, "Mod" }, ["^"] = { 10, 9, "Pow" }, [".."] = { 5, 4, "Concat" },
	["~="] = { 3, 3, "CompareNe" }, ["=="] = { 3, 3, "CompareEq" }, ["<"] = { 3, 3, "CompareLt" },
	["<="] = { 3, 3, "CompareLe" }, [">"] = { 3, 3, "CompareGt" }, [">="] = { 3, 3, "CompareGe" },
	["and"] = { 2, 2, "And" }, ["or"] = { 1, 1, "Or" },
}
local UNOPS = { ["not"] = "Not", ["-"] = "Minus", ["#"] = "Len" }
local COMPOUND = {
	["+="] = "Add", ["-="] = "Sub", ["*="] = "Mul", ["/="] = "Div", ["//="] = "FloorDiv", ["%="] = "Mod",
	["^="] = "Pow", ["..="] = "Concat",
}
local BLOCK_END = { eof = true, ["end"] = true, ["else"] = true, ["elseif"] = true, ["until"] = true }

function Parser.new(lexer)
	local self = setmetatable({}, Parser)
	self.lx = lexer
	self.cur = lexer:next()
	self.prevLine = 1
	self.functionStack = {}
	self.localMap = {}
	self.localStack = {}
	return self
end

function Parser:advance()
	local t = self.cur
	self.prevLine = t.eline
	self.cur = self.lx:next()
	return t
end

function Parser:peek(n)
	return self.lx:peek(n)
end

local function describe(t)
	if t.t == "eof" then
		return "<eof>"
	elseif t.t == "name" or t.t == "number" then
		return tostring(t.v)
	elseif t.t == "string" then
		return "string"
	end
	return "'" .. t.t .. "'"
end

function Parser:expect(tt, ctx)
	local t = self.cur
	if t.t ~= tt then
		fail(t.line, string.format("Expected '%s' when parsing %s, got %s", tt, ctx or "expression", describe(t)))
	end
	return self:advance()
end

function Parser:expectMatch(tt, open, openLine)
	local t = self.cur
	if t.t ~= tt then
		local extra = ""
		if openLine ~= t.line then
			extra = string.format(" (to close '%s' at line %d)", open, openLine)
		end
		fail(t.line, string.format("Expected '%s'%s, got %s", tt, extra, describe(t)))
	end
	return self:advance()
end

function Parser:accept(tt)
	if self.cur.t == tt then
		return self:advance()
	end
	return nil
end

function Parser:expectName(ctx)
	local t = self.cur
	if t.t ~= "name" then
		fail(t.line, string.format("Expected identifier when parsing %s, got %s", ctx, describe(t)))
	end
	self:advance()
	return t
end

function Parser:curFunction()
	return self.functionStack[#self.functionStack]
end

function Parser:pushLocal(name, line)
	local f = self:curFunction()
	local l = {
		name = name,
		shadow = self.localMap[name],
		functionDepth = #self.functionStack - 1,
		loopDepth = f.loopDepth,
		line = line,
	}
	self.localMap[name] = l
	self.localStack[#self.localStack + 1] = l
	return l
end

function Parser:saveLocals()
	return #self.localStack
end

function Parser:restoreLocals(n)
	local st = self.localStack
	for i = #st, n + 1, -1 do
		local l = st[i]
		self.localMap[l.name] = l.shadow
		st[i] = nil
	end
end

function Parser:resolveName(tok)
	local l = self.localMap[tok.v]
	if l then
		return {
			k = "Local", ["local"] = l, upvalue = l.functionDepth ~= #self.functionStack - 1,
			line = tok.line, eline = tok.eline, name = tok.v,
		}
	end
	return { k = "Global", name = tok.v, line = tok.line, eline = tok.eline }
end

function Parser:parseBlock()
	local first = self.cur
	local saved = self:saveLocals()
	local body = self:parseStatements()
	self:restoreLocals(saved)
	return { k = "Block", body = body, line = first.line, eline = self.prevLine }
end

function Parser:parseStatements()
	local body = {}
	while not BLOCK_END[self.cur.t] do
		local isLast = self.cur.t == "return"
		local st = self:parseStat()
		body[#body + 1] = st
		self:accept(";")
		if isLast then
			break
		end
	end
	return body
end

function Parser:parseStat()
	local t = self.cur
	local tt = t.t
	if tt == "if" then
		return self:parseIf()
	elseif tt == "while" then
		return self:parseWhile()
	elseif tt == "do" then
		self:advance()
		local body = self:parseBlock()
		local e = self:expectMatch("end", "do", t.line)
		body.line = t.line
		body.eline = e.eline
		return body
	elseif tt == "for" then
		return self:parseFor()
	elseif tt == "repeat" then
		return self:parseRepeat()
	elseif tt == "function" then
		return self:parseFunctionStat(false)
	elseif tt == "local" then
		return self:parseLocal(t)
	elseif tt == "return" then
		return self:parseReturn()
	elseif tt == "break" then
		self:advance()
		if self:curFunction().loopDepth == 0 then
			fail(t.line, "break statement must be inside a loop")
		end
		return { k = "Break", line = t.line, eline = t.eline }
	elseif tt == "@" then
		return self:parseAttributedStat()
	end
	local expr = self:parsePrimaryExpr(true)
	if expr.k == "Call" then
		return { k = "ExprStat", expr = expr, line = expr.line, eline = expr.eline }
	end
	local c = self.cur.t
	if c == "," or c == "=" then
		return self:parseAssignment(expr)
	end
	if COMPOUND[c] then
		self:advance()
		local value = self:parseExpr()
		return { k = "CompoundAssign", op = COMPOUND[c], var = expr, value = value, line = expr.line, eline = value.eline }
	end
	local ident = (expr.k == "Global" or expr.k == "Local") and expr.name
	if ident == "type" then
		return self:parseTypeAlias(expr.line)
	elseif ident == "export" and self.cur.t == "name" and self.cur.v == "type" then
		self:advance()
		return self:parseTypeAlias(expr.line)
	elseif ident == "continue" then
		if self:curFunction().loopDepth == 0 then
			fail(expr.line, "continue statement must be inside a loop")
		end
		return { k = "Continue", line = expr.line, eline = expr.eline }
	elseif ident == "const" then
		return self:parseLocal(t, true)
	end
	fail(t.line, "Incomplete statement: expected assignment or a function call")
end

function Parser:parseAttributes()
	local native = false
	while self.cur.t == "@" do
		self:advance()
		if self.cur.t == "[" then
			local depth = 0
			repeat
				if self.cur.t == "[" then
					depth += 1
				elseif self.cur.t == "]" then
					depth -= 1
				elseif self.cur.t == "name" and self.cur.v == "native" then
					native = true
				elseif self.cur.t == "eof" then
					fail(self.cur.line, "unterminated attribute list")
				end
				self:advance()
			until depth == 0
		else
			local n = self:expectName("attribute name")
			if n.v == "native" then
				native = true
			end
		end
	end
	return native
end

function Parser:parseAttributedStat()
	local start = self.cur
	local native = self:parseAttributes()
	if self.cur.t == "function" then
		return self:parseFunctionStat(native, start)
	elseif self.cur.t == "local" then
		local lt = self:advance()
		if self.cur.t ~= "function" then
			fail(self.cur.line, "Expected 'function' after attributes on local")
		end
		return self:parseLocalFunction(lt, native)
	end
	fail(self.cur.line, "Expected 'function' or 'local function' after attribute")
end

function Parser:parseIfHead()
	local c = self.cur
	if c.t == "local" or (c.t == "name" and c.v == "const" and self:peek(1).t == "name") then
		self:advance()
		local nt = self:expectName("variable name")
		if self.cur.t == ":" then
			self:advance()
			self:parseType()
		end
		if self.cur.t == "," then
			fail(self.cur.line, "Expected '=' after variable name in 'if local', got ','; only a single binding is allowed")
		end
		self:expect("=", "if local declaration")
		local cond = self:parseExpr()
		return cond, nt
	end
	return self:parseExpr(), nil
end

function Parser:parseIf()
	local start = self:advance()
	local cond, bind = self:parseIfHead()
	self:expect("then", "if statement")
	local saved = self:saveLocals()
	local lv = bind and self:pushLocal(bind.v, bind.line)
	local thenbody = self:parseBlock()
	self:restoreLocals(saved)
	local node = { k = "If", condition = cond, conditionLocal = lv or nil, thenbody = thenbody, line = start.line }
	local t = self.cur
	if t.t == "elseif" then
		node.elsebody = self:parseIf()
		node.eline = node.elsebody.eline
		return node
	end
	if t.t == "else" then
		self:advance()
		node.elsebody = self:parseBlock()
		node.thenEnd = t.line
	end
	local e = self:expectMatch("end", "if", start.line)
	node.eline = e.eline
	return node
end

function Parser:parseLoopBody()
	local f = self:curFunction()
	f.loopDepth += 1
	local body = self:parseBlock()
	f.loopDepth -= 1
	return body
end

function Parser:parseWhile()
	local start = self:advance()
	local cond = self:parseExpr()
	self:expect("do", "while loop")
	local body = self:parseLoopBody()
	local e = self:expectMatch("end", "while", start.line)
	return { k = "While", condition = cond, body = body, line = start.line, eline = e.eline }
end

function Parser:parseRepeat()
	local start = self:advance()
	local f = self:curFunction()
	f.loopDepth += 1
	local saved = self:saveLocals()
	local first = self.cur
	local stats = self:parseStatements()
	local body = { k = "Block", body = stats, line = first.line, eline = self.prevLine }
	self:expectMatch("until", "repeat", start.line)
	local cond = self:parseExpr()
	self:restoreLocals(saved)
	f.loopDepth -= 1
	return { k = "Repeat", body = body, condition = cond, line = start.line, eline = cond.eline }
end

function Parser:parseFor()
	local start = self:advance()
	local n1 = self:expectName("for loop")
	if self.cur.t == "=" then
		if self.cur.t == "=" then
			self:advance()
		end
		local from = self:parseExpr()
		self:expect(",", "for loop")
		local to = self:parseExpr()
		local step
		if self:accept(",") then
			step = self:parseExpr()
		end
		self:expect("do", "for loop")
		local saved = self:saveLocals()
		local var = self:pushLocal(n1.v, n1.line)
		local body = self:parseLoopBody()
		self:restoreLocals(saved)
		local e = self:expectMatch("end", "for", start.line)
		return { k = "For", var = var, from = from, to = to, step = step, body = body, line = start.line, eline = e.eline }
	end
	local names = { n1 }
	if self.cur.t == ":" then
		self:advance()
		self:parseType()
	end
	while self:accept(",") do
		names[#names + 1] = self:expectName("for loop")
		if self.cur.t == ":" then
			self:advance()
			self:parseType()
		end
	end
	self:expect("in", "for loop")
	local values = self:parseExprList()
	self:expect("do", "for loop")
	local saved = self:saveLocals()
	local vars = {}
	for i, n in names do
		vars[i] = self:pushLocal(n.v, n.line)
	end
	local body = self:parseLoopBody()
	self:restoreLocals(saved)
	local e = self:expectMatch("end", "for", start.line)
	return { k = "ForIn", vars = vars, values = values, body = body, line = start.line, eline = e.eline }
end

function Parser:parseFunctionStat(native, startTok)
	local ft = self:advance()
	local start = startTok or ft
	local nt = self:expectName("function name")
	local debugname = nt.v
	local expr = self:resolveName(nt)
	while self.cur.t == "." do
		self:advance()
		local nm = self:expectName("field name")
		debugname = nm.v
		expr = { k = "IndexName", expr = expr, index = nm.v, line = expr.line, eline = nm.eline, indexLine = nm.line }
	end
	local hasself = false
	if self.cur.t == ":" then
		self:advance()
		local nm = self:expectName("method name")
		debugname = nm.v
		expr = { k = "IndexName", expr = expr, index = nm.v, line = expr.line, eline = nm.eline, indexLine = nm.line }
		hasself = true
	end
	local func = self:parseFunctionBody(hasself, ft, debugname, native)
	return { k = "FunctionStat", name = expr, func = func, line = start.line, eline = func.eline }
end

function Parser:parseLocalFunction(lt, native)
	local ft = self:advance()
	local nt = self:expectName("variable name")
	local l = self:pushLocal(nt.v, nt.line)
	local func = self:parseFunctionBody(false, ft, nt.v, native)
	return { k = "LocalFunction", name = l, func = func, line = lt.line, eline = func.eline }
end

function Parser:parseLocal(lt, isConst)
	if not isConst then
		self:advance()
	end
	if self.cur.t == "function" then
		return self:parseLocalFunction(lt, false)
	end
	local names = {}
	repeat
		local nt = self:expectName("variable name")
		if self.cur.t == ":" then
			self:advance()
			self:parseType()
		end
		names[#names + 1] = nt
	until not self:accept(",")
	local values = {}
	if self:accept("=") then
		values = self:parseExprList()
	end
	local vars = {}
	for i, n in names do
		vars[i] = self:pushLocal(n.v, n.line)
	end
	local last = values[#values]
	return { k = "LocalStat", vars = vars, values = values, line = lt.line, eline = last and last.eline or names[#names].eline }
end

function Parser:parseReturn()
	local start = self:advance()
	local list = {}
	if not BLOCK_END[self.cur.t] and self.cur.t ~= ";" then
		list = self:parseExprList()
	end
	local last = list[#list]
	return { k = "Return", list = list, line = start.line, eline = last and last.eline or start.eline }
end

function Parser:parseAssignment(first)
	local vars = { first }
	while self:accept(",") do
		vars[#vars + 1] = self:parsePrimaryExpr(true)
	end
	for _, v in vars do
		if v.k ~= "Local" and v.k ~= "Global" and v.k ~= "IndexName" and v.k ~= "IndexExpr" then
			fail(v.line, "Assigned expression must be a variable or a field")
		end
	end
	self:expect("=", "assignment")
	local values = self:parseExprList()
	return { k = "Assign", vars = vars, values = values, line = first.line, eline = values[#values].eline }
end

function Parser:parseTypeAlias(line)
	local nt = self:expectName("type name")
	if self.cur.t == "<" then
		self:parseGenericList()
	end
	self:expect("=", "type alias")
	self:parseType()
	return { k = "TypeAlias", line = line, eline = self.prevLine }
end

function Parser:parseExprList()
	local list = { self:parseExpr() }
	while self:accept(",") do
		list[#list + 1] = self:parseExpr()
	end
	return list
end

function Parser:parseExpr(limit)
	limit = limit or 0
	local t = self.cur
	local left
	local uop = UNOPS[t.t]
	if uop then
		self:advance()
		local sub = self:parseExpr(8)
		left = { k = "Unary", op = uop, expr = sub, line = t.line, eline = sub.eline }
	else
		left = self:parseAssertionExpr()
	end
	while true do
		local bt = self.cur.t
		local info = BINPRI[bt]
		if not info or info[1] <= limit then
			break
		end
		self:advance()
		local right = self:parseExpr(info[2])
		left = { k = "Binary", op = info[3], left = left, right = right, line = left.line, eline = right.eline }
	end
	return left
end

function Parser:parseAssertionExpr()
	local expr = self:parseSimpleExpr()
	if self.cur.t == "::" then
		self:advance()
		self:parseType()
		expr = { k = "Assert", expr = expr, line = expr.line, eline = self.prevLine }
	end
	return expr
end

function Parser:parseSimpleExpr()
	local t = self.cur
	local tt = t.t
	if tt == "number" then
		self:advance()
		return { k = "Num", value = t.v, line = t.line, eline = t.eline }
	elseif tt == "integer" then
		self:advance()
		return { k = "Int", hi = t.v.hi, lo = t.v.lo, line = t.line, eline = t.eline }
	elseif tt == "string" then
		self:advance()
		return { k = "Str", value = t.v, line = t.line, eline = t.eline }
	elseif tt == "nil" then
		self:advance()
		return { k = "Nil", line = t.line, eline = t.eline }
	elseif tt == "true" or tt == "false" then
		self:advance()
		return { k = "Bool", value = tt == "true", line = t.line, eline = t.eline }
	elseif tt == "..." then
		self:advance()
		if not self:curFunction().vararg then
			fail(t.line, "Cannot use '...' outside of a vararg function")
		end
		return { k = "Varargs", line = t.line, eline = t.eline }
	elseif tt == "{" then
		return self:parseTable()
	elseif tt == "function" then
		local ft = self:advance()
		return self:parseFunctionBody(false, ft, nil, false)
	elseif tt == "@" then
		local native = self:parseAttributes()
		local ft = self.cur
		if ft.t ~= "function" then
			fail(ft.line, "Expected 'function' after attribute")
		end
		self:advance()
		return self:parseFunctionBody(false, ft, nil, native)
	elseif tt == "if" then
		return self:parseIfElseExpr()
	elseif tt == "interpsimple" or tt == "interpbegin" then
		return self:parseInterp()
	end
	return self:parsePrimaryExpr(false)
end

function Parser:parseIfElseExpr()
	local start = self:advance()
	local cond, bind = self:parseIfHead()
	self:expect("then", "if then else expression")
	local saved = self:saveLocals()
	local lv = bind and self:pushLocal(bind.v, bind.line)
	local a = self:parseExpr()
	self:restoreLocals(saved)
	local b
	if self.cur.t == "elseif" then
		b = self:parseIfElseExpr()
	else
		self:expect("else", "if then else expression")
		b = self:parseExpr()
	end
	return { k = "IfElse", condition = cond, conditionLocal = lv or nil, trueExpr = a, falseExpr = b, line = start.line, eline = b.eline }
end

function Parser:parseInterp()
	local t = self:advance()
	if t.t == "interpsimple" then
		return { k = "Interp", strings = { t.v }, expressions = {}, line = t.line, eline = t.eline }
	end
	local strings, exprs = { t.v }, {}
	while true do
		exprs[#exprs + 1] = self:parseExpr()
		local n = self.cur
		if n.t == "interpmid" then
			self:advance()
			strings[#strings + 1] = n.v
		elseif n.t == "interpend" then
			self:advance()
			strings[#strings + 1] = n.v
			break
		else
			fail(n.line, "Malformed interpolated string, got " .. describe(n))
		end
	end
	return { k = "Interp", strings = strings, expressions = exprs, line = t.line, eline = self.prevLine }
end

function Parser:parseTable()
	local start = self:advance()
	local items = {}
	while self.cur.t ~= "}" do
		local t = self.cur
		if t.t == "[" then
			self:advance()
			local key = self:parseExpr()
			self:expect("]", "table field")
			self:expect("=", "table field")
			local value = self:parseExpr()
			items[#items + 1] = { kind = "General", key = key, value = value }
		elseif t.t == "name" and self:peek(1).t == "=" then
			self:advance()
			self:advance()
			local value = self:parseExpr()
			if value.k == "Function" then
				value.debugname = t.v
			end
			items[#items + 1] = { kind = "Record", key = { k = "Str", value = t.v, line = t.line, eline = t.eline }, value = value }
		else
			items[#items + 1] = { kind = "List", value = self:parseExpr() }
		end
		if self.cur.t == "," or self.cur.t == ";" then
			self:advance()
		elseif self.cur.t ~= "}" then
			fail(self.cur.line, "Expected ',' or '}' when parsing table constructor, got " .. describe(self.cur))
		end
	end
	local e = self:expectMatch("}", "{", start.line)
	return { k = "Table", items = items, line = start.line, eline = e.eline }
end

function Parser:parseCallArgs(startLine)
	local t = self.cur
	if t.t == "string" then
		self:advance()
		return { { k = "Str", value = t.v, line = t.line, eline = t.eline } }, t.eline
	elseif t.t == "{" then
		local tbl = self:parseTable()
		return { tbl }, tbl.eline
	elseif t.t == "interpsimple" then
		local e = self:parseInterp()
		return { e }, e.eline
	end
	self:expect("(", "function call arguments")
	local args = {}
	if self.cur.t ~= ")" then
		args = self:parseExprList()
	end
	local e = self:expectMatch(")", "(", t.line)
	return args, e.eline
end

function Parser:parsePrimaryExpr(asStatement)
	local t = self.cur
	local expr
	if t.t == "name" then
		self:advance()
		expr = self:resolveName(t)
	elseif t.t == "(" then
		self:advance()
		local inner = self:parseExpr()
		local e = self:expectMatch(")", "(", t.line)
		expr = { k = "Group", expr = inner, line = t.line, eline = e.eline }
	else
		fail(t.line, "Unexpected " .. describe(t) .. " when parsing expression")
	end
	while true do
		local c = self.cur
		local ct = c.t
		if ct == "." then
			self:advance()
			local nm = self:expectName("field name")
			expr = { k = "IndexName", expr = expr, index = nm.v, line = expr.line, eline = nm.eline, indexLine = nm.line }
		elseif ct == "[" then
			self:advance()
			local idx = self:parseExpr()
			local e = self:expectMatch("]", "[", c.line)
			expr = { k = "IndexExpr", expr = expr, index = idx, line = expr.line, eline = e.eline }
		elseif ct == ":" then
			self:advance()
			local nm = self:expectName("method name")
			local fn = { k = "IndexName", expr = expr, index = nm.v, line = expr.line, eline = nm.eline, indexLine = nm.line }
			if self.cur.t == "<" and self:peek(1).t == "<" then
				self:advance()
				self:advance()
				while self.cur.t ~= ">" do
					self:parseType()
					if not self:accept(",") then
						break
					end
				end
				self:expect(">", "type instantiation")
				self:expect(">", "type instantiation")
			end
			local args, eline = self:parseCallArgs()
			expr = { k = "Call", func = fn, args = args, self = true, line = expr.line, eline = eline }
		elseif ct == "(" then
			if asStatement and c.line ~= self.prevLine then
				break
			end
			local args, eline = self:parseCallArgs()
			expr = { k = "Call", func = expr, args = args, self = false, line = expr.line, eline = eline }
		elseif ct == "<" and self:peek(1).t == "<" then
			self:advance()
			self:advance()
			while self.cur.t ~= ">" do
				self:parseType()
				if not self:accept(",") then
					break
				end
			end
			self:expect(">", "type instantiation")
			self:expect(">", "type instantiation")
		elseif ct == "string" or ct == "{" or ct == "interpsimple" then
			local args, eline = self:parseCallArgs()
			expr = { k = "Call", func = expr, args = args, self = false, line = expr.line, eline = eline }
		else
			break
		end
	end
	return expr
end

function Parser:parseFunctionBody(hasself, ft, debugname, native)
	if self.cur.t == "<" then
		self:parseGenericList()
	end
	local open = self:expect("(", "function")
	local fn = { k = "Function", line = ft.line, debugname = debugname, hasNative = native or false }
	local depth = #self.functionStack
	local frame = { loopDepth = 0, vararg = false }
	self.functionStack[depth + 1] = frame
	fn.functionDepth = depth
	local saved = self:saveLocals()
	if hasself then
		fn.self = self:pushLocal("self", ft.line)
	end
	local args = {}
	while self.cur.t ~= ")" do
		if self.cur.t == "..." then
			self:advance()
			frame.vararg = true
			if self.cur.t == ":" then
				self:advance()
				self:parseType()
			end
			break
		end
		local nt = self:expectName("argument name")
		args[#args + 1] = self:pushLocal(nt.v, nt.line)
		if self.cur.t == ":" then
			self:advance()
			self:parseType()
		end
		if not self:accept(",") then
			break
		end
	end
	self:expectMatch(")", "(", open.line)
	if self.cur.t == ":" then
		self:advance()
		self:parseType()
	end
	fn.args = args
	fn.vararg = frame.vararg
	local first = self.cur
	local stats = self:parseStatements()
	local e = self:expectMatch("end", "function", ft.line)
	fn.body = { k = "Block", body = stats, line = first.line, eline = e.eline }
	fn.eline = e.eline
	self:restoreLocals(saved)
	self.functionStack[depth + 1] = nil
	return fn
end

function Parser:parseGenericList()
	self:expect("<", "generic list")
	while self.cur.t ~= ">" do
		self:expectName("generic name")
		if self.cur.t == "..." then
			self:advance()
		end
		if self.cur.t == "=" then
			self:advance()
			self:parseType()
		end
		if not self:accept(",") then
			break
		end
	end
	self:expect(">", "generic list")
end

function Parser:parseTypeParams()
	self:expect("<", "type parameters")
	while self.cur.t ~= ">" do
		self:parseType()
		if not self:accept(",") then
			break
		end
	end
	self:expect(">", "type parameters")
end

function Parser:parseType()
	if self.cur.t == "|" or self.cur.t == "&" then
		self:advance()
	end
	self:parseSimpleType()
	while true do
		local c = self.cur.t
		if c == "?" then
			self:advance()
		elseif c == "|" or c == "&" then
			self:advance()
			self:parseSimpleType()
		else
			break
		end
	end
end

function Parser:parseParenTypeList()
	self:expect("(", "type list")
	while self.cur.t ~= ")" do
		if self.cur.t == "..." then
			self:advance()
			if self.cur.t ~= ")" then
				self:parseType()
			end
		else
			if self.cur.t == "name" and self:peek(1).t == ":" then
				self:advance()
				self:advance()
			end
			self:parseType()
			if self.cur.t == "..." then
				self:advance()
			end
		end
		if not self:accept(",") then
			break
		end
	end
	self:expect(")", "type list")
end

function Parser:parseSimpleType()
	local t = self.cur
	local tt = t.t
	if tt == "nil" or tt == "true" or tt == "false" or tt == "string" then
		self:advance()
	elseif tt == "name" then
		self:advance()
		if t.v == "typeof" and self.cur.t == "(" then
			self:advance()
			self:parseExpr()
			self:expect(")", "typeof")
			return
		end
		while self.cur.t == "." do
			self:advance()
			self:expectName("type name")
		end
		if self.cur.t == "<" then
			self:parseTypeParams()
		end
		if self.cur.t == "..." then
			self:advance()
		end
	elseif tt == "{" then
		self:advance()
		while self.cur.t ~= "}" do
			local c = self.cur
			if c.t == "[" then
				self:advance()
				self:parseType()
				self:expect("]", "table type")
				self:expect(":", "table type")
				self:parseType()
			elseif c.t == "name" and self:peek(1).t == ":" then
				self:advance()
				self:advance()
				self:parseType()
			elseif c.t == "name" and (c.v == "read" or c.v == "write") and self:peek(1).t == "name" and self:peek(2).t == ":" then
				self:advance()
				self:advance()
				self:advance()
				self:parseType()
			elseif c.t == "name" and (c.v == "read" or c.v == "write") and self:peek(1).t == "[" then
				self:advance()
			else
				self:parseType()
			end
			if self.cur.t == "," or self.cur.t == ";" then
				self:advance()
			elseif self.cur.t ~= "}" then
				fail(self.cur.line, "Expected '}' when parsing table type, got " .. describe(self.cur))
			end
		end
		self:expect("}", "table type")
	elseif tt == "(" or tt == "<" then
		if tt == "<" then
			self:parseGenericList()
		end
		self:parseParenTypeList()
		if self.cur.t == "->" then
			self:advance()
			self:parseType()
		end
	elseif tt == "..." then
		self:advance()
		self:parseType()
	else
		fail(t.line, "Expected type, got " .. describe(t))
	end
end

function Parser.parse(lexer)
	local self = Parser.new(lexer)
	self.functionStack[1] = { loopDepth = 0, vararg = true }
	local first = self.cur
	local body = self:parseStatements()
	if self.cur.t ~= "eof" then
		fail(self.cur.line, "Expected <eof>, got " .. describe(self.cur))
	end
	return { k = "Block", body = body, line = first.line, eline = self.cur.line }, lexer.hotcomments
end

return Parser
end)()
local Builder = (function()
local Builder = {}
Builder.__index = Builder

local DEFAULT_VERSION = 6
local MAX_CONSTANTS = 8388608
local MAX_JUMP = 8388608

local band, bor, bxor, lshift, rshift = bit32.band, bit32.bor, bit32.bxor, bit32.lshift, bit32.rshift
local spack = string.pack

local function varint(n)
	if n < 128 then
		return string.char(n)
	end
	local out = {}
	while n >= 128 do
		out[#out + 1] = string.char(bor(band(n, 127), 128))
		n = math.floor(n / 128)
	end
	out[#out + 1] = string.char(n)
	return table.concat(out)
end

function Builder.new(version)
	local self = setmetatable({}, Builder)
	self.version = version or DEFAULT_VERSION
	self.typeVersion = self.version >= 5 and 3 or (self.version == 4 and 2 or 0)
	self.functions = {}
	self.stringIndex = {}
	self.stringList = {}
	self.mainFunction = 0
	self.current = nil
	return self
end

function Builder.getStringHash(s)
	local len = #s
	local h = len
	for i = len, 1, -1 do
		h = bxor(h, (lshift(h, 5) + rshift(h, 2) + string.byte(s, i)) % 4294967296)
	end
	return band(h, 255)
end

function Builder.getImportId(id0, id1, id2)
	if id2 then
		return 3 * 1073741824 + id0 * 1048576 + id1 * 1024 + id2
	elseif id1 then
		return 2 * 1073741824 + id0 * 1048576 + id1 * 1024
	end
	return 1073741824 + id0 * 1048576
end

function Builder:addString(s)
	local idx = self.stringIndex[s]
	if not idx then
		idx = #self.stringList + 1
		self.stringList[idx] = s
		self.stringIndex[s] = idx
	end
	return idx
end

function Builder:beginFunction(numparams, isvararg)
	local id = #self.functions
	self.functions[id + 1] = { numparams = numparams, isvararg = isvararg, debugname = 0, linedefined = 0 }
	self.current = {
		id = id,
		insns = {},
		lines = {},
		constants = {},
		constantMap = {},
		protos = {},
		protoMap = {},
		jumps = {},
		shapes = {},
		shapeMap = {},
		debugLocals = {},
		debugUpvals = {},
		debugLine = 0,
		hasLongJumps = false,
	}
	return id
end

local function addConstant(self, key, value)
	local c = self.current
	local cached = c.constantMap[key]
	if cached then
		return cached
	end
	local id = #c.constants
	if id >= MAX_CONSTANTS then
		return -1
	end
	c.constantMap[key] = id
	c.constants[id + 1] = value
	return id
end

function Builder:addConstantNil()
	return addConstant(self, "z", { t = "nil" })
end

function Builder:addConstantBoolean(b)
	return addConstant(self, b and "bt" or "bf", { t = "boolean", v = b })
end

function Builder:addConstantNumber(n)
	return addConstant(self, "n" .. spack("<d", n), { t = "number", v = n })
end

function Builder:addConstantString(s)
	local idx = self:addString(s)
	return addConstant(self, "s" .. idx, { t = "string", v = idx })
end

function Builder:addConstantInteger(hi, lo)
	return addConstant(self, "I" .. hi .. "," .. lo, { t = "integer", hi = hi, lo = lo })
end

function Builder:addImport(iid)
	return addConstant(self, "i" .. iid, { t = "import", v = iid })
end

function Builder:addConstantClosure(fid)
	return addConstant(self, "c" .. fid, { t = "closure", v = fid })
end

function Builder:addConstantTable(keys, consts)
	local c = self.current
	local key = table.concat(keys, ",") .. (consts and ("|" .. table.concat(consts, ",")) or "")
	local cached = c.shapeMap[key]
	if cached then
		return cached
	end
	local id = #c.constants
	if id >= MAX_CONSTANTS then
		return -1
	end
	c.shapeMap[key] = id
	c.constants[id + 1] = { t = "table", keys = keys, consts = consts }
	return id
end

function Builder:addChildFunction(fid)
	local c = self.current
	local cached = c.protoMap[fid]
	if cached then
		return cached
	end
	local id = #c.protos
	if id >= 32768 then
		return -1
	end
	c.protoMap[fid] = id
	c.protos[id + 1] = fid
	return id
end

function Builder:emitABC(op, a, b, cc)
	local c = self.current
	local n = #c.insns + 1
	c.insns[n] = op + a * 256 + b * 65536 + cc * 16777216
	c.lines[n] = c.debugLine
end

function Builder:emitAD(op, a, d)
	local c = self.current
	local n = #c.insns + 1
	c.insns[n] = op + a * 256 + band(d, 65535) * 65536
	c.lines[n] = c.debugLine
end

function Builder:emitE(op, e)
	local c = self.current
	local n = #c.insns + 1
	c.insns[n] = op + band(e, 16777215) * 256
	c.lines[n] = c.debugLine
end

function Builder:emitAux(aux)
	local c = self.current
	local n = #c.insns + 1
	c.insns[n] = aux % 4294967296
	c.lines[n] = c.debugLine
end

function Builder:undoEmit()
	local c = self.current
	local n = #c.insns
	c.insns[n] = nil
	c.lines[n] = nil
end

function Builder:emitLabel()
	return #self.current.insns
end

function Builder:getInstructionCount()
	return #self.current.insns
end

function Builder:getDebugPC()
	return #self.current.insns
end

function Builder:lastInstruction()
	local c = self.current
	return c.insns[#c.insns]
end

function Builder:patchJumpD(jumpLabel, targetLabel)
	local c = self.current
	local offset = targetLabel - jumpLabel - 1
	if offset >= -32768 and offset <= 32767 then
		c.insns[jumpLabel + 1] = bor(c.insns[jumpLabel + 1], lshift(band(offset, 65535), 16))
	elseif math.abs(offset) < MAX_JUMP then
		c.hasLongJumps = true
	else
		return false
	end
	c.jumps[#c.jumps + 1] = { source = jumpLabel, target = targetLabel }
	return true
end

function Builder:patchSkipC(jumpLabel, targetLabel)
	local c = self.current
	local offset = targetLabel - jumpLabel - 1
	if offset < 0 or offset > 255 then
		return false
	end
	c.insns[jumpLabel + 1] = bor(c.insns[jumpLabel + 1], lshift(offset, 24))
	return true
end

function Builder:setDebugFunctionName(name)
	self.functions[self.current.id + 1].debugname = self:addString(name)
end

function Builder:setDebugFunctionLineDefined(line)
	self.functions[self.current.id + 1].linedefined = line
end

function Builder:setDebugLine(line)
	self.current.debugLine = line
end

function Builder:pushDebugLocal(name, reg, startpc, endpc)
	local c = self.current
	c.debugLocals[#c.debugLocals + 1] = { name = self:addString(name), reg = reg, startpc = startpc, endpc = endpc }
end

function Builder:pushDebugUpval(name)
	local c = self.current
	c.debugUpvals[#c.debugUpvals + 1] = { name = self:addString(name) }
end

local OP_JUMP, OP_RETURN, OP_JUMPX = 23, 22, 67

function Builder:foldJumps()
	local c = self.current
	if c.hasLongJumps then
		return
	end
	local insns = c.insns
	for _, jump in c.jumps do
		local jl = jump.source
		local ji = insns[jl + 1]
		local d = band(rshift(ji, 16), 65535)
		if d >= 32768 then
			d -= 65536
		end
		local tl = jl + 1 + d
		local ti = insns[tl + 1]
		while band(ti, 255) == OP_JUMP do
			local td = band(rshift(ti, 16), 65535)
			if td >= 32768 then
				break
			end
			tl = tl + 1 + td
			ti = insns[tl + 1]
		end
		local offset = tl - jl - 1
		if band(ji, 255) == OP_JUMP and band(ti, 255) == OP_RETURN then
			insns[jl + 1] = ti
		elseif offset >= -32768 and offset <= 32767 then
			insns[jl + 1] = bor(band(ji, 65535), lshift(band(offset, 65535), 16))
		end
		jump.target = tl
	end
end

local OPLEN2 = {}
for _, op in { 7, 8, 12, 15, 16, 20, 27, 28, 29, 30, 31, 32, 5, 63, 56, 57, 58, 59, 60, 61, 74, 75, 76, 77, 78, 79, 80, 81, 18, 14 } do
	OPLEN2[op] = false
end

function Builder:setOpLengths(lens)
	self.opLen = lens
end

function Builder:expandJumps()
	local c = self.current
	if not c.hasLongJumps then
		return true
	end
	local insns, lines = c.insns, c.lines
	table.sort(c.jumps, function(a, b)
		return a.source < b.source
	end)
	local K = math.floor(32767 / 3)
	local remap = {}
	local newins, newlines = {}, {}
	local cj = 1
	local jumps = c.jumps
	local i = 1
	local opLen = self.opLen
	while i <= #insns do
		local op = band(insns[i], 255)
		if jumps[cj] and jumps[cj].source == i - 1 then
			local offset = jumps[cj].target - jumps[cj].source - 1
			if math.abs(offset) >= K then
				newins[#newins + 1] = OP_JUMP + 65536
				newins[#newins + 1] = OP_JUMPX
				newlines[#newlines + 1] = lines[i]
				newlines[#newlines + 1] = lines[i]
			end
			cj += 1
		end
		local len = opLen[op] or 1
		for _ = 1, len do
			remap[i - 1] = #newins
			newins[#newins + 1] = insns[i]
			newlines[#newlines + 1] = lines[i]
			i += 1
		end
	end
	for _, jump in jumps do
		local offset = jump.target - jump.source - 1
		local newoffset = remap[jump.target] - remap[jump.source] - 1
		if math.abs(newoffset) + 1 >= MAX_JUMP then
			return false
		elseif math.abs(offset) >= K then
			local pt = remap[jump.source] - 1
			local pj = remap[jump.source]
			newins[pt + 1] = bor(band(newins[pt + 1], 255), lshift(band(newoffset + 1, 16777215), 8))
			newins[pj + 1] = bor(band(newins[pj + 1], 65535), lshift(band(-2, 65535), 16))
		else
			local p = remap[jump.source]
			newins[p + 1] = bor(band(newins[p + 1], 65535), lshift(band(newoffset, 65535), 16))
		end
	end
	c.insns, c.lines = newins, newlines
	for _, dl in c.debugLocals do
		if dl.startpc ~= dl.endpc then
			dl.endpc = remap[dl.endpc - 1] + 1
		else
			dl.endpc = remap[dl.endpc]
		end
		dl.startpc = remap[dl.startpc]
	end
	return true
end

local function writeLineInfo(lines)
	local n = #lines
	local function log2(v)
		local r = 0
		v = math.floor(v / 2)
		while v > 0 do
			r += 1
			v = math.floor(v / 2)
		end
		return r
	end
	local span = 16777216
	local offset = 1
	while offset <= n do
		local nxt = offset
		local mn, mx = lines[offset], lines[offset]
		while nxt <= n and nxt < offset + span do
			local l = lines[nxt]
			if l < mn then
				mn = l
			end
			if l > mx then
				mx = l
			end
			if mx - mn > 255 then
				break
			end
			nxt += 1
		end
		if nxt <= n and nxt - offset < span then
			span = 2 ^ log2(nxt - offset)
		end
		offset += span
	end
	local logspan = log2(span)
	local baseline = {}
	local off = 1
	while off <= n do
		local mn = lines[off]
		local nxt = off
		while nxt <= n and nxt < off + span do
			if lines[nxt] < mn then
				mn = lines[nxt]
			end
			nxt += 1
		end
		baseline[#baseline + 1] = mn
		off += span
	end
	local out = { string.char(logspan) }
	local last = 0
	for i = 1, n do
		local delta = lines[i] - baseline[math.floor((i - 1) / span) + 1]
		out[#out + 1] = string.char((delta - last) % 256)
		last = delta % 256
	end
	local lastLine = 0
	for i = 1, #baseline do
		out[#out + 1] = spack("<i4", baseline[i] - lastLine)
		lastLine = baseline[i]
	end
	return table.concat(out)
end

function Builder:endFunction(maxstack, numupvalues, flags)
	local c = self.current
	local f = self.functions[c.id + 1]
	local out = {}
	local function add(s)
		out[#out + 1] = s
	end
	local version = self.version
	if version >= 4 then
		add(string.char(maxstack, f.numparams, numupvalues, f.isvararg and 1 or 0, flags or 0))
		add(varint(#(f.typeinfo or "")))
		if f.typeinfo then
			add(f.typeinfo)
		end
	else
		add(string.char(maxstack, f.numparams, numupvalues, f.isvararg and 1 or 0))
	end
	add(varint(#c.insns))
	for _, insn in c.insns do
		add(spack("<I4", insn))
	end
	add(varint(#c.constants))
	for _, k in c.constants do
		local t = k.t
		if t == "nil" then
			add("\0")
		elseif t == "boolean" then
			add(k.v and "\1\1" or "\1\0")
		elseif t == "number" then
			add("\2" .. spack("<d", k.v))
		elseif t == "string" then
			add("\3" .. varint(k.v))
		elseif t == "integer" then
			local hi, lo = k.hi, k.lo
			local neg = hi >= 2147483648
			if neg then
				lo = (4294967296 - lo) % 4294967296
				hi = (4294967295 - hi + (lo == 0 and 1 or 0)) % 4294967296
			end
			local bytes = {}
			repeat
				local low7 = lo % 128
				lo = math.floor(lo / 128) + (hi % 128) * 33554432
				hi = math.floor(hi / 128)
				if hi > 0 or lo > 0 then
					low7 += 128
				end
				bytes[#bytes + 1] = string.char(low7)
			until hi == 0 and lo == 0
			add("\9" .. (neg and "\1" or "\0") .. table.concat(bytes))
		elseif t == "import" then
			add("\4" .. spack("<I4", k.v))
		elseif t == "table" then
			if k.consts then
				add("\8" .. varint(#k.keys))
				for i, key in k.keys do
					add(varint(key) .. spack("<i4", k.consts[i]))
				end
			else
				add("\5" .. varint(#k.keys))
				for _, key in k.keys do
					add(varint(key))
				end
			end
		elseif t == "closure" then
			add("\6" .. varint(k.v))
		end
	end
	add(varint(#c.protos))
	for _, p in c.protos do
		add(varint(p))
	end
	add(varint(f.linedefined))
	add(varint(f.debugname))
	local hasLines = #c.lines > 0
	for _, l in c.lines do
		if l == 0 then
			hasLines = false
			break
		end
	end
	if hasLines then
		add("\1")
		add(writeLineInfo(c.lines))
	else
		add("\0")
	end
	if #c.debugLocals > 0 or #c.debugUpvals > 0 then
		add("\1")
		add(varint(#c.debugLocals))
		for _, l in c.debugLocals do
			add(varint(l.name) .. varint(l.startpc) .. varint(l.endpc) .. string.char(l.reg))
		end
		add(varint(#c.debugUpvals))
		for _, u in c.debugUpvals do
			add(varint(u.name))
		end
	else
		add("\0")
	end
	if version >= 11 then
		add(varint(0))
	end
	if version >= 12 and band(flags or 0, 8) ~= 0 then
		add(varint(f.cost or 0))
	end
	local body = table.concat(out)
	if version >= 12 then
		body = varint(#body) .. body
	end
	f.data = body
	self.current = nil
end

function Builder:setFunctionTypeInfo(bytes)
	self.functions[self.current.id + 1].typeinfo = bytes
end

function Builder:setMainFunction(fid)
	self.mainFunction = fid
end

function Builder:finalize()
	local out = {}
	if self.version >= 4 then
		out[1] = string.char(self.version, self.typeVersion)
	else
		out[1] = string.char(self.version)
	end
	out[#out + 1] = varint(#self.stringList)
	for _, s in self.stringList do
		out[#out + 1] = varint(#s)
		out[#out + 1] = s
	end
	if self.typeVersion == 3 then
		out[#out + 1] = "\0"
	end
	out[#out + 1] = varint(#self.functions)
	for _, f in self.functions do
		out[#out + 1] = f.data
	end
	out[#out + 1] = varint(self.mainFunction)
	return table.concat(out)
end

Builder.getError = function(message)
	return "\0" .. message
end

return Builder
end)()
local OP = {
  NOP=0, BREAK=1, LOADNIL=2, LOADB=3, LOADN=4, LOADK=5, MOVE=6, GETGLOBAL=7, SETGLOBAL=8, GETUPVAL=9,
  SETUPVAL=10, CLOSEUPVALS=11, GETIMPORT=12, GETTABLE=13, SETTABLE=14, GETTABLEKS=15, SETTABLEKS=16,
  GETTABLEN=17, SETTABLEN=18, NEWCLOSURE=19, NAMECALL=20, CALL=21, RETURN=22, JUMP=23, JUMPBACK=24,
  JUMPIF=25, JUMPIFNOT=26, JUMPIFEQ=27, JUMPIFLE=28, JUMPIFLT=29, JUMPIFNOTEQ=30, JUMPIFNOTLE=31,
  JUMPIFNOTLT=32, ADD=33, SUB=34, MUL=35, DIV=36, MOD=37, POW=38, ADDK=39, SUBK=40, MULK=41, DIVK=42,
  MODK=43, POWK=44, AND=45, OR=46, ANDK=47, ORK=48, CONCAT=49, NOT=50, MINUS=51, LENGTH=52, NEWTABLE=53,
  DUPTABLE=54, SETLIST=55, FORNPREP=56, FORNLOOP=57, FORGLOOP=58, FORGPREP_INEXT=59, FASTCALL3=60,
  FORGPREP_NEXT=61, NATIVECALL=62, GETVARARGS=63, DUPCLOSURE=64, PREPVARARGS=65, LOADKX=66, JUMPX=67,
  FASTCALL=68, COVERAGE=69, CAPTURE=70, SUBRK=71, DIVRK=72, FASTCALL1=73, FASTCALL2=74, FASTCALL2K=75,
  FORGPREP=76, JUMPXEQKNIL=77, JUMPXEQKB=78, JUMPXEQKN=79, JUMPXEQKS=80, IDIV=81, IDIVK=82, FASTPCALL=89,
}
local LBF = {
  ASSERT=1, MATH_ABS=2, MATH_ACOS=3, MATH_ASIN=4, MATH_ATAN2=5, MATH_ATAN=6, MATH_CEIL=7, MATH_COSH=8,
  MATH_COS=9, MATH_DEG=10, MATH_EXP=11, MATH_FLOOR=12, MATH_FMOD=13, MATH_FREXP=14, MATH_LDEXP=15,
  MATH_LOG10=16, MATH_LOG=17, MATH_MAX=18, MATH_MIN=19, MATH_MODF=20, MATH_POW=21, MATH_RAD=22, MATH_SINH=23,
  MATH_SIN=24, MATH_SQRT=25, MATH_TANH=26, MATH_TAN=27, BIT32_ARSHIFT=28, BIT32_BAND=29, BIT32_BNOT=30,
  BIT32_BOR=31, BIT32_BXOR=32, BIT32_BTEST=33, BIT32_EXTRACT=34, BIT32_LROTATE=35, BIT32_LSHIFT=36,
  BIT32_REPLACE=37, BIT32_RROTATE=38, BIT32_RSHIFT=39, TYPE=40, STRING_BYTE=41, STRING_CHAR=42,
  STRING_LEN=43, TYPEOF=44, STRING_SUB=45, MATH_CLAMP=46, MATH_SIGN=47, MATH_ROUND=48, RAWSET=49, RAWGET=50,
  RAWEQUAL=51, TABLE_INSERT=52, TABLE_UNPACK=53, VECTOR=54, BIT32_COUNTLZ=55, BIT32_COUNTRZ=56,
  SELECT_VARARG=57, RAWLEN=58, BIT32_EXTRACTK=59, GETMETATABLE=60, SETMETATABLE=61, TONUMBER=62, TOSTRING=63,
  BIT32_BYTESWAP=64, BUFFER_READI8=65, BUFFER_READU8=66, BUFFER_WRITEU8=67, BUFFER_READI16=68,
  BUFFER_READU16=69, BUFFER_WRITEU16=70, BUFFER_READI32=71, BUFFER_READU32=72, BUFFER_WRITEU32=73,
  BUFFER_READF32=74, BUFFER_WRITEF32=75, BUFFER_READF64=76, BUFFER_WRITEF64=77, VECTOR_MAGNITUDE=78,
  VECTOR_NORMALIZE=79, VECTOR_CROSS=80, VECTOR_DOT=81, VECTOR_FLOOR=82, VECTOR_CEIL=83, VECTOR_ABS=84,
  VECTOR_SIGN=85, VECTOR_CLAMP=86, VECTOR_MIN=87, VECTOR_MAX=88, MATH_LERP=89, VECTOR_LERP=90, MATH_ISNAN=91,
  MATH_ISINF=92, MATH_ISFINITE=93, TABLE_CREATE=133, TABLE_CLEAR=134,
}
local function raise(line, fmt, ...)
	error(string.format(":%d: ", line or 0) .. string.format(fmt, ...), 0)
end

local function forEachChild(node, f)
	local k = node.k
	if k == "Call" then
		f(node.func)
		for _, a in node.args do
			f(a)
		end
	elseif k == "IndexName" or k == "Assert" or k == "Group" or k == "Unary" then
		f(node.expr)
	elseif k == "IndexExpr" then
		f(node.expr)
		f(node.index)
	elseif k == "Function" then
		f(node.body)
	elseif k == "Table" then
		for _, item in node.items do
			if item.key then
				f(item.key)
			end
			f(item.value)
		end
	elseif k == "Binary" then
		f(node.left)
		f(node.right)
	elseif k == "IfElse" then
		f(node.condition)
		f(node.trueExpr)
		f(node.falseExpr)
	elseif k == "Interp" then
		for _, e in node.expressions do
			f(e)
		end
	elseif k == "Block" then
		for _, s in node.body do
			f(s)
		end
	elseif k == "If" then
		f(node.condition)
		f(node.thenbody)
		if node.elsebody then
			f(node.elsebody)
		end
	elseif k == "While" then
		f(node.condition)
		f(node.body)
	elseif k == "Repeat" then
		f(node.body)
		f(node.condition)
	elseif k == "Return" then
		for _, e in node.list do
			f(e)
		end
	elseif k == "ExprStat" then
		f(node.expr)
	elseif k == "LocalStat" then
		for _, e in node.values do
			f(e)
		end
	elseif k == "For" then
		f(node.from)
		f(node.to)
		if node.step then
			f(node.step)
		end
		f(node.body)
	elseif k == "ForIn" then
		for _, e in node.values do
			f(e)
		end
		f(node.body)
	elseif k == "Assign" then
		for _, e in node.vars do
			f(e)
		end
		for _, e in node.values do
			f(e)
		end
	elseif k == "CompoundAssign" then
		f(node.var)
		f(node.value)
	elseif k == "FunctionStat" then
		f(node.name)
		f(node.func)
	elseif k == "LocalFunction" then
		f(node.func)
	end
end

local function collectFunctions(node, list)
	forEachChild(node, function(c)
		collectFunctions(c, list)
	end)
	if node.k == "Function" then
		list[#list + 1] = node
	end
end

local BUILTIN_IDS = {}
do
	local function reg(prefix, names)
		for _, n in names do
			BUILTIN_IDS[prefix .. n] = LBF[(prefix == "" and "" or prefix:sub(1, -2):upper() .. "_") .. n:upper()]
		end
	end
	for _, n in { "assert", "type", "typeof", "rawset", "rawget", "rawequal", "rawlen", "getmetatable", "setmetatable", "tonumber", "tostring" } do
		BUILTIN_IDS[n] = LBF[n:upper()]
	end
	BUILTIN_IDS["unpack"] = LBF.TABLE_UNPACK
	BUILTIN_IDS["select"] = LBF.SELECT_VARARG
	reg("math.", { "abs", "acos", "asin", "atan2", "atan", "ceil", "cosh", "cos", "deg", "exp", "floor", "fmod", "frexp", "ldexp", "log10", "log", "max", "min", "modf", "pow", "rad", "sinh", "sin", "sqrt", "tanh", "tan", "clamp", "sign", "round", "lerp", "isnan", "isinf", "isfinite" })
	reg("bit32.", { "arshift", "band", "bnot", "bor", "bxor", "btest", "extract", "lrotate", "lshift", "replace", "rrotate", "rshift", "countlz", "countrz", "byteswap" })
	reg("string.", { "byte", "char", "len", "sub" })
	reg("table.", { "insert", "unpack", "create", "clear" })
	BUILTIN_IDS["buffer.readi8"] = LBF.BUFFER_READI8
	BUILTIN_IDS["buffer.readu8"] = LBF.BUFFER_READU8
	BUILTIN_IDS["buffer.writei8"] = LBF.BUFFER_WRITEU8
	BUILTIN_IDS["buffer.writeu8"] = LBF.BUFFER_WRITEU8
	BUILTIN_IDS["buffer.readi16"] = LBF.BUFFER_READI16
	BUILTIN_IDS["buffer.readu16"] = LBF.BUFFER_READU16
	BUILTIN_IDS["buffer.writei16"] = LBF.BUFFER_WRITEU16
	BUILTIN_IDS["buffer.writeu16"] = LBF.BUFFER_WRITEU16
	BUILTIN_IDS["buffer.readi32"] = LBF.BUFFER_READI32
	BUILTIN_IDS["buffer.readu32"] = LBF.BUFFER_READU32
	BUILTIN_IDS["buffer.writei32"] = LBF.BUFFER_WRITEU32
	BUILTIN_IDS["buffer.writeu32"] = LBF.BUFFER_WRITEU32
	BUILTIN_IDS["buffer.readf32"] = LBF.BUFFER_READF32
	BUILTIN_IDS["buffer.writef32"] = LBF.BUFFER_WRITEF32
	BUILTIN_IDS["buffer.readf64"] = LBF.BUFFER_READF64
	BUILTIN_IDS["buffer.writef64"] = LBF.BUFFER_WRITEF64
	for _, n in { "magnitude", "normalize", "cross", "dot", "floor", "ceil", "abs", "sign", "clamp", "min", "max", "lerp" } do
		BUILTIN_IDS["vector." .. n] = LBF["VECTOR_" .. n:upper()]
	end
	BUILTIN_IDS["vector.create"] = LBF.VECTOR
end

local C = {}
C.__index = C

local function newCompiler(builder, options)
	local self = setmetatable({}, C)
	self.b = builder
	self.opt = options.optimizationLevel
	self.cov = options.coverageLevel or 0
	self.inlineFrames = {}
	self.version = options.version or 6
	self.dbg = options.debugLevel
	self.constants = {}
	self.variables = {}
	self.globals = { _G = "Mutable" }
	self.builtins = {}
	self.tableShapes = {}
	self.shapeTables = {}
	self.shapeFields = {}
	self.shapeLoops = {}
	self.locals = {}
	self.locstants = {}
	self.functions = {}
	self.upvals = {}
	self.localStack = {}
	self.regTop = 0
	self.stackSize = 0
	self.loops = {}
	self.loopJumps = {}
	self.hasLoops = false
	self.hasMultiRet = false
	self.setfenvUsed = false
	self.getfenvUsed = false
	for name, v in pairs(options.mutableGlobals or {}) do
		self.globals[type(name) == "string" and name or v] = "Mutable"
	end
	return self
end

function C:getVar(l)
	local v = self.variables[l]
	if not v then
		v = { written = false, constant = false }
		self.variables[l] = v
	end
	return v
end

function C:trackValues(node)
	local k = node.k
	if k == "LocalStat" then
		for i, var in node.vars do
			self:getVar(var).init = node.values[i]
		end
	elseif k == "If" or k == "IfElse" then
		if node.conditionLocal then
			self:getVar(node.conditionLocal).init = node.condition
		end
	elseif k == "Assign" then
		for _, v in node.vars do
			self:assignVar(v)
		end
		for _, v in node.values do
			self:trackValues(v)
		end
		return
	elseif k == "CompoundAssign" then
		self:assignVar(node.var)
		self:trackValues(node.value)
		return
	elseif k == "LocalFunction" then
		self:getVar(node.name).init = node.func
	elseif k == "FunctionStat" then
		self:assignVar(node.name)
		self:trackValues(node.func)
		return
	elseif k == "Function" then
		for _, a in node.args do
			self:getVar(a).init = nil
		end
	end
	forEachChild(node, function(c)
		self:trackValues(c)
	end)
end

function C:assignVar(v)
	if v.k == "Local" then
		self:getVar(v["local"]).written = true
	elseif v.k == "Global" then
		self.globals[v.name] = "Written"
	else
		self:trackValues(v)
	end
end

function C:scanFenv(node)
	if node.k == "Global" then
		if node.name == "getfenv" then
			self.getfenvUsed = true
		elseif node.name == "setfenv" then
			self.setfenvUsed = true
		end
	end
	forEachChild(node, function(c)
		self:scanFenv(c)
	end)
end

function C:globalState(name)
	return self.globals[name] or "Default"
end

function C:getBuiltin(node)
	local k = node.k
	if k == "Local" then
		local v = self.variables[node["local"]]
		if v and not v.written and v.init then
			return self:getBuiltin(v.init)
		end
	elseif k == "IndexName" then
		local e = node.expr
		if e.k == "Local" then
			local v = self.variables[e["local"]]
			if v and not v.written and v.init then
				local object
				if v.init.k == "Global" then
					object = v.init
				elseif v.init.k == "Binary" and v.init.op == "Or" and v.init.left.k == "Global" then
					object = v.init.left
				end
				if object and self:globalState(object.name) == "Default" then
					return object.name, node.index
				end
			end
		elseif e.k == "Global" then
			if self:globalState(e.name) == "Default" then
				return e.name, node.index
			end
		end
	elseif k == "Global" then
		if self:globalState(node.name) == "Default" then
			return nil, node.name
		end
	end
	return nil, nil
end

function C:analyzeBuiltins(node)
	if node.k == "Call" and not node.self then
		local object, method = self:getBuiltin(node.func)
		if method then
			local id = BUILTIN_IDS[object and (object .. "." .. method) or method]
			if id == LBF.SELECT_VARARG and not (#node.args == 2 and node.args[2].k == "Varargs") then
				id = nil
			end
			if id then
				self.builtins[node] = id
			end
		end
	end
	forEachChild(node, function(c)
		self:analyzeBuiltins(c)
	end)
end

local function truthy(c)
	return not (c.t == "nil" or (c.t == "boolean" and c.v == false))
end

local function constantsEqual(a, b)
	if a.t ~= b.t then
		return false
	end
	if a.t == "nil" then
		return true
	end
	if a.t == "integer" then
		return a.hi == b.hi and a.lo == b.lo
	end
	return a.v == b.v
end

local function foldUnary(op, arg)
	if op == "Not" then
		return { t = "boolean", v = not truthy(arg) }
	elseif op == "Minus" then
		if arg.t == "number" then
			return { t = "number", v = -arg.v }
		end
	elseif op == "Len" then
		if arg.t == "string" then
			return { t = "number", v = #arg.v }
		end
	end
	return nil
end

local function foldBinary(op, la, ra)
	local ln = ra ~= nil and la.t == "number" and ra.t == "number"
	if op == "Add" then
		if ln then return { t = "number", v = la.v + ra.v } end
	elseif op == "Sub" then
		if ln then return { t = "number", v = la.v - ra.v } end
	elseif op == "Mul" then
		if ln then return { t = "number", v = la.v * ra.v } end
	elseif op == "Div" then
		if ln then return { t = "number", v = la.v / ra.v } end
	elseif op == "FloorDiv" then
		if ln then return { t = "number", v = math.floor(la.v / ra.v) } end
	elseif op == "Mod" then
		if ln then return { t = "number", v = la.v - math.floor(la.v / ra.v) * ra.v } end
	elseif op == "Pow" then
		if ln then return { t = "number", v = la.v ^ ra.v } end
	elseif op == "Concat" then
		if ra and la.t == "string" and ra.t == "string" and #la.v + #ra.v <= 4096 then
			return { t = "string", v = la.v .. ra.v }
		end
	elseif op == "CompareNe" then
		if ra then return { t = "boolean", v = not constantsEqual(la, ra) } end
	elseif op == "CompareEq" then
		if ra then return { t = "boolean", v = constantsEqual(la, ra) } end
	elseif op == "CompareLt" then
		if ln then return { t = "boolean", v = la.v < ra.v } end
	elseif op == "CompareLe" then
		if ln then return { t = "boolean", v = la.v <= ra.v } end
	elseif op == "CompareGt" then
		if ln then return { t = "boolean", v = la.v > ra.v } end
	elseif op == "CompareGe" then
		if ln then return { t = "boolean", v = la.v >= ra.v } end
	elseif op == "And" then
		if truthy(la) then return ra end
		return la
	elseif op == "Or" then
		if truthy(la) then return la end
		return ra
	end
	return nil
end

function C:analyze(node)
	local k = node.k
	local result
	if k == "Group" or k == "Assert" then
		result = self:analyze(node.expr)
	elseif k == "Nil" then
		result = { t = "nil" }
	elseif k == "Bool" then
		result = { t = "boolean", v = node.value }
	elseif k == "Num" then
		result = { t = "number", v = node.value }
	elseif k == "Int" then
		result = { t = "integer", hi = node.hi, lo = node.lo }
	elseif k == "Str" then
		result = { t = "string", v = node.value }
	elseif k == "Local" then
		result = self.locstants[node["local"]]
	elseif k == "Call" then
		self:analyze(node.func)
		local argc = {}
		local allKnown = true
		for i, a in node.args do
			argc[i] = self:analyze(a)
			if not argc[i] then
				allKnown = false
			end
		end
		if allKnown and self.opt >= 2 then
			result = self:foldBuiltinCall(node, argc)
		end
	elseif k == "IndexName" then
		self:analyze(node.expr)
		if self.opt >= 2 and node.expr.k == "Global" and node.expr.name == "math" and self:globalState("math") == "Default" then
			if node.index == "pi" then
				result = { t = "number", v = math.pi }
			elseif node.index == "huge" then
				result = { t = "number", v = math.huge }
			end
		end
	elseif k == "IndexExpr" then
		self:analyze(node.expr)
		self:analyze(node.index)
	elseif k == "Function" then
		self:foldStat(node.body)
	elseif k == "Table" then
		for _, item in node.items do
			if item.key then
				self:analyze(item.key)
			end
			self:analyze(item.value)
		end
	elseif k == "Unary" then
		local arg = self:analyze(node.expr)
		if arg then
			result = foldUnary(node.op, arg)
		end
	elseif k == "Binary" then
		local la = self:analyze(node.left)
		local ra = self:analyze(node.right)
		if la then
			result = foldBinary(node.op, la, ra)
		end
	elseif k == "IfElse" then
		if node.conditionLocal then
			self:analyze(node.condition)
			self:analyze(node.trueExpr)
			self:analyze(node.falseExpr)
			return nil
		end
		local cond = self:analyze(node.condition)
		local t = self:analyze(node.trueExpr)
		local f = self:analyze(node.falseExpr)
		if cond then
			result = truthy(cond) and t or f
		end
	elseif k == "Interp" then
		local all = true
		local parts = {}
		for i, e in node.expressions do
			local c = self:analyze(e)
			if not c or c.t ~= "string" then
				all = false
			end
			parts[i] = c
		end
		if all then
			local out = { node.strings[1] }
			for i = 1, #parts do
				out[#out + 1] = parts[i].v
				out[#out + 1] = node.strings[i + 1]
			end
			local s = table.concat(out)
			if #s <= 4096 then
				result = { t = "string", v = s }
			end
		end
	end
	local old = self.constants[node]
	if old ~= result then
		local log = self.changeLog
		if log then
			log[#log + 1] = { self.constants, node, old }
		end
		self.constants[node] = result
	end
	return result
end

function C:recordLocalConstant(var, c)
	local v = self:getVar(var)
	if not v.written then
		local log = self.changeLog
		if log then
			log[#log + 1] = { v, "constant", v.constant }
			log[#log + 1] = { self.locstants, var, self.locstants[var] }
		end
		v.constant = c ~= nil
		self.locstants[var] = c
	end
end

function C:foldStat(node)
	local k = node.k
	if k == "LocalStat" then
		for i, var in node.vars do
			local value = node.values[i]
			if value then
				self:recordLocalConstant(var, self:analyze(value))
			end
		end
		local nv, nvars = #node.values, #node.vars
		if nvars > nv then
			local last = node.values[nv]
			local multRet = last and (last.k == "Call" or last.k == "Varargs")
			if not multRet then
				for i = nv + 1, nvars do
					self:recordLocalConstant(node.vars[i], { t = "nil" })
				end
			end
		else
			for i = nvars + 1, nv do
				self:analyze(node.values[i])
			end
		end
		return
	end
	forEachChild(node, function(c)
		if c.k == "Block" or c.k == "If" or c.k == "While" or c.k == "Repeat" or c.k == "Break" or c.k == "Continue"
			or c.k == "Return" or c.k == "ExprStat" or c.k == "LocalStat" or c.k == "For" or c.k == "ForIn" or c.k == "Assign"
			or c.k == "CompoundAssign" or c.k == "FunctionStat" or c.k == "LocalFunction" or c.k == "TypeAlias" then
			self:foldStat(c)
		else
			self:analyze(c)
		end
	end)
end

local function getTableHint(expr)
	if expr.k == "Table" then
		return expr
	end
	if expr.k == "Call" and not expr.self and #expr.args == 2 and expr.func.k == "Global" and expr.func.name == "setmetatable" then
		if expr.args[1].k == "Table" then
			return expr.args[1]
		end
	end
	return nil
end

function C:shapeOf(tbl)
	local s = self.tableShapes[tbl]
	if not s then
		s = { hashSize = 0, arraySize = 0 }
		self.tableShapes[tbl] = s
	end
	return s
end

function C:assignShape(var)
	local k = var.k
	if (k ~= "IndexName" and k ~= "IndexExpr") or var.expr.k ~= "Local" then
		return
	end
	local tbl = self.shapeTables[var.expr["local"]]
	if not tbl then
		return
	end
	if k == "IndexName" then
		local key = var.index
		self.shapeFields[tbl] = self.shapeFields[tbl] or {}
		if not self.shapeFields[tbl][key] then
			self.shapeFields[tbl][key] = true
			self:shapeOf(tbl).hashSize += 1
		end
	else
		local index = var.index
		if index.k == "Num" then
			local shape = self:shapeOf(tbl)
			if index.value == shape.arraySize + 1 then
				shape.arraySize += 1
			end
		elseif index.k == "Local" then
			local bound = self.shapeLoops[index["local"]]
			if bound then
				local shape = self:shapeOf(tbl)
				if shape.arraySize == 0 then
					shape.arraySize = bound
				end
			end
		end
	end
end

function C:predictShapes(node)
	local k = node.k
	if k == "LocalStat" then
		if #node.vars == 1 and #node.values == 1 then
			local tbl = getTableHint(node.values[1])
			if tbl and #tbl.items == 0 then
				self.shapeTables[node.vars[1]] = tbl
			end
		end
	elseif k == "Assign" then
		for _, v in node.vars do
			self:assignShape(v)
		end
		for _, v in node.values do
			self:predictShapes(v)
		end
		return
	elseif k == "FunctionStat" then
		self:assignShape(node.name)
		self:predictShapes(node.func)
		return
	elseif k == "For" then
		local from, to = node.from, node.to
		if from.k == "Num" and to.k == "Num" and from.value == 1 and to.value >= 1 and to.value <= 16 and not node.step then
			self.shapeLoops[node.var] = to.value
		end
	end
	forEachChild(node, function(c)
		self:predictShapes(c)
	end)
end

local FOLD = {}
do
	local function reg(name, f)
		local id = BUILTIN_IDS[name]
		if id then
			FOLD[id] = f
		end
	end
	local function numeric(f)
		return function(args)
			local vals = {}
			for i, a in args do
				if a.t ~= "number" then
					return nil
				end
				vals[i] = a.v
			end
			local ok, r = pcall(f, table.unpack(vals))
			if ok and type(r) == "number" then
				return { t = "number", v = r }
			end
			return nil
		end
	end
	local function boolean(f)
		return function(args)
			local vals = {}
			for i, a in args do
				if a.t ~= "number" then
					return nil
				end
				vals[i] = a.v
			end
			local ok, r = pcall(f, table.unpack(vals))
			if ok and type(r) == "boolean" then
				return { t = "boolean", v = r }
			end
			return nil
		end
	end
	for _, n in { "abs", "acos", "asin", "atan2", "atan", "ceil", "cosh", "cos", "deg", "exp", "floor", "fmod", "ldexp", "log10", "log", "max", "min", "pow", "rad", "sinh", "sin", "sqrt", "tanh", "tan" } do
		if math[n] then
			reg("math." .. n, numeric(math[n]))
		end
	end
	reg("math.clamp", numeric(function(x, lo, hi)
		if lo > hi then
			error("invalid clamp")
		end
		return math.min(math.max(x, lo), hi)
	end))
	reg("math.sign", numeric(function(x)
		return x > 0 and 1 or (x < 0 and -1 or 0)
	end))
	reg("math.round", numeric(function(x)
		if x ~= x or x == math.huge or x == -math.huge then
			return x
		end
		return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
	end))
	reg("math.lerp", numeric(function(a, b, t)
		if t == 1 then
			return b
		end
		return a + (b - a) * t
	end))
	reg("math.isnan", boolean(function(x)
		return x ~= x
	end))
	reg("math.isinf", boolean(function(x)
		return x == math.huge or x == -math.huge
	end))
	reg("math.isfinite", boolean(function(x)
		return x == x and x ~= math.huge and x ~= -math.huge
	end))
	for _, n in { "arshift", "band", "bnot", "bor", "bxor", "lrotate", "lshift", "replace", "rrotate", "rshift", "extract", "countlz", "countrz", "byteswap" } do
		if bit32[n] then
			reg("bit32." .. n, numeric(bit32[n]))
		end
	end
	if bit32.btest then
		reg("bit32.btest", boolean(bit32.btest))
	end
	local function typeName(args)
		if #args ~= 1 then
			return nil
		end
		return { t = "string", v = args[1].t }
	end
	reg("type", typeName)
	reg("typeof", typeName)
	reg("string.len", function(args)
		if #args == 1 and args[1].t == "string" then
			return { t = "number", v = #args[1].v }
		end
	end)
	reg("string.sub", function(args)
		if (#args == 2 or #args == 3) and args[1].t == "string" and args[2].t == "number" and (not args[3] or args[3].t == "number") then
			local ok, r = pcall(string.sub, args[1].v, args[2].v, args[3] and args[3].v)
			if ok and #r <= 4096 then
				return { t = "string", v = r }
			end
		end
	end)
	reg("string.char", function(args)
		local vals = {}
		for i, a in args do
			if a.t ~= "number" then
				return nil
			end
			vals[i] = a.v
		end
		if #vals == 0 then
			return nil
		end
		local ok, r = pcall(string.char, table.unpack(vals))
		if ok then
			return { t = "string", v = r }
		end
	end)
	reg("string.byte", function(args)
		if #args >= 1 and #args <= 3 and args[1].t == "string" then
			local vals = {}
			for i = 2, #args do
				if args[i].t ~= "number" then
					return nil
				end
				vals[i - 1] = args[i].v
			end
			local ok, r = pcall(function()
				return { string.byte(args[1].v, table.unpack(vals)) }
			end)
			if ok and #r == 1 then
				return { t = "number", v = r[1] }
			end
		end
	end)
end

function C:foldBuiltinCall(node, args)
	local id = self.builtins[node]
	local f = id and FOLD[id]
	if f then
		return f(args)
	end
	return nil
end

function C:modelCost(node, varc)
	local k = node.k
	if k == "Nil" or k == "Bool" or k == "Num" or k == "Str" or k == "Int" then
		return 0, true
	elseif k == "Local" then
		return 0, varc[node["local"]] == true or self.locstants[node["local"]] ~= nil
	elseif k == "Global" then
		return 1, false
	elseif k == "Varargs" then
		return 3, false
	elseif k == "Group" or k == "Assert" then
		return self:modelCost(node.expr, varc)
	elseif k == "Unary" then
		local c, isc = self:modelCost(node.expr, varc)
		if isc then
			return 0, true
		end
		return c + 1, false
	elseif k == "Binary" then
		local l, lc = self:modelCost(node.left, varc)
		local r, rc = self:modelCost(node.right, varc)
		if lc and rc then
			return 0, true
		end
		return l + r + 1, false
	elseif k == "IndexName" then
		local c = self:modelCost(node.expr, varc)
		return c + 1, false
	elseif k == "IndexExpr" then
		local a = self:modelCost(node.expr, varc)
		local b = self:modelCost(node.index, varc)
		return a + b + 1, false
	elseif k == "Call" then
		local total, allc = 3, true
		total += self:modelCost(node.func, varc)
		local bf = self.builtins[node]
		for _, a in node.args do
			local c, isc = self:modelCost(a, varc)
			total += c
			if not isc then
				allc = false
			end
		end
		if bf and allc and FOLD[bf] then
			return 0, true
		end
		return total, false
	elseif k == "Function" then
		return 10, false
	elseif k == "Table" then
		local total = 2
		for _, item in node.items do
			if item.key then
				total += self:modelCost(item.key, varc)
			end
			total += self:modelCost(item.value, varc) + 1
		end
		return total, false
	elseif k == "IfElse" then
		local c1 = self:modelCost(node.condition, varc)
		local c2 = self:modelCost(node.trueExpr, varc)
		local c3 = self:modelCost(node.falseExpr, varc)
		return c1 + c2 + c3 + 2, false
	elseif k == "Interp" then
		local total = 3
		for _, e in node.expressions do
			total += self:modelCost(e, varc)
		end
		return total, false
	end
	local total = 0
	if k == "Block" then
		for _, st in node.body do
			total += self:modelCost(st, varc)
		end
		return total, false
	elseif k == "If" then
		return 2 + self:modelCost(node.condition, varc) + self:modelCost(node.thenbody, varc) + (node.elsebody and self:modelCost(node.elsebody, varc) or 0), false
	elseif k == "While" or k == "Repeat" then
		return 5 + self:modelCost(node.condition, varc) + self:modelCost(node.body, varc) * 5, false
	elseif k == "For" then
		return 5 + self:modelCost(node.body, varc) * 5, false
	elseif k == "ForIn" then
		for _, e in node.values do
			total += self:modelCost(e, varc)
		end
		return 5 + total + self:modelCost(node.body, varc) * 5, false
	elseif k == "Return" then
		for _, e in node.list do
			total += self:modelCost(e, varc)
		end
		return 1 + total, false
	elseif k == "ExprStat" then
		return self:modelCost(node.expr, varc), false
	elseif k == "LocalStat" then
		for _, e in node.values do
			total += self:modelCost(e, varc)
		end
		return #node.vars + total, false
	elseif k == "Assign" then
		for _, e in node.vars do
			total += self:modelCost(e, varc)
		end
		for _, e in node.values do
			total += self:modelCost(e, varc)
		end
		return 1 + total, false
	elseif k == "CompoundAssign" then
		return 1 + self:modelCost(node.var, varc) + self:modelCost(node.value, varc), false
	elseif k == "FunctionStat" then
		return 2 + self:modelCost(node.name, varc) + 10, false
	elseif k == "LocalFunction" then
		return 10, false
	elseif k == "Break" or k == "Continue" then
		return 1, false
	end
	return 0, false
end

function C:undoLog(log)
	for i = #log, 1, -1 do
		local e = log[i]
		e[1][e[2]] = e[3]
	end
end

function C:getFunctionExpr(node)
	local k = node.k
	if k == "Local" then
		local v = self.variables[node["local"]]
		if not v or v.written or not v.init then
			return nil
		end
		return self:getFunctionExpr(v.init)
	elseif k == "Group" or k == "Assert" then
		return self:getFunctionExpr(node.expr)
	elseif k == "Function" then
		return node
	end
	return nil
end

local ONE_RESULT = {}
do
	for name, id in BUILTIN_IDS do
		local lib, fn = name:match("^(%a+)%.(%w+)$")
		if lib == "math" then
			if fn ~= "frexp" and fn ~= "modf" then
				ONE_RESULT[id] = true
			end
		elseif lib == "bit32" then
			ONE_RESULT[id] = true
		elseif name == "string.len" or name == "string.sub" or name == "string.char" then
			ONE_RESULT[id] = true
		end
	end
	for _, n in { "type", "typeof", "rawlen", "rawequal", "rawget", "rawset", "getmetatable", "setmetatable", "tonumber", "tostring" } do
		ONE_RESULT[BUILTIN_IDS[n]] = true
	end
end

local function unwrap(node)
	while node.k == "Group" or node.k == "Assert" do
		node = node.expr
	end
	return node
end

local ARITH = { Add = "ADD", Sub = "SUB", Mul = "MUL", Div = "DIV", FloorDiv = "IDIV", Mod = "MOD", Pow = "POW" }
local ARITHK = { Add = "ADDK", Sub = "SUBK", Mul = "MULK", Div = "DIVK", FloorDiv = "IDIVK", Mod = "MODK", Pow = "POWK" }
local ISCOMPARE = { CompareNe = true, CompareEq = true, CompareLt = true, CompareLe = true, CompareGt = true, CompareGe = true }

function C:allocReg(node, count)
	local top = self.regTop
	if top + count > 255 then
		raise(node.line, "Out of registers when trying to allocate %d registers: exceeded limit %d", count, 255)
	end
	self.regTop = top + count
	if self.regTop > self.stackSize then
		self.stackSize = self.regTop
	end
	return top
end

function C:setDebugLine(node)
	if self.dbg >= 1 then
		self.b:setDebugLine(type(node) == "number" and node or node.line)
	end
end

function C:setDebugLineEnd(node)
	if self.dbg >= 1 then
		self.b:setDebugLine(node.eline)
	end
end

function C:isConstant(node)
	return self.constants[node] ~= nil
end

function C:isConstantTrue(node)
	local c = self.constants[node]
	return c ~= nil and truthy(c)
end

function C:isConstantFalse(node)
	local c = self.constants[node]
	return c ~= nil and not truthy(c)
end

function C:getConstantNumber(node)
	local c = self.constants[node]
	if c and c.t == "number" then
		local cid = self.b:addConstantNumber(c.v)
		if cid < 0 then
			raise(node.line, "Exceeded constant limit; simplify the code to compile")
		end
		return cid
	end
	return -1
end

function C:getConstantIndex(node)
	local c = self.constants[node]
	if not c then
		return -1
	end
	local b = self.b
	local cid
	if c.t == "integer" then
		cid = self:integerConst(node, c.hi, c.lo)
	elseif c.t == "nil" then
		cid = b:addConstantNil()
	elseif c.t == "boolean" then
		cid = b:addConstantBoolean(c.v)
	elseif c.t == "number" then
		cid = b:addConstantNumber(c.v)
	else
		cid = b:addConstantString(c.v)
	end
	if cid < 0 then
		raise(node.line, "Exceeded constant limit; simplify the code to compile")
	end
	return cid
end

function C:integerConst(node, hi, lo)
	if self.version < 8 then
		raise(node.line, "Integer literals require bytecode version 8 or newer")
	end
	local cid = self.b:addConstantInteger(hi, lo)
	if cid < 0 then
		raise(node.line, "Exceeded constant limit; simplify the code to compile")
	end
	return cid
end

function C:emitLoadK(target, cid)
	if cid < 32768 then
		self.b:emitAD(OP.LOADK, target, cid)
	else
		self.b:emitAD(OP.LOADKX, target, 0)
		self.b:emitAux(cid)
	end
end

function C:stringConst(node, s)
	local cid = self.b:addConstantString(s)
	if cid < 0 then
		raise(node.line, "Exceeded constant limit; simplify the code to compile")
	end
	return cid
end

function C:getExprLocalReg(node)
	node = unwrap(node)
	if node.k == "Local" then
		local l = self.locals[node["local"]]
		if l and l.allocated then
			return l.reg
		end
	end
	return -1
end

function C:getUpval(l)
	for i, u in self.upvals do
		if u == l then
			return i - 1
		end
	end
	if #self.upvals >= 200 then
		raise(l.line, "Out of upvalue registers when trying to allocate %s: exceeded limit %d", l.name, 200)
	end
	local v = self.variables[l]
	if v and v.written then
		local rec = self.locals[l]
		if not rec then
			rec = { allocated = false, captured = false }
			self.locals[l] = rec
		end
		rec.captured = true
	end
	self.upvals[#self.upvals + 1] = l
	return #self.upvals - 1
end

function C:pushLocal(l, reg)
	if #self.localStack >= 200 then
		raise(l.line, "Out of local registers when trying to allocate %s: exceeded limit %d", l.name, 200)
	end
	self.localStack[#self.localStack + 1] = l
	local rec = self.locals[l]
	if not rec then
		rec = { captured = false }
		self.locals[l] = rec
	end
	rec.reg = reg
	rec.allocated = true
	rec.debugpc = self.b:getDebugPC()
end

function C:areLocalsCaptured(start)
	for i = start + 1, #self.localStack do
		if self.locals[self.localStack[i]].captured then
			return true
		end
	end
	return false
end

function C:closeLocals(start)
	local captured = false
	local captureReg = 255
	for i = start + 1, #self.localStack do
		local l = self.locals[self.localStack[i]]
		if l.captured then
			captured = true
			if l.reg < captureReg then
				captureReg = l.reg
			end
		end
	end
	if captured then
		self.b:emitABC(OP.CLOSEUPVALS, captureReg, 0, 0)
	end
end

function C:popLocals(start)
	local st = self.localStack
	for i = start + 1, #st do
		local l = self.locals[st[i]]
		l.allocated = false
		if self.dbg >= 2 then
			self.b:pushDebugLocal(st[i].name, l.reg, l.debugpc, self.b:getDebugPC())
		end
	end
	for i = #st, start + 1, -1 do
		st[i] = nil
	end
end

function C:patchJump(node, label, target)
	if not self.b:patchJumpD(label, target) then
		raise(node.line, "Exceeded jump distance limit; simplify the code to compile")
	end
end

function C:patchJumps(node, labels, target)
	for _, l in labels do
		self:patchJump(node, l, target)
	end
end

function C:patchLoopJumps(node, oldJumps, endLabel, contLabel)
	for i = oldJumps + 1, #self.loopJumps do
		local lj = self.loopJumps[i]
		if lj.type == "break" then
			self:patchJump(node, lj.label, endLabel)
		else
			self:patchJump(node, lj.label, contLabel)
		end
	end
end

function C:isExprMultRet(node)
	if node.k == "Call" then
		if self.opt >= 2 then
			if self.constants[node] then
				return false
			end
			local id = self.builtins[node]
			if id and ONE_RESULT[id] then
				return false
			end
			local func = self:getFunctionExpr(node.func)
			local fi = func and self.functions[func]
			if fi and fi.returnsOne then
				return false
			end
		end
		return true
	end
	return node.k == "Varargs"
end

function C:compileExprConstant(node, c, target)
	local t = c.t
	local b = self.b
	if t == "nil" then
		b:emitABC(OP.LOADNIL, target, 0, 0)
	elseif t == "boolean" then
		b:emitABC(OP.LOADB, target, c.v and 1 or 0, 0)
	elseif t == "number" then
		local d = c.v
		if d >= -32768 and d <= 32767 and d == math.floor(d) and not (d == 0 and 1 / d < 0) then
			b:emitAD(OP.LOADN, target, d)
		else
			local cid = b:addConstantNumber(d)
			if cid < 0 then
				raise(node.line, "Exceeded constant limit; simplify the code to compile")
			end
			self:emitLoadK(target, cid)
		end
	elseif t == "integer" then
		self:emitLoadK(target, self:integerConst(node, c.hi, c.lo))
	else
		self:emitLoadK(target, self:stringConst(node, c.v))
	end
end

function C:compileExprTempMultRet(node, target)
	if node.k == "Call" and self.opt >= 2 and not self:isExprMultRet(node) then
		self:compileExprTemp(node, target)
		return false
	end
	if node.k == "Call" then
		local rt = self.regTop
		self.regTop = target
		self:compileExprCall(node, target, 0, true, true)
		self.regTop = rt
		return true
	elseif node.k == "Varargs" then
		local rt = self.regTop
		self.regTop = target
		self:compileExprVarargs(node, target, 0, true)
		self.regTop = rt
		return true
	end
	self:compileExprTemp(node, target)
	return false
end

function C:compileExprTempTop(node, target)
	local rt = self.regTop
	self.regTop = target + 1
	self:compileExprTemp(node, target)
	self.regTop = rt
end

function C:compileExprVarargs(expr, target, targetCount, multRet)
	self:setDebugLine(expr)
	self.b:emitABC(OP.GETVARARGS, target, multRet and 0 or targetCount + 1, 0)
end

function C:compileExprFastcallN(expr, target, targetCount, targetTop, multRet, regs, bfid)
	local b = self.b
	local nargs = #expr.args
	local opc
	if nargs == 1 then
		opc = OP.FASTCALL1
	elseif nargs == 2 and self:isConstant(expr.args[2]) then
		opc = OP.FASTCALL2K
	elseif nargs == 2 then
		opc = OP.FASTCALL2
	else
		opc = OP.FASTCALL3
	end
	local args = {}
	for i = 1, nargs do
		local a = expr.args[i]
		if i > 1 and opc == OP.FASTCALL2K then
			local cid = self:getConstantIndex(a)
			if cid < 0 then
				raise(expr.line, "Exceeded constant limit; simplify the code to compile")
			end
			args[i] = cid
		else
			local reg = self:getExprLocalReg(a)
			if reg >= 0 then
				args[i] = reg
			else
				args[i] = regs + i
				self:compileExprTempTop(a, args[i])
			end
		end
	end
	local fastcallLabel = b:emitLabel()
	b:emitABC(opc, bfid, args[1], 0)
	if opc == OP.FASTCALL3 then
		b:emitAux(args[2] + args[3] * 256)
	elseif opc ~= OP.FASTCALL1 then
		b:emitAux(args[2])
	end
	for i = 1, nargs do
		if i > 1 and opc == OP.FASTCALL2K then
			self:emitLoadK(regs + i, args[i])
		elseif args[i] ~= regs + i then
			b:emitABC(OP.MOVE, regs + i, args[i], 0)
		end
	end
	self:compileExprTemp(expr.func, regs)
	local callLabel = b:emitLabel()
	if not b:patchSkipC(fastcallLabel, callLabel) then
		raise(expr.func.line, "Exceeded jump distance limit; simplify the code to compile")
	end
	b:emitABC(OP.CALL, regs, nargs + 1, multRet and 0 or targetCount + 1)
	if not targetTop then
		for i = 0, targetCount - 1 do
			b:emitABC(OP.MOVE, target + i, regs + i, 0)
		end
	end
end

function C:compileExprCall(expr, target, targetCount, targetTop, multRet)
	local rt = self.regTop
	self:compileExprCallImpl(expr, target, targetCount, targetTop, multRet)
	self.regTop = rt
end

function C:compileExprCallImpl(expr, target, targetCount, targetTop, multRet)
	local b = self.b
	self:setDebugLine(expr)
	if self.opt >= 2 and not expr.self then
		local func = self:getFunctionExpr(expr.func)
		local fi = func and self.functions[func]
		if fi and fi.canInline and self:tryCompileInlinedCall(expr, func, target, targetCount, multRet) then
			return
		end
	end
	local nargs = #expr.args
	local regCount = math.max(1 + (expr.self and 1 or 0) + nargs, targetCount)
	local regs
	if targetTop then
		regs = self:allocReg(expr, regCount - targetCount) - targetCount
	else
		regs = self:allocReg(expr, regCount)
	end
	local bfid = -1
	if self.opt >= 1 and not expr.self then
		local id = self.builtins[expr]
		if id and id ~= 0 and id ~= LBF.SELECT_VARARG then
			bfid = id
		end
	end
	local maxFast = 2
	if bfid >= 0 and nargs == 3 and self.version >= 6 then
		for i = 1, nargs do
			if self:getExprLocalReg(expr.args[i]) >= 0 then
				maxFast = 3
				break
			end
		end
	end
	if bfid >= 0 and nargs >= 1 and nargs <= maxFast and not self:isExprMultRet(expr.args[nargs]) then
		return self:compileExprFastcallN(expr, target, targetCount, targetTop, multRet, regs, bfid)
	end
	local selfreg = 0
	if expr.self then
		local fi = expr.func
		local reg = self:getExprLocalReg(fi.expr)
		if reg >= 0 then
			selfreg = reg
		else
			selfreg = regs
			self:compileExprTempTop(fi.expr, selfreg)
		end
	elseif bfid < 0 then
		self:compileExprTempTop(expr.func, regs)
	end
	local multCall = false
	local selfn = expr.self and 1 or 0
	for i = 1, nargs do
		if i == nargs then
			multCall = self:compileExprTempMultRet(expr.args[i], regs + selfn + i)
		else
			self:compileExprTempTop(expr.args[i], regs + selfn + i)
		end
	end
	self:setDebugLineEnd(expr.func)
	if expr.self then
		local fi = expr.func
		self:setDebugLine(fi.indexLine)
		local cid = self:stringConst(fi, fi.index)
		b:emitABC(OP.NAMECALL, regs, selfreg, b.getStringHash(fi.index))
		b:emitAux(cid)
	elseif bfid >= 0 then
		local fastcallLabel = b:emitLabel()
		b:emitABC(OP.FASTCALL, bfid, 0, 0)
		self:compileExprTemp(expr.func, regs)
		local callLabel = b:emitLabel()
		if not b:patchSkipC(fastcallLabel, callLabel) then
			raise(expr.func.line, "Exceeded jump distance limit; simplify the code to compile")
		end
	end
	b:emitABC(OP.CALL, regs, multCall and 0 or (selfn + nargs + 1), multRet and 0 or targetCount + 1)
	if not targetTop then
		for i = 0, targetCount - 1 do
			b:emitABC(OP.MOVE, target + i, regs + i, 0)
		end
	end
end

function C:shouldShareClosure(func)
	local f = self.functions[func]
	if not f then
		return false
	end
	for _, uv in f.upvals do
		local ul = self.variables[uv]
		if not ul then
			return false
		end
		if ul.written then
			return false
		end
		if uv.functionDepth ~= 0 or uv.loopDepth ~= 0 then
			local uf = ul.init and ul.init.k == "Function" and ul.init or nil
			if not uf then
				return false
			end
			if uf ~= func and not self:shouldShareClosure(uf) then
				return false
			end
		end
	end
	return true
end

function C:compileExprFunction(expr, target)
	local rt = self.regTop
	local b = self.b
	local f = self.functions[expr]
	local pid = b:addChildFunction(f.id)
	if pid < 0 then
		raise(expr.line, "Exceeded closure limit; simplify the code to compile")
	end
	local captures = {}
	for _, uv in f.upvals do
		local reg = -1
		local rec = self.locals[uv]
		if rec and rec.allocated then
			reg = rec.reg
		end
		if reg >= 0 then
			local ul = self.variables[uv]
			local immutable = not ul or not ul.written
			captures[#captures + 1] = { immutable and 0 or 1, reg }
		elseif self.locstants[uv] then
			local r = self:allocReg(expr, 1)
			self:compileExprConstant(expr, self.locstants[uv], r)
			captures[#captures + 1] = { 0, r }
		else
			captures[#captures + 1] = { 2, self:getUpval(uv) }
		end
	end
	local shared = -1
	if self.opt >= 1 and self:shouldShareClosure(expr) and not self.setfenvUsed then
		local cid = b:addConstantClosure(f.id)
		if cid >= 0 and cid < 32768 then
			shared = cid
		end
	end
	if shared >= 0 then
		b:emitAD(OP.DUPCLOSURE, target, shared)
	else
		b:emitAD(OP.NEWCLOSURE, target, pid)
	end
	for _, c in captures do
		b:emitABC(OP.CAPTURE, c[1], c[2], 0)
	end
	self.regTop = rt
end

local function cmpJumpOp(op, not_)
	if op == "CompareNe" then
		return not_ and OP.JUMPIFEQ or OP.JUMPIFNOTEQ
	elseif op == "CompareEq" then
		return not_ and OP.JUMPIFNOTEQ or OP.JUMPIFEQ
	elseif op == "CompareLt" or op == "CompareGt" then
		return not_ and OP.JUMPIFNOTLT or OP.JUMPIFLT
	end
	return not_ and OP.JUMPIFNOTLE or OP.JUMPIFLE
end

function C:compileCompareJump(expr, not_)
	local rt = self.regTop
	local b = self.b
	local isEq = expr.op == "CompareEq" or expr.op == "CompareNe"
	local left, right = expr.left, expr.right
	local operandIsConstant = self:isConstant(right)
	if isEq and not operandIsConstant then
		operandIsConstant = self:isConstant(left)
		if operandIsConstant then
			left, right = right, left
		end
	end
	if operandIsConstant and self.constants[right].t == "integer" then
		operandIsConstant = false
	end
	local rl = self:compileExprAuto(left)
	local jumpLabel
	if isEq and operandIsConstant then
		local cv = self.constants[right]
		local opc, cid
		local flip = ((expr.op == "CompareEq") == not_) and 2147483648 or 0
		if cv.t == "nil" then
			opc, cid = OP.JUMPXEQKNIL, 0
		elseif cv.t == "boolean" then
			opc, cid = OP.JUMPXEQKB, cv.v and 1 or 0
		elseif cv.t == "number" then
			opc, cid = OP.JUMPXEQKN, self:getConstantIndex(right)
		else
			opc, cid = OP.JUMPXEQKS, self:getConstantIndex(right)
		end
		if cid < 0 then
			raise(expr.line, "Exceeded constant limit; simplify the code to compile")
		end
		jumpLabel = b:emitLabel()
		b:emitAD(opc, rl, 0)
		b:emitAux(cid + flip)
	else
		local opc = cmpJumpOp(expr.op, not_)
		local rr = self:compileExprAuto(right)
		jumpLabel = b:emitLabel()
		if expr.op == "CompareGt" or expr.op == "CompareGe" then
			b:emitAD(opc, rr, 0)
			b:emitAux(rl)
		else
			b:emitAD(opc, rl, 0)
			b:emitAux(rr)
		end
	end
	self.regTop = rt
	return jumpLabel
end

function C:compileConditionValue(node, target, skipJump, onlyTruth)
	local b = self.b
	local cv = self.constants[node]
	if cv then
		if truthy(cv) == onlyTruth then
			if target then
				self:compileExprTemp(node, target)
			end
			skipJump[#skipJump + 1] = b:emitLabel()
			b:emitAD(OP.JUMP, 0, 0)
		end
		return
	end
	local k = node.k
	if k == "Binary" then
		local op = node.op
		if op == "And" or op == "Or" then
			if onlyTruth == (op == "And") then
				local elseJump = {}
				self:compileConditionValue(node.left, nil, elseJump, not onlyTruth)
				self:compileConditionValue(node.right, target, skipJump, onlyTruth)
				local elseLabel = b:emitLabel()
				self:patchJumps(node, elseJump, elseLabel)
			else
				self:compileConditionValue(node.left, target, skipJump, onlyTruth)
				self:compileConditionValue(node.right, target, skipJump, onlyTruth)
			end
			return
		elseif ISCOMPARE[op] then
			if target then
				b:emitABC(OP.LOADB, target, onlyTruth and 1 or 0, 0)
			end
			local jumpLabel = self:compileCompareJump(node, not onlyTruth)
			skipJump[#skipJump + 1] = jumpLabel
			return
		end
	elseif k == "Unary" then
		if not target and node.op == "Not" then
			self:compileConditionValue(node.expr, target, skipJump, not onlyTruth)
			return
		end
	elseif k == "Group" then
		self:compileConditionValue(node.expr, target, skipJump, onlyTruth)
		return
	end
	local rt = self.regTop
	local reg
	if target then
		reg = target
		self:compileExprTemp(node, reg)
	else
		reg = self:compileExprAuto(node)
	end
	skipJump[#skipJump + 1] = b:emitLabel()
	b:emitAD(onlyTruth and OP.JUMPIF or OP.JUMPIFNOT, reg, 0)
	self.regTop = rt
end

function C:isConditionFast(node)
	if self.constants[node] then
		return true
	end
	if node.k == "Binary" then
		return node.op == "And" or node.op == "Or" or ISCOMPARE[node.op] == true
	elseif node.k == "Group" then
		return self:isConditionFast(node.expr)
	end
	return false
end

function C:compileExprAndOr(expr, target, targetTemp)
	local b = self.b
	local and_ = expr.op == "And"
	local rt = self.regTop
	local cl = self.constants[expr.left]
	if cl then
		self:compileExpr((and_ == truthy(cl)) and expr.right or expr.left, target, targetTemp)
		return
	end
	if not self:isConditionFast(expr.left) then
		local reg = self:getExprLocalReg(expr.right)
		if reg >= 0 then
			local lr = self:compileExprAuto(expr.left)
			b:emitABC(and_ and OP.AND or OP.OR, target, lr, reg)
			self.regTop = rt
			return
		end
		local cid = self:getConstantIndex(expr.right)
		if cid >= 0 and cid <= 255 then
			local lr = self:compileExprAuto(expr.left)
			b:emitABC(and_ and OP.ANDK or OP.ORK, target, lr, cid)
			self.regTop = rt
			return
		end
	end
	local reg = targetTemp and target or self:allocReg(expr, 1)
	local skipJump = {}
	self:compileConditionValue(expr.left, reg, skipJump, not and_)
	self:compileExprTemp(expr.right, reg)
	local moveLabel = b:emitLabel()
	self:patchJumps(expr, skipJump, moveLabel)
	if target ~= reg then
		b:emitABC(OP.MOVE, target, reg, 0)
	end
	self.regTop = rt
end

function C:compileExprUnary(expr, target)
	if expr.op == "Minus" and expr.expr.k == "Int" then
		local hi, lo = expr.expr.hi, expr.expr.lo
		lo = (4294967296 - lo) % 4294967296
		hi = (4294967295 - hi + (lo == 0 and 1 or 0)) % 4294967296
		self:emitLoadK(target, self:integerConst(expr, hi, lo))
		return
	end
	local rt = self.regTop
	local re = self:compileExprAuto(expr.expr)
	local op = expr.op == "Not" and OP.NOT or (expr.op == "Minus" and OP.MINUS or OP.LENGTH)
	self.b:emitABC(op, target, re, 0)
	self.regTop = rt
end

local function unrollConcats(args)
	while true do
		local be = args[#args]
		if be.k ~= "Binary" or be.op ~= "Concat" then
			break
		end
		args[#args] = be.left
		args[#args + 1] = be.right
	end
end

function C:compileExprBinary(expr, target, targetTemp)
	local rt = self.regTop
	local b = self.b
	local op = expr.op
	if ARITH[op] then
		if op == "FloorDiv" and self.version < 4 then
			raise(expr.line, "Floor division requires bytecode version 4 or newer")
		end
		local rc = self:getConstantNumber(expr.right)
		if rc >= 0 and rc <= 255 then
			local rl = self:compileExprAuto(expr.left)
			b:emitABC(OP[ARITHK[op]], target, rl, rc)
		else
			local done = false
			if (op == "Sub" or op == "Div") and self.version >= 5 then
				local lc = self:getConstantNumber(expr.left)
				if lc >= 0 and lc <= 255 then
					local rr = self:compileExprAuto(expr.right)
					b:emitABC(op == "Sub" and OP.SUBRK or OP.DIVRK, target, lc, rr)
					done = true
				end
			end
			if not done then
				local rl = self:compileExprAuto(expr.left)
				local rr = self:compileExprAuto(expr.right)
				b:emitABC(OP[ARITH[op]], target, rl, rr)
			end
		end
	elseif op == "Concat" then
		local args = { expr.left, expr.right }
		unrollConcats(args)
		local regs = self:allocReg(expr, #args)
		for i, a in args do
			self:compileExprTempTop(a, regs + i - 1)
		end
		b:emitABC(OP.CONCAT, target, regs, regs + #args - 1)
	elseif ISCOMPARE[op] then
		local jumpLabel = self:compileCompareJump(expr, false)
		b:emitABC(OP.LOADB, target, 0, 1)
		local thenLabel = b:emitLabel()
		b:emitABC(OP.LOADB, target, 1, 0)
		self:patchJump(expr, jumpLabel, thenLabel)
	else
		self:compileExprAndOr(expr, target, targetTemp)
	end
	self.regTop = rt
end

function C:compileExprIfElseAndOr(and_, creg, other, target)
	local cid = self:getConstantIndex(other)
	if cid >= 0 and cid <= 255 then
		self.b:emitABC(and_ and OP.ANDK or OP.ORK, target, creg, cid)
	else
		local rt = self.regTop
		local oreg = self:compileExprAuto(other)
		self.b:emitABC(and_ and OP.AND or OP.OR, target, creg, oreg)
		self.regTop = rt
	end
end

function C:compileExprIfElseLocal(expr, target, targetTemp)
	local b = self.b
	local skipElse = self:isConstantTrue(expr.condition)
	local oldLocals = #self.localStack
	local elseJump = 0
	local rt = self.regTop
	local reg = self:allocReg(expr, 1)
	self:compileExprTemp(expr.condition, reg)
	self:pushLocal(expr.conditionLocal, reg)
	if not skipElse then
		elseJump = b:emitLabel()
		b:emitAD(OP.JUMPIFNOT, reg, 0)
	end
	self:compileExpr(expr.trueExpr, target, targetTemp)
	self:closeLocals(oldLocals)
	self:popLocals(oldLocals)
	self.regTop = rt
	if skipElse then
		return
	end
	local thenLabel = b:emitLabel()
	b:emitAD(OP.JUMP, 0, 0)
	local elseLabel = b:emitLabel()
	self:compileExpr(expr.falseExpr, target, targetTemp)
	local endLabel = b:emitLabel()
	self:patchJump(expr, elseJump, elseLabel)
	self:patchJump(expr, thenLabel, endLabel)
end

function C:compileExprIfElse(expr, target, targetTemp)
	local b = self.b
	if expr.conditionLocal then
		return self:compileExprIfElseLocal(expr, target, targetTemp)
	end
	if self:isConstant(expr.condition) then
		if self:isConstantTrue(expr.condition) then
			self:compileExpr(expr.trueExpr, target, targetTemp)
		else
			self:compileExpr(expr.falseExpr, target, targetTemp)
		end
		return
	end
	local creg = self:getExprLocalReg(expr.condition)
	if creg >= 0 then
		if creg == self:getExprLocalReg(expr.trueExpr) and (self:getExprLocalReg(expr.falseExpr) >= 0 or self:isConstant(expr.falseExpr)) then
			return self:compileExprIfElseAndOr(false, creg, expr.falseExpr, target)
		elseif creg == self:getExprLocalReg(expr.falseExpr) and (self:getExprLocalReg(expr.trueExpr) >= 0 or self:isConstant(expr.trueExpr)) then
			return self:compileExprIfElseAndOr(true, creg, expr.trueExpr, target)
		end
	end
	local elseJump = {}
	self:compileConditionValue(expr.condition, nil, elseJump, false)
	self:compileExpr(expr.trueExpr, target, targetTemp)
	local thenLabel = b:emitLabel()
	b:emitAD(OP.JUMP, 0, 0)
	local elseLabel = b:emitLabel()
	self:compileExpr(expr.falseExpr, target, targetTemp)
	local endLabel = b:emitLabel()
	self:patchJumps(expr, elseJump, elseLabel)
	self:patchJump(expr, thenLabel, endLabel)
end

function C:compileExprInterpString(expr, target, targetTemp)
	local b = self.b
	local function esc(s)
		return (s:gsub("%%", "%%%%"))
	end
	local skipped = 0
	local parts = {}
	for idx, s in expr.strings do
		parts[#parts + 1] = esc(s)
		if idx <= #expr.expressions then
			local c = self.constants[expr.expressions[idx]]
			if c and c.t == "string" then
				parts[#parts + 1] = esc(c.v)
				skipped += 1
			else
				parts[#parts + 1] = "%*"
			end
		end
	end
	local formatString = table.concat(parts)
	local fidx = self:stringConst(expr, formatString)
	local rt = self.regTop
	local regCount = 2 + #expr.expressions - skipped
	local targetTop = targetTemp and target == self.regTop - 1
	local baseReg
	if targetTop then
		baseReg = self:allocReg(expr, regCount - 1) - 1
	else
		baseReg = self:allocReg(expr, regCount)
	end
	self:emitLoadK(baseReg, fidx)
	local sk = 0
	for index, sub in expr.expressions do
		local c = self.constants[sub]
		if not c or c.t ~= "string" then
			self:compileExprTempTop(sub, baseReg + 1 + index - sk)
		else
			sk += 1
		end
	end
	local mcid = self:stringConst(expr, "format")
	b:emitABC(OP.NAMECALL, baseReg, baseReg, b.getStringHash("format"))
	b:emitAux(mcid)
	b:emitABC(OP.CALL, baseReg, #expr.expressions + 2 - skipped, 2)
	if target ~= baseReg then
		b:emitABC(OP.MOVE, target, baseReg, 0)
	end
	self.regTop = rt
end

local function encodeHashSize(hashSize)
	if hashSize == 0 then
		return 0
	end
	local log2 = 0
	while 2 ^ log2 < hashSize do
		log2 += 1
	end
	return log2 + 1
end

function C:compileExprTable(expr, target, targetTemp)
	local b = self.b
	local items = expr.items
	if #items == 0 then
		local shape = self.tableShapes[expr] or { hashSize = 0, arraySize = 0 }
		b:emitABC(OP.NEWTABLE, target, encodeHashSize(shape.hashSize), 0)
		b:emitAux(shape.arraySize)
		return
	end
	local arraySize, hashSize, recordSize, indexSize = 0, 0, 0, 0
	for _, item in items do
		if item.kind == "List" then
			arraySize += 1
		else
			hashSize += 1
		end
		if item.kind == "Record" then
			recordSize += 1
		end
	end
	if arraySize == 0 and hashSize > 0 then
		for _, item in items do
			local ck = item.key and self.constants[item.key]
			if ck and ck.t == "number" and ck.v == indexSize + 1 then
				indexSize += 1
			end
		end
		if hashSize == recordSize + indexSize then
			hashSize = recordSize
		else
			indexSize = 0
		end
	end
	local encodedHashSize = encodeHashSize(hashSize)
	local rt = self.regTop
	local reg = targetTemp and target or self:allocReg(expr, 1)
	local usedTemplate = false
	local lastKeyVal = {}
	if arraySize == 0 and indexSize == 0 and hashSize == recordSize and recordSize >= 1 and recordSize <= 32 then
		local keys, order, map = {}, {}, {}
		for _, item in items do
			local keyCid = self:stringConst(expr, item.key.value)
			local valueCid = self.version >= 7 and self:getConstantIndex(item.value) or -1
			if not (map[keyCid] == -1) then
				if map[keyCid] == nil then
					order[#order + 1] = keyCid
				end
				map[keyCid] = valueCid
			end
		end
		local consts, hasConstants = {}, false
		for i, keyCid in order do
			keys[i] = keyCid
			consts[i] = map[keyCid]
			if consts[i] >= 0 then
				hasConstants = true
			end
		end
		local tid = b:addConstantTable(keys, hasConstants and consts or nil)
		if tid < 0 then
			raise(expr.line, "Exceeded constant limit; simplify the code to compile")
		end
		if tid < 32768 then
			b:emitAD(OP.DUPTABLE, reg, tid)
			usedTemplate = true
			lastKeyVal = map
		end
	end
	if not usedTemplate then
		local last = items[#items]
		local trailingVarargs = last and last.kind == "List" and last.value.k == "Varargs"
		local arrayAllocation = arraySize - (trailingVarargs and 1 or 0) + indexSize
		b:emitABC(OP.NEWTABLE, reg, encodedHashSize, 0)
		b:emitAux(arrayAllocation)
	end
	local arrayChunkSize = math.min(16, arraySize)
	local arrayChunkReg = self:allocReg(expr, arrayChunkSize)
	local arrayChunkCurrent = 0
	local arrayIndex = 1
	local multRet = false
	for i, item in items do
		local key, value = item.key, item.value
		if key and key.k == "Str" and next(lastKeyVal) ~= nil then
			local vc = lastKeyVal[b:addConstantString(key.value)]
			if vc and vc >= 0 then
				continue
			end
		end
		self:setDebugLine(value)
		if self.cov >= 2 then
			b:emitABC(OP.COVERAGE, 0, 0, 0)
		end
		if arrayChunkCurrent > 0 and (key or arrayChunkCurrent == arrayChunkSize) then
			b:emitABC(OP.SETLIST, reg, arrayChunkReg, arrayChunkCurrent + 1)
			b:emitAux(arrayIndex)
			arrayIndex += arrayChunkCurrent
			arrayChunkCurrent = 0
		end
		if key then
			local rsi = self.regTop
			local lv = self:compileLValueIndex(reg, key)
			local rv = self:compileExprAuto(value)
			self:compileAssign(lv, rv)
			self.regTop = rsi
		else
			local temp = arrayChunkReg + arrayChunkCurrent
			if i == #items then
				multRet = self:compileExprTempMultRet(value, temp)
			else
				self:compileExprTempTop(value, temp)
			end
			arrayChunkCurrent += 1
		end
	end
	if arrayChunkCurrent > 0 then
		b:emitABC(OP.SETLIST, reg, arrayChunkReg, multRet and 0 or arrayChunkCurrent + 1)
		b:emitAux(arrayIndex)
	end
	if target ~= reg then
		b:emitABC(OP.MOVE, target, reg, 0)
	end
	self.regTop = rt
end

function C:compileExprIndexName(expr, target, targetTemp)
	local b = self.b
	self:setDebugLine(expr)
	local importRoot, import1, import2
	if expr.expr.k == "IndexName" then
		if expr.expr.expr.k == "Global" then
			importRoot = expr.expr.expr
			import1 = expr.expr
			import2 = expr
		end
	elseif expr.expr.k == "Global" then
		importRoot = expr.expr
		import1 = expr
	end
	if importRoot and self.opt >= 1 and self:globalState(importRoot.name) == "Default" then
		local id0 = self:stringConst(expr, importRoot.name)
		local id1 = self:stringConst(expr, import1.index)
		local id2 = import2 and self:stringConst(expr, import2.index) or -1
		if id0 < 1024 and id1 < 1024 and id2 < 1024 then
			local iid = import2 and b.getImportId(id0, id1, id2) or b.getImportId(id0, id1)
			local cid = b:addImport(iid)
			if cid >= 0 and cid < 32768 then
				b:emitAD(OP.GETIMPORT, target, cid)
				b:emitAux(iid)
				return
			end
		end
	end
	local rt = self.regTop
	local reg = target
	local localReg = self:getExprLocalReg(expr.expr)
	if localReg >= 0 then
		reg = localReg
	elseif targetTemp then
		self:compileExprTemp(expr.expr, target)
	else
		reg = self:compileExprAuto(expr.expr)
	end
	self:setDebugLine(expr.indexLine)
	local cid = self:stringConst(expr, expr.index)
	b:emitABC(OP.GETTABLEKS, target, reg, b.getStringHash(expr.index))
	b:emitAux(cid)
	self.regTop = rt
end

function C:compileExprIndexExpr(expr, target)
	local rt = self.regTop
	local b = self.b
	local cv = self.constants[expr.index]
	if cv and cv.t == "number" and cv.v >= 1 and cv.v <= 256 and cv.v == math.floor(cv.v) then
		local rtbl = self:compileExprAuto(expr.expr)
		self:setDebugLine(expr.index)
		b:emitABC(OP.GETTABLEN, target, rtbl, cv.v - 1)
	elseif cv and cv.t == "string" then
		local cid = self:stringConst(expr, cv.v)
		local rtbl = self:compileExprAuto(expr.expr)
		self:setDebugLine(expr.index)
		b:emitABC(OP.GETTABLEKS, target, rtbl, b.getStringHash(cv.v))
		b:emitAux(cid)
	else
		local rtbl = self:compileExprAuto(expr.expr)
		local ri = self:compileExprAuto(expr.index)
		self:setDebugLine(expr.index)
		b:emitABC(OP.GETTABLE, target, rtbl, ri)
	end
	self.regTop = rt
end

function C:compileExprGlobal(expr, target)
	local b = self.b
	if self.opt >= 1 and self:globalState(expr.name) ~= "Written" then
		local id0 = self:stringConst(expr, expr.name)
		if id0 < 1024 then
			local iid = b.getImportId(id0)
			local cid = b:addImport(iid)
			if cid >= 0 and cid < 32768 then
				b:emitAD(OP.GETIMPORT, target, cid)
				b:emitAux(iid)
				return
			end
		end
	end
	local cid = self:stringConst(expr, expr.name)
	b:emitABC(OP.GETGLOBAL, target, 0, b.getStringHash(expr.name))
	b:emitAux(cid)
end

function C:compileExpr(node, target, targetTemp)
	self:setDebugLine(node)
	if self.cov >= 2 then
		self.b:emitABC(OP.COVERAGE, 0, 0, 0)
	end
	local cv = self.constants[node]
	if cv then
		self:compileExprConstant(node, cv, target)
		return
	end
	local k = node.k
	local b = self.b
	if k == "Group" or k == "Assert" then
		self:compileExpr(node.expr, target, targetTemp)
	elseif k == "Nil" then
		b:emitABC(OP.LOADNIL, target, 0, 0)
	elseif k == "Bool" then
		b:emitABC(OP.LOADB, target, node.value and 1 or 0, 0)
	elseif k == "Num" then
		local cid = b:addConstantNumber(node.value)
		if cid < 0 then
			raise(node.line, "Exceeded constant limit; simplify the code to compile")
		end
		self:emitLoadK(target, cid)
	elseif k == "Str" then
		self:emitLoadK(target, self:stringConst(node, node.value))
	elseif k == "Int" then
		self:emitLoadK(target, self:integerConst(node, node.hi, node.lo))
	elseif k == "Local" then
		local reg = self:getExprLocalReg(node)
		if reg >= 0 then
			if self.opt == 0 or target ~= reg then
				b:emitABC(OP.MOVE, target, reg, 0)
			end
		else
			b:emitABC(OP.GETUPVAL, target, self:getUpval(node["local"]), 0)
		end
	elseif k == "Global" then
		self:compileExprGlobal(node, target)
	elseif k == "Varargs" then
		self:compileExprVarargs(node, target, 1)
	elseif k == "Call" then
		if targetTemp and target == self.regTop - 1 then
			self:compileExprCall(node, target, 1, true)
		else
			self:compileExprCall(node, target, 1)
		end
	elseif k == "IndexName" then
		self:compileExprIndexName(node, target, targetTemp)
	elseif k == "IndexExpr" then
		self:compileExprIndexExpr(node, target)
	elseif k == "Function" then
		self:compileExprFunction(node, target)
	elseif k == "Table" then
		self:compileExprTable(node, target, targetTemp)
	elseif k == "Unary" then
		self:compileExprUnary(node, target)
	elseif k == "Binary" then
		self:compileExprBinary(node, target, targetTemp)
	elseif k == "IfElse" then
		self:compileExprIfElse(node, target, targetTemp)
	elseif k == "Interp" then
		self:compileExprInterpString(node, target, targetTemp)
	else
		raise(node.line, "Unknown expression type %s", tostring(k))
	end
end

function C:compileExprTemp(node, target)
	self:compileExpr(node, target, true)
end

function C:compileExprAuto(node)
	local reg = self:getExprLocalReg(node)
	if reg >= 0 then
		return reg
	end
	reg = self:allocReg(node, 1)
	self:compileExprTemp(node, reg)
	return reg
end

function C:compileExprSide(node)
	local k = node.k
	if k == "Local" or k == "Global" or k == "Varargs" or k == "Function" or self:isConstant(node) then
		return
	end
	local rt = self.regTop
	self:compileExprAuto(node)
	self.regTop = rt
end

function C:compileExprTempN(node, target, targetCount, targetTop)
	if targetCount == 255 then
		raise(node.line, "Exceeded result count limit; simplify the code to compile")
	end
	if node.k == "Call" and not self.constants[node] then
		self:compileExprCall(node, target, targetCount, targetTop)
	elseif node.k == "Varargs" then
		self:compileExprVarargs(node, target, targetCount)
	else
		self:compileExprTemp(node, target)
		for i = 1, targetCount - 1 do
			self.b:emitABC(OP.LOADNIL, target + i, 0, 0)
		end
	end
end

function C:compileExprListTemp(list, target, targetCount, targetTop)
	local n = #list
	if n == targetCount then
		for i = 1, n do
			self:compileExprTemp(list[i], target + i - 1)
		end
	elseif n > targetCount then
		for i = 1, targetCount do
			self:compileExprTemp(list[i], target + i - 1)
		end
		for i = targetCount + 1, n do
			self:compileExprSide(list[i])
		end
	elseif n > 0 then
		for i = 1, n - 1 do
			self:compileExprTemp(list[i], target + i - 1)
		end
		self:compileExprTempN(list[n], target + n - 1, targetCount - (n - 1), targetTop)
	else
		for i = 0, targetCount - 1 do
			self.b:emitABC(OP.LOADNIL, target + i, 0, 0)
		end
	end
end

function C:compileLValueIndex(reg, index)
	local ck = self.constants[index]
	if ck and ck.t == "number" and ck.v >= 1 and ck.v <= 256 and ck.v == math.floor(ck.v) then
		return { kind = "indexnumber", reg = reg, number = ck.v - 1, line = index.line }
	elseif ck and ck.t == "string" then
		return { kind = "indexname", reg = reg, name = ck.v, line = index.line }
	end
	return { kind = "indexexpr", reg = reg, index = self:compileExprAuto(index), line = index.line }
end

function C:compileLValue(node)
	self:setDebugLine(node)
	local k = node.k
	if k == "Local" then
		local reg = self:getExprLocalReg(node)
		if reg >= 0 then
			return { kind = "local", reg = reg, line = node.line }
		end
		return { kind = "upval", upval = self:getUpval(node["local"]), line = node.line }
	elseif k == "Global" then
		return { kind = "global", name = node.name, line = node.line }
	elseif k == "IndexName" then
		local reg = self:compileExprAuto(node.expr)
		return { kind = "indexname", reg = reg, name = node.index, line = node.line }
	elseif k == "IndexExpr" then
		local reg = self:compileExprAuto(node.expr)
		return self:compileLValueIndex(reg, node.index)
	end
	raise(node.line, "Unexpected expression type in assignment")
end

function C:compileLValueUse(lv, reg, set)
	self:setDebugLine(lv.line)
	local b = self.b
	local kind = lv.kind
	if kind == "local" then
		if set then
			b:emitABC(OP.MOVE, lv.reg, reg, 0)
		else
			b:emitABC(OP.MOVE, reg, lv.reg, 0)
		end
	elseif kind == "upval" then
		b:emitABC(set and OP.SETUPVAL or OP.GETUPVAL, reg, lv.upval, 0)
	elseif kind == "global" then
		local cid = self:stringConst(lv, lv.name)
		b:emitABC(set and OP.SETGLOBAL or OP.GETGLOBAL, reg, 0, b.getStringHash(lv.name))
		b:emitAux(cid)
	elseif kind == "indexname" then
		local cid = self:stringConst(lv, lv.name)
		b:emitABC(set and OP.SETTABLEKS or OP.GETTABLEKS, reg, lv.reg, b.getStringHash(lv.name))
		b:emitAux(cid)
	elseif kind == "indexnumber" then
		b:emitABC(set and OP.SETTABLEN or OP.GETTABLEN, reg, lv.reg, lv.number)
	else
		b:emitABC(set and OP.SETTABLE or OP.GETTABLE, reg, lv.reg, lv.index)
	end
end

function C:compileAssign(lv, source)
	self:compileLValueUse(lv, source, true)
end

function C:alwaysTerminates(node)
	local k = node.k
	if k == "Block" then
		for _, s in node.body do
			if self:alwaysTerminates(s) then
				return true
			end
		end
		return false
	elseif k == "Return" or k == "Break" or k == "Continue" then
		return true
	elseif k == "If" then
		if self:isConstantTrue(node.condition) then
			return self:alwaysTerminates(node.thenbody)
		end
		if self:isConstantFalse(node.condition) and node.elsebody then
			return self:alwaysTerminates(node.elsebody)
		end
		return node.elsebody ~= nil and self:alwaysTerminates(node.thenbody) and self:alwaysTerminates(node.elsebody)
	end
	return false
end

local function isStatBreak(node)
	if node.k == "Block" then
		return #node.body == 1 and node.body[1].k == "Break"
	end
	return node.k == "Break"
end

local function extractStatContinue(block)
	if #block.body == 1 and block.body[1].k == "Continue" then
		return block.body[1]
	end
	return nil
end

function C:compileStatIfLocal(stat)
	local b = self.b
	local thenTerminates = self:alwaysTerminates(stat.thenbody)
	local skipElse = self:isConstantTrue(stat.condition)
	local oldLocals = #self.localStack
	local elseJump = 0
	local rt = self.regTop
	local reg = self:allocReg(stat, 1)
	self:compileExprTemp(stat.condition, reg)
	self:pushLocal(stat.conditionLocal, reg)
	if not skipElse then
		elseJump = b:emitLabel()
		b:emitAD(OP.JUMPIFNOT, reg, 0)
	end
	self:compileStat(stat.thenbody)
	if not thenTerminates then
		self:closeLocals(oldLocals)
	end
	self:popLocals(oldLocals)
	self.regTop = rt
	if skipElse then
		return
	end
	if stat.elsebody then
		if thenTerminates then
			local elseLabel = b:emitLabel()
			self:compileStat(stat.elsebody)
			self:patchJump(stat, elseJump, elseLabel)
		else
			local thenLabel = b:emitLabel()
			b:emitAD(OP.JUMP, 0, 0)
			local elseLabel = b:emitLabel()
			self:compileStat(stat.elsebody)
			local endLabel = b:emitLabel()
			self:patchJump(stat, elseJump, elseLabel)
			self:patchJump(stat, thenLabel, endLabel)
		end
	else
		local endLabel = b:emitLabel()
		self:patchJump(stat, elseJump, endLabel)
	end
end

function C:compileStatIf(stat)
	local b = self.b
	if stat.conditionLocal then
		return self:compileStatIfLocal(stat)
	end
	if self:isConstantFalse(stat.condition) then
		if stat.elsebody then
			self:compileStat(stat.elsebody)
		end
		return
	end
	local cand = stat.condition
	if cand.k == "Binary" and cand.op == "And" and self:isConstantFalse(cand.right) then
		self:compileExprSide(cand.left)
		if stat.elsebody then
			self:compileStat(stat.elsebody)
		end
		return
	end
	local loop = self.loops[#self.loops]
	if not stat.elsebody and isStatBreak(stat.thenbody) and not self:areLocalsCaptured(loop.localOffset) then
		local elseJump = {}
		self:compileConditionValue(stat.condition, nil, elseJump, true)
		for _, j in elseJump do
			self.loopJumps[#self.loopJumps + 1] = { type = "break", label = j }
		end
		return
	end
	local continueStatement = extractStatContinue(stat.thenbody)
	if not stat.elsebody and continueStatement and not self:areLocalsCaptured(loop.localOffsetContinue) then
		if not loop.continueUsed then
			loop.continueUsed = continueStatement
		end
		local elseJump = {}
		self:compileConditionValue(stat.condition, nil, elseJump, true)
		for _, j in elseJump do
			self.loopJumps[#self.loopJumps + 1] = { type = "continue", label = j }
		end
		return
	end
	local elseJump = {}
	self:compileConditionValue(stat.condition, nil, elseJump, false)
	self:compileStat(stat.thenbody)
	if stat.elsebody and #elseJump > 0 then
		if self:alwaysTerminates(stat.thenbody) then
			local elseLabel = b:emitLabel()
			self:compileStat(stat.elsebody)
			self:patchJumps(stat, elseJump, elseLabel)
		else
			local thenLabel = b:emitLabel()
			b:emitAD(OP.JUMP, 0, 0)
			local elseLabel = b:emitLabel()
			self:compileStat(stat.elsebody)
			local endLabel = b:emitLabel()
			self:patchJumps(stat, elseJump, elseLabel)
			self:patchJump(stat, thenLabel, endLabel)
		end
	else
		local endLabel = b:emitLabel()
		self:patchJumps(stat, elseJump, endLabel)
	end
end

function C:pushLoop()
	local n = #self.localStack
	self.loops[#self.loops + 1] = { localOffset = n, localOffsetContinue = n }
	self.hasLoops = true
end

function C:compileStatWhile(stat)
	local b = self.b
	if self:isConstantFalse(stat.condition) then
		return
	end
	local oldJumps = #self.loopJumps
	self:pushLoop()
	local loopLabel = b:emitLabel()
	local elseJump = {}
	self:compileConditionValue(stat.condition, nil, elseJump, false)
	self:compileStat(stat.body)
	local contLabel = b:emitLabel()
	local backLabel = b:emitLabel()
	self:setDebugLine(stat.condition)
	b:emitAD(OP.JUMPBACK, 0, 0)
	local endLabel = b:emitLabel()
	self:patchJump(stat, backLabel, loopLabel)
	self:patchJumps(stat, elseJump, endLabel)
	self:patchLoopJumps(stat, oldJumps, endLabel, contLabel)
	for i = #self.loopJumps, oldJumps + 1, -1 do
		self.loopJumps[i] = nil
	end
	self.loops[#self.loops] = nil
end

function C:compileStatRepeat(stat)
	local b = self.b
	local oldJumps = #self.loopJumps
	local oldLocals = #self.localStack
	self:pushLoop()
	local loop = self.loops[#self.loops]
	local loopLabel = b:emitLabel()
	local body = stat.body
	local rt = self.regTop
	local continueValidated = false
	local conditionLocals = 0
	for _, bs in body.body do
		self:compileStat(bs)
		if not loop.continueUsed then
			loop.localOffsetContinue = #self.localStack
		end
		if loop.continueUsed and not continueValidated then
			continueValidated = true
			conditionLocals = #self.localStack
		end
	end
	if continueValidated then
		self:setDebugLineEnd(body.body[#body.body])
		self:closeLocals(conditionLocals)
		self:popLocals(conditionLocals)
	end
	local contLabel = b:emitLabel()
	local endLabel
	self:setDebugLine(stat.condition)
	if self:isConstantTrue(stat.condition) then
		self:closeLocals(oldLocals)
		endLabel = b:emitLabel()
	else
		local skipJump = {}
		self:compileConditionValue(stat.condition, nil, skipJump, true)
		self:closeLocals(oldLocals)
		local backLabel = b:emitLabel()
		b:emitAD(OP.JUMPBACK, 0, 0)
		local skipLabel = b:emitLabel()
		self:closeLocals(oldLocals)
		endLabel = b:emitLabel()
		self:patchJump(stat, backLabel, loopLabel)
		self:patchJumps(stat, skipJump, skipLabel)
	end
	self:popLocals(oldLocals)
	self:patchLoopJumps(stat, oldJumps, endLabel, contLabel)
	for i = #self.loopJumps, oldJumps + 1, -1 do
		self.loopJumps[i] = nil
	end
	self.loops[#self.loops] = nil
	self.regTop = rt
end

function C:compileStatReturn(stat)
	if #stat.list >= 255 then
		raise(stat.line, "Exceeded return count limit; simplify the code to compile")
	end
	local rt = self.regTop
	local list = stat.list
	local temp = 0
	local consecutive = false
	local multRet = false
	local first = #list > 0 and self:getExprLocalReg(list[1]) or -1
	if first >= 0 then
		temp = first
		consecutive = true
		for i = 2, #list do
			if self:getExprLocalReg(list[i]) ~= temp + i - 1 then
				consecutive = false
				break
			end
		end
	end
	if not consecutive and #list > 0 then
		temp = self:allocReg(stat, #list)
		for i, e in list do
			if i == #list then
				multRet = self:compileExprTempMultRet(e, temp + i - 1)
			else
				self:compileExprTempTop(e, temp + i - 1)
			end
		end
	end
	self:closeLocals(0)
	if multRet then
		self.hasMultiRet = true
	end
	self.b:emitABC(OP.RETURN, temp, multRet and 0 or #list + 1, 0)
	self.regTop = rt
end

function C:areLocalsRedundant(stat)
	if #stat.values > #stat.vars then
		return false
	end
	for _, l in stat.vars do
		local v = self.variables[l]
		if not v or not v.constant then
			return false
		end
	end
	return true
end

function C:compileStatLocal(stat)
	local rt = self.regTop
	if self.opt >= 1 and self.dbg <= 1 and self:areLocalsRedundant(stat) then
		return
	end
	if self.opt >= 1 and #stat.vars == 1 and #stat.values == 1 then
		local re = unwrap(stat.values[1])
		if re.k == "Local" then
			local lv = self.variables[stat.vars[1]]
			local rv = self.variables[re["local"]]
			local reg = self:getExprLocalReg(re)
			if reg >= 0 and (not lv or not lv.written) and (not rv or not rv.written) then
				self:pushLocal(stat.vars[1], reg)
				return
			end
		end
	end
	local vars = self:allocReg(stat, #stat.vars)
	self:compileExprListTemp(stat.values, vars, #stat.vars, true)
	for i, l in stat.vars do
		self:pushLocal(l, vars + i - 1)
	end
	if self.regTop < rt then
		self.regTop = rt
	end
end

function C:compileStatFor(stat)
	local b = self.b
	if self.opt >= 2 and self:isConstant(stat.from) and self:isConstant(stat.to) and (not stat.step or self:isConstant(stat.step)) then
		if self:tryCompileUnrolledFor(stat) then
			return
		end
	end
	local rt = self.regTop
	local oldLocals = #self.localStack
	local oldJumps = #self.loopJumps
	self:pushLoop()
	local regs = self:allocReg(stat, 3)
	local varreg = regs + 2
	local v = self.variables[stat.var]
	if v and v.written then
		varreg = self:allocReg(stat, 1)
	end
	self:compileExprTemp(stat.from, regs + 2)
	self:compileExprTemp(stat.to, regs + 0)
	if stat.step then
		self:compileExprTemp(stat.step, regs + 1)
	else
		b:emitABC(OP.LOADN, regs + 1, 1, 0)
	end
	local forLabel = b:emitLabel()
	b:emitAD(OP.FORNPREP, regs, 0)
	local loopLabel = b:emitLabel()
	if varreg ~= regs + 2 then
		b:emitABC(OP.MOVE, varreg, regs + 2, 0)
	end
	self:pushLocal(stat.var, varreg)
	self:compileStat(stat.body)
	self:closeLocals(oldLocals)
	self:popLocals(oldLocals)
	self:setDebugLine(stat)
	local contLabel = b:emitLabel()
	local backLabel = b:emitLabel()
	b:emitAD(OP.FORNLOOP, regs, 0)
	local endLabel = b:emitLabel()
	self:patchJump(stat, forLabel, endLabel)
	self:patchJump(stat, backLabel, loopLabel)
	self:patchLoopJumps(stat, oldJumps, endLabel, contLabel)
	for i = #self.loopJumps, oldJumps + 1, -1 do
		self.loopJumps[i] = nil
	end
	self.loops[#self.loops] = nil
	self.regTop = rt
end

function C:compileStatForIn(stat)
	local b = self.b
	local rt = self.regTop
	local oldLocals = #self.localStack
	local oldJumps = #self.loopJumps
	self:pushLoop()
	local regs = self:allocReg(stat, 3)
	self:compileExprListTemp(stat.values, regs, 3, true)
	local vars = self:allocReg(stat, math.max(#stat.vars, 2))
	local skipOp = OP.FORGPREP
	if self.opt >= 1 and #stat.vars <= 2 then
		if #stat.values == 1 and stat.values[1].k == "Call" then
			local object, method = self:getBuiltin(stat.values[1].func)
			if not object and method == "ipairs" then
				skipOp = OP.FORGPREP_INEXT
			elseif not object and method == "pairs" then
				skipOp = OP.FORGPREP_NEXT
			end
		elseif #stat.values == 2 and not self.getfenvUsed and not self.setfenvUsed then
			local object, method = self:getBuiltin(stat.values[1])
			if not object and method == "next" then
				skipOp = OP.FORGPREP_NEXT
			end
		end
	end
	local skipLabel = b:emitLabel()
	b:emitAD(skipOp, regs, 0)
	local loopLabel = b:emitLabel()
	for i, l in stat.vars do
		self:pushLocal(l, vars + i - 1)
	end
	self:compileStat(stat.body)
	self:closeLocals(oldLocals)
	self:popLocals(oldLocals)
	self:setDebugLine(stat)
	local contLabel = b:emitLabel()
	local backLabel = b:emitLabel()
	b:emitAD(OP.FORGLOOP, regs, 0)
	b:emitAux((skipOp == OP.FORGPREP_INEXT and 2147483648 or 0) + #stat.vars)
	local endLabel = b:emitLabel()
	self:patchJump(stat, skipLabel, backLabel)
	self:patchJump(stat, backLabel, loopLabel)
	self:patchLoopJumps(stat, oldJumps, endLabel, contLabel)
	for i = #self.loopJumps, oldJumps + 1, -1 do
		self.loopJumps[i] = nil
	end
	self.loops[#self.loops] = nil
	self.regTop = rt
end

function C:visitLocals(node, f)
	if node.k == "Local" then
		f(node)
	end
	forEachChild(node, function(c)
		self:visitLocals(c, f)
	end)
end

function C:resolveAssignConflicts(stat, vars, values)
	local conflict, assigned = {}, {}
	local function visit(node)
		self:visitLocals(node, function(n)
			local reg = self:getExprLocalReg(n)
			if reg >= 0 and assigned[reg] then
				conflict[reg] = true
			end
		end)
	end
	for i, var in vars do
		local li = var.lvalue
		if li.kind == "local" then
			if values[i] then
				visit(values[i])
			end
			assigned[li.reg] = true
		end
	end
	for i, var in vars do
		if var.lvalue.kind ~= "local" and values[i] then
			visit(values[i])
		end
	end
	for i = #vars + 1, #values do
		visit(values[i])
	end
	for _, var in vars do
		local li = var.lvalue
		if (li.kind == "indexname" or li.kind == "indexnumber" or li.kind == "indexexpr") and assigned[li.reg] then
			conflict[li.reg] = true
		end
		if li.kind == "indexexpr" and assigned[li.index] then
			conflict[li.index] = true
		end
	end
	for _, var in vars do
		local li = var.lvalue
		if li.kind == "local" and conflict[li.reg] then
			var.conflictReg = self:allocReg(stat, 1)
		end
	end
end

function C:compileStatAssign(stat)
	local rt = self.regTop
	local b = self.b
	if #stat.vars == 1 and #stat.values == 1 then
		local var = self:compileLValue(stat.vars[1])
		if var.kind == "local" then
			self:compileExpr(stat.values[1], var.reg)
		else
			local reg = self:compileExprAuto(stat.values[1])
			self:setDebugLine(stat.vars[1])
			self:compileAssign(var, reg)
		end
		self.regTop = rt
		return
	end
	local vars = {}
	for i, v in stat.vars do
		vars[i] = { lvalue = self:compileLValue(v) }
	end
	self:resolveAssignConflicts(stat, vars, stat.values)
	local nv, nvals = #stat.vars, #stat.values
	for i = 1, math.min(nv, nvals) do
		local value = stat.values[i]
		if i == nvals and nv > nvals then
			local rest = nv - nvals + 1
			local temp = self:allocReg(stat, rest)
			self:compileExprTempN(value, temp, rest, true)
			for j = i, nv do
				vars[j].valueReg = temp + (j - i)
			end
		else
			local var = vars[i]
			if var.lvalue.kind == "local" then
				var.valueReg = var.conflictReg or var.lvalue.reg
				self:compileExpr(value, var.valueReg)
			else
				var.valueReg = self:compileExprAuto(value)
			end
		end
	end
	for i = nv + 1, nvals do
		self:compileExprSide(stat.values[i])
	end
	for _, var in vars do
		if var.lvalue.kind ~= "local" then
			self:setDebugLine(var.lvalue.line)
			self:compileAssign(var.lvalue, var.valueReg)
		end
	end
	for _, var in vars do
		if var.lvalue.kind == "local" and var.valueReg ~= var.lvalue.reg then
			b:emitABC(OP.MOVE, var.lvalue.reg, var.valueReg, 0)
		end
	end
	self.regTop = rt
end

function C:compileStatCompoundAssign(stat)
	local rt = self.regTop
	local b = self.b
	local var = self:compileLValue(stat.var)
	local target = var.kind == "local" and var.reg or self:allocReg(stat, 1)
	local op = stat.op
	if ARITH[op] then
		if op == "FloorDiv" and self.version < 4 then
			raise(stat.line, "Floor division requires bytecode version 4 or newer")
		end
		if var.kind ~= "local" then
			self:compileLValueUse(var, target, false)
		end
		local rc = self:getConstantNumber(stat.value)
		if rc >= 0 and rc <= 255 then
			b:emitABC(OP[ARITHK[op]], target, target, rc)
		else
			local rr = self:compileExprAuto(stat.value)
			b:emitABC(OP[ARITH[op]], target, target, rr)
		end
	else
		local args = { stat.value }
		unrollConcats(args)
		local regs = self:allocReg(stat, 1 + #args)
		self:compileLValueUse(var, regs, false)
		for i, a in args do
			self:compileExprTempTop(a, regs + i)
		end
		b:emitABC(OP.CONCAT, target, regs, regs + #args)
	end
	if var.kind ~= "local" then
		self:compileAssign(var, target)
	end
	self.regTop = rt
end

function C:compileStatFunction(stat)
	local reg = self:getExprLocalReg(stat.name)
	if reg >= 0 then
		self:compileExpr(stat.func, reg)
		return
	end
	local rt = self.regTop
	reg = self:allocReg(stat, 1)
	self:compileExprTemp(stat.func, reg)
	local var = self:compileLValue(stat.name)
	self:compileAssign(var, reg)
	self.regTop = rt
end

function C:compileStat(node)
	self:setDebugLine(node)
	local k = node.k
	local b = self.b
	if self.cov >= 1 and k ~= "Block" and k ~= "TypeAlias" then
		b:emitABC(OP.COVERAGE, 0, 0, 0)
	end
	if k == "Block" then
		local rt = self.regTop
		local oldLocals = #self.localStack
		local terminatesEarly = false
		for _, s in node.body do
			self:compileStat(s)
			if self:alwaysTerminates(s) then
				terminatesEarly = true
				break
			end
		end
		if not terminatesEarly then
			self:closeLocals(oldLocals)
		end
		self:popLocals(oldLocals)
		self.regTop = rt
	elseif k == "If" then
		self:compileStatIf(node)
	elseif k == "While" then
		self:compileStatWhile(node)
	elseif k == "Repeat" then
		self:compileStatRepeat(node)
	elseif k == "Break" then
		local loop = self.loops[#self.loops]
		self:closeLocals(loop.localOffset)
		local label = b:emitLabel()
		b:emitAD(OP.JUMP, 0, 0)
		self.loopJumps[#self.loopJumps + 1] = { type = "break", label = label }
	elseif k == "Continue" then
		local loop = self.loops[#self.loops]
		if not loop.continueUsed then
			loop.continueUsed = node
		end
		self:closeLocals(loop.localOffsetContinue)
		local label = b:emitLabel()
		b:emitAD(OP.JUMP, 0, 0)
		self.loopJumps[#self.loopJumps + 1] = { type = "continue", label = label }
	elseif k == "Return" then
		if self.opt >= 2 and #self.inlineFrames > 0 then
			self:compileInlineReturn(node)
		else
			self:compileStatReturn(node)
		end
	elseif k == "ExprStat" then
		if node.expr.k == "Call" then
			self:compileExprCall(node.expr, self.regTop, 0)
		else
			self:compileExprSide(node.expr)
		end
	elseif k == "LocalStat" then
		self:compileStatLocal(node)
	elseif k == "For" then
		self:compileStatFor(node)
	elseif k == "ForIn" then
		self:compileStatForIn(node)
	elseif k == "Assign" then
		self:compileStatAssign(node)
	elseif k == "CompoundAssign" then
		self:compileStatCompoundAssign(node)
	elseif k == "FunctionStat" then
		self:compileStatFunction(node)
	elseif k == "LocalFunction" then
		local var = self:allocReg(node, 1)
		self:pushLocal(node.name, var)
		self:compileExprFunction(node.func, var)
		self.locals[node.name].debugpc = b:getDebugPC()
	elseif k == "TypeAlias" then
		return
	else
		raise(node.line, "Unknown statement type %s", tostring(k))
	end
end

function C:compileFunction(func, initialFlags)
	local b = self.b
	local nself = func.self and 1 or 0
	local numparams = #func.args + nself
	local fid = b:beginFunction(numparams, func.vararg)
	self:setDebugLine(func)
	if func.vararg then
		b:emitABC(OP.PREPVARARGS, numparams, 0, 0)
	end
	local args = self:allocReg(func, numparams)
	if func.self then
		self:pushLocal(func.self, args)
	end
	for i, a in func.args do
		self:pushLocal(a, args + nself + i - 1)
	end
	local body = func.body
	local terminatesEarly = false
	for _, s in body.body do
		self:compileStat(s)
		if self:alwaysTerminates(s) then
			terminatesEarly = true
			break
		end
	end
	if not terminatesEarly then
		self:setDebugLineEnd(body)
		self:closeLocals(0)
		b:emitABC(OP.RETURN, 0, 1, 0)
	end
	b:setDebugFunctionLineDefined(func.line)
	if self.dbg >= 1 and func.debugname then
		b:setDebugFunctionName(func.debugname)
	end
	if self.dbg >= 2 and #self.upvals > 0 then
		for _, u in self.upvals do
			b:pushDebugUpval(u.name)
		end
	end
	if self.opt >= 1 then
		b:foldJumps()
	end
	if not b:expandJumps() then
		raise(func.line, "Exceeded jump distance limit; simplify the code to compile")
	end
	self:popLocals(0)
	local flags = initialFlags or 0
	if func.functionDepth == 0 and not self.hasLoops then
		flags = bor(flags, 2)
	end
	if func.hasNative then
		flags = bor(flags, 4)
	end
	local upvals = self.upvals
	b:endFunction(self.stackSize, #upvals, flags)
	local info = { id = fid, upvals = upvals }
	if self.opt >= 2 and not func.vararg and not func.self and not self.getfenvUsed and not self.setfenvUsed then
		info.canInline = true
		info.stackSize = self.stackSize
		info.cost = self:modelCost(func.body, {})
		if self:alwaysTerminates(func.body) then
			info.returnsOne = self:returnsOneVisit(func.body)
		end
	end
	self.functions[func] = info
	self.upvals = {}
	self.stackSize = 0
	self.regTop = 0
	self.hasLoops = false
	self.hasMultiRet = false
	self.loops = {}
	self.loopJumps = {}
	return fid, flags
end

local function tripCount(from, to, step)
	local function fits(v)
		return v >= -32768 and v <= 32767 and v == math.floor(v)
	end
	if not (fits(from) and fits(to) and fits(step)) or step == 0 then
		return -1
	end
	if (step < 0 and to > from) or (step > 0 and to < from) then
		return 0
	end
	return math.floor((to - from) / step) + 1
end

function C:tryCompileUnrolledFor(stat)
	local fromc = self.constants[stat.from]
	local toc = self.constants[stat.to]
	local stepc = stat.step and self.constants[stat.step] or { t = "number", v = 1 }
	if fromc.t ~= "number" or toc.t ~= "number" or stepc.t ~= "number" then
		return false
	end
	local count = tripCount(fromc.v, toc.v, stepc.v)
	if count < 0 then
		return false
	end
	if count == 0 then
		return true
	end
	if count > 25 then
		return false
	end
	local lv = self.variables[stat.var]
	if lv and lv.written then
		return false
	end
	local unrolled = self:modelCost(stat.body, { [stat.var] = true }) * count
	local baseline = (self:modelCost(stat.body, {}) + 1) * count
	local profit = unrolled == 0 and 300 or math.min(300, math.floor(100 * baseline / unrolled))
	local threshold = math.floor(25 * profit / 100)
	if unrolled > threshold then
		return false
	end
	self:compileUnrolledFor(stat, count, fromc.v, stepc.v)
	return true
end

function C:compileUnrolledFor(stat, count, from, step)
	local b = self.b
	local var = stat.var
	local rt = self.regTop
	local oldLocals = #self.localStack
	local oldJumps = #self.loopJumps
	self.loops[#self.loops + 1] = { localOffset = oldLocals, localOffsetContinue = oldLocals }
	local log = {}
	local prevLog = self.changeLog
	self.changeLog = log
	for iv = 0, count - 1 do
		log[#log + 1] = { self.locstants, var, self.locstants[var] }
		self.locstants[var] = { t = "number", v = from + iv * step }
		self:foldStat(stat)
		local iterJumps = #self.loopJumps
		self:compileStat(stat.body)
		local contLabel = b:emitLabel()
		for i = iterJumps + 1, #self.loopJumps do
			if self.loopJumps[i].type == "continue" then
				self:patchJump(stat, self.loopJumps[i].label, contLabel)
			end
		end
	end
	local endLabel = b:emitLabel()
	for i = oldJumps + 1, #self.loopJumps do
		if self.loopJumps[i].type == "break" then
			self:patchJump(stat, self.loopJumps[i].label, endLabel)
		end
	end
	for i = #self.loopJumps, oldJumps + 1, -1 do
		self.loopJumps[i] = nil
	end
	self.loops[#self.loops] = nil
	self.changeLog = prevLog
	self:undoLog(log)
	self.regTop = rt
end

function C:compileInlineReturn(stat)
	self:setDebugLine(stat)
	local frame = self.inlineFrames[#self.inlineFrames]
	self:compileExprListTemp(stat.list, frame.target, frame.targetCount, false)
	self:closeLocals(frame.localOffset)
	local label = self.b:emitLabel()
	self.b:emitAD(OP.JUMP, 0, 0)
	frame.returnJumps[#frame.returnJumps + 1] = label
end

function C:tryCompileInlinedCall(expr, func, target, targetCount, multRet)
	local fi = self.functions[func]
	if self.regTop > 128 or fi.stackSize > 32 then
		return false
	end
	if #self.inlineFrames >= 5 then
		return false
	end
	for _, frame in self.inlineFrames do
		if frame.func == func then
			return false
		end
	end
	if multRet then
		return false
	end
	local nparams, nargs = #func.args, #expr.args
	local varc = {}
	local hasConstant = false
	for i = 1, math.min(nparams, nargs, 8) do
		if self:isConstant(expr.args[i]) then
			varc[func.args[i]] = true
			hasConstant = true
		end
	end
	if nargs ~= 0 and not self:isExprMultRet(expr.args[nargs]) then
		for i = nargs + 1, math.min(nparams, 8) do
			varc[func.args[i]] = true
			hasConstant = true
		end
	end
	local inlinedCost = fi.cost
	if hasConstant then
		local log = {}
		local prevLog = self.changeLog
		self.changeLog = log
		for i, var in func.args do
			local v = self.variables[var]
			if not (v and v.written) then
				local arg = expr.args[i]
				local c
				if not arg then
					c = { t = "nil" }
				else
					c = self.constants[arg]
				end
				if c and not (i == nargs and nparams > nargs and self:isExprMultRet(arg)) then
					log[#log + 1] = { self.locstants, var, self.locstants[var] }
					self.locstants[var] = c
				end
			end
		end
		self:foldStat(func.body)
		inlinedCost = self:modelCost(func.body, varc)
		self.changeLog = prevLog
		self:undoLog(log)
	else
		inlinedCost = fi.cost
	end
	local baseline = fi.cost + 3
	local profit = inlinedCost == 0 and 300 or math.min(300, math.floor(100 * baseline / inlinedCost))
	local threshold = math.floor(25 * profit / 100)
	local isIife = unwrap(expr.func).k == "Function"
	if inlinedCost > threshold and not isIife then
		return false
	end
	self:compileInlinedCall(expr, func, target, targetCount)
	return true
end

function C:compileInlinedCall(expr, func, target, targetCount)
	local b = self.b
	local rt = self.regTop
	local oldLocals = #self.localStack
	local nparams, nargs = #func.args, #expr.args
	local args = {}
	for i, var in func.args do
		local arg = expr.args[i]
		local v = self.variables[var]
		if i == nargs and nparams > nargs and self:isExprMultRet(arg) then
			local tail = nparams - nargs + 1
			local reg = self:allocReg(arg, tail)
			if arg.k == "Call" then
				self:compileExprCall(arg, reg, tail, true)
			else
				self:compileExprVarargs(arg, reg, tail)
			end
			for j = i, nparams do
				args[#args + 1] = { var = func.args[j], reg = reg + (j - i) }
			end
			break
		elseif v and v.written then
			local reg = self:allocReg(arg or expr, 1)
			if arg then
				self:compileExprTemp(arg, reg)
			else
				b:emitABC(OP.LOADNIL, reg, 0, 0)
			end
			args[#args + 1] = { var = var, reg = reg }
		elseif not arg then
			args[#args + 1] = { var = var, value = { t = "nil" } }
		elseif self.constants[arg] then
			args[#args + 1] = { var = var, value = self.constants[arg] }
		else
			local le = unwrap(arg)
			local lv = le.k == "Local" and self.variables[le["local"]] or nil
			local reg = le.k == "Local" and self:getExprLocalReg(le) or -1
			if reg >= 0 and (not lv or not lv.written) then
				args[#args + 1] = { var = var, reg = reg, init = lv and lv.init }
			else
				local temp = self:allocReg(arg, 1)
				self:compileExprTemp(arg, temp)
				args[#args + 1] = { var = var, reg = temp, init = arg }
			end
		end
	end
	for i = nparams + 1, nargs do
		self:compileExprSide(expr.args[i])
	end
	for _, a in args do
		if a.value then
			self.locstants[a.var] = a.value
		else
			self:pushLocal(a.var, a.reg)
			if a.init then
				local vv = self:getVar(a.var)
				vv.init = a.init
			end
		end
	end
	local frame = { func = func, localOffset = oldLocals, target = target, targetCount = targetCount, returnJumps = {} }
	self.inlineFrames[#self.inlineFrames + 1] = frame
	local log = {}
	local prevLog = self.changeLog
	self.changeLog = log
	self:foldStat(func.body)
	local terminatesEarly = false
	for _, st in func.body.body do
		self:compileStat(st)
		if self:alwaysTerminates(st) then
			terminatesEarly = true
			local last = frame.returnJumps[#frame.returnJumps]
			if last and last == b:emitLabel() - 1 then
				b:undoEmit()
				frame.returnJumps[#frame.returnJumps] = nil
			end
			break
		end
	end
	if not terminatesEarly then
		for i = 0, targetCount - 1 do
			b:emitABC(OP.LOADNIL, target + i, 0, 0)
		end
		self:closeLocals(oldLocals)
	end
	self:popLocals(oldLocals)
	local returnLabel = b:emitLabel()
	self:patchJumps(expr, frame.returnJumps, returnLabel)
	self.inlineFrames[#self.inlineFrames] = nil
	for _, var in func.args do
		self.locstants[var] = nil
		local vv = self.variables[var]
		if vv then
			vv.init = nil
		end
	end
	self.changeLog = prevLog
	self:undoLog(log)
	self.regTop = rt
end

function C:returnsOneVisit(node)
	if node.k == "Return" then
		return #node.list == 1 and not self:isExprMultRet(node.list[1])
	elseif node.k == "Function" then
		return true
	end
	local ok = true
	forEachChild(node, function(c)
		if ok and not self:returnsOneVisit(c) then
			ok = false
		end
	end)
	return ok
end

local OPLEN = {}
for _, n in { "GETGLOBAL", "SETGLOBAL", "GETIMPORT", "GETTABLEKS", "SETTABLEKS", "NAMECALL", "JUMPIFEQ", "JUMPIFLE", "JUMPIFLT", "JUMPIFNOTEQ",
	"JUMPIFNOTLE", "JUMPIFNOTLT", "NEWTABLE", "SETLIST", "FORGLOOP", "LOADKX", "FASTCALL2", "FASTCALL2K", "FASTCALL3", "JUMPXEQKNIL",
	"JUMPXEQKB", "JUMPXEQKN", "JUMPXEQKS" } do
	OPLEN[OP[n]] = 2
end

local function compileOrThrow(source, options)
	options = options or {}
	local optLevel = options.optimizationLevel
	if optLevel == nil then
		optLevel = 1
	end
	local dbgLevel = options.debugLevel
	if dbgLevel == nil then
		dbgLevel = 1
	end
	local root, hot = Parser.parse(Lexer.new(source))
	local mainFlags = 0
	for _, h in hot do
		local n = h:match("^optimize%s+(%d)")
		if n then
			optLevel = tonumber(n)
		elseif h == "native" then
			mainFlags = bor(mainFlags, 1)
		end
	end
	optLevel = math.clamp(optLevel, 0, 2)
	dbgLevel = math.clamp(dbgLevel, 0, 2)
	local version = options.bytecodeVersion or 6
	if version < 3 or version > 14 then
		error(":0: unsupported bytecode version " .. tostring(version), 0)
	end
	local builder = Builder.new(version)
	builder:setOpLengths(OPLEN)
	local comp = newCompiler(builder, { optimizationLevel = optLevel, debugLevel = dbgLevel, mutableGlobals = options.mutableGlobals, version = version, coverageLevel = options.coverageLevel })
	comp:trackValues(root)
	comp:scanFenv(root)
	if optLevel >= 1 then
		comp:analyzeBuiltins(root)
		comp:foldStat(root)
		comp:predictShapes(root)
	end
	local functions = {}
	collectFunctions(root, functions)
	for _, f in functions do
		local _, flags = comp:compileFunction(f, 0)
		if bit32.band(flags, 4) ~= 0 and bit32.band(mainFlags, 1) == 0 then
			mainFlags = bor(mainFlags, 4)
		end
	end
	local main = {
		k = "Function", args = {}, vararg = true, body = root, functionDepth = 0, line = root.line, eline = root.eline,
		hasNative = false,
	}
	local mainId = comp:compileFunction(main, mainFlags)
	builder:setMainFunction(mainId)
	return builder:finalize()
end

local LuauCompiler = {}

function LuauCompiler.compile(source, options)
	local ok, result = pcall(compileOrThrow, source, options)
	if ok then
		return result
	end
	return Builder.getError(tostring(result))
end

LuauCompiler.BytecodeVersion = 6
LuauCompiler._compileOrThrow = compileOrThrow

return LuauCompiler
end)()

function Disassembler.LuauToBytecode(source, options)
	assert(type(source) == "string",
		"Disassembler.LuauToBytecode: expected string, got " .. type(source))

	if not (options and options.ForcePort) then
		local native = luau_compile or compilescript
		if native then
			local ok, result = pcall(native, source)
			if not ok then
				error("Disassembler.LuauToBytecode: native compiler failed: " .. tostring(result), 0)
			end
			if string_byte(result, 1) == 0 then
				error("Disassembler.LuauToBytecode: " .. string.sub(result, 2), 0)
			end
			return result
		end
	end

	return Disassembler.CompileLuau(source, options)
end

local DecompilerCore = (function()
local DecompilerCore = {}
do

local string_format, string_byte, string_char = string.format, string.byte, string.char
local table_concat, table_insert, table_remove, table_sort = table.concat, table.insert, table.remove, table.sort
local math_floor, math_huge, math_abs = math.floor, math.huge, math.abs
local band, rshift = bit32.band, bit32.rshift
local bor, lshift, bnot = bit32.bor, bit32.lshift, bit32.bnot

local KEYWORDS = {
	["and"]=1,["break"]=1,["do"]=1,["else"]=1,["elseif"]=1,["end"]=1,["false"]=1,["for"]=1,
	["function"]=1,["if"]=1,["in"]=1,["local"]=1,["nil"]=1,["not"]=1,["or"]=1,["repeat"]=1,
	["return"]=1,["then"]=1,["true"]=1,["until"]=1,["while"]=1,["continue"]=1,["goto"]=1,
}
local identCache = {}
local function isIdent(s)
	if type(s) ~= "string" then return false end
	local c = identCache[s]
	if c == nil then
		c = string.match(s, "^[%a_][%w_]*$") ~= nil and not KEYWORDS[s]
		identCache[s] = c
	end
	return c
end

local KT_NIL, KT_BOOL, KT_NUM, KT_STR, KT_VECTOR, KT_INT, KT_VECTORD = 0, 1, 2, 3, 7, 9, 11

local fmtNumber
do
local G_FORMATS = {}
for p = 1, 17 do G_FORMATS[p] = "%." .. p .. "g" end
function fmtNumber(v)
	if v ~= v then return "(0/0)" end
	if v == math_huge then return "math.huge" end
	if v == -math_huge then return "-math.huge" end
	if v == math_floor(v) and math_abs(v) < 1e15 then
		if v == 0 and 1 / v < 0 then return "-0" end
		return string_format("%d", v)
	end
	for p = 1, 17 do
		local s = string_format(G_FORMATS[p], v)
		if tonumber(s) == v then return s end
	end
	return string_format("%.17g", v)
end
end

local STRING_ESCAPE = {}
for b = 0, 255 do
	local c = string_char(b)
	if b == 34 then STRING_ESCAPE[c] = '\\"'
	elseif b == 92 then STRING_ESCAPE[c] = "\\\\"
	elseif b == 10 then STRING_ESCAPE[c] = "\\n"
	elseif b == 13 then STRING_ESCAPE[c] = "\\r"
	elseif b == 9 then STRING_ESCAPE[c] = "\\t"
	elseif b < 32 or b == 127 or b >= 128 then STRING_ESCAPE[c] = string_format("\\%03d", b) end
end
local function fmtString(s)
	if type(s) == "string" and not string.find(s, '[%c"\\\128-\255]') then return '"' .. s .. '"' end
	local validUtf8 = utf8 and utf8.len(s) ~= nil
	if #s == 0 then return '""' end
	return '"' .. string.gsub(s, validUtf8 and '[%c"\\]' or '[%c"\\\128-\255]', STRING_ESCAPE) .. '"'
end

local function Kn(kind, v) return { t = "K", kind = kind, v = v } end
local K_NIL = function() return Kn("nil") end
local function Kbool(b) return Kn("bool", b) end
local function Knum(v) return Kn("num", v) end
local function Kstr(s) return Kn("str", s) end

local function neg(e)
	if e.t == "Not" then return e.a end
	if e.t == "Cmp" then
		if e.op == "==" then return { t = "Cmp", op = "~=", a = e.a, b = e.b } end
		if e.op == "~=" then return { t = "Cmp", op = "==", a = e.a, b = e.b } end
	end
	if e.t == "K" then
		if e.kind == "bool" then return Kbool(not e.v) end
		if e.kind == "nil" then return Kbool(true) end
	end
	return { t = "Not", a = e }
end

local CUR = { refOpen = {} }
local function isRefLive(r, pc)
	local set = CUR.refOpen[r]
	if not set then return false end
	if pc == nil then return true end
	return set[pc] == true
end

local READS_ONLY = { G = true, U = true, Idx = true, Bin = true, Cmp = true, Neg = true, Len = true, Concat = true }
local function unsafeKey(k)
	if k.t ~= "K" then return true end
	if k.kind == "nil" then return true end
	if k.kind == "num" and k.v ~= k.v then return true end
	return false
end

local function ownEffect(e)
	local t = e.t
	if t == "Call" or t == "MCall" then return true, true end
	if t == "Table" then
		local items = e.items
		for i = 1, #items do
			local k = items[i].k
			if k and unsafeKey(k) then return true, true end
		end
		return false, false
	end
	if READS_ONLY[t] then return true, false end
	if t == "R" then
		local ro = CUR.refOpen[e.r]
		if ro ~= nil and (e.pc == nil or ro[e.pc] == true) then return true, false end
	end
	return false, false
end

local function forEachChild(e, fn, x, y)
	local t = e.t
	local c
	if t == "Idx" then
		c = e.o; if c then fn(c, x, y) end
		c = e.k; if c then fn(c, x, y) end
	elseif t == "Call" then
		c = e.f; if c then fn(c, x, y) end
		local a = e.a
		for i = 1, #a do c = a[i]; if c then fn(c, x, y) end end
	elseif t == "MCall" then
		c = e.o; if c then fn(c, x, y) end
		local a = e.a
		for i = 1, #a do c = a[i]; if c then fn(c, x, y) end end
	elseif t == "Bin" or t == "Cmp" or t == "And" or t == "Or" then
		c = e.a; if c then fn(c, x, y) end
		c = e.b; if c then fn(c, x, y) end
	elseif t == "Not" or t == "Neg" or t == "Len" then
		c = e.a; if c then fn(c, x, y) end
	elseif t == "Concat" then
		local l = e.l
		for i = 1, #l do c = l[i]; if c then fn(c, x, y) end end
	elseif t == "Table" then
		local items = e.items
		for i = 1, #items do
			local it = items[i]
			c = it.k; if c then fn(c, x, y) end
			c = it.v; if c then fn(c, x, y) end
		end
	elseif t == "IfElse" then
		c = e.c; if c then fn(c, x, y) end
		c = e.a; if c then fn(c, x, y) end
		c = e.b; if c then fn(c, x, y) end
	elseif t == "FNPrep" then
		local ops = e.ops
		for i = 1, #ops do c = ops[i]; if c then fn(c, x, y) end end
	elseif t == "Closure" then
		local caps = e.caps
		for i = 1, #caps do c = caps[i].node; if c then fn(c, x, y) end end
	end
end

local function forEachStmtExpr(s, fn, x, y)
	local k = s.k
	local c
	if k == "def" or k == "mdef" or k == "call" or k == "eval" then
		c = s.e; if c then fn(c, x, y) end
	elseif k == "massign" then
		local stores = s.stores
		for qi = 1, #stores do
			local st = stores[qi]
			c = st.o; if c then fn(c, x, y) end
			c = st.key; if c then fn(c, x, y) end
		end
		local vals = s.vals
		for qi = 1, #vals do c = vals[qi]; if c then fn(c, x, y) end end
	elseif k == "set" then
		c = s.o; if c then fn(c, x, y) end
		c = s.key; if c then fn(c, x, y) end
		c = s.v; if c then fn(c, x, y) end
	elseif k == "setg" or k == "setu" then
		c = s.v; if c then fn(c, x, y) end
	elseif k == "setlist" then
		c = s.o; if c then fn(c, x, y) end
		local vals = s.vals
		for i = 1, #vals do c = vals[i]; if c then fn(c, x, y) end end
	elseif k == "ncdef" then
		c = s.o; if c then fn(c, x, y) end
	elseif k == "fgprep" then
		local ops = s.ops
		for i = 1, #ops do c = ops[i]; if c then fn(c, x, y) end end
	end
end

local function forEachTermExpr(t, fn, x, y)
	local k = t.k
	if k == "if" then
		local c = t.c
		if c then fn(c, x, y) end
	elseif k == "ret" then
		local vals = t.vals
		for i = 1, #vals do
			local c = vals[i]
			if c then fn(c, x, y) end
		end
	end
end

local function exprEffect(e)
	local t = e.t
	if t == "R" then
		local ro = CUR.refOpen[e.r]
		return ro ~= nil and (e.pc == nil or ro[e.pc] == true), false
	end
	if t == "K" then return false, false end
	if t == "Call" or t == "MCall" then return true, true end
	if t == "G" or t == "U" then return true, false end
	local rd = READS_ONLY[t] == true
	local c1, c2, c3, r2, w2
	if t == "Idx" then
		c1, c2 = e.o, e.k
	elseif t == "Bin" or t == "Cmp" or t == "And" or t == "Or" then
		c1, c2 = e.a, e.b
	elseif t == "Not" or t == "Neg" or t == "Len" then
		c1 = e.a
	elseif t == "IfElse" then
		c1, c2, c3 = e.c, e.a, e.b
	elseif t == "Concat" then
		local l = e.l
		for i = 1, #l do
			local c = l[i]
			if c then
				r2, w2 = exprEffect(c)
				if w2 then return true, true end
				if r2 then rd = true end
			end
		end
	elseif t == "Table" then
		local items = e.items
		for i = 1, #items do
			local k = items[i].k
			if k and unsafeKey(k) then return true, true end
		end
		for i = 1, #items do
			local it = items[i]
			local c = it.k
			if c then
				r2, w2 = exprEffect(c)
				if w2 then return true, true end
				if r2 then rd = true end
			end
			c = it.v
			if c then
				r2, w2 = exprEffect(c)
				if w2 then return true, true end
				if r2 then rd = true end
			end
		end
	elseif t == "FNPrep" then
		local ops = e.ops
		for i = 1, #ops do
			local c = ops[i]
			if c then
				r2, w2 = exprEffect(c)
				if w2 then return true, true end
				if r2 then rd = true end
			end
		end
	elseif t == "Closure" then
		local caps = e.caps
		for i = 1, #caps do
			local c = caps[i].node
			if c then
				r2, w2 = exprEffect(c)
				if w2 then return true, true end
				if r2 then rd = true end
			end
		end
	end
	if c1 then
		r2, w2 = exprEffect(c1)
		if w2 then return true, true end
		if r2 then rd = true end
	end
	if c2 then
		r2, w2 = exprEffect(c2)
		if w2 then return true, true end
		if r2 then rd = true end
	end
	if c3 then
		r2, w2 = exprEffect(c3)
		if w2 then return true, true end
		if r2 then rd = true end
	end
	return rd, false
end

local function collectRegs(e, out, n)
	local t = e.t
	if t == "R" then
		n = n + 1
		out[n] = e.r
		return n
	end
	if t == "K" or t == "G" or t == "U" then return n end
	local c
	if t == "Idx" then
		c = e.o; if c then n = collectRegs(c, out, n) end
		c = e.k; if c then n = collectRegs(c, out, n) end
	elseif t == "Call" then
		c = e.f; if c then n = collectRegs(c, out, n) end
		local a = e.a
		for i = 1, #a do c = a[i]; if c then n = collectRegs(c, out, n) end end
	elseif t == "MCall" then
		c = e.o; if c then n = collectRegs(c, out, n) end
		local a = e.a
		for i = 1, #a do c = a[i]; if c then n = collectRegs(c, out, n) end end
	elseif t == "Bin" or t == "Cmp" or t == "And" or t == "Or" then
		c = e.a; if c then n = collectRegs(c, out, n) end
		c = e.b; if c then n = collectRegs(c, out, n) end
	elseif t == "Not" or t == "Neg" or t == "Len" then
		c = e.a; if c then n = collectRegs(c, out, n) end
	elseif t == "Concat" then
		local l = e.l
		for i = 1, #l do c = l[i]; if c then n = collectRegs(c, out, n) end end
	elseif t == "Table" then
		local items = e.items
		for i = 1, #items do
			local it = items[i]
			c = it.k; if c then n = collectRegs(c, out, n) end
			c = it.v; if c then n = collectRegs(c, out, n) end
		end
	elseif t == "IfElse" then
		c = e.c; if c then n = collectRegs(c, out, n) end
		c = e.a; if c then n = collectRegs(c, out, n) end
		c = e.b; if c then n = collectRegs(c, out, n) end
	elseif t == "FNPrep" then
		local ops = e.ops
		for i = 1, #ops do c = ops[i]; if c then n = collectRegs(c, out, n) end end
	elseif t == "Closure" then
		local caps = e.caps
		for i = 1, #caps do c = caps[i].node; if c then n = collectRegs(c, out, n) end end
	end
	return n
end

local function exprReads(e, r)
	local t = e.t
	if t == "R" then return e.r == r end
	if t == "K" or t == "G" or t == "U" then return false end
	local c
	if t == "Idx" then
		c = e.o; if c and exprReads(c, r) then return true end
		c = e.k; if c and exprReads(c, r) then return true end
	elseif t == "Call" then
		c = e.f; if c and exprReads(c, r) then return true end
		local a = e.a
		for i = 1, #a do c = a[i]; if c and exprReads(c, r) then return true end end
	elseif t == "MCall" then
		c = e.o; if c and exprReads(c, r) then return true end
		local a = e.a
		for i = 1, #a do c = a[i]; if c and exprReads(c, r) then return true end end
	elseif t == "Bin" or t == "Cmp" or t == "And" or t == "Or" then
		c = e.a; if c and exprReads(c, r) then return true end
		c = e.b; if c and exprReads(c, r) then return true end
	elseif t == "Not" or t == "Neg" or t == "Len" then
		c = e.a; if c and exprReads(c, r) then return true end
	elseif t == "Concat" then
		local l = e.l
		for i = 1, #l do c = l[i]; if c and exprReads(c, r) then return true end end
	elseif t == "Table" then
		local items = e.items
		for i = 1, #items do
			local it = items[i]
			c = it.k; if c and exprReads(c, r) then return true end
			c = it.v; if c and exprReads(c, r) then return true end
		end
	elseif t == "IfElse" then
		c = e.c; if c and exprReads(c, r) then return true end
		c = e.a; if c and exprReads(c, r) then return true end
		c = e.b; if c and exprReads(c, r) then return true end
	elseif t == "FNPrep" then
		local ops = e.ops
		for i = 1, #ops do c = ops[i]; if c and exprReads(c, r) then return true end end
	elseif t == "Closure" then
		local caps = e.caps
		for i = 1, #caps do c = caps[i].node; if c and exprReads(c, r) then return true end end
	end
	return false
end

local EMPTY_RD = {}
local RD_SCRATCH = {}
local function packRd(sc, n)
	if n == 0 then return EMPTY_RD end
	if n == 1 then return { sc[1] } end
	if n == 2 then return { sc[1], sc[2] } end
	if n == 3 then return { sc[1], sc[2], sc[3] } end
	local out = table_create(n)
	for i = 1, n do out[i] = sc[i] end
	return out
end

local function stmtReads(s)
	local k = s.k
	local sc = RD_SCRATCH
	local n = 0
	local c
	if k == "def" or k == "mdef" or k == "call" or k == "eval" then
		c = s.e
		if c then
			if k == "def" and c.t == "Closure" then
				local caps, dst = c.caps, s.dst
				for ci = 1, #caps do
					local nd = caps[ci].node
					if nd and nd.r ~= dst then n = collectRegs(nd, sc, n) end
				end
			else
				n = collectRegs(c, sc, n)
			end
		end
	elseif k == "massign" then
		local stores = s.stores
		for qi = 1, #stores do
			local st = stores[qi]
			c = st.o; if c then n = collectRegs(c, sc, n) end
			c = st.key; if c then n = collectRegs(c, sc, n) end
		end
		local vals = s.vals
		for qi = 1, #vals do c = vals[qi]; if c then n = collectRegs(c, sc, n) end end
	elseif k == "set" then
		c = s.o; if c then n = collectRegs(c, sc, n) end
		c = s.key; if c then n = collectRegs(c, sc, n) end
		c = s.v; if c then n = collectRegs(c, sc, n) end
	elseif k == "setg" or k == "setu" then
		c = s.v; if c then n = collectRegs(c, sc, n) end
	elseif k == "setlist" then
		c = s.o; if c then n = collectRegs(c, sc, n) end
		local vals = s.vals
		for i = 1, #vals do c = vals[i]; if c then n = collectRegs(c, sc, n) end end
	elseif k == "ncdef" then
		c = s.o; if c then n = collectRegs(c, sc, n) end
	elseif k == "fgprep" then
		local ops = s.ops
		for i = 1, #ops do c = ops[i]; if c then n = collectRegs(c, sc, n) end end
	end
	return packRd(sc, n)
end

local function stmtDefs(s)
	local k = s.k
	if k == "def" then return { s.dst }
	elseif k == "mdef" then return s.dsts
	elseif k == "ncdef" then return { s.fnReg, s.selfReg } end
	return nil
end

local function termReads(t)
	local k = t.k
	local sc = RD_SCRATCH
	local n = 0
	if k == "if" then
		local c = t.c
		if c then n = collectRegs(c, sc, n) end
	elseif k == "ret" then
		local vals = t.vals
		for i = 1, #vals do
			local c = vals[i]
			if c then n = collectRegs(c, sc, n) end
		end
	end
	if k == "if" and t.c.t == "FNLoop" then n = n + 1; sc[n] = t.c.base + 2 end
	return packRd(sc, n)
end

local function termDefs(t)
	if t.k == "if" then
		local c = t.c
		if c.t == "FNPrep" or c.t == "FNLoop" then return { c.base + 2 } end
		if c.t == "FGLoop" then
			local d = {}
			for i = 1, c.nv do d[i] = c.base + 2 + i end
			return d
		end
	end
	return nil
end

local function stmtEffect(s)
	local k = s.k
	if k == "call" or k == "set" or k == "setg" or k == "setu" or k == "setlist" or k == "massign" or k == "close" or k == "fgprep" then
		return true, true
	end
	local rd, wr = false, false
	if k == "def" or k == "mdef" or k == "eval" then
		local c = s.e
		if c then rd, wr = exprEffect(c) end
	elseif k == "ncdef" then
		local c = s.o
		if c then rd, wr = exprEffect(c) end
		rd = true
	end
	if k == "def" then
		if isRefLive(s.dst, s.pc) then wr = true end
	elseif k == "mdef" then
		local ds = s.dsts
		for i = 1, #ds do if isRefLive(ds[i], s.pc) then wr = true end end
	elseif k == "ncdef" then
		if isRefLive(s.fnReg, s.pc) or isRefLive(s.selfReg, s.pc) then wr = true end
	end
	return rd, wr
end

DecompilerCore._export = {}
local BINOPS = {
	ADD = "+", SUB = "-", MUL = "*", DIV = "/", MOD = "%", POW = "^", IDIV = "//",
	ADDK = "+", SUBK = "-", MULK = "*", DIVK = "/", MODK = "%", POWK = "^", IDIVK = "//",
}
local NOPS = {
	NOP = true, BREAK = true, COVERAGE = true, PREPVARARGS = true, FASTCALL = true, FASTCALL1 = true,
	FASTCALL2 = true, FASTCALL2K = true, FASTCALL3 = true, FASTPCALL = true, CMPPROTO = true,
	NATIVECALL = true, CAPTURE = true,
}

local function constNode(kv)
	local ty, v = kv.Type, kv.Value
	if ty == KT_NIL then return K_NIL()
	elseif ty == KT_BOOL then return Kbool(v and true or false)
	elseif ty == KT_NUM then return Knum(v)
	elseif ty == KT_STR then return Kstr(v)
	elseif ty == KT_VECTOR or ty == KT_VECTORD then return Kn("vec", v)
	elseif ty == KT_INT then return Kn("int", v)
	end
	return Kn("unsup", "constant type " .. tostring(ty))
end

local function termSuccList(t)
	if t.k == "goto" then return { t.to }
	elseif t.k == "if" then return { t.t, t.f } end
	return {}
end

local BINOP_RHS_CONST = { ADDK = true, SUBK = true, MULK = true, DIVK = true, MODK = true, POWK = true, IDIVK = true }
local JUMPLIKE = {
	JUMP = true, JUMPBACK = true, JUMPX = true,
	JUMPIF = true, JUMPIFNOT = true, JUMPIFEQ = true, JUMPIFLE = true, JUMPIFLT = true,
	JUMPIFNOTEQ = true, JUMPIFNOTLE = true, JUMPIFNOTLT = true,
	JUMPXEQKNIL = true, JUMPXEQKB = true, JUMPXEQKN = true, JUMPXEQKS = true,
	FORNPREP = true, FORNLOOP = true, FORGPREP = true, FORGPREP_NEXT = true, FORGPREP_INEXT = true, FORGLOOP = true,
}
local NO_PENDING_TABLES = {}
local FASTCALL_OPS = {
	FASTCALL = true, FASTCALL1 = true, FASTCALL2 = true, FASTCALL2K = true, FASTCALL3 = true, FASTPCALL = true,
}

local lift
do
local sOps, sPcs, sAuxs, sK, sProto, sData
local sBlockAt, sTgts, sCapsOf
local sCur, sSt, sNs
local sPendingMv
local sFastNext = false
local sPendingTables = nil
local sRefSites, sRefSitesN = nil, 0
local sAnyClose = false

local function Rp(r, pc) return { t = "R", r = r, pc = pc, var = nil } end

local function kconst(idx)
	local kv = sK[idx + 1]
	if not kv then return Kn("unsup", "missing constant " .. tostring(idx)) end
	return constNode(kv)
end
local function kstring(idx)
	local kv = sK[idx + 1]
	return kv and kv.Value
end

local function blk(i)
	local b = sBlockAt[i]
	if not b then error("jump into the middle of a block at instruction " .. tostring(i)) end
	return b
end

local function takeMultiArgs(first, base, pc, tail)
	local nr = base - first
	if nr < 0 then nr = 0 end
	local list = table_create(nr + 1)
	local q = 0
	for r = first, base - 1 do q = q + 1; list[q] = { t = "R", r = r, pc = pc, var = nil } end
	list[q + 1] = tail
	return list
end

local function importExpr(id)
	local count = band(rshift(id, 30), 3)
	local e
	for k = 1, count do
		local idx = band(rshift(id, 30 - 10 * k), 1023)
		local name = kstring(idx)
		if k == 1 then e = { t = "G", name = name }
		else e = { t = "Idx", o = e, k = Kstr(name) } end
	end
	return e or Kn("unsup", "empty import")
end

local function noteRefSite(i)
	local rs = sRefSites
	if not rs then rs = {}; sRefSites = rs end
	local m = sRefSitesN + 1
	sRefSitesN = m
	rs[m] = { block = sCur, idx = sNs, caps = sCapsOf[i] }
end

local C_CAPTURE, C_CLOSURE, C_JUMP, C_JUMPX, C_LOADB, C_RETURN = 1, 2, 3, 4, 5, 6
local CLS = table_create(OP_UNSUP, 0)
CLS[OPID.CAPTURE] = C_CAPTURE
CLS[OPID.NEWCLOSURE] = C_CLOSURE
CLS[OPID.DUPCLOSURE] = C_CLOSURE
for name in pairs(JUMPLIKE) do CLS[OPID[name]] = C_JUMP end
CLS[OPID.JUMPX] = C_JUMPX
CLS[OPID.LOADB] = C_LOADB
CLS[OPID.RETURN] = C_RETURN
local ID_CAPTURE = OPID.CAPTURE

local H = table_create(OP_UNSUP)
local function reg(name, fn)
	local id = OPID[name]
	if id == nil then error("lift: no opcode id for " .. name) end
	H[id] = fn
end

reg("MOVE", function(raw, A, i, pc)
	local B = (raw // 65536) % 256
	return { t = "R", r = B, pc = pc, var = nil }, { B }
end)
reg("GETUPVAL", function(raw, A, i, pc)
	return { t = "U", i = (raw // 65536) % 256 }, EMPTY_RD
end)
reg("LOADK", function(raw, A, i, pc)
	local e = kconst(raw // 65536)
	if e.t == "K" then return e, EMPTY_RD end
	return e
end)
reg("LOADN", function(raw, A, i, pc)
	local bx = raw // 65536
	return { t = "K", kind = "num", v = (bx >= 0x8000) and (bx - 0x10000) or bx }, EMPTY_RD
end)
reg("LOADNIL", function(raw, A, i, pc) return K_NIL(), EMPTY_RD end)
reg("LOADB", function(raw, A, i, pc)
	local B, C = (raw // 65536) % 256, raw // 16777216
	sNs = sNs + 1
	sSt[sNs] = { k = "def", dst = A, e = Kbool(B ~= 0), pc = pc, _rd = EMPTY_RD, _ef = nil, did = nil, dvar = nil }
	if C ~= 0 then sCur.term = { k = "goto", to = blk(sTgts[i]), pc = pc, _rd = nil } end
end)
reg("LOADKX", function(raw, A, i, pc) return kconst(sAuxs[i]) end)
reg("GETIMPORT", function(raw, A, i, pc) return importExpr(sAuxs[i] or 0), EMPTY_RD end)
reg("GETGLOBAL", function(raw, A, i, pc) return { t = "G", name = kstring(sAuxs[i]) }, EMPTY_RD end)
reg("SETGLOBAL", function(raw, A, i, pc)
	sNs = sNs + 1
	sSt[sNs] = { k = "setg", name = kstring(sAuxs[i]), v = { t = "R", r = A, pc = pc, var = nil },
		pc = pc, _rd = { A }, _ef = nil }
end)
reg("SETUPVAL", function(raw, A, i, pc)
	sNs = sNs + 1
	sSt[sNs] = { k = "setu", i = (raw // 65536) % 256, v = { t = "R", r = A, pc = pc, var = nil },
		pc = pc, _rd = { A }, _ef = nil }
end)
reg("CLOSEUPVALS", function(raw, A, i, pc)
	sAnyClose = true
	sNs = sNs + 1
	sSt[sNs] = { k = "close", a = A, pc = pc, _rd = nil, _ef = nil }
end)

local function getTableKS(udata)
	return function(raw, A, i, pc)
		local ki = sAuxs[i]
		if udata then ki = band(ki, 0xFFFF) end
		local B = (raw // 65536) % 256
		return { t = "Idx", o = { t = "R", r = B, pc = pc, var = nil },
			k = { t = "K", kind = "str", v = kstring(ki) } }, { B }
	end
end
reg("GETTABLEKS", getTableKS(false))
reg("GETUDATAKS", getTableKS(true))
reg("GETTABLE", function(raw, A, i, pc)
	local B, C = (raw // 65536) % 256, raw // 16777216
	return { t = "Idx", o = { t = "R", r = B, pc = pc, var = nil },
		k = { t = "R", r = C, pc = pc, var = nil } }, { B, C }
end)
reg("GETTABLEN", function(raw, A, i, pc)
	return { t = "Idx", o = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil },
		k = { t = "K", kind = "num", v = raw // 16777216 + 1 } }
end)
local function setTableKS(udata)
	return function(raw, A, i, pc)
		local ki = sAuxs[i]
		if udata then ki = band(ki, 0xFFFF) end
		local B = (raw // 65536) % 256
		sNs = sNs + 1
		sSt[sNs] = { k = "set", o = { t = "R", r = B, pc = pc, var = nil },
			key = { t = "K", kind = "str", v = kstring(ki) },
			v = { t = "R", r = A, pc = pc, var = nil }, pc = pc, _rd = { B, A }, _ef = nil }
	end
end
reg("SETTABLEKS", setTableKS(false))
reg("SETUDATAKS", setTableKS(true))
reg("SETTABLE", function(raw, A, i, pc)
	sNs = sNs + 1
	sSt[sNs] = { k = "set", o = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil },
		key = { t = "R", r = raw // 16777216, pc = pc, var = nil },
		v = { t = "R", r = A, pc = pc, var = nil }, pc = pc, _rd = nil, _ef = nil }
end)
reg("SETTABLEN", function(raw, A, i, pc)
	sNs = sNs + 1
	sSt[sNs] = { k = "set", o = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil },
		key = { t = "K", kind = "num", v = raw // 16777216 + 1 },
		v = { t = "R", r = A, pc = pc, var = nil }, pc = pc, _rd = nil, _ef = nil }
end)
reg("NEWTABLE", function(raw, A, i, pc) return { t = "Table", items = {} }, EMPTY_RD end)
reg("DUPTABLE", function(raw, A, i, pc)
	local kv = sK[(raw // 65536) + 1]
	local items
	local anyPending = false
	local tmpl = kv and kv.Value
	if tmpl and tmpl.Ids then
		local tids = tmpl.Ids
		local nids = #tids
		items = table_create(nids)
		for ii = 1, nids do
			local key = sK[tids[ii]]
			local item = { k = Kstr(key and key.Value), v = nil, pending = true }
			local ci = tmpl.ConstantIndices and tmpl.ConstantIndices[ii]
			if ci and ci >= 0 then item.v = kconst(ci); item.pending = false else anyPending = true end
			items[ii] = item
		end
	else
		items = {}
	end
	local tbl = { t = "Table", items = items, template = true }
	if anyPending then
		if sPendingTables == nil then sPendingTables = {} end
		sPendingTables[#sPendingTables + 1] = tbl
	end
	return tbl
end)
reg("SETLIST", function(raw, A, i, pc)
	local B, C = (raw // 65536) % 256, raw // 16777216
	local vals
	if C == 0 then
		if not sPendingMv then error("SETLIST with open values but no multi-value producer at pc " .. sPcs[i]) end
		vals = takeMultiArgs(B, sPendingMv.base, pc, sPendingMv.expr)
		sPendingMv = nil
	else
		local nv = C - 1
		if nv < 0 then nv = 0 end
		vals = table_create(nv)
		local q = 0
		for r = B, B + C - 2 do q = q + 1; vals[q] = { t = "R", r = r, pc = pc, var = nil } end
	end
	sNs = sNs + 1
	sSt[sNs] = { k = "setlist", o = { t = "R", r = A, pc = pc, var = nil }, start = sAuxs[i], vals = vals,
		pc = pc, _rd = nil, _ef = nil }
end)

local function nameCall(udata)
	return function(raw, A, i, pc)
		local ki = sAuxs[i]
		if udata then ki = band(ki, 0xFFFF) end
		local B = (raw // 65536) % 256
		sNs = sNs + 1
		sSt[sNs] = { k = "ncdef", fnReg = A, selfReg = A + 1,
			o = { t = "R", r = B, pc = pc, var = nil },
			name = kstring(ki), pc = pc, _rd = { B }, _ef = nil }
	end
end
reg("NAMECALL", nameCall(false))
reg("NAMECALLUDATA", nameCall(true))
local function callHandler(raw, A, i, pc)
	local B, C = (raw // 65536) % 256, raw // 16777216
	local args
	if B == 0 then
		if not sPendingMv then error("CALL with open arguments but no multi-value producer at pc " .. sPcs[i]) end
		args = takeMultiArgs(A + 1, sPendingMv.base, pc, sPendingMv.expr)
		sPendingMv = nil
	elseif B == 1 then
		args = {}
	else
		args = table_create(B - 1)
		local q = 0
		for r = A + 1, A + B - 1 do q = q + 1; args[q] = { t = "R", r = r, pc = pc, var = nil } end
	end
	local call
	if sFastNext then
		call = { t = "Call", f = { t = "R", r = A, pc = pc, var = nil }, a = args, multi = (C == 0), fast = true }
		sFastNext = false
	else
		call = { t = "Call", f = { t = "R", r = A, pc = pc, var = nil }, a = args, multi = (C == 0) }
	end
	local crd = nil
	if B >= 1 then
		if B == 1 then crd = { A }
		elseif B == 2 then crd = { A, A + 1 }
		elseif B == 3 then crd = { A, A + 1, A + 2 }
		else
			crd = table_create(B)
			for q = 1, B do crd[q] = A + q - 1 end
		end
	end
	if C == 0 then sPendingMv = { base = A, expr = call }
	elseif C == 1 then
		sNs = sNs + 1
		sSt[sNs] = { k = "call", e = call, pc = pc, _rd = crd, _ef = nil }
	elseif C == 2 then return call, crd
	else
		local dsts = table_create(C - 1)
		local q = 0
		for r = A, A + C - 2 do q = q + 1; dsts[q] = r end
		sNs = sNs + 1
		sSt[sNs] = { k = "mdef", dsts = dsts, e = call, pc = pc, _rd = crd, _ef = nil, dids = nil, dvars = nil }
	end
	return nil
end
reg("CALL", callHandler)
reg("CALLFB", callHandler)
reg("RETURN", function(raw, A, i, pc)
	local B = (raw // 65536) % 256
	local vals
	if B == 0 then
		if not sPendingMv then error("RETURN with open values but no multi-value producer at pc " .. sPcs[i]) end
		vals = takeMultiArgs(A, sPendingMv.base, pc, sPendingMv.expr)
		sPendingMv = nil
	elseif B == 1 then
		vals = {}
	else
		vals = table_create(B - 1)
		local q = 0
		for r = A, A + B - 2 do q = q + 1; vals[q] = { t = "R", r = r, pc = pc, var = nil } end
	end
	sCur.term = { k = "ret", vals = vals, pc = pc, _rd = nil }
end)
local function hFast() sFastNext = true end
for name in pairs(FASTCALL_OPS) do reg(name, hFast) end

reg("NEWCLOSURE", function(raw, A, i, pc)
	local child = sProto.Protos[(raw // 65536) + 1]
	sNs = sNs + 1
	sSt[sNs] = { k = "def", dst = A, e = { t = "Closure", proto = child, caps = sCapsOf[i] or {} },
		pc = pc, _rd = nil, _ef = nil, did = nil, dvar = nil }
	noteRefSite(i)
end)
reg("DUPCLOSURE", function(raw, A, i, pc)
	local kv = sK[(raw // 65536) + 1]
	local child = kv and sData.Protos[(kv.Value or 0) + 1]
	sNs = sNs + 1
	sSt[sNs] = { k = "def", dst = A, e = { t = "Closure", proto = child, caps = sCapsOf[i] or {} },
		pc = pc, _rd = nil, _ef = nil, did = nil, dvar = nil }
	noteRefSite(i)
end)

local function jumpXEQK(kind)
	return function(raw, A, i, pc)
		local aux = sAuxs[i] or 0
		local notFlag = band(rshift(aux, 31), 1)
		local rhs
		if kind == "NIL" then rhs = K_NIL()
		elseif kind == "B" then rhs = Kbool(band(aux, 1) == 1)
		else rhs = kconst(band(aux, 0xFFFFFF)) end
		local c = { t = "Cmp", op = (notFlag == 1) and "==" or "~=",
			a = { t = "R", r = A, pc = pc, var = nil }, b = rhs }
		sCur.term = { k = "if", c = c, t = blk(i + 1), f = blk(sTgts[i]), pc = pc, _rd = nil }
	end
end
reg("JUMPXEQKS", jumpXEQK("S"))
reg("JUMPXEQKN", jumpXEQK("N"))
reg("JUMPXEQKB", jumpXEQK("B"))
reg("JUMPXEQKNIL", jumpXEQK("NIL"))
reg("JUMPIFNOT", function(raw, A, i, pc)
	sCur.term = { k = "if", c = { t = "R", r = A, pc = pc, var = nil }, t = blk(i + 1), f = blk(sTgts[i]),
		pc = pc, _rd = nil }
end)
reg("JUMPIF", function(raw, A, i, pc)
	sCur.term = { k = "if", c = { t = "Not", a = { t = "R", r = A, pc = pc, var = nil } },
		t = blk(i + 1), f = blk(sTgts[i]), pc = pc, _rd = nil }
end)
local function hGoto(raw, A, i, pc)
	sCur.term = { k = "goto", to = blk(sTgts[i]), pc = pc, _rd = nil }
end
reg("JUMP", hGoto)
reg("JUMPBACK", hGoto)
reg("JUMPX", hGoto)
local function cmpJump(sym, wrap)
	return function(raw, A, i, pc)
		local c
		local aux = sAuxs[i]
		local ra, rb = { t = "R", r = A, pc = pc, var = nil }, { t = "R", r = aux, pc = pc, var = nil }
		if wrap then c = { t = "Not", a = { t = "Cmp", op = sym, a = ra, b = rb } }
		else c = { t = "Cmp", op = sym, a = ra, b = rb } end
		sCur.term = { k = "if", c = c, t = blk(i + 1), f = blk(sTgts[i]), pc = pc, _rd = nil }
	end
end
reg("JUMPIFEQ", cmpJump("~=", false))
reg("JUMPIFNOTEQ", cmpJump("==", false))
reg("JUMPIFLE", cmpJump("<=", true))
reg("JUMPIFNOTLE", cmpJump("<=", false))
reg("JUMPIFLT", cmpJump("<", true))
reg("JUMPIFNOTLT", cmpJump("<", false))
reg("FORNPREP", function(raw, A, i, pc)
	sCur.term = { k = "if", c = { t = "FNPrep", base = A, ops = { Rp(A, pc), Rp(A + 1, pc), Rp(A + 2, pc) } },
		t = blk(i + 1), f = blk(sTgts[i]), pc = pc, _rd = nil }
end)
reg("FORNLOOP", function(raw, A, i, pc)
	sCur.term = { k = "if", c = { t = "FNLoop", base = A }, t = blk(sTgts[i]), f = blk(i + 1), pc = pc, _rd = nil }
end)
local function hForgPrep(raw, A, i, pc)
	sNs = sNs + 1
	sSt[sNs] = { k = "fgprep", base = A, ops = { Rp(A, pc), Rp(A + 1, pc), Rp(A + 2, pc) },
		pc = pc, _rd = nil, _ef = nil }
	sCur.term = { k = "goto", to = blk(sTgts[i]), pc = pc, _rd = nil }
end
reg("FORGPREP", hForgPrep)
reg("FORGPREP_NEXT", hForgPrep)
reg("FORGPREP_INEXT", hForgPrep)
reg("FORGLOOP", function(raw, A, i, pc)
	local aux = sAuxs[i] or 0
	sCur.term = { k = "if", c = { t = "FGLoop", base = A, nv = band(aux, 0xFF), ipairs = band(rshift(aux, 31), 1) == 1 },
		t = blk(sTgts[i]), f = blk(i + 1), pc = pc, _rd = nil }
end)

local function binop(sym, rhsConst)
	return function(raw, A, i, pc)
		local rhs, rdc
		local B, C = (raw // 65536) % 256, raw // 16777216
		if rhsConst then
			rhs = kconst(C)
			if rhs.t == "K" then rdc = { B } end
		else
			rhs = { t = "R", r = C, pc = pc, var = nil }
			rdc = { B, C }
		end
		return { t = "Bin", op = sym, a = { t = "R", r = B, pc = pc, var = nil }, b = rhs }, rdc
	end
end
for name, sym in pairs(BINOPS) do reg(name, binop(sym, BINOP_RHS_CONST[name] == true)) end
reg("SUBRK", function(raw, A, i, pc)
	return { t = "Bin", op = "-", a = kconst((raw // 65536) % 256),
		b = { t = "R", r = raw // 16777216, pc = pc, var = nil } }
end)
reg("DIVRK", function(raw, A, i, pc)
	return { t = "Bin", op = "/", a = kconst((raw // 65536) % 256),
		b = { t = "R", r = raw // 16777216, pc = pc, var = nil } }
end)
reg("AND", function(raw, A, i, pc)
	return { t = "And", a = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil },
		b = { t = "R", r = raw // 16777216, pc = pc, var = nil } }
end)
reg("OR", function(raw, A, i, pc)
	return { t = "Or", a = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil },
		b = { t = "R", r = raw // 16777216, pc = pc, var = nil } }
end)
reg("ANDK", function(raw, A, i, pc)
	return { t = "And", a = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil }, b = kconst(raw // 16777216) }
end)
reg("ORK", function(raw, A, i, pc)
	return { t = "Or", a = { t = "R", r = (raw // 65536) % 256, pc = pc, var = nil }, b = kconst(raw // 16777216) }
end)
reg("CONCAT", function(raw, A, i, pc)
	local lo, hi = (raw // 65536) % 256, raw // 16777216
	local nl = hi - lo + 1
	if nl < 0 then nl = 0 end
	local l = table_create(nl)
	local q = 0
	for r = lo, hi do q = q + 1; l[q] = { t = "R", r = r, pc = pc, var = nil } end
	return { t = "Concat", l = l }
end)
local function unary(tag)
	return function(raw, A, i, pc)
		local B = (raw // 65536) % 256
		return { t = tag, a = { t = "R", r = B, pc = pc, var = nil } }, { B }
	end
end
reg("NOT", unary("Not"))
reg("MINUS", unary("Neg"))
reg("LENGTH", unary("Len"))
reg("GETVARARGS", function(raw, A, i, pc)
	local B = (raw // 65536) % 256
	if B == 0 then
		sPendingMv = { base = A, expr = { t = "Vararg", multi = true } }
	elseif B == 2 then return { t = "Vararg", multi = false }
	elseif B > 2 then
		local dsts = table_create(B - 2 + 1)
		local q = 0
		for r = A, A + B - 2 do q = q + 1; dsts[q] = r end
		sNs = sNs + 1
		sSt[sNs] = { k = "mdef", dsts = dsts, e = { t = "Vararg", multi = false }, pc = pc,
			_rd = nil, _ef = nil, dids = nil, dvars = nil }
	end
	return nil
end)

local function hNop() end
for name in pairs(NOPS) do
	local id = OPID[name]
	if id == nil then error("lift: no opcode id for " .. name) end
	if H[id] == nil then H[id] = hNop end
end
H[OP_UNSUP] = function(raw, A, i, pc)
	return { t = "Unsup", text = "unsupported opcode " .. tostring(sOps[i]) }
end
for id = 1, OP_UNSUP do
	if H[id] == nil then error("lift: opcode id " .. id .. " has no handler") end
end

function lift(proto, data)
	local ops, pcs, words, auxs = proto.OpNames, proto.OpPcs, proto.OpWords, proto.OpAux
	local n = proto.OpCount
	local K = proto.Constants
	local ids = proto.OpIds
	if not ids then
		ids = table_create(n)
		for i = 1, n do ids[i] = OPID[ops[i]] or OP_UNSUP end
	end
	sOps, sPcs, sAuxs, sK, sProto, sData = ops, pcs, auxs, K, proto, data
	sCapsOf, sPendingMv, sFastNext, sPendingTables, sRefSites, sRefSitesN, sAnyClose = nil, nil, false, nil, nil, 0, false
	sCur, sSt, sNs = nil, nil, 0

	local pcToIdx = table_create(n > 0 and (pcs[n] + 2) or 0)
	local skip = nil
	local refRegs = {}
	local capsOf = nil
	local curCaps, curN, closurePc = nil, 0, nil
	for i = 1, n do
		pcToIdx[pcs[i]] = i
		local c = CLS[ids[i]]
		if c == C_CAPTURE and curCaps then
			if not skip then skip = {} end
			skip[i] = true
			local w = words[i]
			local cA, cB = (w // 256) % 256, (w // 65536) % 256
			curN = curN + 1
			if cA == 2 then
				curCaps[curN] = { mode = "up", idx = cB }
			else
				local nd = { t = "R", r = cB, pc = closurePc, var = nil, noinline = true }
				if cA == 1 then refRegs[cB] = true; nd.refcap = true end
				curCaps[curN] = { mode = (cA == 1) and "ref" or "val", reg = cB, node = nd }
			end
		elseif c == C_CLOSURE then
			curCaps = {}
			curN = 0
			closurePc = pcs[i]
			if not capsOf then capsOf = {} end
			capsOf[i] = curCaps
		else
			curCaps = nil
		end
	end
	sCapsOf = capsOf

	local isLeader = table_create(n + 1, false)
	isLeader[1] = true
	local tgts = table_create(n)
	for i = 1, n do
		local c = CLS[ids[i]]
		if c >= C_JUMP then
			if c == C_RETURN then
				if i + 1 <= n then isLeader[i + 1] = true end
			else
				local raw = words[i]
				if c ~= C_LOADB or raw // 16777216 ~= 0 then
					local off
					if c == C_JUMPX then
						local sax = raw // 256
						off = (sax >= 0x800000) and (sax - 0x1000000) or sax
					elseif c == C_LOADB then off = raw // 16777216
					else
						local bx = raw // 65536
						off = (bx >= 0x8000) and (bx - 0x10000) or bx
					end
					local pc = pcs[i]
					local tg = pcToIdx[pc + 1 + off]
					if not tg then error("bad jump target at pc " .. tostring(pc)) end
					tgts[i] = tg
					if tg >= 1 and tg <= n then isLeader[tg] = true end
					if i + 1 <= n then isLeader[i + 1] = true end
				end
			end
		end
	end
	sTgts = tgts

	local blocks, blockAt = {}, table_create(n + 1)
	local nBlocks = 0
	local prev = nil
	local moved = false
	for i = 1, n do
		local lead = isLeader[i] or moved
		if skip and ids[i] == ID_CAPTURE and skip[i] then
			moved = lead
		else
			moved = false
			if lead then
				nBlocks = nBlocks + 1
				if prev then prev.stmts = table_create(i - prev.first) end
				local b = {
					id = nBlocks, stmts = nil, term = nil, preds = nil, succs = nil, first = i,
					reach = nil, dead = nil, _clean = nil, lid = nil, webIdx = nil,
					loArr = nil, loOff = nil, liArr = nil, liOff = nil, liW = nil,
				}
				blocks[nBlocks] = b
				blockAt[i] = b
				prev = b
			end
		end
	end
	if prev then prev.stmts = table_create(n + 1 - prev.first) end
	sBlockAt = blockAt

	local lastPc
	for i = 1, n do
		local id = ids[i]
		if not (id == ID_CAPTURE and skip and skip[i]) then
			local pc = pcs[i]
			local b = blockAt[i]
			if b then
				local pb = sCur
				if pb and not pb.term then pb.term = { k = "goto", to = b, _rd = nil } end
				sCur = b; sSt = b.stmts; sNs = 0; sPendingMv = nil; sFastNext = false
			end
			local raw = words[i]
			local A = (raw // 256) % 256
			local e, rdc = H[id](raw, A, i, pc)
			if e then
				local ns = sNs + 1
				sNs = ns
				sSt[ns] = { k = "def", dst = A, e = e, pc = pc, _rd = rdc, _ef = nil, did = nil, dvar = nil }
			end
			lastPc = pc
		end
	end
	local last = sCur
	if last and not last.term then last.term = { k = "ret", vals = {}, pc = lastPc, _rd = nil } end

	for bi = 1, nBlocks do
		local b = blocks[bi]
		if not b.term then b.term = { k = "ret", vals = {} } end
	end

	local refSites, anyClose, pendingTables = sRefSites, sAnyClose, sPendingTables
	sOps, sPcs, sAuxs, sK, sProto, sData = nil, nil, nil, nil, nil, nil
	sBlockAt, sTgts, sCapsOf, sCur, sSt, sPendingMv, sPendingTables, sRefSites = nil, nil, nil, nil, nil, nil, nil, nil

	local refOpen = {}
	if next(refRegs) ~= nil then
		if not refSites then refSites = {} end
		local firstPc = table_create(nBlocks)
		for bi = 1, nBlocks do firstPc[bi] = pcs[blocks[bi].first] end
		local closeAt = nil
		if anyClose then
			closeAt = {}
			for bi = 1, nBlocks do
				local stmts = blocks[bi].stmts
				local list
				for idx = 1, #stmts do
					if stmts[idx].k == "close" then
						if not list then list = {} end
						list[#list + 1] = idx
					end
				end
				closeAt[bi] = list
			end
		end
		local regs = {}
		for _, site in ipairs(refSites) do
			for _, cap in ipairs(site.caps or {}) do
				if cap.mode == "ref" then
					local r = cap.reg
					local R = regs[r]
					if not R then
						R = { iv = table_create(nBlocks), done = table_create(nBlocks, false) }
						regs[r] = R
					end
					local ivR, done = R.iv, R.done
					local function mark(b, from)
						local stmts = b.stmts
						local bi = b.id
						local stopIdx
						if closeAt then
							local cl = closeAt[bi]
							if cl then
								for q = 1, #cl do
									local ci = cl[q]
									if ci >= from and stmts[ci].a <= r then stopIdx = ci; break end
								end
							end
						end
						local lo, hi
						if stopIdx then
							if from < stopIdx then lo = stmts[from].pc; hi = stmts[stopIdx - 1].pc end
						else
							local term = b.term
							local s = stmts[from]
							if s then lo = s.pc else lo = term.pc end
							hi = term.pc
							if not hi then
								local last = stmts[#stmts]
								hi = last and last.pc
							end
						end
						if lo and hi then
							local list = ivR[bi]
							if not list then
								ivR[bi] = { lo, hi }
							else
								local covered = false
								for q = 1, #list, 2 do
									if list[q] <= lo and hi <= list[q + 1] then covered = true; break end
								end
								if not covered then
									list[#list + 1] = lo
									list[#list + 1] = hi
								end
							end
						end
						return stopIdx == nil
					end
					local sb = site.block
					local stack, sp = {}, 0
					local visited = {}
					if mark(sb, site.idx) then
						local ss = termSuccList(sb.term)
						for q = 1, #ss do
							local s = ss[q]
							if not visited[s] then visited[s] = true; sp = sp + 1; stack[sp] = s end
						end
					end
					while sp > 0 do
						local b = stack[sp]
						stack[sp] = nil
						sp = sp - 1
						local bi = b.id
						if not done[bi] then
							done[bi] = true
							if mark(b, 1) then
								local ss = termSuccList(b.term)
								for q = 1, #ss do
									local s = ss[q]
									if not visited[s] then visited[s] = true; sp = sp + 1; stack[sp] = s end
								end
							end
						end
					end
				end
			end
		end
		for r, R in pairs(regs) do
			local ivR = R.iv
			refOpen[r] = setmetatable({}, { __index = function(_, pc)
				local a, z = 1, nBlocks
				while a < z do
					local mid = (a + z + 1) // 2
					if firstPc[mid] <= pc then a = mid else z = mid - 1 end
				end
				local list = ivR[a]
				if list then
					for q = 1, #list, 2 do
						if pc >= list[q] and pc <= list[q + 1] then return true end
					end
				end
				return nil
			end })
		end
	end

	return { blocks = blocks, entry = blocks[1], refRegs = refRegs, refOpen = refOpen, maxStack = proto.MaxStackSize,
		pendingTables = pendingTables or NO_PENDING_TABLES }
end
end
local dbgExpr, dbgStmt

local function isMarker(c)
	local t = c.t
	return t == "FNPrep" or t == "FNLoop" or t == "FGLoop"
end

local function liveBlocks(cfg)
	local cached = cfg._live
	if cached then return cached end
	local blocks = cfg.blocks
	local n = #blocks
	local out = table_create(n)
	local m = 0
	for i = 1, n do
		local b = blocks[i]
		if not b.dead then m = m + 1; out[m] = b end
	end
	return out
end

local function rebuildEdges(cfg)
	cfg._live = nil
	local blocks = cfg.blocks
	for i = 1, #blocks do
		local b = blocks[i]
		b.preds = {}; b.succs = nil; b.reach = false
	end
	local stack = { cfg.entry }
	cfg.entry.reach = true
	local sp = 1
	while sp > 0 do
		local b = stack[sp]
		stack[sp] = nil
		sp = sp - 1
		local ss = termSuccList(b.term)
		b.succs = ss
		for i = 1, #ss do
			local s = ss[i]
			if not s.reach then s.reach = true; sp = sp + 1; stack[sp] = s end
		end
	end
	local nb = #blocks
	local out = table_create(nb)
	local m = 0
	for i = 1, nb do
		local b = blocks[i]
		if not b.reach then b.dead = true; b.succs = {} end
	end
	for i = 1, nb do
		local b = blocks[i]
		if not b.dead then
			m = m + 1; out[m] = b
			local ss = b.succs
			for q = 1, #ss do
				local p = ss[q].preds
				p[#p + 1] = b
			end
		end
	end
	cfg._live = out
end

local function readsOf(s)
	local c = s._rd
	if not c then c = stmtReads(s); s._rd = c end
	return c
end
local function termReadsCached(t)
	local c = t._rd
	if not c then c = termReads(t); t._rd = c end
	return c
end
local function liveOutHas(b, r)
	local arr = b.loArr
	if not arr then
		local lo = b.liveOut
		return lo ~= nil and lo[r] == true
	end
	local w = rshift(r, 5)
	if r < 0 or w >= b.liW then return false end
	return band(arr[b.loOff + w + 1], lshift(1, band(r, 31))) ~= 0
end

local function liveInHas(b, r)
	local arr = b.liArr
	if not arr then
		local li = b.liveIn
		return li ~= nil and li[r] == true
	end
	local w = rshift(r, 5)
	if r < 0 or w >= b.liW then return false end
	return band(arr[b.liOff + w + 1], lshift(1, band(r, 31))) ~= 0
end

local computeLiveness
do
local BITS = {}
for k = 0, 31 do BITS[k] = lshift(1, k) end

local function liveUseDef(blocks, nb, W)
	local limit = W * 32
	local size = nb * W
	local use, def = table_create(size, 0), table_create(size, 0)
	for bi = 1, nb do
		local b = blocks[bi]
		local base = (bi - 1) * W
		b.lid = bi
		local stmts = b.stmts
		for si = 1, #stmts do
			local s = stmts[si]
			local rd = readsOf(s)
			for q = 1, #rd do
				local r = rd[q]
				if r < 0 or r >= limit then return nil, r end
				local w = base + r // 32 + 1
				local bit = BITS[r % 32]
				if band(def[w], bit) == 0 then use[w] = bor(use[w], bit) end
			end
			local k = s.k
			if k == "def" then
				local r = s.dst
				if r < 0 or r >= limit then return nil, r end
				local w = base + r // 32 + 1
				def[w] = bor(def[w], BITS[r % 32])
			elseif k == "mdef" then
				local ds = s.dsts
				for q = 1, #ds do
					local r = ds[q]
					if r < 0 or r >= limit then return nil, r end
					local w = base + r // 32 + 1
					def[w] = bor(def[w], BITS[r % 32])
				end
			elseif k == "ncdef" then
				local r = s.fnReg
				if r ~= nil then
					if r < 0 or r >= limit then return nil, r end
					local w = base + r // 32 + 1
					def[w] = bor(def[w], BITS[r % 32])
					r = s.selfReg
					if r ~= nil then
						if r < 0 or r >= limit then return nil, r end
						w = base + r // 32 + 1
						def[w] = bor(def[w], BITS[r % 32])
					end
				end
			end
		end
		local term = b.term
		local rd = termReadsCached(term)
		for q = 1, #rd do
			local r = rd[q]
			if r < 0 or r >= limit then return nil, r end
			local w = base + r // 32 + 1
			local bit = BITS[r % 32]
			if band(def[w], bit) == 0 then use[w] = bor(use[w], bit) end
		end
		local ds = termDefs(term)
		if ds then
			for q = 1, #ds do
				local r = ds[q]
				if r < 0 or r >= limit then return nil, r end
				local w = base + r // 32 + 1
				def[w] = bor(def[w], BITS[r % 32])
			end
		end
	end
	return use, def
end

local function computeLivenessSparse(cfg, blocks)
	cfg.liveHash = true
	for _, b in ipairs(blocks) do
		local use, def = {}, {}
		for _, s in ipairs(b.stmts) do
			local rd = readsOf(s)
			for q = 1, #rd do local r = rd[q]; if not def[r] then use[r] = true end end
			local ds = stmtDefs(s)
			if ds then for _, r in ipairs(ds) do def[r] = true end end
		end
		local rd = termReadsCached(b.term)
		for q = 1, #rd do local r = rd[q]; if not def[r] then use[r] = true end end
		local ds = termDefs(b.term)
		if ds then for _, r in ipairs(ds) do def[r] = true end end
		b.use, b.def = use, def
		b.liveIn, b.liveOut = {}, {}
		b.loArr, b.liArr = nil, nil
		b._clean = false
	end
	local changed = true
	while changed do
		changed = false
		for bi = #blocks, 1, -1 do
			local b = blocks[bi]
			local out = b.liveOut
			for _, s in ipairs(b.succs) do
				for r in pairs(s.liveIn) do
					if not out[r] then out[r] = true; changed = true end
				end
			end
			local inn = b.liveIn
			for r in pairs(b.use) do if not inn[r] then inn[r] = true; changed = true end end
			for r in pairs(out) do
				if not b.def[r] and not inn[r] then inn[r] = true; changed = true end
			end
		end
	end
end

function computeLiveness(cfg)
	local blocks = liveBlocks(cfg)
	local nb = #blocks
	if cfg.liveHash then return computeLivenessSparse(cfg, blocks) end
	local W = cfg.liveW or (rshift((cfg.maxStack or 255) + 8, 5) + 1)
	local use, def = liveUseDef(blocks, nb, W)
	while not use do
		local need = rshift(def, 5) + 1
		if def < 0 or def >= 0x7FFFFFFF or need > 64 or need <= W then return computeLivenessSparse(cfg, blocks) end
		W = need
		use, def = liveUseDef(blocks, nb, W)
	end
	cfg.liveW = W
	local size = nb * W

	local lin, lout = table_create(size, 0), table_create(size, 0)
	local changed = true
	while changed do
		changed = false
		local back = false
		for bi = nb, 1, -1 do
			local b = blocks[bi]
			local base = (bi - 1) * W
			local succs = b.succs
			for si = 1, #succs do
				local slid = succs[si].lid
				if slid <= bi then back = true end
				local sbase = (slid - 1) * W
				for w = 1, W do
					local v = lin[sbase + w]
					if v ~= 0 then
						local o = lout[base + w]
						local nv = bor(o, v)
						if nv ~= o then lout[base + w] = nv; changed = true end
					end
				end
			end
			for w = 1, W do
				local i = base + w
				local cur = lin[i]
				local nv = bor(cur, bor(use[i], band(lout[i], bnot(def[i]))))
				if nv ~= cur then lin[i] = nv; changed = true end
			end
		end
		if not back then break end
	end

	for bi = 1, nb do
		local b = blocks[bi]
		local base = (bi - 1) * W
		local oa = b.loArr
		if oa and b.liW == W then
			local ob = b.loOff
			for w = 1, W do
				if oa[ob + w] ~= lout[base + w] then b._clean = false; break end
			end
		else
			b._clean = false
		end
		b.loArr, b.loOff = lout, base
		b.liArr, b.liOff = lin, base
		b.liW = W
	end
end
end

local function pureExpr(e)
	local rd, wr = exprEffect(e)
	return not rd and not wr
end

local function effCommute(rd1, wr1, rd2, wr2)
	if wr1 and (rd2 or wr2) then return false end
	if rd1 and wr2 then return false end
	return true
end

local function effOf(s)
	local c = s._ef
	if c == nil then
		local rd, wr = stmtEffect(s)
		c = (rd and 1 or 0) + (wr and 2 or 0)
		s._ef = c
	end
	return c == 1 or c == 3, c >= 2
end
local function invalidate(s) s._rd = nil; s._ef = nil end

local locateUse
do
local luFound, luAccR, luAccW, luReg, luRef
local luC, luK, luN, luR, luW, luD

local function luVisit(container, key, depth)
	local e = container[key]
	if e == nil then return end
	local t = e.t
	if t == "R" then
		if e.r == luReg then
			luFound = true
			luC, luK, luN, luR, luW, luD = container, key, e, luAccR, luAccW, depth
		else
			local ro = luRef[e.r]
			if ro ~= nil and (e.pc == nil or ro[e.pc] == true) then luAccR = true end
		end
		return
	end
	if t == "Idx" then
		luVisit(e, "o", depth); if luFound then return end
		luVisit(e, "k", depth); if luFound then return end
	elseif t == "Call" then
		local savedR, savedW = luAccR, luAccW
		luVisit(e, "f", depth); if luFound then return end
		if e.fast then luAccR, luAccW = savedR, savedW end
		local a = e.a
		for i = 1, #a do luVisit(a, i, depth); if luFound then return end end
	elseif t == "MCall" then
		luVisit(e, "o", depth); if luFound then return end
		local a = e.a
		for i = 1, #a do luVisit(a, i, depth); if luFound then return end end
	elseif t == "Bin" or t == "Cmp" then
		luVisit(e, "a", depth); if luFound then return end
		luVisit(e, "b", depth); if luFound then return end
	elseif t == "And" or t == "Or" then
		luVisit(e, "a", depth); if luFound then return end
		luVisit(e, "b", depth + 1); if luFound then return end
	elseif t == "Not" or t == "Neg" or t == "Len" then
		luVisit(e, "a", depth); if luFound then return end
	elseif t == "Concat" then
		local l = e.l
		for i = 1, #l do luVisit(l, i, depth); if luFound then return end end
	elseif t == "Table" then
		local items = e.items
		for i = 1, #items do
			local it = items[i]
			if it.k then luVisit(it, "k", depth); if luFound then return end end
			luVisit(it, "v", depth); if luFound then return end
		end
	elseif t == "IfElse" then
		luVisit(e, "c", depth); if luFound then return end
		luVisit(e, "a", depth + 1); if luFound then return end
		luVisit(e, "b", depth + 1); if luFound then return end
	elseif t == "FNPrep" then
		local ops = e.ops
		for i = 1, #ops do luVisit(ops, i, depth); if luFound then return end end
	elseif t == "Closure" then
		local caps = e.caps
		for i = 1, #caps do
			local c = caps[i]
			if c.node then luVisit(c, "node", depth); if luFound then return end end
		end
	end
	local rd, wr = ownEffect(e)
	luAccR = luAccR or rd; luAccW = luAccW or wr
end

function locateUse(target, isTerm, r)
	luFound, luAccR, luAccW, luReg, luRef = false, false, false, r, CUR.refOpen
	local k = target.k
	if isTerm then
		if k == "if" then
			luVisit(target, "c", 0)
		elseif k == "ret" then
			local vals = target.vals
			for i = 1, #vals do luVisit(vals, i, 0); if luFound then break end end
		end
	elseif k == "def" or k == "mdef" or k == "call" or k == "eval" then
		luVisit(target, "e", 0)
	elseif k == "set" then
		local o = target.o
		if o ~= nil and not (o.t == "R" and o.r ~= r) then luVisit(target, "o", 0) end
		if not luFound then
			local key = target.key
			if key ~= nil and not (key.t == "R" and key.r ~= r) then luVisit(target, "key", 0) end
		end
		if not luFound then luVisit(target, "v", 0) end
	elseif k == "setg" or k == "setu" then
		luVisit(target, "v", 0)
	elseif k == "massign" then
		local stores = target.stores
		for qi = 1, #stores do
			local st = stores[qi]
			if st.o ~= nil then luVisit(st, "o", 0); if luFound then break end end
			if st.key ~= nil then luVisit(st, "key", 0); if luFound then break end end
		end
		if not luFound then
			local vals = target.vals
			for qi = 1, #vals do luVisit(vals, qi, 0); if luFound then break end end
		end
	elseif k == "setlist" then
		luVisit(target, "o", 0)
		if not luFound then
			local vals = target.vals
			for i = 1, #vals do luVisit(vals, i, 0); if luFound then break end end
		end
	elseif k == "ncdef" then
		luVisit(target, "o", 0)
	elseif k == "fgprep" then
		local ops = target.ops
		for i = 1, #ops do luVisit(ops, i, 0); if luFound then break end end
	end
	if not luFound then return nil end
	local c, kk, n, rd, wr, d = luC, luK, luN, luR, luW, luD
	luC, luN = nil, nil
	return c, kk, n, rd, wr, d
end
end

local function stmtDefsAny(s, set)
	local k = s.k
	local nset = #set
	if k == "def" then
		local d = s.dst
		for q = 1, nset do if set[q] == d then return true end end
	elseif k == "mdef" then
		local ds = s.dsts
		for q = 1, #ds do
			local d = ds[q]
			for p = 1, nset do if set[p] == d then return true end end
		end
	elseif k == "ncdef" then
		local f, sr = s.fnReg, s.selfReg
		for q = 1, nset do
			local x = set[q]
			if x == f or x == sr then return true end
		end
	end
	return false
end

local function tryInline(b, S, i, j, s, r)
	local E = s.e
	local isTerm = j > #S
	local target = isTerm and b.term or S[j]
	local lc, lk, ln, lrd, lwr, ldepth = locateUse(target, isTerm, r)
	if lc == nil or ln.noinline then return false end
	if E.t == "Table" and not isTerm and lc == target and lk == "o"
		and (target.k == "set" or target.k == "setlist") then
		return false
	end
	local rdE, wrE = effOf(s)
	if ldepth > 0 and (rdE or wrE) then return false end
	if not effCommute(rdE, wrE, lrd, lwr) then return false end
	if j - i > 1 then
		local regsE = readsOf(s)
		for k = i + 1, j - 1 do
			local sk = S[k]
			if stmtDefsAny(sk, regsE) then return false end
			if sk.k == "close" then
				for z = 1, #regsE do if regsE[z] >= sk.a then return false end end
			else
				local rdk, wrk = effOf(sk)
				if not effCommute(rdE, wrE, rdk, wrk) then return false end
			end
		end
	end
	lc[lk] = E
	invalidate(target)
	return true
end

local inlineBlock
do
local RUNR, BND = table_create(300), table_create(300)
local rLo, rHi = 1, 0
local FAILED = {}
local failedList, failedN = {}, 0

local function pushStmt(s)
	local k = s.k
	local runR, bnd = RUNR, BND
	if k == "def" then
		local i = s.dst + 1
		runR[i] = 0; bnd[i] = true
		if i < rLo then rLo = i end
		if i > rHi then rHi = i end
	elseif k == "mdef" then
		local ds = s.dsts
		for q = 1, #ds do
			local i = ds[q] + 1
			runR[i] = 0; bnd[i] = true
			if i < rLo then rLo = i end
			if i > rHi then rHi = i end
		end
	elseif k == "ncdef" then
		local f = s.fnReg
		if f ~= nil then
			local i = f + 1
			runR[i] = 0; bnd[i] = true
			if i < rLo then rLo = i end
			if i > rHi then rHi = i end
			local sr = s.selfReg
			if sr ~= nil then
				i = sr + 1
				runR[i] = 0; bnd[i] = true
				if i < rLo then rLo = i end
				if i > rHi then rHi = i end
			end
		end
	end
	local rd = readsOf(s)
	for q = 1, #rd do
		local i = rd[q] + 1
		runR[i] = (runR[i] or 0) + 1
		if i < rLo then rLo = i end
		if i > rHi then rHi = i end
	end
end

local function pushTerm(t)
	local runR, bnd = RUNR, BND
	local ds = termDefs(t)
	if ds then
		for q = 1, #ds do
			local i = ds[q] + 1
			runR[i] = 0; bnd[i] = true
			if i < rLo then rLo = i end
			if i > rHi then rHi = i end
		end
	end
	local rd = termReadsCached(t)
	for q = 1, #rd do
		local i = rd[q] + 1
		runR[i] = (runR[i] or 0) + 1
		if i < rLo then rLo = i end
		if i > rHi then rHi = i end
	end
end

local function moveReads(s, gone)
	local runR = RUNR
	local rd = readsOf(s)
	for q = 1, #rd do
		local i = rd[q] + 1
		runR[i] = (runR[i] or 0) + 1
		if i < rLo then rLo = i end
		if i > rHi then rHi = i end
	end
	local i = gone + 1
	runR[i] = (runR[i] or 0) - 1
	if i < rLo then rLo = i end
	if i > rHi then rHi = i end
end

function inlineBlock(b)
	local S = b.stmts
	local changed = false
	local liveDirty = false
	local redo = false
	for q = 1, failedN do FAILED[failedList[q]] = nil; failedList[q] = nil end
	failedN = 0
	if rHi - rLo > 4096 then
		RUNR, BND = {}, {}
	else
		for i = rLo, rHi do RUNR[i] = nil; BND[i] = nil end
	end
	rLo, rHi = 1000000, -1
	local runR, bnd = RUNR, BND
	local refOpen = CUR.refOpen

	local term = b.term
	pushTerm(term)

	local i = #S
	while i >= 1 do
		local s = S[i]
		local kept = true
		local sk = s.k
		if sk == "def" then
			local selfCapturing = false
			local e = s.e
			if e.t == "Closure" then
				local caps = e.caps
				for ci = 1, #caps do
					local c = caps[ci]
					if c.node and c.node.r == s.dst then selfCapturing = true end
				end
			end
			local r = s.dst
			local ro = refOpen[r]
			if not (ro ~= nil and (s.pc == nil or ro[s.pc] == true)) and not selfCapturing then
				local count = runR[r + 1] or 0
				if count == 1 or count == 0 then
					local deadAfter = bnd[r + 1] or not liveOutHas(b, r)
					if deadAfter then
						if count == 1 then
							local nS = #S
							local useIdx = nil
							for j = i + 1, nS + 1 do
								local rd
								if j <= nS then rd = readsOf(S[j]) else rd = termReadsCached(term) end
								for q = 1, #rd do
									if rd[q] == r then useIdx = j; break end
								end
								if useIdx then break end
							end
							local tgt = useIdx <= nS and S[useIdx] or nil
							if tryInline(b, S, i, useIdx, s, r) then
								moveReads(s, r)
								table_remove(S, i)
								kept = false
								changed = true
								if tgt and FAILED[tgt] then redo = true end
							else
								FAILED[s] = true; failedN = failedN + 1; failedList[failedN] = s
							end
						else
							local rdE, wrE = effOf(s)
							if not rdE and not wrE then
								table_remove(S, i)
								kept = false
								changed = true
								liveDirty = true
							elseif e.t == "Call" or e.t == "MCall" then
								S[i] = { k = "call", e = e, pc = s.pc, _rd = nil, _ef = nil }
								changed = true
							end
						end
					end
				end
			end
		elseif sk == "ncdef" and not isRefLive(s.fnReg, s.pc) and not isRefLive(s.selfReg, s.pc) then
			local A, A1 = s.fnReg, s.selfReg
			local cntF, cntS = runR[A + 1] or 0, runR[A1 + 1] or 0
			local useIdx = nil
			if cntF == 1 and cntS == 1 then
				local rF, rS = false, false
				for j = i + 1, #S + 1 do
					local rdset, sj
					if j <= #S then sj = S[j]; rdset = readsOf(sj) else rdset = termReadsCached(term) end
					local hitF, hitS = false, false
					for q = 1, #rdset do
						local x = rdset[q]
						if x == A then hitF = true elseif x == A1 then hitS = true end
					end
					if (not rF and hitF) or (not rS and hitS) then useIdx = j; break end
					if sj then
						local kj = sj.k
						if kj == "def" then
							local d = sj.dst
							if d == A then rF = true end
							if d == A1 then rS = true end
						elseif kj == "mdef" then
							local ds = sj.dsts
							for q = 1, #ds do
								if ds[q] == A then rF = true end
								if ds[q] == A1 then rS = true end
							end
						elseif kj == "ncdef" then
							local f = sj.fnReg
							if f ~= nil then
								if f == A then rF = true end
								if f == A1 then rS = true end
								local sr = sj.selfReg
								if sr ~= nil then
									if sr == A then rF = true end
									if sr == A1 then rS = true end
								end
							end
						end
					else
						local ds = termDefs(term)
						if ds then
							for q = 1, #ds do
								if ds[q] == A then rF = true end
								if ds[q] == A1 then rS = true end
							end
						end
					end
				end
			end
			local fusable = cntF == 1 and cntS == 1 and useIdx
				and (bnd[A + 1] or not liveOutHas(b, A)) and (bnd[A1 + 1] or not liveOutHas(b, A1))
			local fused = false
			if fusable then
				local isTerm = useIdx > #S
				local target = isTerm and term or S[useIdx]
				local lc, _, ln, lrd, lwr, ldepth = locateUse(target, isTerm, A)
				if lc ~= nil and not ln.noinline and lc.f == ln and lc.t == "Call" then
					local call = lc
					local a1 = call.a[1]
					if a1 and a1.t == "R" and a1.r == A1 and not a1.noinline then
						local rdE, wrE = exprEffect(s.o)
						local okk = true
						if ldepth > 0 and (rdE or wrE) then okk = false end
						if okk and not effCommute(rdE, wrE, lrd, lwr) then okk = false end
						if okk then
							if useIdx - i > 1 then
								local regsE = readsOf(s)
								for k = i + 1, useIdx - 1 do
									local sk2 = S[k]
									if stmtDefsAny(sk2, regsE) then okk = false end
									local rdk, wrk = effOf(sk2)
									if not effCommute(rdE, wrE, rdk, wrk) then okk = false end
								end
							end
						end
						if okk then
							local args = {}
							for q = 2, #call.a do args[#args + 1] = call.a[q] end
							call.t = "MCall"
							call.o = s.o
							call.n = s.name
							call.f = nil
							call.a = args
							invalidate(target)
							moveReads(s, A)
							local ia = A1 + 1
							runR[ia] = (runR[ia] or 0) - 1
							if ia < rLo then rLo = ia end
							if ia > rHi then rHi = ia end
							local tgt = not isTerm and target or nil
							table_remove(S, i)
							kept = false
							changed = true
							fused = true
							if tgt and FAILED[tgt] then redo = true end
						end
					end
				end
			end
			if fusable and not fused then
				FAILED[s] = true; failedN = failedN + 1; failedList[failedN] = s
			end
		end
		if kept then pushStmt(S[i]) end
		i = i - 1
	end
	return changed, liveDirty, not redo
end
end

local function normalizeDegenerate(cfg)
	local changed = false
	for _, b in ipairs(liveBlocks(cfg)) do
		local t = b.term
		if t.k == "if" and t.t == t.f and not isMarker(t.c) then
			local c = t.c
			if c.t == "Call" or c.t == "MCall" then
				b.stmts[#b.stmts + 1] = { k = "call", e = c }
			elseif not pureExpr(c) then
				b.stmts[#b.stmts + 1] = { k = "eval", e = c }
			end
			b.term = { k = "goto", to = t.t }
			b._clean = false
			changed = true
		end
	end
	return changed
end

local function mergeBlocks(cfg)
	local changed = false
	for _, a in ipairs(liveBlocks(cfg)) do
		if not a.dead then
			while a.term.k == "goto" do
				local bb = a.term.to
				if bb == a or bb == cfg.entry or #bb.preds ~= 1 or bb.dead then break end
				for _, s in ipairs(bb.stmts) do a.stmts[#a.stmts + 1] = s end
				a.term = bb.term
				bb.dead = true
				a._clean = false
				changed = true
				a.succs = termSuccList(a.term)
				for _, s in ipairs(a.succs) do
					for pi, p in ipairs(s.preds) do if p == bb then s.preds[pi] = a end end
				end
			end
		end
	end
	if changed then rebuildEdges(cfg) end
	return changed
end

local function retargetPreds(cfg, from, to)
	for _, b in ipairs(liveBlocks(cfg)) do
		local t = b.term
		if t.k == "goto" then
			if t.to == from then t.to = to end
		elseif t.k == "if" then
			if t.t == from then t.t = to end
			if t.f == from then t.f = to end
		end
	end
end

local function normalizeBlocks(cfg)
	local changed = false
	local live = liveBlocks(cfg)
	local retBlocks = 0
	for bi = 1, #live do
		local b = live[bi]
		if #b.stmts == 0 and b.term.k == "ret" then retBlocks = retBlocks + 1 end
	end
	if retBlocks >= 2 then
		local canon = {}
		for _, b in ipairs(live) do
			if not b.dead and #b.stmts == 0 and b.term.k == "ret" then
				local parts = {}
				for i, v in ipairs(b.term.vals) do parts[i] = dbgExpr(v) end
				local key = table_concat(parts, "|") .. "#" .. tostring(#b.term.vals)
				local c = canon[key]
				if not c then canon[key] = b
				elseif c ~= b and b ~= cfg.entry then
					retargetPreds(cfg, b, c)
					changed = true
				end
			end
		end
	end
	for _, b in ipairs(live) do
		if not b.dead and b ~= cfg.entry and #b.stmts == 0 and b.term.k == "goto" and b.term.to ~= b then
			local to = b.term.to
			local seen, cur = { [b] = true }, to
			local ok = true
			while cur.term.k == "goto" and #cur.stmts == 0 and cur ~= cfg.entry do
				if seen[cur] then ok = false break end
				seen[cur] = true
				cur = cur.term.to
			end
			if ok then
				local hasPred = false
				for _, p in ipairs(b.preds or {}) do hasPred = true end
				if hasPred then
					retargetPreds(cfg, b, to)
					changed = true
				end
			end
		end
	end
	if changed then
		rebuildEdges(cfg)
		for _, b in ipairs(liveBlocks(cfg)) do b._clean = false end
	end
	return changed
end

local function foldUsable(X, Y)
	return Y ~= X and not Y.dead and Y.term.k == "if" and not isMarker(Y.term.c)
		and #Y.stmts == 0 and #Y.preds == 1 and Y.preds[1] == X and Y.term.t ~= Y.term.f
end

local function patchEdgesAfterFold(cfg, ord, X, Y, Z, W)
	cfg._live = nil
	X.succs = termSuccList(X.term)
	local zp = Z.preds
	for q = 1, #zp do
		if zp[q] == Y then table_remove(zp, q); break end
	end
	local preds, n = W.preds, 0
	local xo, placed = ord[X], false
	local out = table_create(#preds)
	for i = 1, #preds do
		local p = preds[i]
		if p ~= Y then
			if not placed and p ~= X and ord[p] > xo then n = n + 1; out[n] = X; placed = true end
			if p == X then placed = true end
			n = n + 1; out[n] = p
		end
	end
	if not placed then out[n + 1] = X end
	W.preds = out
	Y.preds = {}; Y.succs = {}; Y.reach = false
end

local function foldConditions(cfg)
	local changedAny = false
	local blocks = cfg.blocks
	local nb = #blocks
	local ord
	local i = 0
	while i < nb do
		i = i + 1
		local X = blocks[i]
		if not X.dead and X.term.k == "if" and not isMarker(X.term.c) and X.term.t ~= X.term.f then
			local tm = X.term
			local Yt, Yf = tm.t, tm.f
			local did = false
			local Y, Z, W
			if foldUsable(X, Yt) then
				Y = Yt
				if Y.term.f == tm.f then
					X.term = { k = "if", c = { t = "And", a = tm.c, b = Y.term.c }, t = Y.term.t, f = tm.f }
					Z, W = tm.f, Y.term.t
					did = true
				elseif Y.term.t == tm.f then
					X.term = { k = "if", c = { t = "Or", a = neg(tm.c), b = Y.term.c }, t = tm.f, f = Y.term.f }
					Z, W = tm.f, Y.term.f
					did = true
				end
				if did then Y.dead = true end
			end
			if not did and foldUsable(X, Yf) then
				Y = Yf
				if Y.term.t == tm.t then
					X.term = { k = "if", c = { t = "Or", a = tm.c, b = Y.term.c }, t = tm.t, f = Y.term.f }
					Z, W = tm.t, Y.term.f
					did = true
				elseif Y.term.f == tm.t then
					X.term = { k = "if", c = { t = "And", a = neg(tm.c), b = Y.term.c }, t = Y.term.t, f = tm.t }
					Z, W = tm.t, Y.term.t
					did = true
				end
				if did then Y.dead = true end
			end
			if did then
				X._rd = nil
				X._clean = false
				changedAny = true
				if Y == cfg.entry or cfg.entry.dead then
					rebuildEdges(cfg)
					i = 0
				else
					if not ord then
						ord = {}
						for k = 1, nb do ord[blocks[k]] = k end
					end
					local first = i
					local xp = X.preds
					for k = 1, #xp do
						local p = xp[k]
						if not p.dead and ord[p] < first then first = ord[p] end
					end
					patchEdgesAfterFold(cfg, ord, X, Y, Z, W)
					i = first - 1
				end
			end
		end
	end
	return changedAny
end

local function isBoolish(e)
	return e.t == "Cmp" or e.t == "Not"
end

local readsReg = exprReads

local function singleDefBlock(Y)
	return #Y.stmts == 1 and Y.stmts[1].k == "def" and Y.term.k == "goto"
end

local function patchEdgesAfterCollapse(cfg, ord, X, M, dead1, dead2)
	cfg._live = nil
	X.succs = { M }
	local preds, n = M.preds, 0
	local xo, placed = ord[X], false
	local out = {}
	for i = 1, #preds do
		local p = preds[i]
		if p ~= dead1 and p ~= dead2 then
			if not placed and p ~= X and ord[p] > xo then n = n + 1; out[n] = X; placed = true end
			if p == X then placed = true end
			n = n + 1; out[n] = p
		end
	end
	if not placed then out[n + 1] = X end
	M.preds = out
	for _, d in ipairs({ dead1, dead2 }) do
		d.preds = {}; d.succs = {}; d.reach = false
	end
end

local function collapseDiamonds(cfg)
	local changedAny = false
	local ord, pM, pDead1, pDead2
	local src = liveBlocks(cfg)
	local list = table_create(#src)
	for k = 1, #src do list[k] = src[k] end
	local i = 0
	while i < #list do
		i = i + 1
		local X = list[i]
		if not X.dead and X.term.k == "if" and not isMarker(X.term.c) and X.term.t ~= X.term.f then
			local tm = X.term
			local did = false
			for side = 1, 2 do
				local Y = (side == 1) and tm.t or tm.f
				local M = (side == 1) and tm.f or tm.t
				if Y ~= X and Y ~= M and not Y.dead and #Y.preds == 1 and singleDefBlock(Y)
					and Y.term.to == M and M ~= X then
					local ydef = Y.stmts[1]
					local r = ydef.dst
					local last = X.stmts[#X.stmts]
					if last and last.k == "def" and last.dst == r and not isRefLive(r, last.pc)
						and not readsReg(ydef.e, r) then
						local enter = (side == 1) and tm.c or neg(tm.c)
						local V1, E2 = last.e, ydef.e
						local newE
						if enter.t == "R" and enter.r == r then
							newE = { t = "And", a = V1, b = E2 }
						elseif enter.t == "Not" and enter.a.t == "R" and enter.a.r == r then
							newE = { t = "Or", a = V1, b = E2 }
						elseif V1.t == "K" and V1.kind == "bool" and isBoolish(enter)
							and not readsReg(enter, r) then
							if V1.v == false then newE = { t = "And", a = enter, b = E2 }
							else newE = { t = "Or", a = neg(enter), b = E2 } end
						end
						if newE then
							last.e = newE
							invalidate(last)
							X.term = { k = "goto", to = M }
							Y.dead = true
							pM, pDead1, pDead2 = M, Y, nil
							did = true
							break
						end
					end
				end
			end
			if not did then
				local T, Fb = tm.t, tm.f
				if T ~= X and Fb ~= X and not T.dead and not Fb.dead and #T.preds == 1 and #Fb.preds == 1
					and singleDefBlock(T) and singleDefBlock(Fb)
					and T.term.to == Fb.term.to and T.term.to ~= X
					and T.stmts[1].dst == Fb.stmts[1].dst and not isRefLive(T.stmts[1].dst, T.stmts[1].pc) then
					local r = T.stmts[1].dst
					local M = T.term.to
					local Vt, Ve = T.stmts[1].e, Fb.stmts[1].e
					local c = tm.c
					local newE
					if Vt.t == "K" and Vt.kind == "bool" and Ve.t == "K" and Ve.kind == "bool" and Vt.v ~= Ve.v then
						if Vt.v == true then
							if isBoolish(c) then newE = c else newE = { t = "IfElse", c = c, a = Vt, b = Ve } end
						else
							newE = neg(c)
						end
					else
						newE = { t = "IfElse", c = c, a = Vt, b = Ve }
					end
					X.stmts[#X.stmts + 1] = { k = "def", dst = r, e = newE, pc = T.stmts[1].pc, _rd = nil, _ef = nil, did = nil, dvar = nil }
					X.term = { k = "goto", to = M }
					T.dead = true; Fb.dead = true
					pM, pDead1, pDead2 = M, T, Fb
					did = true
				end
			end
			if did then
				X._clean = false
				changedAny = true
				if not ord then
					ord = {}
					for k, b in ipairs(cfg.blocks) do ord[b] = k end
				end
				local first = ord[X]
				for _, ps in ipairs({ X.preds, pM.preds }) do
					for k = 1, #ps do
						local p = ps[k]
						if not p.dead and ord[p] < first then first = ord[p] end
					end
				end
				patchEdgesAfterCollapse(cfg, ord, X, pM, pDead1, pDead2)
				for _, d in ipairs({ pDead1, pDead2 }) do
					local lo, hi, od = 1, #list, ord[d]
					while lo < hi do
						local mid = (lo + hi) // 2
						if ord[list[mid]] < od then lo = mid + 1 else hi = mid end
					end
					table_remove(list, lo)
				end
				local lo, hi = 1, #list + 1
				while lo < hi do
					local mid = (lo + hi) // 2
					if ord[list[mid]] < first then lo = mid + 1 else hi = mid end
				end
				i = lo - 1
			end
		end
	end
	return changedAny
end

local function foldValueTests(cfg)
	for _, P in ipairs(liveBlocks(cfg)) do
		if not P.dead and P.term.k == "if" and not isMarker(P.term.c) and P.term.t ~= P.term.f then
			local tm = P.term
			for side = 1, 2 do
				local X = (side == 1) and tm.t or tm.f
				local Z = (side == 1) and tm.f or tm.t
				if X ~= P and X ~= Z and not X.dead and #X.preds == 1 and X.preds[1] == P
					and #X.stmts == 1 and X.stmts[1].k == "def" and X.term.k == "if" and not isMarker(X.term.c)
					and X.term.t ~= X.term.f then
					local d = X.stmts[1]
					local r = d.dst
					local c2 = X.term.c
					local testsR = (c2.t == "R" and c2.r == r)
					local testsNotR = (c2.t == "Not" and c2.a.t == "R" and c2.a.r == r)
					if (testsR or testsNotR) and not isRefLive(r, d.pc)
						and not liveInHas(Z, r) and not readsReg(d.e, r) then
						local t2, f2 = X.term.t, X.term.f
						local failIsTrueEdge = (t2 == Z)
						local failIsFalseEdge = (f2 == Z)
						if failIsTrueEdge ~= failIsFalseEdge then
							local enter = (side == 1) and tm.c or neg(tm.c)
							local keepWhenTruthy
							if testsR then keepWhenTruthy = failIsFalseEdge
							else keepWhenTruthy = failIsTrueEdge end
							local F
							if keepWhenTruthy then F = { t = "And", a = enter, b = d.e }
							else F = { t = "Or", a = neg(enter), b = d.e } end
							P.stmts[#P.stmts + 1] = { k = "def", dst = r, e = F, pc = d.pc, _rd = nil, _ef = nil, did = nil, dvar = nil }
							P.term = { k = "if", c = c2, t = t2, f = f2, pc = X.term.pc }
							P._clean = false
							X.dead = true
							rebuildEdges(cfg)
							return true
						end
					end
				end
			end
		end
	end
	return false
end

local function foldTables(cfg)
	local changed = false
	for _, b in ipairs(liveBlocks(cfg)) do
		local S = b.stmts
		local i = 1
		while i <= #S do
			local s = S[i]
			if s.k == "def" and s.e.t == "Table" and not isRefLive(s.dst, s.pc) then
				local r = s.dst
				local tbl = s.e
				local j = i + 1
				while j <= #S do
					local st = S[j]
					local absorbed = false
					if st.k == "set" and st.o.t == "R" and st.o.r == r and not readsReg(st.key, r) and not readsReg(st.v, r) then
						local key = st.key
						local filled = false
						if tbl.template and key.t == "K" and key.kind == "str" then
							for _, it in ipairs(tbl.items) do
								if it.pending and it.k.v == key.v then
									it.v = st.v; it.pending = false; filled = true
									break
								end
							end
						end
						if not filled then tbl.items[#tbl.items + 1] = { k = key, v = st.v } end
						absorbed = true
					elseif st.k == "setlist" and st.o.t == "R" and st.o.r == r then
						local clean = true
						for _, v in ipairs(st.vals) do if readsReg(v, r) then clean = false end end
						if clean then
							for _, v in ipairs(st.vals) do tbl.items[#tbl.items + 1] = { v = v } end
							absorbed = true
						end
					end
					if not absorbed then break end
					table_remove(S, j)
					b._clean = false
					changed = true
				end
				invalidate(s)
			end
			i = i + 1
		end
	end
	return changed
end

local finalizeTables
do
local function fixPendingTables(e)
	if e.t == "Table" then
		local items = e.items
		for i = 1, #items do
			local it = items[i]
			if it.pending then it.v = K_NIL(); it.pending = false end
		end
	end
	forEachChild(e, fixPendingTables)
end

function finalizeTables(cfg)
	local list = cfg.pendingTables
	if list then
		for ti = 1, #list do
			local items = list[ti].items
			for i = 1, #items do
				local it = items[i]
				if it.pending then it.v = K_NIL(); it.pending = false end
			end
		end
		return
	end
	local blocks = liveBlocks(cfg)
	for bi = 1, #blocks do
		local b = blocks[bi]
		local stmts = b.stmts
		for i = 1, #stmts do forEachStmtExpr(stmts[i], fixPendingTables) end
		forEachTermExpr(b.term, fixPendingTables)
	end
end
end

local simplifyCFG
do
local VERIFY_CLEAN = false
local VERIFY_SETTLED = false

function simplifyCFG(cfg)
	rebuildEdges(cfg)
	local iter = 0
	local liveStale = true
	while true do
		iter = iter + 1
		if iter > 200 then break end
		local changed = false
		if normalizeDegenerate(cfg) then changed = true; liveStale = true; rebuildEdges(cfg) end
		if normalizeBlocks(cfg) then changed = true; liveStale = true end
		if liveStale then
			computeLiveness(cfg)
			liveStale = false
		elseif VERIFY_SETTLED then
			local live0 = liveBlocks(cfg)
			local snap = {}
			for bi = 1, #live0 do
				local b = live0[bi]
				snap[bi] = { b.loArr, b.loOff, b.liArr, b.liOff, b.liW }
			end
			computeLiveness(cfg)
			for bi = 1, #live0 do
				local b, sp = live0[bi], snap[bi]
				local W = b.liW
				if sp[5] ~= W then error("simplifyCFG: live set width changed") end
				for w = 1, W do
					if sp[1][sp[2] + w] ~= b.loArr[b.loOff + w] or sp[3][sp[4] + w] ~= b.liArr[b.liOff + w] then
						error("simplifyCFG: skipped liveness recomputation would have changed block " .. tostring(b.id))
					end
				end
			end
		end
		local live = liveBlocks(cfg)
		for bi = 1, #live do
			local b = live[bi]
			if b._clean then
				if VERIFY_CLEAN and inlineBlock(b) then error("simplifyCFG: stale clean flag on block " .. tostring(b.id)) end
			else
				local ch, liveDirty, settled = inlineBlock(b)
				if ch then
					changed = true
					if liveDirty then liveStale = true end
					b._clean = settled
					if VERIFY_SETTLED and settled and inlineBlock(b) then
						error("simplifyCFG: block " .. tostring(b.id) .. " was not settled after an inline pass")
					end
				else
					b._clean = true
				end
			end
		end
		if foldTables(cfg) then changed = true; liveStale = true end
		if mergeBlocks(cfg) then changed = true; liveStale = true end
		if foldConditions(cfg) then changed = true; liveStale = true end
		if collapseDiamonds(cfg) then changed = true; liveStale = true end
		if not changed and foldValueTests(cfg) then changed = true; liveStale = true end
		if not changed then break end
	end
	finalizeTables(cfg)
end
end

function dbgExpr(e)
	local t = e.t
	if t == "R" then return (e.refcap and "&" or "") .. "R" .. e.r
	elseif t == "K" then
		if e.kind == "str" then return string_format("%q", e.v) end
		return tostring(e.v == nil and "nil" or e.v)
	elseif t == "G" then return "G:" .. tostring(e.name)
	elseif t == "U" then return "U" .. e.i
	elseif t == "Idx" then return dbgExpr(e.o) .. "[" .. dbgExpr(e.k) .. "]"
	elseif t == "Call" then
		local a = {}
		for i, x in ipairs(e.a) do a[i] = dbgExpr(x) end
		return dbgExpr(e.f) .. "(" .. table_concat(a, ", ") .. ")" .. (e.multi and "*" or "")
	elseif t == "MCall" then
		local a = {}
		for i, x in ipairs(e.a) do a[i] = dbgExpr(x) end
		return dbgExpr(e.o) .. ":" .. e.n .. "(" .. table_concat(a, ", ") .. ")"
	elseif t == "Bin" or t == "Cmp" then return "(" .. dbgExpr(e.a) .. " " .. e.op .. " " .. dbgExpr(e.b) .. ")"
	elseif t == "And" then return "(" .. dbgExpr(e.a) .. " and " .. dbgExpr(e.b) .. ")"
	elseif t == "Or" then return "(" .. dbgExpr(e.a) .. " or " .. dbgExpr(e.b) .. ")"
	elseif t == "Not" then return "not " .. dbgExpr(e.a)
	elseif t == "Neg" then return "-" .. dbgExpr(e.a)
	elseif t == "Len" then return "#" .. dbgExpr(e.a)
	elseif t == "Concat" then
		local a = {}
		for i, x in ipairs(e.l) do a[i] = dbgExpr(x) end
		return "concat(" .. table_concat(a, ", ") .. ")"
	elseif t == "Table" then
		local a = {}
		for _, it in ipairs(e.items) do a[#a + 1] = (it.k and ("[" .. dbgExpr(it.k) .. "]=") or "") .. (it.v and dbgExpr(it.v) or "?") end
		return "{" .. table_concat(a, ", ") .. "}"
	elseif t == "Closure" then return "closure<" .. tostring(e.proto and e.proto.Source) .. ">"
	elseif t == "Vararg" then return "..."
	elseif t == "IfElse" then return "(if " .. dbgExpr(e.c) .. " then " .. dbgExpr(e.a) .. " else " .. dbgExpr(e.b) .. ")"
	elseif t == "FNPrep" then return "FNPrep(base=" .. e.base .. ")"
	elseif t == "FNLoop" then return "FNLoop(base=" .. e.base .. ")"
	elseif t == "FGLoop" then return "FGLoop(base=" .. e.base .. ",nv=" .. e.nv .. ")"
	end
	return "?" .. tostring(t)
end

function dbgStmt(s)
	local k = s.k
	if k == "def" then return "R" .. s.dst .. " = " .. dbgExpr(s.e)
	elseif k == "mdef" then
		local d = {}
		for i, r in ipairs(s.dsts) do d[i] = "R" .. r end
		return table_concat(d, ",") .. " = " .. dbgExpr(s.e)
	elseif k == "ncdef" then return "R" .. s.fnReg .. ",R" .. s.selfReg .. " = namecall " .. dbgExpr(s.o) .. ":" .. tostring(s.name)
	elseif k == "call" then return "call " .. dbgExpr(s.e)
	elseif k == "set" then return dbgExpr(s.o) .. "[" .. dbgExpr(s.key) .. "] = " .. dbgExpr(s.v)
	elseif k == "massign" then
		local l, r = {}, {}
		for qi, st in ipairs(s.stores) do
			l[qi] = (st.k == "set") and (dbgExpr(st.o) .. "[" .. dbgExpr(st.key) .. "]") or (st.k == "setg" and ("G:" .. st.name) or ("U" .. st.i))
		end
		for qi, x in ipairs(s.vals) do r[qi] = dbgExpr(x) end
		return table_concat(l, ", ") .. " = " .. table_concat(r, ", ")
	elseif k == "setg" then return "G:" .. s.name .. " = " .. dbgExpr(s.v)
	elseif k == "setu" then return "U" .. s.i .. " = " .. dbgExpr(s.v)
	elseif k == "setlist" then
		local a = {}
		for i, x in ipairs(s.vals) do a[i] = dbgExpr(x) end
		return "setlist " .. dbgExpr(s.o) .. " @" .. tostring(s.start) .. " {" .. table_concat(a, ", ") .. "}"
	elseif k == "close" then return "closeupvals " .. s.a
	elseif k == "fgprep" then return "fgprep base=" .. s.base
	elseif k == "eval" then return "eval " .. dbgExpr(s.e)
	end
	return "?" .. tostring(k)
end

local function dumpCFG(cfg, title)
	local out = { "---- CFG " .. (title or "") }
	for _, b in ipairs(cfg.blocks) do
		if not b.dead then
			local p = {}
			for _, x in ipairs(b.preds or {}) do p[#p + 1] = x.id end
			out[#out + 1] = string_format("B%d  preds={%s}", b.id, table_concat(p, ","))
			for _, s in ipairs(b.stmts) do out[#out + 1] = "    " .. dbgStmt(s) end
			local t = b.term
			if t.k == "goto" then out[#out + 1] = "    goto B" .. t.to.id
			elseif t.k == "if" then out[#out + 1] = string_format("    if %s then B%d else B%d", dbgExpr(t.c), t.t.id, t.f.id)
			elseif t.k == "ret" then
				local a = {}
				for i, x in ipairs(t.vals) do a[i] = dbgExpr(x) end
				out[#out + 1] = "    return " .. table_concat(a, ", ")
			end
		end
	end
	return table_concat(out, "\n")
end
local function buildWebs(cfg, proto)
	local blocks = liveBlocks(cfg)
	local nparams = proto.NumParams or 0

	local defs = {}
	local uf = {}
	local function find(x)
		while uf[x] ~= x do
			uf[x] = uf[uf[x]]
			x = uf[x]
		end
		return x
	end
	local function union(a, b)
		a, b = find(a), find(b)
		if a ~= b then uf[b] = a end
	end
	local function newDef(reg, info)
		local id = #defs + 1
		info.id = id; info.reg = reg
		defs[id] = info
		uf[id] = id
		return id
	end

	local entryDef = {}
	local function getEntryDef(reg)
		local d = entryDef[reg]
		if not d then
			d = newDef(reg, { entry = true, param = (reg < nparams) })
			entryDef[reg] = d
		end
		return d
	end
	for r = 0, nparams - 1 do getEntryDef(r) end

	local exposedByReg = {}
	local lastDef = {}
	local refCaps = {}

	local function useNode(b, cur, node, where)
		if node.selfcap then return end
		local d = cur[node.r]
		if d then
			node.var = d
			if node.refcap then refCaps[#refCaps + 1] = { block = b, idx = where, reg = node.r, node = node } end
		else
			node.var = nil
			local l = exposedByReg[node.r]
			if not l then l = {}; exposedByReg[node.r] = l end
			local n = #l
			l[n + 1] = b; l[n + 2] = node
			if node.refcap then refCaps[#refCaps + 1] = { block = b, idx = where, reg = node.r, node = node } end
		end
	end
	local wB, wCur, wWhere
	local function walkExpr(e)
		if e.t == "R" then useNode(wB, wCur, e, wWhere) return end
		forEachChild(e, walkExpr)
	end

	for bIdx = 1, #blocks do
		local b = blocks[bIdx]
		local cur = {}
		for idx, s in ipairs(b.stmts) do
			if s.k == "def" and s.e.t == "Closure" then
				for _, c in ipairs(s.e.caps) do
					if c.node and c.node.r == s.dst then c.node.selfcap = true end
				end
			end
			wB, wCur, wWhere = b, cur, idx
			forEachStmtExpr(s, walkExpr)
			if s.k == "def" then
				local d = newDef(s.dst, { stmt = s, block = b, idx = idx, pc = s.pc, id = nil, reg = nil })
				s.did = d; cur[s.dst] = d
				if s.e.t == "Closure" then
					for _, c in ipairs(s.e.caps) do
						if c.node and c.node.selfcap then
							c.node.var = d
							if c.node.refcap then refCaps[#refCaps + 1] = { block = b, idx = idx, reg = c.node.r, node = c.node } end
						end
					end
				end
			elseif s.k == "mdef" then
				s.dids = {}
				for q, r in ipairs(s.dsts) do
					local d = newDef(r, { stmt = s, block = b, idx = idx, pc = s.pc, slot = q, id = nil, reg = nil })
					s.dids[q] = d; cur[r] = d
				end
			elseif s.k == "ncdef" then
				local d1 = newDef(s.fnReg, { stmt = s, block = b, idx = idx, pc = s.pc, slot = 1, id = nil, reg = nil })
				local d2 = newDef(s.selfReg, { stmt = s, block = b, idx = idx, pc = s.pc, slot = 2, id = nil, reg = nil })
				s.didF, s.didS = d1, d2
				cur[s.fnReg] = d1; cur[s.selfReg] = d2
			end
		end
		local t = b.term
		local where = #b.stmts + 1
		wB, wCur, wWhere = b, cur, where
		forEachTermExpr(t, walkExpr)
		if t.k == "if" and t.c.t == "FNLoop" then
			local node = { t = "R", r = t.c.base + 2 }
			t.c.idxNode = node
			useNode(b, cur, node, where)
		end
		if t.k == "if" then
			local c = t.c
			if c.t == "FNPrep" or c.t == "FNLoop" then
				local d = newDef(c.base + 2, { term = t, block = b, pc = t.pc, loopvar = true })
				c.did = d; cur[c.base + 2] = d
			elseif c.t == "FGLoop" then
				c.dids = {}
				for q = 1, c.nv do
					local d = newDef(c.base + 2 + q, { term = t, block = b, pc = t.pc, loopvar = true, slot = q })
					c.dids[q] = d; cur[c.base + 2 + q] = d
				end
			end
		end
		lastDef[bIdx] = cur
	end

	local regList = {}
	for r in pairs(exposedByReg) do regList[#regList + 1] = r end
	table_sort(regList)
	local nbl = #blocks
	for bi = 1, nbl do blocks[bi].webIdx = bi end
	local entryBlock = cfg.entry
	for _, r in ipairs(regList) do
		local ed = getEntryDef(r)
		local recs = exposedByReg[r]
		local ids, k = { ed }, 1
		for bi = 1, nbl do
			local ld = lastDef[bi][r]
			if ld then k = k + 1; ids[k] = ld end
		end
		if k == 1 then
			for ri = 2, #recs, 2 do recs[ri].var = ed end
		else
			table_sort(ids)
			local pos = {}
			for q = 1, k do pos[ids[q]] = q - 1 end
			local W = rshift(k - 1, 5) + 1
			local size = nbl * W
			local inn, defOut = table_create(size, 0), table_create(size, 0)
			local isDef = table_create(nbl, false)
			for bi = 1, nbl do
				local ld = lastDef[bi][r]
				if ld then
					isDef[bi] = true
					local pl = pos[ld]
					local w = (bi - 1) * W + rshift(pl, 5) + 1
					defOut[w] = lshift(1, band(pl, 31))
				end
			end
			do
				local pe = pos[ed]
				local w = (entryBlock.webIdx - 1) * W + rshift(pe, 5) + 1
				inn[w] = lshift(1, band(pe, 31))
			end
			local changed = true
			while changed do
				changed = false
				for bi = 1, nbl do
					local base = (bi - 1) * W
					local preds = blocks[bi].preds
					for q = 1, #preds do
						local pi = preds[q].webIdx
						if pi then
							local pbase = (pi - 1) * W
							local srcArr = isDef[pi] and defOut or inn
							for w = 1, W do
								local v = srcArr[pbase + w]
								if v ~= 0 then
									local cur = inn[base + w]
									local nv = bor(cur, v)
									if nv ~= cur then inn[base + w] = nv; changed = true end
								end
							end
						end
					end
				end
			end
			local firstOf = {}
			for ri = 1, #recs, 2 do
				local bi = recs[ri].webIdx
				local first = firstOf[bi]
				if first == nil then
					first = false
					local base = (bi - 1) * W
					for w = 1, W do
						local word = inn[base + w]
						local bitpos = 0
						while word ~= 0 do
							if band(word, 1) == 1 then
								local d = ids[(w - 1) * 32 + bitpos + 1]
								if first then union(first, d) else first = d end
							end
							word = rshift(word, 1)
							bitpos = bitpos + 1
						end
					end
					firstOf[bi] = first
				end
				recs[ri + 1].var = first or nil
			end
		end
	end

	local fullW, partW = {}, {}
	for _, cap in ipairs(refCaps) do
		local r = cap.reg
		local W = cap.node.var
		if W then
			local fw = fullW[r]
			if not fw then fw = {}; fullW[r] = fw end
			local pw = partW[r]
			if not pw then pw = {}; partW[r] = pw end
			local visited = {}
			local stopAt
			local function scanBlock(b, from)
				for idx = from, #b.stmts do
					local s = b.stmts[idx]
					if s.k == "close" and s.a <= r then stopAt = idx; return false end
					if s.k == "def" and s.dst == r then union(W, s.did)
					elseif s.k == "mdef" then
						for q, rr in ipairs(s.dsts) do if rr == r then union(W, s.dids[q]) end end
					elseif s.k == "ncdef" then
						if s.fnReg == r then union(W, s.didF) end
						if s.selfReg == r then union(W, s.didS) end
					end
				end
				local t = b.term
				if t.k == "if" then
					local c = t.c
					if (c.t == "FNPrep" or c.t == "FNLoop") and c.base + 2 == r then union(W, c.did) end
					if c.t == "FGLoop" then
						for q = 1, c.nv do if c.base + 2 + q == r then union(W, c.dids[q]) end end
					end
				end
				stopAt = math_huge
				return true
			end
			local stack = {}
			local cb, from = cap.block, cap.idx
			local prev = pw[cb]
			local covered = prev and from >= prev[1] and from <= prev[2] and find(prev[3]) == find(W)
			if not covered then
				if scanBlock(cb, from) then
					for _, s in ipairs(cb.succs) do
						if not visited[s] then visited[s] = true; stack[#stack + 1] = s end
					end
				end
				pw[cb] = { from, stopAt, W }
			end
			while #stack > 0 do
				local b = table_remove(stack)
				local fwv = fw[b]
				if not (fwv and find(fwv) == find(W)) then
					fw[b] = W
					if scanBlock(b, 1) then
						for _, s in ipairs(b.succs) do
							if not visited[s] then visited[s] = true; stack[#stack + 1] = s end
						end
					end
				end
			end
		end
	end

	local vars = {}
	local varList = {}
	local nVars = 0
	local function varOf(did)
		local root = find(did)
		local v = vars[root]
		if not v then
			nVars = nVars + 1
			v = { id = nVars, reg = defs[root].reg, nuse = 0, defList = {} }
			vars[root] = v
			varList[nVars] = v
		end
		return v
	end
	for id = 1, #defs do
		local d = defs[id]
		local root = find(id)
		local v = vars[root]
		if v then
			local dl = v.defList
			dl[#dl + 1] = d
		else
			nVars = nVars + 1
			v = { id = nVars, reg = defs[root].reg, nuse = 0, defList = { d } }
			vars[root] = v
			varList[nVars] = v
		end
		if d.param then v.isParam = true end
		if d.loopvar then v.isLoopVar = true end
		if d.entry and not d.param then v.entryUndef = true end
	end
	local function annotateExpr(e)
		if e.t == "R" then
			local d = e.var
			if d then
				local v = varOf(d)
				e.var = v
				v.nuse = v.nuse + 1
				if e.refcap then v.refCaptured = true end
				if e.noinline then v.captured = true end
			end
			return
		end
		forEachChild(e, annotateExpr)
	end
	for _, b in ipairs(blocks) do
		for _, s in ipairs(b.stmts) do
			forEachStmtExpr(s, annotateExpr)
			if s.k == "def" then s.dvar = varOf(s.did); s.dvar.defStmt = s.dvar.defStmt or s
			elseif s.k == "mdef" then
				s.dvars = {}
				for q = 1, #s.dsts do s.dvars[q] = varOf(s.dids[q]); s.dvars[q].defStmt = s end
			elseif s.k == "ncdef" then
				s.fvar = varOf(s.didF); s.svar = varOf(s.didS)
			end
		end
		local t = b.term
		forEachTermExpr(t, annotateExpr)
		if t.k == "if" then
			local c = t.c
			if c.t == "FNLoop" and c.idxNode then annotateExpr(c.idxNode) end
			if c.t == "FNPrep" or c.t == "FNLoop" then c.var = varOf(c.did)
			elseif c.t == "FGLoop" then
				c.vars = {}
				for q = 1, c.nv do c.vars[q] = varOf(c.dids[q]) end
			end
		end
	end
	local paramVars = {}
	for r = 0, nparams - 1 do paramVars[r + 1] = varOf(entryDef[r]) end

	return { vars = varList, paramVars = paramVars, find = find }
end
local function analyzeCFG(cfg)
	local entry = cfg.entry
	local post, visited = {}, {}
	do
		local stack = { { entry, 1 } }
		visited[entry] = true
		while #stack > 0 do
			local top = stack[#stack]
			local b, i = top[1], top[2]
			local ss = b.succs
			if i <= #ss then
				top[2] = i + 1
				local s = ss[i]
				if not visited[s] then
					visited[s] = true
					stack[#stack + 1] = { s, 1 }
				end
			else
				post[#post + 1] = b
				stack[#stack] = nil
			end
		end
	end
	local n = #post
	local rpoList = {}
	local rpo = {}
	for i = 1, n do
		rpoList[i] = post[n - i + 1]
		rpo[rpoList[i]] = i
	end
	local idom = { [entry] = entry }
	local function intersect(a, b)
		while a ~= b do
			while rpo[a] > rpo[b] do a = idom[a] end
			while rpo[b] > rpo[a] do b = idom[b] end
		end
		return a
	end
	local changed = true
	while changed do
		changed = false
		for i = 2, n do
			local b = rpoList[i]
			local new
			for _, p in ipairs(b.preds) do
				if idom[p] then
					if new then new = intersect(p, new) else new = p end
				end
			end
			if new and idom[b] ~= new then idom[b] = new; changed = true end
		end
	end
	local children = {}
	for _, b in ipairs(rpoList) do children[b] = {} end
	for i = 2, n do
		local b = rpoList[i]
		local p = idom[b]
		children[p][#children[p] + 1] = b
	end
	local tin, tout, clock = {}, {}, 0
	do
		local stack = { { entry, 1 } }
		clock = clock + 1; tin[entry] = clock
		while #stack > 0 do
			local top = stack[#stack]
			local b, i = top[1], top[2]
			local ch = children[b]
			if i <= #ch then
				top[2] = i + 1
				local c = ch[i]
				clock = clock + 1; tin[c] = clock
				stack[#stack + 1] = { c, 1 }
			else
				clock = clock + 1; tout[b] = clock
				stack[#stack] = nil
			end
		end
	end
	local function dominates(a, b) return tin[a] <= tin[b] and tout[b] <= tout[a] end

	local isBack = {}
	local isHeader = {}
	local latches = {}
	for _, b in ipairs(rpoList) do
		for _, s in ipairs(b.succs) do
			if dominates(s, b) then
				isBack[b] = isBack[b] or {}
				isBack[b][s] = true
				isHeader[s] = true
				latches[s] = latches[s] or {}
				latches[s][#latches[s] + 1] = b
			end
		end
	end
	local loopSet = {}
	for h, ls in pairs(latches) do
		local set = { [h] = true }
		local stack = {}
		for _, l in ipairs(ls) do
			if not set[l] then set[l] = true; stack[#stack + 1] = l end
		end
		while #stack > 0 do
			local b = table_remove(stack)
			for _, p in ipairs(b.preds) do
				if not set[p] and visited[p] then set[p] = true; stack[#stack + 1] = p end
			end
		end
		loopSet[h] = set
	end
	local function loopSize(h) local c = 0 for _ in pairs(loopSet[h]) do c = c + 1 end return c end

	local fwdIn = {}
	for _, b in ipairs(rpoList) do fwdIn[b] = 0 end
	for _, b in ipairs(rpoList) do
		for _, s in ipairs(b.succs) do
			if not (isBack[b] and isBack[b][s]) then fwdIn[s] = fwdIn[s] + 1 end
		end
	end

	local hoisted = {}
	local parent = {}
	for _, b in ipairs(rpoList) do if b ~= entry then parent[b] = idom[b] end end
	local headers = {}
	for h in pairs(loopSet) do headers[#headers + 1] = h end
	table_sort(headers, function(a, b)
		local sa, sb = loopSize(a), loopSize(b)
		if sa ~= sb then return sa < sb end
		return rpo[a] < rpo[b]
	end)
	for _, h in ipairs(headers) do
		local L = loopSet[h]
		for _, b in ipairs(rpoList) do
			if b ~= entry and not L[b] and parent[b] and L[parent[b]] and dominates(h, b) then
				parent[b] = h
				hoisted[b] = true
			end
		end
	end
	local kids = {}
	for _, b in ipairs(rpoList) do kids[b] = {} end
	for _, b in ipairs(rpoList) do
		if b ~= entry then
			local p = parent[b]
			kids[p][#kids[p] + 1] = b
		end
	end
	for _, b in ipairs(rpoList) do
		table_sort(kids[b], function(a, c) return rpo[a] < rpo[c] end)
	end

	return {
		rpo = rpo, rpoList = rpoList, idom = idom, kids = kids, parent = parent,
		isBack = isBack, isHeader = isHeader, loopSet = loopSet, fwdIn = fwdIn,
		hoisted = hoisted, dominates = dominates,
	}
end

local function buildTree(cfg, info)
	local labelN = 0
	local function newLabel() labelN = labelN + 1; return labelN end
	local blockLabel = {}
	local loopLabel = {}
	local emitted = {}
	local doTree, nodeWithin, doBranch

	local function isMerge(y)
		return info.fwdIn[y] >= 2 or info.hoisted[y] == true
	end

	local function mergeKids(x, outside)
		local out = {}
		local L = info.isHeader[x] and info.loopSet[x] or nil
		for _, y in ipairs(info.kids[x]) do
			if isMerge(y) then
				local inLoop = L and L[y] or false
				if (outside and L and not inLoop) or (not outside and (not L or inLoop)) then
					out[#out + 1] = y
				end
			end
		end
		table_sort(out, function(a, b) return info.rpo[a] > info.rpo[b] end)
		return out
	end

	local function stmtNodes(b)
		local out = {}
		for _, s in ipairs(b.stmts) do out[#out + 1] = { n = "Stmt", s = s } end
		return out
	end

	function doBranch(src, tgt)
		if info.isBack[src] and info.isBack[src][tgt] then
			return { { n = "Br", label = loopLabel[tgt], kind = "cont" } }
		end
		if blockLabel[tgt] then
			return { { n = "Br", label = blockLabel[tgt], kind = "exit" } }
		end
		if isMerge(tgt) then
			error("structuring: branch to merge node without enclosing block (irreducible control flow?)")
		end
		return doTree(tgt)
	end

	function nodeWithin(x, ys, idx)
		if idx > #ys then
			if emitted[x] then error("structuring: block emitted twice") end
			emitted[x] = true
			local seq = stmtNodes(x)
			local t = x.term
			if t.k == "goto" then
				local br = doBranch(x, t.to)
				for _, nd in ipairs(br) do seq[#seq + 1] = nd end
			elseif t.k == "if" then
				seq[#seq + 1] = { n = "If", c = t.c, a = doBranch(x, t.t), b = doBranch(x, t.f), term = t, blk = x }
			elseif t.k == "ret" then
				seq[#seq + 1] = { n = "Ret", vals = t.vals }
			end
			return seq
		end
		local y = ys[idx]
		local lab = newLabel()
		blockLabel[y] = lab
		local inner = nodeWithin(x, ys, idx + 1)
		blockLabel[y] = nil
		local out = { { n = "Block", label = lab, body = inner } }
		local after = doTree(y)
		for _, nd in ipairs(after) do out[#out + 1] = nd end
		return out
	end

	function doTree(x)
		if info.isHeader[x] then
			local outs = mergeKids(x, true)
			local ins = mergeKids(x, false)
			local function wrap(i, innerLabel)
				if i > #outs then
					local lab = newLabel()
					loopLabel[x] = lab
					local body = nodeWithin(x, ins, 1)
					loopLabel[x] = nil
					return { { n = "Loop", label = lab, body = body, header = x, exitLabel = innerLabel } }
				end
				local y = outs[i]
				local lab = newLabel()
				blockLabel[y] = lab
				local inner = wrap(i + 1, lab)
				blockLabel[y] = nil
				local out = { { n = "Block", label = lab, body = inner, exitOf = true } }
				local after = doTree(y)
				for _, nd in ipairs(after) do out[#out + 1] = nd end
				return out
			end
			return wrap(1, nil)
		end
		return nodeWithin(x, mergeKids(x, false), 1)
	end

	local tree = doTree(cfg.entry)
	return tree
end
local LOOPKINDS = { While = true, Repeat = true, LoopT = true, ForN = true, ForG = true }

local function isLoopish(n) return LOOPKINDS[n] or n == "DoBlock" end

local function brTo(seq, label)
	return #seq == 1 and seq[1].n == "Br" and seq[1].label == label
end

local function isExitNode(nd)
	local n = nd.n
	return n == "Br" or n == "Ret" or n == "Break" or n == "Continue"
end

local function seqExits(seq)
	local last = seq[#seq]
	if not last then return false end
	if isExitNode(last) then return true end
	if last.n == "If" then return seqExits(last.a) and #last.b > 0 and seqExits(last.b) end
	return false
end

local childSeqs
do
local NO_SEQS = {}
function childSeqs(nd)
	local n = nd.n
	if n == "If" then return { nd.a, nd.b }
	elseif n == "Block" or n == "Loop" or n == "DoBlock" or LOOPKINDS[n] then return { nd.body } end
	return NO_SEQS
end
end

local function countBr(seq, label)
	local c = 0
	for i = 1, #seq do
		local nd = seq[i]
		local n = nd.n
		if n == "Br" then
			if nd.label == label then c = c + 1 end
		elseif n == "If" then
			local a = nd.a
			if a then
				c = c + countBr(a, label)
				local b = nd.b
				if b then c = c + countBr(b, label) end
			end
		elseif n == "Block" or n == "Loop" or n == "DoBlock" or LOOPKINDS[n] then
			c = c + countBr(nd.body, label)
		end
	end
	return c
end

local function treeSize(seq)
	local c = 0
	for i = 1, #seq do
		local nd = seq[i]
		local n = nd.n
		c = c + 1
		if n == "If" then
			local a = nd.a
			if a then
				c = c + treeSize(a)
				local b = nd.b
				if b then c = c + treeSize(b) end
			end
		elseif n == "Block" or n == "Loop" or n == "DoBlock" or LOOPKINDS[n] then
			c = c + treeSize(nd.body)
		end
	end
	return c
end

local function stripTail(seq, label)
	local n = #seq
	if n == 0 then return seq end
	local last = seq[n]
	if (label ~= nil and last.n == "Br" and last.label == label) or (label == nil and last.n == "Continue") then
		seq[n] = nil
		return stripTail(seq, label)
	elseif last.n == "If" then
		last.a = stripTail(last.a, label)
		last.b = stripTail(last.b, label)
	elseif last.n == "Block" or last.n == "DoBlock" then
		last.body = stripTail(last.body, label)
	end
	return seq
end

local function buildForGExplist(ops, out)
	local explist = {}
	local p = 1
	while p <= 3 do
		local op = ops[p]
		local m = (op.t == "R" and op.var and op.var.defStmt and op.var.defStmt.k == "mdef") and op.var.defStmt or nil
		if m and m.dvars[1] == op.var and (p + #m.dvars - 1 == 3) then
			local okk = true
			for q = 1, #m.dvars do
				local o = ops[p + q - 1]
				if not (o.t == "R" and o.var == m.dvars[q]) then okk = false end
			end
			local found
			if okk then
				for idx = #out, 1, -1 do
					if out[idx].n == "Stmt" and out[idx].s == m then found = idx break end
				end
			end
			if found then
				table_remove(out, found)
				m.e.multi = true
				explist[#explist + 1] = m.e
				return explist
			end
		end
		explist[#explist + 1] = op
		p = p + 1
	end
	while #explist > 1 and explist[#explist].t == "K" and explist[#explist].kind == "nil" do
		explist[#explist] = nil
	end
	return explist
end

local function tailMarkerIf(seq)
	local last = seq[#seq]
	if not last or last.n ~= "If" then return false end
	if isMarker(last.c) then return last.c.t == "FNLoop" or last.c.t == "FGLoop" end
	if #last.b > 0 and #last.a > 0 then
		return tailMarkerIf(last.a) or tailMarkerIf(last.b)
	end
	return false
end

local function flattenTailGuards(seq)
	while true do
		local last = seq[#seq]
		if not (last and last.n == "If" and #last.b > 0 and #last.a > 0) or isMarker(last.c) then return seq end
		local aExits, bExits = seqExits(last.a), seqExits(last.b)
		local hoistA
		if aExits and bExits then
			hoistA = tailMarkerIf(last.a)
		elseif aExits then hoistA = false
		elseif bExits then hoistA = true
		else return seq end
		if hoistA then
			local rest = last.a
			last.a = last.b; last.b = {}
			last.c = neg(last.c)
			for _, r in ipairs(rest) do seq[#seq + 1] = r end
		else
			local rest = last.b
			last.b = {}
			for _, r in ipairs(rest) do seq[#seq + 1] = r end
		end
	end
end

local function containsLoop(seq)
	for _, nd in ipairs(seq) do
		if nd.n == "Loop" then return true end
		for _, cs in ipairs(childSeqs(nd)) do if containsLoop(cs) then return true end end
	end
	return false
end

local recognizeSeq

local function findFirstLoop(seq)
	local first = seq[1]
	if not first then return nil end
	if first.n == "Loop" then return seq, 1 end
	if first.n == "Block" then return findFirstLoop(first.body) end
	return nil
end

local function convertLoop(L)
	local body = L.body
	local nb = #body
	local last = body[nb]
	if last and last.n == "If" then
		local c = last.c
		if c.t == "FNLoop" or c.t == "FGLoop" then return nil end
		local function isExitArm(arm)
			return #arm == 1 and arm[1].n == "Br" and not (arm[1].kind == "cont" and arm[1].label == L.label)
		end
		if nb == 1 then
			if isExitArm(last.b) then
				local x = last.b[1]
				return { { n = "While", c = c, body = last.a, label = L.label, exitLabel = x.label, exitKind = x.kind }, { n = "Br", label = x.label, kind = x.kind } }
			elseif isExitArm(last.a) then
				local x = last.a[1]
				return { { n = "While", c = neg(c), body = last.b, label = L.label, exitLabel = x.label, exitKind = x.kind }, { n = "Br", label = x.label, kind = x.kind } }
			end
		end
		if nb >= 2 then
			local a, b = last.a, last.b
			if #a == 1 and #b == 1 and a[1].n == "Br" and b[1].n == "Br" then
				if b[1].kind == "cont" and b[1].label == L.label and not (a[1].kind == "cont" and a[1].label == L.label) then
					body[nb] = nil
					return { { n = "Repeat", c = c, body = body, label = L.label, exitLabel = a[1].label, exitKind = a[1].kind }, { n = "Br", label = a[1].label, kind = a[1].kind } }
				elseif a[1].kind == "cont" and a[1].label == L.label and not (b[1].kind == "cont" and b[1].label == L.label) then
					body[nb] = nil
					return { { n = "Repeat", c = neg(c), body = body, label = L.label, exitLabel = b[1].label, exitKind = b[1].kind }, { n = "Br", label = b[1].label, kind = b[1].kind } }
				end
			end
		end
	end
	return { { n = "LoopT", body = body, label = L.label, exitLabel = L.exitLabel, exitKind = "exit" } }
end

function recognizeSeq(seq)
	local out = {}
	for i = 1, #seq do
		local nd = seq[i]
		local n = nd.n
		if n == "If" then
			nd.a = recognizeSeq(nd.a)
			nd.b = recognizeSeq(nd.b)
			if nd.c.t == "FNPrep" then
				local a, b = nd.a, nd.b
				local done = false
				if #b == 1 and b[1].n == "Br" then
					local E, EK = b[1].label, b[1].kind
					local cont, idx = findFirstLoop(a)
					if cont then
						local L = cont[idx]
						local lb = flattenTailGuards(L.body)
						L.body = lb
						local lastN = lb[#lb]
						if lastN and lastN.n == "If" and lastN.c.t == "FNLoop" and brTo(lastN.a, L.label)
							and #lastN.b == 1 and lastN.b[1].n == "Br" and lastN.b[1].label == E and lastN.b[1].kind == EK then
							lb[#lb] = nil
							cont[idx] = { n = "ForN", prep = nd.c, body = lb, label = L.label, exitLabel = E, exitKind = EK }
							table_insert(cont, idx + 1, { n = "Br", label = E, kind = EK })
							for _, x in ipairs(a) do out[#out + 1] = x end
							done = true
						end
					end
					if not done then
						if not containsLoop(a) then
							out[#out + 1] = { n = "ForN", prep = nd.c, body = a, label = -1, exitLabel = E, exitKind = EK }
							out[#out + 1] = { n = "Br", label = E, kind = EK }
							done = true
						end
					end
				end
				if not done and not containsLoop(a) then
					out[#out + 1] = { n = "ForN", prep = nd.c, body = a, label = -1 }
					for _, x in ipairs(b) do out[#out + 1] = x end
					done = true
				end
				if not done then out[#out + 1] = { n = "Unsup", text = "unrecognised numeric for-loop shape" } end
			elseif nd.c.t == "FGLoop" and out[#out] and out[#out].n == "Stmt" and out[#out].s.k == "fgprep" and not containsLoop(nd.a) then
				local prev = out[#out]
				out[#out] = nil
				local explist = buildForGExplist(prev.s.ops, out)
				out[#out + 1] = { n = "ForG", c = nd.c, explist = explist, body = nd.a, label = -1 }
				for _, x in ipairs(nd.b) do out[#out + 1] = x end
			else
				out[#out + 1] = nd
			end
		elseif n == "Block" then
			nd.body = recognizeSeq(nd.body)
			local prev = out[#out]
			if prev and prev.n == "Stmt" and prev.s.k == "fgprep" then
				local cont, idx = findFirstLoop({ nd })
				if cont then
					local L = cont[idx]
					if #L.body == 1 and L.body[1].n == "If" and L.body[1].c.t == "FGLoop" then
						local ifn = L.body[1]
						if #ifn.b == 1 and ifn.b[1].n == "Br" then
							local E, EK = ifn.b[1].label, ifn.b[1].kind
							out[#out] = nil
							local explist = buildForGExplist(prev.s.ops, out)
							cont[idx] = { n = "ForG", c = ifn.c, explist = explist, body = ifn.a, label = L.label, exitLabel = E, exitKind = EK }
							table_insert(cont, idx + 1, { n = "Br", label = E, kind = EK })
						end
					end
				end
			end
			out[#out + 1] = nd
		elseif n == "Loop" then
			nd.body = recognizeSeq(nd.body)
			if tailMarkerIf(nd.body) then nd.body = flattenTailGuards(nd.body) end
			local prev = out[#out]
			local ifn = (#nd.body == 1 and nd.body[1].n == "If" and nd.body[1].c.t == "FGLoop") and nd.body[1] or nil
			if prev and prev.n == "Stmt" and prev.s.k == "fgprep" and ifn and #ifn.b == 1 and ifn.b[1].n == "Br" then
				local E, EK = ifn.b[1].label, ifn.b[1].kind
				out[#out] = nil
				local explist = buildForGExplist(prev.s.ops, out)
				out[#out + 1] = { n = "ForG", c = ifn.c, explist = explist, body = ifn.a, label = nd.label, exitLabel = E, exitKind = EK }
				out[#out + 1] = { n = "Br", label = E, kind = EK }
			else
				local rep = convertLoop(nd)
				if rep then
					for _, x in ipairs(rep) do out[#out + 1] = x end
				else
					out[#out + 1] = nd
				end
			end
		else
			out[#out + 1] = nd
		end
	end
	return out
end

local function finalizeLoops(seq)
	for i = 1, #seq do
		local nd = seq[i]
		if nd.n == "If" and isMarker(nd.c) then
			seq[i] = { n = "Unsup", text = "unrecognised loop shape" }
			nd = seq[i]
		end
		if nd.n == "Loop" then
			seq[i] = { n = "LoopT", body = nd.body, label = nd.label, exitLabel = nd.exitLabel }
			nd = seq[i]
		end
		for _, cs in ipairs(childSeqs(nd)) do finalizeLoops(cs) end
	end
end

local function lowerBr(seq, ctx)
	for i = 1, #seq do
		local nd = seq[i]
		local n = nd.n
		if n == "Br" then
			if ctx then
				if nd.kind == "cont" and nd.label == ctx.label then
					seq[i] = { n = "Continue" }
				elseif nd.kind == (ctx.exitKind or "exit") and nd.label == ctx.exitLabel then
					seq[i] = { n = "Break" }
				end
			end
		elseif LOOPKINDS[n] then
			lowerBr(nd.body, { label = nd.label, exitLabel = nd.exitLabel, exitKind = nd.exitKind })
		elseif n == "DoBlock" then
			lowerBr(nd.body, nil)
		else
			for _, cs in ipairs(childSeqs(nd)) do lowerBr(cs, ctx) end
		end
	end
end

local function replaceBrWithContinue(seq, label)
	local ok = true
	for i = 1, #seq do
		local nd = seq[i]
		if nd.n == "Br" and nd.label == label then
			seq[i] = { n = "Continue" }
		elseif isLoopish(nd.n) then
			if countBr(nd.body, label) > 0 then ok = false end
		else
			for _, cs in ipairs(childSeqs(nd)) do
				if not replaceBrWithContinue(cs, label) then ok = false end
			end
		end
	end
	return ok
end

local function lastIsBr(seq, label)
	local l = seq[#seq]
	return l ~= nil and l.n == "Br" and l.label == label
end

local normalize
function normalize(seq)
	local out, o = nil, 0
	for idx = 1, #seq do
		local nd = seq[idx]
		local n = nd.n
		if n == "If" then
			nd.a = normalize(nd.a)
			nd.b = normalize(nd.b)
			if #nd.a == 0 and #nd.b > 0 then
				nd.c = neg(nd.c); nd.a, nd.b = nd.b, nd.a
			end
			if #nd.a == 0 and #nd.b == 0 then
				local rd, wr = exprEffect(nd.c)
				if not isMarker(nd.c) and (rd or wr) then
					local ns
					if nd.c.t == "Call" or nd.c.t == "MCall" then ns = { n = "Stmt", s = { k = "call", e = nd.c } }
					else ns = { n = "Stmt", s = { k = "eval", e = nd.c } } end
					if out then o = o + 1; out[o] = ns elseif seq[o + 1] == ns then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = ns end
				end
			elseif #nd.b > 0 and seqExits(nd.a) and not seqExits(nd.b) then
				local rest = nd.b
				nd.b = {}
				if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
				for q = 1, #rest do
					local r = rest[q]
					if out then o = o + 1; out[o] = r elseif seq[o + 1] == r then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = r end
				end
			elseif #nd.b > 0 and seqExits(nd.b) and not seqExits(nd.a) then
				local rest = nd.a
				nd.a = nd.b; nd.b = {}
				nd.c = neg(nd.c)
				if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
				for q = 1, #rest do
					local r = rest[q]
					if out then o = o + 1; out[o] = r elseif seq[o + 1] == r then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = r end
				end
			else
				if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
			end
		elseif n == "Block" then
			nd.body = normalize(nd.body)
			local L = nd.label
			local body = nd.body
			local k = 1
			while k < #body do
				local x = body[k]
				if x.n == "If" and #x.b == 0 and lastIsBr(x.a, L) then
					local rest = {}
					for q = k + 1, #body do rest[#rest + 1] = body[q]; body[q] = nil end
					x.b = normalize(rest)
					x.a = stripTail(x.a, L)
					break
				end
				k = k + 1
			end
			nd.body = stripTail(nd.body, L)
			if countBr(nd.body, L) == 0 then
				local nb = nd.body
				for q = 1, #nb do
					local r = nb[q]
					if out then o = o + 1; out[o] = r elseif seq[o + 1] == r then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = r end
				end
			else
				if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
			end
		elseif n == "DoBlock" and (function()
				local function hasBreak(s)
					for _, x in ipairs(s) do
						if x.n == "Break" then return true end
						if not isLoopish(x.n) then
							for _, cs in ipairs(childSeqs(x)) do if hasBreak(cs) then return true end end
						end
					end
					return false
				end
				nd.body = normalize(nd.body)
				return not hasBreak(nd.body)
			end)() then
			local nb = nd.body
			for q = 1, #nb do
				local r = nb[q]
				if out then o = o + 1; out[o] = r elseif seq[o + 1] == r then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = r end
			end
		elseif LOOPKINDS[n] or n == "DoBlock" then
			nd.body = normalize(nd.body)
			if LOOPKINDS[n] then
				nd.body = stripTail(nd.body, nd.label)
				nd.body = stripTail(nd.body, nil)
				local last = nd.body[#nd.body]
				if last and last.n == "Block" then
					local B = last
					if countBr(B.body, B.label) > 0 then
						local clone = B.body
						if replaceBrWithContinue(clone, B.label) then
							nd.body[#nd.body] = nil
							for _, r in ipairs(clone) do nd.body[#nd.body + 1] = r end
						end
					end
				end
			end
			if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
		else
			if out then o = o + 1; out[o] = nd elseif seq[o + 1] == nd then o = o + 1 else out = table.move(seq, 1, o, 1, {}); o = o + 1; out[o] = nd end
		end
		local lastNd
		if out then lastNd = out[o] else lastNd = seq[o] end
		if lastNd and isExitNode(lastNd) then break end
	end
	if out then return out end
	if o == #seq then return seq end
	return table.move(seq, 1, o, 1, {})
end

local function normalizeFix(t)
	local prev = -1
	for _ = 1, 50 do
		t = normalize(t)
		local sz = treeSize(t)
		if sz == prev then break end
		prev = sz
	end
	return t
end

local function copyTree(seq)
	local out = {}
	for i, nd in ipairs(seq) do
		local c = {}
		for k, v in pairs(nd) do c[k] = v end
		if nd.n == "If" then c.a = copyTree(nd.a); c.b = copyTree(nd.b)
		elseif nd.body then c.body = copyTree(nd.body) end
		out[i] = c
	end
	return out
end

local function hasAnyBr(seq)
	for _, nd in ipairs(seq) do
		if nd.n == "Br" then return true end
		for _, cs in ipairs(childSeqs(nd)) do if hasAnyBr(cs) then return true end end
	end
	return false
end

local function inlineTails(seq, cont)
	local i = 1
	while i <= #seq do
		local nd = seq[i]
		local nn = nd.n
		if nn == "If" or nn == "Block" or nn == "DoBlock" or nn == "Loop" or LOOPKINDS[nn] then
		local after = {}
		local exits = false
		for j = i + 1, #seq do
			after[#after + 1] = seq[j]
			if isExitNode(seq[j]) then exits = true break end
		end
		local fullTail = after
		if not exits and cont then
			fullTail = {}
			for _, x in ipairs(after) do fullTail[#fullTail + 1] = x end
			for _, x in ipairs(cont) do fullTail[#fullTail + 1] = x end
		elseif not exits then
			fullTail = nil
		end
		if nd.n == "Block" and fullTail and #fullTail > 0 then
			local nbr = countBr(nd.body, nd.label)
			local lastT = fullTail[#fullTail]
			local simple = true
			for q = 1, #fullTail - 1 do if fullTail[q].n ~= "Stmt" then simple = false end end
			if nbr > 0 and nbr <= 8 and simple and (lastT.n == "Ret" or lastT.n == "Br") and #fullTail <= 6 then
				local function sub(s)
					local k = 1
					while k <= #s do
						local x = s[k]
						if x.n == "Br" and x.label == nd.label then
							table_remove(s, k)
							local cp = copyTree(fullTail)
							for q = #cp, 1, -1 do table_insert(s, k, cp[q]) end
							k = k + #cp
						else
							for _, cs in ipairs(childSeqs(x)) do sub(cs) end
							k = k + 1
						end
					end
				end
				sub(nd.body)
			end
		end
		if LOOPKINDS[nd.n] or nd.n == "Loop" then
			inlineTails(nd.body, nil)
		else
			for _, cs in ipairs(childSeqs(nd)) do inlineTails(cs, fullTail) end
		end
		end
		i = i + 1
	end
end

local function newFlagVar()
	return { id = -1, reg = -1, nuse = 2, isFlag = true, defList = {} }
end
local function flagAssign(F, code)
	return { n = "Stmt", s = { k = "def", dst = -1, e = Knum(code), dvar = F, synthetic = true } }
end
local function flagIs(F, code)
	return { t = "Cmp", op = "==", a = { t = "R", r = -1, var = F }, b = Knum(code) }
end

local function lowerBlockLeftover(nd)
	local L = nd.label
	local usesCross, outerJumps = false, false
	local function scan(s, depth)
		for _, x in ipairs(s) do
			if x.n == "Br" and x.label == L then
				if depth > 0 then usesCross = true end
			elseif x.n == "Break" or x.n == "Continue" then
				if depth == 0 then outerJumps = true end
			elseif isLoopish(x.n) then scan(x.body, depth + 1)
			else for _, cs in ipairs(childSeqs(x)) do scan(cs, depth) end end
		end
	end
	scan(nd.body, 0)
	local F = (usesCross or outerJumps) and newFlagVar() or nil
	local function rewrite(s, depth)
		local k = 1
		while k <= #s do
			local x = s[k]
			if x.n == "Br" and x.label == L then
				if depth == 0 then
					s[k] = { n = "Break" }
				else
					s[k] = { n = "Break" }
					table_insert(s, k, flagAssign(F, 1))
					k = k + 1
				end
			elseif (x.n == "Break" or x.n == "Continue") and depth == 0 and outerJumps then
				s[k] = { n = "Break" }
				table_insert(s, k, flagAssign(F, x.n == "Break" and 2 or 3))
				k = k + 1
			elseif isLoopish(x.n) then
				local crossed = countBr(x.body, L) > 0
				rewrite(x.body, depth + 1)
				if crossed then
					table_insert(s, k + 1, { n = "If", c = flagIs(F, 1), a = { { n = "Break" } }, b = {} })
					k = k + 1
				end
			else
				for _, cs in ipairs(childSeqs(x)) do rewrite(cs, depth) end
			end
			k = k + 1
		end
	end
	rewrite(nd.body, 0)
	local out = {}
	if F then out[#out + 1] = flagAssign(F, 0) end
	out[#out + 1] = { n = "DoBlock", body = nd.body, label = L }
	if F and outerJumps then
		out[#out + 1] = { n = "If", c = flagIs(F, 2), a = { { n = "Break" } }, b = {} }
		out[#out + 1] = { n = "If", c = flagIs(F, 3), a = { { n = "Continue" } }, b = {} }
	end
	return out
end

local function lowerLoopContinues(seq)
	for i = 1, #seq do
		local nd = seq[i]
		for _, cs in ipairs(childSeqs(nd)) do lowerLoopContinues(cs) end
		if LOOPKINDS[nd.n] and nd.label ~= nil and nd.label >= 0 then
			local L = nd.label
			local function countCross(s, depth)
				local c = 0
				for _, x in ipairs(s) do
					if x.n == "Br" and x.kind == "cont" and x.label == L and depth > 0 then c = c + 1
					elseif isLoopish(x.n) then c = c + countCross(x.body, depth + 1)
					else for _, cs in ipairs(childSeqs(x)) do c = c + countCross(cs, depth) end end
				end
				return c
			end
			if countCross(nd.body, 0) > 0 then
				local F = newFlagVar()
				local function rewrite(s, depth)
					local k = 1
					while k <= #s do
						local x = s[k]
						if x.n == "Br" and x.kind == "cont" and x.label == L and depth > 0 then
							s[k] = { n = "Break" }
							table_insert(s, k, flagAssign(F, 1))
							k = k + 1
						elseif isLoopish(x.n) then
							local crossed = countCross(x.body, 0) > 0
							rewrite(x.body, depth + 1)
							if crossed then
								table_insert(s, k + 1, { n = "If", c = flagIs(F, 1), a = { { n = (depth == 0) and "Continue" or "Break" } }, b = {} })
								k = k + 1
							end
						else
							for _, cs in ipairs(childSeqs(x)) do rewrite(cs, depth) end
						end
						k = k + 1
					end
				end
				rewrite(nd.body, 0)
				table_insert(nd.body, 1, flagAssign(F, 0))
			end
		end
	end
end

local function lowerLeftovers(seq)
	local out = {}
	for i = 1, #seq do
		local nd = seq[i]
		for _, cs in ipairs(childSeqs(nd)) do
			local lowered = lowerLeftovers(cs)
			for q = #cs, 1, -1 do cs[q] = nil end
			for q = 1, #lowered do cs[q] = lowered[q] end
		end
		if nd.n == "Block" then
			for _, x in ipairs(lowerBlockLeftover(nd)) do out[#out + 1] = x end
		else
			out[#out + 1] = nd
		end
	end
	return out
end

local function dumpTree(seq, ind)
	ind = ind or ""
	local out = {}
	for _, nd in ipairs(seq) do
		local n = nd.n
		if n == "Stmt" then out[#out + 1] = ind .. "Stmt " .. dbgStmt(nd.s)
		elseif n == "If" then
			out[#out + 1] = ind .. "If " .. dbgExpr(nd.c)
			out[#out + 1] = ind .. " then:"
			out[#out + 1] = dumpTree(nd.a, ind .. "    ")
			if #nd.b > 0 then
				out[#out + 1] = ind .. " else:"
				out[#out + 1] = dumpTree(nd.b, ind .. "    ")
			end
		elseif n == "Br" then out[#out + 1] = ind .. "Br(" .. tostring(nd.label) .. "," .. tostring(nd.kind) .. ")"
		elseif n == "Ret" then out[#out + 1] = ind .. "Ret"
		elseif n == "Break" or n == "Continue" then out[#out + 1] = ind .. n
		else
			out[#out + 1] = ind .. n .. " label=" .. tostring(nd.label) .. " exit=" .. tostring(nd.exitLabel)
			if nd.body then out[#out + 1] = dumpTree(nd.body, ind .. "    ") end
		end
	end
	return table_concat(out, "\n")
end

local function lowerTree(tree)
	local t = recognizeSeq(tree)
	finalizeLoops(t)
	lowerBr(t, nil)
	t = normalizeFix(t)
	if CUR.debugLower then print("-- after first normalize"); print(CUR.debugLower(t)) end
	inlineTails(t, {})
	lowerBr(t, nil)
	t = normalizeFix(t)
	if CUR.debugLower then print("-- after inlineTails"); print(CUR.debugLower(t)) end
	lowerLoopContinues(t)
	t = lowerLeftovers(t)
	t = normalizeFix(t)
	return t
end
local PREC = {
	["or"] = 1, ["and"] = 2, cmp = 3, concat = 4, add = 5, mul = 6, unary = 7, pow = 8, atom = 10,
}
local BINPREC = { ["+"] = 5, ["-"] = 5, ["*"] = 6, ["/"] = 6, ["//"] = 6, ["%"] = 6, ["^"] = 8 }

local IND = "    "

local debugLocalsByProto = setmetatable({}, { __mode = "k" })
local function debugNameFor(proto, reg, pc)
local raw = proto.RawProto
local L = raw and raw.Locals
	if not L or not pc then return nil end
local byReg = debugLocalsByProto[raw]
if not byReg then
byReg = {}
for order, l in ipairs(L) do
local list = byReg[l.Register]
if not list then list = {}; byReg[l.Register] = list end
list[#list + 1] = { localInfo = l, order = order }
end
for _, list in pairs(byReg) do
table_sort(list, function(a, b)
if a.localInfo.StartPC ~= b.localInfo.StartPC then
return a.localInfo.StartPC < b.localInfo.StartPC
		end
return a.order < b.order
end)
	end
debugLocalsByProto[raw] = byReg
end
local list = byReg[reg]
if not list then return nil end
for i = #list, 1, -1 do
local l = list[i].localInfo
if l.StartPC <= pc and pc <= l.EndPC then return l.Name end
end
return nil
end

local function stringConstantValue(x)
if x and x.t == "K" and x.kind == "str" then return x.v end
return nil
end

local capAbbrevCache = {}
local function capAbbrev(name)
local cached = capAbbrevCache[name]
if cached ~= nil then return cached or nil end
local out = {}
for i = 1, #name do
local ch = string_sub(name, i, i)
if ch >= "A" and ch <= "Z" then out[#out + 1] = ch end
end
local abbrev = #out > 0 and table_concat(out) or false
capAbbrevCache[name] = abbrev
return abbrev or nil
end

local CTOR_RESULT_NAME = {
Vector2 = "vect2",
Vector3int16 = "vect3i16",
Vector2int16 = "vect2i16",
CFrame = "cf",
UDim = "udim",
UDim2 = "udim2",
Rect = "rect",
NumberRange = "numrange",
NumberSequence = "numseq",
NumberSequenceKeypoint = "numseqkp",
ColorSequence = "colorseq",
ColorSequenceKeypoint = "colorseqkp",
Color3 = "color3",
PhysicalProperties = "physprops",
Faces = "faces",
Axes = "axes",
}

local function inferredNameFor(e)
if e.t == "Idx" then
local name = stringConstantValue(e.k)
if name and isIdent(name) then
if name == "new" and e.o and e.o.t == "G" then
local abbrev = capAbbrev(e.o.name)
if abbrev then return abbrev .. "new" end
end
return name
end
elseif e.t == "MCall" and (e.n == "GetService" or e.n == "WaitForChild" or e.n == "FindFirstChild") then
local name = e.a[1] and stringConstantValue(e.a[1])
if name and isIdent(name) then return name end
elseif e.t == "Call" then
local f = e.f
if f and f.t == "Idx" and f.o and f.o.t == "G"
and f.o.name == "Instance" and stringConstantValue(f.k) == "new" then
local name = e.a[1] and stringConstantValue(e.a[1])
if name and isIdent(name) then return name end
elseif f and f.t == "Idx" and f.o and f.o.t == "G"
and stringConstantValue(f.k) == "new" and CTOR_RESULT_NAME[f.o.name] then
return CTOR_RESULT_NAME[f.o.name]
elseif f and f.t == "G" and f.name == "require" and #e.a == 1 then
local arg = e.a[1]
if arg and arg.t == "MCall"
and (arg.n == "WaitForChild" or arg.n == "FindFirstChild") then
local name = arg.a[1] and stringConstantValue(arg.a[1])
if name and isIdent(name) then return name end
elseif arg and arg.t == "Idx" then
local name = stringConstantValue(arg.k)
if name and isIdent(name) then return name end
end
end
end
return nil
end

local function protect(fn)
	if CUR.noCatch then return true, fn() end
	return pcall(fn)
end

local function newFuncCtx(script, proto, parentCtx, upvarObjs)
	local used = {}
setmetatable(used, { __index = parentCtx and parentCtx.used or nil })
	return { script = script, proto = proto, used = used, upvals = upvarObjs or {}, parent = parentCtx }
end

local function uniqueName(fctx, base, preserveOriginal)
	local name = base
	local n = 1
while fctx.used[name] or KEYWORDS[name] or fctx.script.globals[name]
or (not preserveOriginal and fctx.script.reserved[name]) do
name = base .. n
n = n + 1
preserveOriginal = false
	end
	fctx.used[name] = true
	return name
end

local function assignName(fctx, v, prefix)
	if v.name then return v.name end
if v.nuse == 0 and not v.isParam and not v.refCaptured and not v.debugName and not v.inferredName then
		v.name = "_"
		return v.name
	end
	local base = v.debugName
local preserveOriginal = (base and isIdent(base)) or (v.inferredNameOriginal and v.inferredName and isIdent(v.inferredName)) or false
if not preserveOriginal then
base = v.inferredName
end
if not (base and isIdent(base)) then
		repeat
			fctx.script.counter = fctx.script.counter + 1
			base = prefix .. fctx.script.counter
until not (fctx.used[base] or fctx.script.globals[base] or KEYWORDS[base] or fctx.script.reserved[base])
preserveOriginal = false
	end
v.name = uniqueName(fctx, base, preserveOriginal)
	return v.name
end

local exprStr, printFunctionBody

local ALWAYS_TRUTHY_CALLS = {
["Color3.fromRGB"] = true, ["Color3.fromHSV"] = true, ["Color3.new"] = true,
}
local function isAlwaysTruthy(e)
if e.t == "K" then
return e.kind ~= "nil" and not (e.kind == "bool" and e.v == false)
end
if e.t == "Table" or e.t == "Closure" then return true end
if e.t == "Call" and e.f and e.f.t == "Idx" and e.f.o and e.f.o.t == "G"
and e.f.k and e.f.k.t == "K" and e.f.k.kind == "str" then
return ALWAYS_TRUTHY_CALLS[e.f.o.name .. "." .. e.f.k.v] == true
end
return false
end

local function isPrefixAtom(e)
	local t = e.t
	return t == "R" or t == "G" or t == "U" or t == "Idx" or t == "Call" or t == "MCall"
end
local SELF_PAREN = { Bin = true, Cmp = true, And = true, Or = true, Not = true, Neg = true, Len = true, Concat = true, IfElse = true }
local function prefixWrap(e, s)
	if isPrefixAtom(e) or SELF_PAREN[e.t] then return s end
	return "(" .. s .. ")"
end

local function nameOfVar(fctx, v)
	if not v then return "_unknown" end
	while v.alias do v = v.alias end
	if v.name then return v.name end
	return assignName(fctx, v, "v")
end

local function keyStr(fctx, k, ind)
	if k.t == "K" and k.kind == "str" and isIdent(k.v) then return nil, k.v end
	return exprStr(fctx, k, 0, ind), nil
end

local function listStr(fctx, list, ind, forceTailParen)
	local parts = {}
	local n = #list
	for i = 1, n do
		local e = list[i]
		local s = exprStr(fctx, e, 0, ind)
		if i == n and (e.t == "Call" or e.t == "MCall" or e.t == "Vararg") and e.multi == false then
			s = "(" .. s .. ")"
		end
		parts[#parts + 1] = s
	end
	return table_concat(parts, ", ")
end

local function wrapIf(cond, s) if cond then return "(" .. s .. ")" end return s end

function exprStr(fctx, e, minPrec, ind)
	ind = ind or 0
	local t = e.t
	if t == "R" then
		return nameOfVar(fctx, e.var)
	elseif t == "K" then
		local k = e.kind
		if k == "nil" then return "nil"
		elseif k == "bool" then return e.v and "true" or "false"
		elseif k == "num" then
			local s = fmtNumber(e.v)
			if (e.v < 0 or s:sub(1, 1) == "-") and minPrec > PREC.unary then return "(" .. s .. ")" end
			return s
		elseif k == "str" then return fmtString(e.v)
		elseif k == "int" then return tostring(e.v) .. "i"
		elseif k == "vec" then
			local v = e.v
			if type(v) == "table" then
				return string_format("Vector3.new(%s, %s, %s)", fmtNumber(v[1] or v.X or 0), fmtNumber(v[2] or v.Y or 0), fmtNumber(v[3] or v.Z or 0))
			end
			return "nil --[[vector]]"
		end
		return "nil --[[" .. tostring(e.v) .. "]]"
	elseif t == "G" then
		if isIdent(e.name) then return e.name end
		return "_G[" .. fmtString(tostring(e.name)) .. "]"
	elseif t == "U" then
		local u = fctx.upvals[e.i + 1]
		if u then
			if u.name then return u.name end
			return nameOfVar(fctx, u)
		end
		return "upval" .. tostring(e.i)
	elseif t == "Idx" then
		local o = e.o
		local os = prefixWrap(o, exprStr(fctx, o, PREC.atom, ind))
		local ks, field = keyStr(fctx, e.k, ind)
		if field then return os .. "." .. field end
		return os .. "[" .. ks .. "]"
	elseif t == "Call" then
		local f = e.f
		local fs = prefixWrap(f, exprStr(fctx, f, PREC.atom, ind))
		return fs .. "(" .. listStr(fctx, e.a, ind) .. ")"
	elseif t == "MCall" then
		local o = e.o
		local os = prefixWrap(o, exprStr(fctx, o, PREC.atom, ind))
		if isIdent(e.n) then
			return os .. ":" .. e.n .. "(" .. listStr(fctx, e.a, ind) .. ")"
		end
		local args = listStr(fctx, e.a, ind)
		return os .. "[" .. fmtString(e.n) .. "](" .. os .. (args ~= "" and (", " .. args) or "") .. ")"
	elseif t == "Bin" then
		local p = BINPREC[e.op]
		local lp, rp = p, p + 1
		if e.op == "^" then lp, rp = p + 1, p end
		local s = exprStr(fctx, e.a, lp, ind) .. " " .. e.op .. " " .. exprStr(fctx, e.b, rp, ind)
		return wrapIf(p < minPrec, s)
	elseif t == "Cmp" then
		local op = e.op
		local a, b = e.a, e.b
		local s = exprStr(fctx, a, PREC.cmp + 1, ind) .. " " .. op .. " " .. exprStr(fctx, b, PREC.cmp + 1, ind)
		return wrapIf(PREC.cmp < minPrec, s)
	elseif t == "And" then
		local s = exprStr(fctx, e.a, PREC["and"], ind) .. " and " .. exprStr(fctx, e.b, PREC["and"], ind)
		return wrapIf(PREC["and"] < minPrec, s)
	elseif t == "Or" then
		local s = exprStr(fctx, e.a, PREC["or"], ind) .. " or " .. exprStr(fctx, e.b, PREC["or"], ind)
		return wrapIf(PREC["or"] < minPrec, s)
	elseif t == "Not" then
		local s = "not " .. exprStr(fctx, e.a, PREC.unary, ind)
		return wrapIf(PREC.unary < minPrec, s)
	elseif t == "Neg" then
		local inner = exprStr(fctx, e.a, PREC.unary, ind)
		if inner:sub(1, 1) == "-" then inner = "(" .. inner .. ")" end
		return wrapIf(PREC.unary < minPrec, "-" .. inner)
	elseif t == "Len" then
		return wrapIf(PREC.unary < minPrec, "#" .. exprStr(fctx, e.a, PREC.unary, ind))
	elseif t == "Concat" then
		local parts = {}
		for i, x in ipairs(e.l) do
			parts[i] = exprStr(fctx, x, (i == #e.l) and PREC.concat or (PREC.concat + 1), ind)
		end
		return wrapIf(PREC.concat < minPrec, table_concat(parts, " .. "))
	elseif t == "IfElse" then
local s
if isAlwaysTruthy(e.a) then
s = exprStr(fctx, e.c, PREC["and"], ind)
.. " and " .. exprStr(fctx, e.a, PREC["and"], ind)
.. " or " .. exprStr(fctx, e.b, PREC["or"], ind)
elseif isAlwaysTruthy(e.b) then
s = "not " .. exprStr(fctx, e.c, PREC.unary, ind)
.. " and " .. exprStr(fctx, e.b, PREC["and"], ind)
.. " or " .. exprStr(fctx, e.a, PREC["or"], ind)
else
s = "(" .. exprStr(fctx, e.c, PREC["and"], ind)
.. " and {" .. exprStr(fctx, e.a, 0, ind) .. "}"
.. " or {" .. exprStr(fctx, e.b, 0, ind) .. "})[1]"
end
		return wrapIf(minPrec > 0, s)
	elseif t == "Vararg" then
		return "..."
	elseif t == "Table" then
		if #e.items == 0 then return "{}" end
		local items = {}
		local multi = false
		for _, it in ipairs(e.items) do
			local vs = exprStr(fctx, it.v or K_NIL(), 0, ind + 1)
			if vs:find("\n", 1, true) then multi = true end
			if it.k then
				local ks, field = keyStr(fctx, it.k, ind + 1)
				if field then items[#items + 1] = field .. " = " .. vs
				else items[#items + 1] = "[" .. ks .. "] = " .. vs end
			else
				local last = (it == e.items[#e.items])
				if last and (it.v.t == "Call" or it.v.t == "MCall" or it.v.t == "Vararg") and it.v.multi == false then
					vs = "(" .. vs .. ")"
				end
				items[#items + 1] = vs
			end
		end
		local one = "{" .. table_concat(items, ", ") .. "}"
		if not multi and #one <= 100 then return one end
		local pad = string.rep(IND, ind + 1)
		return "{\n" .. pad .. table_concat(items, ",\n" .. pad) .. ",\n" .. string.rep(IND, ind) .. "}"
	elseif t == "Closure" then
		return printFunctionBody(fctx, e, ind)
	elseif t == "Unsup" then
		return "nil --[[" .. e.text .. "]]"
	elseif t == "FNPrep" or t == "FNLoop" or t == "FGLoop" then
		return "nil --[[loop marker]]"
	end
	return "nil --[[unknown expr " .. tostring(t) .. "]]"
end

local function eachVarRef(e, fn)
	if e.t == "R" then
		if e.var then fn(e.var) end
		return
	end
	forEachChild(e, eachVarRef, fn)
end

local function planDeclarations(root, paramVars)
	local scope = {}
	local occ = {}
	local order = {}
	local function add(v, seq, idx)
		local l = occ[v]
		if not l then l = {}; occ[v] = l; order[#order + 1] = v end
		l[#l + 1] = { seq, idx }
	end
	local walkSeq
	local function exprOcc(e, seq, idx)
		if e.t == "R" then
			local v = e.var
			if v then add(v, seq, idx) end
			return
		end
		forEachChild(e, exprOcc, seq, idx)
	end
	local function walkNode(nd, seq, i)
		local n = nd.n
		if n == "Stmt" then
			local s = nd.s
			forEachStmtExpr(s, exprOcc, seq, i)
			if s.k == "def" then add(s.dvar, seq, i)
			elseif s.k == "mdef" then for _, v in ipairs(s.dvars) do add(v, seq, i) end
			elseif s.k == "ncdef" then add(s.fvar, seq, i); add(s.svar, seq, i) end
		elseif n == "If" then
			exprOcc(nd.c, seq, i)
			walkSeq(nd.a, seq, i); walkSeq(nd.b, seq, i)
		elseif n == "While" then
			exprOcc(nd.c, seq, i)
			walkSeq(nd.body, seq, i)
		elseif n == "Repeat" then
			walkSeq(nd.body, seq, i)
			exprOcc(nd.c, nd.body, #nd.body + 1)
		elseif n == "LoopT" or n == "DoBlock" or n == "Block" then
			walkSeq(nd.body, seq, i)
		elseif n == "ForN" then
			for _, op in ipairs(nd.prep.ops) do exprOcc(op, seq, i) end
			nd.prep.var.loopHeader = true
			walkSeq(nd.body, seq, i)
		elseif n == "ForG" then
			for _, e in ipairs(nd.explist) do exprOcc(e, seq, i) end
			for _, v in ipairs(nd.c.vars) do v.loopHeader = true end
			walkSeq(nd.body, seq, i)
		elseif n == "Ret" then
			for _, e in ipairs(nd.vals) do exprOcc(e, seq, i) end
		end
	end
	function walkSeq(seq, parent, idx)
		scope[seq] = { parent = parent, idx = idx, depth = parent and (scope[parent].depth + 1) or 0 }
		for i, nd in ipairs(seq) do walkNode(nd, seq, i) end
	end
	walkSeq(root, nil, nil)

	local declsAt = {}
	local declared = {}
	local function place(v, seq, idx)
		local byIdx = declsAt[seq]
		if not byIdx then byIdx = {}; declsAt[seq] = byIdx end
		local l = byIdx[idx]
		if not l then l = {}; byIdx[idx] = l end
		l[#l + 1] = v
	end
	for _, v in ipairs(order) do
		if not v.isParam and not v.loopHeader and not v.isLoopVar then
			local list = occ[v]
			local S = list[1][1]
			for j = 2, #list do
				local T = list[j][1]
				local a, b = S, T
				while scope[a].depth > scope[b].depth do a = scope[a].parent end
				while scope[b].depth > scope[a].depth do b = scope[b].parent end
				while a ~= b do a = scope[a].parent; b = scope[b].parent end
				S = a
			end
			local minIdx, maxIdx = math_huge, 0
			for _, o in ipairs(list) do
				local sq, ix = o[1], o[2]
				while sq ~= S do
					ix = scope[sq].idx
					sq = scope[sq].parent
				end
				if ix < minIdx then minIdx = ix end
				if ix > maxIdx then maxIdx = ix end
			end
			if v.entryUndef then S = root; minIdx = 1; maxIdx = math_huge end
			v.declSeq, v.declIdx, v.declMax = S, minIdx, maxIdx
			place(v, S, minIdx)
			declared[#declared + 1] = v
		end
	end
	local aggressive = #declared > 120
	local cand = {}
	for _, v in ipairs(order) do
		if v.isParam then
			local list = occ[v]
			local maxIdx = 0
			for _, o in ipairs(list) do
				local sq, ix = o[1], o[2]
				while sq ~= root do ix = scope[sq].idx; sq = scope[sq].parent end
				if ix > maxIdx then maxIdx = ix end
			end
			v.declSeq, v.declIdx, v.declMax = root, 0, maxIdx
			cand[#cand + 1] = v
		elseif v.declSeq and not v.loopHeader and not v.isLoopVar then
			cand[#cand + 1] = v
		end
	end
	local groups = {}
	for _, v in ipairs(cand) do
		if v.reg and v.reg >= 0 and not v.captured and not v.refCaptured and not v.entryUndef
			and (v.nuse > 0 or v.isParam) then
			local bySeq = groups[v.declSeq]
			if not bySeq then bySeq = {}; groups[v.declSeq] = bySeq end
			local l = bySeq[v.reg]
			if not l then l = {}; bySeq[v.reg] = l end
			l[#l + 1] = v
		end
	end
	local function namesCompatible(a, b)
		if a.debugName and b.debugName then return a.debugName == b.debugName end
		return true
	end
	for seq, bySeq in pairs(groups) do
		for reg, list in pairs(bySeq) do
			table_sort(list, function(a, b)
				if a.declIdx ~= b.declIdx then return a.declIdx < b.declIdx end
				return (a.isParam and 0 or 1) < (b.isParam and 0 or 1)
			end)
			local base = list[1]
			for q = 2, #list do
				local v = list[q]
				local ok = false
				if v.isParam then
					ok = false
				elseif v.declIdx > base.declMax then
					if base.debugName and v.debugName then ok = (base.debugName == v.debugName)
					else ok = aggressive and namesCompatible(base, v) or (base.isParam and false) end
					if base.debugName and v.debugName == nil and not aggressive then ok = false end
				elseif v.declIdx == base.declMax then
					local node = seq[v.declIdx]
					ok = node ~= nil and node.n == "Stmt" and node.s.k == "def" and node.s.dvar == v
						and namesCompatible(base, v)
				end
				if ok then
					v.alias = base
					local at = declsAt[seq] and declsAt[seq][v.declIdx]
					if at then
						for qi = #at, 1, -1 do if at[qi] == v then table_remove(at, qi) end end
					end
					if v.declMax > base.declMax then base.declMax = v.declMax end
				else
					base = v
				end
			end
		end
	end
	for _, v in ipairs(cand) do
		if not v.alias and not v.isParam and v.reg and v.reg >= 0 and not v.captured and not v.refCaptured
			and not v.entryUndef and v.nuse > 0 and v.declSeq then
			local node = v.declSeq[v.declIdx]
			local st = node and node.n == "Stmt" and node.s
			if st and st.k == "def" and st.dvar == v and st.e ~= nil then
				local b
				eachVarRef(st.e, function(u) if u.reg == v.reg and u ~= v then b = u end end)
				while b and b.alias do b = b.alias end
				if b and b ~= v and b.reg == v.reg and b.declSeq and b.declSeq ~= v.declSeq and not b.captured
					and not b.refCaptured and not b.entryUndef and not b.loopHeader and not b.isLoopVar
					and (not (b.debugName or v.debugName) or b.debugName == v.debugName) then
					local sq, ix = v.declSeq, nil
					while sq ~= nil and sq ~= b.declSeq do ix = scope[sq].idx; sq = scope[sq].parent end
					if sq == b.declSeq and ix ~= nil and b.declIdx < ix then
						v.alias = b
						local at = declsAt[v.declSeq] and declsAt[v.declSeq][v.declIdx]
						if at then
							for qi = #at, 1, -1 do if at[qi] == v then table_remove(at, qi) end end
						end
						if ix > b.declMax then b.declMax = ix end
					end
				end
			end
		end
	end
	return declsAt
end

local function exprReferencesVar(e, var)
	local found = false
	eachVarRef(e, function(v) if v == var then found = true end end)
	return found
end

local indentStr
do
local indentCache = {}
function indentStr(ind)
	local s = indentCache[ind]
	if s == nil then s = string.rep(IND, ind); indentCache[ind] = s end
	return s
end
end

local OPENERS = { ["then"] = true, ["do"] = true, ["else"] = true, ["repeat"] = true }
local function emitLine(out, ind, text)
	if string_byte(text, 1) == 40 and #out > 0 then
		local prev = out[#out]
		local lastWord = prev:match("([%a_]+)%s*$")
		local lastChar = prev:match("(.)%s*$")
		local isOpener = lastWord and OPENERS[lastWord] and not prev:match("[%w_]%.[%a_]+%s*$")
		if not isOpener and lastChar ~= ";" and lastChar ~= "{" and lastChar ~= "," and not prev:match("^%s*%-%-") then
			out[#out] = prev .. ";"
		end
	end
	out[#out + 1] = indentStr(ind) .. text
end

local printSeq

local function printStmt(fctx, s, declsHere, out, ind, seq, idx)
	local k = s.k
	if k == "def" then
		local v = s.dvar
		local name = nameOfVar(fctx, v)
		local e = s.e
		if (declsHere and declsHere[v]) then
			declsHere[v] = nil
			if e.t == "Closure" then
				local fn = exprStr(fctx, e, 0, ind)
				emitLine(out, ind, "local " .. (fn:gsub("^function", "function " .. name, 1)))
				return
			end
			emitLine(out, ind, "local " .. name .. " = " .. exprStr(fctx, e, 0, ind))
		else
			if e.t == "Closure" and false then end
			emitLine(out, ind, name .. " = " .. exprStr(fctx, e, 0, ind))
		end
	elseif k == "mdef" then
		local names, allDecl = {}, true
		for q, v in ipairs(s.dvars) do
			names[q] = nameOfVar(fctx, v)
			if not (declsHere and declsHere[v]) then allDecl = false end
		end
		if allDecl then
			for _, v in ipairs(s.dvars) do declsHere[v] = nil end
			emitLine(out, ind, "local " .. table_concat(names, ", ") .. " = " .. exprStr(fctx, s.e, 0, ind))
		else
			for q, v in ipairs(s.dvars) do
				if (declsHere and declsHere[v]) then declsHere[v] = nil; emitLine(out, ind, "local " .. names[q]) end
			end
			emitLine(out, ind, table_concat(names, ", ") .. " = " .. exprStr(fctx, s.e, 0, ind))
		end
	elseif k == "call" then
		emitLine(out, ind, exprStr(fctx, s.e, 0, ind))
	elseif k == "set" then
		local o = s.o
		local os = prefixWrap(o, exprStr(fctx, o, PREC.atom, ind))
		local ks, field = keyStr(fctx, s.key, ind)
		local lhs = field and (os .. "." .. field) or (os .. "[" .. ks .. "]")
		emitLine(out, ind, lhs .. " = " .. exprStr(fctx, s.v, 0, ind))
	elseif k == "massign" then
		local lhs = {}
		for qi, st in ipairs(s.stores) do
			if st.k == "set" then
				local o = st.o
				local os = prefixWrap(o, exprStr(fctx, o, PREC.atom, ind))
				local ks, field = keyStr(fctx, st.key, ind)
				lhs[qi] = field and (os .. "." .. field) or (os .. "[" .. ks .. "]")
			elseif st.k == "setg" then
				lhs[qi] = isIdent(st.name) and st.name or ("_G[" .. fmtString(st.name) .. "]")
			else
				local u = fctx.upvals[st.i + 1]
				lhs[qi] = u and (u.name or nameOfVar(fctx, u)) or ("upval" .. tostring(st.i))
			end
		end
		local rhs = {}
		for qi, e in ipairs(s.vals) do rhs[qi] = exprStr(fctx, e, 0, ind) end
		emitLine(out, ind, table_concat(lhs, ", ") .. " = " .. table_concat(rhs, ", "))
	elseif k == "setg" then
		local v = s.v
		if v.t == "Closure" and isIdent(s.name) then
			local fn = exprStr(fctx, v, 0, ind)
			emitLine(out, ind, (fn:gsub("^function", "function " .. s.name, 1)))
		else
			emitLine(out, ind, (isIdent(s.name) and s.name or ("_G[" .. fmtString(s.name) .. "]")) .. " = " .. exprStr(fctx, v, 0, ind))
		end
	elseif k == "setu" then
		local u = fctx.upvals[s.i + 1]
		local nm = u and (u.name or nameOfVar(fctx, u)) or ("upval" .. tostring(s.i))
		emitLine(out, ind, nm .. " = " .. exprStr(fctx, s.v, 0, ind))
	elseif k == "setlist" then
		local o = s.o
		local os = prefixWrap(o, exprStr(fctx, o, PREC.atom, ind))
		local nv = #s.vals
		local lastV = s.vals[nv]
		local spread = lastV and (lastV.t == "Call" or lastV.t == "MCall" or lastV.t == "Vararg") and lastV.multi == true
		for q, v in ipairs(s.vals) do
			if not (spread and q == nv) then
				emitLine(out, ind, os .. "[" .. tostring((s.start or 1) + q - 1) .. "] = " .. exprStr(fctx, v, 0, ind))
			end
		end
		if spread then
			local pk = uniqueName(fctx, "packed")
			local ix = uniqueName(fctx, "i")
			emitLine(out, ind, "do")
			emitLine(out, ind + 1, "local " .. pk .. " = table.pack(" .. exprStr(fctx, lastV, 0, ind + 1) .. ")")
			emitLine(out, ind + 1, "for " .. ix .. " = 1, " .. pk .. ".n do " .. os .. "[" .. tostring((s.start or 1) + nv - 1) .. " + " .. ix .. " - 1] = " .. pk .. "[" .. ix .. "] end")
			emitLine(out, ind, "end")
		end
	elseif k == "eval" then
		emitLine(out, ind, "local _ = " .. exprStr(fctx, s.e, 0, ind))
	elseif k == "ncdef" then
		local fnv, sv = nameOfVar(fctx, s.fvar), nameOfVar(fctx, s.svar)
		emitLine(out, ind, "local " .. sv .. " = " .. exprStr(fctx, s.o, 0, ind))
		emitLine(out, ind, "local " .. fnv .. " = " .. sv .. "[" .. fmtString(s.name) .. "] --[[namecall]]")
		if declsHere then declsHere[s.fvar] = nil; declsHere[s.svar] = nil end
	elseif k == "close" or k == "fgprep" then
	end
end

local function condStr(fctx, c, ind)
	return exprStr(fctx, c, 0, ind)
end

function printSeq(fctx, seq, declsAt, out, ind, isRoot)
	local byIdx = declsAt[seq]
	local nNodes = #seq
	if isRoot and nNodes > 0 and seq[nNodes].n == "Ret" and #seq[nNodes].vals == 0 then nNodes = nNodes - 1 end
	for i = 1, nNodes do
		local nd = seq[i]
		local declsHere
		if byIdx and byIdx[i] then
			declsHere = {}
			for _, v in ipairs(byIdx[i]) do declsHere[v] = true end
			local inlineOK = false
			if nd.n == "Stmt" then
				local s = nd.s
				if s.k == "def" then
					inlineOK = true
					local v = s.dvar
					if declsHere[v] and s.e.t ~= "Closure" and exprReferencesVar(s.e, v) then declsHere[v] = nil; emitLine(out, ind, "local " .. nameOfVar(fctx, v)) end
				elseif s.k == "mdef" or s.k == "ncdef" then inlineOK = true end
			end
			if not inlineOK then
				local names = {}
				for _, v in ipairs(byIdx[i]) do names[#names + 1] = nameOfVar(fctx, v) end
				for _, nm in ipairs(names) do emitLine(out, ind, "local " .. nm) end
				declsHere = nil
			else
				local s = nd.s
				for _, v in ipairs(byIdx[i]) do
					local mine = (s.k == "def" and s.dvar == v)
					if s.k == "mdef" then for _, dv in ipairs(s.dvars) do if dv == v then mine = true end end end
					if s.k == "ncdef" and (s.fvar == v or s.svar == v) then mine = true end
					if not mine and declsHere[v] then
						declsHere[v] = nil
						emitLine(out, ind, "local " .. nameOfVar(fctx, v))
					end
				end
			end
		end
		local n = nd.n
		if n == "Stmt" then
			printStmt(fctx, nd.s, declsHere, out, ind, seq, i)
		elseif n == "If" then
			local chain = nd
			emitLine(out, ind, "if " .. condStr(fctx, chain.c, ind) .. " then")
			while true do
				printSeq(fctx, chain.a, declsAt, out, ind + 1, false)
				local b = chain.b
				if #b == 0 then break end
				if #b == 1 and b[1].n == "If" and not (declsAt[b] and declsAt[b][1]) then
					chain = b[1]
					emitLine(out, ind, "elseif " .. condStr(fctx, chain.c, ind) .. " then")
				else
					emitLine(out, ind, "else")
					printSeq(fctx, b, declsAt, out, ind + 1, false)
					break
				end
			end
			emitLine(out, ind, "end")
		elseif n == "While" then
			emitLine(out, ind, "while " .. condStr(fctx, nd.c, ind) .. " do")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "end")
		elseif n == "LoopT" then
			emitLine(out, ind, "while true do")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "end")
		elseif n == "Repeat" then
			emitLine(out, ind, "repeat")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "until " .. condStr(fctx, nd.c, ind))
		elseif n == "DoBlock" then
			if nd.unsafe then emitLine(out, ind, "-- [decompiler] unstructured control flow below (block " .. tostring(nd.label) .. ")") end
			emitLine(out, ind, "repeat")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "until true")
		elseif n == "ForN" then
			local ops = nd.prep.ops
			local v = nd.prep.var
			local name = assignName(fctx, v, "v")
			local head = "for " .. name .. " = " .. exprStr(fctx, ops[3], 0, ind) .. ", " .. exprStr(fctx, ops[1], 0, ind)
			local stepE = ops[2]
			if not (stepE.t == "K" and stepE.kind == "num" and stepE.v == 1) then
				head = head .. ", " .. exprStr(fctx, stepE, 0, ind)
			end
			emitLine(out, ind, head .. " do")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "end")
		elseif n == "ForG" then
			local names = {}
			for q, v in ipairs(nd.c.vars) do names[q] = assignName(fctx, v, "v") end
			local lst = {}
			for q, e in ipairs(nd.explist) do lst[q] = exprStr(fctx, e, 0, ind) end
			emitLine(out, ind, "for " .. table_concat(names, ", ") .. " in " .. table_concat(lst, ", ") .. " do")
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "end")
		elseif n == "Ret" then
			if #nd.vals == 0 then emitLine(out, ind, "return")
			else emitLine(out, ind, "return " .. listStr(fctx, nd.vals, ind)) end
		elseif n == "Break" then emitLine(out, ind, "break")
		elseif n == "Continue" then emitLine(out, ind, "continue")
		elseif n == "Br" then
			emitLine(out, ind, "-- [decompiler] unstructured jump to the end of block " .. tostring(nd.label))
			emitLine(out, ind, 'error("decompiler: unstructured control flow")')
		elseif n == "Unsup" then
			emitLine(out, ind, "-- [decompiler] " .. nd.text)
			emitLine(out, ind, 'error("decompiler: ' .. nd.text .. '")')
		elseif n == "Block" then
			emitLine(out, ind, "do -- block " .. tostring(nd.label))
			printSeq(fctx, nd.body, declsAt, out, ind + 1, false)
			emitLine(out, ind, "end")
		end
	end
end

local function stripFnTailReturn(seq)
	local last = seq[#seq]
	if not last then return end
	if last.n == "Ret" and #last.vals == 0 then
		seq[#seq] = nil
	elseif last.n == "If" then
		stripFnTailReturn(last.a)
		stripFnTailReturn(last.b)
	end
end

local function countVarOccs(seq, counts)
	local function bump(v) counts[v] = (counts[v] or 0) + 1 end
	local function expr(e)
		if e.t == "R" then if e.var then bump(e.var) end return end
		forEachChild(e, expr)
	end
	local function walk(s)
		for _, nd in ipairs(s) do
			local k = nd.n
			if k == "Stmt" then
				forEachStmtExpr(nd.s, expr)
				if nd.s.dvar then bump(nd.s.dvar) end
				if nd.s.dvars then for _, v in ipairs(nd.s.dvars) do bump(v) end end
			elseif k == "If" then expr(nd.c); walk(nd.a); walk(nd.b)
			elseif k == "While" or k == "Repeat" then expr(nd.c); walk(nd.body)
			elseif k == "ForN" then for _, op in ipairs(nd.prep.ops) do expr(op) end; walk(nd.body)
			elseif k == "ForG" then for _, e in ipairs(nd.explist) do expr(e) end; walk(nd.body)
			elseif k == "Ret" then for _, e in ipairs(nd.vals) do expr(e) end
			elseif nd.body then walk(nd.body) end
		end
	end
	walk(seq)
end

local function fixEscapingLoopVars(root)
	local total
	local function visit(seq)
		for _, nd in ipairs(seq) do
			if nd.n == "ForN" or nd.n == "ForG" then
				if not total then total = {}; countVarOccs(root, total) end
				local vars = (nd.n == "ForN") and { nd.prep.var } or nd.c.vars
				local inside = {}
				countVarOccs(nd.body, inside)
				for q, v in ipairs(vars) do
					local inn = inside[v] or 0
					local tot = total[v] or 0
					if tot > inn then
						local h = { id = -1, reg = -1, nuse = math.max(1, inn), defList = {}, isLoopVar = true, debugName = v.debugName }
						if nd.n == "ForN" then nd.prep.var = h else nd.c.vars[q] = h end
						v.isLoopVar = nil
						v.loopHeader = nil
						table_insert(nd.body, 1, { n = "Stmt", s = { k = "def", dst = -1, e = { t = "R", r = -1, var = h }, dvar = v, synthetic = true } })
						inside[v] = inn + 1
						total[v] = tot + 1
					end
				end
			end
			if nd.n == "If" then visit(nd.a); visit(nd.b)
			elseif nd.body then visit(nd.body) end
		end
	end
	visit(root)
end

local MA_STORE = { set = true, setg = true, setu = true }
local MA_MAX = 128

local function maDeadAfter(b, S, e, r)
	local one = { r }
	for x = e + 1, #S do
		local sx = S[x]
		local rd = readsOf(sx)
		for q = 1, #rd do if rd[q] == r then return false end end
		if stmtDefsAny(sx, one) then return true end
	end
	local rd = termReadsCached(b.term)
	for q = 1, #rd do if rd[q] == r then return false end end
	local td = termDefs(b.term)
	if td then for q = 1, #td do if td[q] == r then return true end end end
	if b.loArr == nil and b.liveOut == nil then return false end
	return not liveOutHas(b, r)
end

local function maTryFold(b, S, i, proto)
	local nS = #S
	local e = i
	while e < nS and e - i + 1 < MA_MAX and MA_STORE[S[e + 1].k] do e = e + 1 end
	local nRun = e - i + 1
	if nRun < 2 then return nil end

	local slotT, slotS, bareCnt, runReads = {}, {}, {}, {}
	for t = 1, nRun do
		local st = S[i + t - 1]
		local ex = st.o
		if ex ~= nil and ex.t == "R" then bareCnt[ex.r] = (bareCnt[ex.r] or 0) + 1; slotT[ex.r] = t; slotS[ex.r] = "o" end
		ex = st.key
		if ex ~= nil and ex.t == "R" then bareCnt[ex.r] = (bareCnt[ex.r] or 0) + 1; slotT[ex.r] = t; slotS[ex.r] = "key" end
		ex = st.v
		if ex ~= nil and ex.t == "R" then bareCnt[ex.r] = (bareCnt[ex.r] or 0) + 1; slotT[ex.r] = t; slotS[ex.r] = "v" end
		local rd = readsOf(st)
		for q = 1, #rd do local r = rd[q]; runReads[r] = (runReads[r] or 0) + 1 end
	end

	local refOpen = CUR.refOpen
	local absorbed, m = {}, 0
	local q = i - 1
	while q >= 1 do
		local D = S[q]
		local dk = D.k
		if dk ~= "def" and dk ~= "mdef" then break end
		local dsts = dk == "def" and { D.dst } or D.dsts
		local ok = true
		if dk == "def" and D.e.t == "Closure" then
			local caps = D.e.caps
			for ci = 1, #caps do local nd = caps[ci].node; if nd and nd.r == D.dst then ok = false end end
		end
		for di = 1, #dsts do
			if not ok then break end
			local r = dsts[di]
			if bareCnt[r] ~= 1 or runReads[r] ~= 1 then ok = false; break end
			local ro = refOpen[r]
			if ro ~= nil and (D.pc == nil or ro[D.pc] == true) then ok = false; break end
			for x = q + 1, i - 1 do
				local sx = S[x]
				if stmtDefsAny(sx, dsts) then ok = false; break end
				local rd = readsOf(sx)
				for z = 1, #rd do if rd[z] == r then ok = false; break end end
				if not ok then break end
			end
			if not ok then break end
			if not maDeadAfter(b, S, e, r) then ok = false; break end
			if debugNameFor(proto, r, S[i + slotT[r] - 1].pc) then ok = false; break end
		end
		if not ok then break end
		m = m + 1
		absorbed[m] = D
		q = q - 1
	end
	if m == 0 then return nil end
	for a = 1, m // 2 do absorbed[a], absorbed[m - a + 1] = absorbed[m - a + 1], absorbed[a] end

	local G, tailK = 0, nil
	for a = 1, m do
		local D = absorbed[a]
		if D.k == "def" then
			local t = slotT[D.dst]
			if t > G then G = t end
		else
			local ds = D.dsts
			local k = #ds
			if a ~= m or k < 2 then return nil end
			local t1 = slotT[ds[1]]
			for di = 1, k do
				local r = ds[di]
				if slotS[r] ~= "v" or slotT[r] ~= t1 + di - 1 then return nil end
			end
			tailK = k
			if t1 + k - 1 > G then G = t1 + k - 1 end
		end
	end
	if G < 2 then return nil end
	if tailK and slotT[absorbed[m].dsts[tailK]] ~= G then return nil end

	local function slotPos(t, name)
		if name == "o" then return 2 * (t - 1) + 1 end
		if name == "key" then return 2 * (t - 1) + 2 end
		return 2 * G + t
	end
	local posA, prevPos = {}, 0
	local isAbs = {}
	local SLOTCODE = { o = 0, key = 1, v = 2 }
	for a = 1, m do
		local D = absorbed[a]
		local ds = D.k == "def" and { D.dst } or D.dsts
		local p = slotPos(slotT[ds[1]], slotS[ds[1]])
		if p <= prevPos then return nil end
		prevPos = p
		posA[a] = p
		for di = 1, #ds do isAbs[slotT[ds[di]] * 3 + SLOTCODE[slotS[ds[di]]]] = true end
	end

	local items, nItems, oc = {}, 0, 0
	for a = 1, m do
		oc = oc + 1
		local rd, wr = effOf(absorbed[a])
		if rd or wr then nItems = nItems + 1; items[nItems] = { oc, posA[a], rd, wr } end
	end
	for t = 1, G do
		local st = S[i + t - 1]
		for ci = 0, 2 do
			local name = (ci == 0 and "o") or (ci == 1 and "key") or "v"
			local ex = st[name]
			if ex ~= nil and not isAbs[t * 3 + ci] then
				oc = oc + 1
				local rd, wr = exprEffect(ex)
				if rd or wr then nItems = nItems + 1; items[nItems] = { oc, slotPos(t, name), rd, wr } end
			end
		end
		oc = oc + 1
		nItems = nItems + 1
		items[nItems] = { oc, 3 * G + t, true, true }
	end
	for x = 1, nItems do
		local ix = items[x]
		for y = 1, nItems do
			local iy = items[y]
			if ix[1] < iy[1] and ix[2] > iy[2] and not effCommute(ix[3], ix[4], iy[3], iy[4]) then return nil end
		end
	end

	local repl = {}
	local tailExpr
	for a = 1, m do
		local D = absorbed[a]
		if D.k == "def" then
			local t = slotT[D.dst]
			local rp = repl[t]
			if not rp then rp = {}; repl[t] = rp end
			rp[slotS[D.dst]] = D.e
		else
			tailExpr = D.e
		end
	end
	local stores, vals, nv = {}, {}, 0
	for t = 1, G do
		local st = S[i + t - 1]
		local ns = { k = st.k, o = st.o, key = st.key, name = st.name, i = st.i, pc = st.pc, _rd = nil, _ef = nil }
		local rp = repl[t]
		if rp then
			if rp.o then ns.o = rp.o end
			if rp.key then ns.key = rp.key end
		end
		stores[t] = ns
		if tailK and t >= G - tailK + 1 then
			if t == G - tailK + 1 then nv = nv + 1; vals[nv] = tailExpr end
		else
			nv = nv + 1
			vals[nv] = (rp and rp.v) or st.v
		end
	end
	return { k = "massign", stores = stores, vals = vals, pc = S[i].pc, _rd = nil, _ef = nil }, i - m, i + G - 1
end

local function maFoldMdefMoves(b, S, proto)
	local refOpen = CUR.refOpen
	local x = 1
	while x < #S do
		local M = S[x]
		if M.k == "mdef" then
			local ds = M.dsts
			local k = #ds
			local y = x + 1
			local targets, movePc, nMoves, ok = {}, {}, 0, true
			for qd = 1, k do
				local mv = S[y]
				local d = ds[qd]
				if mv ~= nil and mv.k == "def" and mv.e.t == "R" and mv.e.r == d and mv.dst ~= d then
					targets[qd] = mv.dst
					movePc[qd] = mv.pc
					nMoves = nMoves + 1
					y = y + 1
				else
					targets[qd] = false
				end
			end
			local lastMove = y - 1
			if nMoves > 0 then
				for qd = 1, k do
					local d = ds[qd]
					local t = targets[qd]
					if not maDeadAfter(b, S, lastMove, d) then ok = false; break end
					for z = x + 1, lastMove do
						local mv = S[z]
						if mv.e.r == d and not (t and mv.dst == t) then ok = false; break end
						if mv.dst == d then ok = false; break end
					end
					if not ok then break end
					if t then
						local mvPc = movePc[qd]
						local ro = refOpen[t]
						if ro ~= nil and (mvPc == nil or ro[mvPc] == true) then ok = false; break end
						for qe = 1, k do
							if qe ~= qd and (t == ds[qe] or t == targets[qe]) then ok = false; break end
						end
						if not ok then break end
						if debugNameFor(proto, d, mvPc) then ok = false; break end
					end
				end
			else
				ok = false
			end
			if ok then
				for qd = 1, k do if targets[qd] then ds[qd] = targets[qd] end end
				local drop = lastMove - x
				local nS = #S
				for z = lastMove + 1, nS do S[z - drop] = S[z] end
				for z = nS - drop + 1, nS do S[z] = nil end
				M._ef = nil
			end
		end
		x = x + 1
	end
end

local function foldMultiAssign(cfg, proto)
	local blocks = liveBlocks(cfg)
	for bi = 1, #blocks do
		local b = blocks[bi]
		local S = b.stmts
		maFoldMdefMoves(b, S, proto)
		local i = 2
		while i < #S do
			if MA_STORE[S[i].k] and MA_STORE[S[i + 1].k] and (S[i - 1].k == "def" or S[i - 1].k == "mdef") then
				local ns, from, to = maTryFold(b, S, i, proto)
				if ns then
					S[from] = ns
					local drop, nS = to - from, #S
					for x = to + 1, nS do S[x - drop] = S[x] end
					for x = nS - drop + 1, nS do S[x] = nil end
					i = from + 1
				else
					while i <= #S and MA_STORE[S[i].k] do i = i + 1 end
				end
			else
				i = i + 1
			end
		end
	end
end

local function analyzeProto(proto, data)
	local cfg = lift(proto, data)
	CUR.refOpen = cfg.refOpen
	simplifyCFG(cfg)
	foldMultiAssign(cfg, proto)
	local webs = buildWebs(cfg, proto)
	local info = analyzeCFG(cfg)
	local tree = buildTree(cfg, info)
	tree = lowerTree(tree)
	stripFnTailReturn(tree)
	tree = normalizeFix(tree)
	fixEscapingLoopVars(tree)
	for _, v in ipairs(webs.vars) do
		for _, d in ipairs(v.defList) do
			local pc = d.pc
			if d.entry and d.param then pc = 0 end
			local nm = debugNameFor(proto, v.reg, pc)
			if nm then v.debugName = nm break end
		end
		if not v.debugName and #v.defList == 1 and v.defStmt and v.defStmt.e then
v.inferredName = inferredNameFor(v.defStmt.e)
		end
if not v.debugName and not v.inferredName then
			local ds = v.defStmt
			if ds and ds.e and ds.e.t == "Closure" and ds.e.proto and isIdent(ds.e.proto.Source or "") then
v.inferredName = ds.e.proto.Source
v.inferredNameOriginal = true
			end
		end
	end
	return { cfg = cfg, webs = webs, tree = tree }
end

local function paramList(fctx, an, isVararg)
	local names = {}
	for i, v in ipairs(an.webs.paramVars) do
		v.isParam = true
		names[i] = assignName(fctx, v, "p")
	end
	if isVararg then names[#names + 1] = "..." end
	return table_concat(names, ", ")
end

local function fallbackBody(proto, err, out, ind)
	emitLine(out, ind, "-- [decompiler] failed on this function: " .. tostring(err):gsub("\n", " "))
	for _, I in ipairs(proto.Instructions or BuildInstructionRecords(proto)) do
		emitLine(out, ind, string_format("-- %04d %s %s %s %s", I.Pc or 0, tostring(I.Name), tostring(I.A), tostring(I.B), tostring(I.C)))
	end
end

function printFunctionBody(fctx, closure, ind)
	local proto = closure.proto
	if not proto then return "function() end --[[missing proto]]" end
	local ups = {}
	for i, cap in ipairs(closure.caps) do
		if cap.mode == "up" then ups[i] = fctx.upvals[cap.idx + 1]
		else ups[i] = cap.node.var end
	end
	for _, cap in ipairs(closure.caps) do
		if cap.node and cap.node.var then nameOfVar(fctx, cap.node.var) end
	end
	local child = newFuncCtx(fctx.script, proto, fctx, ups)
	local ok, headOrErr, bodyLines = protect(function()
		local an = analyzeProto(proto, fctx.script.data)
		local declsAt = planDeclarations(an.tree, an.webs.paramVars)
		local head = paramList(child, an, proto.IsVarArg)
		local out = {}
		printSeq(child, an.tree, declsAt, out, ind + 1, true)
		return head, out
	end)
	if ok then
		if #bodyLines == 0 then return "function(" .. headOrErr .. ") end" end
		return "function(" .. headOrErr .. ")\n" .. table_concat(bodyLines, "\n") .. "\n" .. indentStr(ind) .. "end"
	end
	local out = {}
	fallbackBody(proto, headOrErr, out, ind + 1)
	return "function(...)\n" .. table_concat(out, "\n") .. "\n" .. indentStr(ind) .. "end"
end

local function collectGlobals(data)
	local set = {}
	for _, p in ipairs(data.Protos) do
		local K = p.Constants
		local OpNames, OpAux = p.OpNames, p.OpAux
		for i = 1, p.OpCount do
			local op = OpNames[i]
			if op == "GETGLOBAL" or op == "SETGLOBAL" then
				local kv = K[(OpAux[i] or 0) + 1]
				if kv and type(kv.Value) == "string" then set[kv.Value] = true end
			elseif op == "GETIMPORT" then
				local id = OpAux[i] or 0
				local idx = band(rshift(id, 20), 1023)
				local kv = K[idx + 1]
				if kv and type(kv.Value) == "string" then set[kv.Value] = true end
			end
		end
	end
	return set
end

local function collectReservedNames(data)
local set = {}
for _, p in ipairs(data.Protos) do
local raw = p.RawProto
if raw then
for _, localInfo in ipairs(raw.Locals or {}) do
if isIdent(localInfo.Name) then set[localInfo.Name] = true end
end
for _, name in ipairs(raw.UpvalNames or {}) do
if isIdent(name) then set[name] = true end
end
if isIdent(raw.Source or "") then set[raw.Source] = true end
end
end
return set
end

local function decompileChunk(data)
	identCache = {}
local script = {
data = data,
counter = 0,
globals = collectGlobals(data),
reserved = collectReservedNames(data),
}
	local main = data.MainProto
	local fctx = newFuncCtx(script, main, nil, {})
	local ok, res = protect(function()
		local an = analyzeProto(main, data)
		local declsAt = planDeclarations(an.tree, an.webs.paramVars)
		paramList(fctx, an, main.IsVarArg)
		local out = {}
		printSeq(fctx, an.tree, declsAt, out, 0, true)
		return table_concat(out, "\n")
	end)
	if ok then return res end
	local out = {}
	fallbackBody(main, res, out, 0)
	return table_concat(out, "\n")
end

DecompilerCore.Decompile = decompileChunk
DecompilerCore._export = {
	analyzeProto = analyzeProto, lift = lift, dumpCFG = dumpCFG, simplifyCFG = simplifyCFG,
	buildWebs = buildWebs, analyzeCFG = analyzeCFG, buildTree = buildTree, lowerTree = lowerTree,
	setNoCatch = function(v) CUR.noCatch = v end, dumpTree = dumpTree, setDebugLower = function(f) CUR.debugLower = f end, setRefRegs = function(r) CUR.refOpen = r end, rebuildEdges = rebuildEdges,
}
end
return DecompilerCore
end)()

local function chooseOptimizeDirective(Info, Mode)
	if not Info or not Info.InferenceAvailable or Info.Conflict or Mode == "never" then
		return nil
	end
	if Info.Directive then
		return Info.Directive
	end
	if Mode == "always" then
		return "--!optimize " .. tostring(Info.DefaultOptimizationLevel or 2)
	end
	if Mode == "best" then
		return Info.GuessDirective
	end
	return nil
end

local function formatOptimizationLines(Info, EmittedDirective)
	if not Info or not Info.InferenceAvailable then
		return { "  --!optimize: unknown (no instruction stream to inspect)" }
	end
	local Default = Info.DefaultOptimizationLevel or 2
	local Lines = {}
	if Info.Conflict then
		Lines[1] = "  --!optimize: conflicting evidence (proven minimum " .. tostring(Info.MinimumOptimizationLevel)
			.. ", proven maximum " .. tostring(Info.MaximumOptimizationLevel)
			.. "); the bytecode may be mixed or from an unrecognized compiler"
	elseif Info.ExactOptimizationLevel ~= nil and Info.ExactOptimizationLevel ~= Default then
		local Suffix
		if EmittedDirective then
			Suffix = "; emitted above as the executable directive " .. EmittedDirective
		elseif Info.Directive then
			Suffix = "; add " .. Info.Directive .. " to reproduce it (not emitted with the current option)"
		else
			Suffix = ""
		end
		Lines[1] = "  --!optimize: exactly level " .. tostring(Info.ExactOptimizationLevel)
			.. " (proven below the default level " .. tostring(Default) .. ")" .. Suffix
	else
		local Guess = Info.ExactOptimizationLevel or Info.BestGuessOptimizationLevel
		if Guess == nil or Guess == Default then
			Lines[1] = "  --!optimize: level " .. tostring(Default)
				.. " (default; nothing in the bytecode proves a lower level)"
			if EmittedDirective then
				Lines[1] = Lines[1] .. "; stated above as " .. EmittedDirective
			end
		else
			local Parts = {}
			if Info.MaximumOptimizationLevel then
				Parts[#Parts + 1] = "not level " .. tostring(Default) .. " (maximum level "
					.. tostring(Info.MaximumOptimizationLevel) .. " proven)"
			else
				Parts[#Parts + 1] = "level " .. tostring(Default) .. " by default"
			end
			local Text = "best guess level " .. tostring(Guess) .. " (" .. tostring(Info.Confidence)
				.. " confidence; not proven)"
			if EmittedDirective then
				Text = Text .. "; emitted above as " .. EmittedDirective
			end
			Parts[#Parts + 1] = Text
			Lines[1] = "  --!optimize: " .. table_concat(Parts, "; ")
		end
	end
	for _, Reason in ipairs(Info.Reasons or {}) do
		if Reason.Strength == "note" then
			Lines[#Lines + 1] = "    note: " .. Reason.Text
		else
			Lines[#Lines + 1] = "    " .. Reason.Strength .. " " .. Reason.Constraint .. ": " .. Reason.Text
		end
	end
	return Lines
end

local function formatDirectiveMetadata(NativeInfo, OptimizationInfo, EmittedDirective)
local Lines = { "--[[ Decompiled directive metadata (this block is explanatory, not executable directives):" }
if NativeInfo and NativeInfo.FlagsAvailable then
Lines[#Lines + 1] = NativeInfo.IsNativeModule
and "  --!native: confirmed by the main-prototype flag"
or "  --!native: not marked in the main-prototype flag"
if #NativeInfo.NativeFunctionProtoIndices > 0 then
local Indices = table_create(#NativeInfo.NativeFunctionProtoIndices)
for i, ProtoIndex in ipairs(NativeInfo.NativeFunctionProtoIndices) do
Indices[i] = tostring(ProtoIndex)
end
Lines[#Lines + 1] = "  @native: native-function flags on zero-based proto indices " .. table_concat(Indices, ", ")
if #NativeInfo.NativeFunctionProtoNames > 0 then
local Names = table_create(#NativeInfo.NativeFunctionProtoNames)
for i, Entry in ipairs(NativeInfo.NativeFunctionProtoNames) do
Names[i] = tostring(Entry.ProtoIndex) .. "=" .. Entry.FunctionName
if Entry.NameSource == "fallback" then Names[i] = Names[i] .. " (fallback name)" end
end
Lines[#Lines + 1] = "  @native: reconstructed names by zero-based proto index " .. table_concat(Names, ", ")
end
elseif NativeInfo.HasNativeFunction then
Lines[#Lines + 1] = "  @native: indicated by module metadata; individual proto indices unavailable"
else
Lines[#Lines + 1] = "  @native: no native-function flags detected"
end
if #NativeInfo.NativeColdProtoIndices > 0 then
local Indices = table_create(#NativeInfo.NativeColdProtoIndices)
for i, ProtoIndex in ipairs(NativeInfo.NativeColdProtoIndices) do
Indices[i] = tostring(ProtoIndex)
end
Lines[#Lines + 1] = "  native-cold proto indices: " .. table_concat(Indices, ", ")
else
Lines[#Lines + 1] = "  native-cold proto indices: none detected"
end
if #NativeInfo.InlinableProtoIndices > 0 then
local Indices = table_create(#NativeInfo.InlinableProtoIndices)
for i, ProtoIndex in ipairs(NativeInfo.InlinableProtoIndices) do
Indices[i] = tostring(ProtoIndex)
end
Lines[#Lines + 1] = "  inlinable proto flags (not native): zero-based indices " .. table_concat(Indices, ", ")
end
else
Lines[#Lines + 1] = "  --!native: unknown (native flags are unavailable for this bytecode)"
Lines[#Lines + 1] = "  @native: unknown (native flags are unavailable for this bytecode)"
Lines[#Lines + 1] = "  native-cold proto indices: unknown"
end
for _, Line in ipairs(formatOptimizationLines(OptimizationInfo, EmittedDirective)) do
Lines[#Lines + 1] = Line
end
Lines[#Lines + 1] = "  --!nolint: unknown (lint directives are not serialized in bytecode)"
Lines[#Lines + 1] = "  --!strict/--!nonstrict/--!nocheck: unknown (the original analysis mode is not serialized in bytecode)"
Lines[#Lines + 1] = "]]"
return table_concat(Lines, "\n")
end

local function prependDirectiveMetadata(Source, NativeInfo, OptimizationInfo, Mode)
local Directive = chooseOptimizeDirective(OptimizationInfo, Mode)
local Header = formatDirectiveMetadata(NativeInfo, OptimizationInfo, Directive)
if Directive then Header = Directive .. "\n" .. Header end
if NativeInfo and NativeInfo.IsNativeModule then Header = "--!native\n" .. Header end
return Header .. "\n\n" .. Source
end

function Disassembler.BytecodeToLuau(luauBytecode, appendRawBytecode, Options)
	assert(type(luauBytecode) == "string",
		"Disassembler.BytecodeToLuau: expected string, got " .. type(luauBytecode))
	appendRawBytecode = appendRawBytecode == true
	local OptimizeMode = "exact"
	if type(Options) == "table" and Options.OptimizeDirective ~= nil then
		OptimizeMode = Options.OptimizeDirective
		assert(OptimizeMode == "exact" or OptimizeMode == "always" or OptimizeMode == "best" or OptimizeMode == "never",
			"Disassembler.BytecodeToLuau: Options.OptimizeDirective must be exact, always, best or never")
	end

	local ok, data = pcall(DisassembleCore, luauBytecode, false, true)
	if not ok then
		error("BytecodeToLuau: " .. tostring(data))
	end

	local ok2, decompiled = pcall(DecompilerCore.Decompile, data)
	if not ok2 then
return prependDirectiveMetadata("-- decompilation error: " .. tostring(decompiled), data.NativeInfo, data.OptimizationInfo, OptimizeMode)
	end

decompiled = prependDirectiveMetadata(decompiled, data.NativeInfo, data.OptimizationInfo, OptimizeMode)

	if not appendRawBytecode then
		return decompiled
	end

	local rawDisasm = "-- (appendRawBytecode failed)"
	local ok3, disasmResult = pcall(function()
		return Disassembler.FancyDisassemble(luauBytecode, true, false)
	end)
	if ok3 and type(disasmResult) == "string" then
		rawDisasm = disasmResult
	elseif not ok3 then
		rawDisasm = "-- (appendRawBytecode error: " .. tostring(disasmResult) .. ")"
	end

	local disasmLines = {}
	disasmLines[1] = "\n\n--[[\n========== RAW BYTECODE DISASSEMBLY ==========\n"
	for line in (rawDisasm .. "\n"):gmatch("([^\n]*)\n") do
		disasmLines[#disasmLines + 1] = line
	end
	disasmLines[#disasmLines + 1] = "========== END DISASSEMBLY ==========\n]]"

	return decompiled .. table.concat(disasmLines, "\n")
end

function Disassembler.LuauToMCB(source, options)
	assert(type(source) == "string",
		"Disassembler.LuauToMCB: expected string, got " .. type(source))

	local bytecode = Disassembler.LuauToBytecode(source, options)
	return Disassembler.Assemble(bytecode)
end

function Disassembler.MCBToLuau(machineBytecode, appendRawBytecode, Options)
	assert(type(machineBytecode) == "string",
		"Disassembler.MCBToLuau: expected string, got " .. type(machineBytecode))

	local bytecode = Disassembler.Decode(machineBytecode)
	return Disassembler.BytecodeToLuau(bytecode, appendRawBytecode, Options)
end

return Disassembler
