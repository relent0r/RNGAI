WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibuildstructures.lua' )
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

--RNGAddToBuildQueue = AddToBuildQueue
function AddToBuildQueueRNG(aiBrain, builder, whatToBuild, buildLocation, relative, borderWarning)
    --if not aiBrain.RNG then
    --    return RNGAddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    --end
    if not builder.EngineerBuildQueue then
        builder.EngineerBuildQueue = {}
    end
    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
    --RUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, {buildLocation[1], buildLocation[3], buildLocation[2]}) 
    if borderWarning then
        --LOG('BorderWarning build')
        IssueBuildMobile({builder}, {buildLocation[1], buildLocation[3], buildLocation[2]}, whatToBuild, {})
    else
        aiBrain:BuildStructure(builder, whatToBuild, buildLocation, false)
    end
    local newEntry = {whatToBuild, buildLocation, relative, borderWarning}
    table.insert(builder.EngineerBuildQueue, newEntry)
    if builder.PlatoonHandle.PlatoonData.Construction.HighValue then
        --LOG('Engineer is building high value item')
        local ALLBPS = __blueprints
        local unitBp = ALLBPS[whatToBuild]
        --LOG('Unit being built '..repr(whatToBuild))
        --LOG('Tech category of unit being built '..repr(unitBp.TechCategory))
        if not builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory][builder.EntityId] then
            --LOG('Added engineer entry to queued structures')
            builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory][builder.EntityId] = {Engineer = builder, TimeStamp = GetGameTimeSeconds()}
            --LOG('Queue '..repr(builder.BuilderManagerData.EngineerManager.QueuedStructures[unitBp.TechCategory]))
        end
    end
end

function AIBuildBaseTemplateOrderedRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        if IsResource(buildingType) then
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
        else
            for l,bType in baseTemplate do
                for m,bString in bType[1] do
                    if bString == buildingType then
                        for n,position in bType do
                            if n > 1 and CanBuildStructureAt(aiBrain, whatToBuild, {position[1], GetSurfaceHeight(position[1], position[2]), position[2]}) then
                                if buildingType == 'MassStorage' then
                                    AddToBuildQueueRNG(aiBrain, builder, whatToBuild, position, false, true)
                                else
                                    AddToBuildQueueRNG(aiBrain, builder, whatToBuild, position, false)
                                end
                                table.remove(bType,n)
                                return
                            end
                        end 
                        break
                    end 
                end 
            end 
        end 
    end 
    return
end

