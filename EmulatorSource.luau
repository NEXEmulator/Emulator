--!native
--!nolint
--!nocheck
--!optimize 3
local game,workspace=cloneref(game),cloneref(workspace) --this is not to stop detection from weaktables, this is just so replications to the Instance metatable dont replicate to these instances for better security, I might be just paranoid, but better safe than sorry.
local function NEXRequire(x)
return request({Url=`https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/{x}`,Method="GET"}).Body
end
local function ImportToFolder(x,y)
for i,v in next,y do
if not isfile(`{x}/{i}`) then
writefile(`{x}/{i}`,NEXRequire(v))
              end
      end
end
if not isfolder(".icons") then
makefolder(".icons")
ImportToFolder(".icons",{
["NEX.png"]="Icons/NEX.png",
[".nomedia"]="Icons/.nomedia"
})
end
local version="1.0.8"
local lastversion="1.0.7"
local NEXIcon=getcustomasset(".icons/NEX.png")
local LoadedIcons={NEX=NEXIcon}
local clonef=clonefunction(clonefunction)
local err=clonef(error)
local canhead=({pcall(request,{Url="https://raw.githubusercontent.com",Method="HEAD"})})[1]
local cppf=clonef(newcclosure)
local rawsmt=clonef(setrawmetatable)
local rawmt=clonef(getrawmetatable)
local tclone=clonef(table.clone)
local srot={
  __metatable="The metatable is locked.",
  __newindex=cppf(function()err"attempt to modify a protected metatable"end)
}
local sro=clonef(setreadonly) or cppf(function(x,y)
    if y then
      rawsmt(x,{srot})
    else
      rawsmt(x,{})
    end
  end)
local tablepc=cppf(function(x)
    local ta=tclone(x)
    sro(ta,true)
    return ta
  end)
