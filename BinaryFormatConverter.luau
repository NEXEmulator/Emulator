local Converter={NEX_Version="1.0.2"}local b32=bit32
local spack,sunpack=string.pack,string.unpack
local tconc,tcreat,tsort,tunpack=table.concat,table.create,table.sort,table.unpack
local mfloor,mabs,mceil,mmin=math.floor,math.abs,math.ceil,math.min
local HUGE=math.huge
local schar,sfmt,sfind,ssub,sbyte=string.char,string.format,string.find,string.sub,string.byte
local srep=string.rep
local b32rsh,b32band,b32bor,b32lsh=b32.rshift,b32.band,b32.bor,b32.lshift
local pairs,ipairs,next,pcall,type,tonumber,tostring=pairs,ipairs,next,pcall,type,tonumber,tostring
local HttpService=game:GetService("HttpService")local chr=tcreat(256)for _i=0,255 do chr[_i]=schar(_i)end
local function newBlobKey()local g=HttpService:GenerateGUID(false):gsub("-","")local b=tcreat(16)for i=1,16 do b[i]=schar(tonumber(g:sub(i*2-1,i*2),16))end
	return tconc(b)end
local function lz4Decompress(src,uncompSize)local out=tcreat(uncompSize+64,0)local si=1
	local oi=1
	local slen=#src
	while si<=slen do
		local tok=sbyte(src,si);si+=1
		local ll=b32rsh(tok,4)if ll==15 then
			repeat
				local e=sbyte(src,si)or 0;si+=1;ll+=e
			until e~=255
		end
		local si_end=si+ll-1
		while si<=si_end do
			local ce=mmin(si+199,si_end)local nb=ce-si+1
			if nb==1 then
				out[oi]=sbyte(src,si);oi+=1;si+=1
			elseif nb==2 then
				local a,b=sbyte(src,si,si+1)out[oi]=a;out[oi+1]=b;oi+=2;si+=2
			else
				local bytes={sbyte(src,si,ce)}for k=1,nb do out[oi]=bytes[k];oi+=1 end
				si+=nb
			end
		end
		if si>slen then break end
		local b0=sbyte(src,si)or 0;si+=1
		local b1=sbyte(src,si)or 0;si+=1
		local offset=b0+b1*256
		if offset==0 then break end
		local ml=b32band(tok,0xF)+4
		if b32band(tok,0xF)==15 then
			repeat
				local e=sbyte(src,si)or 0;si+=1;ml+=e
			until e~=255
		end
		local ms=oi-offset
		for _=1,ml do
			out[oi]=(ms>=1)and(out[ms]or 0)or 0;oi+=1;ms+=1
		end
	end
	local BATCH=200
	local rc=0
	local r=tcreat(mceil((oi-1)/BATCH))for i=1,oi-1,BATCH do
		rc+=1;r[rc]=schar(tunpack(out,i,mmin(i+BATCH-1,oi-1)))end
	return tconc(r)end
local function lz4Compress(src)local n=#src
	if n==0 then return "\x00" end
	local limit=n-12
	local htBits=16
	while htBits<20 and b32lsh(1,htBits)<n do htBits+=1 end
	local HTSIZE=b32lsh(1,htBits)local htShift=32-htBits
	local M=2654435761
	local ht=tcreat(HTSIZE,0)local prev=tcreat(n+1,0)local MAX_DEPTH=16
	local oc=0;local out={}local anchor=1
	local ip=1
	local function hash4(b0,b1,b2,b3)local lo=b32band((b0+b1*256)*M,0xFFFFFFFF)local hi=b32band((b2+b3*256)*M,0xFFFFFFFF)return b32rsh(b32band(lo+b32lsh(hi,16),0xFFFFFFFF),htShift)+1
	end
	while ip<=limit do
		local b0,b1,b2,b3=sbyte(src,ip,ip+3)local h=hash4(b0,b1,b2,b3)prev[ip]=ht[h];ht[h]=ip
		local best_ml=3;local best_ref=0
		local maxMl=n-4-ip
		local pos=prev[ip];local depth=0
		while pos>0 and depth<MAX_DEPTH do
			if ip-pos>65535 then break end
			local r0,r1,r2,r3=sbyte(src,pos,pos+3)if r0==b0 and r1==b1 and r2==b2 and r3==b3 then
				local ml=4
				while ml+8<=maxMl and ssub(src,ip+ml,ip+ml+7)==ssub(src,pos+ml,pos+ml+7)do ml+=8 end
				while ml<maxMl and sbyte(src,ip+ml)==sbyte(src,pos+ml)do ml+=1 end
				if ml>best_ml then
					best_ml=ml;best_ref=pos
					if ml>=maxMl then break end
				end
			end
			pos=prev[pos];depth+=1
		end
		if best_ref>0 then
			local ll=ip-anchor;local ml4=best_ml-4;local offset=ip-best_ref
			oc+=1;out[oc]=schar(mmin(ll,15)*16+mmin(ml4,15))if ll>=15 then
				local r=ll-15
				while r>=255 do oc+=1;out[oc]="\xff";r-=255 end
				oc+=1;out[oc]=schar(r)end
			if ll>0 then oc+=1;out[oc]=ssub(src,anchor,ip-1)end
			oc+=1;out[oc]=schar(offset%256)oc+=1;out[oc]=schar(mfloor(offset/256))if ml4>=15 then
				local r=ml4-15
				while r>=255 do oc+=1;out[oc]="\xff";r-=255 end
				oc+=1;out[oc]=schar(r)end
			ip=ip+best_ml;anchor=ip
		else
			ip+=1
		end
	end
	local ll=n-anchor+1
	oc+=1;out[oc]=schar(mmin(ll,15)*16)if ll>=15 then
		local r=ll-15
		while r>=255 do oc+=1;out[oc]="\xff";r-=255 end
		oc+=1;out[oc]=schar(r)end
	oc+=1;out[oc]=ssub(src,anchor,n)return tconc(out,"",1,oc)end
local function zzDec(v)return b32band(v,1)==0 and b32rsh(v,1)or-(b32rsh(v,1)+1)end
local function zzEnc(v)return v>=0 and v*2 or-v*2-1 end
local function deinterleaveU32(data,n)local out=tcreat(n)local n2,n3=n*2,n*3
	for i=1,n do
		out[i]=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)end
	return out
end
local function interleaveU32(vals)local n=#vals
	local n2,n3=n*2,n*3
	local out=tcreat(n*4)for i=1,n do
		local r=(vals[i]or 0)%0x100000000
		out[i]=chr[b32rsh(r,24)]out[n+i]=chr[b32band(b32rsh(r,16),255)]out[n2+i]=chr[b32band(b32rsh(r,8),255)]out[n3+i]=chr[b32band(r,255)]end
	return tconc(out)end
local function deinterleaveI32(data,n)local out=tcreat(n)local n2,n3=n*2,n*3
	for i=1,n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)out[i]=zzDec(raw)end
	return out
end
local function interleaveI32(vals)local n=#vals
	local n2,n3=n*2,n*3
	local out=tcreat(n*4)for i=1,n do
		local r=zzEnc(vals[i])%0x100000000
		out[i]=chr[b32rsh(r,24)]out[n+i]=chr[b32band(b32rsh(r,16),255)]out[n2+i]=chr[b32band(b32rsh(r,8),255)]out[n3+i]=chr[b32band(r,255)]end
	return tconc(out)end
local function deinterleaveRef(data,n)local out=tcreat(n)local n2,n3=n*2,n*3
	local acc=0
	for i=1,n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)acc+=zzDec(raw);out[i]=acc
	end
	return out
end
local deinterleaveParentRef=deinterleaveRef
local function interleaveRef(refs)local n=#refs
	local deltas=tcreat(n)local prev=0
	for i=1,n do local v=refs[i];deltas[i]=v-prev;prev=v end
	return interleaveI32(deltas)end
local interleaveParentRef=interleaveRef
local function deinterleaveF32(data,n)local out=tcreat(n)local n2,n3=n*2,n*3
	for i=1,n do
		local raw=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)local bits=b32bor(b32rsh(raw,1),b32lsh(b32band(raw,1),31))out[i]=(sunpack(">f",schar(b32rsh(bits,24)%256,b32rsh(bits,16)%256,b32rsh(bits,8)%256,bits%256)))end
	return out
end
local function interleaveF32(vals)local n=#vals
	local n2,n3=n*2,n*3
	local out=tcreat(n*4)for i=1,n do
		local b0,b1,b2,b3=sbyte(spack(">f",vals[i]),1,4)local bits=b0*0x1000000+b1*0x10000+b2*0x100+b3
		local raw=b32bor(b32lsh(bits,1),b32rsh(bits,31))%0x100000000
		out[i]=chr[b32rsh(raw,24)]out[n+i]=chr[b32band(b32rsh(raw,16),255)]out[n2+i]=chr[b32band(b32rsh(raw,8),255)]out[n3+i]=chr[b32band(raw,255)]end
	return tconc(out)end
