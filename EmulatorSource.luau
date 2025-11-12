--!native
--!nolint
--!nocheck
--!optimize 3
local game,workspace=cloneref(game),cloneref(workspace) --this is not to stop detection from weaktables, this is just so replications to the Instance metatable dont replicate to these instances for better security, I might be just paranoid, but better safe than sorry.
local cclose,info,genv,index,newindex=coroutine.close,debug.info,loadstring(request({Url="https://raw.githubusercontent.com/NEXEmulator/Emulator/refs/heads/main/AllowedFunctions.luau",Method="GET"}).Body)()
xpcall(function()workspace[nil]()end,function()index=clonefunction(info(2,'f'))end)xpcall(function()workspace.woahs=1 end,function()newindex=clonefunction(info(2,'f'))end)
local GetService=index(game,"GetService")
local GuiService=cloneref(GetService(game,"GuiService"))
local tw=task.wait
local FindFirstChild=clonefunction(index(workspace,"FindFirstChild"))
local NetworkClient=cloneref(GetService(game,"NetworkClient"))
local GetChildren=clonefunction(index(workspace,"GetChildren"))
local Clone=clonefunction(index(workspace,"Clone"))
local IsA=clonefunction(index(workspace,"IsA"))
local ClientReplicator=cloneref(FindFirstChild(NetworkClient,"ClientReplicator"))
local Destroy=clonefunction(index(game,"Destroy"))
if not isfolder("GameData") then
makefolder("GameData")
end
local rgca=clonefunction(getcustomasset)
local rwarn=clonefunction(warn)
local rtype=clonefunction(type)
local tclone=clonefunction(table.clone)
local cdef=clonefunction(task.defer)
local def=function(x,...) return cdef(function(...)return x(...)end,...)end
local info=debug.info
local reg=getreg()
local GameId=index(game,"GameId")
local HttpService=cloneref(GetService(game,"HttpService"))
local MarketplaceService=cloneref(GetService(game,"MarketplaceService"))
local GetProductInfo=clonefunction(index(MarketplaceService,"GetProductInfo"))
local JsonDecode=clonefunction(index(HttpService,"JSONDecode"))
local JsonEncode=clonefunction(index(HttpService,"JSONEncode"))
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
local SetStateEnabled=clonefunction(Instance.new"Humanoid".SetStateEnabled)
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
rwarn("RobloxScriptRequire disabled.")
end
end
local Identity={setidentity=1,getthreadidentity=1}
local renv={}
local InsertService=cloneref(GetService(game,"InsertService"))
local LLA=clonefunction(index(InsertService,"LoadLocalAsset"))
local Players=cloneref(GetService(game,"Players"))
local ClearError=clonefunction(index(GuiService,"ClearError"))
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
local ExternalFilePerms=(settings.ExternalFilePerms[rootid] and true or false)
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
if ExternalFilePerms then
renv[i]=clonefunction(v)
    else
      renv[i]=newcclosure(function(x,...)
      if FilesEnabled then
      return v(`{behave}{x}`,...)
      end
      rwarn("File permissions denied.")
      end)
end
elseif HttpFamily[i] then
renv[i]=newcclosure(function(...)
if HttpEnabled then
return v(...)
end
rwarn("HTTP denied.")
end)
else 
renv[i]=clonefunction(v)
end
end
end
for _,v in reg do
if rtype(v)=="thread" and v~=currentthread then
local env=getfenv(info(v,1,'f'))
if env and env.Protected_Environment then
if debugm then
rwarn(`{env.script} IS PROTECTED`)
                                end
                        else
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
cclose(currentthread)
