-- AI was used in this script due to the complexity. It still took 16 hours just to make this script functional. This module is up for free-use.
local Converter={NEX_Version="1.0.0"}
local b32=bit32
local spack, sunpack=string.pack, string.unpack
local b32rshift=b32.rshift
local b32lshift=b32.lshift
local b32band=b32.band
local b32bor=b32.bor
local mfloor=math.floor
local mmin=math.min
local mceil=math.ceil
local mabs=math.abs
local schar=string.char
local sfmt=string.format
local sfind=string.find
local ssub=string.sub
local sbyte=string.byte
local srep=string.rep
local smatch=string.match
local tbconcat=table.concat
local tbcreate=table.create
local tbunpack=table.unpack
local tbinsert=table.insert

local HttpService=game:GetService("HttpService")

local chr=tbcreate(256)
for _i=0, 255 do chr[_i]=schar(_i) end

local function newBlobKey()
	local g=HttpService:GenerateGUID(false):gsub("-","")
	local b=tbcreate(16)
	for i=1,16 do b[i]=schar(tonumber(g:sub(i*2-1,i*2),16)) end
	return tbconcat(b)
end

local function lz4Decompress(src, uncompSize)
	local out=tbcreate(uncompSize + 64, 0)
	local si=1
	local oi=1
	local slen=#src

	while si <=slen do
		local tok=sbyte(src, si); si=si + 1

		local ll=b32rshift(tok, 4)
		if ll==15 then
			local e
			repeat
				e=sbyte(src, si) or 0
				si=si + 1
				ll=ll + e
			until e ~=255
		end
		for _=1, ll do
			out[oi]=sbyte(src, si) or 0
			oi=oi + 1
			si=si + 1
		end

		if si > slen then break end

		local b0=sbyte(src, si) or 0; si=si + 1
		local b1=sbyte(src, si) or 0; si=si + 1
		local offset=b0 + b1 * 256
		if offset==0 then break end

		local ml=b32band(tok, 0xF) + 4
		if b32band(tok, 0xF)==15 then
			local e
			repeat
				e=sbyte(src, si) or 0
				si=si + 1
				ml=ml + e
			until e ~=255
		end

		local ms=oi - offset
		for _=1, ml do
			out[oi]=(ms >=1) and (out[ms] or 0) or 0
			oi=oi + 1
			ms=ms + 1
		end
	end

	local BATCH=200
	local r=tbcreate(mceil((oi-1)/BATCH))
	for i=1, oi-1, BATCH do
		r[#r+1]=schar(tbunpack(out, i, mmin(i+BATCH-1, oi-1)))
	end
	return tbconcat(r)
end

local function lz4Compress(src)
	local n=#src
	if n==0 then return "\x00" end
	local limit=n - 12

	local htBits=16
	while htBits < 20 and b32lshift(1, htBits) < n do htBits +=1 end
	local HTSIZE=b32lshift(1, htBits)
	local htShift=32 - htBits
	local M=2654435761

	local ht=tbcreate(HTSIZE, 0)
	local prev=tbcreate(n + 1, 0)
	local MAX_DEPTH=16

	local out={}
	local oi=1
	local anchor=1
	local ip=1

	while ip <=limit do
		local b0, b1, b2, b3=sbyte(src, ip, ip + 3)
		local lo=b32band((b0 + b1*256) * M, 0xFFFFFFFF)
		local hi=b32band((b2 + b3*256) * M, 0xFFFFFFFF)
		local h=b32rshift(b32band(lo + b32lshift(hi, 16), 0xFFFFFFFF), htShift) + 1

		prev[ip]=ht[h]
		ht[h]=ip

		local best_ml=3
		local best_ref=0
		local maxMl=n - 4 - ip
		local pos=prev[ip]
		local depth=0

		while pos > 0 and depth < MAX_DEPTH do
			if ip - pos > 65535 then break end
			local r0, r1, r2, r3=sbyte(src, pos, pos + 3)
			if r0==b0 and r1==b1 and r2==b2 and r3==b3 then
				local ml=4
				while ml + 8 <=maxMl
				  and ssub(src, ip+ml, ip+ml+7)==ssub(src, pos+ml, pos+ml+7) do
					ml +=8
				end
				while ml < maxMl and sbyte(src, ip+ml)==sbyte(src, pos+ml) do
					ml +=1
				end
				if ml > best_ml then
					best_ml=ml
					best_ref=pos
					if ml >=maxMl then break end
				end
			end
			pos=prev[pos]
			depth +=1
		end

		if best_ref > 0 then
			local ml=best_ml
			local ref=best_ref
			local ll=ip - anchor
			local ml4=ml - 4
			local offset=ip - ref

			out[oi]=schar(mmin(ll,15)*16 + mmin(ml4,15)); oi+=1
			if ll >=15 then
				local r=ll-15
				while r>=255 do out[oi]="\xff"; oi+=1; r-=255 end
				out[oi]=schar(r); oi+=1
			end
			if ll > 0 then out[oi]=ssub(src, anchor, ip-1); oi+=1 end
			out[oi]=schar(offset%256);            oi+=1
			out[oi]=schar(mfloor(offset/256));    oi+=1
			if ml4 >=15 then
				local r=ml4-15
				while r>=255 do out[oi]="\xff"; oi+=1; r-=255 end
				out[oi]=schar(r); oi+=1
			end

			ip=ip + ml
			anchor=ip
		else
			ip +=1
		end
	end

	local ll=n - anchor + 1
	out[oi]=schar(mmin(ll,15)*16); oi+=1
	if ll >=15 then
		local r=ll-15
		while r>=255 do out[oi]="\xff"; oi+=1; r-=255 end
		out[oi]=schar(r); oi+=1
	end
	out[oi]=ssub(src, anchor, n); oi+=1

	return tbconcat(out, "", 1, oi-1)
end

local function zzDec(v)
	return b32band(v, 1)==0 and b32rshift(v, 1) or -(b32rshift(v, 1) + 1)
end
local function zzEnc(v)
	return v >=0 and v * 2 or -v * 2 - 1
end

local function deinterleaveU32(data, n)
	local out=tbcreate(n)
	local bytes={sbyte(data, 1, n*4)}
	for i=1, n do
		out[i]=bytes[i]*0x1000000 + bytes[n+i]*0x10000 + bytes[2*n+i]*0x100 + bytes[3*n+i]
	end
	return out
end

local function interleaveU32(vals)
	local n=#vals
	local out=tbcreate(n*4)
	for i, v in ipairs(vals) do
		local r=(v or 0) % 0x100000000
		out[i]=chr[b32rshift(r,24)]
		out[n+i]=chr[b32band(b32rshift(r,16),255)]
		out[2*n+i]=chr[b32band(b32rshift(r, 8),255)]
		out[3*n+i]=chr[b32band(r,255)]
	end
	return tbconcat(out)
end

local function deinterleaveI32(data, n)
	local out=tbcreate(n)
	local bytes={sbyte(data, 1, n*4)}
	for i=1, n do
		local raw=bytes[i]*0x1000000 + bytes[n+i]*0x10000 + bytes[2*n+i]*0x100 + bytes[3*n+i]
		out[i]=zzDec(raw)
	end
	return out
end

local function interleaveI32(vals)
	local n=#vals
	local out=tbcreate(n*4)
	for i, v in ipairs(vals) do
		local r=zzEnc(v) % 0x100000000
		out[i]=chr[b32rshift(r,24)]
		out[n+i]=chr[b32band(b32rshift(r,16),255)]
		out[2*n+i]=chr[b32band(b32rshift(r, 8),255)]
		out[3*n+i]=chr[b32band(r,255)]
	end
	return tbconcat(out)
end

local function deinterleaveRef(data, n)
	local out=tbcreate(n)
	local bytes={sbyte(data, 1, n*4)}
	local acc=0
	for i=1, n do
		local raw=bytes[i]*0x1000000 + bytes[n+i]*0x10000 + bytes[2*n+i]*0x100 + bytes[3*n+i]
		acc +=zzDec(raw)
		out[i]=acc
	end
	return out
end

local deinterleaveParentRef=deinterleaveRef

local function interleaveRef(refs)
	local n=#refs
	local deltas=tbcreate(n)
	local prev=0
	for i, v in ipairs(refs) do deltas[i]=v - prev; prev=v end
	return interleaveI32(deltas)
end

local interleaveParentRef=interleaveRef

local function rotDecode(b0, b1, b2, b3)
	local raw=b0*0x1000000 + b1*0x10000 + b2*0x100 + b3
	local bits=b32bor(b32rshift(raw,1), b32lshift(b32band(raw,1),31))
	return (sunpack(">f", schar(
		b32rshift(bits,24)%256, b32rshift(bits,16)%256,
		b32rshift(bits, 8)%256, bits%256)))
end

local function rotEncode(f)
	local b0,b1,b2,b3=sbyte(spack(">f", f), 1, 4)
	local bits=b0*0x1000000 + b1*0x10000 + b2*0x100 + b3
	local raw=b32bor(b32lshift(bits,1), b32rshift(bits,31)) % 0x100000000
	return schar(b32rshift(raw,24)%256, b32rshift(raw,16)%256,
	             b32rshift(raw, 8)%256, raw%256)
end

local function deinterleaveF32(data, n)
	local out=tbcreate(n)
	local bytes={sbyte(data, 1, n*4)}
	for i=1, n do
		out[i]=rotDecode(bytes[i], bytes[n+i], bytes[n*2+i], bytes[n*3+i])
	end
	return out
end

local function interleaveF32(vals)
	local n=#vals
	local out=tbcreate(n*4)
	for i, v in ipairs(vals) do
		local b0,b1,b2,b3=sbyte(spack(">f", v), 1, 4)
		local bits=b0*0x1000000 + b1*0x10000 + b2*0x100 + b3
		local raw=b32bor(b32lshift(bits,1), b32rshift(bits,31)) % 0x100000000
		out[i]=chr[b32rshift(raw,24)]
		out[n+i]=chr[b32band(b32rshift(raw,16),255)]
		out[2*n+i]=chr[b32band(b32rshift(raw, 8),255)]
		out[3*n+i]=chr[b32band(raw,255)]
	end
	return tbconcat(out)
end

local RBX_MAGIC="<roblox!\x89\xFF\x0D\x0A\x1A\x0A\x00\x00"

local function readChunk(data, pos)
	local name=data:sub(pos, pos+3);  pos +=4
	local compLen,   np1=sunpack("<I4", data, pos); pos=np1
	local uncompLen, np2=sunpack("<I4", data, pos); pos=np2
	local _,         np3=sunpack("<I4", data, pos); pos=np3
	local payload
	if compLen==0 then
		payload=data:sub(pos, pos+uncompLen-1); pos +=uncompLen
	else
		payload=lz4Decompress(data:sub(pos, pos+compLen-1), uncompLen); pos +=compLen
	end
	return name, payload, pos
end

local function makeChunk(name, payload)
	local n=#payload
	local compressed=lz4Compress(payload)
	if #compressed < n then
		return name
			.. spack("<I4", #compressed)
			.. spack("<I4", n)
			.. spack("<I4", 0)
			.. compressed
	end
	return name
		.. spack("<I4", 0)
		.. spack("<I4", n)
		.. spack("<I4", 0)
		.. payload
end

local CF_IDENTITY={1,0,0, 0,1,0, 0,0,1}
local CF_SPECIAL={
	[0x02]={1,0,0,   0,1,0,   0,0,1},
	[0x03]={1,0,0,   0,0,-1,  0,1,0},
	[0x05]={1,0,0,   0,-1,0,  0,0,-1},
	[0x06]={1,0,0,   0,0,1,   0,-1,0},
	[0x07]={0,1,0,   1,0,0,   0,0,-1},
	[0x09]={0,0,1,   1,0,0,   0,1,0},
	[0x0A]={0,-1,0,  1,0,0,   0,0,1},
	[0x0C]={0,0,-1,  1,0,0,   0,-1,0},
	[0x0D]={0,1,0,   0,0,1,   1,0,0},
	[0x0E]={0,0,-1,  0,1,0,   1,0,0},
	[0x10]={0,-1,0,  0,0,-1,  1,0,0},
	[0x11]={0,0,1,   0,-1,0,  1,0,0},
	[0x14]={-1,0,0,  0,1,0,   0,0,-1},
	[0x15]={-1,0,0,  0,0,1,   0,1,0},
	[0x17]={-1,0,0,  0,-1,0,  0,0,1},
	[0x18]={-1,0,0,  0,0,-1,  0,-1,0},
	[0x19]={0,1,0,   -1,0,0,  0,0,1},
	[0x1B]={0,0,-1,  -1,0,0,  0,1,0},
	[0x1C]={0,-1,0,  -1,0,0,  0,0,-1},
	[0x1E]={0,0,1,   -1,0,0,  0,-1,0},
	[0x1F]={0,1,0,   0,0,-1,  -1,0,0},
	[0x20]={0,0,1,   0,1,0,   -1,0,0},
	[0x22]={0,-1,0,  0,0,1,   -1,0,0},
	[0x23]={0,0,-1,  0,-1,0,  -1,0,0},
}

local function findCFSpecial(r)
	for id, sr in pairs(CF_SPECIAL) do
		local ok=true
		for j=1, 9 do
			if mabs((r[j] or 0) - sr[j]) > 1e-4 then ok=false; break end
		end
		if ok then return id end
	end
	return nil
end

local function xmlUnescape(s)
	return (s:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">")
	         :gsub("&quot;",'"'):gsub("&apos;","'"))
end
local function xmlEscape(s)
	return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"))
end

local function safeF(v)
	if type(v) ~="number" or v ~=v or mabs(v)==math.huge then
		return "0"
	end
	return sfmt("%.9g", v)
end

local PropType={}

PropType[0x01]={
	name="String",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=data:sub(p,p+len-1);p+=len
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<I4",#v)..v end
		return tbconcat(parts)
	end,
	xmlTag="string",
	readXml=function(s) return s end,
	writeXml=function(v) return tostring(v) end,
}

PropType[0x02]={
	name="Bool",
	readBin=function(data,n)
		local out={}; for i=1,n do out[i]=sbyte(data,i)~=0 end; return out
	end,
	writeBin=function(vals)
		local r={}; for i,v in ipairs(vals) do r[i]=schar(v and 1 or 0) end
		return tbconcat(r)
	end,
	xmlTag="bool",
	readXml=function(s) return s=="true" end,
	writeXml=function(v) return v and "true" or "false" end,
}

PropType[0x03]={
	name="Int",
	readBin=function(data,n) return deinterleaveI32(data,n) end,
	writeBin=function(vals)  return interleaveI32(vals) end,
	xmlTag="int",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return tostring(mfloor(v or 0)) end,
}

PropType[0x04]={
	name="Float",
	readBin=function(data,n) return deinterleaveF32(data,n) end,
	writeBin=function(vals)  return interleaveF32(vals) end,
	xmlTag="float",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return safeF(v) end,
}

PropType[0x05]={
	name="Double",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do out[i],p=sunpack("<d",data,p) end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<d",v) end
		return tbconcat(parts)
	end,
	xmlTag="double",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return sfmt("%.17g",v) end,
}

PropType[0x06]={
	name="UDim",
	readBin=function(data,n)
		local sc=deinterleaveF32(data:sub(1,n*4),n)
		local of=deinterleaveI32(data:sub(n*4+1),n)
		local out={}; for i=1,n do out[i]={scale=sc[i],offset=of[i]} end; return out
	end,
	writeBin=function(vals)
		local sc,of={},{}
		for i,v in ipairs(vals) do sc[i]=v.scale;of[i]=v.offset end
		return interleaveF32(sc)..interleaveI32(of)
	end,
	xmlTag="UDim",
	readXml=function(_,sub)
		return {scale=tonumber(sub.S or"0"),offset=tonumber(sub.O or"0")}
	end,
	writeXml=function(v) return ("<S>%g</S><O>%d</O>"):format(v.scale,v.offset) end,
}

PropType[0x07]={
	name="UDim2",
	readBin=function(data,n)
		local xs=deinterleaveF32(data:sub(1,n*4),n)
		local ys=deinterleaveF32(data:sub(n*4+1,n*8),n)
		local xo=deinterleaveI32(data:sub(n*8+1,n*12),n)
		local yo=deinterleaveI32(data:sub(n*12+1),n)
		local out={}
		for i=1,n do out[i]={xScale=xs[i],yScale=ys[i],xOffset=xo[i],yOffset=yo[i]} end
		return out
	end,
	writeBin=function(vals)
		local xs,ys,xo,yo={},{},{},{}
		for i,v in ipairs(vals) do xs[i]=v.xScale;ys[i]=v.yScale;xo[i]=v.xOffset;yo[i]=v.yOffset end
		return interleaveF32(xs)..interleaveF32(ys)..interleaveI32(xo)..interleaveI32(yo)
	end,
	xmlTag="UDim2",
	readXml=function(_,sub)
		return {xScale=tonumber(sub.XS or"0"),xOffset=tonumber(sub.XO or"0"),
		        yScale=tonumber(sub.YS or"0"),yOffset=tonumber(sub.YO or"0")}
	end,
	writeXml=function(v)
		return ("<XS>%g</XS><XO>%d</XO><YS>%g</YS><YO>%d</YO>"):format(
			v.xScale,v.xOffset,v.yScale,v.yOffset)
	end,
}

PropType[0x08]={
	name="Ray",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local ox,oy,oz,dx,dy,dz
			ox,p=sunpack("<f",data,p);oy,p=sunpack("<f",data,p);oz,p=sunpack("<f",data,p)
			dx,p=sunpack("<f",data,p);dy,p=sunpack("<f",data,p);dz,p=sunpack("<f",data,p)
			out[i]={ox=ox,oy=oy,oz=oz,dx=dx,dy=dy,dz=dz}
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do
			parts[#parts+1]=spack("<ffffff",v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)
		end; return tbconcat(parts)
	end,
	xmlTag="Ray",
	readXml=function(_,sub)
		local o=type(sub.origin)=="table"    and sub.origin    or {}
		local d=type(sub.direction)=="table" and sub.direction or {}
		return {ox=tonumber(o.X or"0"),oy=tonumber(o.Y or"0"),oz=tonumber(o.Z or"0"),
		        dx=tonumber(d.X or"0"),dy=tonumber(d.Y or"0"),dz=tonumber(d.Z or"0")}
	end,
	writeXml=function(v)
		return ("<origin><X>%g</X><Y>%g</Y><Z>%g</Z></origin>"
		       .."<direction><X>%g</X><Y>%g</Y><Z>%g</Z></direction>"):format(
			v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)
	end,
}

PropType[0x09]={
	name="Faces",
	readBin=function(data,n) local out={}; for i=1,n do out[i]=sbyte(data,i) end; return out end,
	writeBin=function(vals)
		local r={}; for i,v in ipairs(vals) do r[i]=schar((v or 0)%256) end; return tbconcat(r)
	end,
	xmlTag="Faces",
	readXml=function(_,sub)
		local v=0
		if sub.Right=="true"  then v+=1  end; if sub.Top=="true"    then v+=2  end
		if sub.Back=="true"   then v+=4  end; if sub.Left=="true"   then v+=8  end
		if sub.Bottom=="true" then v+=16 end; if sub.Front=="true"  then v+=32 end
		return v
	end,
	writeXml=function(v)
		local function b(m) return b32band(v,m)~=0 and "true" or "false" end
		return ("<Right>%s</Right><Top>%s</Top><Back>%s</Back>"
		       .."<Left>%s</Left><Bottom>%s</Bottom><Front>%s</Front>"):format(
			b(1),b(2),b(4),b(8),b(16),b(32))
	end,
}

PropType[0x0A]={
	name="Axes",
	readBin=function(data,n) local out={}; for i=1,n do out[i]=sbyte(data,i) end; return out end,
	writeBin=function(vals)
		local r={}; for i,v in ipairs(vals) do r[i]=schar((v or 0)%256) end; return tbconcat(r)
	end,
	xmlTag="Axes",
	readXml=function(_,sub)
		local v=0
		if sub.X=="true" then v+=4 end
		if sub.Y=="true" then v+=2 end
		if sub.Z=="true" then v+=1 end
		return v
	end,
	writeXml=function(v)
		local function b(m) return b32band(v,m)~=0 and "true" or "false" end
		return ("<X>%s</X><Y>%s</Y><Z>%s</Z>"):format(b(4),b(2),b(1))
	end,
}

PropType[0x0B]={
	name="BrickColor",
	readBin=function(data,n) return deinterleaveU32(data,n) end,
	writeBin=function(vals)  return interleaveU32(vals) end,
	xmlTag="BrickColor",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return tostring(mfloor(v or 0)) end,
}

PropType[0x0C]={
	name="Color3",
	readBin=function(data,n)
		local rs=deinterleaveF32(data:sub(1,n*4),n)
		local gs=deinterleaveF32(data:sub(n*4+1,n*8),n)
		local bs=deinterleaveF32(data:sub(n*8+1),n)
		local out={}; for i=1,n do out[i]={r=rs[i],g=gs[i],b=bs[i]} end; return out
	end,
	writeBin=function(vals)
		local rs,gs,bs={},{},{}
		for i,v in ipairs(vals) do rs[i]=v.r;gs[i]=v.g;bs[i]=v.b end
		return interleaveF32(rs)..interleaveF32(gs)..interleaveF32(bs)
	end,
	xmlTag="Color3",
	readXml=function(s,sub)
		if sub and sub.R then
			return {r=tonumber(sub.R or"0"),g=tonumber(sub.G or"0"),b=tonumber(sub.B or"0")}
		end
		local packed=tonumber(s) or 0
		return {r=b32band(b32rshift(packed,16),0xFF)/255,
		        g=b32band(b32rshift(packed, 8),0xFF)/255,
		        b=b32band(packed,0xFF)/255}
	end,
	writeXml=function(v) return ("<R>%.9g</R><G>%.9g</G><B>%.9g</B>"):format(v.r,v.g,v.b) end,
}

PropType[0x0D]={
	name="Vector2",
	readBin=function(data,n)
		local xs=deinterleaveF32(data:sub(1,n*4),n)
		local ys=deinterleaveF32(data:sub(n*4+1),n)
		local out={}; for i=1,n do out[i]={x=xs[i],y=ys[i]} end; return out
	end,
	writeBin=function(vals)
		local xs,ys={},{}
		for i,v in ipairs(vals) do xs[i]=v.x;ys[i]=v.y end
		return interleaveF32(xs)..interleaveF32(ys)
	end,
	xmlTag="Vector2",
	readXml=function(_,sub) return {x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0")} end,
	writeXml=function(v) return ("<X>%.9g</X><Y>%.9g</Y>"):format(v.x,v.y) end,
}

PropType[0x0E]={
	name="Vector3",
	readBin=function(data,n)
		local xs=deinterleaveF32(data:sub(1,n*4),n)
		local ys=deinterleaveF32(data:sub(n*4+1,n*8),n)
		local zs=deinterleaveF32(data:sub(n*8+1),n)
		local out={}; for i=1,n do out[i]={x=xs[i],y=ys[i],z=zs[i]} end; return out
	end,
	writeBin=function(vals)
		local xs,ys,zs={},{},{}
		for i,v in ipairs(vals) do xs[i]=v.x;ys[i]=v.y;zs[i]=v.z end
		return interleaveF32(xs)..interleaveF32(ys)..interleaveF32(zs)
	end,
	xmlTag="Vector3",
	readXml=function(_,sub)
		return {x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0")}
	end,
	writeXml=function(v) return ("<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>") end,
}

PropType[0x10]={
	name="CFrame",
	readBin=function(data,n)
		local p=1
		local rotations={}
		for i=1,n do
			local spec=sbyte(data,p); p+=1
			if spec==0 then
				local r={}
				for j=1,9 do r[j],p=sunpack("<f",data,p) end
				rotations[i]=r
			else
				rotations[i]=CF_SPECIAL[spec] or CF_IDENTITY
			end
		end
		local posData=data:sub(p)
		local xs=deinterleaveF32(posData:sub(1,n*4),n)
		local ys=deinterleaveF32(posData:sub(n*4+1,n*8),n)
		local zs=deinterleaveF32(posData:sub(n*8+1),n)
		local out={}
		for i=1,n do out[i]={r=rotations[i],x=xs[i],y=ys[i],z=zs[i]} end
		return out
	end,
	writeBin=function(vals)
		local perInst={}
		local xs,ys,zs={},{},{}
		for i,v in ipairs(vals) do
			local r=v.r or CF_IDENTITY
			local specId=findCFSpecial(r)
			if specId then
				perInst[i]=schar(specId)
			else
				local rParts={"\x00"}
				for j=1,9 do rParts[#rParts+1]=spack("<f",r[j] or 0) end
				perInst[i]=tbconcat(rParts)
			end
			xs[i]=v.x or 0; ys[i]=v.y or 0; zs[i]=v.z or 0
		end
		return tbconcat(perInst)
		       ..interleaveF32(xs)..interleaveF32(ys)..interleaveF32(zs)
	end,
	xmlTag="CoordinateFrame",
	readXml=function(_,sub)
		return {
			x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0"),
			r={
				tonumber(sub.R00 or"1"),tonumber(sub.R01 or"0"),tonumber(sub.R02 or"0"),
				tonumber(sub.R10 or"0"),tonumber(sub.R11 or"1"),tonumber(sub.R12 or"0"),
				tonumber(sub.R20 or"0"),tonumber(sub.R21 or"0"),tonumber(sub.R22 or"1"),
			}
		}
	end,
	writeXml=function(v)
		local r=v.r or CF_IDENTITY
		return ("<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>"
		       .."<R00>"..safeF(r[1]).."</R00><R01>"..safeF(r[2]).."</R01><R02>"..safeF(r[3]).."</R02>"
		       .."<R10>"..safeF(r[4]).."</R10><R11>"..safeF(r[5]).."</R11><R12>"..safeF(r[6]).."</R12>"
		       .."<R20>"..safeF(r[7]).."</R20><R21>"..safeF(r[8]).."</R21><R22>"..safeF(r[9]).."</R22>")
	end,
}

PropType[0x12]={
	name="Enum",
	readBin=function(data,n) return deinterleaveU32(data,n) end,
	writeBin=function(vals)  return interleaveU32(vals) end,
	xmlTag="token",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return tostring(mfloor(v or 0)) end,
}

PropType[0x13]={
	name="Referent",
	readBin=function(data,n) return deinterleaveRef(data,n) end,
	writeBin=function(vals)  return interleaveRef(vals) end,
	xmlTag="Ref",
	readXml=function(s)
		if not s or s=="null" or s=="" then return -1 end
		local hex=s:match("^RBX(%x+)$")
		if hex then return tonumber(hex,16) end
		return tonumber(s) or -1
	end,
	writeXml=function(v) return (not v or v==-1 or v<0) and "null" or ("RBX"..sfmt("%08X",v)) end,
}

PropType[0x14]={
	name="Vector3int16",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local x,y,z
			x,p=sunpack("<i2",data,p);y,p=sunpack("<i2",data,p);z,p=sunpack("<i2",data,p)
			out[i]={x=x,y=y,z=z}
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<i2i2i2",v.x or 0,v.y or 0,v.z or 0) end
		return tbconcat(parts)
	end,
	xmlTag="Vector3int16",
	readXml=function(_,sub)
		return {x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0")}
	end,
	writeXml=function(v) return ("<X>%d</X><Y>%d</Y><Z>%d</Z>"):format(v.x,v.y,v.z) end,
}

PropType[0x15]={
	name="NumberSequence",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local count,np=sunpack("<I4",data,p);p=np
			local kps={}
			for j=1,count do
				local t,v,e
				t,p=sunpack("<f",data,p);v,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)
				kps[j]={t=t,v=v,e=e}
			end
			out[i]=kps
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,kps in ipairs(vals) do
			parts[#parts+1]=spack("<I4",#kps)
			for _,kp in ipairs(kps) do parts[#parts+1]=spack("<fff",kp.t,kp.v,kp.e) end
		end; return tbconcat(parts)
	end,
	xmlTag="NumberSequence",
	readXml=function(s)
		local kps={}
		for t,v,e in (s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+") do
			kps[#kps+1]={t=tonumber(t),v=tonumber(v),e=tonumber(e)}
		end; return kps
	end,
	writeXml=function(v)
		local parts={}
		for _,kp in ipairs(v) do parts[#parts+1]=sfmt("%g %g %g ",kp.t,kp.v,kp.e) end
		return tbconcat(parts)
	end,
}

PropType[0x16]={
	name="ColorSequence",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local count,np=sunpack("<I4",data,p);p=np
			local kps={}
			for j=1,count do
				local t,r,g,bb,e
				t,p=sunpack("<f",data,p);r,p=sunpack("<f",data,p)
				g,p=sunpack("<f",data,p);bb,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)
				kps[j]={t=t,r=r,g=g,b=bb,e=e}
			end
			out[i]=kps
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,kps in ipairs(vals) do
			parts[#parts+1]=spack("<I4",#kps)
			for _,kp in ipairs(kps) do parts[#parts+1]=spack("<fffff",kp.t,kp.r,kp.g,kp.b,kp.e) end
		end; return tbconcat(parts)
	end,
	xmlTag="ColorSequence",
	readXml=function(s)
		local kps={}
		for t,r,g,b,e in (s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+") do
			kps[#kps+1]={t=tonumber(t),r=tonumber(r),g=tonumber(g),b=tonumber(b),e=tonumber(e)}
		end; return kps
	end,
	writeXml=function(v)
		local parts={}
		for _,kp in ipairs(v) do parts[#parts+1]=sfmt("%g %g %g %g %g ",kp.t,kp.r,kp.g,kp.b,kp.e) end
		return tbconcat(parts)
	end,
}

PropType[0x17]={
	name="NumberRange",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local mn,mx;mn,p=sunpack("<f",data,p);mx,p=sunpack("<f",data,p)
			out[i]={min=mn,max=mx}
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<ff",v.min,v.max) end
		return tbconcat(parts)
	end,
	xmlTag="NumberRange",
	readXml=function(s)
		local a,b=s:match("(%S+)%s+(%S+)")
		return {min=tonumber(a or"0"),max=tonumber(b or"1")}
	end,
	writeXml=function(v) return sfmt("%g %g ",v.min,v.max) end,
}

PropType[0x18]={
	name="Rect",
	readBin=function(data,n)
		local mnx=deinterleaveF32(data:sub(1,n*4),n)
		local mny=deinterleaveF32(data:sub(n*4+1,n*8),n)
		local mxx=deinterleaveF32(data:sub(n*8+1,n*12),n)
		local mxy=deinterleaveF32(data:sub(n*12+1),n)
		local out={}
		for i=1,n do out[i]={minX=mnx[i],minY=mny[i],maxX=mxx[i],maxY=mxy[i]} end
		return out
	end,
	writeBin=function(vals)
		local mnx,mny,mxx,mxy={},{},{},{}
		for i,v in ipairs(vals) do mnx[i]=v.minX;mny[i]=v.minY;mxx[i]=v.maxX;mxy[i]=v.maxY end
		return interleaveF32(mnx)..interleaveF32(mny)..interleaveF32(mxx)..interleaveF32(mxy)
	end,
	xmlTag="Rect2D",
	readXml=function(_,sub)
		local mn=type(sub.min)=="table" and sub.min or {}
		local mx=type(sub.max)=="table" and sub.max or {}
		return {minX=tonumber(mn.X or"0"),minY=tonumber(mn.Y or"0"),
		        maxX=tonumber(mx.X or"0"),maxY=tonumber(mx.Y or"0")}
	end,
	writeXml=function(v)
		return ("<min><X>%g</X><Y>%g</Y></min><max><X>%g</X><Y>%g</Y></max>"):format(
			v.minX,v.minY,v.maxX,v.maxY)
	end,
}

PropType[0x19]={
	name="PhysicalProperties",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local custom=sbyte(data,p)~=0;p+=1
			if custom then
				local d,f,e,fw,ew
				d,p=sunpack("<f",data,p);f,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)
				fw,p=sunpack("<f",data,p);ew,p=sunpack("<f",data,p)
				out[i]={custom=true,density=d,friction=f,elasticity=e,frictionWeight=fw,elasticityWeight=ew}
			else
				out[i]={custom=false}
			end
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do
			if v.custom then
				parts[#parts+1]="\x01"..spack("<fffff",v.density,v.friction,v.elasticity,v.frictionWeight,v.elasticityWeight)
			else
				parts[#parts+1]="\x00"
			end
		end; return tbconcat(parts)
	end,
	xmlTag="PhysicalProperties",
	readXml=function(_,sub)
		if sub.CustomPhysics=="true" then
			return {custom=true,density=tonumber(sub.Density or"0"),friction=tonumber(sub.Friction or"0"),
			        elasticity=tonumber(sub.Elasticity or"0"),frictionWeight=tonumber(sub.FrictionWeight or"0"),
			        elasticityWeight=tonumber(sub.ElasticityWeight or"0")}
		end
		return {custom=false}
	end,
	writeXml=function(v)
		if v.custom then
			return ("<CustomPhysics>true</CustomPhysics><Density>%g</Density>"
			       .."<Friction>%g</Friction><Elasticity>%g</Elasticity>"
			       .."<FrictionWeight>%g</FrictionWeight><ElasticityWeight>%g</ElasticityWeight>"):format(
				v.density,v.friction,v.elasticity,v.frictionWeight,v.elasticityWeight)
		end
		return "<CustomPhysics>false</CustomPhysics>"
	end,
}

PropType[0x1A]={
	name="Color3uint8",
	readBin=function(data,n)
		local out={}
		for i=1,n do out[i]={r=sbyte(data,i),g=sbyte(data,n+i),b=sbyte(data,n*2+i)} end
		return out
	end,
	writeBin=function(vals)
		local rs,gs,bs={},{},{}
		for i,v in ipairs(vals) do
			rs[i]=schar(v.r%256);gs[i]=schar(v.g%256);bs[i]=schar(v.b%256)
		end
		return tbconcat(rs)..tbconcat(gs)..tbconcat(bs)
	end,
	xmlTag="Color3uint8",
	readXml=function(_,sub)
		return {r=tonumber(sub.R or"0"),g=tonumber(sub.G or"0"),b=tonumber(sub.B or"0")}
	end,
	writeXml=function(v) return ("<R>%d</R><G>%d</G><B>%d</B>"):format(v.r,v.g,v.b) end,
}

PropType[0x1B]={
	name="Int64",
	readBin=function(data,n)
		local out={}
		for i=1,n do
			local hi=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000
			         +sbyte(data,n*2+i)*0x100+sbyte(data,n*3+i)
			local lo=sbyte(data,n*4+i)*0x1000000+sbyte(data,n*5+i)*0x10000
			         +sbyte(data,n*6+i)*0x100+sbyte(data,n*7+i)
			local combined=hi*0x100000000+lo
			if b32band(lo,1)==0 then out[i]=mfloor(combined/2)
			else out[i]=-mfloor((combined+1)/2) end
		end; return out
	end,
	writeBin=function(vals)
		local n=#vals
		local by={}; for k=0,7 do by[k]=tbcreate(n) end
		for i,v in ipairs(vals) do
			local raw=v>=0 and v*2 or -v*2-1
			local lo=raw%0x100000000
			local hi=mfloor(raw/0x100000000)
			by[0][i]=schar(b32rshift(hi,24)%256);by[1][i]=schar(b32rshift(hi,16)%256)
			by[2][i]=schar(b32rshift(hi, 8)%256);by[3][i]=schar(hi%256)
			by[4][i]=schar(b32rshift(lo,24)%256);by[5][i]=schar(b32rshift(lo,16)%256)
			by[6][i]=schar(b32rshift(lo, 8)%256);by[7][i]=schar(lo%256)
		end
		local parts={}; for k=0,7 do parts[#parts+1]=tbconcat(by[k]) end
		return tbconcat(parts)
	end,
	xmlTag="int64",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return tostring(mfloor(v or 0)) end,
}

PropType[0x1C]={
	name="SharedString",
	readBin=function(data,n) return deinterleaveU32(data,n) end,
	writeBin=function(vals)  return interleaveU32(vals) end,
	xmlTag="SharedString",
	readXml=function(s) return s or "" end,
	writeXml=function(v) return v or "" end,
}

local b64chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64enc={}
for i=0, 63 do b64enc[i]=b64chars:sub(i+1,i+1) end
local b64dec={}
for i=0, 63 do b64dec[sbyte(b64chars, i+1)]=i end

local function base64Encode(s)
	local out={}
	local n=#s
	for i=1, n, 3 do
		local a, b, c=sbyte(s, i, i+2)
		a=a or 0; b=b or 0; c=c or 0
		local v=a*65536 + b*256 + c
		out[#out+1]=b64enc[b32rshift(v,18)]
		out[#out+1]=b64enc[b32band(b32rshift(v,12),63)]
		out[#out+1]=i+1<=n and b64enc[b32band(b32rshift(v,6),63)] or "="
		out[#out+1]=i+2<=n and b64enc[b32band(v,63)]               or "="
	end
	return tbconcat(out)
end

local function base64Decode(s)
	s=s:gsub("[^A-Za-z0-9+/=]","")
	local out={}
	local i=1
	local slen=#s
	while i <=slen do
		local ba, bb, bc, bd=sbyte(s, i, i+3)
		local a=b64dec[ba] or 0
		local b=b64dec[bb] or 0
		local c=b64dec[bc] or 0
		local d=b64dec[bd] or 0
		i +=4
		local v=a*262144 + b*4096 + c*64 + d
		out[#out+1]=schar(b32rshift(v,16))
		if bc ~=61 then out[#out+1]=schar(b32band(b32rshift(v,8),255)) end
		if bd ~=61 then out[#out+1]=schar(b32band(v,255)) end
	end
	return tbconcat(out)
end

PropType[0x1E]={
	name="OptionalCFrame",
	readBin=function(data,n)
		local p=2

		local specs=tbcreate(n)
		local rots=tbcreate(n)
		for i=1, n do
			local s=sbyte(data,p) or 0;  p +=1
			specs[i]=s
			if s==0 then
				local r={sunpack("<9f", data, p)}
				table.remove(r, #r)
				p +=36
				rots[i]=r
			else
				rots[i]=CF_SPECIAL[s] or CF_IDENTITY
			end
		end

		local xs=deinterleaveF32(data:sub(p, p+n*4-1), n); p +=n*4
		local ys=deinterleaveF32(data:sub(p, p+n*4-1), n); p +=n*4
		local zs=deinterleaveF32(data:sub(p, p+n*4-1), n); p +=n*4

		p +=1
		local present=tbcreate(n)
		for i=1, n do present[i]=(sbyte(data, p+i-1) or 0) ~=0 end

		local out=tbcreate(n)
		for i=1, n do
			if present[i] then
				out[i]={r=rots[i], x=xs[i], y=ys[i], z=zs[i]}
			else
				out[i]=nil
			end
		end
		return out
	end,
	writeBin=function(vals)
		local n=#vals
		local boolBytes=tbcreate(n)
		local cfParts={}
		local xs=tbcreate(n); local ys=tbcreate(n); local zs=tbcreate(n)
		for i=1, n do
			local v=vals[i]
			local cf=v or {r=CF_IDENTITY, x=0, y=0, z=0}
			boolBytes[i]=schar(v and 1 or 0)
			local r=cf.r or CF_IDENTITY
			local specId=findCFSpecial(r)
			if specId then
				cfParts[#cfParts+1]=schar(specId)
			else
				cfParts[#cfParts+1]="\x00"
				for j=1, 9 do cfParts[#cfParts+1]=spack("<f", r[j] or 0) end
			end
			xs[i]=cf.x or 0;  ys[i]=cf.y or 0;  zs[i]=cf.z or 0
		end
		return "\x10"
		       .. tbconcat(cfParts)
		       .. interleaveF32(xs) .. interleaveF32(ys) .. interleaveF32(zs)
		       .. "\x02"
		       .. tbconcat(boolBytes)
	end,
	xmlTag="OptionalCoordinateFrame",
	readXml=function(_,sub)
		if not sub or not sub.CFrame then return nil end
		local cf=sub.CFrame
		local function v(k) return tonumber(type(cf)=="table" and cf[k] or nil) or 0 end
		return {r={v"R00",v"R01",v"R02", v"R10",v"R11",v"R12", v"R20",v"R21",v"R22"},
		        x=v"X", y=v"Y", z=v"Z"}
	end,
	writeXml=function(v)
		if not v then return "" end
		local r=v.r or CF_IDENTITY
		return ("<CFrame>"
		       .."<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>"
		       .."<R00>"..safeF(r[1]).."</R00><R01>"..safeF(r[2]).."</R01><R02>"..safeF(r[3]).."</R02>"
		       .."<R10>"..safeF(r[4]).."</R10><R11>"..safeF(r[5]).."</R11><R12>"..safeF(r[6]).."</R12>"
		       .."<R20>"..safeF(r[7]).."</R20><R21>"..safeF(r[8]).."</R21><R22>"..safeF(r[9]).."</R22>"
		       .."</CFrame>")
	end,
}

PropType[0x1F]={
	name="ProtectedString",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=data:sub(p,p+len-1);p+=len
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<I4",#v)..v end
		return tbconcat(parts)
	end,
	xmlTag="ProtectedString",
	readXml=function(s) return s or "" end,
	writeXml=function(v) return tostring(v or "") end,
}

PropType[0x20]={
	name="Font",
	readBin=function(data,n)
		local out={}; local p=1
		for i=1,n do
			local flen,np=sunpack("<I4",data,p);p=np
			local family=data:sub(p,p+flen-1);p+=flen
			local weight,np2=sunpack("<I2",data,p);p=np2
			local style=sbyte(data,p);p+=1
			local clen,np3=sunpack("<I4",data,p);p=np3
			local cached=data:sub(p,p+clen-1);p+=clen
			out[i]={family=family,weight=weight,style=style,cachedFaceId=cached}
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do
			local fam=v.family or ""
			local cac=v.cachedFaceId or ""
			parts[#parts+1]=spack("<I4",#fam)..fam
			                ..spack("<I2",v.weight or 400)
			                ..schar(v.style or 0)
			                ..spack("<I4",#cac)..cac
		end; return tbconcat(parts)
	end,
	xmlTag="Font",
	readXml=function(_,sub)
		local famSub=type(sub.Family)=="table" and sub.Family or {}
		local family=type(famSub.url)=="string" and famSub.url or (type(sub.Family)=="string" and sub.Family or "")
		local weightMap={Thin=100,ExtraLight=200,Light=300,Regular=400,Medium=500,
		                 SemiBold=600,Bold=700,ExtraBold=800,Heavy=900}
		local styleMap={Normal=0,Italic=2}
		local w=tonumber(sub.Weight) or weightMap[sub.Weight or ""] or 400
		local st=styleMap[sub.Style or "Normal"] or 0
		return {family=family,weight=w,style=st,cachedFaceId=""}
	end,
	writeXml=function(v)
		local styleNames={[0]="Normal",[2]="Italic"}
		local s=styleNames[v.style or 0] or "Normal"
		return ("<Family><url>"..xmlEscape(v.family or "").."</url></Family>"
		       .."<Weight>"..tostring(v.weight or 400).."</Weight>"
		       .."<Style>"..s.."</Style>")
	end,
}

PropType[0x21]={
	name="SecurityCapabilities",
	readBin=function(data,n)
		local out={}; local p=1
		for i=1,n do
			local lo,hi
			lo,p=sunpack("<I4",data,p); hi,p=sunpack("<I4",data,p)
			out[i]=lo + hi*0x100000000
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do
			v=v or 0
			local lo=v%0x100000000
			local hi=mfloor(v/0x100000000)%0x100000000
			parts[#parts+1]=spack("<I4",lo)..spack("<I4",hi)
		end; return tbconcat(parts)
	end,
	xmlTag="SecurityCapabilities",
	readXml=function(s) return tonumber(s) or 0 end,
	writeXml=function(v) return tostring(mfloor(v or 0)) end,
}

local function getType(id)
	if PropType[id] then return PropType[id] end
	return {
		name="Unknown("..sfmt("0x%02X",id)..")",
		readBin=function() return {} end,
		writeBin=function() return "" end,
		xmlTag="BinaryString",
		readXml=function(s) return s end,
		writeXml=function(v) return tostring(v or "") end,
	}
end

local CONTENT_PROPS={
	SoundId=true,
	Image=true, HoverImage=true, PressedImage=true,
	Texture=true,
	LinkedSource=true,
	MeshId=true, TextureId=true, TextureID=true,
	SkyboxBk=true, SkyboxDn=true, SkyboxFt=true,
	SkyboxLf=true, SkyboxRt=true, SkyboxUp=true,
	AnimationId=true,
	ShirtTemplate=true, PantsTemplate=true,
	ContentId=true, GraphicId=true,
	OverlayTextureId=true, BaseTextureId=true, NormalMap=true,
	VideoSource=true,
}

local BINARY_STRING_PROPS={
	AttributesSerialize=true,
	Tags=true,
	PhysicsData=true,
	PhysicsGrid=true,
	LevelOfDetailData=true,
	TerrainColors=true,
	TerrainMaterialColors=true,
	SmoothGrid=true,
	ClusterGrid=true,
}

local function parseBinary(data)
	assert(data:sub(1,16)==RBX_MAGIC, "Not a valid .rbxm binary file")
	local pos=17
	local _,np2=sunpack("<I4",data,pos);pos=np2
	local _,np3=sunpack("<I4",data,pos);pos=np3
	pos+=8

	local typeMap={};local instMap={};local sharedStrs={};local roots={}

	while pos <=#data do
		if pos + 15 > #data then break end

		local chunkName=data:sub(pos, pos+3);          pos=pos + 4
		local cLen=sunpack("<I4", data, pos);     pos=pos + 4
		local uLen=sunpack("<I4", data, pos);     pos=pos + 4
		pos=pos + 4

		if type(cLen)~="number" or type(uLen)~="number" or cLen<0 or uLen<0
		   or cLen > #data or uLen > #data * 8 then
			break
		end

		if chunkName:sub(1,3)=="END" then break end

		local payload=nil

		if cLen==0 then
			if pos + uLen - 1 <=#data then
				payload=data:sub(pos, pos + uLen - 1)
			end
			pos=mmin(pos + uLen, #data + 1)
		else
			if pos + cLen - 1 <=#data then
				local ok_lz4, result=pcall(lz4Decompress, data:sub(pos, pos+cLen-1), uLen)
				if ok_lz4 then
					payload=result
				end
			end
			pos=mmin(pos + cLen, #data + 1)
		end

		if payload ~=nil then

		if chunkName=="META" then

		elseif chunkName=="SSTR" then
			pcall(function()
				local sp=1
				local _,np=sunpack("<I4",payload,sp);sp=np
				local count,np2=sunpack("<I4",payload,sp);sp=np2
				for i=1,count do
					sp+=16
					local s,np3=sunpack("<s4",payload,sp);sp=np3
					sharedStrs[i-1]=s
				end
			end)

		elseif chunkName=="INST" then
			pcall(function()
				local sp=1
				local typeIdx,np1=sunpack("<I4",payload,sp);sp=np1
				local cnLen,  np2=sunpack("<I4",payload,sp);sp=np2
				local className=payload:sub(sp,sp+cnLen-1);sp+=cnLen
				local isService=sbyte(payload,sp)~=0;sp+=1
				local count,np3=sunpack("<I4",payload,sp);sp=np3
				local refs=deinterleaveRef(payload:sub(sp,sp+count*4-1),count);sp+=count*4
				if isService then sp+=count end

				typeMap[typeIdx]={className=className,count=count,referents=refs}
				for _,ref in ipairs(refs) do
					instMap[ref]={referent=ref,className=className,isService=isService,
					              properties={},children={},parent=nil}
				end
			end)

		elseif chunkName=="PROP" then
			pcall(function()
				local sp=1
				local typeIdx,np1=sunpack("<I4",payload,sp);sp=np1
				local pnLen,  np2=sunpack("<I4",payload,sp);sp=np2
				local propName=payload:sub(sp,sp+pnLen-1);sp+=pnLen
				local typeId=sbyte(payload,sp);sp+=1
				if typeId==0x01 and CONTENT_PROPS[propName] then typeId=0x22 end
				if typeId==0x01 and BINARY_STRING_PROPS[propName] then typeId=0x1E2 end
				local ti=typeMap[typeIdx]
				if ti then
					local typeInfo=getType(typeId)
					local ok2,values=pcall(typeInfo.readBin,payload:sub(sp),ti.count)
					if ok2 then
						for i,ref in ipairs(ti.referents) do
							local inst=instMap[ref]
							if inst and values[i]~=nil then
								inst.properties[propName]={typeId=typeId,value=values[i]}
							end
						end
					end
				end
			end)

		elseif chunkName=="PRNT" then
			pcall(function()
				local sp=2
				local count,np=sunpack("<I4",payload,sp);sp=np
				local childRefs=deinterleaveRef(payload:sub(sp,         sp+count*4-1),count)
				local parentRefs=deinterleaveParentRef(payload:sub(sp+count*4, sp+count*8-1),count)
				for i=1,count do
					local child=instMap[childRefs[i]]
					local parent=instMap[parentRefs[i]]
					if child then
						child.parent=parent
						if parent then parent.children[#parent.children+1]=child
						else           roots[#roots+1]=child end
					end
				end
			end)

		end
		end
	end

	if #roots==0 and next(instMap) then
		for _, inst in pairs(instMap) do
			if inst.parent==nil then
				roots[#roots+1]=inst
			end
		end
	end

	if #roots==0 and next(instMap) then
		local isChild={}
		for _, inst in pairs(instMap) do
			for _, child in ipairs(inst.children) do
				isChild[child.referent]=true
			end
		end
		for _, inst in pairs(instMap) do
			if not isChild[inst.referent] then
				roots[#roots+1]=inst
			end
		end
	end

	if #roots==0 and next(instMap) then
		for _, inst in pairs(instMap) do
			inst.children={}
			roots[#roots+1]=inst
		end
	end

	return roots,sharedStrs
end

local function tokenize(xml)
	local tokens={}
	local pos=1
	local n=#xml

	while pos <=n do
		local c=sbyte(xml, pos)

		if c ~=60 then
			local e=sfind(xml, "<", pos, true)
			local text=ssub(xml, pos, e and e-1 or n)
			pos=e or n+1
			if sfind(text, "%S") then
				if sfind(text, "&", 1, true) then text=xmlUnescape(text) end
				tokens[#tokens+1]={type="text", text=text}
			end

		else
			local c2=sbyte(xml, pos+1)

			if c2==33 then
				local c3=sbyte(xml, pos+2)
				if c3==45 and sbyte(xml, pos+3)==45 then
					local e=sfind(xml, "-->", pos+4, true)
					pos=e and e+3 or n+1

				elseif c3==91 and ssub(xml, pos, pos+8)=="<![CDATA[" then
					local e=sfind(xml, "]]>", pos+9, true)
					if e then
						tokens[#tokens+1]={type="text", text=ssub(xml, pos+9, e-1)}
						pos=e+3
					else
						pos=n+1
					end

				else
					local e=sfind(xml, ">", pos+2, true)
					pos=e and e+1 or n+1
				end

			elseif c2==63 then
				local e=sfind(xml, "?>", pos+2, true)
				pos=e and e+2 or n+1

			elseif c2==47 then
				local e=sfind(xml, ">", pos+2, true)
				if not e then break end
				local name=ssub(xml, pos+2, e-1):match("^%s*([%w:_%.%-]*)%s*")
				tokens[#tokens+1]={type="close", name=name}
				pos=e+1

			else
				local e=sfind(xml, ">", pos+1, true)
				if not e then break end
				local tag=ssub(xml, pos+1, e-1)
				pos=e+1
				local selfClose=sbyte(tag, #tag)==47
				if selfClose then tag=ssub(tag, 1, -2) end
				local tname=tag:match("^%s*([%w:_%.%-]+)")
				if tname then
					local attrs={}
					for k,v in tag:gmatch('%s+([%w:_%-]+)%s*=%s*"([^"]*)"') do
						attrs[k]=sfind(v,"&",1,true) and xmlUnescape(v) or v
					end
					for k,v in tag:gmatch("%s+([%w:_%-]+)%s*=%s*'([^']*)'") do
						attrs[k]=sfind(v,"&",1,true) and xmlUnescape(v) or v
					end
					tokens[#tokens+1]={type=selfClose and "selfclose" or "open",
					                     name=tname, attrs=attrs}
				end
			end
		end
	end
	return tokens
end

local function parseElement(tokens,ti,closeName)
	local text=""; local sub={}
	while ti<=#tokens do
		local tok=tokens[ti]
		if tok.type=="close" and tok.name==closeName then
			return text:match("^%s*(.-)%s*$"),sub,ti+1
		elseif tok.type=="text" then
			text..=tok.text; ti+=1
		elseif tok.type=="open" then
			local childName=tok.name; ti+=1
			local childText,childSub,newTi=parseElement(tokens,ti,childName)
			ti=newTi
			sub[childName]=next(childSub) and childSub or childText
		elseif tok.type=="selfclose" then
			sub[tok.name]=""; ti+=1
		else ti+=1 end
	end
	return text:match("^%s*(.-)%s*$"),sub,ti
end

local function parseProperties(tokens,ti)
	local props={}
	while ti<=#tokens do
		local tok=tokens[ti]
		if tok.type=="close" and tok.name=="Properties" then
			return props,ti+1
		elseif tok.type=="open" or tok.type=="selfclose" then
			local propTag=tok.name
			local propName=tok.attrs and tok.attrs.name
			if tok.type=="selfclose" then
				if propName then props[propName]={xmlTag=propTag,text="",sub={}} end
				ti+=1
			else
				ti+=1
				local text,sub,newTi=parseElement(tokens,ti,propTag); ti=newTi
				if propName then props[propName]={xmlTag=propTag,text=text,sub=sub} end
			end
		else ti+=1 end
	end
	return props,ti
end

local parseXmlItems
parseXmlItems=function(tokens, ti, refCounter, stopTag)
	stopTag=stopTag or "roblox"
	local nodes={}
	while ti <=#tokens do
		local tok=tokens[ti]

		if tok.type=="close" then
			if tok.name==stopTag then
				return nodes, ti
			else
				ti +=1
			end

		elseif tok.type=="open" and tok.name=="Item" then
			local className=tok.attrs and tok.attrs.class or "Unknown"
			local xmlRef=tok.attrs and tok.attrs.referent or nil
			refCounter[1] +=1
			local ref=refCounter[1]
			local node={referent=ref, className=className, xmlRef=xmlRef,
			              properties={}, children={}, parent=nil}
			ti +=1

			while ti <=#tokens do
				local inner=tokens[ti]
				if inner.type=="close" and inner.name=="Item" then
					ti +=1; break

				elseif inner.type=="open" and inner.name=="Properties" then
					ti +=1
					local props, newTi=parseProperties(tokens, ti)
					ti=newTi
					node.properties=props

				elseif inner.type=="open" and inner.name=="Item" then
					local children, newTi=parseXmlItems(tokens, ti, refCounter, "Item")
					ti=newTi
					for _, child in ipairs(children) do
						child.parent=node
						node.children[#node.children+1]=child
					end

				else
					ti +=1
				end
			end
			nodes[#nodes + 1]=node

		else
			ti +=1
		end
	end
	return nodes, ti
end

local function parseXml(xml)
	local tokens=tokenize(xml)
	local ti=1
	while ti<=#tokens and not(tokens[ti].type=="open" and tokens[ti].name=="roblox") do
		ti+=1
	end
	if ti>#tokens then error("RBXConverter: no <roblox> root element found") end
	ti+=1
	local refCounter={0}

	local xmlSharedStrings={}
	local tmpTi=ti
	while tmpTi<=#tokens do
		local tok=tokens[tmpTi]
		if tok.type=="open" and tok.name=="SharedStrings" then
			tmpTi+=1
			while tmpTi<=#tokens do
				local t=tokens[tmpTi]
				if t.type=="close" and t.name=="SharedStrings" then tmpTi+=1; break end
				if t.type=="open" and t.name=="SharedString" then
					local key=t.attrs and t.attrs.md5 or ""
					tmpTi+=1
					local content=""
					while tmpTi<=#tokens do
						local t2=tokens[tmpTi]
						if t2.type=="close" and t2.name=="SharedString" then tmpTi+=1; break end
						if t2.type=="text" then content=content..t2.text end
						tmpTi+=1
					end
					xmlSharedStrings[key]=base64Decode(content)
				else
					tmpTi+=1
				end
			end
			break
		elseif tok.type=="open" and tok.name=="Item" then
			break
		else
			tmpTi+=1
		end
	end

	local roots,_=parseXmlItems(tokens,ti,refCounter,"roblox")
	return roots, xmlSharedStrings
end

local xmlTagToTypeId={}
for id,info in pairs(PropType) do
	if info.xmlTag then xmlTagToTypeId[info.xmlTag]=id end
end
xmlTagToTypeId["string"]=0x01
xmlTagToTypeId["bool"]=0x02
xmlTagToTypeId["int"]=0x03
xmlTagToTypeId["float"]=0x04
xmlTagToTypeId["double"]=0x05
xmlTagToTypeId["BinaryString"]=0x1E2
xmlTagToTypeId["ProtectedString"]=0x1F
xmlTagToTypeId["Font"]=0x20
xmlTagToTypeId["SecurityCapabilities"]=0x21
xmlTagToTypeId["OptionalCoordinateFrame"]=0x1E
xmlTagToTypeId["Content"]=0x22

PropType[0x1E2]={
	name="BinaryString",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=data:sub(p,p+len-1);p+=len
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do parts[#parts+1]=spack("<I4",#(v or ""))..(v or "") end
		return tbconcat(parts)
	end,
	xmlTag="BinaryString",
	readXml=function(s) return base64Decode(s or "") end,
	writeXml=function(v) return base64Encode(v or "") end,
}
PropType[0x22]={
	name="Content",
	readBin=function(data,n)
		local out={};local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=data:sub(p,p+len-1);p+=len
		end; return out
	end,
	writeBin=function(vals)
		local parts={}
		for _,v in ipairs(vals) do
			v=tostring(v or "")
			parts[#parts+1]=spack("<I4",#v)..v
		end; return tbconcat(parts)
	end,
	xmlTag="Content",
	readXml=function(text,sub)
		if type(sub)=="table" then
			if type(sub.url)=="string" and sub.url~="" then return sub.url end
			if sub.null~=nil then return "" end
		end
		return text or ""
	end,
	writeXml=function(v)
		v=tostring(v or "")
		if v=="" then return "<null></null>"
		else return "<url>"..xmlEscape(v).."</url>" end
	end,
}

local function serializeBinary(roots, xmlSharedStrings)
	local allInsts={}
	local function collect(node)
		allInsts[#allInsts+1]=node
		for _,child in ipairs(node.children) do collect(child) end
	end
	for _,root in ipairs(roots) do collect(root) end

	local refMap={}
	for i,inst in ipairs(allInsts) do refMap[inst]=i-1 end

	local xmlRefNodeMap={}
	for _,inst in ipairs(allInsts) do
		if inst.xmlRef then xmlRefNodeMap[inst.xmlRef]=inst end
	end

	local sstrBlobs={}
	local sstrKeyToIdx={}
	if xmlSharedStrings and next(xmlSharedStrings) then
		sstrBlobs[1]=""
		sstrKeyToIdx[""]=0
		for key,blob in pairs(xmlSharedStrings) do
			local idx=#sstrBlobs
			sstrBlobs[idx+1]=blob
			sstrKeyToIdx[key]=idx
		end
	end

	local typeOrder={}
	local typeIndexMap={}
	for _,inst in ipairs(allInsts) do
		if not typeIndexMap[inst.className] then
			typeIndexMap[inst.className]=#typeOrder
			typeOrder[#typeOrder+1]=inst.className
		end
	end

	local instChunks={}
	local classGroups={}
	for _,inst in ipairs(allInsts) do
		local cn=inst.className
		if not classGroups[cn] then classGroups[cn]={} end
		classGroups[cn][#classGroups[cn]+1]=inst
	end

	for ti,className in ipairs(typeOrder) do
		local group=classGroups[className]
		local refs={}
		for i,inst in ipairs(group) do refs[i]=refMap[inst] end
		local payload=spack("<I4",ti-1)
		              ..spack("<I4",#className)..className
		              .."\x00"
		              ..spack("<I4",#group)
		              ..interleaveRef(refs)
		instChunks[#instChunks+1]=makeChunk("INST",payload)
	end

	local propNames={}
	for _,inst in ipairs(allInsts) do
		local cn=inst.className
		if not propNames[cn] then propNames[cn]={} end
		for pname in pairs(inst.properties) do propNames[cn][pname]=true end
	end

	local PROTECTED_STRING_PROPS={}

	local propChunks={}
	for ti,className in ipairs(typeOrder) do
		local group=classGroups[className]
		local pnames={}
		for pname in pairs(propNames[className] or {}) do pnames[#pnames+1]=pname end
		table.sort(pnames)

		for _,pname in ipairs(pnames) do
			local typeId=nil
			local vals={}
			for i,inst in ipairs(group) do
				local prop=inst.properties[pname]
				if prop and type(prop)=="table" then
					if prop.typeId then
						if not typeId then typeId=prop.typeId end
						vals[i]=prop.value

					elseif prop.xmlTag then
						local tid=xmlTagToTypeId[prop.xmlTag] or 0x01
						if not typeId then typeId=tid end
						local ti2=getType(tid)
						local v=ti2.readXml(prop.text or "", prop.sub or {})
						if v~=nil then
							if tid==0x1C then
								local key=prop.text or ""
								local idx=sstrKeyToIdx[key]
								if idx==nil then
									idx=#sstrBlobs; sstrBlobs[idx+1]=""
									sstrKeyToIdx[key]=idx
								end
								vals[i]=idx
							elseif tid==0x13 and v and v ~=-1 then
								local refStr=prop.text or ""
								local refNode=xmlRefNodeMap[refStr]
								if refNode then
									vals[i]=refMap[refNode]
								else
									vals[i]=v
								end
							else
								vals[i]=v
							end
						end
					end
				else
					vals[i]=nil
				end
			end
			if not typeId then continue end

			local typeInfo=getType(typeId)
			for i=1,#group do
				if vals[i]==nil then
					if typeId==0x01 then vals[i]=""
					elseif typeId==0x02 then vals[i]=false
					elseif typeId==0x03 or typeId==0x04 or typeId==0x05
					    or typeId==0x0B or typeId==0x12 then vals[i]=0
					elseif typeId==0x0C then vals[i]={r=0,g=0,b=0}
					elseif typeId==0x0E then vals[i]={x=0,y=0,z=0}
					elseif typeId==0x10 then vals[i]={r=CF_IDENTITY,x=0,y=0,z=0}
					elseif typeId==0x13 then vals[i]=-1
					elseif typeId==0x1E then vals[i]=nil
					elseif typeId==0x1E2 or typeId==0x1F then vals[i]=""
					elseif typeId==0x20 then vals[i]={family="",weight=400,style=0,cachedFaceId=""}
					elseif typeId==0x21 then vals[i]=0
					elseif typeId==0x22 then vals[i]=""
					else vals[i]=0 end
				end
			end

			local binData=typeInfo.writeBin(vals)
			if binData and #binData>0 then
				local binTypeId
				if typeId==0x22 or typeId==0x1E2 then
					binTypeId=0x01
				elseif typeId==0x1F and not PROTECTED_STRING_PROPS[pname] then
					binTypeId=0x01
				else
					binTypeId=typeId
				end
				local payload=spack("<I4I4",ti-1,#pname)..pname..chr[binTypeId]..binData
				propChunks[#propChunks+1]=makeChunk("PROP",payload)
			end
		end
	end

	local sstrChunk=nil
	if #sstrBlobs>0 then
		local parts={spack("<I4",0)}
		parts[#parts+1]=spack("<I4",#sstrBlobs)
		for _,blob in ipairs(sstrBlobs) do
			parts[#parts+1]=newBlobKey()
			parts[#parts+1]=spack("<I4",#blob)..blob
		end
		sstrChunk=makeChunk("SSTR",tbconcat(parts))
	end

	local childRefs,parentRefs={},{}
	for _,inst in ipairs(allInsts) do
		childRefs[#childRefs+1]=refMap[inst]
		parentRefs[#parentRefs+1]=inst.parent and refMap[inst.parent] or -1
	end
	local prntPayload="\x00"
	                 ..spack("<I4",#allInsts)
	                 ..interleaveRef(childRefs)
	                 ..interleaveParentRef(parentRefs)
	local prntChunk=makeChunk("PRNT",prntPayload)

	local endPayload="</roblox>"
	local endChunk="END\0"
	                ..spack("<I4",0)
	                ..spack("<I4",#endPayload)
	                ..spack("<I4",0)
	                ..endPayload

	local header=RBX_MAGIC
	             ..spack("<I4",#typeOrder)
	             ..spack("<I4",#allInsts)
	             ..spack("<I4",0)..spack("<I4",0)

	local parts={header}
	if sstrChunk then parts[#parts+1]=sstrChunk end
	for _,c in ipairs(instChunks)  do parts[#parts+1]=c end
	for _,c in ipairs(propChunks)  do parts[#parts+1]=c end
	parts[#parts+1]=prntChunk
	parts[#parts+1]=endChunk
	return tbconcat(parts)
end


local function serializeXml(roots,sharedStrs)
	local lines={}
	lines[#lines+1]='<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime"'
	                ..' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
	                ..' xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd"'
	                ..' version="4">'

	local blobKeyCache={}
	local function getBlobKey(blob)
		if not blobKeyCache[blob] then blobKeyCache[blob]=newBlobKey() end
		return blobKeyCache[blob]
	end
	local sharedBlobByMd5={}
	local function collectSharedBlobs(node)
		for _,prop in pairs(node.properties) do
			local tid=type(prop)=="table" and prop.typeId or nil
			if tid==0x1C then
				local idx=prop.value
				if type(idx)=="number" and sharedStrs and sharedStrs[idx] then
					local blob=sharedStrs[idx]
					local key=getBlobKey(blob)
					sharedBlobByMd5[key]=blob
				end
			end
		end
		for _,child in ipairs(node.children) do collectSharedBlobs(child) end
	end
	if sharedStrs then
		for _,root in ipairs(roots) do collectSharedBlobs(root) end
	end

	if next(sharedBlobByMd5) then
		lines[#lines+1]="\t<SharedStrings>"
		for key,blob in pairs(sharedBlobByMd5) do
			local keyB64=base64Encode(key)
			local blobB64=base64Encode(blob)
			local wrapped={}
			for i=1,#blobB64,76 do wrapped[#wrapped+1]="\t\t\t"..blobB64:sub(i,i+75) end
			lines[#lines+1]='\t\t<SharedString md5="'..keyB64..'">'
			lines[#lines+1]=tbconcat(wrapped,"\n")
			lines[#lines+1]="\t\t</SharedString>"
		end
		lines[#lines+1]="\t</SharedStrings>"
	end

	local function writeNode(node,indent)
		local tab=srep("\t",indent)
		lines[#lines+1]=tab..'<Item class="'..xmlEscape(node.className)
		                ..'" referent="RBX'..sfmt("%08X",node.referent)..'">'
		lines[#lines+1]=tab.."\t<Properties>"

		local pnames={}
		for pname in pairs(node.properties) do pnames[#pnames+1]=pname end
		table.sort(pnames)

		for _,pname in ipairs(pnames) do
			local prop=node.properties[pname]
			local typeId,value

			if type(prop)=="table" and prop.typeId then
				typeId=prop.typeId
				value=prop.value
			elseif type(prop)=="table" and prop.xmlTag then
				typeId=xmlTagToTypeId[prop.xmlTag] or 0x01
				local typeInfo=getType(typeId)
				value=typeInfo.readXml(prop.text,prop.sub or {})
			else
				continue
			end

			if typeId==0x1C then
				local idx=type(value)=="number" and value or tonumber(value) or 0
				local blob=sharedStrs and sharedStrs[idx] or ""
				value=base64Encode(getBlobKey(blob))
			end

			local typeInfo=getType(typeId)
			local tag=typeInfo.xmlTag
			local ok,inner=pcall(typeInfo.writeXml,value)
			if ok then
				local encoded
				if typeId==0x1F then
					encoded="<![CDATA["..inner.."]]>"
				elseif typeId==0x01 or typeId==0x02 or typeId==0x03 or typeId==0x04
				    or typeId==0x05 or typeId==0x0B or typeId==0x12 or typeId==0x15
				    or typeId==0x16 or typeId==0x17 or typeId==0x1B or typeId==0x1C
				    or typeId==0x21 then
					encoded=xmlEscape(inner)
				else
					encoded=inner
				end
				lines[#lines+1]=tab.."\t\t<"..tag..' name="'..xmlEscape(pname)..'">'
				                ..encoded
				                .."</"..tag..">"
			end
		end

		lines[#lines+1]=tab.."\t</Properties>"

		for _,child in ipairs(node.children) do
			writeNode(child,indent+1)
		end

		lines[#lines+1]=tab.."</Item>"
	end

	for _,root in ipairs(roots) do writeNode(root,1) end
	lines[#lines+1]="</roblox>"
	return tbconcat(lines,"\n")
end

function Converter.XMLToBinary(xmlString)
	assert(type(xmlString)=="string" and #xmlString>0,
		"XMLToBinary: expected a non-empty XML string")
	local roots, xmlSharedStrings=parseXml(xmlString)
	assert(#roots > 0, "XMLToBinary: no instances found in XML string")
	return serializeBinary(roots, xmlSharedStrings)
end

function Converter.BinaryToXML(binaryString)
	assert(type(binaryString)=="string" and #binaryString>0,
		"BinaryToXML: expected a non-empty binary string")
	local roots, sharedStrs=parseBinary(binaryString)
	assert(#roots > 0, "BinaryToXML: no instances found in binary string")
	return serializeXml(roots, sharedStrs)
end

return Converter