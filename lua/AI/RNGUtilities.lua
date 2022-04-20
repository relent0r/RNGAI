local AIUtils = import('/lua/ai/AIUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local Utils = import('/lua/utilities.lua')
local MABC = import('/lua/editor/MarkerBuildConditions.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local ToString = import('/lua/sim/CategoryUtils.lua').ToString
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local ALLBPS = __blueprints

-- TEMPORARY LOUD LOCALS
local RNGPOW = math.pow
local RNGSQRT = math.sqrt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGREMOVE = table.remove
local RNGSORT = table.sort
local RNGFLOOR = math.floor
local RNGCEIL = math.ceil
local RNGPI = math.pi
local RNGCAT = table.cat
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- Cached categories
local CategoriesShield = categories.SHIELD * categories.STRUCTURE

--[[
Valid Threat Options:
            Overall
            OverallNotAssigned
            StructuresNotMex
            Structures
            Naval
            Air
            Land
            Experimental
            Commander
            Artillery
            AntiAir
            AntiSurface
            AntiSub
            Economy
            Unknown
    
            It should be noted that calculateplatoonthreat does not use imap values but looks to perform a string search through the blueprints
            of the threat types. e.g there is no antisurface, but there is a surface. If you use a non valid threat type you will get overall.
        self:SetUpAttackVectorsToArmy(categories.STRUCTURE - (categories.MASSEXTRACTION))
        --RNGLOG('Attack Vectors'..repr(self:GetAttackVectors()))

        setfocusarmy -1 = back to observer
]]

local PropBlacklist = {}
-- This uses a mix of Uveso's reclaim logic and my own
function ReclaimRNGAIThread(platoon, self, aiBrain)
    local function MexBuild(platoon, eng, aiBrain)
        local bool,markers=MABC.CanBuildOnMassMexPlatoon(aiBrain, platoon:GetPlatoonPosition(), 25)
        if bool then
            IssueClearCommands({eng})
            local factionIndex = aiBrain:GetFactionIndex()
            local buildingTmplFile = import('/lua/BuildingTemplates.lua')
            local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
            local whatToBuild = aiBrain:DecideWhatToBuild(eng, 'T1Resource', buildingTmpl)
            --RNGLOG('Reclaim AI We can build on a mass marker within 30')
            for _,massMarker in markers do
                EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 2)
                EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                if massMarker.BorderWarning then
                    --RNGLOG('Border Warning on mass point marker')
                    IssueBuildMobile({eng}, massMarker.Position, whatToBuild, {})
                else
                    --RNGLOG('Reclaim AI building mex')
                    aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                end
            end
            while eng and not eng.Dead and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                coroutine.yield(20)
            end
        end
    end

    --RNGLOG('* AI-RNG: Start Reclaim Function')
    if aiBrain.StartReclaimTaken then
        --RNGLOG('StartReclaimTaken set to true')
        --RNGLOG('Start Reclaim Table has '..RNGGETN(aiBrain.StartReclaimTable)..' items in it')
    end
    IssueClearCommands({self})
    local locationType = self.PlatoonData.LocationType
    local initialRange = 40
    local createTick = GetGameTick()
    local reclaimLoop = 0
    local VDist2 = VDist2

    self.BadReclaimables = self.BadReclaimables or {}

    while aiBrain:PlatoonExists(platoon) and self and not self.Dead do
        local engPos = self:GetPosition()
        local minRec = platoon.PlatoonData.MinimumReclaim
        if not aiBrain.StartReclaimTaken then
            --self:SetCustomName('StartReclaim Logic Start')
            --RNGLOG('Reclaim Function - Starting reclaim is false')
            local tableSize = RNGGETN(aiBrain.StartReclaimTable)
            --LOG('Start reclaim table size '..tableSize)
            if tableSize > 0 then
                local reclaimCount = 0
                local firstReclaim = false
                while tableSize > 0 do
                    --coroutine.yield(10)
                    aiBrain.StartReclaimTaken = true
                    local closestReclaimDistance = false
                    local closestReclaim
                    local closestReclaimKey
                    local highestValue = 0
                    if not firstReclaim then
                        for k, r in aiBrain.StartReclaimTable do
                            if r.Reclaim and not IsDestroyed(r.Reclaim) then
                                if r.Reclaim.MaxMassReclaim > highestValue then
                                    closestReclaim = r.Reclaim
                                    closestReclaimKey = k
                                    highestValue  = r.Reclaim.MaxMassReclaim
                                end
                            end
                        end
                        firstReclaim = true
                    else
                        for k, r in aiBrain.StartReclaimTable do
                            local reclaimDistance
                            if r.Reclaim and not IsDestroyed(r.Reclaim) then
                                reclaimDistance = VDist3Sq(engPos, r.Reclaim.CachePosition)
                                if not closestReclaimDistance or reclaimDistance < closestReclaimDistance then
                                    closestReclaim = r.Reclaim
                                    closestReclaimDistance = reclaimDistance
                                    closestReclaimKey = k
                                end
                            end
                        end
                    end
                    if closestReclaim then
                        --RNGLOG('Closest Reclaim is true we are going to try reclaim it')
                        reclaimCount = reclaimCount + 1
                       --RNGLOG('Reclaim Function - Issuing reclaim')
                        IssueReclaim({self}, closestReclaim)
                        coroutine.yield(20)
                        local reclaimTimeout = 0
                        local massOverflow = false
                        while aiBrain:PlatoonExists(platoon) and closestReclaim and (not IsDestroyed(closestReclaim)) and (reclaimTimeout < 40) do
                            reclaimTimeout = reclaimTimeout + 1
                            --RNGLOG('Waiting for reclaim to no longer exist')
                            if aiBrain:GetEconomyStoredRatio('MASS') > 0.95 then
                                -- we are overflowing mass, assume we either need actual power or build power and we'll be close enough to the base to provide it.
                                -- watch out for thrashing as I don't have a minimum storage check on this builder
                                --LOG('We are overflowing mass return from early reclaim thread')
                                IssueClearCommands({self})
                                return
                            end
                            if self:IsUnitState('Reclaiming') and reclaimTimeout > 0 then
                                reclaimTimeout = reclaimTimeout - 1
                            end
                            coroutine.yield(20)
                        end
                        engPos = self:GetPosition()
                        local rectDef = Rect(engPos[1] - 8, engPos[3] - 8, engPos[1] + 8, engPos[3] + 8)
                        local reclaimRect = GetReclaimablesInRect(rectDef)
                        local engReclaiming = false
                        if reclaimRect then
                            for c, b in reclaimRect do
                                if not IsProp(b) or self.BadReclaimables[b] then continue end
                                -- Start Blacklisted Props
                                local blacklisted = false
                                for _, BlackPos in PropBlacklist do
                                    if b.CachePosition[1] == BlackPos[1] and b.CachePosition[3] == BlackPos[3] then
                                        blacklisted = true
                                        break
                                    end
                                end
                                if blacklisted then continue end
                                if b.MaxMassReclaim then
                                    engReclaiming = true
                                    reclaimCount = reclaimCount + 1
                                    IssueReclaim({self}, b)
                                end
                            end
                        end
                        if engReclaiming then
                            local idleCounter = 0
                            while not self.Dead and 0<RNGGETN(self:GetCommandQueue()) and aiBrain:PlatoonExists(platoon) do
                                self:SetCustomName('Engineer in reclaim loop')
                                if not self:IsUnitState('Reclaiming') and not self:IsUnitState('Moving') then
                                    --RNGLOG('We are not reclaiming or moving in the reclaim loop')
                                    --RNGLOG('But we still have '..RNGGETN(self:GetCommandQueue())..' Commands in the queue')
                                    idleCounter = idleCounter + 1
                                    if idleCounter > 15 then
                                        --RNGLOG('idleCounter hit, breaking loop')
                                        break
                                    end
                                end
                                --RNGLOG('We are reclaiming stuff')
                                coroutine.yield(30)
                            end
                        end
                        --RNGLOG('Reclaim Count is '..reclaimCount)
                        if reclaimCount > 10 then
                            break
                        end
                        --RNGLOG('Set key to nil '..closestReclaimKey)
                        aiBrain.StartReclaimTable[closestReclaimKey] = nil
                    end
                    reclaimCount = reclaimCount + 1
                    if reclaimCount > 10 then
                        break
                    end
                    coroutine.yield(2)
                    aiBrain.StartReclaimTable = aiBrain:RebuildTable(aiBrain.StartReclaimTable)
                    tableSize = RNGGETN(aiBrain.StartReclaimTable)
                end
                
                if RNGGETN(aiBrain.StartReclaimTable) == 0 then
                    --RNGLOG('Start Reclaim Taken set to true')
                    aiBrain.StartReclaimTaken = true
                else
                    --RNGLOG('Start Reclaim table not empty, set StartReclaimTaken to false')
                    aiBrain.StartReclaimTaken = false
                end
            end
            --self:SetCustomName('StartReclaim logic end')
        end
        if platoon.PlatoonData.ReclaimTable then
           --RNGLOG('We are going to lookup the reclaim table for high reclaim positions')
            if aiBrain.MapReclaimTable then
               --LOG('aiBrain MapReclaimTable exist')
                local reclaimOptions = {}
                local maxReclaimCount = 30
                local validLocation = false
                for _, v in aiBrain.MapReclaimTable do
                    if v.TotalReclaim > 100 then
                        RNGINSERT(reclaimOptions, {Position = v.Position, TotalReclaim = v.TotalReclaim, Distance=VDist2Sq(engPos[1], engPos[3], v.Position[1], v.Position[3])})
                    end
                end
                table.sort(reclaimOptions, function(a,b) return a.Distance < b.Distance end)
               --LOG('reclaimOptions table size is '..RNGGETN(reclaimOptions))
                for _, v in reclaimOptions do
                    if platoon.PlatoonData.Early and v.Distance > 14400 then
                       --RNGLOG('Early reclaim and its too far away lets go for something closer')
                        break
                    end
                    if GetThreatAtPosition( aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < 2 then
                        if AIAttackUtils.CanGraphToRNG(engPos, v.Position, 'Amphibious') then
                           --RNGLOG('Lets go to reclaim at '..repr(v))
                            validLocation = v.Position
                            break
                        elseif not platoon.PlatoonData.Early then
                           --RNGLOG('We want to go to this reclaim but cant graph to it, transport time? '..repr(v))
                            validLocation = v.Position
                            break
                        end
                    end
                end
                if validLocation then
                    --RNGLOG('We have a valid reclaim location')
                    IssueClearCommands({self})
                    if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, self, validLocation) then
                       --RNGLOG('We have issued move orders to get to the reclaim location')
                        if not self or self.Dead or not aiBrain:PlatoonExists(platoon) then
                            return
                        end
                        local engStuckCount = 0
                        local Lastdist
                        local dist
                        while not self.Dead and aiBrain:PlatoonExists(platoon) do
                            engPos = self:GetPosition()
                            dist = VDist2Sq(engPos[1], engPos[3], validLocation[1], validLocation[3])
                            if dist < 144 then
                               --RNGLOG('We are at the grid square location, dist is '..dist)
                                IssueClearCommands({self})
                                break
                            end
                            if Lastdist ~= dist then
                                engStuckCount = 0
                                Lastdist = dist
                            else
                                engStuckCount = engStuckCount + 1
                                --RNGLOG('* AI-RNG: * EngineerBuildAI: has no moved during move to build position look, adding one, current is '..engStuckCount)
                                if engStuckCount > 40 and not self:IsUnitState('Reclaiming') then
                                    --RNGLOG('* AI-RNG: * EngineerBuildAI: Stuck while moving to build position. Stuck='..engStuckCount)
                                    break
                                end
                            end
                            if self:IsUnitState("Moving") then
                                if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                                    local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                                    if enemyEngineer then
                                        local enemyEngPos
                                        for _, unit in enemyEngineer do
                                            if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                                enemyEngPos = unit:GetPosition()
                                                if VDist2Sq(engPos[1], engPos[3], enemyEngPos[1], enemyEngPos[3]) < 100 then
                                                    IssueStop({self})
                                                    IssueClearCommands({self})
                                                    IssueReclaim({self}, enemyEngineer[1])
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            coroutine.yield(30)
                        end
                        if not self or self.Dead or not aiBrain:PlatoonExists(platoon) then
                            coroutine.yield(1)
                            return
                        end
                        engPos = self:GetPosition()
                        -- reclaim grid for a better reclaim position 9 points with 1 being the current engineer position
                        -- we create a grid of 8 squares around the engineer that it will search after each grid square is reclaim it is removed.
                        local reclaimGrid = {
                            {engPos[1], 0 ,engPos[3]},
                            {engPos[1], 0 ,engPos[3] + 15},
                            {engPos[1] + 15, 0 ,engPos[3] + 15},
                            {engPos[1] + 15, 0, engPos[3]},
                            {engPos[1] + 15, 0, engPos[3] - 15},
                            {engPos[1], 0, engPos[3] - 15},
                            {engPos[1] - 15, 0, engPos[3] - 15},
                            {engPos[1] - 15, 0, engPos[3]},
                            {engPos[1] - 15, 0, engPos[3] + 15},
                            {engPos[1], 0 ,engPos[3] + 25},
                            {engPos[1] + 15, 0 ,engPos[3] + 25},
                            {engPos[1] + 25, 0 ,engPos[3] + 25},
                            {engPos[1] + 25, 0 ,engPos[3] + 15},
                            {engPos[1] + 25, 0, engPos[3]},
                            {engPos[1] + 25, 0, engPos[3] - 15},
                            {engPos[1] + 25, 0, engPos[3] - 25},
                            {engPos[1] + 15, 0, engPos[3] - 25},
                            {engPos[1], 0, engPos[3] - 25},
                            {engPos[1] - 15, 0, engPos[3] - 25},
                            {engPos[1] - 25, 0, engPos[3] - 25},
                            {engPos[1] - 25, 0, engPos[3] - 15},
                            {engPos[1] - 25, 0, engPos[3]},
                            {engPos[1] - 25, 0, engPos[3] + 15},
                            {engPos[1] - 15, 0, engPos[3] + 25},
                            {engPos[1] - 25, 0, engPos[3] + 25},
                        }
                        --LOG('EngineerReclaimGrid '..repr(reclaimGrid))
                        if reclaimGrid and RNGGETN( reclaimGrid ) > 0 then
                            --LOG('We are going to try reclaim within the grid')
                            local reclaimCount = 0
                            for k, square in reclaimGrid do
                                if square[1] - 8 <= 3 or square[1] + 8 >= ScenarioInfo.size[1] - 3 or square[3] - 8 <= 3 or square[3] + 8 >= ScenarioInfo.size[1] - 3 then
                                    --LOG('Grid square position outside of map border')
                                    continue
                                end
                                --LOG('reclaimGrid square table is '..repr(square))
                                local rectDef = Rect(square[1] - 8, square[3] - 8, square[1] + 8, square[3] + 8)
                                local reclaimRect = GetReclaimablesInRect(rectDef)
                                local engReclaiming = false
                                if reclaimRect then
                                    for c, b in reclaimRect do
                                        if not IsProp(b) or self.BadReclaimables[b] then continue end
                                        -- Start Blacklisted Props
                                        local blacklisted = false
                                        for _, BlackPos in PropBlacklist do
                                            if b.CachePosition[1] == BlackPos[1] and b.CachePosition[3] == BlackPos[3] then
                                                blacklisted = true
                                                break
                                            end
                                        end
                                        if blacklisted then continue end
                                        if b.MaxMassReclaim and b.MaxMassReclaim > 5 then
                                            engReclaiming = true
                                            reclaimCount = reclaimCount + 1
                                            IssueReclaim({self}, b)
                                        end
                                    end
                                end
                                if engReclaiming then
                                    local idleCounter = 0
                                    while not self.Dead and 0<RNGGETN(self:GetCommandQueue()) and aiBrain:PlatoonExists(platoon) do
                                        self:SetCustomName('Engineer in reclaim loop')
                                        if not self:IsUnitState('Reclaiming') and not self:IsUnitState('Moving') then
                                           --RNGLOG('We are not reclaiming or moving in the reclaim loop')
                                           --RNGLOG('But we still have '..RNGGETN(self:GetCommandQueue())..' Commands in the queue')
                                            idleCounter = idleCounter + 1
                                            if idleCounter > 15 then
                                               --RNGLOG('idleCounter hit, breaking loop')
                                                break
                                            end
                                        end
                                        --RNGLOG('We are reclaiming stuff')
                                        coroutine.yield(30)
                                    end
                                end
                                MexBuild(platoon, self, aiBrain)
                            end
                           --LOG('reclaim grid loop has finished')
                           --LOG('Total things that should have be issued reclaim are '..reclaimCount)
                        end
                    end
                else
                   --LOG('No valid reclaim options')
                end
            else
               --LOG('aiBrain MapReclaimTable does not exist')
            end
        end
        local furtherestReclaim = nil
        local closestReclaim = nil
        local closestDistance = 10000
        local furtherestDistance = 0
        local x1 = engPos[1] - initialRange
        local x2 = engPos[1] + initialRange
        local z1 = engPos[3] - initialRange
        local z2 = engPos[3] + initialRange
        local rect = Rect(x1, z1, x2, z2)
        local reclaimRect = {}
        reclaimRect = GetReclaimablesInRect(rect)
        if not engPos then
            coroutine.yield(1)
            return
        end

        local reclaim = {}
        local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
        --RNGLOG('* AI-RNG: Going through reclaim table')
        --self:SetCustomName('Loop through reclaim table')
        if reclaimRect and RNGGETN( reclaimRect ) > 0 then
            for k,v in reclaimRect do
                if not IsProp(v) or self.BadReclaimables[v] then continue end
                local rpos = v.CachePosition
                -- Start Blacklisted Props
                local blacklisted = false
                for _, BlackPos in PropBlacklist do
                    if rpos[1] == BlackPos[1] and rpos[3] == BlackPos[3] then
                        blacklisted = true
                        break
                    end
                end
                if blacklisted then continue end
                -- End Blacklisted Props
                if not needEnergy or v.MaxEnergyReclaim then
                    if v.MaxMassReclaim and v.MaxMassReclaim > minRec then
                        if not self.BadReclaimables[v] then
                            local distance = VDist2(engPos[1], engPos[3], v.CachePosition[1], v.CachePosition[3])
                            if distance < closestDistance then
                                closestReclaim = v.CachePosition
                                closestDistance = distance
                            end
                            if distance > furtherestDistance then -- and distance < closestDistance + 20
                                furtherestReclaim = v.CachePosition
                                furtherestDistance = distance
                            end
                            if furtherestDistance - closestDistance > 20 then
                                break
                            end
                        end
                    end
                end
            end
        else
            --self:SetCustomName('No reclaim, increase 100 from '..initialRange)
            initialRange = initialRange + 100
            --RNGLOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 300 then
                --RNGLOG('* AI-RNG: Reclaim range > 300, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                coroutine.yield(1)
                return
            end
            coroutine.yield(2)
            continue
        end
        if closestDistance == 10000 then
            --self:SetCustomName('closestDistance return 10000')
            initialRange = initialRange + 100
            --RNGLOG('* AI-RNG: initialRange is'..initialRange)
            if initialRange > 200 then
                --RNGLOG('* AI-RNG: Reclaim range > 200, Disabling Reclaim.')
                PropBlacklist = {}
                aiBrain.ReclaimEnabled = false
                aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                coroutine.yield(1)
                return
            end
            coroutine.yield(2)
            continue
        end
        if self.Dead then 
            return
        end
        --RNGLOG('* AI-RNG: Closest Distance is : '..closestDistance..'Furtherest Distance is :'..furtherestDistance)
        -- Clear Commands first
        IssueClearCommands({self})
        --RNGLOG('* AI-RNG: Attempting move to closest reclaim')
        --RNGLOG('* AI-RNG: Closest reclaim is '..repr(closestReclaim))
        if not closestReclaim then
            --self:SetCustomName('no closestDistance')
            coroutine.yield(2)
            return
        end
        if self.lastXtarget == closestReclaim[1] and self.lastYtarget == closestReclaim[3] then
            --self:SetCustomName('blocked reclaim')
            self.blocked = self.blocked + 1
            --RNGLOG('* AI-RNG: Reclaim Blocked + 1 :'..self.blocked)
            if self.blocked > 3 then
                self.blocked = 0
                table.insert (PropBlacklist, closestReclaim)
                --RNGLOG('* AI-RNG: Reclaim Added to blacklist')
            end
        else
            self.blocked = 0
            self.lastXtarget = closestReclaim[1]
            self.lastYtarget = closestReclaim[3]
            StartMoveDestination(self, closestReclaim)
        end

        --RNGLOG('* AI-RNG: Attempting agressive move to furtherest reclaim')
        -- Clear Commands first
        --self:SetCustomName('Aggressive move to reclaim')
        IssueClearCommands({self})
        IssueAggressiveMove({self}, furtherestReclaim)
        local reclaiming = not self:IsIdleState()
        local max_time = platoon.PlatoonData.ReclaimTime
        local currentTime = 0
        local idleCount = 0
        while reclaiming do
            --RNGLOG('* AI-RNG: Engineer is reclaiming')
            --self:SetCustomName('reclaim loop start')
            coroutine.yield(100)
            currentTime = currentTime + 10
            if currentTime > max_time then
                reclaiming = false
            end
            if self:IsIdleState() then
                idleCount = idleCount + 1
                if idleCount > 5 then
                    reclaiming = false
                end
            end
            MexBuild(platoon, self, aiBrain)
            --self:SetCustomName('reclaim loop end')
        end
        local basePosition = aiBrain.BuilderManagers['MAIN'].Position
        local location = AIUtils.RandomLocation(basePosition[1],basePosition[3])
        --RNGLOG('* AI-RNG: basePosition random location :'..repr(location))
        IssueClearCommands({self})
        StartMoveDestination(self, location)
        coroutine.yield(30)
        --self:SetCustomName('moving back to base')
        reclaimLoop = reclaimLoop + 1
        if reclaimLoop == 5 then
            --RNGLOG('* AI-RNG: reclaimLopp = 5 returning')
            coroutine.yield(1)
            return
        end
        --self:SetCustomName('end of reclaim function')
        coroutine.yield(5)
    end
end

function StartMoveDestination(self,destination)
    local NowPosition = self:GetPosition()
    local x, z, y = unpack(self:GetPosition())
    local count = 0
    IssueClearCommands({self})
    while x == NowPosition[1] and y == NowPosition[3] and count < 20 do
        count = count + 1
        IssueClearCommands({self})
        IssueMove( {self}, destination )
        coroutine.yield(10)
    end
end
-- Get the military operational areas of the map. Credit to Uveso, this is based on his zones but a little more for small map sizes.
function GetMOARadii(bool)
    -- Military area is slightly less than half the map size (10x10map) or maximal 200.
    local BaseMilitaryArea = math.max( ScenarioInfo.size[1]-50, ScenarioInfo.size[2]-50 ) / 2.2
    BaseMilitaryArea = math.max( 180, BaseMilitaryArea )
    -- DMZ is half the map. Mainly used for air formers
    local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
    -- Restricted Area is half the BaseMilitaryArea. That's a little less than 1/4 of a 10x10 map
    local BaseRestrictedArea = BaseMilitaryArea / 2
    -- Make sure the Restricted Area is not smaller than 50 or greater than 100
    BaseRestrictedArea = math.max( 60, BaseRestrictedArea )
    BaseRestrictedArea = math.min( 120, BaseRestrictedArea )
    -- The rest of the map is enemy area
    local BaseEnemyArea = math.max( ScenarioInfo.size[1], ScenarioInfo.size[2] ) * 1.5
    -- "bool" is only true if called from "AIBuilders/Mobile Land.lua", so we only print this once.
    if bool then
        --RNGLOG('* RNGAI: BaseRestrictedArea= '..math.floor( BaseRestrictedArea * 0.01953125 ) ..' Km - ('..BaseRestrictedArea..' units)' )
        --RNGLOG('* RNGAI: BaseMilitaryArea= '..math.floor( BaseMilitaryArea * 0.01953125 )..' Km - ('..BaseMilitaryArea..' units)' )
        --RNGLOG('* RNGAI: BaseDMZArea= '..math.floor( BaseDMZArea * 0.01953125 )..' Km - ('..BaseDMZArea..' units)' )
        --RNGLOG('* RNGAI: BaseEnemyArea= '..math.floor( BaseEnemyArea * 0.01953125 )..' Km - ('..BaseEnemyArea..' units)' )
    end
    return BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea
end

function EngineerTryReclaimCaptureArea(aiBrain, eng, pos, pointRadius)
    if not pos then
        return false
    end
    if not pointRadius then
        pointRadius = 10
    end
    local Reclaiming = false
    --Temporary for troubleshooting
    --local GetBlueprint = moho.entity_methods.GetBlueprint
    -- Check if enemy units are at location
    local checkUnits = GetUnitsAroundPoint(aiBrain, (categories.STRUCTURE + categories.MOBILE) - categories.AIR, pos, pointRadius, 'Enemy')
    -- reclaim units near our building place.
    if checkUnits and RNGGETN(checkUnits) > 0 then
        for num, unit in checkUnits do
            --temporary for troubleshooting
            --unitdesc = GetBlueprint(unit).Description
            if unit.Dead or unit:BeenDestroyed() then
                continue
            end
            if not IsEnemy( aiBrain:GetArmyIndex(), unit:GetAIBrain():GetArmyIndex() ) then
                continue
            end
            if unit:IsCapturable() and not EntityCategoryContains(categories.TECH1 * (categories.MOBILE + categories.WALL), unit) and unit:GetFractionComplete() == 1 then 
                --RNGLOG('* AI-RNG: Unit is capturable and not category t1 mobile'..unitdesc)
                -- if we can capture the unit/building then do so
                unit.CaptureInProgress = true
                IssueCapture({eng}, unit)
            else
                --RNGLOG('* AI-RNG: We are going to reclaim the unit'..unitdesc)
                -- if we can't capture then reclaim
                unit.ReclaimInProgress = true
                IssueReclaim({eng}, unit)
            end
        end
        Reclaiming = true
    end
    -- reclaim rocks etc or we can't build mexes or hydros
    local Reclaimables = GetReclaimablesInRect(Rect(pos[1], pos[3], pos[1], pos[3]))
    if Reclaimables and RNGGETN( Reclaimables ) > 0 then
        for k,v in Reclaimables do
            if v.MaxMassReclaim and v.MaxMassReclaim > 5 or v.MaxEnergyReclaim and v.MaxEnergyReclaim > 5 then
                IssueReclaim({eng}, v)
            end
        end
    end
    return Reclaiming
end



function EngineerTryRepair(aiBrain, eng, whatToBuild, pos)
    if not pos then
        return false
    end

    local structureCat = ParseEntityCategory(whatToBuild)
    local checkUnits = GetUnitsAroundPoint(aiBrain, structureCat, pos, 1, 'Ally')
    if checkUnits and RNGGETN(checkUnits) > 0 then
        for num, unit in checkUnits do
            IssueRepair({eng}, unit)
        end
        return true
    end

    return false
end

function AIFindUnmarkedExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Unmarked Expansion', pos, radius, tMin, tMax, tRings, tType)
    --RNGLOG('Valid Unmarked Expansion Markers '..repr(validPos))

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindLargeExpansionMarkerNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Large Expansion Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindStartLocationNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end

    local validPos = {}

    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Blank Marker', pos, radius, tMin, tMax, tRings, tType)
    local startX, startZ = aiBrain:GetArmyStartPos()
    for _, v in positions do
        if string.sub(v.Name, 1, 5) == 'ARMY_' then
            if startX ~= v.Position[1] and startZ ~= v.Position[3] then
                table.insert(validPos, v)
            end
        end
    end
    --RNGLOG('Valid Pos table '..repr(validPos))

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, validPos)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerThreatRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, validPos)
    end

    return retPos, retName
