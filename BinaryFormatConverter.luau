--ai was used for optimization here. Im also not sure if --native will even do anything here
local converter={nex_version="1.0.2"}
local clonefunction=clonefunction

if not clonefunction then
clonefunction=function(x) return x end
end
local cf=clonefunction(clonefunction)
if newcclosure then
local nc=cf(newcclosure)
else
local nc=clonefunction
end
-- bit32
local b32=bit32
local b32rsh=cf(b32.rshift)
local b32band=cf(b32.band)
local b32bor=cf(b32.bor)
local b32lsh=cf(b32.lshift)

-- string
local spack=cf(string.pack)
local sunpack=cf(string.unpack)
local schar=cf(string.char)
local sfmt=cf(string.format)
local sfind=cf(string.find)
local ssub=cf(string.sub)
local sbyte=cf(string.byte)
local srep=cf(string.rep)

-- table
local tconc=cf(table.concat)
local tcreat=cf(table.create)
local tsort=cf(table.sort)
local tunpack=cf(table.unpack)

-- math
local mfloor=cf(math.floor)
local mabs=cf(math.abs)
local mceil=cf(math.ceil)
local mmin=cf(math.min)
local huge=math.huge

-- globals
local pairs=cf(pairs)
local next=cf(next)
local pcall=cf(pcall)
local type=cf(type)
local tonumber=cf(tonumber)
local tostring=cf(tostring)

local httpservice=game:getservice("HttpService")

-- character lookup table
local chr=tcreat(256)
for _i=0, 255 do
	chr[_i]=schar(_i)
end

-- ────────────────────────────────────────────────────────────
-- GUID / blob key
-- ────────────────────────────────────────────────────────────
local function newblobkey()
	local g=httpservice:generateguid(false):gsub("-", "")
	local b=tcreat(16)
	for i=1, 16 do
		b[i]=schar(tonumber(g:sub(i*2-1, i*2), 16))
	end
	return tconc(b)
end

-- ────────────────────────────────────────────────────────────
-- LZ4 decompression
-- ────────────────────────────────────────────────────────────
local function lz4decompress(src, uncompsize)
	local out=tcreat(uncompsize+64, 0)
	local si=1
	local oi=1
	local slen=#src
	while si<=slen do
		local tok=sbyte(src, si); si+=1
		local ll=b32rsh(tok, 4)
		if ll==15 then
			repeat
				local e=sbyte(src, si) or 0; si+=1; ll+=e
			until e~=255
		end
		local si_end=si+ll-1
		while si<=si_end do
			local ce=mmin(si+199, si_end)
			local nb=ce-si+1
			if nb==1 then
				out[oi]=sbyte(src, si); oi+=1; si+=1
			elseif nb==2 then
				local a, b=sbyte(src, si, si+1)
				out[oi]=a; out[oi+1]=b; oi+=2; si+=2
			else
				local bytes={sbyte(src, si, ce)}
				for k=1, nb do out[oi]=bytes[k]; oi+=1 end
				si+=nb
			end
		end
		if si>slen then break end
		local b0=sbyte(src, si) or 0; si+=1
		local b1=sbyte(src, si) or 0; si+=1
		local offset=b0+b1*256
		if offset==0 then break end
		local ml=b32band(tok, 0xF)+4
		if b32band(tok, 0xF)==15 then
			repeat
				local e=sbyte(src, si) or 0; si+=1; ml+=e
			until e~=255
		end
		local ms=oi-offset
		for _=1, ml do
			out[oi]=(ms>=1) and (out[ms] or 0) or 0; oi+=1; ms+=1
		end
	end
	local batch=200
	local rc=0
	local r=tcreat(mceil((oi-1)/batch))
	for i=1, oi-1, batch do
		rc+=1; r[rc]=schar(tunpack(out, i, mmin(i+batch-1, oi-1)))
	end
	return tconc(r)
end

-- ────────────────────────────────────────────────────────────
-- LZ4 compression
-- ────────────────────────────────────────────────────────────
local function lz4compress(src)
	local n=#src
	if n==0 then return "\x00" end
	local limit=n-12
	local htbits=16
	while htbits<20 and b32lsh(1, htbits)<n do htbits+=1 end
	local htsize=b32lsh(1, htbits)
	local htshift=32-htbits
	local m=2654435761
	local ht=tcreat(htsize, 0)
	local prev=tcreat(n+1, 0)
	local max_depth=16
	local oc=0; local out={}; local anchor=1; local ip=1
	local function hash4(b0, b1, b2, b3)
		local lo=b32band((b0+b1*256)*m, 0xFFFFFFFF)
		local hi=b32band((b2+b3*256)*m, 0xFFFFFFFF)
		return b32rsh(b32band(lo+b32lsh(hi, 16), 0xFFFFFFFF), htshift)+1
	end
	while ip<=limit do
		local b0, b1, b2, b3=sbyte(src, ip, ip+3)
		local h=hash4(b0, b1, b2, b3)
		prev[ip]=ht[h]; ht[h]=ip
		local best_ml=3; local best_ref=0
		local maxml=n-4-ip
		local pos=prev[ip]; local depth=0
		while pos>0 and depth<max_depth do
			if ip-pos>65535 then break end
			local r0, r1, r2, r3=sbyte(src, pos, pos+3)
			if r0==b0 and r1==b1 and r2==b2 and r3==b3 then
				local ml=4
				while ml+8<=maxml and ssub(src, ip+ml, ip+ml+7)==ssub(src, pos+ml, pos+ml+7) do ml+=8 end
				while ml<maxml and sbyte(src, ip+ml)==sbyte(src, pos+ml) do ml+=1 end
				if ml>best_ml then
					best_ml=ml; best_ref=pos
					if ml>=maxml then break end
				end
			end
			pos=prev[pos]; depth+=1
		end
		if best_ref>0 then
			local ll=ip-anchor
			local ml4=best_ml-4
			local offset=ip-best_ref
			oc+=1; out[oc]=schar(mmin(ll, 15)*16+mmin(ml4, 15))
			if ll>=15 then
				local r=ll-15
				while r>=255 do oc+=1; out[oc]="\xff"; r-=255 end
				oc+=1; out[oc]=schar(r)
			end
			if ll>0 then oc+=1; out[oc]=ssub(src, anchor, ip-1) end
			oc+=1; out[oc]=schar(offset%256)
			oc+=1; out[oc]=schar(mfloor(offset/256))
			if ml4>=15 then
				local r=ml4-15
				while r>=255 do oc+=1; out[oc]="\xff"; r-=255 end
				oc+=1; out[oc]=schar(r)
			end
			ip=ip+best_ml; anchor=ip
		else
			ip+=1
		end
	end
	local ll=n-anchor+1
	oc+=1; out[oc]=schar(mmin(ll, 15)*16)
	if ll>=15 then
		local r=ll-15
		while r>=255 do oc+=1; out[oc]="\xff"; r-=255 end
		oc+=1; out[oc]=schar(r)
	end
	oc+=1; out[oc]=ssub(src, anchor, n)
	return tconc(out, "", 1, oc)
end

-- ────────────────────────────────────────────────────────────
-- Zigzag encode / decode helpers
-- ────────────────────────────────────────────────────────────
local function zzdec(v) return b32band(v, 1)==0 and b32rsh(v, 1) or-(b32rsh(v, 1)+1) end
local function zzenc(v) return v>=0 and v*2 or-v*2-1 end

-- ────────────────────────────────────────────────────────────
-- Interleave helpers
-- ────────────────────────────────────────────────────────────
local function deinterleaveu32(data, n)
	local out=tcreat(n)
	local n2, n3=n*2, n*3
	for i=1, n do
		out[i]=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)
	end
	return out
end

local function interleaveu32(vals)
	local n=#vals
	local n2, n3=n*2, n*3
	local out=tcreat(n*4)
	for i=1, n do
		local r=(vals[i] or 0)%0x100000000
		out[i]=chr[b32rsh(r,24)]
		out[n+i]=chr[b32band(b32rsh(r,16),255)]
		out[n2+i]=chr[b32band(b32rsh(r,8),255)]
		out[n3+i]=chr[b32band(r,255)]
	end
	return tconc(out)
end

local function deinterleavei32(data, n)
	local out=tcreat(n)
	local n2, n3=n*2, n*3
	for i=1, n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)
		out[i]=zzdec(raw)
	end
	return out
end

local function interleavei32(vals)
	local n=#vals
	local n2, n3=n*2, n*3
	local out=tcreat(n*4)
	for i=1, n do
		local r=zzenc(vals[i])%0x100000000
		out[i]=chr[b32rsh(r,24)]
		out[n+i]=chr[b32band(b32rsh(r,16),255)]
		out[n2+i]=chr[b32band(b32rsh(r,8),255)]
		out[n3+i]=chr[b32band(r,255)]
	end
	return tconc(out)
end

local function deinterleaveref(data, n)
	local out=tcreat(n)
	local n2, n3=n*2, n*3
	local acc=0
	for i=1, n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)
		acc+=zzdec(raw); out[i]=acc
	end
	return out
end

local deinterleaveparentref=deinterleaveref

local function interleaveref(refs)
	local n=#refs
	local deltas=tcreat(n)
	local prev=0
	for i=1, n do
		local v=refs[i]; deltas[i]=v-prev; prev=v
	end
	return interleavei32(deltas)
end

local interleaveparentref=interleaveref

local function deinterleavef32(data, n)
	local out=tcreat(n)
	local n2, n3=n*2, n*3
	for i=1, n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)
		local bits=b32bor(b32rsh(raw,1), b32lsh(b32band(raw,1),31))
		out[i]=(sunpack(">f", schar(b32rsh(bits,24)%256, b32rsh(bits,16)%256, b32rsh(bits,8)%256, bits%256)))
	end
	return out
end

