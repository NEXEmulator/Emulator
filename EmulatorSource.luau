--!native
--!nolint
--!nocheck
--!optimize 3
local info,genv,index=debug.info,loadstring(request({Url="https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/AllowedFunctions.luau",Method="GET"}).Body)()
xpcall(function()workspace[nil]()end,function()index=info(2,'f')end)
if not isfolder("GameData") then
makefolder("GameData")
end
local rwarn=clonefunction(warn)
local tclone=table.clone
local cdef=clonefunction(task.defer)
local def=function(x,...) return cdef(function(...)return x(...)end,...)end
local info=debug.info
local reg=getreg()
local GameId=index(game,"GameId")
local GetService=index(game,"GetService")
local HttpService=GetService(game,"HttpService")
local MarketplaceService=GetService(game,"MarketplaceService")
local GetProductInfo=index(MarketplaceService,"GetProductInfo")
local JsonDecode=index(HttpService,"JSONDecode")
local JsonEncode=index(HttpService,"JSONEncode")
local SettingsExist=isfile("Settings.json")
local s,settingst=pcall(function()
return JsonDecode(HttpService,readfile("Settings.json"))
end)
local settings=SettingsExist and s and settingst or {EmulateOnGameIsLoaded=true,CapabilityMax=2,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms={},DebugMode=false}
local tw=task.wait
local IsLoaded=index(game,"IsLoaded")
if settings.EmulateOnGameIsLoaded then
repeat tw() until IsLoaded(game)
end
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local rootid=JsonDecode(HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{GameId}`,Method="GET"}).Body).rootPlaceId
local behave=`GameData/{rootid}/`
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
local Identity={setidentity=1,getthreadidentity=1}
local extraf={}
local renv={}
local InsertService=GetService(game,"InsertService")
local LLA=index(InsertService,"LoadLocalAsset")
local oldset=setidentity
local oldti=getthreadidentity
genv.LoadLocalAsset=function(x)
local id=oldti()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,getcustomasset(x))
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
renv.EXTRAFILEPERMS=extraf
renv.Settings=tclone(settings)
for i,v in next,genv do
if not NotAllowed[i] then
if Identity[i] then
renv[i]=function(x)
if CapabilityMax>=(x or 0) then
return v(x)
else
rwarn("Capability changing permissions denied.")
end
end
elseif FileFamily[i] then
renv[i]=function(x,...)
if FilesEnabled then
return v(`{behave}{x}`,...)
end
rwarn("File permissions denied.")
end
if ExternalFilePerms then
extraf[i]=v
end
elseif HttpFamily[i] then
renv[i]=function(...)
if HttpEnabled then
return v(...)
end
rwarn("HTTP denied.")
end
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