end

function AIFindExpansionAreaNeedsEngineerRNG(aiBrain, locationType, radius, tMin, tMax, tRings, tType, eng)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    if not pos then
        return false
    end
    local positions = AIUtils.AIGetMarkersAroundLocationRNG(aiBrain, 'Expansion Area', pos, radius, tMin, tMax, tRings, tType)

    local retPos, retName
    if eng then
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, eng:GetPosition(), radius, tMin, tMax, tRings, tType, positions)
    else
        retPos, retName = AIUtils.AIFindMarkerNeedsEngineerRNG(aiBrain, pos, radius, tMin, tMax, tRings, tType, positions)
    end

    return retPos, retName
end

function AIGetMassMarkerLocations(aiBrain, includeWater, waterOnly)
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            if waterOnly then
                if v.Water then
                    table.insert(markerList, {Position = v.position, Name = k})
                end
            elseif includeWater then
                table.insert(markerList, {Position = v.position, Name = k})
            else
                if not v.Water then
                    table.insert(markerList, {Position = v.position, Name = k})
                end
            end
        end
    end
    return markerList
end

-- This is Sproutos function 
function PositionInWater(pos)
	return GetTerrainHeight(pos[1], pos[3]) < GetSurfaceHeight(pos[1], pos[3])
end

function GetClosestMassMarkerToPos(aiBrain, pos)
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
        for k, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                table.insert(markerList, {Position = v.position, Name = k})
            end
        end
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(pos[1], pos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            --RNGLOG('Can build at position '..repr(v.Position))
            loc = v.Position
            name = v.Name
            lowest = distance
        else
            --RNGLOG('Cant build at position '..repr(v.Position))
        end
    end

    return loc, name
end

function GetClosestMassMarker(aiBrain, unit)
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerList = {}
    for k, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            table.insert(markerList, {Position = v.position, Name = k})
        end
    end

    local engPos = unit:GetPosition()
    local loc, distance, lowest, name = nil

    for _, v in markerList do
        local x = v.Position[1]
        local y = v.Position[2]
        local z = v.Position[3]
        distance = VDist2Sq(engPos[1], engPos[3], x, z)
        if (not lowest or distance < lowest) and CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            loc = v.Position
            name = v.Name
            lowest = distance
        end
    end

    return loc, name
end

function GetLastACUPosition(aiBrain, enemyIndex)
    local acuPos = {}
    local lastSpotted = 0
    if aiBrain.EnemyIntel.ACU then
        for k, v in aiBrain.EnemyIntel.ACU do
            if k == enemyIndex then
                acuPos = v.Position
                lastSpotted = v.LastSpotted
                --RNGLOG('* AI-RNG: acuPos has data')
            else
                --RNGLOG('* AI-RNG: acuPos is currently false')
            end
        --[[if aiBrain.EnemyIntel.ACU[enemyIndex] == enemyIndex then
            acuPos = aiBrain.EnemyIntel.ACU[enemyIndex].ACUPosition
            lastSpotted = aiBrain.EnemyIntel.ACU[enemyIndex].LastSpotted
            --RNGLOG('* AI-RNG: acuPos has data')
        else
            --RNGLOG('* AI-RNG: acuPos is currently false')
        end]]
        end
    end
    return acuPos, lastSpotted
end


function lerpy(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, distance - weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    local distanceFrac = distance[2] / distance[1]
    local x = vec1[1] * (1 - distanceFrac) + vec2[1] * distanceFrac
    local y = vec1[2] * (1 - distanceFrac) + vec2[2] * distanceFrac
    local z = vec1[3] * (1 - distanceFrac) + vec2[3] * distanceFrac
    return {x,y,z}
end

function LerpyRotate(vec1, vec2, distance)
    -- Courtesy of chp2001
    -- note the distance param is {distance, weapon range}
    -- vec1 is friendly unit, vec2 is enemy unit
    -- Had to add more documentation cause I suck at maths
    -- distance[1] is the degrees from vec2 e.g 90 is right, -90 is left
    -- distance[2] is the distance from vec2
    -- So for say acu support, vec1 is the enemy position, vec2 is the acu position, distance[1] is degrees right or left.
    -- then distance[2] is how far from the acu they will stand
    -- Actually thats still not right, I dont fully understand what distance[1] does, yea I know just learn vectors
    local distanceFrac = distance[2] / distance[1]
    local z = vec2[3] + distanceFrac * (vec2[1] - vec1[1])
    local y = vec2[2] - distanceFrac * (vec2[2] - vec1[2])
    local x = vec2[1] - distanceFrac * (vec2[3] - vec1[3])
    return {x,y,z}
end

-- This is softles, I was curious to see what it looked like compared to lerpy. Used in scouts avoiding enemy tanks.
function AvoidLocation(pos,target,dist)
    if not target then
        return pos
    elseif not pos then
        return target
    end
    local delta = VDiff(target,pos)
    local norm = math.max(VDist2(delta[1],delta[3],0,0),1)
    local x = pos[1]+dist*delta[1]/norm
    local z = pos[3]+dist*delta[3]/norm
    x = math.min(ScenarioInfo.size[1]-5,math.max(5,x))
    z = math.min(ScenarioInfo.size[2]-5,math.max(5,z))
    return {x,GetSurfaceHeight(x,z),z}
end

function CheckCustomPlatoons(aiBrain)
    if not aiBrain.StructurePool then
        --RNGLOG('* AI-RNG: Creating Structure Pool Platoon')
        local structurepool = aiBrain:MakePlatoon('StructurePool', 'none')
        structurepool:UniquelyNamePlatoon('StructurePool')
        structurepool.BuilderName = 'Structure Pool'
        aiBrain.StructurePool = structurepool
    end
end

function AIFindBrainTargetInRangeOrigRNG(aiBrain, position, platoon, squad, maxRange, atkPri, enemyBrain)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    if not aiBrain or not position or not maxRange or not platoon or not enemyBrain then
        return false
    end
    local VDist2 = VDist2
    local RangeList = { [1] = maxRange }
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [3] = 384,
            [4] = 512,
            [5] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [4] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    local enemyIndex = enemyBrain:GetArmyIndex()
    for _, range in RangeList do
        local targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, position, maxRange, 'Enemy')
        for _, v in atkPri do
            local category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local distance = false
            for num, unit in targetUnits do
                if not unit.Dead and not unit.CaptureInProgress and EntityCategoryContains(category, unit) and unit:GetAIBrain():GetArmyIndex() == enemyIndex and platoon:CanAttackTarget(squad, unit) then
                    local unitPos = unit:GetPosition()
                    if not retUnit or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                        retUnit = unit
                        distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    end
                end
            end
            if retUnit then
                return retUnit
            end
        end
    end

    return false
end

function InitialMassMarkersInWater(aiBrain)
    if RNGGETN(AIGetMassMarkerLocations(aiBrain, false, true)) > 0 then
        return true
    else
        return false
    end
end

function PositionOnWater(positionX, positionZ)
    --Check if a position is under water. Used to identify if threat/unit position is over water
    -- Terrain >= Surface = Target is on land
    -- Terrain < Surface = Target is in water
    if positionX and positionZ then
        return GetTerrainHeight( positionX, positionZ ) < GetSurfaceHeight( positionX, positionZ )
    end
    return false
end

function ManualBuildStructure(aiBrain, eng, structureType, tech, position)
    -- Usage ManualBuildStructure(aiBrain, engineerunit, 'AntiSurface', 'TECH2', {123:20:123})
    local factionIndex = aiBrain:GetFactionIndex()
    -- 1: UEF, 2: Aeon, 3: Cybran, 4: Seraphim, 5: Nomads
    DefenseTable = {
        { 
        AntiAir = {
            TECH1 = 'ueb2104',
            TECH2 = 'ueb2204',
            TECH3 = 'ueb2304'
            },
        AntiSurface = {
            TECH1 = 'ueb2101',
            TECH2 = 'ueb2301',
            TECH3 = 'xeb2306'
            },
        AntiNaval = {
            TECH1 = 'ueb2109',
            TECH2 = 'ueb2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'uab2104',
            TECH2 = 'uab2204',
            TECH3 = 'uab2304'
            },
        AntiSurface = {
            TECH1 = 'uab2101',
            TECH2 = 'uab2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'uab2109',
            TECH2 = 'uab2205',
            TECH3 = ''
            }
        },
        {
        AntiAir = {
            TECH1 = 'urb2104',
            TECH2 = 'urb2204',
            TECH3 = 'urb2304'
            },
        AntiSurface = {
            TECH1 = 'urb2101',
            TECH2 = 'urb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'urb2109',
            TECH2 = 'urb2205',
            TECH3 = 'xrb2308'
            }
        },
        {
        AntiAir = {
            TECH1 = 'xsb2104',
            TECH2 = 'xsb2204',
            TECH3 = 'xsb2304'
            },
        AntiSurface = {
            TECH1 = 'xsb2101',
            TECH2 = 'xsb2301',
            TECH3 = ''
            },
        AntiNaval = {
            TECH1 = 'xsb2109',
            TECH2 = 'xsb2205',
            TECH3 = ''
            }
        }
    }
    local blueprintID = DefenseTable[factionIndex][structureType][tech]
    if CanBuildStructureAt(aiBrain, blueprintID, position) then
        IssueStop({eng})
        IssueClearCommands({eng})
        aiBrain:BuildStructure(eng, blueprintID, position, false)
    end
end

function TacticalMassLocations(aiBrain)
    -- Scans the map and trys to figure out tactical locations with multiple mass markers
    -- markerLocations will be returned in the table full of these tables { Name="Mass7", Position={ 189.5, 24.240200042725, 319.5, type="VECTOR3" } }

    --RNGLOG('* AI-RNG: * Starting Tactical Mass Location Function')
    local markerGroups = {}
    local markerLocations = AIGetMassMarkerLocations(aiBrain, false, false)
    if markerLocations then
        aiBrain.BrainIntel.MassMarker = RNGGETN(markerLocations)
    end
    local group = 1
    local duplicateMarker = {}
    -- loop thru all the markers --
    for key_1, marker_1 in markerLocations do
        -- only process a marker that has not already been used
            local groupSet = {MarkerGroup=group, Markers={}}
            -- loop thru all the markers --
            for key_2, marker_2 in markerLocations do
                -- bypass any marker that's already been used
                if VDist2Sq(marker_1.Position[1], marker_1.Position[3], marker_2.Position[1], marker_2.Position[3]) < 1600 then
                    -- insert marker into group --
                    table.insert(groupSet['Markers'], marker_2)
                    markerLocations[key_2] = nil
                end
            end
            markerLocations[key_1] = nil
            if RNGGETN(groupSet['Markers']) > 2 then
                table.insert(markerGroups, groupSet)
                --RNGLOG('Group Set Markers :'..repr(groupSet))
                group = group + 1
            end
    end
    --RNGLOG('End Marker Groups :'..repr(markerGroups))
    aiBrain.TacticalMonitor.TacticalMassLocations = markerGroups
    --RNGLOG('* AI-RNG: * Marker Groups :'..repr(aiBrain.TacticalMonitor.TacticalMassLocations))
end

function MarkTacticalMassLocations(aiBrain)
--[[ Gets tactical mass locations and sets markers on ones with no existing expansion markers
    'Air Path Node',
    'Amphibious Path Node',
    'Blank Marker',
    'Camera Info',
    'Combat Zone',
    'Defensive Point',
    'Effect',
    'Expansion Area',
    'Hydrocarbon',
    'Island',
    'Land Path Node',
    'Large Expansion Area',
    'Mass',
    'Naval Area',
    'Naval Defensive Point',
    'Naval Exclude',
    'Naval Link',
    'Naval Rally Point',
    'Protected Experimental Construction',
    'Rally Point',
    'Transport Marker',
    'Water Path Node',
    'Weather Definition',
    'Weather Generator',]]

    local massGroups = aiBrain.TacticalMonitor.TacticalMassLocations
    local expansionMarkers = Scenario.MasterChain._MASTERCHAIN_.Markers
    local markerList = {}
    --RNGLOG('Pre Sorted MassGroups'..repr(massGroups))
    if massGroups then
        if expansionMarkers then
            for k, v in expansionMarkers do
                if v.type == 'Expansion Area' or v.type == 'Large Expansion Area' then
                    table.insert(markerList, {Position = v.position})
                end
            end
        end
        for i = 1, 16 do
            if Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i] then
                table.insert(markerList, {Position = Scenario.MasterChain._MASTERCHAIN_.Markers['ARMY_'..i].position})
            end
        end
        for key, group in massGroups do
            for key2, marker in markerList do
                if VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]) < 3600 then
                    --RNGLOG('Location :'..repr(group.Markers[1])..' is less than 3600 from :'..repr(marker))
                    massGroups[key] = nil
                else
                    --RNGLOG('Location :'..repr(group.Markers[1])..' is more than 3600 from :'..repr(marker))
                    --RNGLOG('Location distance :'..VDist2Sq(group.Markers[1].Position[1], group.Markers[1].Position[3], marker.Position[1], marker.Position[3]))
                end
            end
        end
        aiBrain:RebuildTable(massGroups)
    end
    aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups = massGroups
    --RNGLOG('* AI-RNG: * Total Expansion, Large expansion markers'..repr(markerList))
    --RNGLOG('* AI-RNG: * Unmarked Mass Groups'..repr(massGroups))