local cclose,info,genv,index,newindex=coroutine.close,debug.info,loadstring(NEXRequire("AllowedFunctions.luau"))()
xpcall(function()workspace[nil]()end,function()index=clonef(info(2,'f'))end)xpcall(function()workspace.woahs=1 end,function()newindex=clonef(info(2,'f'))end)
local GetService=index(game,"GetService")
local GuiService=cloneref(GetService(game,"GuiService"))
local ot=os.clock
local t=ot()
local NEXTitle=`NEX Emulator (V{version})`
local SendNotification=clonef(index(GuiService,"SendNotification"))
SendNotification(GuiService,{
Icon=NEXIcon,
Title=NEXTitle,
Text="NEX Emulation starting..."
})
local tw=task.wait
local FindFirstChild=clonef(index(workspace,"FindFirstChild"))
local NetworkClient=cloneref(GetService(game,"NetworkClient"))
local GetChildren=clonef(index(workspace,"GetChildren"))
local Clone=clonef(index(workspace,"Clone"))
local IsA=clonef(index(workspace,"IsA"))
local ClientReplicator=cloneref(FindFirstChild(NetworkClient,"ClientReplicator"))
local Destroy=clonef(index(game,"Destroy"))
if not isfolder("GameData") then
makefolder("GameData")
end
local rgca=clonef(getcustomasset)
local rwarn=clonef(warn)
local rtype=clonef(type)
local cdef=clonef(task.defer)
local def=function(x,...) return cdef(function(...)return x(...)end,...)end
local reg=getreg()
local GameId=index(game,"GameId")
local HttpService=cloneref(GetService(game,"HttpService"))
local MarketplaceService=cloneref(GetService(game,"MarketplaceService"))
local GetProductInfo=clonef(index(MarketplaceService,"GetProductInfo"))
local JsonDecode=clonef(index(HttpService,"JSONDecode"))
local JsonEncode=clonef(index(HttpService,"JSONEncode"))
local rootid=JsonDecode(HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{GameId}`,Method="GET"}).Body).rootPlaceId
local behave=`GameData/{rootid}/Storage/`
local SettingsPrefix=`GameData/{rootid}/`
if not isfolder(SettingsPrefix) then
makefolder(SettingsPrefix)
end
if not isfolder(behave) then
makefolder(behave)
end
local gca=function(x) return rgca(`{behave}{x}`) end
local RootName=`{SettingsPrefix}RootName {GetProductInfo(MarketplaceService,rootid).Name}`
local SettingsExist=isfile(`{SettingsPrefix}Settings.json`)
local s,settingst=pcall(function()
return JsonDecode(HttpService,readfile(`{SettingsPrefix}Settings.json`))
end)
local origs={CapabilityMax=2,EmulateOnGameIsLoaded=true,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms=false,DebugMode=false,RobloxScriptRequire=true,XMLEnabled=true}
if not isfile("StarterSettings.json") then
writefile("StarterSettings.json",JsonEncode(HttpService,origs))
end
local settings=SettingsExist and s and settingst or JsonDecode(HttpService,readfile("StarterSettings.json"))
local stjson
if not isfile("._NEXVERSION") or readfile("._NEXVERSION")==lastversion then
  writefile("._NEXVERSION",version)
  for i,v in next,origs do
    if settings[i]==nil then
      settings[i]=v
    end
  end
  stjson=JsonEncode(HttpService,settings)
  writefile("StarterSettings.json",stjson)
else
stjson=JsonEncode(HttpService,settings)
end
if not SettingsExist then
writefile(`{SettingsPrefix}Settings.json`,stjson)
end
local IsLoaded=index(game,"IsLoaded")
if settings.EmulateOnGameIsLoaded then
repeat tw() until IsLoaded(game)
end
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local SetStateEnabled=clonef(Instance.new"Humanoid".SetStateEnabled)
local rnexists=`{SettingsPrefix}.rootname`
if not isfile(rnexists) then
writefile(RootName,' ')
writefile(rnexists,' ')
end
local grenv=getrenv()
local rrequire=grenv.require
local exstr="hi"
local find,sub=clonef(exstr.find),clonef(exstr.sub)
local foundationimage=function(x)
return find(x,"://")~=nil
end
if settings.RobloxScriptRequire then
genv.Rrequire=rrequire
else
genv.RobloxScriptRequire=function(...)
rwarn("RobloxScriptRequire disabled.")
end
end
local Identity={setidentity=1,getthreadidentity=1}
local renv={}
local InsertService=cloneref(GetService(game,"InsertService"))
local LLA=clonef(index(InsertService,"LoadLocalAsset"))
local Players=cloneref(GetService(game,"Players"))
local ClearError=clonef(index(GuiService,"ClearError"))
local oldset=setidentity
local oldti=getthreadidentity
local LP=cloneref(index(Players,"LocalPlayer"))
local Kick=index(LP,"Kick")
local function GetCurrentThread()
local ThreadIdentifier=info(0,'f')
for _,v in reg do
if rtype(v)=="thread" and info(v,0,'f')==ThreadIdentifier then
return v
end
end
end
local currentthread=GetCurrentThread()
genv.GetCurrentThread=GetCurrentThread
genv.DisconnectFromServer=function()
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
Kick(LP)
ClearError(GuiService)
repeat tw() until index(ClientReplicator,"Parent")==nil
local char=cloneref(index(LP,"Character"))
newindex(char,"Archivable",true)
local c=GetChildren(Clone(char))
for i,v in GetChildren(char) do --didnt use next because it's already an integer placement, not a dict
if IsA(v,"BasePart") or index(v,"ClassName")=="Accessory" then --I wanted to use if not v:IsA"LuaSourceContainer" but it didnt let me walk for some reason
Destroy(v)
newindex(c[i],"Parent",char)
end
end
local hum=cloneref(index(char,"Humanoid"))
SetStateEnabled(hum,15,false)
end
genv.ToastNotify=function(x)
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
      end
local ticon=x.Icon
x.Icon=(foundationimage(ticon) and nil) or ticon
return SendNotification(GuiService,x)
end
local HttpEnabled=settings.HTTPEnabled
local FilesEnabled=settings.FilesEnabled
local ExternalFilePerms=settings.ExternalFilePerms
local gitpattern="^https://github.com/([^/]+)/([^/]+)(.*)$"
local apipattern="https://api.github.com/repos/%s/%s/contents/%s"
local apiwpattern="https://api.github.com/repos/%s/%s/contents/"
local match=clonef(string.match)
local function convertgit(x)
  local owner,repo,folder=match(x,gitpattern)
  if owner and repo then
      if folder and folder ~= "" then
          folder = folder:gsub("^/", "")
          return string.format(apipattern, owner, repo, folder),repo
      else
          return string.format(apiwpattern, owner, repo),repo
      end
  else
      return nil
  end
end
local df,dfo=clonef(delfile),clonef(delfolder)
local wf=clonef(writefile)
local xml={
Name="",
}
local woahc=clonef(pcall)
local XMLEnabled=settings.XMLEnabled
local function xmlobject(x,y)
if XMLEnabled then
local obj
if xml.Name==x then
    obj=xml.Object
    else
    local xmlc=`<roblox version="4"><Item Class="{x}"></Item></roblox>`
    wf('.xmlcache',xmlc)
    xml.Name=x
    obj=rgca'.xmlcache'
    xml.Object=obj
    df'.xmlcache'
    end
local instance=LLA(InsertService,obj)
if y then
        woahc(newindex,instance,"Parent",y)
    end
return instance
  else
    rwarn("XML permissions denied.")
  end
end
local function loadxml(x)
if XMLEnabled then
xml.Name=""
wf(".xmlcache",x)
local obj=LLA(InsertService,rgca'.xmlcache')
df'.xmlcache'
return obj
  else
    rwarn("XML permissions denied.")
  end
end
local sf,gsub,gmatch=clonef(string.format),clonef(string.gsub),clonef(string.gmatch)
local ti,tc,tun,tsort=clonef(table.insert),clonef(table.concat),clonef(table.unpack),clonef(table.sort)
local ton,tos,typo=clonef(tonumber),clonef(tostring),clonef(typeof)
local mfloor=clonef(math.floor)
local V3,V2,V3i16,V2i16,CF,UD,UD2,Rec,NR,NS,NSK,CS,CSK,C3,PP,Fa,Ax=Vector3.new,Vector2.new,Vector3int16.new,Vector2int16.new,CFrame.new,UDim.new,UDim2.new,Rect.new,NumberRange.new,NumberSequence.new,NumberSequenceKeypoint.new,ColorSequence.new,ColorSequenceKeypoint.new,Color3.new,PhysicalProperties.new,Faces.new,Axes.new
local EnAx,EnNI=Enum.Axis,Enum.NormalId
local function clean(s)return(gsub(s,"%s+",""))end
local function getfaces(v)local f={}if v.Right then ti(f,EnNI.Right)end if v.Top then ti(f,EnNI.Top)end if v.Back then ti(f,EnNI.Back)end if v.Left then ti(f,EnNI.Left)end if v.Bottom then ti(f,EnNI.Bottom)end if v.Front then ti(f,EnNI.Front)end return Fa(tun(f))end
local function getaxes(v)local a={}if v.X then ti(a,EnAx.X)end if v.Y then ti(a,EnAx.Y)end if v.Z then ti(a,EnAx.Z)end return Ax(tun(a))end
local typemap={
["Vector3"]={enc=function(p)local v=p.Value return sf('<X>%g</X><Y>%g</Y><Z>%g</Z>',v.X,v.Y,v.Z)end,dec=function(s)s=clean(s)return V3(ton(match(s,"<X>(.-)</X>"))or 0,ton(match(s,"<Y>(.-)</Y>"))or 0,ton(match(s,"<Z>(.-)</Z>"))or 0)end},
["Vector2"]={enc=function(p)local v=p.Value return sf('<X>%g</X><Y>%g</Y>',v.X,v.Y)end,dec=function(s)s=clean(s)return V2(ton(match(s,"<X>(.-)</X>"))or 0,ton(match(s,"<Y>(.-)</Y>"))or 0)end},
["Vector3int16"]={enc=function(p)local v=p.Value return sf('<X>%d</X><Y>%d</Y><Z>%d</Z>',v.X,v.Y,v.Z)end,dec=function(s)s=clean(s)return V3i16(ton(match(s,"<X>(.-)</X>"))or 0,ton(match(s,"<Y>(.-)</Y>"))or 0,ton(match(s,"<Z>(.-)</Z>"))or 0)end},
["Vector2int16"]={enc=function(p)local v=p.Value return sf('<X>%d</X><Y>%d</Y>',v.X,v.Y)end,dec=function(s)s=clean(s)return V2i16(ton(match(s,"<X>(.-)</X>"))or 0,ton(match(s,"<Y>(.-)</Y>"))or 0)end},
["CFrame"]={enc=function(p)local c={p.Value:GetComponents()}return sf('<X>%g</X><Y>%g</Y><Z>%g</Z><R00>%g</R00><R01>%g</R01><R02>%g</R02><R10>%g</R10><R11>%g</R11><R12>%g</R12><R20>%g</R20><R21>%g</R21><R22>%g</R22>',tun(c))end,dec=function(s)s=clean(s)local c={}for v in gmatch(s,">([^<]+)<")do ti(c,ton(v))end if#c<12 then c={ton(match(s,"<X>(.-)</X>")),ton(match(s,"<Y>(.-)</Y>")),ton(match(s,"<Z>(.-)</Z>")),ton(match(s,"<R00>(.-)</R00>")),ton(match(s,"<R01>(.-)</R01>")),ton(match(s,"<R02>(.-)</R02>")),ton(match(s,"<R10>(.-)</R10>")),ton(match(s,"<R11>(.-)</R11>")),ton(match(s,"<R12>(.-)</R12>")),ton(match(s,"<R20>(.-)</R20>")),ton(match(s,"<R21>(.-)</R21>")),ton(match(s,"<R22>(.-)</R22>"))}end return CF(tun(c))end},
["UDim"]={enc=function(p)local v=p.Value return sf('<S>%g</S><O>%d</O>',v.Scale,v.Offset)end,dec=function(s)s=clean(s)return UD(ton(match(s,"<S>(.-)</S>"))or 0,ton(match(s,"<O>(.-)</O>"))or 0)end},
["UDim2"]={enc=function(p)local v=p.Value return sf('<XS>%g</XS><XO>%d</XO><YS>%g</YS><YO>%d</YO>',v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)end,dec=function(s)s=clean(s)return UD2(ton(match(s,"<XS>(.-)</XS>"))or 0,ton(match(s,"<XO>(.-)</XO>"))or 0,ton(match(s,"<YS>(.-)</YS>"))or 0,ton(match(s,"<YO>(.-)</YO>"))or 0)end},
["Rect2D"]={enc=function(p)local v=p.Value return sf('<min><X>%g</X><Y>%g</Y></min><max><X>%g</X><Y>%g</Y></max>',v.Min.X,v.Min.Y,v.Max.X,v.Max.Y)end,dec=function(s)s=clean(s)return Rec(ton(match(s,"<min>.*<X>(.-)</X>"))or 0,ton(match(s,"<min>.*<Y>(.-)</Y>"))or 0,ton(match(s,"<max>.*<X>(.-)</X>"))or 0,ton(match(s,"<max>.*<Y>(.-)</Y>"))or 0)end},
["NumberRange"]={enc=function(p)return sf('%g %g',p.Value.Min,p.Value.Max)end,dec=function(s)local m1,m2=match(s,"([^%s]+)%s+([^%s]+)")return NR(ton(m1)or 0,ton(m2)or 0)end},
["NumberSequence"]={enc=function(p)local r={}for _,k in ipairs(p.Value.Keypoints)do ti(r,sf("%g %g %g",k.Time,k.Value,k.Envelope))end return tc(r," ")end,dec=function(s)local k,v={},{}for x in gmatch(s,"([^%s]+)")do ti(v,ton(x))end for i=1,#v,3 do ti(k,NSK(v[i],v[i+1],v[i+2]))end return NS(k)end},
["ColorSequence"]={enc=function(p)local r={}for _,k in ipairs(p.Value.Keypoints)do ti(r,sf("%g %g %g %g 0",k.Time,k.Value.R,k.Value.G,k.Value.B))end return tc(r," ")end,dec=function(s)local k,v={},{}for x in gmatch(s,"([^%s]+)")do ti(v,ton(x))end for i=1,#v,5 do ti(k,CSK(v[i],C3(v[i+1],v[i+2],v[i+3])))end return CS(k)end},
["Color3"]={enc=function(p)local v=p.Value return sf('<R>%g</R><G>%g</G><B>%g</B>',v.R,v.G,v.B)end,dec=function(s)s=clean(s)return C3(ton(match(s,"<R>(.-)</R>"))or 0,ton(match(s,"<G>(.-)</G>"))or 0,ton(match(s,"<B>(.-)</B>"))or 0)end},
["Color3uint8"]={enc=function(p)local v=p.Value return tos(4278190080+(mfloor(v.R*255)*65536)+(mfloor(v.G*255)*256)+mfloor(v.B*255))end,dec=function(s)local u=ton(s)or 0 return Color3.fromRGB(mfloor(u/65536)%256,mfloor(u/256)%256,u%256)end},
["PhysicalProperties"]={enc=function(p)local v=p.Value if v==nil then return "null" end if typo(v)=="string" then return v end return sf('<CustomPhysics>true</CustomPhysics><Density>%g</Density><Friction>%g</Friction><Elasticity>%g</Elasticity><FrictionWeight>%g</FrictionWeight><ElasticityWeight>%g</ElasticityWeight>',v.Density,v.Friction,v.Elasticity,v.FrictionWeight,v.ElasticityWeight)end,dec=function(s)return s end},
["Faces"]={enc=function(p)local v,f=p.Value,0 if v.Right then f+=1 end if v.Top then f+=2 end if v.Back then f+=4 end if v.Left then f+=8 end if v.Bottom then f+=16 end if v.Front then f+=32 end return tos(f)end,dec=function(s)local i=ton(s)or 0 return getfaces({Right=(i%2>=1),Top=(i%4>=2),Back=(i%8>=4),Left=(i%16>=8),Bottom=(i%32>=16),Front=(i%64>=32)})end},
["Axes"]={enc=function(p)local v,f=p.Value,0 if v.X then f+=1 end if v.Y then f+=2 end if v.Z then f+=4 end return tos(f)end,dec=function(s)local i=ton(s)or 0 return getaxes({X=(i%2>=1),Y=(i%4>=2),Z=(i%8>=4)})end}
}
typemap["CoordinateFrame"]=typemap["CFrame"]
local function tabletoxml(root)
  local out={'<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'}
  local uss={}
  local function scan(t)for k,v in next,t do if type(v)=="table" and v.Tag=="SharedString" then uss[v.Value]=true end if type(k)=="string" and k:find("^Item") then scan(v) end end end
  scan(root)
  if root.SharedStrings then local sb={} for h,c in next,root.SharedStrings do if uss[h] then ti(sb,sf('<SharedString md5="%s">%s</SharedString>',h,c)) end end if #sb>0 then ti(out,"\n<SharedStrings>") ti(out,"\n"..tc(sb,"\n")) ti(out,"\n</SharedStrings>") end end
  local refmap,refcnt={},0
  local function remap_refs(t)
    local it={} for k,v in next,t do if typo(k)=="string" and k:find("^Item") then ti(it,{k,v}) end end
    tsort(it,function(a,b) return (ton(match(a[1],"%d+"))or 0)<(ton(match(b[1],"%d+"))or 0) end)
    for _,pair in ipairs(it) do
      local d=pair[2]
      refcnt=refcnt+1
      local oldRef=d.Referent
      local newRef=sf("NEX%d",refcnt)
      if oldRef then refmap[oldRef]=newRef end
      d.Referent=newRef
      remap_refs(d)
    end
  end
  remap_refs(root)
  local function proc(t)
    local it={} for k,v in next,t do if typo(k)=="string" and k:find("^Item") then ti(it,{k,v}) end end
    tsort(it,function(a,b) return (ton(match(a[1],"%d+"))or 0)<(ton(match(b[1],"%d+"))or 0) end)
    for _,pair in ipairs(it) do
      local d,ref=pair[2],pair[2].Referent
      ti(out,sf('\n<Item class="%s" referent="%s">',d.ClassName or "Part",ref)) ti(out,"\n<Properties>")
      for pn,pw in next,d do
        if pn~="ClassName" and pn~="Referent" and not pn:find("^Item") and typo(pw)=="table" and pw.Tag then
          local tag,logic=pw.Tag,typemap[pw.Tag]
          if tag=="Ref" then 
            local v = pw.Value
            if v and refmap[v] then v=refmap[v] end
            ti(out,sf('\n<Ref name="%s">%s</Ref>',pn,(v==nil)and"null"or tos(v)))
          elseif tag=="BinaryString" or tag=="ProtectedString" or tag=="string" then ti(out,sf('\n<%s name="%s"><![CDATA[%s]]></%s>',tag,pn,pw.Value,tag))
          elseif logic then local val=logic.enc(pw) ti(out,sf('\n<%s name="%s">%s</%s>',tag,pn,(val=="null")and"null"or val,tag))
          elseif tag=="UniqueId" or tag=="SharedString" then ti(out,sf('\n<%s name="%s">%s</%s>',tag,pn,pw.Value,tag))
          elseif tag=="bool" then ti(out,sf('\n<bool name="%s">%s</bool>',pn,tos(pw.Value)))
          elseif tag=="int" or tag=="int64" then ti(out,sf('\n<%s name="%s">%d</%s>',tag,pn,pw.Value,tag))
          elseif tag=="float" or tag=="double" then ti(out,sf('\n<%s name="%s">%g</%s>',tag,pn,pw.Value,tag))
          elseif tag=="token" then ti(out,sf('\n<%s name="%s">%d</%s>',tag,pn,mfloor(pw.Value+0.5),tag))
          else ti(out,sf('\n<%s name="%s">%s</%s>',tag,pn,tos(pw.Value),tag)) end
        end end
      ti(out,"\n</Properties>") proc(d) ti(out,"\n</Item>")
    end end
  proc(root) ti(out,"\n</roblox>") return tc(out)
end
local function xmltotable(xml)
  local ss={} for h,b in gmatch(xml,'<SharedString md5="([^"]+)">([^<]*)</SharedString>') do ss[h]=b end
  local function parse(s)
    local res,idx,pos={},1,1
    while true do
      local b,e,cls,ref=s:find('<Item class="([^"]*)" referent="([^"]*)"[^>]*>',pos)
      if not b then b,e,cls=s:find('<Item class="([^"]*)"[^>]*>',pos) end if not b then break end
      local d,ce=1,e+1
      while d>0 do local no,nc=s:find('<Item%s',ce),s:find('</Item>',ce) if nc and(not no or nc<no) then d-=1 ce=nc+7 elseif no then d+=1 ce=no+6 else break end end
      local idat={ClassName=cls,Referent=ref} local body=s:sub(b,ce) local ps,pe,pc=body:find("<Properties>"),nil,body:find("</Properties>")
      if ps and pc then pe=ps+11 local px=body:sub(pe+1,pc-1)
        for tag,n,c in gmatch(px,"<([^%s>]+) name=\"([^\"]+)\">(.-)</%1>") do
          local v=c if tag=="BinaryString" or tag=="ProtectedString" or tag=="string" then v=gsub(c,"<!%[CDATA%[(.-)%]%]>","%1")
          elseif tag=="bool" then v=(c=="true") elseif tag=="int" or tag=="float" or tag=="double" or tag=="token" or tag=="int64" then v=ton(c)
          elseif tag=="Ref" then v=(c~="null"and c)or nil elseif typemap[tag] then v=typemap[tag].dec(c) elseif tag=="SharedString" then v=c end
          idat[n]={Tag=tag,Value=v} end end
      local chi=parse(body:sub((pc or 0)+13,#body-7)) for k,v in next,chi do idat[k]=v end
      res["Item"..idx]=idat idx+=1 pos=ce
    end return res end
  local fin=parse(xml) fin.SharedStrings=ss return fin
end
local req=clonef(request)
local mf=clonef(makefolder)
local isf=clonef(isfile)
local function getgit(x)
local url,repo=convertgit(x)
local tab=JsonDecode(HttpService,req({Url=url,Method="GET"}).Body)
  local newtable={}
  for _,v in tab do
      newtable[v.name]={
          path=v.path,
          url=v.html_url,
          rawurl=v.download_url,
          type=v.type,
          self=v.url
      }
  end
  return newtable,repo
end
local reverse=clonef(string.reverse)
local function splitxml(xml,y)
local res={}
local s=xml
local h=match(xml,"(<roblox[^>]*>)") or '<roblox version="4">'
if find(s,"^<roblox")then
s=reverse(gsub(reverse(gsub(s,"^<roblox[^>]*>","")),">xolbor/<","",1))
end
if find(s,"^%s*<Item")then
s=gsub(s,"^%s*","")
local _,p=find(s,"<Properties>.-</Properties>")
if not p then _,p=find(s,"^<Item[^>]*>")end
s=reverse(gsub(reverse(sub(s,p+1)),">metI/<","",1))
end
local cur=1
while true do
local b,e,c=find(s,'<Item class="([^"]+)"[^>]*>',cur)
if not b then break end
local d,p,f=1,e+1,nil
while d>0 do
local ns,ne=find(s,'<Item%s',p)
local cs,ce=find(s,'</Item>',p)
if cs and(not ns or cs<ns)then
d=d-1
f=ce
p=ce+1
elseif ns then
d=d+1
p=ne+1
else break end
end
if f then
local x=sub(s,b,f)
if y then x=h..x..'</roblox>' end
ti(res,{Class=c,XML=x})
cur=f+1
else cur=e+1 end
end
return res
end
local XML={
Object=cppf(xmlobject),
Load=cppf(loadxml),
TableToXML=cppf(tabletoxml),
XMLToTable=cppf(xmltotable),
SplitXML=cppf(splitxml)
}
local roblox={XML=tclone(XML)}
renv.roblox=tclone(roblox)
genv.LoadLocalAsset=function(x)
if FilesEnabled then
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,gca(x))
end
rwarn("File permissions denied.")
end
genv.InsertAsset=function(x)
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,x)
end
local FileFamily={getfilename=1,readfile=1,writefile=1,isfile=1,isfolder=1,listfiles=1,makefolder=1,delfolder=1,delfile=1,appendfile=1,loadfile=1,getcustomasset=1}
local debugm=settings.DebugMode
genv.getfilename=function(x,removedot)
local slash,name=find(x,"/[^/]*$")
if slash then
name=sub(x,slash+1)
else
name=x
end
if removedot then
local dot=find(name,"%.")
if dot then
return sub(name,1,dot-1)
end
end
return name
end
local CapabilityMax=settings.CapabilityMax
local externalfp={}
renv.ExternalFileFunctions=externalfp
renv.Settings=tclone(settings)
renv.LoadedIcons=tclone(LoadedIcons)
for i,v in next,genv do
if not NotAllowed[i] then
if Identity[i] then
renv[i]=cppf(function(x)
if CapabilityMax>=(x or 0) then
return v(x)
else
rwarn("Capability changing permissions denied.")
end
end)
elseif FileFamily[i] then
if ExternalFilePerms then
externalfp[i]=clonef(v)
end
renv[i]=cppf(function(x,...)
if FilesEnabled then
return v(`{behave}{x}`,...)
end
rwarn("File permissions denied.")
end)
elseif HttpFamily[i] then
renv[i]=cppf(function(...)
if HttpEnabled then
return v(...)
end
rwarn("HTTP denied.")
end)
else 
if type(v)=="function" then
renv[i]=clonef(v)
else
renv[i]=tclone(v)
end
end
end
end
local function obsolete(x)
local n=cloneref(x)
setrawmetatable(n,{})
return n
end
local tonum=clonef(tonumber)
local nexenv={
task=task,
__index=index,
__newindex=newindex,
std={
NEXFunctions={},
call={protected=pcall,extended_protected=xpcall},
coutw=rwarn,
throw=err,
dicti=next,
cout=print,
tick=os.clock,
sleep=task.wait,
task=task,
os=os,
math=math,
functiondebug={
info=debug.info,
getenvironment=getfenv,
},
luadebug={
lua_registry=getreg()
},
table=table,
types={
luatype=type,
luautype=typeof
},
tabledebug={
__len=rawlen,
__index=rawget,
__newindex=rawset,
__metatable={rawgetmetatable=rawmt,rawsetmetatable=clonef(setrawmetatable)},
setmetatable=setmetatable,
__equal=rawequal,
getmetatable=getmetatable,
},
string=string,
convert={
tonumber=tonum,
tostring=tostring,
  },
globals={
globalenvironment=_G,
sharedenvironment=shared,
},
random=Random,
threads=coroutine,
luaL_dostring=loadstring,
RobloxObjects={
Game=obsolete(Game),
Color3=Color3,
Enum=Enum,
Path2DControlPoint=Path2DControlPoint,
PhysicalProperties=PhysicalProperties,
OverlapParams=OverlapParams,
Vector3=Vector3,
Vector2=Vector2,
RotationCurveKey=RotationCurveKey,
RaycastParams=RaycastParams,
TweenInfo=TweenInfo,
CFrame=CFrame,
UDim2=UDim2,
Font=Font,
UDim=UDim,
Instance=Instance,
}
}
}
setmetatable(nexenv,{
__metatable="The metatable is locked."
})
local function nex(x)
rawmt(x).__index=nexenv
end
local examplet={}
local getf=clonef(getfenv)
local cc,cr=coroutine.create,coroutine.resume
local precalculatedsize=1024*16
local NEXHttp={}
local apf=clonef(appendfile)
local function download(url,filename,chunksize)
if FilesEnabled then
local ext={installedsize=0,finished=false,WaitForFile=cppf(function(self)
repeat tw() until self.finished
return self.installedsize
end)}
if canhead then
ext.size=req{Url=url,Method='HEAD'}['Content-Length']
    else
ext.size="0"
    end
cr(cc(function()
chunksize=(chunksize and 1024*chunksize) or precalculatedsize
local start,Headers,body,bodysize=0,{}
wf(`{behave}{filename}`,'')
repeat Headers.Range=`bytes={start}-{start+chunksize-1}`
body=req{Url=url,Method='GET',Headers=Headers}.Body
apf(`{behave}{filename}`,body)
bodysize=#body
start+=bodysize
ext.installedsize=start
until bodysize<chunksize
ext.finished=true
end))
return ext
  else
      rwarn("File permissions denied.")
  end
end
local function streamget(url,chunksize)
if HttpEnabled then
local ext={installedsize=0,finished=false,body='',WaitForFile=cppf(function(self)
repeat tw() until self.finished
return self.body 
end)}
if canhead then
ext.size=req{Url=url,Method='HEAD'}['Content-Length']
   else
ext.size="0"
   end
cr(cc(function()
chunksize=(chunksize and 1024*chunksize) or precalculatedsize
local start,Headers,body,bodysize=0,{}
repeat Headers.Range=`bytes={start}-{start+chunksize-1}`
body=req{Url=url,Method='GET',Headers=Headers}.Body
ext.body=ext.body..body
bodysize=#body
start+=bodysize
ext.installedsize=start
until bodysize<chunksize
ext.finished=true
end))
return ext
  else
      rwarn("HTTP permissions denied.")
  end
end
local nd=cppf(clonef(download))
local git={
getgit=cppf(getgit),
clone=cppf(function(x)
          if FilesEnabled then
  local tab,repo=getgit(x)
  local rep=`{behave}{repo}/`
  mf(rep)
              local function check(i,v)
                  if v.type=="file" then
                      nd(v.rawurl,`{repo}/{v.path}`)
                  else
                  mf(`{rep}{v.path}`)
                  local newtab=getgit(`{x}/{v.path}`)
                  for i,v in next,newtab do
                          check(i,v)
                      end
                  end
              end
 for i,v in next,tab do
  check(i,v)
end
          else
              rwarn("File permissions denied.")
          end
      end)
}
NEXHttp.download=cppf(download)
NEXHttp.streamget=cppf(streamget)
renv.git=tclone(git)
local isfl=clonef(isfolder)
local lf=clonef(listfiles)
local gsub=clonef(exstr.gsub)
local requests={}
local byte=clonef(string.byte)
local sillystring='\\x%02X'
local function utf8(x)
local res={}
for i=1,#x do
res[i]=format(sillystring,byte(x,i))
    end
return tc(res)
end
local seriousstring = '\\x(%x%x)'
local woahnumber=16
local gmatch=clonef(string.gmatch)
local char=clonef(string.char)
local function untf8(x)
local res = {}
local amount=0 --Instead of #res+1, because this is faster
for hex in gmatch(x,seriousstring) do
amount+=1
res[amount] = char(tonum(hex,woahnumber))
end
return tc(res)
end
local function retq(x,url)
return {ok=x.Success,status_code=x.StatusCode,content=utf8(x.Body),text=x.Body,json=cppf(function() return JsonDecode(HttpService,x.Body)end),headers=x.Headers,raise_for_status=cppf(function() if not x.Success then err(x.StatusMessage) end end),url=url,elapsed=x.Headers['x-timer']}
end
requests.get=cppf(function(x,options)
if HttpEnabled then
options.Url=x
options.Method="GET"
return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.post=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="POST"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.options=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="OPTIONS"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.patch=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="PATCH"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.put=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="PUT"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.delete=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="DELETE"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.post=cppf(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="POST"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
local encrypt={
utf8={
encode=cppf(utf8),
decode=cppf(untf8)
  },
base64={
  encode=clonef(crypt.base64.encode),
  decode=clonef(crypt.base64.decode)
}
}
renv.crypt=tclone(encrypt)
renv.requests=tclone(requests)
renv.typefile=cppf(function(x)
if FilesEnabled then
if isf(`{behave}{x}`) then
return "file"
      elseif isfl(`{behave}{x}`) then
return "folder"
      else
        err("File doesnt exist!")
end
      else
          rwarn("File permissions denied.")
      end
  end)
local split=clonef(exstr.split)
local rf=clonef(readfile)
local function writeline(path,line,content) 
  local lines = {}
  for i,v in split(rf(`{behave}{path}`),'\n') do
  lines[i]=v
  end
  if not lines[line] then
  for i=1,line do
  lines[i]=lines[i] or ''
  end
  end
  lines[line]=content
wf(`{behave}{path}`,tc(lines, "\n"))
end
local function readline(path,line)
if FilesEnabled then
  local lines = {}
  for i,v in split(rf(`{behave}{path}`),'\n') do
  lines[i]=v
  end
  return lines[line]
  end
rwarn("File permissions denied.")
end
local globalread=cppf(function(self)
  return rf(`{behave}{self.Path}`)
end)
local globalwrite=cppf(function(self,x)
return wf(`{behave}{self.Path}`,x)
end)
local wl,rl=clonef(writeline),clonef(readline)
local globalwriteline=cppf(function(self,x,y)
return wl(self.Path,x,y)
end)
local globalreadline=cppf(function(self,x)
return rl(self.Path,x)
end)
local function checksexy(x,t)
for _,v in lf(`{behave}{x}`) do
t[#t+1]=v
if typefile(v)=="folder" then
check(v)
          end
end
end
local globalgd=cppf(function(self)
local t={}
checksexy(`{behave}{self.Path}`,t)
return t
end)
local globaldestroy=cppf(function(self)
if self.Type=="file" then
          df(`{behave}{self.Path}`)
  else
          dfo(`{behave}{self.Path}`)
  end
end)
local globalgc=cppf(function(self) 
return lf(`{behave}{self.Path}`)
end)
local function OpenFile(x)
if x then
if not isf(`{behave}{x}`) then
    wf(`{behave}{x}`,'')
  end
  else
x="unnamed"
if not isf(`{behave}{x}`) then --Why would any sane person even do this, just use the path argument!
wf(`{behave}{x}`,'')
    else
local newstr=`{behave}{x} (1)`
local count=1
while isf(newstr) do
count+=1
newstr=`{behave}{x} ({count})`
    end
wf(newstr,'')
  end
  end
local FileData={
Path=x,
Destroy=globaldestroy,
Name=getfilename(x),
Type=typefile(x),
GetChildren=cppf(function(self)
return {}
  end),
GetDescendants=cppf(function(self)
    return {}
  end)
}
if FileData.Type=="file" then
FileData.Read=globalread
FileData.Write=globalwrite
FileData.ReplaceLine=globalwriteline
FileData.ReadLine=globalreadline
elseif FileData.Type=="folder" then
FileData.GetChildren=globalgc
FileData.GetDescendants=globalgd
end
local bc=clonef(buffer.create)
local metatable={
__namecall=cppf(function(x,...)
local method=getnamecallmethod()
local methf=x[method]
if not methf then
              err("Attempted to call a non-existent method!")
          else
return methf(x,...)
          end
      end),
__type="File",
__tostring=cppf(function() return FileData.Name end),
__index=FileData,
__newindex=cppf(function(l,y,z)
if y=="Path" then
wf(`{behave}{z}`,l:Read())
l:Destroy()
elseif y=="Name" then
wf(`{behave}{x:gsub(FileData.Name,'')}{z}`,l:Read())
l:Destroy()
      elseif y=="Type" then
l:Destroy()
if z=="folder" then
mf(`{behave}{x}`)
        elseif z=="file" then
wf(`{behave}{x}`,'')
        else
err(`Cannot change the type of File to {z}`)
        end
      else
err(`Cannot modify the {y} of File.`)
    end
  end),
__metatable="The metatable is locked."
}
local Holder=bc(0)
rawsmt(Holder,metatable)
return Holder
end
renv.OpenFile=cppf(OpenFile)
renv.readline=cppf(readline)
renv.writeline=cppf(writeline)
renv.listfiles=cppf(function(x)
if FilesEnabled then
if not x or x=='./' then
x=''
end
local fi=lf(`{behave}{x}`)
local newfi={}
for i,v in fi do
newfi[i]=gsub(v,behave,'')
  end
return newfi
  else
      rwarn("File permissions denied.")
  end
end)
renv.NEXHttp=tclone(NEXHttp)
renv._NEXVERSION=version
local iro=clonef(isreadonly)
local rant={}
local function nexify()
for _,v in reg do
if not rant[v] and rtype(v)=="thread" then --this is the most
rant[v]=true
local threadf=info(v,1,'f')
local env=getf(threadf)
local envm=rawmt(env)
local envmm=rawmt(envm) or examplet
if iro(envmm) then
if debugm then
  rwarn(`Came across an abnormal thread! ({env.script})`)
        end
      else
local envmi=envm.__index
local indr=rawmt(envmi)
if indr then
local oindrmt=indr.__metatable
indr.__metatable=nil
local newind=tclone(envmi)
envm.__index=newind
indr.__metatable=oindrmt
end
local envte=newind or env
local envtenex=envte
if env and env.Protected_Environment then
if debugm or env.ForceDebuggedEnvironment then
rwarn(`{env.script} IS PROTECTED`)
                      end
              else
if env.NEXLuau then
nex(env)
envte=nexenv.std.NEXFunctions
envtenex=nexenv
                      end
if env.ExternalThread then
local newfunc=clonef(threadf)
cclose(v)
tw()
cr(cc(newfunc))
if debugm then
rwarn(`{env.script} is EXTERNAL`)
end
end
for i,x in next,renv do
envte[i]=x
end
envtenex.NEX_Loaded=true
                      if debugm or env.ForceDebuggedEnvironment then
                      rwarn(`NEX LOADED IN {env.script}`)
                      end
end
end
end
end
end
renv.UpdateNEX=newcclosure(function()nexify()end)
nexify()
SendNotification(GuiService,{
Icon=NEXIcon,
Title=NEXTitle,
Text=`NEX Emulation finished in {ot()-t}`
})
tw(0.01)
cdef(function()nexify()cclose(currentthread)end)
