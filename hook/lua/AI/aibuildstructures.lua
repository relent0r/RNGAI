WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibuildstructures.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

RNGAddToBuildQueue = AddToBuildQueue
function AddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    if not aiBrain.RNG then
        return RNGAddToBuildQueue(aiBrain, builder, whatToBuild, buildLocation, relative)
    end
    if not builder.EngineerBuildQueue then
        builder.EngineerBuildQueue = {}
    end
    -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
    RUtils.EngineerTryReclaimCaptureArea(aiBrain, builder, BuildToNormalLocation(buildLocation)) 
    aiBrain:BuildStructure(builder, whatToBuild, buildLocation, false)
    local newEntry = {whatToBuild, buildLocation, relative}
    table.insert(builder.EngineerBuildQueue, newEntry)
end

function AIBuildBaseTemplateOrderedRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local factionIndex = aiBrain:GetFactionIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        if IsResource(buildingType) then
            return AIExecuteBuildStructureRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference)
        else
            for l,bType in baseTemplate do
                for m,bString in bType[1] do
                    if bString == buildingType then
                        for n,position in bType do
                            if n > 1 and aiBrain:CanBuildStructureAt(whatToBuild, BuildToNormalLocation(position)) then
                                 AddToBuildQueue(aiBrain, builder, whatToBuild, position, false)
                                 table.remove(bType,n)
                                 return DoHackyLogic(buildingType, builder)
                            end # if n > 1 and can build structure at
                        end # for loop
                        break
                    end # if bString == builderType
                end # for loop
            end # for loop
        end # end else
    end # if what to build
    return # unsuccessful build
end


