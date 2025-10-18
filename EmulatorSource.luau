--!native
--!nolint
--!nocheck
--!optimize 3
local info,genv,index=debug.info,loadstring(request({Url="https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/AllowedFunctions.luau",Method="GET"}).Body)()
xpcall(function()workspace[nil]()end,function()index=info(2,'f')end)
if not isfolder("GameData") then
makefolder("GameData")
end
local def=task.defer
local info=debug.info
local reg=getreg()
local NEXEnabled=true
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
local settings=SettingsExist and s and settingst or {CapabilityMax=2,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms={},DebugMode=false}
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local rootid=JsonDecode(HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{GameId}`,Method="GET"}).Body).rootPlaceId
local behave=`GameData/{rootid}/`
local RootName=`{behave}RootName {GetProductInfo(MarketplaceService,rootid).Name}`
if not isfile(RootName) then
writefile(RootName,' ')
end
local FileFamily={getfilename=1,readfile=1,writefile=1,isfile=1,isfolder=1,listfiles=1,makefolder=1,delfolder=1,delfile=1,appendfile=1,loadfile=1,getcustomasset=1}
if not SettingsExist then
writefile("Settings.json",JsonEncode(HttpService,settings))
end
if not isfolder(behave) then
makefolder(behave)
end
local Identity={setidentity=1}
local extraf={}
local renv={}
local InsertService=GetService(game,"InsertService")
local LLA=index(InsertService,"LoadLocalAsset")
local oldset=setidentity
genv.LoadLocalAsset=function(x)
local id=getthreadidentity()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,getcustomasset(x))
end
genv.InsertAsset=function(x)
local id=getthreadidentity()
if id<3 then
oldset(3)
def(oldset,id)
end
return LLA(InsertService,x)
end
local exstr="hi"
local find,sub=exstr.find,exstr.sub
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
renv.EXTRAFILEPERMS=extraf
renv.Settings=table.clone(settings)
local protectedfunctions={}
for _,v in genv do
protectedfunctions[v]=v
end
for _,v in renv do
protectedfunctions[v]=v
end
local oldhook=hookfunction
genv.hookfunction=function(x,y)
protectedfunctions[task.defer]=task.defer
if protectedfunctions[x] then
warn("Cannot hook protected functions. Reason: some functions could be hooked to gain access to unrestricted functions like oldset.")
    else
    return oldhook(x,y)
    end
end
for i,v in next,genv do
if not NotAllowed[i] then
if Identity[i] then
renv[i]=function(x)
if NEXEnabled then
if settings.CapabilityMax>=x then
return v(x)
else
warn("Capability changing permissions denied.")
end
end
end
elseif FileFamily[i] then
renv[i]=function(x,...)
if NEXEnabled then
if settings.FilesEnabled then
return v(`{behave}{x}`,...)
end
warn("File permissions denied.")
end
end
if settings.ExternalFilePerms[rootid] then
extraf[i]=v
end
elseif HttpFamily[i] then
renv[i]=function(...)
if NEXEnabled then
if settings.HTTPEnabled then
return v(...)
end
warn("HTTP denied.")
end
end
else 
if type(v)=="function" then
renv[i]=function(...)
if NEXEnabled then
return v(...)
end
end
else
renv[i]=v
end
end
end
end
for _,v in reg do
if type(v)=="thread" then
local env=getfenv(info(v,1,'f'))
if env then
for i,v in next,renv do
  env[i]=v
end
env.NEX_Loaded=true
if settings.DebugMode then
  print(`NEX LOADED IN {env.script}`)
end
end
end
end