end

function GenerateMassGroupMarkerLocations(aiBrain)
    -- Will generate locations for markers on the center point for each unmarked mass group
    local markerGroups = aiBrain.TacticalMonitor.TacticalUnmarkedMassGroups
    local newMarkerLocations = {}
    if RNGGETN(markerGroups) > 0 then
        for key, group in markerGroups do
            local position = MassGroupCenter(group)
            table.insert(newMarkerLocations, position)
            --RNGLOG('Position for new marker is :'..repr(position))
        end
        --RNGLOG('Completed New marker positions :'..repr(newMarkerLocations))
        return newMarkerLocations
    end
    return false
end

function CreateMarkers(markerType, newMarkers)
-- markerType = string e.g "Marker Area"
-- newMarkers = a table of new marker positions e.g {{123,12,123}}
--[[    
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Expansion Area' then
            if string.find(k, 'ExpansionArea') then
                WARN('* AI-RNG: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            elseif not string.find(k, 'Expansion Area') then
                WARN('* AI-RNG: ValidateMapAndMarkers: MarkerType: [\''..v.type..'\'] Has wrong Index Name ['..k..']. (Should be [Expansion Area xx]!!!)')
            end
        end
    end
]]
    --RNGLOG('Marker Dump'..repr(Scenario.MasterChain._MASTERCHAIN_.Markers))
    for index, markerPosition in newMarkers do    
        --RNGLOG('markerType is : '..markerType..' Index is : '..index)
        --local markerName = markerType..' '..index
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index] = { }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].color = 'ff000000'
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].hint = true
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].orientation = { 0, 0, 0 }
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].prop = "/env/common/props/markers/M_Expansion_prop.bp"
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].type = markerType
        Scenario.MasterChain._MASTERCHAIN_.Markers[markerType..' '..index].position = markerPosition
    end
    for k, v in Scenario.MasterChain._MASTERCHAIN_.Markers do
        if v.type == 'Unmarked Expansion' then
            --RNGLOG('Unmarked Expansion Marker at :'..repr(v.position))
        end
    end
end

function GeneratePointsAroundPosition(position,radius,num)
    -- Courtesy of chp2001
    -- position = { 233.5, 25.239820480347, 464.5, type="VECTOR3" }
    -- radius = the size of the circle
    -- num = the number of points around the circle

    local nnn=0
    local coords = {}
    while nnn < num do
        local xxx = 0
        local zzz = 0
        xxx = position[1] + radius * math.cos (nnn/num* (2 * math.pi))
        zzz = position[3] + radius * math.sin (nnn/num* (2 * math.pi))
        table.insert(coords, {xxx, zzz})
        nnn = nnn + 1
        coroutine.yield(1)
    end
    return coords
end


function MassGroupCenter(massGroup)
    -- Courtesy of chp2001
    -- takes a group of mass marker positions and will return the center point
    -- Mark Group definition = {MarkerGroup=1,Markers={{ Name="Mass 20", Position={ 159.5, 10.000610351563, 418.5, type="VECTOR3" }}}
    local xx1=0
    local yy1=0
    local zz1=0
    local nn1=0
    for key_1, marker_1 in massGroup.Markers do
        xx1=xx1+marker_1.Position[1]
        yy1=yy1+marker_1.Position[2]
        zz1=zz1+marker_1.Position[3]
        nn1=nn1 + 1
    end
    return {xx1/nn1,yy1/nn1,zz1/nn1}
end

function SetArcPoints(position,enemyPosition,radius,num,arclength)
    -- Courtesy of chp2001
    -- position = engineer position
    -- enemyPosition = base or assault point
    -- radius = distance from the enemyPosition
    -- num = number of points along the arc. Must be greater than 1.
    -- arclength - length of the arc in game units
    -- The radius impacts how large the arclength will be, the arclength has a maximum of around 32
    -- so to increase the width of the arc you also need to increase the radius.
    -- Example set
    -- local arcenemyBase = { 360.5, 10, 365.5, type="VECTOR3" }
    -- local arcengineer = { 233.5, 10, 386.5, type="VECTOR3" }
    -- RUtils.SetArcPoints(arcengineer, arcenemyBase, 80, 3, 30)

    local nnn=0
    local num1 = num-1
    local coords = {}
    local distvec = {position[1]-enemyPosition[1],position[3]-enemyPosition[3]}
    local angoffset = math.atan2(distvec[2],distvec[1])
    local arcangle = arclength/radius
    while nnn <= num1 do
        local xxx = 0
        local zzz = 0
        xxx = enemyPosition[1] + radius * math.cos (nnn/num1* (arcangle)+angoffset-arcangle/2)
        zzz = enemyPosition[3] + radius * math.sin (nnn/num1* (arcangle)+angoffset-arcangle/2)
        table.insert(coords, {xxx,0,zzz})
        nnn = nnn + 1
        coroutine.yield(1)
    end
    --RNGLOG('Resulting Table :'..repr(coords))
    return coords
end

function AIFindBrainTargetInRangeRNG(aiBrain, position, platoon, squad, maxRange, atkPri, avoidbases, platoonThreat, index, ignoreCivilian)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    local VDist2 = VDist2
    if platoon.PlatoonData.GetTargetsFromBase then
        --RNGLOG('Looking for targets from position '..platoon.PlatoonData.LocationType)
        position = aiBrain.BuilderManagers[platoon.PlatoonData.LocationType].Position
    end
    local enemyThreat, targetUnits, category
    local RangeList = { [1] = maxRange }
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not avoidbases then
        avoidbases = false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [3] = 384,
            [4] = 512,
            [5] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [4] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end

    for _, range in RangeList do
        targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, position, range, 'Enemy')
        for _, v in atkPri do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            local retUnit = false
            local distance = false
            local targetShields = 9999
            for num, unit in targetUnits do
                if index then
                    for k, v in index do
                        if unit:GetAIBrain():GetArmyIndex() == v then
                            if not unit.Dead and not unit.CaptureInProgress and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                                local unitPos = unit:GetPosition()
                                if not retUnit or VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance then
                                    retUnit = unit
                                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                                end
                                if platoon.MovementLayer == 'Air' and platoonThreat then
                                    enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                                    --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                                    if enemyThreat > platoonThreat then
                                        continue
                                    end
                                end
                                local numShields = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                                if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                                    retUnit = unit
                                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                                    targetShields = numShields
                                end
                            end
                        end
                    end
                else
                    if not unit.Dead and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                        if ignoreCivilian then
                            if ArmyIsCivilian(unit:GetArmy()) then
                                --RNGLOG('Unit is civilian')
                                continue
                            end
                        end
                        local unitPos = unit:GetPosition()
                        if avoidbases then
                            for _, w in ArmyBrains do
                                if IsEnemy(w:GetArmyIndex(), aiBrain:GetArmyIndex()) or (aiBrain:GetArmyIndex() == w:GetArmyIndex()) then
                                    local estartX, estartZ = w:GetArmyStartPos()
                                    if VDist2Sq(estartX, estartZ, unitPos[1], unitPos[3]) < 22500 then
                                        continue
                                    end
                                end
                            end
                        end
                        if platoon.MovementLayer == 'Air' and platoonThreat then
                            enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                            --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                            if enemyThreat > platoonThreat then
                                continue
                            end
                        end
                        local numShields = aiBrain:GetNumUnitsAroundPoint(categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                        if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                end
            end
            if retUnit and targetShields > 0 then
                local platoonUnits = platoon:GetPlatoonUnits()
                for _, w in platoonUnits do
                    if not w.Dead then
                        unit = w
                        break
                    end
                end
                local closestBlockingShield, shieldHealth = GetClosestShieldProtectingTargetRNG(unit, retUnit)
                if closestBlockingShield then
                    return closestBlockingShield, shieldHealth
                end
            end
            if retUnit then
                return retUnit
            end
        end
        coroutine.yield(2)
    end
    return false
end

function AIFindBrainTargetInACURangeRNG(aiBrain, position, platoon, squad, maxRange, atkPri, platoonThreat, ignoreCivilian)
    if not position then
        position = platoon:GetPlatoonPosition()
    end
    local VDist2 = VDist2
    local enemyThreat, targetUnits, category
    local RangeList = { [1] = maxRange }
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    
    if maxRange > 512 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [3] = 384,
            [4] = 512,
            [5] = maxRange,
        }
    elseif maxRange > 256 then
        RangeList = {
            [1] = 30,
            [1] = 64,
            [2] = 128,
            [2] = 192,
            [3] = 256,
            [4] = maxRange,
        }
    elseif maxRange > 64 then
        RangeList = {
            [1] = 30,
            [2] = maxRange,
        }
    end
    local acuUnit = false
    local SquadTargetList = {
        Attack = {
            Unit = false,
            Distance = false
        },
        Artillery = {
            Unit = false,
            Distance = false
        }
    }

    for _, range in RangeList do
        targetUnits = GetUnitsAroundPoint(aiBrain, categories.ALLUNITS, position, range, 'Enemy')
        for _, category in atkPri do
            local retUnit = false
            local distance = false
            local targetShields = 9999
            for num, unit in targetUnits do
                if not unit.Dead and EntityCategoryContains(category, unit) and platoon:CanAttackTarget(squad, unit) then
                    if ignoreCivilian then
                        if ArmyIsCivilian(unit:GetArmy()) then
                            --RNGLOG('Unit is civilian')
                            continue
                        end
                    end
                    local unitPos = unit:GetPosition()
                    if platoon.MovementLayer == 'Air' and platoonThreat then
                        enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                        --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                        if enemyThreat > platoonThreat then
                            continue
                        end
                    end
                    if EntityCategoryContains(categories.COMMAND, unit) then
                        acuUnit = unit

                    end
                    local unitDistance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    if EntityCategoryContains(categories.MOBILE, unit) then
                        if not SquadTargetList.Attack.Unit or unitDistance < SquadTargetList.Attack.Distance then
                            SquadTargetList.Attack.Unit = unit
                            SquadTargetList.Attack.Distance = unitDistance
                        end
                    elseif EntityCategoryContains(categories.STRUCTURE, unit) then
                        if not SquadTargetList.Artillery.Unit or unitDistance < SquadTargetList.Artillery.Distance then
                            SquadTargetList.Artillery.Unit = unit
                            SquadTargetList.Artillery.Distance = unitDistance
                        end
                    end
                end
            end
            if SquadTargetList.Attack.Unit or SquadTargetList.Artillery.Unit then
                return SquadTargetList, acuUnit
            end
        end
        coroutine.yield(2)
    end
    return false
end

function AIFindACUTargetInRangeRNG(aiBrain, platoon, position, squad, maxRange, platoonThreat, index)
    local VDist2 = VDist2
    local enemyThreat
    if not aiBrain or not position or not maxRange then
        return false
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    local targetUnits = GetUnitsAroundPoint(aiBrain, categories.COMMAND, position, maxRange, 'Enemy')
    local retUnit = false
    local distance = false
    local targetShields = 9999
    for num, unit in targetUnits do
        if index then
            for k, v in index do
                if unit:GetAIBrain():GetArmyIndex() == v then
                    if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) then
                        local unitPos = unit:GetPosition()
                        local unitArmyIndex = unit:GetArmy()
        
                        --[[if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                            continue
                        end]]
                        if platoon.MovementLayer == 'Air' and platoonThreat then
                            enemyThreat = GetThreatAtPosition( aiBrain, unitPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'AntiAir')
                            --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                            if enemyThreat > platoonThreat then
                                continue
                            end
                        end
                        local numShields = GetNumUnitsAroundPoint(aiBrain, categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                        if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                            retUnit = unit
                            distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                            targetShields = numShields
                        end
                    end
                end
            end
        else
            if not unit.Dead and EntityCategoryContains(categories.COMMAND, unit) and platoon:CanAttackTarget(squad, unit) then
                local unitPos = unit:GetPosition()
                local unitArmyIndex = unit:GetArmy()

                if not aiBrain.EnemyIntel.ACU[unitArmyIndex].OnField then
                    continue
                end
                if platoon.MovementLayer == 'Air' and platoonThreat then
                    enemyThreat = GetThreatAtPosition( aiBrain, unitPos, 0, true, 'AntiAir')
                    --RNGLOG('Enemy Threat is '..enemyThreat..' and my threat is '..platoonThreat)
                    if enemyThreat > platoonThreat then
                        continue
                    end
                end
                local numShields = GetNumUnitsAroundPoint(aiBrain, categories.DEFENSE * categories.SHIELD * categories.STRUCTURE, unitPos, 46, 'Enemy')
                if not retUnit or numShields < targetShields or (numShields == targetShields and VDist2Sq(position[1], position[3], unitPos[1], unitPos[3]) < distance) then
                    retUnit = unit
                    distance = VDist2Sq(position[1], position[3], unitPos[1], unitPos[3])
                    targetShields = numShields
                end
            end
        end
    end
    if retUnit and targetShields > 0 then
        local platoonUnits = platoon:GetPlatoonUnits()
        for _, w in platoonUnits do
            if not w.Dead then
                unit = w
                break
            end
        end
        local closestBlockingShield, shieldHealth = GetClosestShieldProtectingTargetRNG(unit, retUnit)
        if closestBlockingShield then
            return closestBlockingShield, shieldHealth
        end
    end
    if retUnit then
        return retUnit
    end

    return false
end

function AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, position, squad, maxRange, targetQueryCategory, TargetSearchCategory, enemyBrain)
    local ALLBPS = ALLBPS
    if type(TargetSearchCategory) == 'string' then
        TargetSearchCategory = ParseEntityCategory(TargetSearchCategory)
    end
    local enemyIndex = false
    local VDist2 = VDist2
    local MyArmyIndex = aiBrain:GetArmyIndex()
    if enemyBrain then
        enemyIndex = enemyBrain:GetArmyIndex()
    end
    local acuPresent = false
    local acuUnit = false
    local defenseRange = 0
    local unitThreatTable = {}
    local totalThreat = 0
    local RangeList = {
        [1] = 10,
        [2] = maxRange,
        [3] = maxRange + 30,
    }
    local TargetUnit = false
    local TargetsInRange, TargetPosition, category, distance, targetRange, baseTargetRange, canAttack
    for _, range in RangeList do
        if not position then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: position is empty')
            return false
        end
        if not range then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: range is empty')
            return false
        end
        if not TargetSearchCategory then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: TargetSearchCategory is empty')
            return false
        end
        TargetsInRange = GetUnitsAroundPoint(aiBrain, targetQueryCategory, position, range, 'Enemy')
        --DrawCircle(position, range, '0000FF')
        for _, v in TargetSearchCategory do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            distance = maxRange * maxRange
            --RNGLOG('* AIFindNearestCategoryTargetInRange: numTargets '..RNGGETN(TargetsInRange)..'  ')
            for num, Target in TargetsInRange do
                if Target.Dead or Target:BeenDestroyed() then
                    continue
                end
                if Target.Sync.id and not unitThreatTable[Target.Sync.id] then
                    if platoon.MovementLayer == 'Water' then
                        totalThreat = totalThreat + ALLBPS[Target.UnitId].Defense.SurfaceThreatLevel + ALLBPS[Target.UnitId].Defense.SubThreatLevel
                    else
                        totalThreat = totalThreat + ALLBPS[Target.UnitId].Defense.SurfaceThreatLevel
                    end
                    unitThreatTable[Target.Sync.id] = true
                    if ALLBPS[Target.UnitId].Weapon[1].RangeCategory == 'UWRC_DirectFire' and ALLBPS[Target.UnitId].Weapon[1].MaxRadius > defenseRange then
                        defenseRange = ALLBPS[Target.UnitId].Weapon[1].MaxRadius
                    end
                end
                TargetPosition = Target:GetPosition()
                -- check if we have a special player as enemy
                if enemyBrain and enemyIndex and enemyBrain ~= enemyIndex then continue end
                if EntityCategoryContains(categories.COMMAND, Target) then
                    acuPresent = true
                    acuUnit = Target
                end
                -- check if the Target is still alive, matches our target priority and can be attacked from our platoon
                if not Target.Dead and not Target.CaptureInProgress and EntityCategoryContains(category, Target) and platoon:CanAttackTarget(squad, Target) then
                    -- yes... we need to check if we got friendly units with GetUnitsAroundPoint(_, _, _, 'Enemy')
                    if not IsEnemy( MyArmyIndex, Target:GetAIBrain():GetArmyIndex() ) then continue end
                    if Target.ReclaimInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: ReclaimInProgress !!! Ignoring the target.')
                        continue
                    end
                    if Target.CaptureInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: CaptureInProgress !!! Ignoring the target.')
                        continue
                    end
                    targetRange = VDist2Sq(position[1],position[3],TargetPosition[1],TargetPosition[3])
                    -- check if the target is in range of the unit and in range of the base
                    if targetRange < distance then
                        TargetUnit = Target
                        distance = targetRange
                    end
                end
            end
            if TargetUnit then
                --RNGLOG('Target Found in target aquisition function')
                return TargetUnit, acuPresent, acuUnit, totalThreat, defenseRange, TargetsInRange
            end
        end
        coroutine.yield(2)
    end
    --RNGLOG('NO Target Found in target aquisition function')
    return TargetUnit, acuPresent, acuUnit, totalThreat, defenseRange, TargetsInRange