local AntiSpamList = {}
function AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
    local factionIndex = aiBrain:GetFactionIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    -- If the c-engine can't decide what to build, then search the build template manually.
    if not whatToBuild then
        if AntiSpamList[buildingType] then
            return false
        end
        local FactionIndexToName = {[1] = 'UEF', [2] = 'AEON', [3] = 'CYBRAN', [4] = 'SERAPHIM', [5] = 'NOMADS', [6] = 'ARM', [7] = 'CORE' }
        local AIFactionName = FactionIndexToName[factionIndex]
        SPEW('*AIExecuteBuildStructure: We cant decide whatToBuild! AI-faction: '..AIFactionName..', Building Type: '..tostring(buildingType)..', engineer-faction: '..tostring(builder.factionCategory))
        -- Get the UnitId for the actual buildingType
        local BuildUnitWithID
        for Key, Data in buildingTemplate do
            if Data[1] and Data[2] and Data[1] == buildingType then
                SPEW('*AIExecuteBuildStructure: Found template: '..tostring(Data[1])..' - Using UnitID: '..tostring(Data[2]))
                BuildUnitWithID = Data[2]
                break
            end
        end
        -- If we can't find a template, then return
        if not BuildUnitWithID then
            AntiSpamList[buildingType] = true
            WARN('*AIExecuteBuildStructure: No '..tostring(builder.factionCategory)..' unit found for template: '..tostring(buildingType)..'! ')
            return false
        end
        -- get the needed tech level to build buildingType
        local BBC = __blueprints[BuildUnitWithID].CategoriesHash
        local NeedTech
        if BBC.BUILTBYCOMMANDER or BBC.BUILTBYTIER1COMMANDER or BBC.BUILTBYTIER1ENGINEER then
            NeedTech = 1
        elseif BBC.BUILTBYTIER2COMMANDER or BBC.BUILTBYTIER2ENGINEER then
            NeedTech = 2
        elseif BBC.BUILTBYTIER3COMMANDER or BBC.BUILTBYTIER3ENGINEER then
            NeedTech = 3
        end
        -- If we can't find a techlevel for the building we want to build, then return
        if not NeedTech then
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for BuildUnitWithID: '..tostring(BuildUnitWithID))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Need engineer with Techlevel ('..NeedTech..') for BuildUnitWithID: '..tostring(BuildUnitWithID))
        end
        -- get the actual tech level from the builder
        local BC = builder:GetBlueprint().CategoriesHash
        if BC.TECH1 or BC.COMMAND then
            HasTech = 1
        elseif BC.TECH2 then
            HasTech = 2
        elseif BC.TECH3 then
            HasTech = 3
        end
        -- If we can't find a techlevel for the building we  want to build, return
        if not HasTech then
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for engineer: '..tostring(builder:GetBlueprint().BlueprintId))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer ('..tostring(builder:GetBlueprint().BlueprintId)..') has Techlevel ('..HasTech..')')
        end

        if HasTech < NeedTech then
            WARN('*AIExecuteBuildStructure: TECH'..HasTech..' Unit "'..BuildUnitWithID..'" is assigned to build TECH'..NeedTech..' buildplatoon! ('..tostring(buildingType)..')')
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer with Techlevel ('..HasTech..') can build TECH'..NeedTech..' BuildUnitWithID: '..tostring(BuildUnitWithID))
        end

        HasFaction = builder.factionCategory
        NeedFaction = string.upper(__blueprints[string.lower(BuildUnitWithID)].General.FactionName)
        if HasFaction ~= NeedFaction then
            WARN('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', ('..HasFaction..') engineers can\'t build ('..NeedFaction..') structures!')
            return false
        else
            SPEW('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', Engineer with faction ('..HasFaction..') can build faction ('..NeedFaction..') - BuildUnitWithID: '..tostring(BuildUnitWithID))
        end

        local IsRestricted = import('/lua/game.lua').IsRestricted
        if IsRestricted(BuildUnitWithID, aiBrain:GetArmyIndex()) then
            WARN('*AIExecuteBuildStructure: Unit is Restricted!!! Building Type: '..tostring(buildingType)..', faction: '..tostring(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
            AntiSpamList[buildingType] = true
            return false
        end

        WARN('*AIExecuteBuildStructure: DecideWhatToBuild call failed for Building Type: '..tostring(buildingType)..', faction: '..tostring(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
        return false
    end
    -- find a place to build it (ignore enemy locations if it's a resource)
    -- build near the base the engineer is part of, rather than the engineer location
    local relativeTo
    if closeToBuilder then
        relativeTo = builder:GetPosition()
    elseif builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
    else
        local startPosX, startPosZ = aiBrain:GetArmyStartPos()
        relativeTo = {startPosX, 0, startPosZ}
    end
    local location = false
    if IsResource(buildingType) then
        if buildingType ~= 'T1HydroCarbon' and constructionData.MexThreat then
            --RNGLOG('MexThreat Builder Type')
            local threatMin = -9999
            local threatMax = 9999
            local threatRings = 0
            local threatType = 'AntiSurface'
            local markerTable = RUtils.AIGetSortedMassLocationsThreatRNG(aiBrain, constructionData.MinDistance, constructionData.MaxDistance, constructionData.ThreatMin, constructionData.ThreatMax, constructionData.ThreatRings, constructionData.ThreatType, relativeTo)
            relative = false
            for _,v in markerTable do
                if VDist3( v.position, relativeTo ) <= constructionData.MaxDistance and VDist3( v.position, relativeTo ) >= constructionData.MinDistance then
                    if CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then
                        --RNGLOG('MassPoint found for engineer')
                        location = table.copy(markerTable[Random(1,table.getn(markerTable))])
                        location = {location.position[1], location.position[3], location.position[2]}
                        --RNGLOG('Location is '..repr(location))
                        break
                    end
                end
            end
            if not location and EntityCategoryContains(categories.COMMAND,builder) then
                --RNGLOG('Location Returned by marker table is '..repr(location))
                return false
            end
        else
            location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, 'Enemy', relativeTo[1], relativeTo[3], 5)
        end
    else
        location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, baseTemplate, relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
    end
    -- if it's a reference, look around with offsets
    if not location and reference then
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                break
            end
        end
    end
    -- if we have no place to build, then maybe we have a modded/new buildingType. Lets try 'T1LandFactory' as dummy and search for a place to build near base
    if not location and not IsResource(buildingType) and builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        --RNGLOG('*AIExecuteBuildStructure: Find no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near base...')
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --RNGLOG('*AIExecuteBuildStructure: Yes! Found a place near base to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we still have no place to build, then maybe we have really no place near the base to build. Lets search near engineer position
    if not location and not IsResource(buildingType) then
        --RNGLOG('*AIExecuteBuildStructure: Find still no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near Engineer...')
        relativeTo = builder:GetPosition()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --RNGLOG('*AIExecuteBuildStructure: Yes! Found a place near engineer to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we have a location, build!
    if location then
        local borderWarning = false
        local relativeLoc = BuildToNormalLocation(location)
        if relative then
            relativeLoc = {relativeLoc[1] + relativeTo[1], relativeLoc[2] + relativeTo[2], relativeLoc[3] + relativeTo[3]}
        end
        if relativeLoc[1] - playableArea[1] <= 8 or relativeLoc[1] >= playableArea[3] - 8 or relativeLoc[3] - playableArea[2] <= 8 or relativeLoc[3] >= playableArea[4] - 8 then
            --RNGLOG('Playable Area 1, 3 '..repr(playableArea))
            --RNGLOG('Scenario Info 1, 3 '..repr(ScenarioInfo.size))
            --RNGLOG('BorderWarning is true, location is '..repr(relativeLoc))
            borderWarning = true
        end
        -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
        AddToBuildQueueRNG(aiBrain, builder, whatToBuild, NormalToBuildLocation(relativeLoc), false, borderWarning)
        return true
    end
    -- At this point we're out of options, so move on to the next thing
    return false
end

function AIBuildBaseTemplateRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        for _,bType in baseTemplate do
            for n,bString in bType[1] do
                AIExecuteBuildStructureRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
                return
            end
        end
    end
end

function AIBuildAvoidRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, cons)
    --LOG('AIBuildAvoidRNG Started')
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    local VDist3Sq = VDist3Sq
    local relativeTo
    local factionIndex = aiBrain:GetFactionIndex()

    local function normalposition(vec)
        return {vec[1],GetTerrainHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],GetTerrainHeight(vec[1],vec[2])}
    end
    --LOG('AIBuildAvoidRNG Checking if close to builder')
    if closeToBuilder then
        relativeTo = builder:GetPosition()
    elseif builder.BuilderManagerData and builder.BuilderManagerData.EngineerManager then
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
    else
        local startPosX, startPosZ = aiBrain:GetArmyStartPos()
        relativeTo = {startPosX, 0, startPosZ}
    end
    --LOG('AIBuildAvoidRNG Checking if cons.AvoidCategory')
    if cons.AvoidCategory then
        --LOG('AIBuildAvoidRNG Attempting to find position')
        local radius = cons.Radius or 10
        local unitList = aiBrain:GetUnitsAroundPoint(cons.AvoidCategory,  relativeTo, 60, 'Ally')
        local location = false
        local locationFound = false
        local unitCount = 0
        if whatToBuild then
            for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
                location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
                if location then
                    for _, v in unitList do
                        if VDist3Sq({location[1], location[3], location[2]}, v:GetPosition()) < radius * radius then
                            unitCount = unitCount + 1
                        end
                    end
                    if unitCount < 1 then
                        --LOG('AIBuildAvoidRNG I think we found a position at '..repr(location))
                        break
                    end
                end
            end
        end
        if location then
            --LOG('AIBuildAvoidRNG Placing into build queue')
            --LOG('Build queue is as follows')
            --LOG('whatToBuild '..whatToBuild)
            --LOG('Builder Location '..repr({location[1], location[3], location[2]})..' that last number should be a zero')
            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, location, false)
            return true
        end
    end
    --LOG('AIBuildAvoidRNG is returning false')
    return false
end

function AIBuildAdjacencyPriorityRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, cons)
    --RNGLOG('beginning adjacencypriority')
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    local scaleCount = 1
    local VDist3Sq = VDist3Sq
    local Centered=cons.Centered
    local AdjacencyBias=cons.AdjacencyBias
    local enemyReferencePos = aiBrain.emanager.enemy.Position or aiBrain.MapCenterPoint
    if AdjacencyBias then
        if AdjacencyBias=='Forward' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)<VDist3Sq(b:GetPosition(),enemyReferencePos) end)
            end
        elseif AdjacencyBias=='Back' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)>VDist3Sq(b:GetPosition(),enemyReferencePos) end)
            end
        elseif AdjacencyBias=='BackClose' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)/VDist3Sq(a:GetPosition(),builder:GetPosition())>VDist3Sq(b:GetPosition(),enemyReferencePos)/VDist3Sq(b:GetPosition(),builder:GetPosition()) end)
            end
        elseif AdjacencyBias=='ForwardClose' then
            for _,v in reference do
                table.sort(v,function(a,b) return VDist3Sq(a:GetPosition(),enemyReferencePos)*VDist3Sq(a:GetPosition(),builder:GetPosition())<VDist3Sq(b:GetPosition(),enemyReferencePos)*VDist3Sq(b:GetPosition(),builder:GetPosition()) end)
            end
        end
    end
    local function normalposition(vec)
        return {vec[1],GetTerrainHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],GetTerrainHeight(vec[1],vec[2])}
    end
    if whatToBuild then
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildingType })
        --RNGLOG('reference contains '..repr(table.getn(reference))..' items')
        if cons.Scale then
            --RNGLOG('Scale construction option is true')
            if buildingType == 'T1EnergyProduction' then
                --RNGLOG('buildingType is T1EnergyProduction')
                if aiBrain.EconomyMonitorThread then
                    local currentEnergyTrend = aiBrain.EconomyOverTimeCurrent.EnergyTrendOverTime
                    --RNGLOG('EnergyTrend when going to build T1 power '..currentEnergyTrend)
                    --RNGLOG('Amount of power needed is '..(120 - currentEnergyTrend))
                    local energyNumber = 120 - currentEnergyTrend
                    scaleCount = math.ceil(energyNumber/20)
                end
            end
        end
        local scalenumber = 0
        local itemQueued = false
        for i=1, scaleCount do
            scalenumber = scalenumber + 1
            for _,x in reference do
                for k,v in x do
                    if not Centered then
                        if not v.Dead then
                            local targetSize = v:GetBlueprint().Physics
                            local targetPos = v:GetPosition()
                            local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
                            local offsetX=math.floor(differenceX/2)
                            local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
                            local offsetZ=math.floor(differenceZ/2)
                            local offsetfactory=0
                            if EntityCategoryContains(categories.FACTORY, v) and (buildingType=='T1LandFactory' or buildingType=='T2SupportLandFactory' or buildingType=='T3SupportLandFactory') then
                                offsetfactory=2
                            end
                            -- Top/bottom of unit
                            for i=-offsetX,offsetX do
                                local testPos = { targetPos[1] + (i * 1), targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2)-offsetfactory, 0 }
                                local testPos2 = { targetPos[1] + (i * 1), targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2)+offsetfactory, 0 }
                                -- check if the buildplace is to close to the border or inside buildable area
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) then
                                        if cons.AvoidCategory and GetNumUnitsAroundPoint(aiBrain, cons.AvoidCategory, normalposition(testPos), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                                        if cons.AvoidCategory and GetNumUnitsAroundPoint(aiBrain, cons.AvoidCategory, normalposition(testPos2), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                            end
                            -- Sides of unit
                            for i=-offsetZ,offsetZ do
                                local testPos = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2)-offsetfactory, targetPos[3] + (i * 1), 0 }
                                local testPos2 = { targetPos[1]+targetSize.SkirtSizeX/2+(unitSize.SkirtSizeX/2)+offsetfactory, targetPos[3] + (i * 1), 0 }
                                if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos)
                                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) then
                                        if cons.AvoidCategory and GetNumUnitsAroundPoint(aiBrain, cons.AvoidCategory, normalposition(testPos), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                                    --table.insert(template[1], testPos2)
                                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                                        if cons.AvoidCategory and GetNumUnitsAroundPoint(aiBrain, cons.AvoidCategory, normalposition(testPos2), cons.maxRadius, 'Ally')<cons.maxUnits then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        elseif not cons.AvoidCategory then
                                            AddToBuildQueueRNG(aiBrain, builder, whatToBuild, heightbuildpos(testPos2), false)
                                            if cons.Scale then
                                                itemQueued = true
                                                break
                                            end
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    else
                        if not v.Dead then
                            local targetSize = v:GetBlueprint().Physics
                            local targetPos = v:GetPosition()
                            targetPos[1] = targetPos[1]-- - (targetSize.SkirtSizeX/2)
                            targetPos[3] = targetPos[3]-- - (targetSize.SkirtSizeZ/2)
                            -- Top/bottom of unit
                            local testPos = { targetPos[1], targetPos[3]-targetSize.SkirtSizeZ/2-(unitSize.SkirtSizeZ/2), 0 }
                            local testPos2 = { targetPos[1], targetPos[3]+targetSize.SkirtSizeZ/2+(unitSize.SkirtSizeZ/2), 0 }
                            -- check if the buildplace is to close to the border or inside buildable area
                            if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos)
                            end
                            if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos2)
                            end
                            -- Sides of unit
                            local testPos = { targetPos[1]+targetSize.SkirtSizeX/2 + (unitSize.SkirtSizeX/2), targetPos[3], 0 }
                            local testPos2 = { targetPos[1]-targetSize.SkirtSizeX/2-(unitSize.SkirtSizeX/2), targetPos[3], 0 }
                            if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos)
                            end
                            if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                                table.insert(template[1], testPos2)
                            end
                        end
                    end
                    if itemQueued then
                        break
                    end
                end
                if itemQueued then
                    break
                end
                -- build near the base the engineer is part of, rather than the engineer location
                local baseLocation = {nil, nil, nil}
                if builder.BuildManagerData and builder.BuildManagerData.EngineerManager then
                    baseLocation = builder.BuildManagerdata.EngineerManager.Location
                end
                --ForkThread(RNGrenderReference,template[1],unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                local location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, template, false, builder, baseLocation[1], baseLocation[3])
                if location then
                    if location[1] > 8 and location[1] < ScenarioInfo.size[1] - 8 and location[2] > 8 and location[2] < ScenarioInfo.size[2] - 8 then
                        --RNGLOG('Build '..repr(buildingType)..' at adjacency: '..repr(location) )
                        AddToBuildQueueRNG(aiBrain, builder, whatToBuild, location, false)
                        if cons.Scale then
                            itemQueued = true
                            break
                        end
                        return true
                    end
                end
                if itemQueued then
                    break
                end
            end
        end
        if itemQueued then
            --RNGLOG('scaleNumber '..scalenumber)
            return true
        end
        
        -- Build in a regular spot if adjacency not found
        if cons.AdjRequired then
            return false
        else
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, builder, true,  buildingTemplate, baseTemplate)
        end
    end
    return false
