
local AIUtils = import("/lua/ai/aiutilities.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local RNGBeginSession = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').BeginSession
local RNGAIBeginSessionFunction = BeginSession
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

function BeginSession()
    ValidateModFilesRNG()
    RNGAIBeginSessionFunction()
    RNGBeginSession()
end

RNGCreateResourceDeposit = CreateResourceDeposit
local CreateMarkerRNG = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').CreateMarkerRNG
CreateResourceDeposit = function(t,x,y,z,size)
    CreateMarkerRNG(t,x,y,z,size)
    RNGCreateResourceDeposit(t,x,y,z,size)
end

RNGSetPlayableRect = SetPlayableRect
local RNGSetPlayableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').SetPlayableArea
SetPlayableRect = function(minx,minz,maxx,maxz)
    RNGSetPlayableRect(minx,minz,maxx,maxz)
    RNGSetPlayableArea(minx,minz,maxx,maxz)
end

function ValidateModFilesRNG()
    local ModName = '* '..'RNGAI'
    local ModDirectory = 'RNGAI'
    local Files = 95
    local Bytes = 4043783
    LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Running from: '..debug.getinfo(1).source..'.')
    LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Checking directory /mods/ for '..ModDirectory..'...')
    local FilesInFolder = DiskFindFiles('/mods/', '*.*')
    local modfoundcount = 0
    for _, FilepathAndName in FilesInFolder do
        if string.find(FilepathAndName, 'mod_info.lua') then
            if string.gsub(FilepathAndName, ".*/(.*)/.*", "%1") == string.lower(ModDirectory) then
                modfoundcount = modfoundcount + 1
                LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Found directory: '..FilepathAndName..'.')
            end
        end
    end
    if modfoundcount == 1 then
      LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check OK. Found '..modfoundcount..' '..ModDirectory..' directory.')
    else
      LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check FAILED! Found '..modfoundcount..' '..ModDirectory..' directories.')
    end
    LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Checking files and filesize for '..ModDirectory..'...')
    local FilesInFolder = DiskFindFiles('/mods/'..ModDirectory..'/', '*.*')
    local filecount = 0
    local bytecount = 0
    for _, FilepathAndName in FilesInFolder do
        if not string.find(FilepathAndName, '.git') then
            filecount = filecount + 1
            local fileinfo = DiskGetFileInfo(FilepathAndName)
            bytecount = bytecount + fileinfo.SizeBytes
        end
    end
    local FAIL = false
    if filecount < Files then
        LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check FAILED! Directory: '..ModDirectory..' - Missing '..(Files - filecount)..' files! ('..filecount..'/'..Files..')')
        FAIL = true
    elseif filecount > Files then
        LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check FAILED! Directory: '..ModDirectory..' - Found '..(filecount - Files)..' odd files! ('..filecount..'/'..Files..')')
        FAIL = true
    end
    if bytecount < Bytes then
        LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check FAILED! Directory: '..ModDirectory..' - Missing '..(Bytes - bytecount)..' bytes! ('..bytecount..'/'..Bytes..')')
        FAIL = true
    elseif bytecount > Bytes then
        LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check FAILED! Directory: '..ModDirectory..' - Found '..(bytecount - Bytes)..' odd bytes! ('..bytecount..'/'..Bytes..')')
        FAIL = true
    end
    if not FAIL then
        LOG(''..ModName..': ['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] - Check OK! files: '..filecount..', bytecount: '..bytecount..'.')
    end
end