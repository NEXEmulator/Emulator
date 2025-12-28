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
local basepart = {['CornerWedgePart']=true,["Part"]=true,['FlagStand']=true,['Platform']=true,['Seat']=true,["SkateboardPlatform"]=true,["SpawnLocation"]=true,["WedgePart"]=true,["VehicleSeat"]=true,["Terrain"]=true,["MeshPart"]=true,["PartOperation"]=true,["IntersectOperation"]=true,["UnionOperation"]=true,["NegateOperation"]=true,["TrussPart"]=true}
local clamp = clonef(math.clamp)
local tc = clonef(table.concat)
local typo = clonef(typeof)
local format = clonef(string.format)
local floor = clonef(math.floor)
local tos = clonef(tostring)
local insert = clonef(table.insert)
local upc = clonef(table.unpack)
local handlers = {
  ["string"] = function(pn, pv)
    local tag = (pn == "HistoryId" or pn == "UniqueId") and "string" or "string"
    return format('\n<%s name="%s"><![CDATA[%s]]></%s>', tag, pn, tos(pv), tag)
  end,
  ["boolean"] = function(pn, pv)
    return format('\n<bool name="%s">%s</bool>', pn, tos(pv))
  end,
  ["number"] = function(pn, pv)
    return format('\n<double name="%s">%f</double>', pn, pv)
  end,
  ["Vector3"] = function(pn, pv)
    return format('\n<Vector3 name="%s"><X>%f</X><Y>%f</Y><Z>%f</Z></Vector3>', pn, pv.X, pv.Y, pv.Z)
  end,
  ["Vector2"] = function(pn, pv)
    return format('\n<Vector2 name="%s"><X>%f</X><Y>%f</Y></Vector2>', pn, pv.X, pv.Y)
  end,
  ["CFrame"] = function(pn, pv)
    return format('\n<CoordinateFrame name="%s"><X>%f</X><Y>%f</Y><Z>%f</Z><R00>%f</R00><R01>%f</R01><R02>%f</R02><R10>%f</R10><R11>%f</R11><R12>%f</R12><R20>%f</R20><R21>%f</R21><R22>%f</R22></CoordinateFrame>', pn, upc({pv.GetComponents(pv)}))
  end,
  ["UDim2"] = function(pn, pv)
    return format('\n<UDim2 name="%s"><XS>%f</XS><XO>%d</XO><YS>%f</YS><YO>%d</YO></UDim2>', pn, pv.X.Scale, pv.X.Offset, pv.Y.Scale, pv.Y.Offset)
  end,
  ["UDim"] = function(pn, pv)
    return format('\n<UDim name="%s"><S>%f</S><O>%d</O></UDim>', pn, pv.Scale, pv.Offset)
  end,
  ["Rect"] = function(pn, pv)
    return format('\n<Rect2D name="%s"><min><X>%f</X><Y>%f</Y></min><max><X>%f</X><Y>%f</Y></max></Rect2D>', pn, pv.Min.X, pv.Min.Y, pv.Max.X, pv.Max.Y)
  end,
  ["PhysicalProperties"] = function(pn, pv)
    return format('\n<PhysicalProperties name="%s"><CustomPhysics>true</CustomPhysics><AcousticAbsorption>%f</AcousticAbsorption><Density>%f</Density><Elasticity>%f</Elasticity><Friction>%f</Friction><ElasticityWeight>%f</ElasticityWeight><FrictionWeight>%f</FrictionWeight></PhysicalProperties>', pn, pv.AcousticAbsorption, pv.Density, pv.Elasticity, pv.Friction, pv.ElasticityWeight, pv.FrictionWeight)
  end,
  ["NumberRange"] = function(pn, pv)
    return format('\n<NumberRange name="%s">%f %f</NumberRange>', pn, pv.Min, pv.Max)
  end,
  ["EnumItem"] = function(pn, pv)
    local tag = (pn == "Capabilities") and "SecurityCapabilities" or "token"
    return format('\n<%s name="%s">%d</%s>', tag, pn, pv.Value, tag)
  end,
  ["Axes"] = function(pn, pv)
    local val = (pv.X and 1 or 0) + (pv.Y and 2 or 0) + (pv.Z and 4 or 0)
    return format('\n<Axes name="%s"><axes>%d</axes></Axes>', pn, val)
  end,
  ["Faces"] = function(pn, pv)
    local val = (pv.Front and 1 or 0) + (pv.Back and 2 or 0) + (pv.Top and 4 or 0) + (pv.Bottom and 8 or 0) + (pv.Left and 16 or 0) + (pv.Right and 32 or 0)
    return format('\n<Faces name="%s"><faces>%d</faces></Faces>', pn, val)
  end
}
local function tabletoxml(x)
  local res = {'<roblox version="4">'}
  local function tsex(tabl)
    for i, v in next, tabl do
      if i == "WorkspaceMeta" then
        for k, val in next, v do
          insert(res, format('\n<Meta name="%s">%s</Meta>', k, tos(val)))
        end
      elseif sub(i, 1, 4) == "Item" then
        insert(res, v.referent and format('\n<Item class="%s" referent="%s">', v.ClassName, v.referent) or format('\n<Item class="%s">', v.ClassName))
        local padd = false
        local class = v.ClassName
        for pn, pv in next, v do
          if pn ~= "ClassName" and pn ~= "referent" and sub(pn, 1, 4) ~= "Item" then
            if not padd then
              padd = true
              insert(res, "\n<Properties>")
            end
            local tp = typo(pv)
            local handler = handlers[tp]
            if handler then
              insert(res, handler(pn, pv))
            elseif tp == "Color3" then
              if basepart[class] then
                local u = (4278190080)+(floor(clamp(pv.R*255,0,255))*65536)+(floor(clamp(pv.G*255,0,255))*256)+floor(clamp(pv.B*255,0,255))
                insert(res, format('\n<Color3uint8 name="%s">%u</Color3uint8>', pn, u))
              else
                insert(res, format('\n<Color3 name="%s"><R>%f</R><G>%f</G><B>%f</B></Color3>', pn, pv.R, pv.G, pv.B))
              end
            elseif tp == "table" then
              if pv.Content then
                insert(res, format('\n<Content name="%s"><url>%s</url></Content>', pn, pv.Content))
              elseif pv.Reference then
                insert(res, format('\n<Ref name="%s">%s</Ref>', pn, pv.Reference))
              elseif pv.SharedString then
                insert(res, format('\n<SharedString name="%s">%s</SharedString>', pn, pv.SharedString))
              else
                insert(res, format('\n%s', pv[1]))
              end
            else
              insert(res, format('\n<%s name="%s">%s</%s>', tp, pn, tos(pv), tp))
            end
          end
        end
        if padd then insert(res, "\n</Properties>") end
        for kn, kv in next, v do
          if sub(kn, 1, 4) == "Item" then
            tsex({[kn] = kv})
          end
        end
        insert(res, "\n</Item>")
      end
    end
  end
  tsex(x)
  insert(res, "\n</roblox>")
  return tc(res)
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
local XML={
Object=cppf(xmlobject),
Load=cppf(loadxml),
TableToXML=cppf(tabletoxml)
}
renv.XML=tclone(XML)
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