end

function AIFindBrainTargetACURNG(aiBrain, platoon, position, squad, maxRange, targetQueryCategory, TargetSearchCategory, enemyBrain)
    if type(TargetSearchCategory) == 'string' then
        TargetSearchCategory = ParseEntityCategory(TargetSearchCategory)
    end
    local enemyIndex = false
    local VDist2 = VDist2
    local MyArmyIndex = aiBrain:GetArmyIndex()
    if enemyBrain then
        enemyIndex = enemyBrain:GetArmyIndex()
    end
    local totalThreat = 0
    local unitThreatTable = {}
    local acuPresent = false
    local acuUnit = false
    local RangeList = {
        [1] = maxRange,
        [2] = maxRange + 30,
    }
    local TargetUnit = false
    local TargetsInRange, EnemyStrength, TargetPosition, category, distance, targetRange, baseTargetRange, canAttack
    for _, range in RangeList do
        if not position then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: position is empty')
            return false
        end
        if not range then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: range is empty')
            return false
        end
        if not TargetSearchCategory then
            WARN('* AI-Uveso: AIFindNearestCategoryTargetInCloseRange: TargetSearchCategory is empty')
            return false
        end
        TargetsInRange = GetUnitsAroundPoint(aiBrain, targetQueryCategory, position, range, 'Enemy')
        --DrawCircle(position, range, '0000FF')
        for _, v in TargetSearchCategory do
            category = v
            if type(category) == 'string' then
                category = ParseEntityCategory(category)
            end
            distance = maxRange * maxRange
            --RNGLOG('* AIFindNearestCategoryTargetInRange: numTargets '..RNGGETN(TargetsInRange)..'  ')
            for num, Target in TargetsInRange do
                if Target.Dead or Target:BeenDestroyed() then
                    continue
                end
                if Target.Sync.id and not unitThreatTable[Target.Sync.id] then
                    totalThreat = totalThreat + ALLBPS[Target.UnitId].Defense.SurfaceThreatLevel
                    unitThreatTable[Target.Sync.id] = true
                end
                TargetPosition = Target:GetPosition()
                EnemyStrength = 0
                -- check if we have a special player as enemy
                if enemyBrain and enemyIndex and enemyBrain ~= enemyIndex then continue end
                if EntityCategoryContains(categories.COMMAND, Target) then
                    acuPresent = true
                    acuUnit = Target
                end
                -- check if the Target is still alive, matches our target priority and can be attacked from our platoon
                if not Target.Dead and not Target.CaptureInProgress and EntityCategoryContains(category, Target) and platoon:CanAttackTarget(squad, Target) then
                    -- yes... we need to check if we got friendly units with GetUnitsAroundPoint(_, _, _, 'Enemy')
                    if not IsEnemy( MyArmyIndex, Target:GetAIBrain():GetArmyIndex() ) then continue end
                    if Target.ReclaimInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: ReclaimInProgress !!! Ignoring the target.')
                        continue
                    end
                    if Target.CaptureInProgress then
                        --WARN('* AIFindNearestCategoryTargetInRange: CaptureInProgress !!! Ignoring the target.')
                        continue
                    end
                    targetRange = VDist2Sq(position[1],position[3],TargetPosition[1],TargetPosition[3])
                    -- check if the target is in range of the unit and in range of the base
                    if targetRange < distance then
                        TargetUnit = Target
                        distance = targetRange
                    end
                end
            end
            if TargetUnit then
                --RNGLOG('Target Found in target aquisition function')
                return TargetUnit, acuPresent, acuUnit, totalThreat
            end
           coroutine.yield(2)
        end
        coroutine.yield(1)
    end
    --RNGLOG('NO Target Found in target aquisition function')
    return TargetUnit, acuPresent, acuUnit, totalThreat
end

function GetAssisteesRNG(aiBrain, locationType, assisteeType, buildingCategory, assisteeCategory)
    if assisteeType == categories.FACTORY then
        -- Sift through the factories in the location
        local manager = aiBrain.BuilderManagers[locationType].FactoryManager
        return manager:GetFactoriesWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.ENGINEER then
        local manager = aiBrain.BuilderManagers[locationType].EngineerManager
        return manager:GetEngineersWantingAssistance(buildingCategory, assisteeCategory)
    elseif assisteeType == categories.STRUCTURE then
        local manager = aiBrain.BuilderManagers[locationType].PlatoonFormManager
        return manager:GetUnitsBeingBuilt(buildingCategory, assisteeCategory)
    else
        error('*AI ERROR: Invalid assisteeType - ' .. ToString(assisteeType))
    end

    return false
end

function ExpansionSpamBaseLocationCheck(aiBrain, location)
    local validLocation = false
    local enemyStarts = {}
    if not location then
        return false
    end

    if RNGGETN(aiBrain.EnemyIntel.EnemyStartLocations) > 0 then
        --RNGLOG('*AI RNG: Enemy Start Locations are present for ExpansionSpamBase')
        --RNGLOG('*AI RNG: SpamBase position is'..repr(location))
        enemyStarts = aiBrain.EnemyIntel.EnemyStartLocations
    else
        return false
    end
    
    for key, startloc in enemyStarts do
        
        local locationDistance = VDist2Sq(startloc.Position[1], startloc.Position[3],location[1], location[3])
        --RNGLOG('*AI RNG: location position distance for ExpansionSpamBase is '..locationDistance)
        if  locationDistance > 25600 and locationDistance < 250000 then
            --RNGLOG('*AI RNG: SpamBase distance is within bounds, position is'..repr(location))
            --RNGLOG('*AI RNG: Enemy Start Position is '..repr(startloc))
            if AIAttackUtils.CanGraphToRNG(startloc.Position, location, 'Land') then
                --RNGLOG('Can graph to enemy location for spam base')
                --RNGLOG('*AI RNG: expansion position is within range and pathable to an enemy base for ExpansionSpamBase')
                validLocation = true
                break
            else
                continue
            end
        else
            continue
        end
    end

    if validLocation then
        --RNGLOG('*AI RNG: Spam base is true')
        return true
    else
        --RNGLOG('*AI RNG: Spam base is false')
        return false
    end

    return false
end

function GetNavalPlatoonMaxRangeRNG(aiBrain, platoon)
    local maxRange = 0
    local platoonUnits = platoon:GetPlatoonUnits()
    for _,unit in platoonUnits do
        if unit.Dead then
            continue
        end

        for _,weapon in unit.UnitId.Weapon do
            if not weapon.FireTargetLayerCapsTable or not weapon.FireTargetLayerCapsTable.Water then
                continue
            end

            #Check if the weapon can hit land from water
            local canAttackLand = string.find(weapon.FireTargetLayerCapsTable.Water, 'Land', 1, true)

            if canAttackLand and weapon.MaxRadius > maxRange then
                isTech1 = EntityCategoryContains(categories.TECH1, unit)
                maxRange = weapon.MaxRadius

                if weapon.BallisticArc == 'RULEUBA_LowArc' then
                    selectedWeaponArc = 'low'
                elseif weapon.BallisticArc == 'RULEUBA_HighArc' then
                    selectedWeaponArc = 'high'
                else
                    selectedWeaponArc = 'none'
                end
            end
        end
    end

    if maxRange == 0 then
        return false
    end

    -- T1 naval units don't hit land targets very well. Bail out!
    if isTech1 then
        return false
    end

    return maxRange, selectedWeaponArc
end

function UnitRatioCheckRNG(aiBrain, ratio, categoryOne, compareType, categoryTwo)
    local numOne = GetCurrentUnits(aiBrain, categoryOne)
    local numTwo = GetCurrentUnits(aiBrain, categoryTwo)
    --RNGLOG(aiBrain:GetArmyIndex()..' CompareBody {World} ( '..numOne..' '..compareType..' '..numTwo..' ) -- ['..ratio..'] -- return '..repr(CompareBody(numOne / numTwo, ratio, compareType)))
    return CompareBodyRNG(numOne / numTwo, ratio, compareType)
end

function CompareBodyRNG(numOne, numTwo, compareType)
    if compareType == '>' then
        if numOne > numTwo then
            return true
        end
    elseif compareType == '<' then
        if numOne < numTwo then
            return true
        end
    elseif compareType == '>=' then
        if numOne >= numTwo then
            return true
        end
    elseif compareType == '<=' then
        if numOne <= numTwo then
            return true
        end
    else
       error('*AI ERROR: Invalid compare type: ' .. compareType)
       return false
    end
    return false
end

function DebugArrayRNG(Table)
   --RNGLOG('DebugArrayRNG Checking Table')
    for Index, Array in Table do
        if type(Array) == 'thread' or type(Array) == 'userdata' then
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        elseif type(Array) == 'table' then
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). I won\'t print that!')
        else
           --RNGLOG('Index['..Index..'] is type('..type(Array)..'). "', repr(Array),'".')
        end
    end
end




--[[
   This is Sproutos work, an early function from the master himself
   Inputs : 
   location, location name string
   radius, radius from location position int
   orientation, return positions based on string 'FRONT', 'REAR', 'ALL'
   positionselection, return all, random, selection int or bool
   layer, movement layer string
   patroltype return sequence bool or nil

   Returns :
   sortedList, position table
   Orient, string NESW
   positionselection, int
   ]]
function GetBasePerimeterPoints( aiBrain, location, radius, orientation, positionselection, layer, patroltype )
    
	local newloc = false
	local Orient = false
	local Basename = false
	
	-- we've been fed a base name rather than 3D co-ordinates
	-- store the Basename and convert location into a 3D position
	if type(location) == 'string' then
		Basename = location
		newloc = aiBrain.BuilderManagers[location].Position or false
		Orient = aiBrain.BuilderManagers[location].Orientation or false
		if newloc then
			location = table.copy(newloc)
		end
	end

	-- we dont have a valid 3D location
	-- likely base is no longer active --
	if not location[3] then
		return {}
	end

	if not layer then
		layer = 'Amphibious'
	end

	if not patroltype then
		patroltype = false
	end

	-- get the map dimension sizes
	local Mx = ScenarioInfo.size[1]
	local Mz = ScenarioInfo.size[2]	
	
	if orientation then
		local Sx = RNGCEIL(location[1])
		local Sz = RNGCEIL(location[3])
	
		if not Orient then
			-- tracks if we used threat to determine Orientation
			local Direction = false
			local threats = aiBrain:GetThreatsAroundPosition( location, 16, true, 'Economy' )
			RNGSORT( threats, function(a,b) return VDist2Sq(a[1],a[2],location[1],location[3]) + a[3] < VDist2Sq(b[1],b[2],location[1],location[3]) + b[3] end )
			for _,v in threats do
				Direction = GetDirectionInDegrees( {v[1],location[2],v[2]}, location )
				break	-- process only the first one
			end
			
			if Direction then
				if Direction < 45 or Direction > 315 then
					Orient = 'S'
				elseif Direction >= 45 and Direction < 135 then
					Orient = 'E'
				elseif Direction >= 135 and Direction < 225 then
					Orient = 'N'
				else
					Orient = 'W'
				end
			else
				-- Use map position to determine orientation
				-- First step is too determine if you're in the top or bottom 25% of the map
				-- if you are then you will orient N or S otherwise E or W
				-- the OrientvalueREAR will be set to value of the REAR positions (either the X or Z value depending upon NSEW Orient value)

				-- check if upper or lower quarter		
				if ( Sz <= (Mz * .25) or Sz >= (Mz * .75) ) then
					Orient = 'NS'
				-- otherwise use East/West orientation
				else
					Orient = 'EW'
				end

				-- orientation will be overridden if we are particularily close to a map edge
				-- check if extremely close to an edge (within 11% of map size)
				if (Sz <= (Mz * .11) or Sz >= (Mz * .89)) then
					Orient = 'NS'
				end

				if (Sx <= (Mx * .11) or Sx >= (Mx * .89)) then
					Orient = 'EW'
				end

				-- Second step is to determine if we are N or S - or - E or W
				
				if Orient == 'NS' then 
					-- if N/S and in the lower half of map
					if (Sz > (Mz* 0.5)) then
						Orient = 'N'
					-- else we must be in upper half
					else	
						Orient = 'S'
					end
				else
					-- if E/W and we are in the right side of the map
					if (Sx > (Mx* 0.5)) then
						Orient = 'W'
					-- else we must on the left side
					else
						Orient = 'E'
					end
				end
			end

			-- store the Orientation for any given base
			if Basename then
				aiBrain.BuilderManagers[Basename].Orientation = Orient		
			end
		end
		
		if Orient == 'S' then
			OrientvalueREAR = Sz - radius
			OrientvalueFRONT = Sz + radius		
		elseif Orient == 'E' then
			OrientvalueREAR = Sx - radius
			OrientvalueFRONT = Sx + radius
		elseif Orient == 'N' then
			OrientvalueREAR = Sz + radius
			OrientvalueFRONT = Sz - radius
		elseif Orient == 'W' then
			OrientvalueREAR = Sx + radius
			OrientvalueFRONT = Sz - radius
		end
	end

	-- If radius is very small just return the centre point and orientation
	-- this is often used by engineers to build structures according to a base template with fixed positions
	-- and still maintain the appropriate rotation -- 
	if radius < 4 then
		return { {location[1],0,location[3]} }, Orient
	end	

	local locList = {}
	local counter = 0

	local lowlimit = (radius * -1)
	local highlimit = radius
	local steplimit = (radius / 2)
	
	-- build an array of points in the shape of a box w 5 points to a side
	-- eliminating the corner positions along the way
	-- the points will be numbered from upper left to lower right
	-- this code will always return the 12 points around whatever position it is fed
	-- even if those points result in some point off of the map
	for x = lowlimit, highlimit, steplimit do
		
		for y = lowlimit, highlimit, steplimit do
			
			-- this code lops off the corners of the box and the interior points leaving us with 3 points to a side
			-- basically it forms a '+' shape
			if not (x == 0 and y == 0)	and	(x == lowlimit or y == lowlimit or x == highlimit or y == highlimit)
			and not ((x == lowlimit and y == lowlimit) or (x == lowlimit and y == highlimit)
			or ( x == highlimit and y == highlimit) or ( x == highlimit and y == lowlimit)) then
				locList[counter+1] = { RNGCEIL(location[1] + x), GetSurfaceHeight(location[1] + x, location[3] + y), RNGCEIL(location[3] + y) }
				counter = counter + 1
			end
		end
	end

	-- if we have an orientation build a list of those points that meet that specification
	-- FRONT will have all points that do not match the OrientvalueREAR (9 points)
	-- REAR will have all point that DO match the OrientvalueREAR (3 points)
	-- otherwise we keep all 12 generated points
	if orientation == 'FRONT' or orientation == 'REAR' then
		
		local filterList = {}
		counter = 0

		for k,v in locList do
			local x = v[1]
			local z = v[3]

			if Orient == 'N' or Orient == 'S' then
				if orientation == 'FRONT' and z ~= OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and z == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			elseif Orient == 'W' or Orient == 'E' then
				if orientation == 'FRONT' and x ~= OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				elseif orientation == 'REAR' and x == OrientvalueREAR then
					filterList[counter+1] = v
					counter = counter + 1
				end
			end
		end
		locList = filterList
	end
	
	-- sort the points from front to rear based upon orientation
	if Orient == 'N' then
		table.sort(locList, function(a,b) return a[3] < b[3] end)
	elseif Orient == 'S' then
		table.sort(locList, function(a,b) return a[3] > b[3] end)
	elseif Orient == 'E' then 
		table.sort(locList, function(a,b) return a[1] > b[1] end)
	elseif Orient == 'W' then
		table.sort(locList, function(a,b) return a[1] < b[1] end)
	end

	local sortedList = {}
	
	if table.getsize(locList) == 0 then
		return {} 
	end
	
	-- Originally I always did this and it worked just fine but I want
	-- to find a way to get the AI to rotate templated builds so I need
	-- to provide a consistent result based upon orientation and NOT 
	-- sorted by proximity to map centre -- as I had been doing -- so 
	-- now I only sort the list if its a patrol or Air request
	-- I have kept the original code contained inside this loop but 
	-- it doesn't run
	if patroltype or layer == 'Air' then
		local lastX = Mx* 0.5
		local lastZ = Mz* 0.5
	
		if patroltype or layer == 'Air' then
			lastX = location[1]
			lastZ = location[3]
		end
		
	
		-- Sort points by distance from (lastX, lastZ) - map centre
		-- or if patrol or 'Air', then from the provided location
		for i = 1, counter do
		
			local lowest
			local czX, czZ, pos, distance, key
		
			for k, v in locList do
				local x = v[1]
				local z = v[3]
				distance = VDist2Sq(lastX, lastZ, x, z)
				if not lowest or distance < lowest then
					pos = v
					lowest = distance
					key = k
				end
			end
		
			if not pos then
				return {} 
			end
		
			sortedList[i] = pos
			
			-- use the last point selected as the start point for the next distance check
			if patroltype or layer == 'Air' then
				lastX = pos[1]
				lastZ = pos[3]
			end
			RNGREMOVE(locList, key)
		end
	else
		sortedList = locList
	end

	-- pick a specific position
	if positionselection then
	
		if type(positionselection) == 'boolean' then
			positionselection = Random( 1, counter )	--RNGGETN(sortedList))
		end

	end


	return sortedList, Orient, positionselection