end

function AINewExpansionBaseRNG(aiBrain, baseName, position, builder, constructionData)
    local radius = constructionData.ExpansionRadius or 100
    if position[4] then
        position = {position[1], position[2], position[3]}
    end
    -- PBM Style expansion bases here
    if not aiBrain.BuilderManagers or aiBrain.BuilderManagers[baseName] or not builder.BuilderManagerData then
        --LOG('*AI DEBUG: ARMY ' .. aiBrain:GetArmyIndex() .. ': New Engineer for expansion base - ' .. baseName)
        builder.BuilderManagerData.EngineerManager:RemoveUnit(builder)
        aiBrain.BuilderManagers[baseName].EngineerManager:AddUnit(builder, true)
        return
    end

    aiBrain:AddBuilderManagers(position, radius, baseName, true)

    -- Move the engineer to the new base managers
    builder.BuilderManagerData.EngineerManager:RemoveUnit(builder)
    aiBrain.BuilderManagers[baseName].EngineerManager:AddUnit(builder, true)

    -- Iterate through bases finding the value of each expansion
    local baseValues = {}
    local highPri = false
    for templateName, baseData in BaseBuilderTemplates do
        local baseValue = baseData.ExpansionFunction(aiBrain, position, constructionData.NearMarkerType)
        table.insert(baseValues, { Base = templateName, Value = baseValue })
        --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
        if not highPri or baseValue > highPri then
            --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
            highPri = baseValue
        end
    end

    -- Random to get any picks of same value
    local validNames = {}
    for k,v in baseValues do
        if v.Value == highPri then
            table.insert(validNames, v.Base)
        end
    end
    --SPEW('*AI DEBUG: AINewExpansionBase(): validNames for Expansions ' .. repr(validNames))
    local pick = validNames[ Random(1, table.getn(validNames)) ]

    -- Error if no pick
    if not pick then
        RNGLOG('*AI DEBUG: ARMY ' .. aiBrain:GetArmyIndex() .. ': Layer Preference - ' .. per .. ' - yielded no base types at - ' .. locationType)
    end

    -- Setup base
    --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. aiBrain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
    import('/mods/RNGAI/lua/ai/aiaddbuildertable.lua').AddGlobalBaseTemplate(aiBrain, baseName, pick)

    -- If air base switch to building an air factory rather than land
    if (string.find(pick, 'Air') or string.find(pick, 'Water')) then
        local numToChange = BaseBuilderTemplates[pick].BaseSettings.FactoryCount.Land
        for k,v in constructionData.BuildStructures do
            if constructionData.BuildStructures[k] == 'T1LandFactory' and numToChange <= 0 then
                constructionData.BuildStructures[k] = 'T1AirFactory'
            elseif constructionData.BuildStructures[k] == 'T1LandFactory' and numToChange > 0 then
                numToChange = numToChange - 1
            end
        end
    end
end

function AIBuildBaseTemplateFromDefensivePointRNG(baseTemplate, location)
    local baseT = {}
    if location and baseTemplate then
        for templateNum, template in baseTemplate do
            baseT[templateNum] = {}
            for rowNum,rowData in template do
                if type(rowData[1]) == 'number' then
                    baseT[templateNum][rowNum] = {}
                    baseT[templateNum][rowNum][1] = math.floor(rowData[1] + location[1]) + 0.5
                    baseT[templateNum][rowNum][2] = math.floor(rowData[2] + location[3]) + 0.5
                    baseT[templateNum][rowNum][3] = 0
                else
                    baseT[templateNum][rowNum] = template[rowNum]
                end
            end
        end
    end
    return baseT
end