local AntiSpamList = {}
function AIExecuteBuildStructureRNG(aiBrain, builder, buildingType, closeToBuilder, relative, buildingTemplate, baseTemplate, reference, constructionData)
    local factionIndex = aiBrain:GetFactionIndex()
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    -- If the c-engine can't decide what to build, then search the build template manually.
    if not whatToBuild then
        if AntiSpamList[buildingType] then
            return false
        end
        local FactionIndexToName = {[1] = 'UEF', [2] = 'AEON', [3] = 'CYBRAN', [4] = 'SERAPHIM', [5] = 'NOMADS', [6] = 'ARM', [7] = 'CORE' }
        local AIFactionName = FactionIndexToName[factionIndex]
        SPEW('*AIExecuteBuildStructure: We cant decide whatToBuild! AI-faction: '..AIFactionName..', Building Type: '..repr(buildingType)..', engineer-faction: '..repr(builder.factionCategory))
        -- Get the UnitId for the actual buildingType
        local BuildUnitWithID
        for Key, Data in buildingTemplate do
            if Data[1] and Data[2] and Data[1] == buildingType then
                SPEW('*AIExecuteBuildStructure: Found template: '..repr(Data[1])..' - Using UnitID: '..repr(Data[2]))
                BuildUnitWithID = Data[2]
                break
            end
        end
        -- If we can't find a template, then return
        if not BuildUnitWithID then
            AntiSpamList[buildingType] = true
            WARN('*AIExecuteBuildStructure: No '..repr(builder.factionCategory)..' unit found for template: '..repr(buildingType)..'! ')
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
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for BuildUnitWithID: '..repr(BuildUnitWithID))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Need engineer with Techlevel ('..NeedTech..') for BuildUnitWithID: '..repr(BuildUnitWithID))
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
            WARN('*AIExecuteBuildStructure: Can\'t find techlevel for engineer: '..repr(builder:GetBlueprint().BlueprintId))
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer ('..repr(builder:GetBlueprint().BlueprintId)..') has Techlevel ('..HasTech..')')
        end

        if HasTech < NeedTech then
            WARN('*AIExecuteBuildStructure: TECH'..HasTech..' Unit "'..BuildUnitWithID..'" is assigned to build TECH'..NeedTech..' buildplatoon! ('..repr(buildingType)..')')
            return false
        else
            SPEW('*AIExecuteBuildStructure: Engineer with Techlevel ('..HasTech..') can build TECH'..NeedTech..' BuildUnitWithID: '..repr(BuildUnitWithID))
        end

        HasFaction = builder.factionCategory
        NeedFaction = string.upper(__blueprints[string.lower(BuildUnitWithID)].General.FactionName)
        if HasFaction ~= NeedFaction then
            WARN('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', ('..HasFaction..') engineers can\'t build ('..NeedFaction..') structures!')
            return false
        else
            SPEW('*AIExecuteBuildStructure: AI-faction: '..AIFactionName..', Engineer with faction ('..HasFaction..') can build faction ('..NeedFaction..') - BuildUnitWithID: '..repr(BuildUnitWithID))
        end

        local IsRestricted = import('/lua/game.lua').IsRestricted
        if IsRestricted(BuildUnitWithID, GetFocusArmy()) then
            WARN('*AIExecuteBuildStructure: Unit is Restricted!!! Building Type: '..repr(buildingType)..', faction: '..repr(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
            AntiSpamList[buildingType] = true
            return false
        end

        WARN('*AIExecuteBuildStructure: DecideWhatToBuild call failed for Building Type: '..repr(buildingType)..', faction: '..repr(builder.factionCategory)..' - Unit:'..BuildUnitWithID)
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
        if buildingType != 'T1HydroCarbon' and constructionData.MexThreat then
            LOG('MexThreat Builder Type')
            local threatMin = -9999
            local threatMax = 9999
            local threatRings = 0
            local threatType = 'AntiSurface'
            local markerTable = RUtils.AIGetSortedMassLocationsThreatRNG(aiBrain, constructionData.MinDistance, constructionData.MaxDistance, constructionData.ThreatMin, constructionData.ThreatMax, constructionData.ThreatRings, constructionData.ThreatType, relativeTo)
            relative = false
            for _,v in markerTable do
                if VDist3( v.Position, relativeTo ) <= constructionData.MaxDistance and VDist3( v.Position, relativeTo ) >= constructionData.MinDistance then
                    if aiBrain:CanBuildStructureAt('ueb1103', v.Position) then
                        LOG('MassPoint found for engineer')
                        location = table.copy(markerTable[Random(1,table.getn(markerTable))])
                        location = {location.Position[1], location.Position[3], location.Position[2]}
                        LOG('Location is '..repr(location))
                        break
                    end
                end
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
        --LOG('*AIExecuteBuildStructure: Find no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near base...')
        relativeTo = builder.BuilderManagerData.EngineerManager:GetLocationCoords()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --LOG('*AIExecuteBuildStructure: Yes! Found a place near base to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we still have no place to build, then maybe we have really no place near the base to build. Lets search near engineer position
    if not location and not IsResource(buildingType) then
        --LOG('*AIExecuteBuildStructure: Find still no place to Build! - buildingType '..repr(buildingType)..' - ('..builder.factionCategory..') Trying again with T1LandFactory and RandomIter. Searching near Engineer...')
        relativeTo = builder:GetPosition()
        for num,offsetCheck in RandomIter({1,2,3,4,5,6,7,8}) do
            location = aiBrain:FindPlaceToBuild('T1LandFactory', whatToBuild, BaseTmplFile['MovedTemplates'..offsetCheck][factionIndex], relative, closeToBuilder, nil, relativeTo[1], relativeTo[3])
            if location then
                --LOG('*AIExecuteBuildStructure: Yes! Found a place near engineer to Build! - buildingType '..repr(buildingType))
                break
            end
        end
    end
    -- if we have a location, build!
    if location then
        local relativeLoc = BuildToNormalLocation(location)
        if relative then
            relativeLoc = {relativeLoc[1] + relativeTo[1], relativeLoc[2] + relativeTo[2], relativeLoc[3] + relativeTo[3]}
        end
        -- put in build queue.. but will be removed afterwards... just so that it can iteratively find new spots to build
        AddToBuildQueue(aiBrain, builder, whatToBuild, NormalToBuildLocation(relativeLoc), false)
        return true
    end
    -- At this point we're out of options, so move on to the next thing
    return false
end

function AIBuildAdjacencyPriorityRNG(aiBrain, builder, buildingType , closeToBuilder, relative, buildingTemplate, baseTemplate, reference, cons)
    LOG('beginning adjacencypriority')
    local whatToBuild = aiBrain:DecideWhatToBuild(builder, buildingType, buildingTemplate)
    if whatToBuild then
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildingType })
        LOG('reference contains '..repr(table.getn(reference))..' items')
        for _,x in reference do
            for k,v in x do
                if not v.Dead then
                    local targetSize = v:GetBlueprint().Physics
                    local targetPos = v:GetPosition()
                    targetPos[1] = targetPos[1] - (targetSize.SkirtSizeX/2)
                    targetPos[3] = targetPos[3] - (targetSize.SkirtSizeZ/2)
                    -- Top/bottom of unit
                    for i=0,((targetSize.SkirtSizeX/2)-1) do
                        local testPos = { targetPos[1] + 1 + (i * 2), targetPos[3]-(unitSize.SkirtSizeZ/2), 0 }
                        local testPos2 = { targetPos[1] + 1 + (i * 2), targetPos[3]+targetSize.SkirtSizeZ+(unitSize.SkirtSizeZ/2), 0 }
                        -- check if the buildplace is to close to the border or inside buildable area
                        if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos)
                        end
                        if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos2)
                        end
                    end
                    -- Sides of unit
                    for i=0,((targetSize.SkirtSizeZ/2)-1) do
                        local testPos = { targetPos[1]+targetSize.SkirtSizeX + (unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i * 2), 0 }
                        local testPos2 = { targetPos[1]-(unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i*2), 0 }
                        if testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos)
                        end
                        if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos2)
                        end
                    end
                end
            end
            -- build near the base the engineer is part of, rather than the engineer location
            local baseLocation = {nil, nil, nil}
            if builder.BuildManagerData and builder.BuildManagerData.EngineerManager then
                baseLocation = builder.BuildManagerdata.EngineerManager.Location
            end
            local location = aiBrain:FindPlaceToBuild(buildingType, whatToBuild, template, false, builder, baseLocation[1], baseLocation[3])
            if location then
                if location[1] > 8 and location[1] < ScenarioInfo.size[1] - 8 and location[2] > 8 and location[2] < ScenarioInfo.size[2] - 8 then
                    --LOG('Build '..repr(buildingType)..' at adjacency: '..repr(location) )
                    AddToBuildQueue(aiBrain, builder, whatToBuild, location, false)
                    return true
                end
            end
        end
        -- Build in a regular spot if adjacency not found
        if cons.AdjRequired then
            return false
        else
            return AIExecuteBuildStructure(aiBrain, builder, buildingType, builder, true,  buildingTemplate, baseTemplate)
        end
    end
    return false
end