end

function GetDistanceBetweenTwoVectors( v1, v2 )
    return VDist3(v1, v2)
end

function XZDistanceTwoVectors( v1, v2 )
    return VDist2( v1[1], v1[3], v2[1], v2[3] )
end

function GetVectorLength( v )
    return RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
end

function NormalizeVector( v )

	if v.x then
		v = {v.x, v.y, v.z}
	end
	
    local length = RNGSQRT( math.pow( v[1], 2 ) + math.pow( v[2], 2 ) + math.pow(v[3], 2 ) )
	
    if length > 0 then
        local invlength = 1 / length
        return Vector( v[1] * invlength, v[2] * invlength, v[3] * invlength )
    else
        return Vector( 0,0,0 )
    end
end

function GetDifferenceVector( v1, v2 )
    return Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3])
end

function GetDirectionVector( v1, v2 )
    return NormalizeVector( Vector(v1[1] - v2[1], v1[2] - v2[2], v1[3] - v2[3]) )
end

function GetDirectionInDegrees( v1, v2 )
    local RNGACOS = math.acos
	local vec = GetDirectionVector( v1, v2)
	
	if vec[1] >= 0 then
		return RNGACOS(vec[3]) * (360/(RNGPI*2))
	end
	
	return 360 - (RNGACOS(vec[3]) * (360/(RNGPI*2)))
end

function ComHealthRNG(cdr)
    local armorPercent = 100 / cdr:GetMaxHealth() * cdr:GetHealth()
    local shieldPercent = armorPercent
    if cdr.MyShield then
        shieldPercent = 100 / cdr.MyShield:GetMaxHealth() * cdr.MyShield:GetHealth()
    end
    return ( armorPercent + shieldPercent ) / 2
end

-- This is Uvesos lead target function 
function LeadTargetRNG(LauncherPos, target, minRadius, maxRadius)
    -- Get launcher and target position
    --local LauncherPos = launcher:GetPosition()
    local TargetPos
    -- Get target position in 1 second intervals.
    -- This allows us to get speed and direction from the target
    local TargetStartPosition=0
    local Target1SecPos=0
    local Target2SecPos=0
    local XmovePerSec=0
    local YmovePerSec=0
    local XmovePerSecCheck=-1
    local YmovePerSecCheck=-1
    -- Check if the target is runing straight or circling
    -- If x/y and xcheck/ycheck are equal, we can be sure the target is moving straight
    -- in one direction. At least for the last 2 seconds.
    local LoopSaveGuard = 0
    while target and (XmovePerSec ~= XmovePerSecCheck or YmovePerSec ~= YmovePerSecCheck) and LoopSaveGuard < 10 do
        -- 1st position of target
        TargetPos = target:GetPosition()
        TargetStartPosition = {TargetPos[1], 0, TargetPos[3]}
        coroutine.yield(10)
        -- 2nd position of target after 1 second
        TargetPos = target:GetPosition()
        Target1SecPos = {TargetPos[1], 0, TargetPos[3]}
        XmovePerSec = (TargetStartPosition[1] - Target1SecPos[1])
        YmovePerSec = (TargetStartPosition[3] - Target1SecPos[3])
        coroutine.yield(10)
        -- 3rd position of target after 2 seconds to verify straight movement
        TargetPos = target:GetPosition()
        Target2SecPos = {TargetPos[1], TargetPos[2], TargetPos[3]}
        XmovePerSecCheck = (Target1SecPos[1] - Target2SecPos[1])
        YmovePerSecCheck = (Target1SecPos[3] - Target2SecPos[3])
        --We leave the while-do check after 10 loops (20 seconds) and try collateral damage
        --This can happen if a player try to fool the targetingsystem by circling a unit.
        LoopSaveGuard = LoopSaveGuard + 1
    end
    -- Get launcher position height
    local fromheight = GetTerrainHeight(LauncherPos[1], LauncherPos[3])
    if GetSurfaceHeight(LauncherPos[1], LauncherPos[3]) > fromheight then
        fromheight = GetSurfaceHeight(LauncherPos[1], LauncherPos[3])
    end
    -- Get target position height
    local toheight = GetTerrainHeight(Target2SecPos[1], Target2SecPos[3])
    if GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3]) > toheight then
        toheight = GetSurfaceHeight(Target2SecPos[1], Target2SecPos[3])
    end
    -- Get height difference between launcher position and target position
    -- Adjust for height difference by dividing the height difference by the missiles max speed
    local HeightDifference = math.abs(fromheight - toheight) / 12
    -- Speed up time is distance the missile will travel while reaching max speed (~22.47 MapUnits)
    -- divided by the missiles max speed (12) which is equal to 1.8725 seconds flight time
    local SpeedUpTime = 22.47 / 12
    --  Missile needs 3 seconds to launch
    local LaunchTime = 3
    -- Get distance from launcher position to targets starting position and position it moved to after 1 second
    local dist1 = VDist2(LauncherPos[1], LauncherPos[3], Target1SecPos[1], Target1SecPos[3])
    local dist2 = VDist2(LauncherPos[1], LauncherPos[3], Target2SecPos[1], Target2SecPos[3])
    -- Missile has a faster turn rate when targeting targets < 50 MU away, so it will level off faster
    local LevelOffTime = 0.25
    local CollisionRangeAdjust = 0
    if dist2 < 50 then
        LevelOffTime = 0.02
        CollisionRangeAdjust = 2
    end
    -- Divide both distances by missiles max speed to get time to impact
    local time1 = (dist1 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    local time2 = (dist2 / 12) + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Get the missile travel time by extrapolating speed and time from dist1 and dist2
    local MissileTravelTime = (time2 + (time2 - time1)) + ((time2 - time1) * time2)
    -- Now adding all times to get final missile flight time to the position where the target will be
    local MissileImpactTime = MissileTravelTime + LaunchTime + SpeedUpTime + LevelOffTime + HeightDifference
    -- Create missile impact corrdinates based on movePerSec * MissileImpactTime
    local MissileImpactX = Target2SecPos[1] - (XmovePerSec * MissileImpactTime)
    local MissileImpactY = Target2SecPos[3] - (YmovePerSec * MissileImpactTime)
    -- Adjust for targets CollisionOffsetY. If the hitbox of the unit is above the ground
    -- we nedd to fire "behind" the target, so we hit the unit in midair.
    local TargetCollisionBoxAdjust = 0
    local TargetBluePrint = __blueprints[target.UnitId]
    if TargetBluePrint.CollisionOffsetY and TargetBluePrint.CollisionOffsetY > 0 then
        -- if the unit is far away we need to target farther behind the target because of the projectile flight angel
        local DistanceOffset = (100 / 256 * dist2) * 0.06
        TargetCollisionBoxAdjust = TargetBluePrint.CollisionOffsetY * CollisionRangeAdjust + DistanceOffset
    end
    -- To calculate the Adjustment behind the target we use a variation of the Pythagorean theorem. (Percent scale technique)
    -- (a²+b²=c²) If we add x% to c² then also a² and b² are x% larger. (a²)*x% + (b²)*x% = (c²)*x%
    local Hypotenuse = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    local HypotenuseScale = 100 / Hypotenuse * TargetCollisionBoxAdjust
    local aLegScale = (MissileImpactX - LauncherPos[1]) / 100 * HypotenuseScale
    local bLegScale = (MissileImpactY - LauncherPos[3]) / 100 * HypotenuseScale
    -- Add x percent (behind) the target coordinates to get our final missile impact coordinates
    MissileImpactX = MissileImpactX + aLegScale
    MissileImpactY = MissileImpactY + bLegScale
    -- Cancel firing if target is outside map boundries
    if MissileImpactX < 0 or MissileImpactY < 0 or MissileImpactX > ScenarioInfo.size[1] or MissileImpactY > ScenarioInfo.size[2] then
        --RNGLOG('Target outside map boundries')
        return false
    end
    local dist3 = VDist2(LauncherPos[1], LauncherPos[3], MissileImpactX, MissileImpactY)
    if dist3 < minRadius or dist3 > maxRadius then
        --RNGLOG('Target outside max radius')
        return false
    end
    -- return extrapolated target position / missile impact coordinates
    return {MissileImpactX, Target2SecPos[2], MissileImpactY}
end

function AIFindRangedAttackPositionRNG(aiBrain, platoon, MaxPlatoonWeaponRange)
    local startPositions = {}
    local myArmy = ScenarioInfo.ArmySetup[aiBrain.Name]
    local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
    local platoonPosition = platoon:GetPlatoonPosition()

    for i = 1, 16 do
        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
        local posThreat = 0
        local posDistance = 0
        if startPos then
            if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                posThreat = GetThreatAtPosition(aiBrain, startPos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'StructuresNotMex')
                --RNGLOG('Ranged attack loop position is '..repr(startPos)..' with threat of '..posThreat)
                if posThreat > 5 then
                    if GetNumUnitsAroundPoint(aiBrain, categories.STRUCTURE - categories.WALL, startPos, 50, 'Enemy') > 0 then
                        --RNGLOG('Ranged attack position has structures within range')
                        posDistance = VDist2Sq(mainBasePos[1], mainBasePos[3], startPos[1], startPos[2])
                        --RNGLOG('Potential Naval Ranged attack position :'..repr(startPos)..' Threat at Position :'..posThreat..' Distance :'..posDistance)
                        table.insert(startPositions,
                            {
                                Position = startPos,
                                Threat = posThreat,
                                Distance = posDistance,
                            }
                        )
                    else
                        --RNGLOG('Ranged attack position has threat but no structures within range')
                    end
                end
            end
        end
    end
    --RNGLOG('Potential Positions Table '..repr(startPositions))
    -- We sort the positions so the closest are first
    RNGSORT( startPositions, function(a,b) return a.Distance < b.Distance end )
    --RNGLOG('Potential Positions Sorted by distance'..repr(startPositions))
    local attackPosition = false
    local targetStartPosition = false
    --We look for the closest
    for k, v in startPositions do
        local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(aiBrain, 'Water Path Node', v.Position[1], v.Position[3])
        if waterNodeDist and waterNodeDist < (MaxPlatoonWeaponRange * MaxPlatoonWeaponRange + 900) then
            --RNGLOG('Start position is '..waterNodeDist..' from water node, weapon range on platoon is '..MaxPlatoonWeaponRange..' we are going to attack from this position')
            if AIAttackUtils.CheckPlatoonPathingEx(platoon, waterNodePos) then
                attackPosition = waterNodePos
                targetStartPosition = v.Position
                break
            end
        end
    end
    if attackPosition then
        --RNGLOG('Valid Attack Position '..repr(attackPosition)..' target Start Position '..repr(targetStartPosition))
    end
    return attackPosition, targetStartPosition
end
-- Another of Sproutos functions
function GetEnemyUnitsInRect( aiBrain, x1, z1, x2, z2 )
    
    local units = GetUnitsInRect(x1, z1, x2, z2)
    
    if units then
	
        local enemyunits = {}
		local counter = 0
		
        local IsEnemy = IsEnemy
		local GetAIBrain = moho.entity_methods.GetAIBrain
		
        for _,v in units do
		
            if not v.Dead and IsEnemy( GetAIBrain(v).ArmyIndex, aiBrain.ArmyIndex) then
                enemyunits[counter+1] =  v
				counter = counter + 1
            end
        end 
		
        if counter > 0 then
            return enemyunits, counter
        end
    end
    
    return {}, 0
end

function GetShieldRadiusAboveGroundSquaredRNG(shield)
    local BP = shield:GetBlueprint().Defense.Shield
    local width = BP.ShieldSize
    local height = BP.ShieldVerticalOffset

    return width * width - height * height
end

function ShieldProtectingTargetRNG(aiBrain, targetUnit)
    if not targetUnit then
        return false
    end

    -- If targetUnit is within the radius of any shields return true
    local tPos = targetUnit:GetPosition()
    local shields = GetUnitsAroundPoint(aiBrain, CategoriesShield, targetUnit:GetPosition(), 50, 'Enemy')
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)
            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                return true
            end
        end
    end
    return false
end

local markerTypeCache = { }
--- Flushes the entire cache
function FlushMarkerTypeCache()
    markerTypeCache = { }
end
--- Flushes a single element from the cache
-- @param markerType The type to flush.
function FlushElementOfMarkerTypeCache(markerType)
    markerTypeCache[markerType] = nil
end
--- Sets the cache for a specific marker type - it is up to you to make 
-- sure the format is correct: {Position = v.position, Name = k}.
-- @param markerType The type to set.
-- @param markers The marker to set.
function SetMarkerTypeCache(markerType, markers)
    markerTypeCache[markerType] = markers
end

function GetMarkersByType(markerType)

    --RNGLOG("Retrieving markers of type: " .. markerType)

    -- check if parameter is set, if not - help us all and return everything
    if not markerType then 
        return Scenario.MasterChain._MASTERCHAIN_.Markers
    end
    -- check if we already looked for these in the past
    if not markerTypeCache[markerType] then
        -- make it easier to read
        local markers = Scenario.MasterChain._MASTERCHAIN_.Markers
        -- prepare a table to keep the markers
        local cache = { }
        -- go over every marker and popualte our table
        if markers then
            for k, v in markers do
                if v.type == markerType then
                    table.insert(cache, {Position = v.position, Name = k})
                end
            end
        end
        -- add the markers of this type to the cache
        markerTypeCache[markerType] = cache
        --RNGLOG("ScenarioUtils: Cached " .. RNGGETN(cache) .. " markers of type: " .. markerType)
    end
    -- return the cached markers
    return markerTypeCache[markerType]
end

