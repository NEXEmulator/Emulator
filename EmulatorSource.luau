local info,renv,genv,index=debug.info,getrenv(),getgenv()
xpcall(function()game[nil]()end,function()index=info(2,'f')end)
if not isfolder("games") then
makefolder("games")
end
local NEXEnabled=true
local GameId=index(game,"GameId")
local GetService=index(game,"GetService")
local HttpService=GetService(game,"HttpService")
local MarketplaceService=GetService(game,"MarketplaceService")
local GetProductInfo=index(MarketplaceService,"GetProductInfo")
local JsonDecode=index(HttpService,"JSONDecode")
local JsonEncode=index(HttpService,"JSONEncode")
local SettingsExist=isfile("settings.json")
local s,settingst=pcall(function()
return JsonDecode(HttpService,readfile("settings.json"))
end)
local settings=SettingsExist and s and settingst or {CapabilityMax=2,HTTPEnabled=false,FilesEnabled=false,ExternalFPerms={}}
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local rootid=JsonDecode(HttpService,
request({Url=`https://develop.roblox.com/v1/universes/{GameId}`,Method="GET"}).Body).rootPlaceId
local behave=`games/{rootid}/{GetProductInfo(MarketplaceService,rootid).Name}`
local FileFamily={readfile=1,writefile=1,isfile=1,isfolder=1,listfiles=1,makefolder=1,delfolder=1,delfile=1,appendfile=1,loadfile=1,getcustomasset=1}
if not isfile("settings.json") then
writefile("settings.json",JsonEncode(HttpService,settings))
end
local Identity={setidentity=1}
local extraf={}
genv.GetObjects=index(game,"GetObjects")
renv.EXTRAFILEPERMS=extraf
renv.Settings=table.clone(settings)
renv.StopNEX=function()NEXEnabled=false end
renv.StartNEX=function()NEXEnabled=true end
for i,v in next,genv do
if not NotAllowed[i] then
if Identity[i] then
  renv[i]=function(x)
    if NEXEnabled then
      if settings.CapabilityMax>=x then
        return v(x)
      else
        print("CAPABILITY PERMISSIONS DENIED")
      end
    end
end
elseif FileFamily[i] then
renv[i]=function(...)
  if NEXEnabled then
  if settings.FilesEnabled then
  return v(...)
  end
print("FILE PERMISSIONS DISABLED")
  end
end
if settings.ExternalFPerms[rootid] then
  extraf[i]=v
end
elseif HttpFamily[i] then
renv[i]=function(x,...)
  if NEXEnabled then
  if settings.HTTPEnabled then
    return v(`{behave}{x}`,...)
  end
  print("HTTP PERMISSIONS DENIED")
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
