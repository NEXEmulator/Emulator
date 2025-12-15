--!native
--!nolint
--!nocheck
--!optimize 3
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
local version="1.0.7"
local NEXIcon=getcustomasset(".icons/NEX.png")
local LoadedIcons={NEX=NEXIcon}
local cclose,info,genv,index,newindex=coroutine.close,debug.info,loadstring(NEXRequire("AllowedFunctions.luau"))()
xpcall(function()workspace[nil]()end,function()index=clonefunction(info(2,'f'))end)xpcall(function()workspace.woahs=1 end,function()newindex=clonefunction(info(2,'f'))end)
local GetService=index(orgame,"GetService")
local err=clonefunction(error)
local GuiService=cloneref(GetService(game,"GuiService"))
local ot=os.clock
local t=ot()
local NEXTitle=`NEX Emulator (V{version})`
local SendNotification=index(GuiService,"SendNotification")
SendNotification(GuiService,{
Icon=NEXIcon,
Title=NEXTitle,
Text="NEX Emulation starting..."
})
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
local reg=getreg()
local GameId=index(game,"GameId")
local HttpService=cloneref(GetService(game,"HttpService"))
local MarketplaceService=cloneref(GetService(game,"MarketplaceService"))
local GetProductInfo=clonefunction(index(MarketplaceService,"GetProductInfo"))
local JsonDecode=clonefunction(index(HttpService,"JSONDecode"))
local JsonEncode=clonefunction(index(HttpService,"JSONEncode"))
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
if not isfile("StarterSettings.json") then
writefile("StarterSettings.json",JsonEncode(HttpService,{EmulateOnGameIsLoaded=true,CapabilityMax=2,HTTPEnabled=true,FilesEnabled=true,ExternalFilePerms=false,DebugMode=false,RobloxScriptRequire=true}))
end
local settings=SettingsExist and s and settingst or JsonDecode(HttpService,readfile("StarterSettings.json"))
if not SettingsExist then
writefile(`{SettingsPrefix}Settings.json`,JsonEncode(HttpService,settings))
end
local IsLoaded=index(game,"IsLoaded")
if settings.EmulateOnGameIsLoaded then
repeat tw() until IsLoaded(game)
end
local NotAllowed={getgenv=1}
local HttpFamily={request=1}
local SetStateEnabled=clonefunction(Instance.new"Humanoid".SetStateEnabled)
local rnexists=`{SettingsPrefix}.rootname`
if not isfile(rnexists) then
writefile(RootName,' ')
writefile(rnexists,' ')
end
local grenv=getrenv()
local rrequire=grenv.require
local foundationimage=rrequire(index(index(index(index(index(index(index(index(index(game,"CorePackages"),"Packages"),"_Index"),"Foundation"),"Foundation"),"Components"),"Image"),"ImageSet"),"isFoundationImage"))
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
local match=string.match
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
local req=clonefunction(request)
local wf=clonefunction(writefile)
local mf=clonefunction(makefolder)
local isf=clonefunction(isfile)
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
local CapabilityMax=settings.CapabilityMax
local externalfp={}
renv.ExternalFileFunctions=externalfp
renv.Settings=tclone(settings)
renv.LoadedIcons=tclone(LoadedIcons)
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
externalfp[i]=clonefunction(v)
end
renv[i]=newcclosure(function(x,...)
if FilesEnabled then
return v(`{behave}{x}`,...)
end
rwarn("File permissions denied.")
end)
elseif HttpFamily[i] then
renv[i]=newcclosure(function(...)
if HttpEnabled then
return v(...)
end
rwarn("HTTP denied.")
end)
else 
if type(v)=="function" then
renv[i]=clonefunction(v)
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
local rawmt=clonefunction(getrawmetatable)
local tonum=clonefunction(tonumber)
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
__metatable={rawgetmetatable=rawmt,rawsetmetatable=clonefunction(setrawmetatable)},
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
local getf=clonefunction(getfenv)
local cc,cr=coroutine.create,coroutine.resume
local precalculatedsize=1024*16
local NEXHttp={}
local apf=clonefunction(appendfile)
local function download(url,filename,chunksize)
if FilesEnabled then
local ext={installedsize=0,finished=false,WaitForFile=newcclosure(function(self)
repeat tw() until self.finished
return self.installedsize
end)}
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
local ext={installedsize=0,finished=false,body='',WaitForFile=newcclosure(function(self)
repeat tw() until self.finished
return self.body 
end)}
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
local nd=newcclosure(clonefunction(download))
local git={
getgit=newcclosure(getgit),
clone=newcclosure(function(x)
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
NEXHttp.download=newcclosure(download)
NEXHttp.streamget=newcclosure(streamget)
renv.git=tclone(git)
local isfl=clonefunction(isfolder)
local lf=clonefunction(listfiles)
local gsub=clonefunction(exstr.gsub)
local requests={}
local byte=clonefunction(string.byte)
local format=clonefunction(string.format)
local sillystring='\\x%02X'
local tc=clonefunction(table.concat)
local function utf8(x)
local res={}
for i=1,#x do
res[i]=format(sillystring,byte(x,i))
    end
return tc(res)
end
local seriousstring = '\\x(%x%x)'
local woahnumber=16
local gmatch=clonefunction(string.gmatch)
local char=clonefunction(string.char)
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
return {ok=x.Success,status_code=x.StatusCode,content=utf8(x.Body),text=x.Body,json=newcclosure(function() return JsonDecode(HttpService,x.Body)end),headers=x.Headers,raise_for_status=newcclosure(function() if not x.Success then err(x.StatusMessage) end end),url=url,elapsed=x.Headers['x-timer']}
end
requests.get=newcclosure(function(x,options)
if HttpEnabled then
options.Url=x
options.Method="GET"
return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.post=newcclosure(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="POST"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.options=newcclosure(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="OPTIONS"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.patch=newcclosure(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="PATCH"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.put=newcclosure(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="PUT"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.delete=newcclosure(function(x,options)
  if HttpEnabled then
    options.Url=x
    options.Method="DELETE"
    return retq(req(options),x)
  else
    err("HTTP Permissions Denied.")
  end
end)
requests.post=newcclosure(function(x,options)
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
encode=newcclosure(utf8),
decode=newcclosure(untf8)
  },
base64={
  encode=clonefunction(crypt.base64.encode),
  decode=clonefunction(crypt.base64.decode)
}
}
renv.crypt=tclone(encrypt)
renv.requests=tclone(requests)
renv.typefile=newcclosure(function(x)
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
local split=clonefunction(exstr.split)
local rf=clonefunction(readfile)
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
local globalread=newcclosure(function(self)
  return rf(`{behave}{self.Path}`)
end)
local globalwrite=newcclosure(function(self,x)
return wf(`{behave}{self.Path}`,x)
end)
local wl,rl=clonefunction(writeline),clonefunction(readline)
local globalwriteline=newcclosure(function(self,x,y)
return wl(self.Path,x,y)
end)
local globalreadline=newcclosure(function(self,x)
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
local globalgd=newcclosure(function(self)
local t={}
checksexy(`{behave}{self.Path}`,t)
return t
end)
local df,dfo=clonefunction(delfile),clonefunction(delfolder)
local globaldestroy=newcclosure(function(self)
if self.Type=="file" then
          df(`{behave}{self.Path}`)
  else
          dfo(`{behave}{self.Path}`)
  end
end)
local globalgc=newcclosure(function(self) 
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
GetChildren=newcclosure(function(self)
return {}
  end),
GetDescendants=newcclosure(function(self)
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
local bc=clonefunction(buffer.create)
local rawsmt=clonefunction(rawsetmetatable)
local metatable={
__namecall=function(x,...)
local method=getnamecallmethod()
local methf=x[method]
if not methf then
              err("Attempted to call a non-existent method!")
          else
return methf(x,...)
          end
      end,
__type="File",
__tostring=function() return FileData.Name end,
__index=FileData,
__newindex=function(l,y,z)
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
  end,
__metatable="The metatable is locked."
}
local Holder=bc(0)
rawsmt(Holder,metatable)
return Holder
end
renv.OpenFile=newcclosure(OpenFile)
renv.readline=newcclosure(readline)
renv.writeline=newcclosure(writeline)
renv.listfiles=newcclosure(function(x)
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
for _,v in reg do
if rtype(v)=="thread" and v~=currentthread then
local threadf=info(v,1,'f')
local env=getf(threadf)
local envm=rawmt(env)
local envmm=rawmt(envm) or examplet
if not envmm.__newindex then
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
local newfunc=clonefunction(threadf)
cclose(v)
tw()
cr(cc(newfunc))
if debugm then
rwarn(`{env.script} is EXTERNAL`)
end
end
for i,v in next,renv do
envte[i]=v
end
envtenex.NEX_Loaded=true
                      if debugm or env.ForceDebuggedEnvironment then
                      rwarn(`NEX LOADED IN {env.script}`)
                      end
end
end
end
end
SendNotification(GuiService,{
Icon=NEXIcon,
Title=NEXTitle,
Text=`NEX Emulation finished in {ot()-t}`
})
cdef(function()cclose(currentthread)end)