function AIGetSortedMassLocationsThreatRNG(aiBrain, minDist, maxDist, tMin, tMax, tRings, tType, position)

    local threatCheck = false
    local maxDistance = 2000
    local minDistance = 0
    local VDist2Sq = VDist2Sq


    local startX, startZ
    
    if position then
        startX = position[1]
        startZ = position[3]
    else
        startX, startZ = aiBrain:GetArmyStartPos()
    end
    if maxDist and minDist then
        maxDistance = maxDist * maxDist
        minDistance = minDist * minDist
    end

    if tMin and tMax and tType then
        threatCheck = true
    else
        threatCheck = false
    end

    local markerList = GetMarkersByType('Mass')
    RNGSORT(markerList, function(a,b) return VDist2Sq(a.Position[1],a.Position[3], startX,startZ) < VDist2Sq(b.Position[1],b.Position[3], startX,startZ) end)
    --RNGLOG('Sorted Mass Marker List '..repr(markerList))
    local newList = {}
    for _, v in markerList do
        -- check distance to map border. (game engine can't build mass closer then 8 mapunits to the map border.) 
        if VDist2Sq(v.Position[1], v.Position[3], startX, startZ) < minDistance then
            continue
        end
        if VDist2Sq(v.Position[1], v.Position[3], startX, startZ) > maxDistance  then
            --RNGLOG('Current Distance of marker..'..VDist2Sq(v.Position[1], v.Position[3], startX, startZ))
            --RNGLOG('Max Distance'..maxDistance)
            --RNGLOG('mass marker MaxDistance Reached, breaking loop')
            break
        end
        if CanBuildStructureAt(aiBrain, 'ueb1103', v.Position) then
            if threatCheck then
                if GetThreatAtPosition(aiBrain, v.Position, 0, true, tType) >= tMax then
                    --RNGLOG('mass marker threatMax Reached, continuing')
                    continue
                end
            end
            table.insert(newList, v)
        end
    end
    --RNGLOG('Return marker list has '..RNGGETN(newList)..' entries')
    return newList
end

function EdgeDistance(x,y,mapwidth)
    local edgeDists = { x, y, math.abs(x-mapwidth), math.abs(y-mapwidth)}
    RNGSORT(edgeDists, function(k1, k2) return k1 < k2 end)
    return edgeDists[1]
end

function GetDirectorTarget(aiBrain, platoon, threatType, platoonThreat)


    
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end

end

DisplayBaseMexAllocationRNG = function(aiBrain)
    local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
    local adaptiveResourceMarkers = GetMarkersRNG()
    local MassMarker = {}
    for _, v in adaptiveResourceMarkers do
        if v.type == 'Mass' then
            table.insert(MassMarker, v)
        end
    end
    while aiBrain.Result ~= "defeat" do
        for _, v in MassMarker do
            local pos1={0,0,0}
            local pos2={0,0,0}
            table.sort(starts,function(k1,k2) return VDist2Sq(k1.Position[1],k1.Position[3],v.position[1],v.position[3])<VDist2Sq(k2.Position[1],k2.Position[3],v.position[1],v.position[3]) end)
            local chosenstart = starts[1]
            pos1=v.position
            pos2=chosenstart.Position
            DrawLinePop(pos1,pos2,'ffFF0000')
        end
        coroutine.yield(2)
    end
end

CountSoonMassSpotsRNG = function(aiBrain)
    local enemies={}
    local VDist2Sq = VDist2Sq
    for i,v in ArmyBrains do
        if ArmyIsCivilian(v:GetArmyIndex()) or not IsEnemy(aiBrain:GetArmyIndex(),v:GetArmyIndex()) or v.Result=="defeat" then continue end
        local index = v:GetArmyIndex()
        local astartX, astartZ = v:GetArmyStartPos()
        local aiBrainstart = {Position={astartX, GetTerrainHeight(astartX, astartZ), astartZ},army=i}
        table.insert(enemies,aiBrainstart)
    end
    local startX, startZ = aiBrain:GetArmyStartPos()
    local adaptiveResourceMarkers = GetMarkersRNG()
    table.sort(enemies,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],startX,startZ)<VDist2Sq(b.Position[1],b.Position[3],startX,startZ) end)
    while not aiBrain.cmanager do coroutine.yield(20) end
    if not aiBrain.expansionMex or not aiBrain.expansionMex[1].priority then
        --initialize expansion priority
        local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
        local Expands = AIUtils.AIGetMarkerLocations(aiBrain, 'Expansion Area')
        local BigExpands = AIUtils.AIGetMarkerLocations(aiBrain, 'Large Expansion Area')
        if not aiBrain.emanager then aiBrain.emanager={} end
        aiBrain.emanager.expands = {}
        aiBrain.emanager.enemies=enemies
        aiBrain.emanager.enemy=enemies[1]
        for _, v in Expands do
            v.expandtype='expand'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        for _, v in BigExpands do
            v.expandtype='bigexpand'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        for _, v in starts do
            v.expandtype='start'
            v.mexnum=0
            v.mextable={}
            v.relevance=0
            v.owner=nil
            table.insert(aiBrain.emanager.expands,v)
        end
        aiBrain.expansionMex={}
        local expands={}
        for k, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                table.sort(aiBrain.emanager.expands,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],v.position[1],v.position[3])<VDist2Sq(b.Position[1],b.Position[3],v.position[1],v.position[3]) end)
                if VDist3Sq(aiBrain.emanager.expands[1].Position,v.position)<25*25 then
                    table.insert(aiBrain.emanager.expands[1].mextable,{v,Position = v.position, Name = k})
                    aiBrain.emanager.expands[1].mexnum=aiBrain.emanager.expands[1].mexnum+1
                    table.insert(aiBrain.expansionMex, {v,Position = v.position, Name = k,ExpandMex=true})
                else
                    table.insert(aiBrain.expansionMex, {v,Position = v.position, Name = k})
                end
            end
        end
        for _,v in aiBrain.expansionMex do
            table.sort(aiBrain.emanager.expands,function(a,b) return VDist2Sq(a.Position[1],a.Position[3],v.Position[1],v.Position[3])<VDist2Sq(b.Position[1],b.Position[3],v.Position[1],v.Position[3]) end)
            v.distsq=VDist2Sq(aiBrain.emanager.expands[1].Position[1],aiBrain.emanager.expands[1].Position[2],v.Position[1],v.Position[3])
            if v.ExpandMex then
                v.priority=aiBrain.emanager.expands[1].mexnum
                v.expand=aiBrain.emanager.expands[1]
                v.expand.taken=0
                v.expand.takentime=0
            else
                v.priority=1
            end
        end
    end
    aiBrain.cmanager.unclaimedmexcount=0
    local massmarkers={}
        for _, v in adaptiveResourceMarkers do
            if v.type == 'Mass' then
                table.insert(massmarkers,v)
            end
        end
    while aiBrain.Result ~= "defeat" do
        local markercache=table.copy(massmarkers)
        for _=0,10 do
            local soonmexes={}
            local unclaimedmexcount=0
            for i,v in markercache do
                if not CanBuildStructureAt(aiBrain, 'ueb1103', v.position) then 
                    table.remove(markercache,i) 
                    continue 
                end
                if aiBrain:GetNumUnitsAroundPoint(categories.MASSEXTRACTION + categories.ENGINEER, v.position, 50*ScenarioInfo.size[1]/256, 'Ally')>0 then
                    unclaimedmexcount=unclaimedmexcount+1
                    table.insert(soonmexes,{Position = v.position, Name = i})
                end
            end
            aiBrain.cmanager.unclaimedmexcount=(aiBrain.cmanager.unclaimedmexcount+unclaimedmexcount)/2
            aiBrain.emanager.soonmexes=soonmexes
            --RNGLOG(repr(aiBrain.Nickname)..' unclaimedmex='..repr(aiBrain.cmanager.unclaimedmexcount))
            coroutine.yield(20)
        end
    end
end
-- start of supporting functions for zone area thingy
GenerateDistinctColorTable = function(num)
    local function factorial(n,min)
        if n>min and n>1 then
            return n*factorial(n-1)
        else
            return n
        end
    end
    local function combintoid(a,b,c)
        local o=tostring(0)
        local tab={a,b,c}
        local tabid={}
        for k,v in tab do
            local n=v
            tabid[k]=tostring(v)
            while n<1000 do
                n=n*10
                tabid[k]=o..tabid[k]
            end
        end
        return tabid[1]..tabid[2]..tabid[3]
    end
    local i=0
    local n=1
    while i<num do
        n=n+1
        i=n*n*n-n
    end
    local ViableValues={}
    for x=0,256,256/(n-1) do
        table.insert(ViableValues,ToColorRNG(0,256,x/256))
    end
    local colortable={}
    local combinations={}
    --[[for k,v in ViableValues do
        table.insert(colortable,v..v..v)
        combinations[combintoid(k,k,k)]=1
    end]]
    local max=ViableValues[RNGGETN(ViableValues)]
    local min=ViableValues[1]
    local primaries={min..min..min,max..max..min,max..min..max,min..max..max,max..min..min,min..max..min,min..min..max,max..max..max}
    combinations[combintoid(max,max,min)]=1
    combinations[combintoid(max,min,max)]=1
    combinations[combintoid(min,max,max)]=1
    combinations[combintoid(max,min,min)]=1
    combinations[combintoid(min,max,min)]=1
    combinations[combintoid(min,min,max)]=1
    combinations[combintoid(max,max,max)]=1
    combinations[combintoid(min,min,min)]=1
    for a,d in ViableValues do
        for b,e in ViableValues do
            for c,f in ViableValues do
                if not combinations[combintoid(a,b,c)] and not (a==b and b==c) then
                    table.insert(colortable,d..e..f)
                    combinations[combintoid(a,b,c)]=1
                end
            end
        end
    end
    for _,v in primaries do
        table.insert(colortable,v)
    end
    return colortable
end

GrabRandomDistinctColor = function(num)
    local output=GenerateDistinctColorTable(num)
    return output[math.random(RNGGETN(output))]
end
LastKnownThread = function(aiBrain)
    aiBrain.lastknown={}
    --aiBrain:ForkThread(ShowLastKnown)
    aiBrain:ForkThread(TruePlatoonPriorityDirector)
    while not aiBrain.emanager.enemies do coroutine.yield(20) end
    while aiBrain.Result ~= "defeat" do
        local time=GetGameTimeSeconds()
        for _=0,10 do
            local enemyMexes = {}
            local mexcount = 0
            local eunits=aiBrain:GetUnitsAroundPoint(categories.LAND + categories.STRUCTURE, {0,0,0}, math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])*1.5, 'Enemy')
            for _,v in eunits do
                if not v or v.Dead then continue end
                if ArmyIsCivilian(v:GetArmy()) then continue end
                local id=v.Sync.id
                local unitPosition = table.copy(v:GetPosition())
                if EntityCategoryContains(categories.MASSEXTRACTION,v) then
                    if not aiBrain.lastknown[id] or time-aiBrain.lastknown[id].time>10 then
                        aiBrain.lastknown[id]={}
                        aiBrain.lastknown[id].object=v
                        aiBrain.lastknown[id].Position=unitPosition
                        aiBrain.lastknown[id].time=time
                        aiBrain.lastknown[id].recent=true
                        aiBrain.lastknown[id].type='mex'
                    end
                    mexcount = mexcount + 1
                    if not v.zoneid and aiBrain.ZonesInitialized then
                        if PositionOnWater(unitPosition[1], unitPosition[3]) then
                            -- tbd define water based zones
                            v.zoneid = 'water'
                        else
                            v.zoneid = MAP:GetZoneID(unitPosition,aiBrain.Zones.Land.index)
                        end
                    end
                    if not enemyMexes[v.zoneid] then
                        enemyMexes[v.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                    end
                    if EntityCategoryContains(categories.TECH1,v) then
                        enemyMexes[v.zoneid].T1 = enemyMexes[v.zoneid].T1 + 1
                    elseif EntityCategoryContains(categories.TECH2,v) then
                        enemyMexes[v.zoneid].T2 = enemyMexes[v.zoneid].T2 + 1
                    else
                        enemyMexes[v.zoneid].T3 = enemyMexes[v.zoneid].T3 + 1
                    end
                end
                if not aiBrain.lastknown[id] or time-aiBrain.lastknown[id].time>10 then
                    if not aiBrain.lastknown[id] then
                        aiBrain.lastknown[id]={}
                        if EntityCategoryContains(categories.MOBILE,v) then
                            if EntityCategoryContains(categories.ENGINEER-categories.COMMAND,v) then
                                aiBrain.lastknown[id].type='eng'
                            elseif EntityCategoryContains(categories.COMMAND,v) then
                                aiBrain.lastknown[id].type='acu'
                            elseif EntityCategoryContains(categories.ANTIAIR,v) then
                                aiBrain.lastknown[id].type='aa'
                            elseif EntityCategoryContains(categories.DIRECTFIRE,v) then
                                aiBrain.lastknown[id].type='tank'
                            elseif EntityCategoryContains(categories.INDIRECTFIRE,v) then
                                aiBrain.lastknown[id].type='arty'
                            end
                        elseif EntityCategoryContains(categories.RADAR,v) then
                            aiBrain.lastknown[id].type='radar'
                        end
                    end
                    aiBrain.lastknown[id].object=v
                    aiBrain.lastknown[id].Position=unitPosition
                    aiBrain.lastknown[id].time=time
                    aiBrain.lastknown[id].recent=true
                    
                end
            end
            aiBrain.emanager.mex = enemyMexes
            coroutine.yield(20)
            time=GetGameTimeSeconds()
        end
        for i,v in aiBrain.lastknown do
            if (v.object and v.object.Dead) then
                aiBrain.lastknown[i]=nil
            elseif time-v.time>120 or (v.object and v.object.Dead) or (time-v.time>15 and GetNumUnitsAroundPoint(aiBrain,categories.MOBILE,v.Position,20,'Ally')>3) then
                aiBrain.lastknown[i].recent=false
            end
        end
    end
end
ShowLastKnown = function(aiBrain)
    if ScenarioInfo.Options.AIDebugDisplay ~= 'displayOn' then
        return
    end
    while not aiBrain.lastknown do
        coroutine.yield(2)
    end
    while aiBrain.result ~= "defeat" do
        local time=GetGameTimeSeconds()
        local lastknown=table.copy(aiBrain.lastknown)
        for _,v in lastknown do
            if v.recent then
                local ratio=(1-(time-v.time)/120)*(1-(time-v.time)/120)
                local ratio2=(1-(time-v.time)/120)
                local color=ToColorRNG(10,255,ratio2)
                local color1=ToColorRNG(10,255,ratio)
                local color2=ToColorRNG(10,100,math.random())
                local color3=ToColorRNG(10,100,math.random())
                DrawCircle(v.Position,3,color..color1..color2..color3)
            else
                DrawCircle(v.Position,2,ToColorRNG(120,200,math.random())..ToColorRNG(50,255,math.random())..ToColorRNG(50,255,math.random())..ToColorRNG(50,255,math.random()))
            end
        end
        coroutine.yield(2)
    end
end
--[[TruePlatoonPriorityDirector = function(aiBrain)
    aiBrain.prioritypoints={}
    while not aiBrain.lastknown do WaitSeconds(2) end
    while aiBrain.Result ~= "defeat" do
        aiBrain.prioritypoints={}
        for _=0,5 do
            for k,v in aiBrain.lastknown do
                if not v.recent or aiBrain.prioritypoints[k] then continue end
                local priority=0
                if v.type then
                    if v.type=='eng' then
                        priority=30
                    elseif v.type=='mex' then
                        priority=20
                    elseif v.type=='radar' then
                        priority=100
                    else
                        priority=10
                    end
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=GrabPosDangerRNG(aiBrain,v.Position,30).enemy,unit=v.object}
                end
            end
            coroutine.yield(10)
        end
    end
end]]

TruePlatoonPriorityDirector = function(aiBrain)
    aiBrain.prioritypoints={}
    while not aiBrain.lastknown do coroutine.yield(20) end
    while aiBrain.Result ~= "defeat" do
        --RNGLOG('Check Expansion table in priority directo')
        if aiBrain.BrainIntel.ExpansionWatchTable then
            for k, v in aiBrain.BrainIntel.ExpansionWatchTable do
                if v.Land > 0 or v.Structures > 0 then
                    local priority=0
                    local acuPresent = false
                    if v.Structures > 0 then
                        -- We divide by 100 because of mexes being 1000 and greater threat. If they ever fix the threat numbers of mexes then this can change
                        priority = priority + (v.Structures / 100)
                        --RNGLOG('Structure Priority is '..priority)
                    end
                    if v.Land > 0 then 
                        priority = priority + 50
                    end
                    if v.PlatoonAssigned then
                        priority = priority - 20
                    end
                    if v.MassPoints >= 3 then
                        priority = priority + 50
                    elseif v.MassPoints >= 2 then
                        priority = priority + 30
                    end
                    if v.Commander > 0 then
                        acuPresent = true
                    end
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=GrabPosDangerRNG(aiBrain,v.Position,30).enemy,unit=v.object, ACUPresent=acuPresent}
                else
                    local acuPresent = false
                    local priority=0
                    if v.MassPoints >= 2 then
                        priority = priority + 30
                    end
                    if v.Commander > 0 then
                        acuPresent = true
                    end
                    aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=0,unit=v.object, ACUPresent=acuPresent}
                end
            end
            coroutine.yield(10)
        end
        --RNGLOG('Check lastknown')
        for k,v in aiBrain.lastknown do
            if not v.recent or aiBrain.prioritypoints[k] then continue end
            local priority=0
            if v.type then
                if v.type=='eng' then
                    priority=50
                elseif v.type=='mex' then
                    priority=40
                elseif v.type=='radar' then
                    priority=100
                else
                    priority=20
                end
                aiBrain.prioritypoints[k]={type='raid',Position=v.Position,priority=priority,danger=GrabPosDangerRNG(aiBrain,v.Position,30).enemy,unit=v.object}
            end
        end
        if aiBrain.CDRUnit.Active then
            --[[
                local minpri=300
                local dangerpri=500
                local healthcutoff=5000
                local dangerfactor = cdr.CurrentEnemyThreat/cdr.CurrentFriendlyThreat
                Danger factor doesn't quite fit in yet. More work.
                local healthdanger = minpri + (dangerpri - minpri) * healthcutoff / aiBrain.CDRUnit:GetHealth() * dangerfactor
            ]]
            local healthdanger = 2500000 / aiBrain.CDRUnit.Health 
           --RNGLOG('CDR health is '..aiBrain.CDRUnit.Health)
           --RNGLOG('Health Danger is '..healthdanger)
            local enemyThreat
            local friendlyThreat
            if aiBrain.CDRUnit.CurrentEnemyThreat > 0 then
                enemyThreat = aiBrain.CDRUnit.CurrentEnemyThreat
            else
                enemyThreat = 1
            end


            if aiBrain.CDRUnit.CurrentFriendlyThreat > 0 then
                friendlyThreat = aiBrain.CDRUnit.CurrentFriendlyThreat
            else
                friendlyThreat = 1
            end
           --RNGLOG('prioritypoint friendly threat is '..friendlyThreat)
           --RNGLOG('prioritypoint enemy threat is '..enemyThreat)
           --RNGLOG('Priority Based on threat would be '..(healthdanger * (enemyThreat / friendlyThreat)))
           --RNGLOG('Instead is it '..healthdanger)
            local acuPriority = healthdanger * (enemyThreat / friendlyThreat)
            if aiBrain.CDRUnit.Caution then
                acuPriority = acuPriority + 100
            end
            aiBrain.prioritypoints['ACU']={type='raid',Position=aiBrain.CDRUnit.Position,priority=acuPriority,danger=GrabPosDangerRNG(aiBrain,aiBrain.CDRUnit.Position,30).enemy,unit=nil}
        end
        coroutine.yield(50)
        --RNGLOG('Priority Points'..repr(aiBrain.prioritypoints))
    end
end

ACUPriorityDirector = function(aiBrain, platoon, platoonPosition, maxRadius)
    -- See if anything in the ACU table looks good to attack
    local enemyUnitThreat = 0
    local armyIndex = aiBrain:GetArmyIndex()
    local target = false
    local enemyACUTable = {}
    if not platoon.MovementLayer then
        platoon:ConfigurePlatoon()
    end
    if aiBrain.EnemyIntel.ACU then
        for k, v in aiBrain.EnemyIntel.ACU do
            if aiBrain.CDRUnit.EnemyCDRPresent then
                target = AIFindACUTargetInRangeRNG(aiBrain, platoon, aiBrain.CDRUnit.Position, 'Attack', maxRadius, platoon.CurrentPlatoonThreat)
                return target
            elseif k ~= armyIndex and v.Ally then
                if ArmyBrains[k].RNG and ArmyBrains[k].CDRUnit.EnemyCDRPresent then
                    target = AIFindACUTargetInRangeRNG(aiBrain, self, ArmyBrains[k].CDRUnit.Position, 'Attack', maxRadius, self.CurrentPlatoonThreat)
                   --LOG('Return ACU enemy acu from ally cdr')
                    return target
                end
            elseif not v.Ally and v.OnField and (v.LastSpotted + 30) > GetGameTimeSeconds() then
                if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
                    if VDist2Sq(v.Position[1], v.Position[3], platoonPosition[1], platoonPosition[3]) < 6400 then
                        local enemyUnits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE + categories.INDIRECTFIRE, v.Position, 60 ,'Enemy')
                        for c, b in enemyUnits do
                            if b and not b.Dead then
                                if EntityCategoryContains(categories.COMMAND, b) then
                                    enemyUnitThreat = enemyUnitThreat + b:EnhancementThreatReturn()
                                    RNGINSERT(enemyACUTable, b)
                                else
                                    --RNGLOG('Unit ID is '..v.UnitId)
                                    if bp.SurfaceThreatLevel ~= nil then
                                        enemyUnitThreat = enemyUnitThreat + ALLBPS[b.UnitId].Defense.SurfaceThreatLevel
                                    end
                                end
                            end
                        end
                        if RNGGETN(enemyACUTable) > 0 then
                            --Do funky stuff to see if we should try rush this acu
                        end
                    end
                elseif platoon.MovementLayer == 'Air' then
                    local enemyUnits=GetUnitsAroundPoint(aiBrain, categories.ANTIAIR, v.Position, 60 ,'Enemy')
                    for c, b in enemyUnits do
                        if b and not b.Dead then
                            if EntityCategoryContains(categories.COMMAND, b) then
                                RNGINSERT(enemyACUTable, b)
                            else
                                --RNGLOG('Unit ID is '..v.UnitId)
                                if bp.AirThreatLevel ~= nil then
                                    enemyUnitThreat = enemyUnitThreat + ALLBPS[b.UnitId].Defense.AirThreatLevel
                                end
                            end
                        end
                    end
                    if RNGGETN(enemyACUTable) > 0 then
                        --Do funky stuff to see if we should try snipe this acu
                    end
                end
            end
        end
    end
