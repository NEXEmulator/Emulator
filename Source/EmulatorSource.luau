--!native
--!nolint
--!nocheck
--!optimize 3
local nv={}
nv.select=clonefunction(select)
nv.game,nv.workspace=cloneref(game),cloneref(workspace) --this is not to stop detection from weaktables, this is just so replications to the Instance metatable dont replicate to these instances for better security, I might be just paranoid, but better safe than sorry.
nv.NEXRequire = function(x)
return request({Url=`https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/{x}`,Method="GET"}).Body
end
nv.ImportToFolder = function(x,y)
for i,v in next,y do
if not isfile(`{x}/{i}`) then
writefile(`{x}/{i}`,nv.NEXRequire(v))
            end
    end
end
if not isfolder(".icons") then
makefolder(".icons")
nv.ImportToFolder(".icons",{
["NEX.png"]="Icons/NEX.png",
[".nomedia"]="Icons/.nomedia"
})
end
nv.version="1.0.9"
nv.lastversion="1.0.8"
nv.NEXIcon=getcustomasset(".icons/NEX.png")
nv.LoadedIcons={NEX=nv.NEXIcon}
nv.BinaryFormat=loadstring(request({Url="https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/BinaryFormatConverter.luau",Method="GET"}).Body)()
nv.clonef=clonefunction(clonefunction)
nv.cppf=nv.clonef(newcclosure)
nv.XMLToBinary=nv.cppf(nv.BinaryFormat.XMLToBinary)
nv.BinaryToXML=nv.cppf(nv.BinaryFormat.BinaryToXML)
nv.err=nv.clonef(error)
nv.canhead=({pcall(request,{Url="https://raw.githubusercontent.com",Method="HEAD"})})[1]
nv.rawsmt=nv.clonef(setrawmetatable)
nv.rawmt=nv.clonef(getrawmetatable)
nv.tclone=nv.clonef(table.clone)
nv.srot={
__metatable="The metatable is locked.",
__newindex=nv.cppf(function()nv.err"attempt to modify a protected metatable"end)
}
nv.sro=nv.clonef(setreadonly) or nv.cppf(function(x,y)
  if y then
    nv.rawsmt(x,{nv.srot})
  else
    nv.rawsmt(x,{})
  end
end)
nv.tablepc=nv.cppf(function(x)
  local ta=nv.tclone(x)
  nv.sro(ta,true)
  return ta
end)
nv.cclose,nv.info,nv.genv,nv.index,nv.newindex=coroutine.close,debug.info,loadstring(nv.NEXRequire("AllowedFunctions.luau"))()
xpcall(function()nv.workspace[nil]()end,function()nv.index=nv.clonef(nv.info(2,'f'))end)xpcall(function()nv.workspace.woahs=1 end,function()nv.newindex=nv.clonef(nv.info(2,'f'))end)
nv.GetService=nv.index(nv.game,"GetService")
nv.GuiService=cloneref(nv.GetService(nv.game,"GuiService"))
nv.ot=os.clock
nv.t=nv.ot()
nv.NEXTitle=`NEX Emulator (V{nv.version})`
nv.SendNotification=nv.clonef(nv.index(nv.GuiService,"SendNotification"))
nv.SendNotification(nv.GuiService,{
Icon=nv.NEXIcon,
Title=nv.NEXTitle,
Text="NEX Emulation starting..."
})
nv.tw=task.wait
nv.FindFirstChild=nv.clonef(nv.index(nv.workspace,"FindFirstChild"))
nv.NetworkClient=cloneref(nv.GetService(nv.game,"NetworkClient"))
nv.GetChildren=nv.clonef(nv.index(nv.workspace,"GetChildren"))
nv.Clone=nv.clonef(nv.index(nv.workspace,"Clone"))
nv.IsA=nv.clonef(nv.index(nv.workspace,"IsA"))
nv.ClientReplicator=cloneref(nv.FindFirstChild(nv.NetworkClient,"ClientReplicator"))
nv.Destroy=nv.clonef(nv.index(nv.game,"Destroy"))
if not isfolder("GameData") then
makefolder("GameData")
end
nv.rgca=nv.clonef(getcustomasset)
nv.rwarn=nv.clonef(warn)
nv.rtype=nv.clonef(type)
nv.cdef=nv.clonef(task.defer)
nv.def=function(x,...) return nv.cdef(function(...)return x(...)end,...)end
nv.reg=getreg()
nv.GameId=nv.index(nv.game,"GameId")
nv.HttpService=cloneref(nv.GetService(nv.game,"HttpService"))
nv.MarketplaceService=cloneref(nv.GetService(nv.game,"MarketplaceService"))
nv.GetProductInfo=nv.clonef(nv.index(nv.MarketplaceService,"GetProductInfo"))
nv.JsonDecode=nv.clonef(nv.index(nv.HttpService,"JSONDecode"))
nv.JsonEncode=nv.clonef(nv.index(nv.HttpService,"JSONEncode"))
nv.rootid=nv.JsonDecode(nv.HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{nv.GameId}`,Method="GET"}).Body).rootPlaceId
nv.behave=`GameData/{nv.rootid}/Storage/`
nv.SettingsPrefix=`GameData/{nv.rootid}/`
if not isfolder(nv.SettingsPrefix) then
makefolder(nv.SettingsPrefix)
end
if not isfolder(nv.behave) then
makefolder(nv.behave)
end
nv.gca=function(x) return nv.rgca(`{nv.behave}{x}`) end
nv.RootName=`{nv.SettingsPrefix}RootName {nv.GetProductInfo(nv.MarketplaceService,nv.rootid).Name}`
nv.SettingsExist=isfile(`{nv.SettingsPrefix}Settings.json`)
nv.s,nv.settingst=pcall(function()
return nv.JsonDecode(nv.HttpService,readfile(`{nv.SettingsPrefix}Settings.json`))
end)
nv.origs={CapabilityMax=2,EmulateOnGameIsLoaded=true,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms=false,DebugMode=false,RobloxScriptRequire=true,XMLEnabled=true}
if not isfile("StarterSettings.json") then
writefile("StarterSettings.json",nv.JsonEncode(nv.HttpService,nv.origs))
end
nv.settings=nv.SettingsExist and nv.s and nv.settingst or nv.JsonDecode(nv.HttpService,readfile("StarterSettings.json"))
if not isfile("._NEXVERSION") or readfile("._NEXVERSION")==nv.lastversion then
writefile("._NEXVERSION",nv.version)
for i,v in next,nv.origs do
  if nv.settings[i]==nil then
    nv.settings[i]=v
  end
end
nv.stjson=nv.JsonEncode(nv.HttpService,nv.settings)
writefile("StarterSettings.json",nv.stjson)
else
nv.stjson=nv.JsonEncode(nv.HttpService,nv.settings)
end
if not nv.SettingsExist then
writefile(`{nv.SettingsPrefix}Settings.json`,nv.stjson)
end
nv.IsLoaded=nv.index(nv.game,"IsLoaded")
if nv.settings.EmulateOnGameIsLoaded then
repeat nv.tw() until nv.IsLoaded(nv.game)
end
nv.NotAllowed={getgenv=1}
nv.HttpFamily={request=1}
nv.SerializationService=cloneref(nv.GetService(nv.game,"SerializationService"))
nv.DeserializeInstance=nv.clonef(nv.index(nv.SerializationService,"DeserializeInstancesAsync"))
nv.bufferstring=nv.clonef(buffer.fromstring)
nv.SetStateEnabled=nv.clonef(Instance.new"Humanoid".SetStateEnabled)
nv.rnexists=`{nv.SettingsPrefix}.rootname`
if not isfile(nv.rnexists) then
writefile(nv.RootName,' ')
writefile(nv.rnexists,' ')
end
nv.grenv=getrenv()
nv.rrequire=nv.grenv.require
nv.exstr="hi"
nv.find,nv.sub=nv.clonef(nv.exstr.find),nv.clonef(nv.exstr.sub)
nv.foundationimage=function(x)
return nv.find(x,"://")~=nil
end
if nv.settings.RobloxScriptRequire then
nv.genv.Rrequire=nv.rrequire
else
nv.genv.RobloxScriptRequire=function(...)
nv.rwarn("RobloxScriptRequire disabled.")
end
end
nv.Identity={setidentity=1,getthreadidentity=1}
nv.renv={}
nv.InsertService=cloneref(nv.GetService(nv.game,"InsertService"))
nv.LLA=nv.clonef(nv.index(nv.InsertService,"LoadLocalAsset"))
nv.Players=cloneref(nv.GetService(nv.game,"Players"))
nv.ClearError=nv.clonef(nv.index(nv.GuiService,"ClearError"))
nv.oldset=setidentity
nv.oldti=getthreadidentity
nv.LP=cloneref(nv.index(nv.Players,"LocalPlayer"))
nv.Kick=nv.index(nv.LP,"Kick")
nv.GetCurrentThread = function()
local ThreadIdentifier=nv.info(0,'f')
for _,v in nv.reg do
if nv.rtype(v)=="thread" and nv.info(v,0,'f')==ThreadIdentifier then
return v
end
end
end
nv.currentthread=nv.GetCurrentThread()
nv.genv.GetCurrentThread=nv.GetCurrentThread
nv.genv.DisconnectFromServer=function()
local id=nv.oldti()
if id<3 then
nv.oldset(3)
nv.def(nv.oldset,id)
end
nv.Kick(nv.LP)
nv.ClearError(nv.GuiService)
repeat nv.tw() until nv.index(nv.ClientReplicator,"Parent")==nil
local char=cloneref(nv.index(nv.LP,"Character"))
nv.newindex(char,"Archivable",true)
local c=nv.GetChildren(nv.Clone(char))
for i,v in nv.GetChildren(char) do --didnt use next because it's already an integer placement, not a dict
if nv.IsA(v,"BasePart") or nv.index(v,"ClassName")=="Accessory" then --I wanted to use if not v:IsA"LuaSourceContainer" but it didnt let me walk for some reason
nv.Destroy(v)
nv.newindex(c[i],"Parent",char)
end
end
local hum=cloneref(nv.index(char,"Humanoid"))
nv.SetStateEnabled(hum,15,false)
end
nv.genv.ToastNotify=function(x)
local id=nv.oldti()
if id<3 then
nv.oldset(3)
nv.def(nv.oldset,id)
    end
local ticon=x.Icon
x.Icon=(nv.foundationimage(ticon) and nil) or ticon
return nv.SendNotification(nv.GuiService,x)
end
nv.HttpEnabled=nv.settings.HTTPEnabled
nv.FilesEnabled=nv.settings.FilesEnabled
nv.ExternalFilePerms=nv.settings.ExternalFilePerms
nv.gitpattern="^https://github.com/([^/]+)/([^/]+)(.*)$"
nv.apipattern="https://api.github.com/repos/%s/%s/contents/%s"
nv.apiwpattern="https://api.github.com/repos/%s/%s/contents/"
nv.match=nv.clonef(string.match)
nv.convertgit = function(x)
local owner,repo,folder=nv.match(x,nv.gitpattern)
if owner and repo then
    if folder and folder ~= "" then
        folder = folder:gsub("^/", "")
        return string.format(nv.apipattern, owner, repo, folder),repo
    else
        return string.format(nv.apiwpattern, owner, repo),repo
    end
else
    return nil
end
end
nv.df,nv.dfo=nv.clonef(delfile),nv.clonef(delfolder)
nv.wf=nv.clonef(writefile)
nv.xml={
Name="",
}
nv.woahc=nv.clonef(pcall)
nv.HttpGet=nv.index(nv.game,"HttpGet")
nv.RFS=nv.GetService(nv.game,"ReflectionService")
nv.GPOC=nv.clonef(nv.index(nv.RFS,"GetPropertiesOfClass"))
nv.getproperties = function(x)
  local props={}
  for _,v in nv.GPOC(nv.RFS,nv.index(x,"ClassName")) do
    if v.Permits.Read then
      props[v.Name]=nv.index(x,v.Name)
    end
  end
  return props
end
nv.XMLEnabled=nv.settings.XMLEnabled
nv.ind=nv.select(2,pcall(nv.index,nv.HttpService,"RequestInternal"))
nv.requestinternal=nv.ind and nv.clonef(nv.ind) or error
if nv.woahc(nv.requestinternal,{Url="https://example.com",Method="GET"}) then
  nv.interfunc=function(x)
    local id=nv.oldti()
    if id<3 then
      nv.oldset(3)
      nv.def(nv.oldset,id)
    end
    return nv.requestinternal(nv.HttpService,{Url=x,Method="GET"})
  end
else
  nv.interfunc=function(x)
    local id=nv.oldti()
    if id<3 then
      nv.oldset(3)
      nv.def(nv.oldset,id)
    end
    return nv.HttpGet(nv.game,x)
  end
end
nv.GetAssetSource = function(x)
return nv.interfunc("https://assetdelivery.roblox.com/v1/asset/?id="..x)
end
nv.xmlobject = function(x,y)
if nv.XMLEnabled then
local instancexml=[[<roblox version="4">
    <Item class="]]..x..[[">
    </Item>
    </roblox>
    ]]
local instance=nv.DeserializeInstance(nv.SerializationService,nv.bufferstring(instancexml))[1]
nv.newindex(instance,"Parent",y)
    return instance
else
  nv.rwarn("XML permissions denied.")
end
end
nv.loadxml = function(x)
if nv.XMLEnabled then
return nv.DeserializeInstance(nv.SerializationService,nv.bufferstring(x))
else
  nv.rwarn("XML permissions denied.")
end
end
nv.sf,nv.gsub,nv.gmatch=nv.clonef(string.format),nv.clonef(string.gsub),nv.clonef(string.gmatch)
nv.format=nv.sf
nv.ti,nv.tc,nv.tun,nv.tsort=nv.clonef(table.insert),nv.clonef(table.concat),nv.clonef(table.unpack),nv.clonef(table.sort)
nv.ton,nv.tos,nv.typo=nv.clonef(tonumber),nv.clonef(tostring),nv.clonef(typeof)
nv.mfloor=nv.clonef(math.floor)
nv.V3,nv.V2,nv.V3i16,nv.V2i16,nv.CF,nv.UD,nv.UD2,nv.Rec,nv.NR,nv.NS,nv.NSK,nv.CS,nv.CSK,nv.C3,nv.PP,nv.Fa,nv.Ax=Vector3.new,Vector2.new,Vector3int16.new,Vector2int16.new,CFrame.new,UDim.new,UDim2.new,Rect.new,NumberRange.new,NumberSequence.new,NumberSequenceKeypoint.new,ColorSequence.new,ColorSequenceKeypoint.new,Color3.new,PhysicalProperties.new,Faces.new,Axes.new
nv.EnAx,nv.EnNI=Enum.Axis,Enum.NormalId
nv.clean = function(s)return(nv.gsub(s,"%s+",""))end
nv.getfaces = function(v)local f={}if v.Right then nv.ti(f,nv.EnNI.Right)end if v.Top then nv.ti(f,nv.EnNI.Top)end if v.Back then nv.ti(f,nv.EnNI.Back)end if v.Left then nv.ti(f,nv.EnNI.Left)end if v.Bottom then nv.ti(f,nv.EnNI.Bottom)end if v.Front then nv.ti(f,nv.EnNI.Front)end return nv.Fa(nv.tun(f))end
nv.getaxes = function(v)local a={}if v.X then nv.ti(a,nv.EnAx.X)end if v.Y then nv.ti(a,nv.EnAx.Y)end if v.Z then nv.ti(a,nv.EnAx.Z)end return nv.Ax(nv.tun(a))end
nv.typemap={
["Vector3"]={enc=function(p)local v=p.Value return nv.sf('<X>%g</X><Y>%g</Y><Z>%g</Z>',v.X,v.Y,v.Z)end,dec=function(s)s=nv.clean(s)return nv.V3(nv.ton(nv.match(s,"<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<Y>(.-)</Y>"))or 0,nv.ton(nv.match(s,"<Z>(.-)</Z>"))or 0)end},
["Vector2"]={enc=function(p)local v=p.Value return nv.sf('<X>%g</X><Y>%g</Y>',v.X,v.Y)end,dec=function(s)s=nv.clean(s)return nv.V2(nv.ton(nv.match(s,"<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<Y>(.-)</Y>"))or 0)end},
["Vector3int16"]={enc=function(p)local v=p.Value return nv.sf('<X>%d</X><Y>%d</Y><Z>%d</Z>',v.X,v.Y,v.Z)end,dec=function(s)s=nv.clean(s)return nv.V3i16(nv.ton(nv.match(s,"<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<Y>(.-)</Y>"))or 0,nv.ton(nv.match(s,"<Z>(.-)</Z>"))or 0)end},
["Vector2int16"]={enc=function(p)local v=p.Value return nv.sf('<X>%d</X><Y>%d</Y>',v.X,v.Y)end,dec=function(s)s=nv.clean(s)return nv.V2i16(nv.ton(nv.match(s,"<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<Y>(.-)</Y>"))or 0)end},
["CFrame"]={enc=function(p)local c={p.Value:GetComponents()}return nv.sf('<X>%g</X><Y>%g</Y><Z>%g</Z><R00>%g</R00><R01>%g</R01><R02>%g</R02><R10>%g</R10><R11>%g</R11><R12>%g</R12><R20>%g</R20><R21>%g</R21><R22>%g</R22>',nv.tun(c))end,dec=function(s)s=nv.clean(s)local c={}for v in nv.gmatch(s,">([^<]+)<")do nv.ti(c,nv.ton(v))end if#c<12 then c={nv.ton(nv.match(s,"<X>(.-)</X>")),nv.ton(nv.match(s,"<Y>(.-)</Y>")),nv.ton(nv.match(s,"<Z>(.-)</Z>")),nv.ton(nv.match(s,"<R00>(.-)</R00>")),nv.ton(nv.match(s,"<R01>(.-)</R01>")),nv.ton(nv.match(s,"<R02>(.-)</R02>")),nv.ton(nv.match(s,"<R10>(.-)</R10>")),nv.ton(nv.match(s,"<R11>(.-)</R11>")),nv.ton(nv.match(s,"<R12>(.-)</R12>")),nv.ton(nv.match(s,"<R20>(.-)</R20>")),nv.ton(nv.match(s,"<R21>(.-)</R21>")),nv.ton(nv.match(s,"<R22>(.-)</R22>"))}end return nv.CF(nv.tun(c))end},
["UDim"]={enc=function(p)local v=p.Value return nv.sf('<S>%g</S><O>%d</O>',v.Scale,v.Offset)end,dec=function(s)s=nv.clean(s)return nv.UD(nv.ton(nv.match(s,"<S>(.-)</S>"))or 0,nv.ton(nv.match(s,"<O>(.-)</O>"))or 0)end},
["UDim2"]={enc=function(p)local v=p.Value return nv.sf('<XS>%g</XS><XO>%d</XO><YS>%g</YS><YO>%d</YO>',v.X.Scale,v.X.Offset,v.Y.Scale,v.Y.Offset)end,dec=function(s)s=nv.clean(s)return nv.UD2(nv.ton(nv.match(s,"<XS>(.-)</XS>"))or 0,nv.ton(nv.match(s,"<XO>(.-)</XO>"))or 0,nv.ton(nv.match(s,"<YS>(.-)</YS>"))or 0,nv.ton(nv.match(s,"<YO>(.-)</YO>"))or 0)end},
["Rect2D"]={enc=function(p)local v=p.Value return nv.sf('<min><X>%g</X><Y>%g</Y></min><max><X>%g</X><Y>%g</Y></max>',v.Min.X,v.Min.Y,v.Max.X,v.Max.Y)end,dec=function(s)s=nv.clean(s)return nv.Rec(nv.ton(nv.match(s,"<min>.*<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<min>.*<Y>(.-)</Y>"))or 0,nv.ton(nv.match(s,"<max>.*<X>(.-)</X>"))or 0,nv.ton(nv.match(s,"<max>.*<Y>(.-)</Y>"))or 0)end},
["NumberRange"]={enc=function(p)return nv.sf('%g %g',p.Value.Min,p.Value.Max)end,dec=function(s)local m1,m2=nv.match(s,"([^%s]+)%s+([^%s]+)")return nv.NR(nv.ton(m1)or 0,nv.ton(m2)or 0)end},
["NumberSequence"]={enc=function(p)local r={}for _,k in ipairs(p.Value.Keypoints)do nv.ti(r,nv.sf("%g %g %g",k.Time,k.Value,k.Envelope))end return nv.tc(r," ")end,dec=function(s)local k,v={},{}for x in nv.gmatch(s,"([^%s]+)")do nv.ti(v,nv.ton(x))end for i=1,#v,3 do nv.ti(k,nv.NSK(v[i],v[i+1],v[i+2]))end return nv.NS(k)end},
["ColorSequence"]={enc=function(p)local r={}for _,k in ipairs(p.Value.Keypoints)do nv.ti(r,nv.sf("%g %g %g %g 0",k.Time,k.Value.R,k.Value.G,k.Value.B))end return nv.tc(r," ")end,dec=function(s)local k,v={},{}for x in nv.gmatch(s,"([^%s]+)")do nv.ti(v,nv.ton(x))end for i=1,#v,5 do nv.ti(k,nv.CSK(v[i],nv.C3(v[i+1],v[i+2],v[i+3])))end return nv.CS(k)end},
["Color3"]={enc=function(p)local v=p.Value return nv.sf('<R>%g</R><G>%g</G><B>%g</B>',v.R,v.G,v.B)end,dec=function(s)s=nv.clean(s)return nv.C3(nv.ton(nv.match(s,"<R>(.-)</R>"))or 0,nv.ton(nv.match(s,"<G>(.-)</G>"))or 0,nv.ton(nv.match(s,"<B>(.-)</B>"))or 0)end},
["Color3uint8"]={enc=function(p)local v=p.Value return nv.tos(4278190080+(nv.mfloor(v.R*255)*65536)+(nv.mfloor(v.G*255)*256)+nv.mfloor(v.B*255))end,dec=function(s)local u=nv.ton(s)or 0 return Color3.fromRGB(nv.mfloor(u/65536)%256,nv.mfloor(u/256)%256,u%256)end},
["PhysicalProperties"]={enc=function(p)local v=p.Value if v==nil then return "null" end if nv.typo(v)=="string" then return v end return nv.sf('<CustomPhysics>true</CustomPhysics><Density>%g</Density><Friction>%g</Friction><Elasticity>%g</Elasticity><FrictionWeight>%g</FrictionWeight><ElasticityWeight>%g</ElasticityWeight>',v.Density,v.Friction,v.Elasticity,v.FrictionWeight,v.ElasticityWeight)end,dec=function(s)return s end},
["Faces"]={enc=function(p)local v,f=p.Value,0 if v.Right then f+=1 end if v.Top then f+=2 end if v.Back then f+=4 end if v.Left then f+=8 end if v.Bottom then f+=16 end if v.Front then f+=32 end return nv.tos(f)end,dec=function(s)local i=nv.ton(s)or 0 return nv.getfaces({Right=(i%2>=1),Top=(i%4>=2),Back=(i%8>=4),Left=(i%16>=8),Bottom=(i%32>=16),Front=(i%64>=32)})end},
["Axes"]={enc=function(p)local v,f=p.Value,0 if v.X then f+=1 end if v.Y then f+=2 end if v.Z then f+=4 end return nv.tos(f)end,dec=function(s)local i=nv.ton(s)or 0 return nv.getaxes({X=(i%2>=1),Y=(i%4>=2),Z=(i%8>=4)})end}
}
nv.typemap["CoordinateFrame"]=nv.typemap["CFrame"]
nv.tabletoxml = function(root)
local out={'<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">'}
local uss={}
local function scan(t)for k,v in next,t do if type(v)=="table" and v.Tag=="SharedString" then uss[v.Value]=true end if type(k)=="string" and k:find("^Item") then scan(v) end end end
scan(root)
if root.SharedStrings then local sb={} for h,c in next,root.SharedStrings do if uss[h] then nv.ti(sb,nv.sf('<SharedString md5="%s">%s</SharedString>',h,c)) end end if #sb>0 then nv.ti(out,"\n<SharedStrings>") nv.ti(out,"\n"..tc(sb,"\n")) nv.ti(out,"\n</SharedStrings>") end end
local refmap,refcnt={},0
local function remap_refs(t)
  local it={} for k,v in next,t do if nv.typo(k)=="string" and k:find("^Item") then nv.ti(it,{k,v}) end end
  nv.tsort(it,function(a,b) return (nv.ton(nv.match(a[1],"%d+"))or 0)<(nv.ton(nv.match(b[1],"%d+"))or 0) end)
  for _,pair in ipairs(it) do
    local d=pair[2]
    refcnt=refcnt+1
    local oldRef=d.Referent
    local newRef=nv.sf("NEX%d",refcnt)
    if oldRef then refmap[oldRef]=newRef end
    d.Referent=newRef
    remap_refs(d)
  end
end
remap_refs(root)
local function proc(t)
  local it={} for k,v in next,t do if nv.typo(k)=="string" and k:find("^Item") then nv.ti(it,{k,v}) end end
  nv.tsort(it,function(a,b) return (nv.ton(nv.match(a[1],"%d+"))or 0)<(nv.ton(nv.match(b[1],"%d+"))or 0) end)
  for _,pair in ipairs(it) do
    local d,ref=pair[2],pair[2].Referent
    nv.ti(out,nv.sf('\n<Item class="%s" referent="%s">',d.ClassName or "Part",ref)) nv.ti(out,"\n<Properties>")
    for pn,pw in next,d do
      if pn~="ClassName" and pn~="Referent" and not pn:find("^Item") and nv.typo(pw)=="table" and pw.Tag then
        local tag,logic=pw.Tag,nv.typemap[pw.Tag]
        if tag=="Ref" then 
          local v = pw.Value
          if v and refmap[v] then v=refmap[v] end
          nv.ti(out,nv.sf('\n<Ref name="%s">%s</Ref>',pn,(v==nil)and"null"or nv.tos(v)))
        elseif tag=="BinaryString" or tag=="ProtectedString" or tag=="string" then nv.ti(out,nv.sf('\n<%s name="%s"><![CDATA[%s]]></%s>',tag,pn,pw.Value,tag))
        elseif logic then local val=logic.enc(pw) nv.ti(out,nv.sf('\n<%s name="%s">%s</%s>',tag,pn,(val=="null")and"null"or val,tag))
        elseif tag=="UniqueId" or tag=="SharedString" then nv.ti(out,nv.sf('\n<%s name="%s">%s</%s>',tag,pn,pw.Value,tag))
        elseif tag=="bool" then nv.ti(out,nv.sf('\n<bool name="%s">%s</bool>',pn,nv.tos(pw.Value)))
        elseif tag=="int" or tag=="int64" then nv.ti(out,nv.sf('\n<%s name="%s">%d</%s>',tag,pn,pw.Value,tag))
        elseif tag=="float" or tag=="double" then nv.ti(out,nv.sf('\n<%s name="%s">%g</%s>',tag,pn,pw.Value,tag))
        elseif tag=="token" then nv.ti(out,nv.sf('\n<%s name="%s">%d</%s>',tag,pn,nv.mfloor(pw.Value+0.5),tag))
        else nv.ti(out,nv.sf('\n<%s name="%s">%s</%s>',tag,pn,nv.tos(pw.Value),tag)) end
      end end
    nv.ti(out,"\n</Properties>") proc(d) nv.ti(out,"\n</Item>")
  end end
proc(root) nv.ti(out,"\n</roblox>") return nv.tc(out)
end
nv.xmltotable = function(xml)
local ss={} for h,b in nv.gmatch(xml,'<SharedString md5="([^"]+)">([^<]*)</SharedString>') do ss[h]=b end
local function parse(s)
  local res,idx,pos={},1,1
  while true do
    local b,e,cls,ref=s:find('<Item class="([^"]*)" referent="([^"]*)"[^>]*>',pos)
    if not b then b,e,cls=s:find('<Item class="([^"]*)"[^>]*>',pos) end if not b then break end
    local d,ce=1,e+1
    while d>0 do local no,nc=s:find('<Item%s',ce),s:find('</Item>',ce) if nc and(not no or nc<no) then d-=1 ce=nc+7 elseif no then d+=1 ce=no+6 else break end end
    local idat={ClassName=cls,Referent=ref} local body=s:sub(b,ce) local ps,pe,pc=body:find("<Properties>"),nil,body:find("</Properties>")
    if ps and pc then pe=ps+11 local px=body:sub(pe+1,pc-1)
      for tag,n,c in nv.gmatch(px,"<([^%s>]+) name=\"([^\"]+)\">(.-)</%1>") do
        local v=c if tag=="BinaryString" or tag=="ProtectedString" or tag=="string" then v=nv.gsub(c,"<!%[CDATA%[(.-)%]%]>","%1")
        elseif tag=="bool" then v=(c=="true") elseif tag=="int" or tag=="float" or tag=="double" or tag=="token" or tag=="int64" then v=nv.ton(c)
        elseif tag=="Ref" then v=(c~="null"and c)or nil elseif nv.typemap[tag] then v=nv.typemap[tag].dec(c) elseif tag=="SharedString" then v=c end
        idat[n]={Tag=tag,Value=v} end end
    local chi=parse(body:sub((pc or 0)+13,#body-7)) for k,v in next,chi do idat[k]=v end
    res["Item"..idx]=idat idx+=1 pos=ce
  end return res end
local fin=parse(xml) fin.SharedStrings=ss return fin
end
nv.req=nv.clonef(request)
nv.mf=nv.clonef(makefolder)
nv.isf=nv.clonef(isfile)
nv.getgit = function(x)
local url,repo=nv.convertgit(x)
local tab=nv.JsonDecode(nv.HttpService,nv.req({Url=url,Method="GET"}).Body)
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
nv.reverse=nv.clonef(string.reverse)
nv.rf=nv.clonef(readfile)
nv.splitxml = function(xml,y)
local res={}
local s=xml
local h=nv.match(xml,"(<roblox[^>]*>)") or '<roblox version="4">'
local ss={}
for hash,data in nv.gmatch(xml,'<SharedString md5="([^"]+)">([^<]*)</SharedString>') do
  ss[hash]=data
end
if nv.find(s,"^<roblox")then s=nv.reverse(nv.gsub(nv.reverse(nv.gsub(s,"^<roblox[^>]*>","")),">xolbor/<","",1))
end
if nv.find(s,"^%s*<Item")then
  s=nv.gsub(s,"^%s*","")
  local _,p=nv.find(s,"<Properties>.-</Properties>")
  if not p then _,p=nv.find(s,"^<Item[^>]*>")end
  s=nv.reverse(nv.gsub(nv.reverse(nv.sub(s,p+1)),">metI/<","",1))
end
local cur=1
while true do
  local b,e,c=nv.find(s,'<Item class="([^"]+)"[^>]*>',cur)
  if not b then break end
  local d,p,f=1,e+1,nil
  while d>0 do
    local ns,ne=nv.find(s,'<Item%s',p)
    local cs,ce=nv.find(s,'</Item>',p)
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
    local x=nv.sub(s,b,f)
    if y then
      local needed={}
      for hash in nv.gmatch(x,'<SharedString name="[^"]*">([^<]+)</SharedString>') do
        if ss[hash] and not needed[hash] then
          needed[hash]=true
        end
      end
      local ssblock=""
      local sb={}
      for hash in next,needed do
        nv.ti(sb,nv.sf('<SharedString md5="%s">%s</SharedString>',hash,ss[hash]))
      end
      if #sb>0 then
        ssblock="\n<SharedStrings>\n"..tc(sb,"\n").."\n</SharedStrings>"
      end
      x=h..ssblock..x..'</roblox>'
    end
    nv.ti(res,{Class=c,XML=x})
    cur=f+1
  else cur=e+1 end
end
return res
end
nv.XML={
Object=nv.cppf(nv.xmlobject),
Load=nv.cppf(nv.loadxml),
TableToXML=nv.cppf(nv.tabletoxml),
XMLToTable=nv.cppf(nv.xmltotable),
SplitXML=nv.cppf(nv.splitxml)
}
nv.robloxtype = function(x)
  if nv.sub(x,1, 8) == "<roblox!" then
    return "binary"
  elseif nv.sub(x,1, 7) == "<roblox" then
    return "xml"
  else
    return "unknown"
  end
end
nv.FixStudioXML=nv.cppf(function(x)
  return nv.gsub(nv.gsub(x,'<Item class="Workspace"','<Item class="Model"'),'<Item class="Terrain"','<Item class="Folder"')
end)
nv.roblox={XML=nv.tclone(nv.XML),GetAssetSource=nv.cppf(nv.GetAssetSource),BinaryFormat={
    XMLToBinary=nv.XMLToBinary,
    BinaryToXML=nv.BinaryToXML,
    XMLType=nv.cppf(nv.robloxtype),
    FixStudioXML=nv.FixStudioXML
}}
nv.genv.GetProperties=nv.cppf(nv.getproperties)
nv.genv.GetLocalObjects=function(x)
  local id=nv.oldti()
  if id<3 then
  nv.oldset(3)
  nv.def(nv.oldset,id)
  end
    return nv.DeserializeInstance(nv.SerializationService,nv.bufferstring(nv.FixStudioXML(nv.rf(`{nv.behave}{x}`))))
end
nv.genv.GetObjects=function(x)
  local id=nv.oldti()
  if id<3 then
  nv.oldset(3)
  nv.def(nv.oldset,id)
  end
  local assetid=nv.match(x,"%d+")
  if assetid then
    return nv.DeserializeInstance(nv.SerializationService,nv.bufferstring(nv.FixStudioXML(nv.GetAssetSource(assetid))))
  else
    nv.err("Invalid asset id.")
  end
end
nv.genv.LoadLocalAsset=function(x)
if nv.FilesEnabled then
local id=nv.oldti()
if id<3 then
nv.oldset(3)
nv.def(nv.oldset,id)
end
return nv.LLA(nv.InsertService,nv.gca(x))
end
nv.rwarn("File permissions denied.")
end
nv.genv.InsertAsset=function(x)
local id=nv.oldti()
if id<3 then
nv.oldset(3)
nv.def(nv.oldset,id)
end
return nv.LLA(nv.InsertService,x)
end
nv.FileFamily={getfilename=1,readfile=1,writefile=1,isfile=1,isfolder=1,listfiles=1,makefolder=1,delfolder=1,delfile=1,appendfile=1,loadfile=1,getcustomasset=1}
nv.debugm=nv.settings.DebugMode
nv.genv.getfilename=function(x,removedot)
local slash,name=nv.find(x,"/[^/]*$")
if slash then
name=nv.sub(x,slash+1)
else
name=x
end
if removedot then
local dot=nv.find(name,"%.")
if dot then
return nv.sub(name,1,dot-1)
end
end
return name
end
nv.CapabilityMax=nv.settings.CapabilityMax
nv.externalfp={}
nv.renv.ExternalFileFunctions=nv.externalfp
nv.renv.Settings=nv.tclone(nv.settings)
nv.renv.LoadedIcons=nv.tclone(nv.LoadedIcons)
for i,v in next,nv.genv do
if not nv.NotAllowed[i] then
if nv.Identity[i] then
nv.renv[i]=nv.cppf(function(x)
if nv.CapabilityMax>=(x or 0) then
return v(x)
else
nv.rwarn("Capability changing permissions denied.")
end
end)
elseif nv.FileFamily[i] then
if nv.ExternalFilePerms then
nv.externalfp[i]=nv.clonef(v)
end
nv.renv[i]=nv.cppf(function(x,...)
if nv.FilesEnabled then
return v(`{nv.behave}{x}`,...)
end
nv.rwarn("File permissions denied.")
end)
elseif nv.HttpFamily[i] then
nv.renv[i]=nv.cppf(function(...)
if nv.HttpEnabled then
return v(...)
end
nv.rwarn("HTTP denied.")
end)
else 
if type(v)=="function" then
nv.renv[i]=nv.clonef(v)
else
nv.renv[i]=nv.tclone(v)
end
end
end
end
nv.obsolete = function(x)
local n=cloneref(x)
setrawmetatable(n,{})
return n
end
nv.tonum=nv.clonef(tonumber)
nv.nexenv={
task=task,
__index=nv.index,
__newindex=nv.newindex,
std={
NEXFunctions={},
call={protected=pcall,extended_protected=xpcall},
coutw=nv.rwarn,
throw=nv.err,
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
__metatable={rawgetmetatable=nv.rawmt,rawsetmetatable=nv.clonef(setrawmetatable)},
setmetatable=setmetatable,
__equal=rawequal,
getmetatable=getmetatable,
},
string=string,
convert={
tonumber=nv.tonum,
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
Game=nv.obsolete(Game),
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
setmetatable(nv.nexenv,{
__metatable="The metatable is locked."
})
nv.nex = function(x)
nv.rawmt(x).__index=nv.nexenv
end
nv.examplet={}
nv.getf=nv.clonef(getfenv)
nv.cc,nv.cr=coroutine.create,coroutine.resume
nv.precalculatedsize=1024*16
nv.NEXHttp={}
nv.apf=nv.clonef(appendfile)
nv.download = function(url,filename,chunksize)
if nv.FilesEnabled then
local ext={installedsize=0,finished=false,WaitForFile=nv.cppf(function(self)
repeat nv.tw() until self.finished
return self.installedsize
end)}
if nv.canhead then
ext.size=nv.req{Url=url,Method='HEAD'}['Content-Length']
  else
ext.size="0"
  end
nv.cr(nv.cc(function()
chunksize=(chunksize and 1024*chunksize) or nv.precalculatedsize
local start,Headers,body,bodysize=0,{}
nv.wf(`{nv.behave}{filename}`,'')
repeat Headers.Range=`bytes={start}-{start+chunksize-1}`
body=nv.req{Url=url,Method='GET',Headers=Headers}.Body
nv.apf(`{nv.behave}{filename}`,body)
bodysize=#body
start+=bodysize
ext.installedsize=start
until bodysize<chunksize
ext.finished=true
end))
return ext
else
    nv.rwarn("File permissions denied.")
end
end
nv.streamget = function(url,chunksize)
if nv.HttpEnabled then
local ext={installedsize=0,finished=false,body='',WaitForFile=nv.cppf(function(self)
repeat nv.tw() until self.finished
return self.body 
end)}
if nv.canhead then
ext.size=nv.req{Url=url,Method='HEAD'}['Content-Length']
 else
ext.size="0"
 end
nv.cr(nv.cc(function()
chunksize=(chunksize and 1024*chunksize) or nv.precalculatedsize
local start,Headers,body,bodysize=0,{}
repeat Headers.Range=`bytes={start}-{start+chunksize-1}`
body=nv.req{Url=url,Method='GET',Headers=Headers}.Body
ext.body=ext.body..body
bodysize=#body
start+=bodysize
ext.installedsize=start
until bodysize<chunksize
ext.finished=true
end))
return ext
else
    nv.rwarn("HTTP permissions denied.")
end
end
nv.nd=nv.cppf(nv.clonef(nv.download))
nv.git={
getgit=nv.cppf(nv.getgit),
clone=nv.cppf(function(x)
        if nv.FilesEnabled then
local tab,repo=nv.getgit(x)
local rep=`{nv.behave}{repo}/`
nv.mf(rep)
            local function check(i,v)
                if v.type=="file" then
                    nv.nd(v.rawurl,`{repo}/{v.path}`)
                else
                nv.mf(`{rep}{v.path}`)
                local newtab=nv.getgit(`{x}/{v.path}`)
                for i,v in next,newtab do
                        check(i,v)
                    end
                end
            end
for i,v in next,tab do
check(i,v)
end
        else
            nv.rwarn("File permissions denied.")
        end
    end)
}
nv.NEXHttp.download=nv.cppf(nv.download)
nv.roblox.DownloadAsset=nv.cppf(function(x,y)
    if nv.FilesEnabled then
      local id=nv.oldti()
      if id<3 then
        nv.oldset(3)
        nv.def(nv.oldset,id)
      end
      nv.wf(`{nv.behave}{y}`,nv.GetAssetSource(x))
    end
  end)
nv.renv.roblox=nv.tclone(nv.roblox)
nv.NEXHttp.streamget=nv.cppf(nv.streamget)
nv.renv.git=nv.tclone(nv.git)
nv.isfl=nv.clonef(isfolder)
nv.lf=nv.clonef(listfiles)
nv.requests={}
nv.byte=nv.clonef(string.byte)
nv.sillystring='\\x%02X'
nv.utf8 = function(x)
local res={}
for i=1,#x do
res[i]=nv.format(nv.sillystring,nv.byte(x,i))
  end
return nv.tc(res)
end
nv.seriousstring = '\\x(%x%x)'
nv.woahnumber=16
nv.char=nv.clonef(string.char)
nv.untf8 = function(x)
local res = {}
local amount=0 --Instead of #res+1, because this is faster
for hex in nv.gmatch(x,nv.seriousstring) do
amount+=1
res[amount] = nv.char(nv.tonum(hex,nv.woahnumber))
end
return nv.tc(res)
end
nv.retq = function(x,url)
return {ok=x.Success,status_code=x.StatusCode,content=nv.utf8(x.Body),text=x.Body,json=nv.cppf(function() return nv.JsonDecode(nv.HttpService,x.Body)end),headers=x.Headers,raise_for_status=nv.cppf(function() if not x.Success then nv.err(x.StatusMessage) end end),url=url,elapsed=x.Headers['x-timer']}
end
nv.requests.get=nv.cppf(function(x,options)
if nv.HttpEnabled then
options.Url=x
options.Method="GET"
return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.post=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="POST"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.options=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="OPTIONS"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.patch=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="PATCH"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.put=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="PUT"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.delete=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="DELETE"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.requests.post=nv.cppf(function(x,options)
if nv.HttpEnabled then
  options.Url=x
  options.Method="POST"
  return nv.retq(nv.req(options),x)
else
  nv.err("HTTP Permissions Denied.")
end
end)
nv.encrypt={
utf8={
encode=nv.cppf(nv.utf8),
decode=nv.cppf(nv.untf8)
},
base64={
encode=nv.clonef(crypt.base64.encode),
decode=nv.clonef(crypt.base64.decode)
}
}
nv.renv.crypt=nv.tclone(nv.encrypt)
nv.renv.requests=nv.tclone(nv.requests)
nv.renv.typefile=nv.cppf(function(x)
if nv.FilesEnabled then
if nv.isf(`{nv.behave}{x}`) then
return "file"
    elseif nv.isfl(`{nv.behave}{x}`) then
return "folder"
    else
      nv.err("File doesnt exist!")
end
    else
        nv.rwarn("File permissions denied.")
    end
end)
nv.split=nv.clonef(nv.exstr.split)
nv.writeline = function(path,line,content) 
local lines = {}
for i,v in nv.split(nv.rf(`{nv.behave}{path}`),'\n') do
lines[i]=v
end
if not lines[line] then
for i=1,line do
lines[i]=lines[i] or ''
end
end
lines[line]=content
nv.wf(`{nv.behave}{path}`,nv.tc(lines, "\n"))
end
nv.readline = function(path,line)
if nv.FilesEnabled then
local lines = {}
for i,v in nv.split(nv.rf(`{nv.behave}{path}`),'\n') do
lines[i]=v
end
return lines[line]
end
nv.rwarn("File permissions denied.")
end
nv.globalread=nv.cppf(function(self)
return nv.rf(`{nv.behave}{self.Path}`)
end)
nv.globalwrite=nv.cppf(function(self,x)
return nv.wf(`{nv.behave}{self.Path}`,x)
end)
nv.wl,nv.rl=nv.clonef(nv.writeline),nv.clonef(nv.readline)
nv.globalwriteline=nv.cppf(function(self,x,y)
return nv.wl(self.Path,x,y)
end)
nv.globalreadline=nv.cppf(function(self,x)
return nv.rl(self.Path,x)
end)
nv.checksexy = function(x,t)
for _,v in nv.lf(`{nv.behave}{x}`) do
t[#t+1]=v
if typefile(v)=="folder" then
check(v)
        end
end
end
nv.globalgd=nv.cppf(function(self)
local t={}
nv.checksexy(`{nv.behave}{self.Path}`,t)
return t
end)
nv.globaldestroy=nv.cppf(function(self)
if self.Type=="file" then
        nv.df(`{nv.behave}{self.Path}`)
else
        nv.dfo(`{nv.behave}{self.Path}`)
end
end)
nv.globalgc=nv.cppf(function(self) 
return nv.lf(`{nv.behave}{self.Path}`)
end)
nv.OpenFile = function(x)
if x then
if not nv.isf(`{nv.behave}{x}`) then
  nv.wf(`{nv.behave}{x}`,'')
end
else
x="unnamed"
if not nv.isf(`{nv.behave}{x}`) then --Why would any sane person even do this, just use the path argument!
nv.wf(`{nv.behave}{x}`,'')
  else
local newstr=`{nv.behave}{x} (1)`
local count=1
while nv.isf(newstr) do
count+=1
newstr=`{nv.behave}{x} ({count})`
  end
nv.wf(newstr,'')
end
end
local FileData={
Path=x,
Destroy=nv.globaldestroy,
Name=getfilename(x),
Type=typefile(x),
GetChildren=nv.cppf(function(self)
return {}
end),
GetDescendants=nv.cppf(function(self)
  return {}
end)
}
if FileData.Type=="file" then
FileData.Read=nv.globalread
FileData.Write=nv.globalwrite
FileData.ReplaceLine=nv.globalwriteline
FileData.ReadLine=nv.globalreadline
elseif FileData.Type=="folder" then
FileData.GetChildren=nv.globalgc
FileData.GetDescendants=nv.globalgd
end
local bc=nv.clonef(buffer.create)
local metatable={
__namecall=nv.cppf(function(x,...)
local method=getnamecallmethod()
local methf=x[method]
if not methf then
            nv.err("Attempted to call a non-existent method!")
        else
return methf(x,...)
        end
    end),
__type="File",
__tostring=nv.cppf(function() return FileData.Name end),
__index=FileData,
__newindex=nv.cppf(function(l,y,z)
if y=="Path" then
nv.wf(`{nv.behave}{z}`,l:Read())
l:Destroy()
elseif y=="Name" then
nv.wf(`{nv.behave}{x:gsub(FileData.Name,'')}{z}`,l:Read())
l:Destroy()
    elseif y=="Type" then
l:Destroy()
if z=="folder" then
nv.mf(`{nv.behave}{x}`)
      elseif z=="file" then
nv.wf(`{nv.behave}{x}`,'')
      else
nv.err(`Cannot change the type of File to {z}`)
      end
    else
nv.err(`Cannot modify the {y} of File.`)
  end
end),
__metatable="The metatable is locked."
}
local Holder=bc(0)
nv.rawsmt(Holder,metatable)
return Holder
end
nv.renv.OpenFile=nv.cppf(nv.OpenFile)
nv.renv.readline=nv.cppf(nv.readline)
nv.renv.writeline=nv.cppf(nv.writeline)
nv.renv.listfiles=nv.cppf(function(x)
if nv.FilesEnabled then
if not x or x=='./' then
x=''
end
local fi=nv.lf(`{nv.behave}{x}`)
local newfi={}
for i,v in fi do
newfi[i]=nv.gsub(v,nv.behave,'')
end
return newfi
else
    nv.rwarn("File permissions denied.")
end
end)
nv.renv.NEXHttp=nv.tclone(nv.NEXHttp)
nv.renv._NEXVERSION=nv.version
nv.iro=nv.clonef(isreadonly)
nv.rant={}
nv.tclose=nv.clonef(task.cancel)
nv.tspawn=nv.clonef(task.spawn)
nv.nexify = function()
for _,v in nv.reg do
if not nv.rant[v] and nv.rtype(v)=="thread" then --this is the most
nv.rant[v]=true
local threadf=nv.info(v,1,'f')
local env=nv.getf(threadf)
local envm=nv.rawmt(env)
local envmm=nv.rawmt(envm) or nv.examplet
local envmi=envm.__index
local indr=nv.rawmt(envmi)
if nv.iro(envmm) or nv.iro(envm) then
if nv.debugm then
nv.rwarn(`Came across an abnormal thread! ({env.script})`)
      end
    else
if indr then
local oindrmt=indr.__metatable
indr.__metatable=nil
local newind=nv.tclone(envmi)
envm.__index=newind
indr.__metatable=oindrmt
end
local envte=newind or env
local envtenex=envte
if env and env.Protected_Environment then
if nv.debugm or env.ForceDebuggedEnvironment then
nv.rwarn(`{env.script} IS PROTECTED`)
                    end
            else
if env.NEXLuau then
nv.nex(env)
envte=nv.nexenv.std.NEXFunctions
envtenex=nv.nexenv
                    end
if env.ExternalThread then
nv.tclose(v)
nv.tw()
nv.tspawn(v)
if nv.debugm then
nv.rwarn(`{env.script} is EXTERNAL`)
end
end
for i,x in next,nv.renv do
envte[i]=x
end
envtenex.NEX_Loaded=true
                    if nv.debugm or env.ForceDebuggedEnvironment then
                    nv.rwarn(`NEX LOADED IN {env.script}`)
                    end
end
end
end
end
end
nv.renv.UpdateNEX=newcclosure(function()nv.nexify()end)
nv.nexify()
nv.SendNotification(nv.GuiService,{
Icon=nv.NEXIcon,
Title=nv.NEXTitle,
Text=`NEX Emulation finished in {nv.ot()-nv.t}`
})
nv.tw(0.01)
nv.cdef(function()nv.nexify()nv.tclose(nv.currentthread)end)
