--!native
--!nolint
--!nocheck
--!optimize 3
local info,genv,index,newindex=debug.info,loadstring(request({Url="https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/AllowedFunctions.luau",Method="GET"}).Body)()
xpcall(function()workspace[nil]()end,function()index=clonefunction(info(2,'f'))end)xpcall(function()workspace.woahs=1 end,function()newindex=clonefunction(info(2,'f'))end)
local GetService=index(game,"GetService")
local GuiService=GetService(game,"GuiService")
local tw=task.wait
local FindFirstChild=index(game,"FindFirstChild")
local NetworkClient=GetService(game,"NetworkClient")
local GetChildren=index(game,"GetChildren")
local Clone=index(game,"Clone")
local IsA=index(game,"IsA")
local ClientReplicator=FindFirstChild(NetworkClient,"ClientReplicator")
local Destroy=index(game,"Destroy")
if not isfolder("GameData") then
makefolder("GameData")
end
local rgca=clonefunction(getcustomasset)
local rwarn=clonefunction(warn)
local tclone=table.clone
local cdef=clonefunction(task.defer)
local def=function(x,...) return cdef(function(...)return x(...)end,...)end
local info=debug.info
local reg=getreg()
local GameId=index(game,"GameId")
local HttpService=GetService(game,"HttpService")
local MarketplaceService=GetService(game,"MarketplaceService")
local GetProductInfo=index(MarketplaceService,"GetProductInfo")
local JsonDecode=index(HttpService,"JSONDecode")
local JsonEncode=index(HttpService,"JSONEncode")
local SettingsExist=isfile("Settings.json")
local s,settingst=pcall(function()
return JsonDecode(HttpService,readfile("Settings.json"))
end)
local settings=SettingsExist and s and settingst or {EmulateOnGameIsLoaded=true,CapabilityMax=2,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms={},DebugMode=false,RobloxScriptRequire=true}
local IsLoaded=index(game,"IsLoaded")
if settings.EmulateOnGameIsLoaded then
repeat tw() until IsLoaded(game)
end
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local rootid=JsonDecode(HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{GameId}`,Method="GET"}).Body).rootPlaceId
local behave=`GameData/{rootid}/`
local gca=function(x) return rgca(`{behave}{x}`) end
local RootName=`{behave}RootName {GetProductInfo(MarketplaceService,rootid).Name}`
local rnexists=`{behave}.rootname`
if not isfile(rnexists) then
writefile(RootName,' ')
writefile(rnexists,' ')
end
local FileFamily={getfilename=1,readfile=1,writefile=1,isfile=1,isfolder=1,listfiles=1,makefolder=1,delfolder=1,delfile=1,appendfile=1,loadfile=1,getcustomasset=1}
if not SettingsExist then
writefile("Settings.json",JsonEncode(HttpService,settings))
end
if not isfolder(behave) then
makefolder(behave)
end
if settings.RobloxScriptRequire then
genv.Rrequire=getrenv().require
else
genv.RobloxScriptRequire=function(...)
warn("RobloxScriptRequire disabled.")
end
end
local Identity={setidentity=1,getthreadidentity=1}
local extraf={}
local renv={}
local InsertService=GetService(game,"InsertService")
local LLA=clonefunction(index(InsertService,"LoadLocalAsset"))
local Players=GetService(game,"Players")
local ClearError=index(GuiService,"ClearError")
local oldset=setidentity
local oldti=getthreadidentity
genv.DisconnectFromServer=function()
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
local LP=index(Players,"LocalPlayer")
index(LP,"Kick")(LP)
ClearError(GuiService)
repeat tw() until index(ClientReplicator,"Parent")==nil
local char=index(LP,"Character")
newindex(char,"Archivable",true)
local c=GetChildren(Clone(char))
for i,v in GetChildren(char) do --didnt use next because it's already an integer placement, not a dict
if IsA(v,"BasePart") or index(v,"ClassName")=="Accessory" then --I wanted to use if not v:IsA"LuaSourceContainer" but it didnt let me walk for some reason
Destroy(v)
c[i].Parent=char
end
end
end
genv.LoadLocalAsset=function(x)
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,gca(x))
end
genv.InsertAsset=function(x)
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,x)
end
local debugm=settings.DebugMode
local exstr="hi"
local find,sub=clonefunction(exstr.find),clonefunction(exstr.sub)
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
local HttpEnabled=settings.HTTPEnabled
local FilesEnabled=settings.FilesEnabled
local CapabilityMax=settings.CapabilityMax
local ExternalFilePerms=settings.ExternalFilePerms[rootid]
renv.EXTRAFILEPERMS=ExternalFilePerms
renv.Settings=tclone(settings)
for i,v in next,genv do
if not NotAllowed[i] then
if Identity[i] then
renv[i]=newcclosure(function(x)
if CapabilityMax>=(x or 0) then
return v(x)
else
rwarn("Capability changing permissions denied.")
end
end)
elseif FileFamily[i] then
renv[i]=newcclosure(function(x,...)
if FilesEnabled then
return v(`{behave}{x}`,...)
end
rwarn("File permissions denied.")
end)
if ExternalFilePerms then
extraf[i]=v
end
elseif HttpFamily[i] then
renv[i]=newcclosure(function(...)
if HttpEnabled then
return v(...)
end
rwarn("HTTP denied.")
end)
else 
renv[i]=v
end
end
end
for _,v in reg do
if type(v)=="thread" then
local env=getfenv(info(v,1,'f'))
if env  then
for i,v in next,renv do
env[i]=v
end
env.NEX_Loaded=true
if debugm then
rwarn(`NEX LOADED IN {env.script}`)
end
end
end
end