end

ToColorRNG = function(min,max,ratio)
    local ToBase16 = function(num)
        if num<10 then
            return tostring(num)
        elseif num==10 then
            return 'a'
        elseif num==11 then
            return 'b'
        elseif num==12 then
            return 'c'
        elseif num==13 then
            return 'd'
        elseif num==14 then
            return 'e'
        else
            return 'f'
        end
    end
    local baseones=0
    local basetwos=0
    local numinit=math.abs(math.ceil((max-min)*ratio+min))
    basetwos=math.floor(numinit/16)
    baseones=numinit-basetwos*16
    return ToBase16(basetwos)..ToBase16(baseones)
end

-- end of supporting functions for zone area thingy

-- TruePlatoon Support functions

GrabPosDangerRNG = function(aiBrain,pos,radius)

    local brainThreats = {ally=0,enemy=0}
    local enemyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Enemy')
    for _,v in enemyunits do
        if not v.Dead then
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            if ALLBPS[v.UnitId].Defense.SurfaceThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel*mult
            end
        end
    end

    local allyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Ally')
    for _,v in allyunits do
        if not v.Dead then
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            if ALLBPS[v.UnitId].Defense.SurfaceThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + ALLBPS[v.UnitId].Defense.SurfaceThreatLevel*mult
            end
        end
    end
    return brainThreats
end

GrabPosDangerRNGOriginal = function(aiBrain,pos,radius)
    local function GetWeightedHealthRatio(unit)
        if unit.MyShield then
            return (unit.MyShield:GetHealth()+unit:GetHealth())/(unit.MyShield:GetMaxHealth()+unit:GetMaxHealth())
        else
            return unit:GetHealthPercent()
        end
    end
    local brainThreats = {ally=0,enemy=0}
    local allyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Ally')
    local enemyunits=GetUnitsAroundPoint(aiBrain, categories.DIRECTFIRE+categories.INDIRECTFIRE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local mult=1
            if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                mult=0.3
            end
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.SurfaceThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.SurfaceThreatLevel*GetWeightedHealthRatio(v)*mult
            end
        end
    end
    return brainThreats
end

GrabPosDangerRNGold = function(aiBrain,pos,radius)
    -- this is stupid, won't return ally commander threat >_<
    local brainThreats = {ally=0,enemy=0}
    brainThreats.ally = brainThreats.ally + aiBrain:GetThreatAtPosition(pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Land', aiBrain:GetArmyIndex())
    brainThreats.enemy = brainThreats.enemy + aiBrain:GetThreatAtPosition(pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Land')
    brainThreats.ally = brainThreats.ally + aiBrain:GetThreatAtPosition(pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander', aiBrain:GetArmyIndex())
    brainThreats.enemy = brainThreats.enemy + aiBrain:GetThreatAtPosition(pos, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Commander')
    --RNGLOG('GrabPosDanger ally :'..brainThreats.ally.. ' Enemy :'..brainThreats.enemy)
    return brainThreats
end

GrabPosEconRNG = function(aiBrain,pos,radius)
    local brainThreats = {ally=0,enemy=0}
    local allyunits=GetUnitsAroundPoint(aiBrain, categories.STRUCTURE,pos,radius,'Ally')
    if not allyunits then return brainThreats end
    local enemyunits=GetUnitsAroundPoint(aiBrain, categories.STRUCTURE,pos,radius,'Enemy')
    for _,v in allyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.ally = brainThreats.ally + bp.EconomyThreatLevel
            end
        end
    end
    for _,v in enemyunits do
        if not v.Dead then
            local index = v:GetAIBrain():GetArmyIndex()
            --RNGLOG('Unit Defense is'..repr(v:GetBlueprint().Defense))
            --RNGLOG('Unit ID is '..v.UnitId)
            --bp = v:GetBlueprint().Defense
            local bp = __blueprints[v.UnitId].Defense
            --RNGLOG(repr(__blueprints[v.UnitId].Defense))
            if bp.EconomyThreatLevel ~= nil then
                brainThreats.enemy = brainThreats.enemy + bp.EconomyThreatLevel
            end
        end
    end
    return brainThreats
end

PlatoonReclaimQueryRNGRNG = function(aiBrain,platoon)
    -- we need to figure a way to make sure we arn't to close to an existing tagged reclaim area
    if aiBrain.ReclaimEnabled then
        local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
        local homeBaseLocation = aiBrain.BuilderManagers['MAIN'].Position
        local platoonPos = platoon:GetPosition()
        if VDist2Sq(platoonPos[1], platoonPos[3], homeBaseLocation[1], homeBaseLocation[3]) < (BaseDMZArea * BaseDMZArea) then
            local valueTrigger = 200
            local currentValue = 0
            local x1 = platoonPos[1] - 20
            local x2 = platoonPos[1] + 20
            local z1 = platoonPos[3] - 20
            local z2 = platoonPos[3] + 20
            local rect = Rect(x1, z1, x2, z2)
            local reclaimRect = {}
            reclaimRect = GetReclaimablesInRect(rect)
            if not platoonPos then
                coroutine.yield(1)
                return
            end
            if reclaimRect and RNGGETN( reclaimRect ) > 0 then
                for k,v in reclaimRect do
                    if not IsProp(v) or self.BadReclaimables[v] then continue end
                    currentValue = currentValue + v.MaxMassReclaim
                    if currentValue > valueTrigger then
                        --insert into table stuff
                        --break
                    end
                end
            end
        end
    end
end

RenderBrainIntelRNG = function(aiBrain)

    while aiBrain.Result ~= "defeat" do
        for _,expansion in aiBrain.BrainIntel.ExpansionWatchTable do
            if expansion.Position then
                DrawCircle(expansion.Position,math.min(10,expansion.Commander/8),'FF9999FF')
                DrawCircle(expansion.Position,math.min(10,expansion.Land/8),'FF99FF99')
                DrawCircle(expansion.Position,math.min(10,expansion.Structures/8),'FF999999')
            end
        end
        coroutine.yield(2)
    end
end

--[[function MexUpgradeManagerRNG(aiBrain)
    local homebasex,homebasey = aiBrain:GetArmyStartPos()
    local VDist3Sq = VDist3Sq
    local homepos = {homebasex,GetTerrainHeight(homebasex,homebasey),homebasey}
    local ratio=0.35
    while not aiBrain.cmanager.categoryspend or GetGameTimeSeconds()<250 do
        WaitSeconds(10)
    end
    while not aiBrain.defeat do
        local mexes1 = aiBrain:GetListOfUnits(categories.MASSEXTRACTION - categories.TECH3, true, false)
        local time=GetGameTimeSeconds()
        --if aiBrain.EcoManagerPowerStateCheck(aiBrain) then
        --    WaitSeconds(4)
        --    continue
        --end
        local currentupgradecost=0
        local mexes={}
        for i,v in mexes1 do
            --if not v.UCost then
            if v:IsUnitState('Upgrading') and v.UCost then currentupgradecost=currentupgradecost+v.UCost table.remove(mexes,i) continue end
            local spende=GetConsumptionPerSecondEnergy(v)
            local producem=GetProductionPerSecondMass(v)
            local unit=v:GetBlueprint()
            if spende<unit.Economy.MaintenanceConsumptionPerSecondEnergy and spende>0 then
                v.UEmult=spende/unit.Economy.MaintenanceConsumptionPerSecondEnergy
            else
                v.UEmult=1
            end
            if producem>unit.Economy.ProductionPerSecondMass then
                v.UMmult=producem/unit.Economy.ProductionPerSecondMass
            else
                v.UMmult=1
            end
            local uunit=aiBrain:GetUnitBlueprint(unit.General.UpgradesTo)
            local mcost=uunit.Economy.BuildCostMass/uunit.Economy.BuildTime*unit.Economy.BuildRate
            local ecost=uunit.Economy.BuildCostEnergy/uunit.Economy.BuildTime*unit.Economy.BuildRate
            v.UCost=mcost
            v.UECost=ecost
            v.TMCost=uunit.Economy.BuildCostMass
            v.Uupgrade=unit.General.UpgradesTo
        --end
            if not v.UAge then
                v.UAge=time
            end
            v.TAge=1/(1+math.min(120,time-v.UAge)/120)
            table.insert(mexes,v)
        end
        --if 10>aiBrain.cmanager.income.r.m*ratio then
        --    WaitSeconds(3)
        --    continue
        --end
        if currentupgradecost<aiBrain.cmanager.income.r.m*ratio then
            table.sort(mexes,function(a,b) return (1+VDist3Sq(a:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,a:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*a.UCost*a.TMCost*a.UECost*a.UEmult*a.TAge/a.UMmult/a.UMmult<(1+VDist3Sq(b:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,b:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*b.UCost*b.TMCost*b.UECost*b.UEmult*b.TAge/b.UMmult/b.UMmult end)
            local startval=aiBrain.cmanager.income.r.m*ratio-currentupgradecost
            --local starte=aiBrain.cmanager.income.r.e*1.3-aiBrain.cmanager.spend.e
            for _,v in mexes do
                if startval>0 then
                    IssueUpgrade({v}, v.Uupgrade)
                    startval=startval-v.UCost
                else
                    break
                end
            end
        end
        WaitSeconds(4)
    end
end]]

function MexUpgradeManagerRNG(aiBrain)
    local homebasex,homebasey = aiBrain:GetArmyStartPos()
    local VDist3Sq = VDist3Sq
    local homepos = {homebasex,GetTerrainHeight(homebasex,homebasey),homebasey}
    local ratio=0.35
    local currentlyUpgrading = 0
    while not aiBrain.defeat or GetGameTimeSeconds()<250 do
        local extractors = aiBrain:GetListOfUnits(categories.MASSEXTRACTION * (categories.TECH1 + categories.TECH2), true)


        coroutine.yield(40)
    end
    while not aiBrain.defeat do
        local mexes1 = aiBrain:GetListOfUnits(categories.MASSEXTRACTION - categories.TECH3, true, false)
        local time=GetGameTimeSeconds()
        --[[if aiBrain.EcoManagerPowerStateCheck(aiBrain) then
            WaitSeconds(4)
            continue
        end]]
        local currentupgradecost=0
        local mexes={}
        for i,v in mexes1 do
            --if not v.UCost then
            if v:IsUnitState('Upgrading') and v.UCost then currentupgradecost=currentupgradecost+v.UCost table.remove(mexes,i) continue end
            local spende=GetConsumptionPerSecondEnergy(v)
            local producem=GetProductionPerSecondMass(v)
            local unit=v:GetBlueprint()
            if spende<unit.Economy.MaintenanceConsumptionPerSecondEnergy and spende>0 then
                v.UEmult=spende/unit.Economy.MaintenanceConsumptionPerSecondEnergy
            else
                v.UEmult=1
            end
            if producem>unit.Economy.ProductionPerSecondMass then
                v.UMmult=producem/unit.Economy.ProductionPerSecondMass
            else
                v.UMmult=1
            end
            local uunit=aiBrain:GetUnitBlueprint(unit.General.UpgradesTo)
            local mcost=uunit.Economy.BuildCostMass/uunit.Economy.BuildTime*unit.Economy.BuildRate
            local ecost=uunit.Economy.BuildCostEnergy/uunit.Economy.BuildTime*unit.Economy.BuildRate
            v.UCost=mcost
            v.UECost=ecost
            v.TMCost=uunit.Economy.BuildCostMass
            v.Uupgrade=unit.General.UpgradesTo
        --end
            if not v.UAge then
                v.UAge=time
            end
            v.TAge=1/(1+math.min(120,time-v.UAge)/120)
            table.insert(mexes,v)
        end
        --[[if 10>aiBrain.cmanager.income.r.m*ratio then
            WaitSeconds(3)
            continue
        end]]
        if currentupgradecost<aiBrain.cmanager.income.r.m*ratio then
            table.sort(mexes,function(a,b) return (1+VDist3Sq(a:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,a:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*a.UCost*a.TMCost*a.UECost*a.UEmult*a.TAge/a.UMmult/a.UMmult<(1+VDist3Sq(b:GetPosition(),homepos)/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*(1-VDist3Sq(aiBrain.emanager.enemy.Position,b:GetPosition())/ScenarioInfo.size[2]/ScenarioInfo.size[2]/2)*b.UCost*b.TMCost*b.UECost*b.UEmult*b.TAge/b.UMmult/b.UMmult end)
            local startval=aiBrain.cmanager.income.r.m*ratio-currentupgradecost
            --local starte=aiBrain.cmanager.income.r.e*1.3-aiBrain.cmanager.spend.e
            for _,v in mexes do
                if startval>0 then
                    IssueUpgrade({v}, v.Uupgrade)
                    startval=startval-v.UCost
                else
                    break
                end
            end
        end
        coroutine.yield(40)
    end
end

AIFindDynamicExpansionPointRNG = function(aiBrain, locationType, radius, threatMin, threatMax, threatRings, threatType)
    local pos = aiBrain:PBMGetLocationCoords(locationType)
    local retPos, retName
    radius = radius * radius

    if not pos then
        return false
    else
       --RNGLOG('Location Pos is '..repr(pos))
    end
   --RNGLOG('Checking if Dynamic Expansions Table Exist')
    if aiBrain.BrainIntel.DynamicExpansionPositions then
        for k, v in aiBrain.BrainIntel.DynamicExpansionPositions do
           --RNGLOG('Dynamic Expansion data '..repr(v))
            if not aiBrain.BuilderManagers[v.Zone] then
               --RNGLOG('No existing builder manager for zone')
               --RNGLOG('Distance is '..VDist3Sq(pos, v.Position)..' needs to be under '..radius)
                if VDist3Sq(pos, v.Position) < radius and GetThreatAtPosition( aiBrain, v.Position, threatRings, true, threatType) < threatMax then
                    retPos = v.Position
                    retName = v.Zone
                    break
                end
            end
        end
    else
       --RNGLOG('Dynamic Expansions table doesnt exist')
    end
    if retPos then
        return retPos, retName
    end
    return false
end
--[[
function GetBuildLocationRNG(aiBrain, buildingTemplate, baseTemplate, buildUnit, eng, adjacent, category, radius, relative)
    -- A small note that caught me out.
    -- Always set the engineers position to zero in the build location otherwise youll get buildings are super strange angles
    -- and you wont understand why. I think the 3rd param is actually rotation not height.
    --RNGLOG('GetBuildLocationRNG Function')
    local buildLocation = false
    local whatToBuild = aiBrain:DecideWhatToBuild(eng, buildUnit, buildingTemplate)
    local engPos = eng:GetPosition()
    if adjacent then
        --RNGLOG('Request for Adjacency')
        local testUnits  = aiBrain:GetUnitsAroundPoint(category, engPos, radius, 'Ally')
        --RNGLOG('Test units have '..RNGGETN(testUnits)..' number of units')
        local index = aiBrain:GetArmyIndex()
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildUnit })
        local closeUnits = {}
        for _, v in testUnits do
            if not v.Dead and not v:IsBeingBuilt() and v:GetAIBrain():GetArmyIndex() == index then
                table.insert(closeUnits, v)
            end
        end
        if RNGGETN(closeUnits) > 0 then
            for k,v in closeUnits do
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
                        if VDist2Sq(testPos[1],testPos[2],engPos[1],engPos[3])>3 and testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos)
                        end
                        if VDist2Sq(testPos2[1],testPos2[2],engPos[1],engPos[3])>3 and testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos2)
                        end
                    end
                    -- Sides of unit
                    for i=0,((targetSize.SkirtSizeZ/2)-1) do
                        local testPos = { targetPos[1]+targetSize.SkirtSizeX + (unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i * 2), 0 }
                        local testPos2 = { targetPos[1]-(unitSize.SkirtSizeX/2), targetPos[3] + 1 + (i*2), 0 }
                        if VDist2Sq(testPos[1],testPos[2],engPos[1],engPos[3])>3 and testPos[1] > 8 and testPos[1] < ScenarioInfo.size[1] - 8 and testPos[2] > 8 and testPos[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos)
                        end
                        if VDist2Sq(testPos2[1],testPos2[2],engPos[1],engPos[3])>3 and testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                            table.insert(template[1], testPos2)
                        end
                    end
                end
            end
            --RNGLOG('template contents '..repr(template))
            local location = aiBrain:FindPlaceToBuild(buildUnit, whatToBuild, template, false, eng, nil, engPos[1], engPos[3])
            --if location and relative then
            --    local relativeLoc = {location[1], 0, location[2]}
            --    buildLocation = {relativeLoc[1] + engPos[1], relativeLoc[3] + engPos[3], 0}
            --else
            if location then
                buildLocation = location
            end
        end
    else
        --RNGLOG('Request for Non Adjacency')
        --RNGLOG('buildUnit '..buildUnit)
        --RNGLOG('whatToBuild '..whatToBuild)
        local location = aiBrain:FindPlaceToBuild(buildUnit, whatToBuild, baseTemplate, relative, eng, nil, engPos[1], engPos[3])
        if location and relative then
            local relativeLoc = {location[1], 0, location[2]}
            buildLocation = {relativeLoc[1] + engPos[1], relativeLoc[3] + engPos[3], 0}
        else
            buildLocation = location
        end
    end
    if buildLocation then
       --RNGLOG('Build Location returned '..repr(buildLocation))
       --RNGLOG('What to build returned '..repr(whatToBuild))
        return buildLocation, whatToBuild
    end
   --LOG('GetBuildLocationRNG is false')
    return false
end]]

function GetBuildLocationRNG(aiBrain, buildingTemplate, baseTemplate, buildUnit, eng, adjacent, category, radius, relative)
    -- A small note that caught me out.
    -- Always set the engineers position to zero in the build location otherwise youll get buildings are super strange angles
    -- and you wont understand why. I think the 3rd param is actually rotation not height.
    --RNGLOG('GetBuildLocationRNG Function')
    local buildLocation = false
    local whatToBuild = aiBrain:DecideWhatToBuild(eng, buildUnit, buildingTemplate)
    local engPos = eng:GetPosition()
    local function normalposition(vec)
        return {vec[1],GetSurfaceHeight(vec[1],vec[2]),vec[2]}
    end
    local function heightbuildpos(vec)
        return {vec[1],vec[2],0}
    end
    
    if adjacent then
        local unitSize = aiBrain:GetUnitBlueprint(whatToBuild).Physics
        local testUnits  = aiBrain:GetUnitsAroundPoint(category, engPos, radius, 'Ally')
        local index = aiBrain:GetArmyIndex()
        local closeUnits = {}
        for _, v in testUnits do
            if not v.Dead and not v:IsBeingBuilt() and v:GetAIBrain():GetArmyIndex() == index then
                table.insert(closeUnits, v)
            end
        end
        local template = {}
        table.insert(template, {})
        table.insert(template[1], { buildUnit })
        for _,unit in closeUnits do
            local targetSize = unit:GetBlueprint().Physics
            local targetPos = unit:GetPosition()
            local differenceX=math.abs(targetSize.SkirtSizeX-unitSize.SkirtSizeX)
            local offsetX=math.floor(differenceX/2)
            local differenceZ=math.abs(targetSize.SkirtSizeZ-unitSize.SkirtSizeZ)
            local offsetZ=math.floor(differenceZ/2)
            local offsetfactory=0
            if EntityCategoryContains(categories.FACTORY, unit) and (buildUnit=='T1LandFactory' or buildUnit=='T2SupportLandFactory' or buildUnit=='T3SupportLandFactory') then
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
                        return heightbuildpos(testPos), whatToBuild
                    end
                end
                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                    --table.insert(template[1], testPos2)
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                        if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) then
                            return heightbuildpos(testPos), whatToBuild
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
                        if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) then
                            return heightbuildpos(testPos), whatToBuild
                        end
                    end
                end
                if testPos2[1] > 8 and testPos2[1] < ScenarioInfo.size[1] - 8 and testPos2[2] > 8 and testPos2[2] < ScenarioInfo.size[2] - 8 then
                    --ForkThread(RNGtemporaryrenderbuildsquare,testPos2,unitSize.SkirtSizeX,unitSize.SkirtSizeZ)
                    --table.insert(template[1], testPos2)
                    if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos2)) then
                        if CanBuildStructureAt(aiBrain, whatToBuild, normalposition(testPos)) then
                            return heightbuildpos(testPos), whatToBuild
                        end
                    end
                end
            end
        end
    else
        -- build near the base the engineer is part of, rather than the engineer location
        --RNGLOG('Request for Non Adjacency')
        --RNGLOG('buildUnit '..buildUnit)
        --RNGLOG('whatToBuild '..whatToBuild)
        local location = aiBrain:FindPlaceToBuild(buildUnit, whatToBuild, baseTemplate, relative, eng, nil, engPos[1], engPos[3])
        if location and relative then
            local relativeLoc = {location[1], 0, location[2]}
            return {relativeLoc[1] + engPos[1], relativeLoc[3] + engPos[3], 0}, whatToBuild
        else
            return location, whatToBuild
        end
    end
    return false
end


function GetAngleRNG(myX, myZ, myDestX, myDestZ, theirX, theirZ)
    --[[ Softles gave me this to help improve the mass point retreat mechanic
       If (myX,myZ) is the platoon, (myDestX,myDestZ) the mass point, and (theirX, theirZ) the enemy threat
       Then 0 => mass point in same direction as enemy, 1 => mass point in complete opposite direction
       You, your dest, and them form a triangle.
       First work out side lengths
    ]]
    local aSq = (myX - myDestX)*(myX - myDestX) + (myZ - myDestZ)*(myZ - myDestZ)
    local bSq = (myX - theirX)*(myX - theirX) + (myZ - theirZ)*(myZ - theirZ)
    local cSq = (myDestX - theirX)*(myDestX - theirX) + (myDestZ - theirZ)*(myDestZ - theirZ)
    -- Quick check to see if anything is a 0 length (a problem, since it then wouldn't be a triangle)
    if aSq == 0 or bSq == 0 or cSq == 0 then
        return 0
    end
    -- Now use cosine rule to get angle
    -- c^2 = b^2 + a^2 - 2ab*cos(angle) => angle = acos((a^2+b^2-c^2)/2ab)
    local prepStep = (bSq + aSq - cSq)/(2*math.sqrt(aSq*bSq))
    -- Quickly check it is between 1 and -1, if it gets rounded (because computers) to -1.0000001 then we'd throw an error (bad!)
    if prepStep > 1 then
        return 0
    elseif prepStep < -1 then
        return 1
    end
    local angle = math.acos(prepStep)
    -- Now normalise into a [0 to 1] value
    return angle/math.pi
end

function ClosestResourceMarkersWithinRadius(aiBrain, pos, markerType, radius, canBuild, maxThreat, threatType)
    local adaptiveResourceMarkers = GetMarkersRNG()
    local markerTable = {}
    local radiusLimit = radius * radius
    for k, v in adaptiveResourceMarkers do
        if v.type == markerType then
            RNGINSERT(markerTable, {Position = v.position, Name = k, Distance = VDist2Sq(pos[1], pos[3], v.position[1], v.position[3])})
        end
    end
    table.sort(markerTable, function(a,b) return a.Distance < b.Distance end)
    for k, v in markerTable do
        if v.Distance <= radiusLimit then
            --RNGLOG('Marker is within distance with '..v.Distance)
            if canBuild then
                if CanBuildStructureAt(aiBrain, 'ueb1102', v.Position) then
                    --RNGLOG('We can build on this hydro '..repr(v.Position))
                    if maxThreat and threatType then
                        --RNGLOG('Threat at position is '..GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType))
                        --RNGLOG('Max Threat is')
                        if GetThreatAtPosition(aiBrain, v.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, threatType) < maxThreat then
                            --RNGLOG('Return true with threat check')
                            return v
                        end
                    else
                        return v
                    end
                end
            else
                return v
            end
            
        end
    end
    --RNGLOG('ClosestMarkersWithin radius failing '..radius)
    return false
end

function GetBomberGroundAttackPosition(aiBrain, platoon, target, platoonPosition, targetPosition, targetDistance)
    local function DrawCirclePoints(points, radius, center)
        local circlePoints = {}
        local slice = 2 * math.pi / points
        for i=1, points do
            local angle = slice * i
            local newX = center[1] + radius * math.cos(angle)
            local newY = center[3] + radius * math.sin(angle)
            table.insert(circlePoints, { newX, 0 , newY})
        end
        return circlePoints
    end

    local pointTable = DrawCirclePoints(8, platoon.PlatoonStrikeRadius, targetPosition)
    local maxDamage = ALLBPS[target.UnitId].Economy.BuildCostMass
    local setPointPos = false
    -- Check radius of target position to set the minimum damage
    local enemiesAroundTarget = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE, targetPosition, platoon.PlatoonStrikeRadius + 4, 'Enemy')
    local damage = 0
    for _, unit in enemiesAroundTarget do
        if not unit.Dead then
            local unitPos = unit:GetPosition()
            local damageRadius = (ALLBPS[unit.UnitId].SizeX or 1 + ALLBPS[unit.UnitId].SizeZ or 1) / 4
           --LOG('Unit is '..unit.UnitId)
           --LOG('unitPos is '..repr(unitPos))
           --LOG('Distance between units '..VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]))
           --LOG('strike radius + damage radius '..(platoon.PlatoonStrikeRadius + damageRadius))
            if VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]) <= (platoon.PlatoonStrikeRadius * 2 + damageRadius) then
                if platoon.PlatoonStrikeDamage > ALLBPS[unit.UnitId].Defense.MaxHealth or platoon.PlatoonStrikeDamage > (unit:GetHealth() / 3) then
                    damage = damage + ALLBPS[unit.UnitId].Economy.BuildCostMass
                else
                   --LOG('Strike will not kill target or 3 passes')
                end
            end
        end
       --LOG('Current potential strike damage '..damage)
    end
    maxDamage = damage
    -- Now look at points for a better strike target
   --LOG('StrikeForce Looking for better strike target position')
    for _, pointPos in pointTable do
       --LOG('pointPos is '..repr(pointPos))
       --LOG('pointPos distance from targetpos is '..VDist2(pointPos[1],pointPos[2],targetPosition[1],targetPosition[3]))
        
        local damage = 0
        local enemiesAroundTarget = GetUnitsAroundPoint(aiBrain, categories.STRUCTURE, {pointPos[1], 0, pointPos[3]}, platoon.PlatoonStrikeRadius + 4, 'Enemy')
       --LOG('Table count of enemies at pointPos '..table.getn(enemiesAroundTarget))
        for _, unit in enemiesAroundTarget do
            if not unit.Dead then
                local unitPos = unit:GetPosition()
                local damageRadius = (ALLBPS[unit.UnitId].SizeX or 1 + ALLBPS[unit.UnitId].SizeZ or 1) / 4
               --LOG('Unit is '..unit.UnitId)
               --LOG('unitPos is '..repr(unitPos))
               --LOG('Distance between units '..VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]))
               --LOG('strike radius + damage radius '..(platoon.PlatoonStrikeRadius + damageRadius))
                if VDist2(targetPosition[1], targetPosition[3], unitPos[1], unitPos[3]) <= (platoon.PlatoonStrikeRadius * 2 + damageRadius) then
                    if platoon.PlatoonStrikeDamage > ALLBPS[unit.UnitId].Defense.MaxHealth or platoon.PlatoonStrikeDamage > (unit:GetHealth() / 3) then
                        damage = damage + ALLBPS[unit.UnitId].Economy.BuildCostMass
                    else
                       --LOG('Strike will not kill target or 3 passes')
                    end
                end
            end
           --LOG('Initial strike damage '..damage)
        end
       --LOG('Current maxDamage is '..maxDamage)
        if damage > maxDamage then
           --LOG('StrikeForce found better strike damage of '..damage)
            maxDamage = damage
            setPointPos = pointPos
        end
    end
    if setPointPos then
        setPointPos = {setPointPos[1], GetSurfaceHeight(setPointPos[1], setPointPos[3]), setPointPos[3]} 
        local movePoint = lerpy(platoonPosition, targetPosition, {targetDistance, targetDistance - (platoon.PlatoonStrikeRadiusDistance + 25)})
        platoon:ForkThread(platoon.DrawTargetRadius, movePoint, platoon.PlatoonStrikeRadius)
        platoon:ForkThread(platoon.DrawTargetRadius, setPointPos, platoon.PlatoonStrikeRadius)
        return setPointPos, movePoint
    end
    return false