local RBX_MAGIC="<roblox!\x89\xFF\x0D\x0A\x1A\x0A\x00\x00"
local function makeChunk(name,payload)local n=#payload
	local compressed=lz4Compress(payload)if#compressed<n then
		return name..spack("<I4",#compressed)..spack("<I4",n)..spack("<I4",0)..compressed
	end
	return name..spack("<I4",0)..spack("<I4",n)..spack("<I4",0)..payload
end
local CF_IDENTITY={1,0,0,0,1,0,0,0,1}local CF_SPECIAL={[0x02]={1,0,0,0,1,0,0,0,1},[0x03]={1,0,0,0,0,-1,0,1,0},[0x05]={1,0,0,0,-1,0,0,0,-1},[0x06]={1,0,0,0,0,1,0,-1,0},[0x07]={0,1,0,1,0,0,0,0,-1},[0x09]={0,0,1,1,0,0,0,1,0},[0x0A]={0,-1,0,1,0,0,0,0,1},[0x0C]={0,0,-1,1,0,0,0,-1,0},[0x0D]={0,1,0,0,0,1,1,0,0},[0x0E]={0,0,-1,0,1,0,1,0,0},[0x10]={0,-1,0,0,0,-1,1,0,0},[0x11]={0,0,1,0,-1,0,1,0,0},[0x14]={-1,0,0,0,1,0,0,0,-1},[0x15]={-1,0,0,0,0,1,0,1,0},[0x17]={-1,0,0,0,-1,0,0,0,1},[0x18]={-1,0,0,0,0,-1,0,-1,0},[0x19]={0,1,0,-1,0,0,0,0,1},[0x1B]={0,0,-1,-1,0,0,0,1,0},[0x1C]={0,-1,0,-1,0,0,0,0,-1},[0x1E]={0,0,1,-1,0,0,0,-1,0},[0x1F]={0,1,0,0,0,-1,-1,0,0},[0x20]={0,0,1,0,1,0,-1,0,0},[0x22]={0,-1,0,0,0,1,-1,0,0},[0x23]={0,0,-1,0,-1,0,-1,0,0},}local function findCFSpecial(r)for id,sr in pairs(CF_SPECIAL)do
		local ok=true
		for j=1,9 do
			if mabs((r[j]or 0)-sr[j])>1e-4 then ok=false;break end
		end
		if ok then return id end
	end
end
local function xmlUnescape(s)return(s:gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"))end
local function xmlEscape(s)return(tostring(s):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;"):gsub('"',"&quot;"))end
local function safeF(v)if type(v)~="number" or v~=v or mabs(v)==HUGE then return "0" end
	return sfmt("%.9g",v)end
local PropType={}PropType[0x01]={name="String",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=ssub(data,p,p+len-1);p+=len
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n*2)for i=1,n do local v=vals[i]pc+=1;parts[pc]=spack("<I4",#v)pc+=1;parts[pc]=v
		end;return tconc(parts)end,xmlTag="string",readXml=function(s)return s end,writeXml=function(v)return tostring(v)end,}PropType[0x02]={name="Bool",readBin=function(data,n)local out=tcreat(n)for i=1,n do out[i]=sbyte(data,i)~=0 end;return out
	end,writeBin=function(vals)local n=#vals;local out=tcreat(n)for i=1,n do out[i]=chr[vals[i]and 1 or 0]end
		return tconc(out)end,xmlTag="bool",readXml=function(s)return s=="true" end,writeXml=function(v)return v and "true" or "false" end,}PropType[0x03]={name="Int",readBin=function(data,n)return deinterleaveI32(data,n)end,writeBin=function(vals)return interleaveI32(vals)end,xmlTag="int",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return tostring(mfloor(v or 0))end,}PropType[0x04]={name="Float",readBin=function(data,n)return deinterleaveF32(data,n)end,writeBin=function(vals)return interleaveF32(vals)end,xmlTag="float",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return safeF(v)end,}PropType[0x05]={name="Double",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do out[i],p=sunpack("<d",data,p)end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do pc+=1;parts[pc]=spack("<d",vals[i])end
		return tconc(parts)end,xmlTag="double",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return sfmt("%.17g",v)end,}PropType[0x06]={name="UDim",readBin=function(data,n)local sc=deinterleaveF32(ssub(data,1,n*4),n)local of=deinterleaveI32(ssub(data,n*4+1),n)local out=tcreat(n)for i=1,n do out[i]={scale=sc[i],offset=of[i]}end;return out
	end,writeBin=function(vals)local n=#vals;local sc=tcreat(n);local of=tcreat(n)for i=1,n do sc[i]=vals[i].scale;of[i]=vals[i].offset end
		return interleaveF32(sc)..interleaveI32(of)end,xmlTag="UDim",readXml=function(_,sub)return{scale=tonumber(sub.S or"0"),offset=tonumber(sub.O or"0")}end,writeXml=function(v)return sfmt("<S>%g</S><O>%d</O>",v.scale,v.offset)end,}PropType[0x07]={name="UDim2",readBin=function(data,n)local xs=deinterleaveF32(ssub(data,1,n*4),n)local ys=deinterleaveF32(ssub(data,n*4+1,n*8),n)local xo=deinterleaveI32(ssub(data,n*8+1,n*12),n)local yo=deinterleaveI32(ssub(data,n*12+1),n)local out=tcreat(n)for i=1,n do out[i]={xScale=xs[i],yScale=ys[i],xOffset=xo[i],yOffset=yo[i]}end
		return out
	end,writeBin=function(vals)local n=#vals
		local xs=tcreat(n);local ys=tcreat(n);local xo=tcreat(n);local yo=tcreat(n)for i=1,n do local v=vals[i];xs[i]=v.xScale;ys[i]=v.yScale;xo[i]=v.xOffset;yo[i]=v.yOffset end
		return interleaveF32(xs)..interleaveF32(ys)..interleaveI32(xo)..interleaveI32(yo)end,xmlTag="UDim2",readXml=function(_,sub)return{xScale=tonumber(sub.XS or"0"),xOffset=tonumber(sub.XO or"0"),yScale=tonumber(sub.YS or"0"),yOffset=tonumber(sub.YO or"0")}end,writeXml=function(v)return sfmt("<XS>%g</XS><XO>%d</XO><YS>%g</YS><YO>%d</YO>",v.xScale,v.xOffset,v.yScale,v.yOffset)end,}PropType[0x08]={name="Ray",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local ox,oy,oz,dx,dy,dz
			ox,p=sunpack("<f",data,p);oy,p=sunpack("<f",data,p);oz,p=sunpack("<f",data,p)dx,p=sunpack("<f",data,p);dy,p=sunpack("<f",data,p);dz,p=sunpack("<f",data,p)out[i]={ox=ox,oy=oy,oz=oz,dx=dx,dy=dy,dz=dz}end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]pc+=1;parts[pc]=spack("<ffffff",v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)end;return tconc(parts)end,xmlTag="Ray",readXml=function(_,sub)local o=type(sub.origin)=="table" and sub.origin or{}local d=type(sub.direction)=="table" and sub.direction or{}return{ox=tonumber(o.X or"0"),oy=tonumber(o.Y or"0"),oz=tonumber(o.Z or"0"),dx=tonumber(d.X or"0"),dy=tonumber(d.Y or"0"),dz=tonumber(d.Z or"0")}end,writeXml=function(v)return sfmt("<origin><X>%g</X><Y>%g</Y><Z>%g</Z></origin><direction><X>%g</X><Y>%g</Y><Z>%g</Z></direction>",v.ox,v.oy,v.oz,v.dx,v.dy,v.dz)end,}PropType[0x09]={name="Faces",readBin=function(data,n)local out=tcreat(n);for i=1,n do out[i]=sbyte(data,i)end;return out
	end,writeBin=function(vals)local n=#vals;local out=tcreat(n)for i=1,n do out[i]=chr[(vals[i]or 0)%256]end;return tconc(out)end,xmlTag="Faces",readXml=function(_,sub)local v=0
		if sub.Right=="true" then v+=1 end;if sub.Top=="true" then v+=2 end
		if sub.Back=="true" then v+=4 end;if sub.Left=="true" then v+=8 end
		if sub.Bottom=="true" then v+=16 end;if sub.Front=="true" then v+=32 end
		return v
	end,writeXml=function(v)local function b(m)return b32band(v,m)~=0 and "true" or "false" end
		return sfmt("<Right>%s</Right><Top>%s</Top><Back>%s</Back><Left>%s</Left><Bottom>%s</Bottom><Front>%s</Front>",b(1),b(2),b(4),b(8),b(16),b(32))end,}PropType[0x0A]={name="Axes",readBin=function(data,n)local out=tcreat(n);for i=1,n do out[i]=sbyte(data,i)end;return out
	end,writeBin=function(vals)local n=#vals;local out=tcreat(n)for i=1,n do out[i]=chr[(vals[i]or 0)%256]end;return tconc(out)end,xmlTag="Axes",readXml=function(_,sub)local v=0
		if sub.X=="true" then v+=4 end
		if sub.Y=="true" then v+=2 end
		if sub.Z=="true" then v+=1 end
		return v
	end,writeXml=function(v)local function b(m)return b32band(v,m)~=0 and "true" or "false" end
		return sfmt("<X>%s</X><Y>%s</Y><Z>%s</Z>",b(4),b(2),b(1))end,}PropType[0x0B]={name="BrickColor",readBin=function(data,n)return deinterleaveU32(data,n)end,writeBin=function(vals)return interleaveU32(vals)end,xmlTag="BrickColor",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return tostring(mfloor(v or 0))end,}PropType[0x0C]={name="Color3",readBin=function(data,n)local rs=deinterleaveF32(ssub(data,1,n*4),n)local gs=deinterleaveF32(ssub(data,n*4+1,n*8),n)local bs=deinterleaveF32(ssub(data,n*8+1),n)local out=tcreat(n)for i=1,n do out[i]={r=rs[i],g=gs[i],b=bs[i]}end;return out
	end,writeBin=function(vals)local n=#vals;local rs=tcreat(n);local gs=tcreat(n);local bs=tcreat(n)for i=1,n do local v=vals[i];rs[i]=v.r;gs[i]=v.g;bs[i]=v.b end
		return interleaveF32(rs)..interleaveF32(gs)..interleaveF32(bs)end,xmlTag="Color3",readXml=function(s,sub)if sub and sub.R then
			return{r=tonumber(sub.R or"0"),g=tonumber(sub.G or"0"),b=tonumber(sub.B or"0")}end
		local packed=tonumber(s)or 0
		return{r=b32band(b32rsh(packed,16),0xFF)/255,g=b32band(b32rsh(packed,8),0xFF)/255,b=b32band(packed,0xFF)/255}end,writeXml=function(v)return sfmt("<R>%.9g</R><G>%.9g</G><B>%.9g</B>",v.r,v.g,v.b)end,}PropType[0x0D]={name="Vector2",readBin=function(data,n)local xs=deinterleaveF32(ssub(data,1,n*4),n)local ys=deinterleaveF32(ssub(data,n*4+1),n)local out=tcreat(n)for i=1,n do out[i]={x=xs[i],y=ys[i]}end;return out
	end,writeBin=function(vals)local n=#vals;local xs=tcreat(n);local ys=tcreat(n)for i=1,n do xs[i]=vals[i].x;ys[i]=vals[i].y end
		return interleaveF32(xs)..interleaveF32(ys)end,xmlTag="Vector2",readXml=function(_,sub)return{x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0")}end,writeXml=function(v)return sfmt("<X>%.9g</X><Y>%.9g</Y>",v.x,v.y)end,}PropType[0x0E]={name="Vector3",readBin=function(data,n)local xs=deinterleaveF32(ssub(data,1,n*4),n)local ys=deinterleaveF32(ssub(data,n*4+1,n*8),n)local zs=deinterleaveF32(ssub(data,n*8+1),n)local out=tcreat(n)for i=1,n do out[i]={x=xs[i],y=ys[i],z=zs[i]}end;return out
	end,writeBin=function(vals)local n=#vals;local xs=tcreat(n);local ys=tcreat(n);local zs=tcreat(n)for i=1,n do local v=vals[i];xs[i]=v.x;ys[i]=v.y;zs[i]=v.z end
		return interleaveF32(xs)..interleaveF32(ys)..interleaveF32(zs)end,xmlTag="Vector3",readXml=function(_,sub)return{x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0")}end,writeXml=function(v)return "<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>"
	end,}PropType[0x10]={name="CFrame",readBin=function(data,n)local p=1
		local rotations=tcreat(n)for i=1,n do
			local spec=sbyte(data,p);p+=1
			if spec==0 then
				local r=tcreat(9)for j=1,9 do r[j],p=sunpack("<f",data,p)end
				rotations[i]=r
			else
				rotations[i]=CF_SPECIAL[spec]or CF_IDENTITY
			end
		end
		local posData=ssub(data,p)local xs=deinterleaveF32(ssub(posData,1,n*4),n)local ys=deinterleaveF32(ssub(posData,n*4+1,n*8),n)local zs=deinterleaveF32(ssub(posData,n*8+1),n)local out=tcreat(n)for i=1,n do out[i]={r=rotations[i],x=xs[i],y=ys[i],z=zs[i]}end
		return out
	end,writeBin=function(vals)local n=#vals
		local pc=0;local perInst=tcreat(n)local xs=tcreat(n);local ys=tcreat(n);local zs=tcreat(n)for i=1,n do
			local v=vals[i];local r=v.r or CF_IDENTITY
			local specId=findCFSpecial(r)if specId then
				pc+=1;perInst[pc]=schar(specId)else
				local rp=tcreat(10);rp[1]="\x00"
				for j=1,9 do rp[j+1]=spack("<f",r[j]or 0)end
				pc+=1;perInst[pc]=tconc(rp)end
			xs[i]=v.x or 0;ys[i]=v.y or 0;zs[i]=v.z or 0
		end
		return tconc(perInst,"",1,pc)..interleaveF32(xs)..interleaveF32(ys)..interleaveF32(zs)end,xmlTag="CoordinateFrame",readXml=function(_,sub)return{x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0"),r={tonumber(sub.R00 or"1"),tonumber(sub.R01 or"0"),tonumber(sub.R02 or"0"),tonumber(sub.R10 or"0"),tonumber(sub.R11 or"1"),tonumber(sub.R12 or"0"),tonumber(sub.R20 or"0"),tonumber(sub.R21 or"0"),tonumber(sub.R22 or"1")},}end,writeXml=function(v)local r=v.r or CF_IDENTITY
		return "<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>".."<R00>"..safeF(r[1]).."</R00><R01>"..safeF(r[2]).."</R01><R02>"..safeF(r[3]).."</R02>".."<R10>"..safeF(r[4]).."</R10><R11>"..safeF(r[5]).."</R11><R12>"..safeF(r[6]).."</R12>".."<R20>"..safeF(r[7]).."</R20><R21>"..safeF(r[8]).."</R21><R22>"..safeF(r[9]).."</R22>"
	end,}PropType[0x12]={name="Enum",readBin=function(data,n)return deinterleaveU32(data,n)end,writeBin=function(vals)return interleaveU32(vals)end,xmlTag="token",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return tostring(mfloor(v or 0))end,}PropType[0x13]={name="Referent",readBin=function(data,n)return deinterleaveRef(data,n)end,writeBin=function(vals)return interleaveRef(vals)end,xmlTag="Ref",readXml=function(s)if not s or s=="null" or s=="" then return-1 end
		local hex=s:match("^RBX(%x+)$")if hex then return tonumber(hex,16)end
		return tonumber(s)or-1
	end,writeXml=function(v)return(not v or v==-1 or v<0)and "null" or("RBX"..sfmt("%08X",v))end,}PropType[0x14]={name="Vector3int16",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local x,y,z
			x,p=sunpack("<i2",data,p);y,p=sunpack("<i2",data,p);z,p=sunpack("<i2",data,p)out[i]={x=x,y=y,z=z}end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]pc+=1;parts[pc]=spack("<i2i2i2",v.x or 0,v.y or 0,v.z or 0)end;return tconc(parts)end,xmlTag="Vector3int16",readXml=function(_,sub)return{x=tonumber(sub.X or"0"),y=tonumber(sub.Y or"0"),z=tonumber(sub.Z or"0")}end,writeXml=function(v)return sfmt("<X>%d</X><Y>%d</Y><Z>%d</Z>",v.x,v.y,v.z)end,}PropType[0x15]={name="NumberSequence",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local count,np=sunpack("<I4",data,p);p=np
			local kps=tcreat(count)for j=1,count do
				local t,v,e
				t,p=sunpack("<f",data,p);v,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)kps[j]={t=t,v=v,e=e}end
			out[i]=kps
		end;return out
	end,writeBin=function(vals)local nv=#vals;local pc=0;local parts=tcreat(nv*4)for i=1,nv do
			local kps=vals[i];local nk=#kps
			pc+=1;parts[pc]=spack("<I4",nk)for j=1,nk do local kp=kps[j]pc+=1;parts[pc]=spack("<fff",kp.t,kp.v,kp.e)end
		end;return tconc(parts)end,xmlTag="NumberSequence",readXml=function(s)local kps={};local kc=0
		for t,v,e in(s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+")do
			kc+=1;kps[kc]={t=tonumber(t),v=tonumber(v),e=tonumber(e)}end;return kps
	end,writeXml=function(v)local n=#v;local pc=0;local parts=tcreat(n)for i=1,n do local kp=v[i]pc+=1;parts[pc]=sfmt("%g %g %g ",kp.t,kp.v,kp.e)end;return tconc(parts)end,}PropType[0x16]={name="ColorSequence",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local count,np=sunpack("<I4",data,p);p=np
			local kps=tcreat(count)for j=1,count do
				local t,r,g,bb,e
				t,p=sunpack("<f",data,p);r,p=sunpack("<f",data,p)g,p=sunpack("<f",data,p);bb,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)kps[j]={t=t,r=r,g=g,b=bb,e=e}end
			out[i]=kps
		end;return out
	end,writeBin=function(vals)local nv=#vals;local pc=0;local parts=tcreat(nv*4)for i=1,nv do
			local kps=vals[i];local nk=#kps
			pc+=1;parts[pc]=spack("<I4",nk)for j=1,nk do local kp=kps[j]pc+=1;parts[pc]=spack("<fffff",kp.t,kp.r,kp.g,kp.b,kp.e)end
		end;return tconc(parts)end,xmlTag="ColorSequence",readXml=function(s)local kps={};local kc=0
		for t,r,g,b,e in(s.." "):gmatch("(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+")do
			kc+=1;kps[kc]={t=tonumber(t),r=tonumber(r),g=tonumber(g),b=tonumber(b),e=tonumber(e)}end;return kps
	end,writeXml=function(v)local n=#v;local pc=0;local parts=tcreat(n)for i=1,n do local kp=v[i]pc+=1;parts[pc]=sfmt("%g %g %g %g %g ",kp.t,kp.r,kp.g,kp.b,kp.e)end;return tconc(parts)end,}PropType[0x17]={name="NumberRange",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local mn,mx;mn,p=sunpack("<f",data,p);mx,p=sunpack("<f",data,p)out[i]={min=mn,max=mx}end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]pc+=1;parts[pc]=spack("<ff",v.min,v.max)end;return tconc(parts)end,xmlTag="NumberRange",readXml=function(s)local a,b=s:match("(%S+)%s+(%S+)")return{min=tonumber(a or"0"),max=tonumber(b or"1")}end,writeXml=function(v)return sfmt("%g %g ",v.min,v.max)end,}PropType[0x18]={name="Rect",readBin=function(data,n)local mnx=deinterleaveF32(ssub(data,1,n*4),n)local mny=deinterleaveF32(ssub(data,n*4+1,n*8),n)local mxx=deinterleaveF32(ssub(data,n*8+1,n*12),n)local mxy=deinterleaveF32(ssub(data,n*12+1),n)local out=tcreat(n)for i=1,n do out[i]={minX=mnx[i],minY=mny[i],maxX=mxx[i],maxY=mxy[i]}end
		return out
	end,writeBin=function(vals)local n=#vals
		local mnx=tcreat(n);local mny=tcreat(n);local mxx=tcreat(n);local mxy=tcreat(n)for i=1,n do local v=vals[i];mnx[i]=v.minX;mny[i]=v.minY;mxx[i]=v.maxX;mxy[i]=v.maxY end
		return interleaveF32(mnx)..interleaveF32(mny)..interleaveF32(mxx)..interleaveF32(mxy)end,xmlTag="Rect2D",readXml=function(_,sub)local mn=type(sub.min)=="table" and sub.min or{}local mx=type(sub.max)=="table" and sub.max or{}return{minX=tonumber(mn.X or"0"),minY=tonumber(mn.Y or"0"),maxX=tonumber(mx.X or"0"),maxY=tonumber(mx.Y or"0")}end,writeXml=function(v)return sfmt("<min><X>%g</X><Y>%g</Y></min><max><X>%g</X><Y>%g</Y></max>",v.minX,v.minY,v.maxX,v.maxY)end,}PropType[0x19]={name="PhysicalProperties",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local custom=sbyte(data,p)~=0;p+=1
			if custom then
				local d,f,e,fw,ew
				d,p=sunpack("<f",data,p);f,p=sunpack("<f",data,p);e,p=sunpack("<f",data,p)fw,p=sunpack("<f",data,p);ew,p=sunpack("<f",data,p)out[i]={custom=true,density=d,friction=f,elasticity=e,frictionWeight=fw,elasticityWeight=ew}else
				out[i]={custom=false}end
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]if v.custom then
				pc+=1;parts[pc]="\x01"..spack("<fffff",v.density,v.friction,v.elasticity,v.frictionWeight,v.elasticityWeight)else
				pc+=1;parts[pc]="\x00"
			end
		end;return tconc(parts)end,xmlTag="PhysicalProperties",readXml=function(_,sub)if sub.CustomPhysics=="true" then
			return{custom=true,density=tonumber(sub.Density or"0"),friction=tonumber(sub.Friction or"0"),elasticity=tonumber(sub.Elasticity or"0"),frictionWeight=tonumber(sub.FrictionWeight or"0"),elasticityWeight=tonumber(sub.ElasticityWeight or"0")}end
		return{custom=false}end,writeXml=function(v)if v.custom then
			return sfmt("<CustomPhysics>true</CustomPhysics><Density>%g</Density>".."<Friction>%g</Friction><Elasticity>%g</Elasticity>".."<FrictionWeight>%g</FrictionWeight><ElasticityWeight>%g</ElasticityWeight>",v.density,v.friction,v.elasticity,v.frictionWeight,v.elasticityWeight)end
		return "<CustomPhysics>false</CustomPhysics>"
	end,}PropType[0x1A]={name="Color3uint8",readBin=function(data,n)local out=tcreat(n);local n2=n*2
		for i=1,n do out[i]={r=sbyte(data,i),g=sbyte(data,n+i),b=sbyte(data,n2+i)}end
		return out
	end,writeBin=function(vals)local n=#vals;local rs=tcreat(n);local gs=tcreat(n);local bs=tcreat(n)for i=1,n do local v=vals[i];rs[i]=chr[v.r%256];gs[i]=chr[v.g%256];bs[i]=chr[v.b%256]end
		return tconc(rs)..tconc(gs)..tconc(bs)end,xmlTag="Color3uint8",readXml=function(_,sub)return{r=tonumber(sub.R or"0"),g=tonumber(sub.G or"0"),b=tonumber(sub.B or"0")}end,writeXml=function(v)return sfmt("<R>%d</R><G>%d</G><B>%d</B>",v.r,v.g,v.b)end,}PropType[0x1B]={name="Int64",readBin=function(data,n)local out=tcreat(n)local n2,n3,n4,n5,n6,n7=n*2,n*3,n*4,n*5,n*6,n*7
		for i=1,n do
			local hi=sbyte(data,i)*0x1000000+sbyte(data,n+i)*0x10000+sbyte(data,n2+i)*0x100+sbyte(data,n3+i)local lo=sbyte(data,n4+i)*0x1000000+sbyte(data,n5+i)*0x10000+sbyte(data,n6+i)*0x100+sbyte(data,n7+i)local combined=hi*0x100000000+lo
			if b32band(lo,1)==0 then out[i]=mfloor(combined/2)else out[i]=-mfloor((combined+1)/2)end
		end;return out
	end,writeBin=function(vals)local n=#vals
		local by={};for k=0,7 do by[k]=tcreat(n)end
		for i=1,n do
			local v=vals[i]local raw=v>=0 and v*2 or-v*2-1
			local lo=raw%0x100000000
			local hi=mfloor(raw/0x100000000)by[0][i]=chr[b32rsh(hi,24)%256];by[1][i]=chr[b32rsh(hi,16)%256]by[2][i]=chr[b32rsh(hi,8)%256];by[3][i]=chr[hi%256]by[4][i]=chr[b32rsh(lo,24)%256];by[5][i]=chr[b32rsh(lo,16)%256]by[6][i]=chr[b32rsh(lo,8)%256];by[7][i]=chr[lo%256]end
		local pc=0;local parts=tcreat(8)for k=0,7 do pc+=1;parts[pc]=tconc(by[k])end
		return tconc(parts)end,xmlTag="int64",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return tostring(mfloor(v or 0))end,}PropType[0x1C]={name="SharedString",readBin=function(data,n)return deinterleaveU32(data,n)end,writeBin=function(vals)return interleaveU32(vals)end,xmlTag="SharedString",readXml=function(s)return s or "" end,writeXml=function(v)return v or "" end,}local b64chars="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local b64enc={};for i=0,63 do b64enc[i]=ssub(b64chars,i+1,i+1)end
local b64dec={};for i=0,63 do b64dec[sbyte(b64chars,i+1)]=i end
local function base64Encode(s)local n=#s
	local oc=0;local out=tcreat(mceil(n/3)*4)for i=1,n,3 do
		local a=sbyte(s,i)or 0
		local b=sbyte(s,i+1)or 0
		local c=sbyte(s,i+2)or 0
		local v=a*65536+b*256+c
		oc+=1;out[oc]=b64enc[b32rsh(v,18)]oc+=1;out[oc]=b64enc[b32band(b32rsh(v,12),63)]oc+=1;out[oc]=i+1<=n and b64enc[b32band(b32rsh(v,6),63)]or "="
		oc+=1;out[oc]=i+2<=n and b64enc[b32band(v,63)]or "="
	end
	return tconc(out)end
local function base64Decode(s)s=s:gsub("[^A-Za-z0-9+/=]","")local n=#s
	local oc=0;local out=tcreat(mceil(n/4)*3)local i=1
	while i<=n do
		local a=b64dec[sbyte(s,i)]or 0;i+=1
		local b=b64dec[sbyte(s,i)]or 0;i+=1
		local c=b64dec[sbyte(s,i)]or 0;i+=1
		local d=b64dec[sbyte(s,i)]or 0;i+=1
		local v=a*262144+b*4096+c*64+d
		oc+=1;out[oc]=schar(b32rsh(v,16))if sbyte(s,i-2)~=61 then oc+=1;out[oc]=schar(b32band(b32rsh(v,8),255))end
		if sbyte(s,i-1)~=61 then oc+=1;out[oc]=schar(b32band(v,255))end
	end
	return tconc(out)end
PropType[0x1E]={name="OptionalCFrame",readBin=function(data,n)local p=2
		local specs=tcreat(n);local rots=tcreat(n)for i=1,n do
			local s=sbyte(data,p)or 0;p+=1
			if s==0 then
				local r=tcreat(9)for j=1,9 do r[j],p=sunpack("<f",data,p)end
				rots[i]=r
			else
				rots[i]=CF_SPECIAL[s]or CF_IDENTITY
			end
			specs[i]=s
		end
		local xs=deinterleaveF32(ssub(data,p,p+n*4-1),n);p+=n*4
		local ys=deinterleaveF32(ssub(data,p,p+n*4-1),n);p+=n*4
		local zs=deinterleaveF32(ssub(data,p,p+n*4-1),n);p+=n*4
		p+=1
		local out=tcreat(n)for i=1,n do
			out[i]=(sbyte(data,p+i-1)or 0)~=0 and{r=rots[i],x=xs[i],y=ys[i],z=zs[i]}or nil
		end
		return out
	end,writeBin=function(vals)local n=#vals
		local bools=tcreat(n)local pc=0;local cfBytes=tcreat(n*10)local xs=tcreat(n);local ys=tcreat(n);local zs=tcreat(n)for i=1,n do
			local v=vals[i]local cf=v or{r=CF_IDENTITY,x=0,y=0,z=0}bools[i]=chr[v and 1 or 0]local r=cf.r or CF_IDENTITY
			local specId=findCFSpecial(r)if specId then
				pc+=1;cfBytes[pc]=schar(specId)else
				pc+=1;cfBytes[pc]="\x00"
				for j=1,9 do pc+=1;cfBytes[pc]=spack("<f",r[j]or 0)end
			end
			xs[i]=cf.x or 0;ys[i]=cf.y or 0;zs[i]=cf.z or 0
		end
		return "\x10"..tconc(cfBytes,"",1,pc)..interleaveF32(xs)..interleaveF32(ys)..interleaveF32(zs).."\x02"..tconc(bools)end,xmlTag="OptionalCoordinateFrame",readXml=function(_,sub)if not sub or not sub.CFrame then return nil end
		local cf=sub.CFrame
		local function v(k)return tonumber(type(cf)=="table" and cf[k]or nil)or 0 end
		return{r={v"R00",v"R01",v"R02",v"R10",v"R11",v"R12",v"R20",v"R21",v"R22"},x=v"X",y=v"Y",z=v"Z"}end,writeXml=function(v)if not v then return "" end
		local r=v.r or CF_IDENTITY
		return "<CFrame>".."<X>"..safeF(v.x).."</X><Y>"..safeF(v.y).."</Y><Z>"..safeF(v.z).."</Z>".."<R00>"..safeF(r[1]).."</R00><R01>"..safeF(r[2]).."</R01><R02>"..safeF(r[3]).."</R02>".."<R10>"..safeF(r[4]).."</R10><R11>"..safeF(r[5]).."</R11><R12>"..safeF(r[6]).."</R12>".."<R20>"..safeF(r[7]).."</R20><R21>"..safeF(r[8]).."</R21><R22>"..safeF(r[9]).."</R22>".."</CFrame>"
	end,}PropType[0x1E4]={name="ProtectedString",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=ssub(data,p,p+len-1);p+=len
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n*2)for i=1,n do local v=vals[i]pc+=1;parts[pc]=spack("<I4",#v)pc+=1;parts[pc]=v
		end;return tconc(parts)end,xmlTag="ProtectedString",readXml=function(s)return s or "" end,writeXml=function(v)return tostring(v or "")end,}PropType[0x1F]={name="UniqueId",readBin=function(data,n)local out=tcreat(n);local n4=n*4;local n2=n*2;local n3=n*3
		for i=1,n do
			local blob=tcreat(16);local base=0
			for f=0,3 do
				local seg=f*n4
				blob[base+1]=schar(sbyte(data,seg+i)or 0)
				blob[base+2]=schar(sbyte(data,seg+n+i)or 0)
				blob[base+3]=schar(sbyte(data,seg+n2+i)or 0)
				blob[base+4]=schar(sbyte(data,seg+n3+i)or 0)
				base+=4
			end
			out[i]=tconc(blob)
		end;return out
	end,writeBin=function(vals)local n=#vals;local n2=n*2;local n3=n*3;local null=("\0"):rep(16)
		local g={}for f=0,3 do g[f]=tcreat(n*4)end
		for i=1,n do local v=vals[i]or null
			for f=0,3 do local base=f*4
				g[f][i]=chr[sbyte(v,base+1)or 0];g[f][n+i]=chr[sbyte(v,base+2)or 0]
				g[f][n2+i]=chr[sbyte(v,base+3)or 0];g[f][n3+i]=chr[sbyte(v,base+4)or 0]
			end
		end
		local pc=0;local parts=tcreat(4)
		for f=0,3 do pc+=1;parts[pc]=tconc(g[f])end;return tconc(parts)
	end,xmlTag="UniqueId",readXml=function(s)local hex=(s or ""):gsub("%s","")
		if #hex==0 then return("\0"):rep(16)end
		local out=tcreat(16);for i=1,16 do out[i]=schar(tonumber(hex:sub(i*2-1,i*2),16)or 0)end;return tconc(out)
	end,writeXml=function(v)local out=tcreat(16);for i=1,16 do out[i]=sfmt("%02x",sbyte(v,i)or 0)end;return tconc(out)end,}PropType[0x20]={name="Font",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local flen,np=sunpack("<I4",data,p);p=np
			local family=ssub(data,p,p+flen-1);p+=flen
			local weight,np2=sunpack("<I2",data,p);p=np2
			local style=sbyte(data,p);p+=1
			local clen,np3=sunpack("<I4",data,p);p=np3
			local cached=ssub(data,p,p+clen-1);p+=clen
			out[i]={family=family,weight=weight,style=style,cachedFaceId=cached}end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]local fam=v.family or "";local cac=v.cachedFaceId or ""
			pc+=1;parts[pc]=spack("<I4",#fam)..fam..spack("<I2",v.weight or 400)..chr[v.style or 0]..spack("<I4",#cac)..cac
		end;return tconc(parts)end,xmlTag="Font",readXml=function(_,sub)local famSub=type(sub.Family)=="table" and sub.Family or{}local family=type(famSub.url)=="string" and famSub.url or(type(sub.Family)=="string" and sub.Family or "")local weightMap={Thin=100,ExtraLight=200,Light=300,Regular=400,Medium=500,SemiBold=600,Bold=700,ExtraBold=800,Heavy=900}local styleMap={Normal=0,Italic=2}return{family=family,weight=tonumber(sub.Weight)or weightMap[sub.Weight or ""]or 400,style=styleMap[sub.Style or "Normal"]or 0,cachedFaceId=""}end,writeXml=function(v)local styleNames={[0]="Normal",[2]="Italic"}return "<Family><url>"..xmlEscape(v.family or "").."</url></Family>".."<Weight>"..tostring(v.weight or 400).."</Weight>".."<Style>"..(styleNames[v.style or 0]or "Normal").."</Style>"
	end,}PropType[0x21]={name="SecurityCapabilities",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local lo,hi;lo,p=sunpack("<I4",data,p);hi,p=sunpack("<I4",data,p)out[i]=lo+hi*0x100000000
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n)for i=1,n do local v=vals[i]or 0
			local lo=v%0x100000000
			local hi=mfloor(v/0x100000000)%0x100000000
			pc+=1;parts[pc]=spack("<I4",lo)..spack("<I4",hi)end;return tconc(parts)end,xmlTag="SecurityCapabilities",readXml=function(s)return tonumber(s)or 0 end,writeXml=function(v)return tostring(mfloor(v or 0))end,}local function getType(id)return PropType[id]or{name="Unknown("..sfmt("0x%02X",id)..")",readBin=function()return{}end,writeBin=function()return "" end,xmlTag="BinaryString",readXml=function(s)return s end,writeXml=function(v)return tostring(v or "")end,}end
local CONTENT_PROPS={SoundId=true,Image=true,HoverImage=true,PressedImage=true,Texture=true,LinkedSource=true,MeshId=true,TextureId=true,TextureID=true,SkyboxBk=true,SkyboxDn=true,SkyboxFt=true,SkyboxLf=true,SkyboxRt=true,SkyboxUp=true,AnimationId=true,ShirtTemplate=true,PantsTemplate=true,ContentId=true,GraphicId=true,OverlayTextureId=true,BaseTextureId=true,NormalMap=true,VideoSource=true,AssetId=true,}local BINARY_STRING_PROPS={AttributesSerialize=true,Tags=true,PhysicsData=true,PhysicsGrid=true,LevelOfDetailData=true,TerrainColors=true,TerrainMaterialColors=true,SmoothGrid=true,ClusterGrid=true,CollisionGroupData=true,MaterialColors=true,HiddenServices=true,VisibleServices=true,}local NETASSET_PROPS={SolidMeshHolder=true}local xmlTagToTypeId={}for id,info in pairs(PropType)do
	if info.xmlTag then xmlTagToTypeId[info.xmlTag]=id end
end
xmlTagToTypeId["string"]=0x01;xmlTagToTypeId["bool"]=0x02
xmlTagToTypeId["int"]=0x03;xmlTagToTypeId["float"]=0x04
xmlTagToTypeId["double"]=0x05;xmlTagToTypeId["BinaryString"]=0x1E2
xmlTagToTypeId["ProtectedString"]=0x1E4;xmlTagToTypeId["UniqueId"]=0x1F;xmlTagToTypeId["Font"]=0x20
xmlTagToTypeId["SecurityCapabilities"]=0x21
xmlTagToTypeId["OptionalCoordinateFrame"]=0x1E
xmlTagToTypeId["Content"]=0x22;xmlTagToTypeId["NetAssetRef"]=0x1E3
PropType[0x1E3]={name="NetAssetRef",readBin=function(data,n)return deinterleaveU32(data,n)end,writeBin=function(vals)return interleaveU32(vals)end,xmlTag="NetAssetRef",readXml=function(s)return base64Decode(s or "")end,writeXml=function(v)return base64Encode(v or "")end,}PropType[0x1E2]={name="BinaryString",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			out[i]=ssub(data,p,p+len-1);p+=len
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n*2)for i=1,n do local v=vals[i]or ""
			pc+=1;parts[pc]=spack("<I4",#v)pc+=1;parts[pc]=v
		end;return tconc(parts)end,xmlTag="BinaryString",readXml=function(s)return base64Decode(s or "")end,writeXml=function(v)return base64Encode(v or "")end,}PropType[0x22]={name="Content",readBin=function(data,n)local out=tcreat(n);local p=1
		for i=1,n do
			local len,np=sunpack("<I4",data,p);p=np
			local raw=ssub(data,p,p+len-1);p+=len
			if len>=8 and sbyte(raw,1)==0x01 and sbyte(raw,2)==0x00
			 and sbyte(raw,3)==0x00 and sbyte(raw,4)==0x00 then
				local slen=sunpack("<I4",raw,5)out[i]=ssub(raw,9,8+slen)elseif len>=1 and sbyte(raw,1)==0x00 then
				out[i]=""
			else
				out[i]=raw
			end
		end;return out
	end,writeBin=function(vals)local n=#vals;local pc=0;local parts=tcreat(n*2)for i=1,n do local v=tostring(vals[i]or "")pc+=1;parts[pc]=spack("<I4",#v)pc+=1;parts[pc]=v
		end;return tconc(parts)end,xmlTag="Content",readXml=function(text,sub)if type(sub)=="table" then
			if type(sub.url)=="string" and sub.url~="" then return sub.url end
			if sub.null~=nil then return "" end
		end
		return text or ""
	end,writeXml=function(v)v=tostring(v or "")return v=="" and "<null></null>" or "<url>"..xmlEscape(v).."</url>"
	end,}local function parseBinary(data)assert(ssub(data,1,16)==RBX_MAGIC,"Not a valid .rbxm binary file")local pos=17
	local _,np2=sunpack("<I4",data,pos);pos=np2
	local _,np3=sunpack("<I4",data,pos);pos=np3
	pos+=8
	local typeMap={};local instMap={};local sharedStrs={};local roots={}local rc=0
	while pos<=#data do
		if pos+15>#data then break end
		local chunkName=ssub(data,pos,pos+3);pos+=4
		local cLen=sunpack("<I4",data,pos);pos+=4
		local uLen=sunpack("<I4",data,pos);pos+=4
		pos+=4
		if type(cLen)~="number" or type(uLen)~="number"
		 or cLen<0 or uLen<0 or cLen>#data or uLen>#data*8 then break end
		if ssub(chunkName,1,3)=="END" then break end
		local payload
		if cLen==0 then
			if pos+uLen-1<=#data then payload=ssub(data,pos,pos+uLen-1)end
			pos=mmin(pos+uLen,#data+1)else
			if pos+cLen-1<=#data then
				local ok,result=pcall(lz4Decompress,ssub(data,pos,pos+cLen-1),uLen)if ok then payload=result end
			end
			pos=mmin(pos+cLen,#data+1)end
		if payload==nil then continue end
		if chunkName=="META" then
		elseif chunkName=="SSTR" then
			pcall(function()local sp=1
				local _,np=sunpack("<I4",payload,sp);sp=np
				local count,np2=sunpack("<I4",payload,sp);sp=np2
				for i=1,count do
					local key=ssub(payload,sp,sp+15);sp+=16
					local s,np3=sunpack("<s4",payload,sp);sp=np3
					sharedStrs[i-1]={blob=s,key=key}end
			end)elseif chunkName=="INST" then
			pcall(function()local sp=1
				local typeIdx,np1=sunpack("<I4",payload,sp);sp=np1
				local cnLen,np2=sunpack("<I4",payload,sp);sp=np2
				local className=ssub(payload,sp,sp+cnLen-1);sp+=cnLen
				local isService=sbyte(payload,sp)~=0;sp+=1
				local count,np3=sunpack("<I4",payload,sp);sp=np3
				local refs=deinterleaveRef(ssub(payload,sp,sp+count*4-1),count);sp+=count*4
				if isService then sp+=count end
				typeMap[typeIdx]={className=className,count=count,referents=refs}for i=1,count do
					local ref=refs[i]instMap[ref]={referent=ref,className=className,isService=isService,properties={},children={},parent=nil}end
			end)elseif chunkName=="PROP" then
			pcall(function()local sp=1
				local typeIdx,np1=sunpack("<I4",payload,sp);sp=np1
				local pnLen,np2=sunpack("<I4",payload,sp);sp=np2
				local propName=ssub(payload,sp,sp+pnLen-1);sp+=pnLen
				local typeId=sbyte(payload,sp);sp+=1
				if typeId==0x01 and CONTENT_PROPS[propName]then typeId=0x22 end
				if typeId==0x01 and BINARY_STRING_PROPS[propName]then typeId=0x1E2 end
				if typeId==0x1C and NETASSET_PROPS[propName]then typeId=0x1E3 end
				local ti=typeMap[typeIdx]if not ti then return end
				local typeInfo=getType(typeId)local ok2,values=pcall(typeInfo.readBin,ssub(payload,sp),ti.count)if not ok2 then return end
				local refs=ti.referents
				for i=1,#refs do
					local inst=instMap[refs[i]]if inst and values[i]~=nil then
						inst.properties[propName]={typeId=typeId,value=values[i]}end
				end
			end)elseif chunkName=="PRNT" then
			pcall(function()local sp=2
				local count,np=sunpack("<I4",payload,sp);sp=np
				local childRefs=deinterleaveRef(ssub(payload,sp,sp+count*4-1),count)local parentRefs=deinterleaveParentRef(ssub(payload,sp+count*4,sp+count*8-1),count)for i=1,count do
					local child=instMap[childRefs[i]]local parent=instMap[parentRefs[i]]if child then
						child.parent=parent
						if parent then
							local cc=#parent.children+1;parent.children[cc]=child
						else
							rc+=1;roots[rc]=child
						end
					end
				end
			end)end
	end
	if rc==0 and next(instMap)then
		for _,inst in pairs(instMap)do
			if inst.parent==nil then rc+=1;roots[rc]=inst end
		end
	end
	if rc==0 and next(instMap)then
		local isChild={}for _,inst in pairs(instMap)do
			local ch=inst.children
			for i=1,#ch do isChild[ch[i].referent]=true end
		end
		for _,inst in pairs(instMap)do
			if not isChild[inst.referent]then rc+=1;roots[rc]=inst end
		end
	end
	if rc==0 and next(instMap)then
		for _,inst in pairs(instMap)do
			inst.children={};rc+=1;roots[rc]=inst
		end
	end
	local sharedBlobs={};local sharedKeys={}for idx,entry in pairs(sharedStrs)do
		sharedBlobs[idx]=entry.blob;sharedKeys[idx]=entry.key
	end
	return roots,sharedBlobs,sharedKeys
end
local function tokenize(xml)local tc=0;local tokens={}local pos=1;local n=#xml
	while pos<=n do
		local c=sbyte(xml,pos)if c~=60 then
			local e=sfind(xml,"<",pos,true)local text=ssub(xml,pos,e and e-1 or n)pos=e or n+1
			if sfind(text,"%S")then
				if sfind(text,"&",1,true)then text=xmlUnescape(text)end
				tc+=1;tokens[tc]={type="text",text=text}end
		else
			local c2=sbyte(xml,pos+1)if c2==33 then
				local c3=sbyte(xml,pos+2)if c3==45 and sbyte(xml,pos+3)==45 then
					local e=sfind(xml,"-->",pos+4,true)pos=e and e+3 or n+1
				elseif c3==91 and ssub(xml,pos,pos+8)=="<![CDATA[" then
					local e=sfind(xml,"]]>",pos+9,true)if e then
						tc+=1;tokens[tc]={type="text",text=ssub(xml,pos+9,e-1)}pos=e+3
					else pos=n+1 end
				else
					local e=sfind(xml,">",pos+2,true)pos=e and e+1 or n+1
				end
			elseif c2==63 then
				local e=sfind(xml,"?>",pos+2,true)pos=e and e+2 or n+1
			elseif c2==47 then
				local e=sfind(xml,">",pos+2,true)if not e then break end
				local name=ssub(xml,pos+2,e-1):match("^%s*([%w:_%.-]*)%s*")tc+=1;tokens[tc]={type="close",name=name}pos=e+1
			else
				local e=sfind(xml,">",pos+1,true)if not e then break end
				local tag=ssub(xml,pos+1,e-1)pos=e+1
				local selfClose=sbyte(tag,#tag)==47
				if selfClose then tag=ssub(tag,1,-2)end
				local tname=tag:match("^%s*([%w:_%.-]+)")if tname then
					local attrs={}for k,v in tag:gmatch('%s+([%w:_%-]+)%s*=%s*"([^"]*)"')do
						attrs[k]=sfind(v,"&",1,true)and xmlUnescape(v)or v
					end
					for k,v in tag:gmatch("%s+([%w:_%-]+)%s*=%s*'([^']*)'")do
						attrs[k]=sfind(v,"&",1,true)and xmlUnescape(v)or v
					end
					tc+=1;tokens[tc]={type=selfClose and "selfclose" or "open",name=tname,attrs=attrs}end
			end
		end
	end
	return tokens
end
local function parseElement(tokens,ti,closeName)local text="";local sub={}local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]if tok.type=="close" and tok.name==closeName then
			return text:match("^%s*(.-)%s*$"),sub,ti+1
		elseif tok.type=="text" then
			text..=tok.text;ti+=1
		elseif tok.type=="open" then
			local childName=tok.name;ti+=1
			local childText,childSub,newTi=parseElement(tokens,ti,childName)ti=newTi
			sub[childName]=next(childSub)and childSub or childText
		elseif tok.type=="selfclose" then
			sub[tok.name]="";ti+=1
		else ti+=1 end
	end
	return text:match("^%s*(.-)%s*$"),sub,ti
end
local function parseProperties(tokens,ti)local props={}local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]if tok.type=="close" and tok.name=="Properties" then
			return props,ti+1
		elseif tok.type=="open" or tok.type=="selfclose" then
			local propTag=tok.name
			local propName=tok.attrs and tok.attrs.name
			if tok.type=="selfclose" then
				if propName then props[propName]={xmlTag=propTag,text="",sub={}}end
				ti+=1
			else
				ti+=1
				local text,sub,newTi=parseElement(tokens,ti,propTag);ti=newTi
				if propName then props[propName]={xmlTag=propTag,text=text,sub=sub}end
			end
		else ti+=1 end
	end
	return props,ti
end
local parseXmlItems
parseXmlItems=function(tokens,ti,refCounter,stopTag)stopTag=stopTag or "roblox"
	local nc=0;local nodes={}local nt=#tokens
	while ti<=nt do
		local tok=tokens[ti]if tok.type=="close" then
			if tok.name==stopTag then return nodes,ti
			else ti+=1 end
		elseif tok.type=="open" and tok.name=="Item" then
			local className=tok.attrs and tok.attrs.class or "Unknown"
			local xmlRef=tok.attrs and tok.attrs.referent or nil
			refCounter[1]+=1
			local node={referent=refCounter[1],className=className,xmlRef=xmlRef,properties={},children={},parent=nil}ti+=1
			local nch=0
			while ti<=nt do
				local inner=tokens[ti]if inner.type=="close" and inner.name=="Item" then
					ti+=1;break
				elseif inner.type=="open" and inner.name=="Properties" then
					ti+=1
					local props,newTi=parseProperties(tokens,ti)ti=newTi;node.properties=props
				elseif inner.type=="open" and inner.name=="Item" then
					local children,newTi=parseXmlItems(tokens,ti,refCounter,"Item")ti=newTi
					for i=1,#children do
						local child=children[i];nch+=1
						child.parent=node;node.children[nch]=child
					end
				else ti+=1 end
			end
			nc+=1;nodes[nc]=node
		else ti+=1 end
	end
	return nodes,ti
end
local function parseXml(xml)local tokens=tokenize(xml)local ti=1;local nt=#tokens
	while ti<=nt and not(tokens[ti].type=="open" and tokens[ti].name=="roblox")do
		ti+=1
	end
	if ti>nt then error("RBXConverter: no <roblox> root element found")end
	ti+=1
	local refCounter={0}local xmlSharedStrings={}local tmpTi=ti
	while tmpTi<=nt do
		local tok=tokens[tmpTi]if tok.type=="open" and tok.name=="SharedStrings" then
			tmpTi+=1
			while tmpTi<=nt do
				local t=tokens[tmpTi]if t.type=="close" and t.name=="SharedStrings" then tmpTi+=1;break end
				if t.type=="open" and t.name=="SharedString" then
					local key=t.attrs and t.attrs.md5 or ""
					tmpTi+=1;local content=""
					while tmpTi<=nt do
						local t2=tokens[tmpTi]if t2.type=="close" and t2.name=="SharedString" then tmpTi+=1;break end
						if t2.type=="text" then content..=t2.text end
						tmpTi+=1
					end
					xmlSharedStrings[key]=base64Decode(content)else tmpTi+=1 end
			end
			break
		elseif tok.type=="open" and tok.name=="Item" then
			break
		else tmpTi+=1 end
	end
	local roots,_=parseXmlItems(tokens,ti,refCounter,"roblox")return roots,xmlSharedStrings
end
local function serializeBinary(roots,xmlSharedStrings)local allInsts={}local function collect(node)local ac=#allInsts+1;allInsts[ac]=node
		local ch=node.children
		for i=1,#ch do collect(ch[i])end
	end
	for i=1,#roots do collect(roots[i])end
	local na=#allInsts
	local refMap={}for i=1,na do refMap[allInsts[i]]=i-1 end
	local xmlRefNodeMap={}for i=1,na do
		local inst=allInsts[i]if inst.xmlRef then xmlRefNodeMap[inst.xmlRef]=inst end
	end
	local sstrBlobs={};local sstrKeyToIdx={};local sc=0
	if xmlSharedStrings and next(xmlSharedStrings)then
		sc+=1;sstrBlobs[sc]="";sstrKeyToIdx[""]=0
		for key,blob in pairs(xmlSharedStrings)do
			sc+=1;sstrBlobs[sc]=blob;sstrKeyToIdx[key]=sc-1
		end
	end
	local typeOrder={};local typeIndexMap={};local toc=0
	for i=1,na do
		local cn=allInsts[i].className
		if not typeIndexMap[cn]then
			toc+=1;typeIndexMap[cn]=toc;typeOrder[toc]=cn
		end
	end
	local classGroups={}for i=1,na do
		local cn=allInsts[i].className
		local g=classGroups[cn]if not g then g={};classGroups[cn]=g end
		g[#g+1]=allInsts[i]end
	local ic=0;local instChunks=tcreat(toc)for ti=1,toc do
		local className=typeOrder[ti]local group=classGroups[className]local ng=#group
		local refs=tcreat(ng)for i=1,ng do refs[i]=refMap[group[i]]end
		local payload=spack("<I4",ti-1)..spack("<I4",#className)..className.."\x00"..spack("<I4",ng)..interleaveRef(refs)ic+=1;instChunks[ic]=makeChunk("INST",payload)end
	local propNames={}for i=1,na do
		local inst=allInsts[i];local cn=inst.className
		local pm=propNames[cn]if not pm then pm={};propNames[cn]=pm end
		for pname in pairs(inst.properties)do pm[pname]=true end
	end
	local PROTECTED_STRING_PROPS={}local pcc=0;local propChunks={}for ti=1,toc do
		local className=typeOrder[ti]local group=classGroups[className]local ng=#group
		local pnames={};local pnc=0
		for pname in pairs(propNames[className]or{})do pnc+=1;pnames[pnc]=pname end
		tsort(pnames)for pi=1,pnc do
			local pname=pnames[pi]local typeId=nil;local vals=tcreat(ng)for i=1,ng do
				local prop=group[i].properties[pname]if prop and type(prop)=="table" then
					if prop.typeId then
						if not typeId then typeId=prop.typeId end
						vals[i]=prop.value
					elseif prop.xmlTag then
						local tid=xmlTagToTypeId[prop.xmlTag]or 0x01
						if not typeId then typeId=tid end
						local v=getType(tid).readXml(prop.text or "",prop.sub or{})if v~=nil then
							if tid==0x1C then
								local key=prop.text or ""
								local idx=sstrKeyToIdx[key]if idx==nil then
									sc+=1;sstrBlobs[sc]="";sstrKeyToIdx[key]=sc-1;idx=sc-1
								end
								vals[i]=idx
							elseif tid==0x1E3 then
								local blob=base64Decode(prop.text or "")local idx=sstrKeyToIdx[blob]if idx==nil then
									sc+=1;sstrBlobs[sc]=blob;sstrKeyToIdx[blob]=sc-1;idx=sc-1
								end
								vals[i]=idx
							elseif tid==0x13 and v and v~=-1 then
								local refNode=xmlRefNodeMap[prop.text or ""]vals[i]=refNode and refMap[refNode]or v
							else
								vals[i]=v
							end
						end
					end
				end
			end
			if not typeId then continue end
			local typeInfo=getType(typeId)for i=1,ng do
				if vals[i]==nil then
					if typeId==0x01 then vals[i]=""
					elseif typeId==0x02 then vals[i]=false
					elseif typeId==0x03 or typeId==0x04 or typeId==0x05
					 or typeId==0x0B or typeId==0x12 then vals[i]=0
					elseif typeId==0x0C then vals[i]={r=0,g=0,b=0}elseif typeId==0x0E then vals[i]={x=0,y=0,z=0}elseif typeId==0x10 then vals[i]={r=CF_IDENTITY,x=0,y=0,z=0}elseif typeId==0x13 then vals[i]=-1
					elseif typeId==0x1E then vals[i]=false
					elseif typeId==0x1E2 or typeId==0x1E4 then vals[i]=""
					elseif typeId==0x1F then vals[i]=("\0"):rep(16)
					elseif typeId==0x20 then vals[i]={family="",weight=400,style=0,cachedFaceId=""}elseif typeId==0x21 or typeId==0x22 then vals[i]=0
					else vals[i]=0 end
				end
			end
			local binData=typeInfo.writeBin(vals)if binData and#binData>0 then
				local binTypeId
				if typeId==0x22 then binTypeId=0x1D
				elseif typeId==0x1E2 then binTypeId=0x01
				elseif typeId==0x1E3 then binTypeId=0x1C
				elseif typeId==0x1E4 and not PROTECTED_STRING_PROPS[pname]then binTypeId=0x01
				else binTypeId=typeId end
				local payload=spack("<I4I4",ti-1,#pname)..pname..chr[binTypeId]..binData
				pcc+=1;propChunks[pcc]=makeChunk("PROP",payload)end
		end
	end
	local sstrChunk
	if sc>0 then
		local sp=0;local sparts=tcreat(sc*2+2)sp+=1;sparts[sp]=spack("<I4",0)sp+=1;sparts[sp]=spack("<I4",sc)for i=1,sc do
			local blob=sstrBlobs[i]sp+=1;sparts[sp]=newBlobKey()sp+=1;sparts[sp]=spack("<I4",#blob)..blob
		end
		sstrChunk=makeChunk("SSTR",tconc(sparts))end
	local childRefs=tcreat(na);local parentRefs=tcreat(na)for i=1,na do
		local inst=allInsts[i]childRefs[i]=refMap[inst]parentRefs[i]=inst.parent and refMap[inst.parent]or-1
	end
	local prntPayload="\x00"..spack("<I4",na)..interleaveRef(childRefs)..interleaveParentRef(parentRefs)local prntChunk=makeChunk("PRNT",prntPayload)local endPayload="</roblox>"
	local endChunk="END\0"..spack("<I4",0)..spack("<I4",#endPayload)..spack("<I4",0)..endPayload
	local header=RBX_MAGIC..spack("<I4",toc)..spack("<I4",na)..spack("<I4",0)..spack("<I4",0)local fp=0;local final=tcreat(4+ic+pcc)fp+=1;final[fp]=header
	if sstrChunk then fp+=1;final[fp]=sstrChunk end
	for i=1,ic do fp+=1;final[fp]=instChunks[i]end
	for i=1,pcc do fp+=1;final[fp]=propChunks[i]end
	fp+=1;final[fp]=prntChunk
	fp+=1;final[fp]=endChunk
	return tconc(final)end
local function serializeXml(roots,sharedStrs,sharedKeys)local lc=0;local lines={}lc+=1;lines[lc]='<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime"'..' xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"'..' xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd"'..' version="4">'
	local blobKeyCache={}if sharedKeys and sharedStrs then
		local usedKeys={}for idx,key in pairs(sharedKeys)do
			local blob=sharedStrs[idx]if blob and not blobKeyCache[blob]and not usedKeys[key]then
				blobKeyCache[blob]=key;usedKeys[key]=true
			end
		end
	end
	local function getBlobKey(blob)if not blobKeyCache[blob]then blobKeyCache[blob]=newBlobKey()end
		return blobKeyCache[blob]end
	local sharedBlobByMd5={}local function collectSharedBlobs(node)for pname,prop in pairs(node.properties)do
			if type(prop)=="table" and prop.typeId==0x1C and not CONTENT_PROPS[pname]then
				local idx=prop.value
				if type(idx)=="number" and sharedStrs and sharedStrs[idx]then
					local blob=sharedStrs[idx]sharedBlobByMd5[getBlobKey(blob)]=blob
				end
			end
		end
		local ch=node.children
		for i=1,#ch do collectSharedBlobs(ch[i])end
	end
	if sharedStrs then
		for i=1,#roots do collectSharedBlobs(roots[i])end
	end
	if next(sharedBlobByMd5)then
		lc+=1;lines[lc]="\t<SharedStrings>"
		for key,blob in pairs(sharedBlobByMd5)do
			local keyB64=base64Encode(key)local blobB64=base64Encode(blob)local nb=#blobB64
			local wc=0;local wrapped=tcreat(mceil(nb/76))for i=1,nb,76 do wc+=1;wrapped[wc]="\t\t\t"..ssub(blobB64,i,i+75)end
			lc+=1;lines[lc]='\t\t<SharedString md5="'..keyB64..'">'
			lc+=1;lines[lc]=tconc(wrapped,"\n")lc+=1;lines[lc]="\t\t</SharedString>"
		end
		lc+=1;lines[lc]="\t</SharedStrings>"
	end
	local tabCache=tcreat(8)for d=0,7 do tabCache[d]=srep("\t",d)end
	local function getTab(d)return tabCache[d]or srep("\t",d)end
	local function writeNode(node,indent)local tab=getTab(indent)local tab1=getTab(indent+1)local tab2=getTab(indent+2)lc+=1;lines[lc]=tab..'<Item class="'..xmlEscape(node.className)..'" referent="RBX'..sfmt("%08X",node.referent)..'">'
		lc+=1;lines[lc]=tab1.."<Properties>"
		local pnames={};local pnc=0
		for pname in pairs(node.properties)do pnc+=1;pnames[pnc]=pname end
		tsort(pnames)for pi=1,pnc do
			local pname=pnames[pi]local prop=node.properties[pname]local typeId,value
			if type(prop)=="table" and prop.typeId then
				typeId=prop.typeId;value=prop.value
			elseif type(prop)=="table" and prop.xmlTag then
				typeId=xmlTagToTypeId[prop.xmlTag]or 0x01
				value=getType(typeId).readXml(prop.text,prop.sub or{})else continue end
			if typeId==0x1C or typeId==0x1E3 then
				local idx=type(value)=="number" and value or tonumber(value)or 0
				local blob=sharedStrs and sharedStrs[idx]or ""
				if CONTENT_PROPS[pname]then
					typeId=0x22;value=blob
				elseif typeId==0x1E3 then
					value=blob
				else
					value=base64Encode(getBlobKey(blob))end
			end
			local typeInfo=getType(typeId)local tag=typeInfo.xmlTag
			local ok,inner=pcall(typeInfo.writeXml,value)if ok then
				local encoded
				if typeId==0x1E4 then
					local sv=tostring(inner or "")if sv:find("[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]")then
						encoded=base64Encode(sv);tag="BinaryString"
					else encoded="<![CDATA["..sv.."]]>" end
				elseif typeId==0x01 or typeId==0x02 or typeId==0x03 or typeId==0x04
				 or typeId==0x05 or typeId==0x0B or typeId==0x12 or typeId==0x15
				 or typeId==0x16 or typeId==0x17 or typeId==0x1B or typeId==0x1C
				 or typeId==0x21 then
					local sv=tostring(inner or "")if sv:find("[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\xFF]")then
						encoded=base64Encode(sv);tag="BinaryString"
					else encoded=xmlEscape(sv)end
				else
					encoded=inner
				end
				lc+=1;lines[lc]=tab2.."<"..tag..' name="'..xmlEscape(pname)..'">'..encoded.."</"..tag..">"
			end
		end
		lc+=1;lines[lc]=tab1.."</Properties>"
		local ch=node.children
		for i=1,#ch do writeNode(ch[i],indent+1)end
		lc+=1;lines[lc]=tab.."</Item>"
	end
	for i=1,#roots do writeNode(roots[i],1)end
	lc+=1;lines[lc]="</roblox>"
	return tconc(lines,"\n")end
function Converter.XMLToBinary(xmlString)assert(type(xmlString)=="string" and#xmlString>0,"XMLToBinary: expected a non-empty XML string")local roots,xmlSharedStrings=parseXml(xmlString)assert(#roots>0,"XMLToBinary: no instances found in XML string")return serializeBinary(roots,xmlSharedStrings)end
function Converter.BinaryToXML(binaryString)assert(type(binaryString)=="string" and#binaryString>0,"BinaryToXML: expected a non-empty binary string")local roots,sharedStrs,sharedKeys=parseBinary(binaryString)assert(#roots>0,"BinaryToXML: no instances found in binary string")return serializeXml(roots,sharedStrs,sharedKeys)end
return Converter