local function interleavef32(vals)
	local n=#vals
	local n2, n3=n*2, n*3
	local out=tcreat(n*4)
	for i=1, n do
		local b0,b1,b2,b3=sbyte(spack(">f", vals[i]), 1, 4)
		local bits=b0*0x1000000+b1*0x10000+b2*0x100+b3
		local raw=b32bor(b32lsh(bits,1), b32rsh(bits,31))%0x100000000
		out[i]=chr[b32rsh(raw,24)]
		out[n+i]=chr[b32band(b32rsh(raw,16),255)]
		out[n2+i]=chr[b32band(b32rsh(raw,8),255)]
		out[n3+i]=chr[b32band(raw,255)]
	end
	return tconc(out)
end

-- ────────────────────────────────────────────────────────────
-- Chunk builder
-- ────────────────────────────────────────────────────────────
local rbx_magic="<roblox!\x89\xFF\x0D\x0A\x1A\x0A\x00\x00"

local function makechunk(name, payload)
	local n=#payload
	local compressed=lz4compress(payload)
	if #compressed<n then
		return name..spack("<I4",#compressed)..spack("<I4",n)..spack("<I4",0)..compressed
	end
	return name..spack("<I4",0)..spack("<I4",n)..spack("<I4",0)..payload
end

-- ────────────────────────────────────────────────────────────
-- CFrame orientation tables
-- ────────────────────────────────────────────────────────────
local cf_identity={1,0,0,0,1,0,0,0,1}
local cf_special={
	[0x02]={1,0,0,0,1,0,0,0,1},   [0x03]={1,0,0,0,0,-1,0,1,0},
	[0x05]={1,0,0,0,-1,0,0,0,-1}, [0x06]={1,0,0,0,0,1,0,-1,0},
	[0x07]={0,1,0,1,0,0,0,0,-1},  [0x09]={0,0,1,1,0,0,0,1,0},
	[0x0A]={0,-1,0,1,0,0,0,0,1},  [0x0C]={0,0,-1,1,0,0,0,-1,0},
	[0x0D]={0,1,0,0,0,1,1,0,0},   [0x0E]={0,0,-1,0,1,0,1,0,0},
	[0x10]={0,-1,0,0,0,-1,1,0,0}, [0x11]={0,0,1,0,-1,0,1,0,0},
	[0x14]={-1,0,0,0,1,0,0,0,-1}, [0x15]={-1,0,0,0,0,1,0,1,0},
	[0x17]={-1,0,0,0,-1,0,0,0,1}, [0x18]={-1,0,0,0,0,-1,0,-1,0},
	[0x19]={0,1,0,-1,0,0,0,0,1},  [0x1B]={0,0,-1,-1,0,0,0,1,0},
	[0x1C]={0,-1,0,-1,0,0,0,0,-1},[0x1E]={0,0,1,-1,0,0,0,-1,0},
	[0x1F]={0,1,0,0,0,-1,-1,0,0}, [0x20]={0,0,1,0,1,0,-1,0,0},
	[0x22]={0,-1,0,0,0,1,-1,0,0}, [0x23]={0,0,-1,0,-1,0,-1,0,0},
}

local function findcfspecial(r)
	for id, sr in pairs(cf_special) do
		local ok=true
		for j=1, 9 do
			if mabs((r[j] or 0)-sr[j])>1e-4 then ok=false; break end
		end
		if ok then return id end
	end
end

-- ────────────────────────────────────────────────────────────
-- XML helpers
-- ────────────────────────────────────────────────────────────
local function xmlunescape(s)
	return (s:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"))
end

local function xmlescape(s)
	return (tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"))
end

local function safef(v)
	if type(v)~="number" or v~=v or mabs(v)==huge then return "0" end
	return sfmt("%.9g", v)
end

-- ────────────────────────────────────────────────────────────
-- Base64
-- ────────────────────────────────────────────────────────────
local b64chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64enc={}; for i=0, 63 do b64enc[i]=ssub(b64chars, i+1, i+1) end
local b64dec={}; for i=0, 63 do b64dec[sbyte(b64chars, i+1)]=i end

local function base64encode(s)
	local n=#s
	local oc=0
	local out=tcreat(mceil(n/3)*4)
	for i=1, n, 3 do
		local a=sbyte(s,i)   or 0
		local b=sbyte(s,i+1) or 0
		local c=sbyte(s,i+2) or 0
		local v=a*65536+b*256+c
		oc+=1; out[oc]=b64enc[b32rsh(v,18)]
		oc+=1; out[oc]=b64enc[b32band(b32rsh(v,12),63)]
		oc+=1; out[oc]=i+1<=n and b64enc[b32band(b32rsh(v,6),63)] or "="
		oc+=1; out[oc]=i+2<=n and b64enc[b32band(v,63)] or "="
	end
	return tconc(out)
end

local function base64decode(s)
	s=s:gsub("[^A-Za-z0-9+/=]", "")
	local n=#s
	local oc=0
	local out=tcreat(mceil(n/4)*3)
	local i=1
	while i<=n do
		local a=b64dec[sbyte(s,i)] or 0; i+=1
		local b=b64dec[sbyte(s,i)] or 0; i+=1
		local c=b64dec[sbyte(s,i)] or 0; i+=1
		local d=b64dec[sbyte(s,i)] or 0; i+=1
		local v=a*262144+b*4096+c*64+d
		oc+=1; out[oc]=schar(b32rsh(v,16))
		if sbyte(s,i-2)~=61 then oc+=1; out[oc]=schar(b32band(b32rsh(v,8),255)) end
		if sbyte(s,i-1)~=61 then oc+=1; out[oc]=schar(b32band(v,255)) end
	end
	return tconc(out)
end

-- ────────────────────────────────────────────────────────────
-- Property type definitions
-- ────────────────────────────────────────────────────────────
local proptype={}

proptype[0x01]={
	name="String",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do
			local len, np=sunpack("<I4", data, p); p=np
			out[i]=ssub(data, p, p+len-1); p+=len
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n*2)
		for i=1, n do
			local v=vals[i]
			pc+=1; parts[pc]=spack("<I4", #v)
			pc+=1; parts[pc]=v
		end
		return tconc(parts)
	end,
	xmltag="string",
	readxml=function(s) return s end,
	writexml=function(v) return tostring(v) end,
}

proptype[0x02]={
	name="Bool",
	readbin=function(data, n)
		local out=tcreat(n)
		for i=1, n do out[i]=sbyte(data,i)~=0 end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local out=tcreat(n)
		for i=1, n do out[i]=chr[vals[i] and 1 or 0] end
		return tconc(out)
	end,
	xmltag="bool",
	readxml=function(s) return s=="true" end,
	writexml=function(v) return v and "true" or "false" end,
}

proptype[0x03]={
	name="Int",
	readbin=function(data, n) return deinterleavei32(data, n) end,
	writebin=function(vals) return interleavei32(vals) end,
	xmltag="int",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return tostring(mfloor(v or 0)) end,
}

proptype[0x04]={
	name="Float",
	readbin=function(data, n) return deinterleavef32(data, n) end,
	writebin=function(vals) return interleavef32(vals) end,
	xmltag="float",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return safef(v) end,
}

proptype[0x05]={
	name="Double",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do out[i], p=sunpack("<d", data, p) end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1, n do pc+=1; parts[pc]=spack("<d", vals[i]) end
		return tconc(parts)
	end,
	xmltag="double",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return sfmt("%.17g", v) end,
}

proptype[0x06]={
	name="UDim",
	readbin=function(data, n)
		local sc=deinterleavef32(ssub(data,1,n*4), n)
		local of=deinterleavei32(ssub(data,n*4+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={scale=sc[i], offset=of[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local sc=tcreat(n); local of=tcreat(n)
		for i=1, n do sc[i]=vals[i].scale; of[i]=vals[i].offset end
		return interleavef32(sc)..interleavei32(of)
	end,
	xmltag="UDim",
	readxml=function(_, sub) return {scale=tonumber(sub.s or"0"), offset=tonumber(sub.o or"0")} end,
	writexml=function(v) return sfmt("<S>%g</S><O>%d</O>", v.scale, v.offset) end,
}

proptype[0x07]={
	name="UDim2",
	readbin=function(data, n)
		local xs=deinterleavef32(ssub(data,1,n*4), n)
		local ys=deinterleavef32(ssub(data,n*4+1,n*8), n)
		local xo=deinterleavei32(ssub(data,n*8+1,n*12), n)
		local yo=deinterleavei32(ssub(data,n*12+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={xscale=xs[i], yscale=ys[i], xoffset=xo[i], yoffset=yo[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local xs=tcreat(n); local ys=tcreat(n); local xo=tcreat(n); local yo=tcreat(n)
		for i=1, n do
			local v=vals[i]; xs[i]=v.xscale; ys[i]=v.yscale; xo[i]=v.xoffset; yo[i]=v.yoffset
		end
		return interleavef32(xs)..interleavef32(ys)..interleavei32(xo)..interleavei32(yo)
	end,
	xmltag="UDim2",
	readxml=function(_, sub)
		return {xscale=tonumber(sub.xs or"0"), xoffset=tonumber(sub.xo or"0"),
		        yscale=tonumber(sub.ys or"0"), yoffset=tonumber(sub.yo or"0")}
	end,
	writexml=function(v)
		return sfmt("<XS>%g</XS><XO>%d</XO><YS>%g</YS><YO>%d</YO>", v.xscale, v.xoffset, v.yscale, v.yoffset)
	end,
}

proptype[0x08]={
	name="Ray",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do
			local ox,oy,oz,dx,dy,dz
			ox,p=sunpack("<f",data,p); oy,p=sunpack("<f",data,p); oz,p=sunpack("<f",data,p)
			dx,p=sunpack("<f",data,p); dy,p=sunpack("<f",data,p); dz,p=sunpack("<f",data,p)
			out[i]={ox=ox, oy=oy, oz=oz, dx=dx, dy=dy, dz=dz}
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1, n do
			local v=vals[i]
			pc+=1; parts[pc]=spack("<ffffff", v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)
		end
		return tconc(parts)
	end,
	xmltag="Ray",
	readxml=function(_, sub)
		local o=type(sub.origin)=="table" and sub.origin or {}
		local d=type(sub.direction)=="table" and sub.direction or {}
		return {ox=tonumber(o.x or"0"), oy=tonumber(o.y or"0"), oz=tonumber(o.z or"0"),
		        dx=tonumber(d.x or"0"), dy=tonumber(d.y or"0"), dz=tonumber(d.z or"0")}
	end,
	writexml=function(v)
		return sfmt("<origin><X>%g</X><Y>%g</Y><Z>%g</Z></origin><direction><X>%g</X><Y>%g</Y><Z>%g</Z></direction>",
			v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)
	end,
}

proptype[0x09]={
	name="Faces",
	readbin=function(data, n)
		local out=tcreat(n)
		for i=1, n do out[i]=sbyte(data,i) end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local out=tcreat(n)
		for i=1, n do out[i]=chr[(vals[i] or 0)%256] end
		return tconc(out)
	end,
	xmltag="Faces",
	readxml=function(_, sub)
		local v=0
		if sub.right=="true"  then v+=1  end; if sub.top=="true"    then v+=2  end
		if sub.back=="true"   then v+=4  end; if sub.left=="true"   then v+=8  end
		if sub.bottom=="true" then v+=16 end; if sub.front=="true"  then v+=32 end
		return v
	end,
	writexml=function(v)
		local function b(m) return b32band(v,m)~=0 and "true" or "false" end
		return sfmt("<Right>%s</Right><Top>%s</Top><Back>%s</Back><Left>%s</Left><Bottom>%s</Bottom><Front>%s</Front>",
			b(1),b(2),b(4),b(8),b(16),b(32))
	end,
}

proptype[0x0A]={
	name="Axes",
	readbin=function(data, n)
		local out=tcreat(n)
		for i=1, n do out[i]=sbyte(data,i) end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local out=tcreat(n)
		for i=1, n do out[i]=chr[(vals[i] or 0)%256] end
		return tconc(out)
	end,
	xmltag="Axes",
	readxml=function(_, sub)
		local v=0
		if sub.x=="true" then v+=4 end
		if sub.y=="true" then v+=2 end
		if sub.z=="true" then v+=1 end
		return v
	end,
	writexml=function(v)
		local function b(m) return b32band(v,m)~=0 and "true" or "false" end
		return sfmt("<X>%s</X><Y>%s</Y><Z>%s</Z>", b(4),b(2),b(1))
	end,
}

proptype[0x0B]={
	name="BrickColor",
	readbin=function(data, n) return deinterleaveu32(data, n) end,
	writebin=function(vals) return interleaveu32(vals) end,
	xmltag="BrickColor",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return tostring(mfloor(v or 0)) end,
}

proptype[0x0C]={
	name="Color3",
	readbin=function(data, n)
		local rs=deinterleavef32(ssub(data,1,n*4), n)
		local gs=deinterleavef32(ssub(data,n*4+1,n*8), n)
		local bs=deinterleavef32(ssub(data,n*8+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={r=rs[i], g=gs[i], b=bs[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local rs=tcreat(n); local gs=tcreat(n); local bs=tcreat(n)
		for i=1, n do local v=vals[i]; rs[i]=v.r; gs[i]=v.g; bs[i]=v.b end
		return interleavef32(rs)..interleavef32(gs)..interleavef32(bs)
	end,
	xmltag="Color3",
	readxml=function(s, sub)
		if sub and sub.r then
			return {r=tonumber(sub.r or"0"), g=tonumber(sub.g or"0"), b=tonumber(sub.b or"0")}
		end
		local packed=tonumber(s) or 0
		return {
			r=b32band(b32rsh(packed,16),0xFF)/255,
			g=b32band(b32rsh(packed,8),0xFF)/255,
			b=b32band(packed,0xFF)/255,
		}
	end,
	writexml=function(v) return sfmt("<R>%.9g</R><G>%.9g</G><B>%.9g</B>", v.r,v.g,v.b) end,
}

proptype[0x0D]={
	name="Vector2",
	readbin=function(data, n)
		local xs=deinterleavef32(ssub(data,1,n*4), n)
		local ys=deinterleavef32(ssub(data,n*4+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={x=xs[i], y=ys[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local xs=tcreat(n); local ys=tcreat(n)
		for i=1, n do xs[i]=vals[i].x; ys[i]=vals[i].y end
		return interleavef32(xs)..interleavef32(ys)
	end,
	xmltag="Vector2",
	readxml=function(_, sub) return {x=tonumber(sub.x or"0"), y=tonumber(sub.y or"0")} end,
	writexml=function(v) return sfmt("<X>%.9g</X><Y>%.9g</Y>", v.x, v.y) end,
}

proptype[0x0E]={
	name="Vector3",
	readbin=function(data, n)
		local xs=deinterleavef32(ssub(data,1,n*4), n)
		local ys=deinterleavef32(ssub(data,n*4+1,n*8), n)
		local zs=deinterleavef32(ssub(data,n*8+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={x=xs[i], y=ys[i], z=zs[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local xs=tcreat(n); local ys=tcreat(n); local zs=tcreat(n)
		for i=1, n do local v=vals[i]; xs[i]=v.x; ys[i]=v.y; zs[i]=v.z end
		return interleavef32(xs)..interleavef32(ys)..interleavef32(zs)
	end,
	xmltag="Vector3",
	readxml=function(_, sub) return {x=tonumber(sub.x or"0"), y=tonumber(sub.y or"0"), z=tonumber(sub.z or"0")} end,
	writexml=function(v) return "<X>"..safef(v.x).."</X><Y>"..safef(v.y).."</Y><Z>"..safef(v.z).."</Z>" end,
}

proptype[0x10]={
	name="CFrame",
	readbin=function(data, n)
		local p=1
		local rotations=tcreat(n)
		for i=1, n do
			local spec=sbyte(data, p); p+=1
			if spec==0 then
				local r=tcreat(9)
				for j=1, 9 do r[j], p=sunpack("<f", data, p) end
				rotations[i]=r
			else
				rotations[i]=cf_special[spec] or cf_identity
			end
		end
		local posdata=ssub(data, p)
		local xs=deinterleavef32(ssub(posdata,1,n*4), n)
		local ys=deinterleavef32(ssub(posdata,n*4+1,n*8), n)
		local zs=deinterleavef32(ssub(posdata,n*8+1), n)
		local out=tcreat(n)
		for i=1, n do out[i]={r=rotations[i], x=xs[i], y=ys[i], z=zs[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local pc=0; local perinst=tcreat(n)
		local xs=tcreat(n); local ys=tcreat(n); local zs=tcreat(n)
		for i=1, n do
			local v=vals[i]; local r=v.r or cf_identity
			local specid=findcfspecial(r)
			if specid then
				pc+=1; perinst[pc]=schar(specid)
			else
				local rp=tcreat(10); rp[1]="\x00"
				for j=1, 9 do rp[j+1]=spack("<f", r[j] or 0) end
				pc+=1; perinst[pc]=tconc(rp)
			end
			xs[i]=v.x or 0; ys[i]=v.y or 0; zs[i]=v.z or 0
		end
		return tconc(perinst,"",1,pc)..interleavef32(xs)..interleavef32(ys)..interleavef32(zs)
	end,
	xmltag="CoordinateFrame",
	readxml=function(_, sub)
		return {
			x=tonumber(sub.x or"0"), y=tonumber(sub.y or"0"), z=tonumber(sub.z or"0"),
			r={
				tonumber(sub.r00 or"1"), tonumber(sub.r01 or"0"), tonumber(sub.r02 or"0"),
				tonumber(sub.r10 or"0"), tonumber(sub.r11 or"1"), tonumber(sub.r12 or"0"),
				tonumber(sub.r20 or"0"), tonumber(sub.r21 or"0"), tonumber(sub.r22 or"1"),
			},
		}
	end,
	writexml=function(v)
		local r=v.r or cf_identity
		return "<X>"..safef(v.x).."</X><Y>"..safef(v.y).."</Y><Z>"..safef(v.z).."</Z>"
.."<R00>"..safef(r[1]).."</R00><R01>"..safef(r[2]).."</R01><R02>"..safef(r[3]).."</R02>"
.."<R10>"..safef(r[4]).."</R10><R11>"..safef(r[5]).."</R11><R12>"..safef(r[6]).."</R12>"
.."<R20>"..safef(r[7]).."</R20><R21>"..safef(r[8]).."</R21><R22>"..safef(r[9]).."</R22>"
	end,
}

proptype[0x12]={
	name="Enum",
	readbin=function(data, n) return deinterleaveu32(data, n) end,
	writebin=function(vals) return interleaveu32(vals) end,
	xmltag="token",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return tostring(mfloor(v or 0)) end,
}

proptype[0x13]={
	name="Referent",
	readbin=function(data, n) return deinterleaveref(data, n) end,
	writebin=function(vals) return interleaveref(vals) end,
	xmltag="Ref",
	readxml=function(s)
		if not s or s=="null" or s=="" then return-1 end
		local hex=s:match("^RBX(%x+)$")
		if hex then return tonumber(hex, 16) end
		return tonumber(s) or-1
	end,
	writexml=function(v) return (not v or v==-1 or v<0) and "null" or ("RBX"..sfmt("%08X",v)) end,
}

proptype[0x14]={
	name="Vector3int16",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do
			local x, y, z
			x,p=sunpack("<i2",data,p); y,p=sunpack("<i2",data,p); z,p=sunpack("<i2",data,p)
			out[i]={x=x, y=y, z=z}
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1, n do
			local v=vals[i]
			pc+=1; parts[pc]=spack("<i2i2i2", v.x or 0, v.y or 0, v.z or 0)
		end
		return tconc(parts)
	end,
	xmltag="Vector3int16",
	readxml=function(_, sub) return {x=tonumber(sub.x or"0"), y=tonumber(sub.y or"0"), z=tonumber(sub.z or"0")} end,
	writexml=function(v) return sfmt("<X>%d</X><Y>%d</Y><Z>%d</Z>", v.x,v.y,v.z) end,
}

proptype[0x15]={
	name="NumberSequence",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do
			local count, np=sunpack("<I4", data, p); p=np
			local kps=tcreat(count)
			for j=1, count do
				local t, v, e
				t,p=sunpack("<f",data,p); v,p=sunpack("<f",data,p); e,p=sunpack("<f",data,p)
				kps[j]={t=t, v=v, e=e}
			end
			out[i]=kps
		end
		return out
	end,
	writebin=function(vals)
		local nv=#vals; local pc=0; local parts=tcreat(nv*4)
		for i=1, nv do
			local kps=vals[i]; local nk=#kps
			pc+=1; parts[pc]=spack("<I4", nk)
			for j=1, nk do local kp=kps[j]; pc+=1; parts[pc]=spack("<fff",kp.t,kp.v,kp.e) end
		end
		return tconc(parts)
	end,
	xmltag="NumberSequence",
	readxml=function(s)
		local kps={}; local kc=0
		for t,v,e in (s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+") do
			kc+=1; kps[kc]={t=tonumber(t), v=tonumber(v), e=tonumber(e)}
		end
		return kps
	end,
	writexml=function(v)
		local n=#v; local pc=0; local parts=tcreat(n)
		for i=1, n do local kp=v[i]; pc+=1; parts[pc]=sfmt("%g %g %g ",kp.t,kp.v,kp.e) end
		return tconc(parts)
	end,
}

proptype[0x16]={
	name="ColorSequence",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1, n do
			local count, np=sunpack("<I4", data, p); p=np
			local kps=tcreat(count)
			for j=1, count do
				local t,r,g,bb,e
				t,p=sunpack("<f",data,p); r,p=sunpack("<f",data,p)
				g,p=sunpack("<f",data,p); bb,p=sunpack("<f",data,p); e,p=sunpack("<f",data,p)
				kps[j]={t=t, r=r, g=g, b=bb, e=e}
			end
			out[i]=kps
		end
		return out
	end,
	writebin=function(vals)
		local nv=#vals; local pc=0; local parts=tcreat(nv*4)
		for i=1, nv do
			local kps=vals[i]; local nk=#kps
			pc+=1; parts[pc]=spack("<I4",nk)
			for j=1, nk do local kp=kps[j]; pc+=1; parts[pc]=spack("<fffff",kp.t,kp.r,kp.g,kp.b,kp.e) end
		end
		return tconc(parts)
	end,
	xmltag="ColorSequence",
	readxml=function(s)
		local kps={}; local kc=0
		for t,r,g,b,e in (s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+") do
			kc+=1; kps[kc]={t=tonumber(t),r=tonumber(r),g=tonumber(g),b=tonumber(b),e=tonumber(e)}
		end
		return kps
	end,
	writexml=function(v)
		local n=#v; local pc=0; local parts=tcreat(n)
		for i=1,n do local kp=v[i]; pc+=1; parts[pc]=sfmt("%g %g %g %g %g ",kp.t,kp.r,kp.g,kp.b,kp.e) end
		return tconc(parts)
	end,
}

proptype[0x17]={
	name="NumberRange",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local mn,mx; mn,p=sunpack("<f",data,p); mx,p=sunpack("<f",data,p)
			out[i]={min=mn, max=mx}
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1,n do local v=vals[i]; pc+=1; parts[pc]=spack("<ff",v.min,v.max) end
		return tconc(parts)
	end,
	xmltag="NumberRange",
	readxml=function(s) local a,b=s:match("(%S+)%s+(%S+)"); return{min=tonumber(a or"0"),max=tonumber(b or"1")} end,
	writexml=function(v) return sfmt("%g %g ",v.min,v.max) end,
}

proptype[0x18]={
	name="Rect",
	readbin=function(data, n)
		local mnx=deinterleavef32(ssub(data,1,n*4),n)
		local mny=deinterleavef32(ssub(data,n*4+1,n*8),n)
		local mxx=deinterleavef32(ssub(data,n*8+1,n*12),n)
		local mxy=deinterleavef32(ssub(data,n*12+1),n)
		local out=tcreat(n)
		for i=1,n do out[i]={minx=mnx[i],miny=mny[i],maxx=mxx[i],maxy=mxy[i]} end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local mnx=tcreat(n);local mny=tcreat(n);local mxx=tcreat(n);local mxy=tcreat(n)
		for i=1,n do local v=vals[i];mnx[i]=v.minx;mny[i]=v.miny;mxx[i]=v.maxx;mxy[i]=v.maxy end
		return interleavef32(mnx)..interleavef32(mny)..interleavef32(mxx)..interleavef32(mxy)
	end,
	xmltag="Rect2D",
	readxml=function(_, sub)
		local mn=type(sub.min)=="table" and sub.min or {}
		local mx=type(sub.max)=="table" and sub.max or {}
		return {minx=tonumber(mn.x or"0"),miny=tonumber(mn.y or"0"),maxx=tonumber(mx.x or"0"),maxy=tonumber(mx.y or"0")}
	end,
	writexml=function(v) return sfmt("<min><X>%g</X><Y>%g</Y></min><max><X>%g</X><Y>%g</Y></max>",v.minx,v.miny,v.maxx,v.maxy) end,
}

proptype[0x19]={
	name="PhysicalProperties",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local custom=sbyte(data,p)~=0; p+=1
			if custom then
				local d,f,e,fw,ew
				d,p=sunpack("<f",data,p); f,p=sunpack("<f",data,p); e,p=sunpack("<f",data,p)
				fw,p=sunpack("<f",data,p); ew,p=sunpack("<f",data,p)
				out[i]={custom=true,density=d,friction=f,elasticity=e,frictionweight=fw,elasticityweight=ew}
			else
				out[i]={custom=false}
			end
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1,n do
			local v=vals[i]
			if v.custom then
				pc+=1; parts[pc]="\x01"..spack("<fffff",v.density,v.friction,v.elasticity,v.frictionweight,v.elasticityweight)
			else
				pc+=1; parts[pc]="\x00"
			end
		end
		return tconc(parts)
	end,
	xmltag="PhysicalProperties",
	readxml=function(_, sub)
		if sub.customphysics=="true" then
			return {custom=true,density=tonumber(sub.density or"0"),friction=tonumber(sub.friction or"0"),
			        elasticity=tonumber(sub.elasticity or"0"),frictionweight=tonumber(sub.frictionweight or"0"),
			        elasticityweight=tonumber(sub.elasticityweight or"0")}
		end
		return {custom=false}
	end,
	writexml=function(v)
		if v.custom then
			return sfmt("<CustomPhysics>true</CustomPhysics><Density>%g</Density>"
.."<Friction>%g</Friction><Elasticity>%g</Elasticity>"
.."<FrictionWeight>%g</FrictionWeight><ElasticityWeight>%g</ElasticityWeight>",
				v.density,v.friction,v.elasticity,v.frictionweight,v.elasticityweight)
		end
		return "<CustomPhysics>false</CustomPhysics>"
	end,
}

proptype[0x1A]={
	name="Color3uint8",
	readbin=function(data, n)
		local out=tcreat(n); local n2=n*2
		for i=1,n do out[i]={r=sbyte(data,i), g=sbyte(data,n+i), b=sbyte(data,n2+i)} end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local rs=tcreat(n);local gs=tcreat(n);local bs=tcreat(n)
		for i=1,n do local v=vals[i]; rs[i]=chr[v.r%256]; gs[i]=chr[v.g%256]; bs[i]=chr[v.b%256] end
		return tconc(rs)..tconc(gs)..tconc(bs)
	end,
	xmltag="Color3uint8",
	readxml=function(_, sub) return {r=tonumber(sub.r or"0"),g=tonumber(sub.g or"0"),b=tonumber(sub.b or"0")} end,
	writexml=function(v) return sfmt("<R>%d</R><G>%d</G><B>%d</B>",v.r,v.g,v.b) end,
}

proptype[0x1B]={
	name="Int64",
	readbin=function(data, n)
		local out=tcreat(n)
		local n2,n3,n4,n5,n6,n7=n*2,n*3,n*4,n*5,n*6,n*7
		for i=1,n do
			local hi=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)
			local lo=sbyte(data,n4+i)*0x1000000+sbyte(data,n5+i)*0x10000+sbyte(data,n6+i)*0x100+sbyte(data,n7+i)
			local combined=hi*0x100000000+lo
			if b32band(lo,1)==0 then out[i]=mfloor(combined/2) else out[i]=-mfloor((combined+1)/2) end
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local by={}; for k=0,7 do by[k]=tcreat(n) end
		for i=1,n do
			local v=vals[i]; local raw=v>=0 and v*2 or-v*2-1
			local lo=raw%0x100000000; local hi=mfloor(raw/0x100000000)
			by[0][i]=chr[b32rsh(hi,24)%256]; by[1][i]=chr[b32rsh(hi,16)%256]
			by[2][i]=chr[b32rsh(hi,8)%256];  by[3][i]=chr[hi%256]
			by[4][i]=chr[b32rsh(lo,24)%256]; by[5][i]=chr[b32rsh(lo,16)%256]
			by[6][i]=chr[b32rsh(lo,8)%256];  by[7][i]=chr[lo%256]
		end
		local pc=0; local parts=tcreat(8)
		for k=0,7 do pc+=1; parts[pc]=tconc(by[k]) end
		return tconc(parts)
	end,
	xmltag="int64",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return tostring(mfloor(v or 0)) end,
}

proptype[0x1C]={
	name="SharedString",
	readbin=function(data, n) return deinterleaveu32(data, n) end,
	writebin=function(vals) return interleaveu32(vals) end,
	xmltag="SharedString",
	readxml=function(s) return s or "" end,
	writexml=function(v) return v or "" end,
}

proptype[0x1E]={
	name="OptionalCFrame",
	readbin=function(data, n)
		local p=2
		local specs=tcreat(n); local rots=tcreat(n)
		for i=1,n do
			local s=sbyte(data,p) or 0; p+=1
			if s==0 then
				local r=tcreat(9)
				for j=1,9 do r[j],p=sunpack("<f",data,p) end
				rots[i]=r
			else
				rots[i]=cf_special[s] or cf_identity
			end
			specs[i]=s
		end
		local xs=deinterleavef32(ssub(data,p,p+n*4-1),n); p+=n*4
		local ys=deinterleavef32(ssub(data,p,p+n*4-1),n); p+=n*4
		local zs=deinterleavef32(ssub(data,p,p+n*4-1),n); p+=n*4
		p+=1
		local out=tcreat(n)
		for i=1,n do
			out[i]=(sbyte(data,p+i-1) or 0)~=0 and {r=rots[i],x=xs[i],y=ys[i],z=zs[i]} or nil
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals
		local bools=tcreat(n); local pc=0; local cfbytes=tcreat(n*10)
		local xs=tcreat(n); local ys=tcreat(n); local zs=tcreat(n)
		for i=1,n do
			local v=vals[i]; local cf=v or {r=cf_identity,x=0,y=0,z=0}
			bools[i]=chr[v and 1 or 0]
			local r=cf.r or cf_identity
			local specid=findcfspecial(r)
			if specid then
				pc+=1; cfbytes[pc]=schar(specid)
			else
				pc+=1; cfbytes[pc]="\x00"
				for j=1,9 do pc+=1; cfbytes[pc]=spack("<f",r[j] or 0) end
			end
			xs[i]=cf.x or 0; ys[i]=cf.y or 0; zs[i]=cf.z or 0
		end
		return "\x10"..tconc(cfbytes,"",1,pc)..interleavef32(xs)..interleavef32(ys)..interleavef32(zs).."\x02"..tconc(bools)
	end,
	xmltag="OptionalCoordinateFrame",
	readxml=function(_, sub)
		if not sub or not sub.cframe then return nil end
		local cf=sub.cframe
		local function v(k) return tonumber(type(cf)=="table" and cf[k] or nil) or 0 end
		return {r={v"R00",v"R01",v"R02",v"R10",v"R11",v"R12",v"R20",v"R21",v"R22"}, x=v"X",y=v"Y",z=v"Z"}
	end,
	writexml=function(v)
		if not v then return "" end
		local r=v.r or cf_identity
		return "<CFrame>"
.."<X>"..safef(v.x).."</X><Y>"..safef(v.y).."</Y><Z>"..safef(v.z).."</Z>"
.."<R00>"..safef(r[1]).."</R00><R01>"..safef(r[2]).."</R01><R02>"..safef(r[3]).."</R02>"
.."<R10>"..safef(r[4]).."</R10><R11>"..safef(r[5]).."</R11><R12>"..safef(r[6]).."</R12>"
.."<R20>"..safef(r[7]).."</R20><R21>"..safef(r[8]).."</R21><R22>"..safef(r[9]).."</R22>"
.."</CFrame>"
	end,
}

proptype[0x1E2]={
	name="BinaryString",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p); p=np
			out[i]=ssub(data,p,p+len-1); p+=len
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n*2)
		for i=1,n do
			local v=vals[i] or ""
			pc+=1; parts[pc]=spack("<I4",#v)
			pc+=1; parts[pc]=v
		end
		return tconc(parts)
	end,
	xmltag="BinaryString",
	readxml=function(s) return base64decode(s or "") end,
	writexml=function(v) return base64encode(v or "") end,
}

proptype[0x1E3]={
	name="NetAssetRef",
	readbin=function(data, n) return deinterleaveu32(data, n) end,
	writebin=function(vals) return interleaveu32(vals) end,
	xmltag="NetAssetRef",
	readxml=function(s) return base64decode(s or "") end,
	writexml=function(v) return base64encode(v or "") end,
}

proptype[0x1E4]={
	name="ProtectedString",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p); p=np
			out[i]=ssub(data,p,p+len-1); p+=len
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n*2)
		for i=1,n do
			local v=vals[i]
			pc+=1; parts[pc]=spack("<I4",#v)
			pc+=1; parts[pc]=v
		end
		return tconc(parts)
	end,
	xmltag="ProtectedString",
	readxml=function(s) return s or "" end,
	writexml=function(v) return tostring(v or "") end,
}

proptype[0x1F]={
	name="UniqueId",
	readbin=function(data, n)
		local out=tcreat(n); local n4=n*4; local n2=n*2; local n3=n*3
		for i=1,n do
			local blob=tcreat(16); local base=0
			for f=0,3 do
				local seg=f*n4
				blob[base+1]=schar(sbyte(data,seg+i)   or 0)
				blob[base+2]=schar(sbyte(data,seg+n+i)  or 0)
				blob[base+3]=schar(sbyte(data,seg+n2+i) or 0)
				blob[base+4]=schar(sbyte(data,seg+n3+i) or 0)
				base+=4
			end
			out[i]=tconc(blob)
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local n2=n*2; local n3=n*3; local null=("\0"):rep(16)
		local g={}; for f=0,3 do g[f]=tcreat(n*4) end
		for i=1,n do
			local v=vals[i] or null
			for f=0,3 do
				local base=f*4
				g[f][i]=chr[sbyte(v,base+1) or 0]; g[f][n+i]=chr[sbyte(v,base+2) or 0]
				g[f][n2+i]=chr[sbyte(v,base+3) or 0]; g[f][n3+i]=chr[sbyte(v,base+4) or 0]
			end
		end
		local pc=0; local parts=tcreat(4)
		for f=0,3 do pc+=1; parts[pc]=tconc(g[f]) end
		return tconc(parts)
	end,
	xmltag="UniqueId",
	readxml=function(s)
		local hex=(s or ""):gsub("%s","")
		if #hex==0 then return ("\0"):rep(16) end
		local out=tcreat(16)
		for i=1,16 do out[i]=schar(tonumber(hex:sub(i*2-1,i*2),16) or 0) end
		return tconc(out)
	end,
	writexml=function(v)
		local out=tcreat(16)
		for i=1,16 do out[i]=sfmt("%02x",sbyte(v,i) or 0) end
		return tconc(out)
	end,
}

proptype[0x20]={
	name="Font",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local flen,np=sunpack("<I4",data,p); p=np
			local family=ssub(data,p,p+flen-1); p+=flen
			local weight,np2=sunpack("<I2",data,p); p=np2
			local style=sbyte(data,p); p+=1
			local clen,np3=sunpack("<I4",data,p); p=np3
			local cached=ssub(data,p,p+clen-1); p+=clen
			out[i]={family=family,weight=weight,style=style,cachedfaceid=cached}
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1,n do
			local v=vals[i]; local fam=v.family or ""; local cac=v.cachedfaceid or ""
			pc+=1; parts[pc]=spack("<I4",#fam)..fam..spack("<I2",v.weight or 400)..chr[v.style or 0]..spack("<I4",#cac)..cac
		end
		return tconc(parts)
	end,
	xmltag="Font",
	readxml=function(_, sub)
		local famsub=type(sub.family)=="table" and sub.family or {}
		local family=type(famsub.url)=="string" and famsub.url or (type(sub.family)=="string" and sub.family or "")
		local weightmap={thin=100,extralight=200,light=300,regular=400,medium=500,semibold=600,bold=700,extrabold=800,heavy=900}
		local stylemap={normal=0,italic=2}
		return {
			family=family,
			weight=tonumber(sub.weight) or weightmap[sub.weight or ""] or 400,
			style=stylemap[sub.style or "Normal"] or 0,
			cachedfaceid="",
		}
	end,
	writexml=function(v)
		local stylenames={[0]="Normal",[2]="Italic"}
		return "<Family><url>"..xmlescape(v.family or "").."</url></Family>"
.."<Weight>"..tostring(v.weight or 400).."</Weight>"
.."<Style>"..(stylenames[v.style or 0] or "Normal").."</Style>"
	end,
}

proptype[0x21]={
	name="SecurityCapabilities",
	readbin=function(data, n)
		local out=tcreat(n); local p=1
		for i=1,n do
			local lo,hi; lo,p=sunpack("<I4",data,p); hi,p=sunpack("<I4",data,p)
			out[i]=lo+hi*0x100000000
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local pc=0; local parts=tcreat(n)
		for i=1,n do
			local v=vals[i] or 0
			local lo=v%0x100000000; local hi=mfloor(v/0x100000000)%0x100000000
			pc+=1; parts[pc]=spack("<I4",lo)..spack("<I4",hi)
		end
		return tconc(parts)
	end,
	xmltag="SecurityCapabilities",
	readxml=function(s) return tonumber(s) or 0 end,
	writexml=function(v) return tostring(mfloor(v or 0)) end,
}

proptype[0x22]={
	name="Content",
	readbin=function(data, n)
		local out=tcreat(n)
		local srctypes=deinterleavei32(ssub(data,1,n*4),n); local p=n*4+1
		local uricount; uricount,p=sunpack("<I4",data,p)
		local uris=tcreat(uricount)
		for i=1,uricount do
			local ulen; ulen,p=sunpack("<I4",data,p); uris[i]=ssub(data,p,p+ulen-1); p+=ulen
		end
		local objcount; objcount,p=sunpack("<I4",data,p); p+=objcount*4
		p+=4
		local ui=0
		for i=1,n do
			if srctypes[i]==1 then ui+=1; out[i]=uris[ui] or "" else out[i]="" end
		end
		return out
	end,
	writebin=function(vals)
		local n=#vals; local srctypeints=tcreat(n); local uriparts={}; local uc=0
		for i=1,n do
			local v=tostring(vals[i] or "")
			if v~="" then srctypeints[i]=1; uc+=1; uriparts[uc]=spack("<I4",#v)..v
			else srctypeints[i]=0 end
		end
		return interleavei32(srctypeints)..spack("<I4",uc)..tconc(uriparts)..spack("<I4",0)..spack("<I4",0)
	end,
	xmltag="Content",
	readxml=function(text, sub)
		if type(sub)=="table" then
			if type(sub.uri)=="string" then return sub.uri end
			if type(sub.url)=="string" and sub.url~="" then return sub.url end
			if sub.null~=nil then return "" end
		end
		return text or ""
	end,
	writexml=function(v)
		v=tostring(v or "")
		return v=="" and "<null></null>" or "<url>"..xmlescape(v).."</url>"
	end,
}

-- ────────────────────────────────────────────────────────────
-- XML tag → typeId map
-- ────────────────────────────────────────────────────────────
local xmltagtotypeid={}
for id, info in pairs(proptype) do
	if info.xmltag then xmltagtotypeid[info.xmltag]=id end
end
xmltagtotypeid["string"]=0x01
xmltagtotypeid["bool"]=0x02
xmltagtotypeid["int"]=0x03
xmltagtotypeid["float"]=0x04
xmltagtotypeid["double"]=0x05
xmltagtotypeid["BinaryString"]=0x1E2
xmltagtotypeid["ProtectedString"]=0x1E4
xmltagtotypeid["UniqueId"]=0x1F
xmltagtotypeid["Font"]=0x20
xmltagtotypeid["SecurityCapabilities"]=0x21
xmltagtotypeid["OptionalCoordinateFrame"]=0x1E
xmltagtotypeid["Content"]=0x22
xmltagtotypeid["NetAssetRef"]=0x1E3

local function gettype(id)
	return proptype[id] or {
		name="Unknown("..sfmt("0x%02X",id)..")",
		readbin=function() return {} end,
		writebin=function() return "" end,
		xmltag="BinaryString",
		readxml=function(s) return s end,
		writexml=function(v) return tostring(v or "") end,
	}
end

-- ────────────────────────────────────────────────────────────
-- Known property sets
-- ────────────────────────────────────────────────────────────
local content_props={
	SoundId=true,Image=true,HoverImage=true,PressedImage=true,Texture=true,LinkedSource=true,
	MeshId=true,TextureId=true,TextureID=true,SkyboxBk=true,SkyboxDn=true,SkyboxFt=true,
	SkyboxLf=true,SkyboxRt=true,SkyboxUp=true,AnimationId=true,ShirtTemplate=true,
	PantsTemplate=true,ContentId=true,GraphicId=true,OverlayTextureId=true,BaseTextureId=true,
	NormalMap=true,VideoSource=true,AssetId=true,EmissiveMaskContent=true,ColorMaskContent=true,
	MetalnessContent=true,RoughnessContent=true,NormalContent=true,
}

local binary_string_props={
	AttributesSerialize=true,Tags=true,PhysicsData=true,PhysicsGrid=true,LevelOfDetailData=true,
	TerrainColors=true,TerrainMaterialColors=true,SmoothGrid=true,ClusterGrid=true,
	CollisionGroupData=true,MaterialColors=true,HiddenServices=true,VisibleServices=true,
}

local netasset_props={SolidMeshHolder=true}

local class_string_props={
	Animation={AnimationId=true},
	Beam={Texture=true},
	Decal={Texture=true,NormalMap=true},
	ImageButton={Image=true,HoverImage=true,PressedImage=true},
	ImageLabel={Image=true},
	LocalScript={LinkedSource=true},
	MaterialVariant={NormalMap=true},
	MeshPart={MeshId=true,TextureID=true},
	ModuleScript={LinkedSource=true},
	Pants={PantsTemplate=true},
	ParticleEmitter={Texture=true},
	Script={LinkedSource=true},
	Shirt={ShirtTemplate=true},
	Sky={SkyboxBk=true,SkyboxDn=true,SkyboxFt=true,SkyboxLf=true,SkyboxRt=true,SkyboxUp=true},
	Sound={SoundId=true},
	SpecialMesh={MeshId=true,TextureId=true},
	Texture={Texture=true,NormalMap=true},
	UnionOperation={AssetId=true},
}

-- ────────────────────────────────────────────────────────────
-- Binary parser
-- ────────────────────────────────────────────────────────────
local function parsebinary(data)
	assert(ssub(data,1,16)==rbx_magic, "Not a valid .rbxm binary file")
	local pos=17
	local _,np2=sunpack("<I4",data,pos); pos=np2
	local _,np3=sunpack("<I4",data,pos); pos=np3
	pos+=8
	local typemap={}; local instmap={}; local sharedstrs={}; local roots={}; local rc=0
	while pos<=#data do
		if pos+15>#data then break end
		local chunkname=ssub(data,pos,pos+3); pos+=4
		local clen=sunpack("<I4",data,pos); pos+=4
		local ulen=sunpack("<I4",data,pos); pos+=4
		pos+=4
		if type(clen)~="number" or type(ulen)~="number"
			or clen<0 or ulen<0 or clen>#data or ulen>#data*8 then break end
		if ssub(chunkname,1,3)=="END" then break end
		local payload
		if clen==0 then
			if pos+ulen-1<=#data then payload=ssub(data,pos,pos+ulen-1) end
			pos=mmin(pos+ulen, #data+1)
		else
			if pos+clen-1<=#data then
				local ok,result=pcall(lz4decompress, ssub(data,pos,pos+clen-1), ulen)
				if ok then payload=result end
			end
			pos=mmin(pos+clen, #data+1)
		end
		if payload==nil then continue end
		if chunkname=="META" then
			-- metadata chunk, skip
		elseif chunkname=="SSTR" then
			pcall(function()
				local sp=1
				local _,np=sunpack("<I4",payload,sp); sp=np
				local count,np2=sunpack("<I4",payload,sp); sp=np2
				for i=1,count do
					local key=ssub(payload,sp,sp+15); sp+=16
					local s,np3=sunpack("<s4",payload,sp); sp=np3
					sharedstrs[i-1]={blob=s, key=key}
				end
			end)
		elseif chunkname=="INST" then
			pcall(function()
				local sp=1
				local typeidx,np1=sunpack("<I4",payload,sp); sp=np1
				local cnlen,np2=sunpack("<I4",payload,sp); sp=np2
				local classname=ssub(payload,sp,sp+cnlen-1); sp+=cnlen
				local isservice=sbyte(payload,sp)~=0; sp+=1
				local count,np3=sunpack("<I4",payload,sp); sp=np3
				local refs=deinterleaveref(ssub(payload,sp,sp+count*4-1),count); sp+=count*4
				if isservice then sp+=count end
				typemap[typeidx]={classname=classname, count=count, referents=refs}
				for i=1,count do
					local ref=refs[i]
					instmap[ref]={referent=ref,classname=classname,isservice=isservice,properties={},children={},parent=nil}
				end
			end)
		elseif chunkname=="PROP" then
			pcall(function()
				local sp=1
				local typeidx,np1=sunpack("<I4",payload,sp); sp=np1
				local pnlen,np2=sunpack("<I4",payload,sp); sp=np2
				local propname=ssub(payload,sp,sp+pnlen-1); sp+=pnlen
				local typeid=sbyte(payload,sp); sp+=1
				local ti=typemap[typeidx]
				if typeid==0x01 and binary_string_props[propname] then typeid=0x1E2 end
				if typeid==0x1C and netasset_props[propname]      then typeid=0x1E3 end
				if not ti then return end
				local typeinfo=gettype(typeid)
				local ok2,values=pcall(typeinfo.readbin, ssub(payload,sp), ti.count)
				if not ok2 then return end
				local refs=ti.referents
				for i=1,#refs do
					local inst=instmap[refs[i]]
					if inst and values[i]~=nil then
						inst.properties[propname]={typeid=typeid, value=values[i]}
					end
				end
			end)
		elseif chunkname=="PRNT" then
			pcall(function()
				local sp=2
				local count,np=sunpack("<I4",payload,sp); sp=np
				local childrefs=deinterleaveref(ssub(payload,sp,sp+count*4-1),count)
				local parentrefs=deinterleaveparentref(ssub(payload,sp+count*4,sp+count*8-1),count)
				for i=1,count do
					local child=instmap[childrefs[i]]
					local parent=instmap[parentrefs[i]]
					if child then
						child.parent=parent
						if parent then
							local cc=#parent.children+1; parent.children[cc]=child
						else
							rc+=1; roots[rc]=child
						end
					end
				end
			end)
		end
	end
	-- fallback root discovery
	if rc==0 and next(instmap) then
		for _,inst in pairs(instmap) do
			if inst.parent==nil then rc+=1; roots[rc]=inst end
		end
	end
	if rc==0 and next(instmap) then
		local ischild={}
		for _,inst in pairs(instmap) do
			local ch=inst.children
			for i=1,#ch do ischild[ch[i].referent]=true end
		end
		for _,inst in pairs(instmap) do
			if not ischild[inst.referent] then rc+=1; roots[rc]=inst end
		end
	end
	if rc==0 and next(instmap) then
		for _,inst in pairs(instmap) do
			inst.children={}; rc+=1; roots[rc]=inst
		end
	end
	local sharedblobs={}; local sharedkeys={}
	for idx,entry in pairs(sharedstrs) do
		sharedblobs[idx]=entry.blob; sharedkeys[idx]=entry.key
	end
	return roots, sharedblobs, sharedkeys
end

-- ────────────────────────────────────────────────────────────
-- XML tokeniser
-- ────────────────────────────────────────────────────────────
local function tokenize(xml)
	local tc=0; local tokens={}; local pos=1; local n=#xml
	while pos<=n do
		local c=sbyte(xml,pos)
		if c~=60 then
			local e=sfind(xml,"<",pos,true)
			local text=ssub(xml,pos,e and e-1 or n); pos=e or n+1
			if sfind(text,"%S") then
				if sfind(text,"&",1,true) then text=xmlunescape(text) end
				tc+=1; tokens[tc]={type="text",text=text}
			end
		else
			local c2=sbyte(xml,pos+1)
			if c2==33 then
				local c3=sbyte(xml,pos+2)
				if c3==45 and sbyte(xml,pos+3)==45 then
					local e=sfind(xml,"-->",pos+4,true); pos=e and e+3 or n+1
				elseif c3==91 and ssub(xml,pos,pos+8)=="<![CDATA[" then
					local e=sfind(xml,"]]>",pos+9,true)
					if e then
						tc+=1; tokens[tc]={type="text",text=ssub(xml,pos+9,e-1)}; pos=e+3
					else pos=n+1 end
				else
					local e=sfind(xml,">",pos+2,true); pos=e and e+1 or n+1
				end
			elseif c2==63 then
				local e=sfind(xml,"?>",pos+2,true); pos=e and e+2 or n+1
			elseif c2==47 then
				local e=sfind(xml,">",pos+2,true); if not e then break end
				local name=ssub(xml,pos+2,e-1):match("^%s*([%w:_%.-]*)%s*")
				tc+=1; tokens[tc]={type="close",name=name}; pos=e+1
			else
				local e=sfind(xml,">",pos+1,true); if not e then break end
				local tag=ssub(xml,pos+1,e-1); pos=e+1
				local selfclose=sbyte(tag,#tag)==47
				if selfclose then tag=ssub(tag,1,-2) end
				local tname=tag:match("^%s*([%w:_%.-]+)")
				if tname then
					local attrs={}
					for k,v in tag:gmatch('%s+([%w:_%-]+)%s*=%s*"([^"]*)"') do
						attrs[k]=sfind(v,"&",1,true) and xmlunescape(v) or v
					end
					for k,v in tag:gmatch("%s+([%w:_%-]+)%s*=%s*'([^']*)'") do
						attrs[k]=sfind(v,"&",1,true) and xmlunescape(v) or v
					end
					tc+=1; tokens[tc]={type=selfclose and "selfclose" or "open", name=tname, attrs=attrs}
				end
			end
		end
	end
	return tokens
end

-- ────────────────────────────────────────────────────────────
-- XML element parsers
-- ────────────────────────────────────────────────────────────
local function parseelement(tokens, ti, closename)
	local text=""; local sub={}; local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]
		if tok.type=="close" and tok.name==closename then
			return text:match("^%s*(.-)%s*$"), sub, ti+1
		elseif tok.type=="text" then
			text..=tok.text; ti+=1
		elseif tok.type=="open" then
			local childname=tok.name; ti+=1
			local childtext,childsub,newti=parseelement(tokens,ti,childname); ti=newti
			sub[childname]=next(childsub) and childsub or childtext
		elseif tok.type=="selfclose" then
			sub[tok.name]=""; ti+=1
		else
			ti+=1
		end
	end
	return text:match("^%s*(.-)%s*$"), sub, ti
end

local function parseproperties(tokens, ti)
	local props={}; local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]
		if tok.type=="close" and tok.name=="Properties" then
			return props, ti+1
		elseif tok.type=="open" or tok.type=="selfclose" then
			local proptag=tok.name
			local propname=tok.attrs and tok.attrs.name
			if tok.type=="selfclose" then
				if propname then props[propname]={xmltag=proptag,text="",sub={}} end
				ti+=1
			else
				ti+=1
				local text,sub,newti=parseelement(tokens,ti,proptag); ti=newti
				if propname then props[propname]={xmltag=proptag,text=text,sub=sub} end
			end
		else
			ti+=1
		end
	end
	return props, ti
end

local parsexmlitems
parsexmlitems=function(tokens, ti, refcounter, stoptag)
	stoptag=stoptag or "roblox"
	local nc_=0; local nodes={}; local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]
		if tok.type=="close" then
			if tok.name==stoptag then return nodes, ti
			else ti+=1 end
		elseif tok.type=="open" and tok.name=="Item" then
			local classname=tok.attrs and tok.attrs.class or "Unknown"
			local xmlref=tok.attrs and tok.attrs.referent or nil
			refcounter[1]+=1
			local node={referent=refcounter[1],classname=classname,xmlref=xmlref,properties={},children={},parent=nil}
			ti+=1; local nch=0
			while ti<=nt do
				local inner=tokens[ti]
				if inner.type=="close" and inner.name=="Item" then
					ti+=1; break
				elseif inner.type=="open" and inner.name=="Properties" then
					ti+=1
					local props,newti=parseproperties(tokens,ti); ti=newti; node.properties=props
				elseif inner.type=="open" and inner.name=="Item" then
					local children,newti=parsexmlitems(tokens,ti,refcounter,"Item"); ti=newti
					for i=1,#children do
						local child=children[i]; nch+=1
						child.parent=node; node.children[nch]=child
					end
				else
					ti+=1
				end
			end
			nc_+=1; nodes[nc_]=node
		else
			ti+=1
		end
	end
	return nodes, ti
end

local function parsexml(xml)
	local tokens=tokenize(xml); local ti=1; local nt=#tokens
	while ti<=nt and not (tokens[ti].type=="open" and tokens[ti].name=="roblox") do
		ti+=1
	end
	if ti>nt then error("RBXConverter: no <roblox> root element found") end
	ti+=1
	local refcounter={0}; local xmlsharedstrings={}; local tmpti=ti
	while tmpti<=nt do
		local tok=tokens[tmpti]
		if tok.type=="open" and tok.name=="SharedStrings" then
			tmpti+=1
			while tmpti<=nt do
				local t=tokens[tmpti]
				if t.type=="close" and t.name=="SharedStrings" then tmpti+=1; break end
				if t.type=="open" and t.name=="SharedString" then
					local key=t.attrs and t.attrs.md5 or ""
					tmpti+=1; local content=""
					while tmpti<=nt do
						local t2=tokens[tmpti]
						if t2.type=="close" and t2.name=="SharedString" then tmpti+=1; break end
						if t2.type=="text" then content..=t2.text end
						tmpti+=1
					end
					xmlsharedstrings[key]=base64decode(content)
				else
					tmpti+=1
				end
			end
			break
		elseif tok.type=="open" and tok.name=="Item" then
			break
		else
			tmpti+=1
		end
	end
	local roots,_=parsexmlitems(tokens,ti,refcounter,"roblox")
	return roots, xmlsharedstrings
end

-- ────────────────────────────────────────────────────────────
-- Binary serialiser
-- ────────────────────────────────────────────────────────────
local function serializebinary(roots, xmlsharedstrings)
	local allinsts={}
	local function collect(node)
		local ac=#allinsts+1; allinsts[ac]=node
		local ch=node.children
		for i=1,#ch do collect(ch[i]) end
	end
	for i=1,#roots do collect(roots[i]) end
	local na=#allinsts
	local refmap={}
	for i=1,na do refmap[allinsts[i]]=i-1 end
	local xmlrefnodemap={}
	for i=1,na do
		local inst=allinsts[i]
		if inst.xmlref then xmlrefnodemap[inst.xmlref]=inst end
	end
	local sstrblobs={}; local sstrkeytoidx={}; local sc=0
	if xmlsharedstrings and next(xmlsharedstrings) then
		sc+=1; sstrblobs[sc]=""; sstrkeytoidx[""]=0
		for key,blob in pairs(xmlsharedstrings) do
			sc+=1; sstrblobs[sc]=blob; sstrkeytoidx[key]=sc-1
		end
	end
	local typeorder={}; local typeindexmap={}; local toc=0
	for i=1,na do
		local cn=allinsts[i].classname
		if not typeindexmap[cn] then
			toc+=1; typeindexmap[cn]=toc; typeorder[toc]=cn
		end
	end
	local classgroups={}
	for i=1,na do
		local cn=allinsts[i].classname
		local g=classgroups[cn]; if not g then g={}; classgroups[cn]=g end
		g[#g+1]=allinsts[i]
	end
	local ic=0; local instchunks=tcreat(toc)
	for ti=1,toc do
		local classname=typeorder[ti]; local group=classgroups[classname]; local ng=#group
		local refs=tcreat(ng)
		for i=1,ng do refs[i]=refmap[group[i]] end
		local payload=spack("<I4",ti-1)..spack("<I4",#classname)..classname.."\x00"..spack("<I4",ng)..interleaveref(refs)
		ic+=1; instchunks[ic]=makechunk("INST",payload)
	end
	local propnames={}
	for i=1,na do
		local inst=allinsts[i]; local cn=inst.classname
		local pm=propnames[cn]; if not pm then pm={}; propnames[cn]=pm end
		for pname in pairs(inst.properties) do pm[pname]=true end
	end
	local protected_string_props={}; local pcc=0; local propchunks={}
	for ti=1,toc do
		local classname=typeorder[ti]; local group=classgroups[classname]; local ng=#group
		local pnames={}; local pnc=0
		for pname in pairs(propnames[classname] or {}) do pnc+=1; pnames[pnc]=pname end
		tsort(pnames)
		for pi=1,pnc do
			local pname=pnames[pi]; local typeid=nil; local vals=tcreat(ng)
			for i=1,ng do
				local prop=group[i].properties[pname]
				if prop and type(prop)=="table" then
					if prop.typeid then
						if not typeid then typeid=prop.typeid end
						vals[i]=prop.value
					elseif prop.xmltag then
						local tid=xmltagtotypeid[prop.xmltag] or 0x01
						if tid==0x01 and content_props[pname]
							and not (class_string_props[classname] and class_string_props[classname][pname]) then
							tid=0x22
						end
						if not typeid then typeid=tid end
						local v=gettype(tid).readxml(prop.text or "", prop.sub or {})
						if v~=nil then
							if tid==0x1C then
								local key=prop.text or ""
								local idx=sstrkeytoidx[key]
								if idx==nil then sc+=1; sstrblobs[sc]=""; sstrkeytoidx[key]=sc-1; idx=sc-1 end
								vals[i]=idx
							elseif tid==0x1E3 then
								local blob=base64decode(prop.text or "")
								local idx=sstrkeytoidx[blob]
								if idx==nil then sc+=1; sstrblobs[sc]=blob; sstrkeytoidx[blob]=sc-1; idx=sc-1 end
								vals[i]=idx
							elseif tid==0x13 and v and v~=-1 then
								local refnode=xmlrefnodemap[prop.text or ""]
								vals[i]=refnode and refmap[refnode] or v
							else
								vals[i]=v
							end
						end
					end
				end
			end
			if not typeid then continue end
			if class_string_props[classname] and class_string_props[classname][pname] then typeid=0x01 end
			local typeinfo=gettype(typeid)
			for i=1,ng do
				if vals[i]==nil then
					if     typeid==0x01 then vals[i]=""
					elseif typeid==0x02 then vals[i]=false
					elseif typeid==0x03 or typeid==0x04 or typeid==0x05
					    or typeid==0x0B or typeid==0x12 then vals[i]=0
					elseif typeid==0x0C then vals[i]={r=0,g=0,b=0}
					elseif typeid==0x0E then vals[i]={x=0,y=0,z=0}
					elseif typeid==0x10 then vals[i]={r=cf_identity,x=0,y=0,z=0}
					elseif typeid==0x13 then vals[i]=-1
					elseif typeid==0x1E then vals[i]=false
					elseif typeid==0x1E2 or typeid==0x1E4 then vals[i]=""
					elseif typeid==0x1F  then vals[i]=("\0"):rep(16)
					elseif typeid==0x20  then vals[i]={family="",weight=400,style=0,cachedfaceid=""}
					elseif typeid==0x21  then vals[i]=0
					elseif typeid==0x22  then vals[i]=""
					else vals[i]=0 end
				end
			end
			local bindata=typeinfo.writebin(vals)
			if bindata and #bindata>0 then
				local bintypeid
				if     typeid==0x22 and not (class_string_props[classname] and class_string_props[classname][pname]) then bintypeid=0x22
				elseif typeid==0x1E2 then bintypeid=0x01
				elseif typeid==0x1E3 then bintypeid=0x1C
				elseif typeid==0x1E4 and not protected_string_props[pname] then bintypeid=0x01
				else   bintypeid=typeid end
				local payload=spack("<I4I4",ti-1,#pname)..pname..chr[bintypeid]..bindata
				pcc+=1; propchunks[pcc]=makechunk("PROP",payload)
			end
		end
	end
	local sstrchunk
	if sc>0 then
		local sp=0; local sparts=tcreat(sc*2+2)
		sp+=1; sparts[sp]=spack("<I4",0)
		sp+=1; sparts[sp]=spack("<I4",sc)
		for i=1,sc do
			local blob=sstrblobs[i]
			sp+=1; sparts[sp]=newblobkey()
			sp+=1; sparts[sp]=spack("<I4",#blob)..blob
		end
		sstrchunk=makechunk("SSTR",tconc(sparts))
	end
	local childrefs=tcreat(na); local parentrefs=tcreat(na)
	for i=1,na do
		local inst=allinsts[i]
		childrefs[i]=refmap[inst]
		parentrefs[i]=inst.parent and refmap[inst.parent] or-1
	end
	local prntpayload="\x00"..spack("<I4",na)..interleaveref(childrefs)..interleaveparentref(parentrefs)
	local prntchunk=makechunk("PRNT",prntpayload)
	local endpayload="</roblox>"
	local endchunk="END\0"..spack("<I4",0)..spack("<I4",#endpayload)..spack("<I4",0)..endpayload
	local header=rbx_magic..spack("<I4",toc)..spack("<I4",na)..spack("<I4",0)..spack("<I4",0)
	local fp=0; local final=tcreat(4+ic+pcc)
	fp+=1; final[fp]=header
	if sstrchunk then fp+=1; final[fp]=sstrchunk end
	for i=1,ic  do fp+=1; final[fp]=instchunks[i] end
	for i=1,pcc do fp+=1; final[fp]=propchunks[i] end
	fp+=1; final[fp]=prntchunk
	fp+=1; final[fp]=endchunk
	return tconc(final)
end

-- ────────────────────────────────────────────────────────────
-- XML serialiser
-- ────────────────────────────────────────────────────────────
local function serializexml(roots, sharedstrs, sharedkeys)
	local lc=0; local lines={}
	lc+=1; lines[lc]='<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime"'
..' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'
..' xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd"'
..' version="4">'
	local blobkeycache={}
	if sharedkeys and sharedstrs then
		local usedkeys={}
		for idx,key in pairs(sharedkeys) do
			local blob=sharedstrs[idx]
			if blob and not blobkeycache[blob] and not usedkeys[key] then
				blobkeycache[blob]=key; usedkeys[key]=true
			end
		end
	end
	local function getblobkey(blob)
		if not blobkeycache[blob] then blobkeycache[blob]=newblobkey() end
		return blobkeycache[blob]
	end
	local sharedblobbymd5={}
	local function collectsharedblobs(node)
		for pname,prop in pairs(node.properties) do
			if type(prop)=="table" and prop.typeid==0x1C and not content_props[pname] then
				local idx=prop.value
				if type(idx)=="number" and sharedstrs and sharedstrs[idx] then
					local blob=sharedstrs[idx]
					sharedblobbymd5[getblobkey(blob)]=blob
				end
			end
		end
		local ch=node.children
		for i=1,#ch do collectsharedblobs(ch[i]) end
	end
	if sharedstrs then
		for i=1,#roots do collectsharedblobs(roots[i]) end
	end
	if next(sharedblobbymd5) then
		lc+=1; lines[lc]="\t<SharedStrings>"
		for key,blob in pairs(sharedblobbymd5) do
			local keyb64=base64encode(key); local blobb64=base64encode(blob); local nb=#blobb64
			local wc=0; local wrapped=tcreat(mceil(nb/76))
			for i=1,nb,76 do wc+=1; wrapped[wc]="\t\t\t"..ssub(blobb64,i,i+75) end
			lc+=1; lines[lc]='\t\t<SharedString md5="'..keyb64..'">'
			lc+=1; lines[lc]=tconc(wrapped,"\n")
			lc+=1; lines[lc]="\t\t</SharedString>"
		end
		lc+=1; lines[lc]="\t</SharedStrings>"
	end
	local tabcache=tcreat(8)
	for d=0,7 do tabcache[d]=srep("\t",d) end
	local function gettab(d) return tabcache[d] or srep("\t",d) end
	local function writenode(node, indent)
		local tab=gettab(indent); local tab1=gettab(indent+1); local tab2=gettab(indent+2)
		lc+=1; lines[lc]=tab..'<Item class="'..xmlescape(node.classname)..'" referent="RBX'..sfmt("%08X",node.referent)..'">'
		lc+=1; lines[lc]=tab1.."<Properties>"
		local pnames={}; local pnc=0
		for pname in pairs(node.properties) do pnc+=1; pnames[pnc]=pname end
		tsort(pnames)
		for pi=1,pnc do
			local pname=pnames[pi]; local prop=node.properties[pname]; local typeid,value
			if type(prop)=="table" and prop.typeid then
				typeid=prop.typeid; value=prop.value
			elseif type(prop)=="table" and prop.xmltag then
				typeid=xmltagtotypeid[prop.xmltag] or 0x01
				value=gettype(typeid).readxml(prop.text, prop.sub or {})
			else continue end
			if typeid==0x01 and content_props[pname] then typeid=0x22 end
			if typeid==0x1C or typeid==0x1E3 then
				local idx=type(value)=="number" and value or tonumber(value) or 0
				local blob=sharedstrs and sharedstrs[idx] or ""
				if content_props[pname] then
					typeid=0x22; value=blob
				elseif typeid==0x1E3 then
					value=blob
				else
					value=base64encode(getblobkey(blob))
				end
			end
			local typeinfo=gettype(typeid); local tag=typeinfo.xmltag
			local ok,inner=pcall(typeinfo.writexml,value)
			if ok then
				local encoded
				if typeid==0x1E4 then
					local sv=tostring(inner or "")
					if sv:find("[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]") then
						encoded=base64encode(sv); tag="BinaryString"
					else encoded="<![CDATA["..sv.."]]>" end
				elseif typeid==0x01 or typeid==0x02 or typeid==0x03 or typeid==0x04
				    or typeid==0x05 or typeid==0x0B or typeid==0x12 or typeid==0x15
				    or typeid==0x16 or typeid==0x17 or typeid==0x1B or typeid==0x1C
				    or typeid==0x21 then
					local sv=tostring(inner or "")
					if sv:find("[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]") then
						encoded=base64encode(sv); tag="BinaryString"
					else encoded=xmlescape(sv) end
				else
					encoded=inner
				end
				lc+=1; lines[lc]=tab2.."<"..tag..' name="'..xmlescape(pname)..'">'..encoded.."</"..tag..">"
			end
		end
		lc+=1; lines[lc]=tab1.."</Properties>"
		local ch=node.children
		for i=1,#ch do writenode(ch[i],indent+1) end
		lc+=1; lines[lc]=tab.."</Item>"
	end
	for i=1,#roots do writenode(roots[i],1) end
	lc+=1; lines[lc]="</roblox>"
	return tconc(lines,"\n")
end

-- ────────────────────────────────────────────────────────────
-- Public API  (wrapped with newcclosure for exploit safety)
-- ────────────────────────────────────────────────────────────
converter.XMLToBinary=nc(function(xmlstring)
	assert(type(xmlstring)=="string" and #xmlstring>0, "XMLToBinary: expected a non-empty XML string")
	local roots, xmlsharedstrings=parsexml(xmlstring)
	assert(#roots>0, "XMLToBinary: no instances found in XML string")
	return serializebinary(roots, xmlsharedstrings)
end)

converter.BinaryToXML=nc(function(binarystring)
	assert(type(binarystring)=="string" and #binarystring>0, "BinaryToXML: expected a non-empty binary string")
	local roots, sharedstrs, sharedkeys=parsebinary(binarystring)
	assert(#roots>0, "BinaryToXML: no instances found in binary string")
	return serializexml(roots, sharedstrs, sharedkeys)
end)

return converter