end

-- need to ask maudlin about these unless I want to reinvent the rather cleverly done wheel here

function GetBomberRange(oUnit)
    -- Gets  + 25 added to the return value. Assume to give the strat a better runup?
    local oBP = oUnit:GetBlueprint()
    local iRange = 0
    for sWeaponRef, tWeapon in oBP.Weapon do
        if tWeapon.WeaponCategory == 'Bomb' or tWeapon.WeaponCategory == 'Direct Fire' then
            if (tWeapon.MaxRadius or 0) > iRange then
                iRange = tWeapon.MaxRadius
            end
        end
    end
    return iRange
end

function GetAngleFromAToB(tLocA, tLocB)
    --Returns an angle 0 = north, 90 = east, etc. based on direction of tLocB from tLocA
    local iTheta = math.atan(math.abs(tLocA[3] - tLocB[3]) / math.abs(tLocA[1] - tLocB[1])) * 180 / math.pi
    if tLocB[1] > tLocA[1] then
        if tLocB[3] > tLocA[3] then
            return 90 + iTheta
        else return 90 - iTheta
        end
    else
        if tLocB[3] > tLocA[3] then
            return 270 - iTheta
        else return 270 + iTheta
        end
    end
end

function GetClosestShieldProtectingTargetRNG(attackingUnit, targetUnit, attackingPosition)
    if not targetUnit or not attackingUnit then
        return false
    end
    local blockingList = {}

    -- If targetUnit is within the radius of any shields, the shields need to be destroyed.
    local aiBrain
    local aPos = attackingUnit:GetPosition()
    if attackingUnit then
        aiBrain = attackingUnit:GetAIBrain()
        aPos = attackingUnit:GetPosition()
    elseif attackingPosition then
        aPos = attackingPosition
    end

    local tPos = targetUnit:GetPosition()
    
    local shields = aiBrain:GetUnitsAroundPoint(categories.SHIELD * categories.STRUCTURE, targetUnit:GetPosition(), 50, 'Enemy')
    for _, shield in shields do
        if not shield.Dead then
            local shieldPos = shield:GetPosition()
            local shieldSizeSq = GetShieldRadiusAboveGroundSquaredRNG(shield)

            if VDist2Sq(tPos[1], tPos[3], shieldPos[1], shieldPos[3]) < shieldSizeSq then
                table.insert(blockingList, shield)
            end
        end
    end

    -- Return the closest blocking shield
    local closest = false
    local closestDistSq = 999999
    local closestHealth = 0
    for _, shield in blockingList do
        if shield and not shield.Dead then
            local shieldPos = shield:GetPosition()
            local distSq = VDist2Sq(aPos[1], aPos[3], shieldPos[1], shieldPos[3])

            if distSq < closestDistSq then
                closest = shield
                closestDistSq = distSq
            end
        end
    end
    local shieldHealth = 0
    if closest.MyShield then
        shieldHealth = closest.MyShield:GetHealth()
    end
    return closest, shieldHealth
end


function ValidateMainBase(platoon, squad, aiBrain)
    local target = false
    local TargetSearchPriorities = {
        categories.EXPERIMENTAL * categories.LAND,
        categories.MASSEXTRACTION,
        categories.ENERGYPRODUCTION,
        categories.ENERGYSTORAGE,
        categories.MASSFABRICATION,
        categories.STRUCTURE,
        categories.ALLUNITS,
    }
    if platoon.Zone and platoon.PlatoonData.LocationType then
        if platoon.Zone == aiBrain.BuilderManagers[platoon.PlatoonData.LocationType].Zone then
            if aiBrain.Brain.Zones.Land.zones[platoon.Zone].enemythreat > 0 then
                target = AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, platoon:GetPlatoonPosition(), 'Attack', 120, categories.LAND, TargetSearchPriorities)
            end
            if not target then
                for _, v in aiBrain.Zones.Land.zones[platoon.Zone].edges do
                    if v.zone.enemythreat > 0 then
                        target = AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, platoon:GetPlatoonPosition(), 'Attack', 120, categories.LAND, TargetSearchPriorities)
                    end
                    if target then
                        break
                    end
                end
            end
        end
    end
    return target
end

-- Borrowed this from Balth I think.
function CalculatedDPSRNG(weapon)
    -- Base values
    local MathMax = math.max
    local MathFloor = math.floor
    local ProjectileCount
    --LOG('Running Calculated DPS')
    --LOG('Weapon '..repr(weapon))
    if weapon.MuzzleSalvoDelay == 0 then
        ProjectileCount = MathMax(1, RNGGETN(weapon.RackBones[1].MuzzleBones or {'nehh'} ) )
    else
        ProjectileCount = (weapon.MuzzleSalvoSize or 1)
    end
    if weapon.RackFireTogether then
        ProjectileCount = ProjectileCount * MathMax(1, RNGGETN(weapon.RackBones or {'nehh'} ) )
    end
    -- Game logic rounds the timings to the nearest tick --  MathMax(0.1, 1 / (weapon.RateOfFire or 1)) for unrounded values
    local DamageInterval = MathFloor((MathMax(0.1, 1 / (weapon.RateOfFire or 1)) * 10) + 0.5) / 10 + ProjectileCount * (MathMax(weapon.MuzzleSalvoDelay or 0, weapon.MuzzleChargeDelay or 0) * (weapon.MuzzleSalvoSize or 1) )
    local Damage = ((weapon.Damage or 0) + (weapon.NukeInnerRingDamage or 0)) * ProjectileCount * (weapon.DoTPulses or 1)

    -- Beam calculations.
    if weapon.BeamLifetime and weapon.BeamLifetime == 0 then
        -- Unending beam. Interval is based on collision delay only.
        DamageInterval = 0.1 + (weapon.BeamCollisionDelay or 0)
    elseif weapon.BeamLifetime and weapon.BeamLifetime > 0 then
        -- Uncontinuous beam. Interval from start to next start.
        DamageInterval = DamageInterval + weapon.BeamLifetime
        -- Damage is calculated as a single glob, beam weapons are typically underappreciated
        Damage = Damage * (weapon.BeamLifetime / (0.1 + (weapon.BeamCollisionDelay or 0)))
    end

    return Damage * (1 / DamageInterval) or 0
end

--[[
RNGLOG('Mex Upgrade Mass in storage is '..GetEconomyStored(aiBrain, 'MASS'))
RNGLOG('Unit Being built BP is '..unit.UnitBeingBuilt:GetBlueprint().BlueprintId)
RNGLOG('upgradeID is '..upgradeID)
if not unit.Dead and (unit.UnitBeingBuilt:GetBlueprint().BlueprintId ~= upgradeID) then
    if upgradePauseLimit < 5 and (GetEconomyStored(aiBrain, 'MASS') <= 20 or GetEconomyStored(aiBrain, 'ENERGY') <= 200) then
       --RNGLOG('Extractor upgrade economy low')
        upgradePauseLimit = upgradePauseLimit + 1
        if not unit:IsPaused() then
           --RNGLOG('Extractor Paused')
            unit:SetPaused( true )
        end
    elseif unit:IsPaused() then
       --RNGLOG('Extractor UnPaused')
        unit:SetPaused( false )
    end
end]]
