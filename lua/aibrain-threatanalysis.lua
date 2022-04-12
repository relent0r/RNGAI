
WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibrain.lua' )
local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetMOARadii()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
local Mapping = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local DebugArrayRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').DebugArrayRNG
local AIUtils = import('/lua/ai/AIUtilities.lua')
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local PlatoonGenerateSafePathToRNG = import('/lua/AI/aiattackutilities.lua').PlatoonGenerateSafePathToRNG
local GetClosestPathNodeInRadiusByLayerRNG = import('/lua/AI/aiattackutilities.lua').GetClosestPathNodeInRadiusByLayerRNG
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GiveResource = moho.aibrain_methods.GiveResource
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatsAroundPosition = moho.aibrain_methods.GetThreatsAroundPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local VDist2Sq = VDist2Sq
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGINSERT = table.insert
local RNGGETN = table.getn
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

-- debugging tools
local debug = false 

-- keep track of all the debug threads
local debugThreads = { }

local function DebugCleanup()

    -- keep reference to ourself
    local self = import("/mods/RNGAI/lua/aibrain-threatanalysis.lua")

    while true do 

        -- find reference to ourself
        local other = import("/mods/RNGAI/lua/aibrain-threatanalysis.lua")

        -- references do not match: reload detected, we are no longer ourself!
        if self ~= other then 
            LOG("Removing old debug functions")
            ForkThread(
                function()
                    for k, thread in debugThreads do 
                        KillThread(thread)
                    end
                end
            )
        end

        coroutine.yield(1)
    end
end

local function VisualizeThreatLocationsThread (brain)
    local color = "ffffff"
    while true do 
        for k, loc in brain.debugThreatLocations do 
            local position = { loc[1], 0, loc[2] }
            position[2] = GetSurfaceHeight(loc[1], loc[2])
            DrawCircle(position, 10, color)
        end

        coroutine.yield(1)
    end
end

if debug then 

    for k, brain in ArmyBrains do 
        brain.debugThreatLocations = { }
        table.insert(debugThreads, ForkThread(VisualizeThreatLocationsThread, brain))
    end

    table.insert(debugThreads, ForkThread(DebugCleanup))
end

-- change to upvalue scope for performance
local MathMax = math.max

-- pre-compute categories for performance
local CategoriesStructuresNotMex = categories.STRUCTURE - categories.TECH1 - categories.WALL - categories.MASSEXTRACTION

local CategoriesEnergy = categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesDefense = categories.DEFENSE * (categories.TECH2 + categories.TECH3)
local CategoriesStrategic = categories.STRATEGIC * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesIntelligence = categories.INTELLIGENCE * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL)
local CategoriesFactory = categories.FACTORY * (categories.TECH2 + categories.TECH3 ) - categories.SUPPORTFACTORY - categories.EXPERIMENTAL - categories.CRABEGG - categories.CARRIER
local CategoriesShield = categories.SHIELD * categories.STRUCTURE

local function GetShieldRadiusAboveGroundSquaredRNG(shield)
    local BP = shield:GetBlueprint().Defense.Shield
    local width = BP.ShieldSize
    local height = BP.ShieldVerticalOffset

    return width * width - height * height
end

local function ShieldProtectingTargetRNG(aiBrain, targetUnit, shields)

    -- if no target unit, then we can skip
    if not targetUnit then
        return false
    end
    
    -- defensive programming
    shields = shields or GetUnitsAroundPoint(aiBrain, CategoriesShield, targetUnit:GetPosition(), 50, 'Enemy')

    -- determine if target unit is part of some shield
    local tPos = targetUnit:GetPosition()
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

local LookupAirThreat = { }
local LookupLandThreat = { }

TacticalThreatAnalysisRNG = function(self, ALLBPS)

    LOG("Started analysis for: " .. self.Nickname)
    local startedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()

    self.EnemyIntel.DirectorData = {
        DefenseCluster = {},
        Strategic = {},
        Energy = {},
        Intel = {},
        Defense = {},
        Factory = {},
        Mass = {},
        Combat = {},
    }

    local energyUnits = {}
    local strategicUnits = {}
    local defensiveUnits = {}
    local intelUnits = {}
    local factoryUnits = {}
    local gameTime = GetGameTimeSeconds()
    local scanRadius = 0
    local IMAPSize = 0
    local maxmapdimension = MathMax(ScenarioInfo.size[1],ScenarioInfo.size[2])
    self.EnemyIntel.EnemyFireBaseDetected = false
    self.EnemyIntel.EnemyAirFireBaseDetected = false
    self.EnemyIntel.EnemyFireBaseTable = {}

    if maxmapdimension == 256 then
        scanRadius = 11.5
        IMAPSize = 16
    elseif maxmapdimension == 512 then
        scanRadius = 22.5
        IMAPSize = 32
    elseif maxmapdimension == 1024 then
        scanRadius = 45.0
        IMAPSize = 64
    elseif maxmapdimension == 2048 then
        scanRadius = 89.5
        IMAPSize = 128
    else
        scanRadius = 180.0
        IMAPSize = 256
    end

    local v = Vector(0, 0, 0)
    
    if RNGGETN(self.EnemyIntel.EnemyThreatLocations) > 0 then

        if debug then 

            -- remove all previous entries
            for k, v in self.debugThreatLocations do 
                self.debugThreatLocations[k] = nil
            end

            -- populate it again
            for k, threat in self.EnemyIntel.EnemyThreatLocations do
                self.debugThreatLocations[k] = threat.Position 
            end
        end

        local LookupAirThreat = { }
        local LookupLandThreat = { }

        -- pre-process all threat to populate lookup tables for anti air and land
        for k, threat in self.EnemyIntel.EnemyThreatLocations do
            if threat.ThreatType == "AntiAir" then 
                LookupAirThreat[threat.Position[1]] = LookupAirThreat[threat.Position[1]] or { }
                LookupAirThreat[threat.Position[1]][threat.Position[2]] = threat.Threat
            elseif threat.ThreatType == "Land" then 
                LookupLandThreat[threat.Position[1]] = LookupLandThreat[threat.Position[1]] or { }
                LookupLandThreat[threat.Position[1]][threat.Position[2]] = threat.Threat
            end
        end

        if debug then 
            -- print out all the air threats found
            for xi, x in LookupAirThreat do 
                for zi, t in x do 
                    LOG(string.format("Air threat at (%f, %f) = %f", xi, zi, t))
                end
            end

            -- print out all the land threats found
            for xi, x in LookupLandThreat do 
                for zi, t in x do 
                    LOG(string.format("Land threat at (%f, %f) = %f", xi, zi, t))
                end
            end
        end

        for k, threat in self.EnemyIntel.EnemyThreatLocations do

            -- INFO: threat = { table: 22C1FF50 
            -- INFO:   EnemyBaseRadius=true,
            -- INFO:   InsertTime=676.10003662109,
            -- INFO:   Position={ table: 22C1F168  400, 400 },
            -- INFO:   PositionOnWater=false,
            -- INFO:   Threat=159,
            -- INFO:   ThreatType="StructuresNotMex"
            -- INFO: }

            if (gameTime - threat.InsertTime) < 25 and threat.ThreatType == 'StructuresNotMex' then

                -- position format as used by the engine
                v[1] = threat.Position[1]
                v[2] = 0 
                v[3] = threat.Position[2]

                -- retrieve units and shields that are in or overlap with the iMAP cell
                local unitsAtLocation = GetUnitsAroundPoint(self, CategoriesStructuresNotMex, v, scanRadius, 'Enemy')
                local shieldsAtLocation = GetUnitsAroundPoint(self, CategoriesShield, v, 50 + scanRadius, 'Enemy')

                for s, unit in unitsAtLocation do
                    local unitIndex = unit:GetAIBrain():GetArmyIndex()
                    if not ArmyIsCivilian(unitIndex) then
                        if EntityCategoryContains( CategoriesEnergy, unit) then
                            --RNGLOG('Inserting Enemy Energy Structure '..unit.UnitId)
                            RNGINSERT(energyUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel * 2, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(self, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesDefense, unit) then
                            --RNGLOG('Inserting Enemy Defensive Structure '..unit.UnitId)
                            RNGINSERT(
                                defensiveUnits, { 
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(self, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesStrategic, unit) then
                            --RNGLOG('Inserting Enemy Strategic Structure '..unit.UnitId)
                            RNGINSERT(strategicUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(self, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesIntelligence, unit) then
                            --RNGLOG('Inserting Enemy Intel Structure '..unit.UnitId)
                            RNGINSERT(intelUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(self, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        elseif EntityCategoryContains( CategoriesFactory, unit) then
                            --RNGLOG('Inserting Enemy Intel Structure '..unit.UnitId)
                            RNGINSERT(factoryUnits, {
                                EnemyIndex = unitIndex, 
                                Value = ALLBPS[unit.UnitId].Defense.EconomyThreatLevel, 
                                HP = unit:GetHealth(), 
                                Object = unit, 
                                Shielded = ShieldProtectingTargetRNG(self, unit, shieldsAtLocation), 
                                IMAP = threat.Position, 
                                Air = LookupAirThreat[threat.Position[1]][threat.Position[2]] or 0, 
                                Land = LookupLandThreat[threat.Position[1]][threat.Position[2]] or 0 
                            })
                        end
                    end
                end
            end
        end
    end

    if RNGGETN(defensiveUnits) > 0 then
        for k, unit in defensiveUnits do
            for q, threat in self.EnemyIntel.EnemyThreatLocations do
                if not threat.LandDefStructureCount then
                    threat.LandDefStructureCount = 0
                end
                if not threat.AirDefStructureCount then
                    threat.AirDefStructureCount = 0
                end
                if table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'AntiAir' then 
                    unit.Air = threat.Threat
                elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'Land' then
                    unit.Land = threat.Threat
                elseif table.equal(unit.IMAP,threat.Position) and threat.ThreatType == 'StructuresNotMex' then
                    if ALLBPS[unit.Object.UnitId].Defense.SurfaceThreatLevel > 0 then
                        threat.LandDefStructureCount = threat.LandDefStructureCount + 1
                    elseif ALLBPS[unit.Object.UnitId].Defense.AirThreatLevel > 0 then
                        threat.AirDefStructureCount = threat.AirDefStructureCount + 1
                    end
                    if threat.LandDefStructureCount + threat.AirDefStructureCount > 5 then
                        self.EnemyIntel.EnemyFireBaseDetected = true
                    end
                    if self.EnemyIntel.EnemyFireBaseDetected then
                        if not self.EnemyIntel.EnemyFireBaseTable[q] then
                            self.EnemyIntel.EnemyFireBaseTable[q] = {}
                            self.EnemyIntel.EnemyFireBaseTable[q] = { 
                                EnemyIndex = unit.EnemyIndex, 
                                Location = {unit.IMAP[1], 0, unit.IMAP[2]}, 
                                Shielded = unit.Shielded, 
                                Air = GetThreatAtPosition(self, { unit.IMAP[1], 0, unit.IMAP[2] }, self.BrainIntel.IMAPConfig.Rings, true, 'AntiAir'), 
                                Land = GetThreatAtPosition(self, { unit.IMAP[1], 0, unit.IMAP[2] }, self.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface')
                                }
                        end
                    end
                end
                --LOG('Enemy Threat Location '..q..' Have Land Defensive Structure Count of '..self.EnemyIntel.EnemyThreatLocations[q].LandDefStructureCount)
                --LOG('Enemy Threat Location '..q..' Have Air Defensive Structure Count of '..self.EnemyIntel.EnemyThreatLocations[q].AirDefStructureCount)
            end
            --RNGLOG('Enemy Defense Structure has '..unit.Air..' air threat and '..unit.Land..' land threat'..' belonging to energy index '..unit.EnemyIndex)
        end
        
        local firebaseTable = {}
        for q, threat in self.EnemyIntel.EnemyThreatLocations do
            local tableEntry = { Position = threat.Position, Land = { Count = 0 }, Air = { Count = 0 }, aggX = 0, aggZ = 0, weight = 0, validated = false}
            if threat.LandDefStructureCount > 0 then
                --LOG('Enemy Threat Location with ID '..q..' has '..threat.LandDefStructureCount..' at imap position '..repr(threat.Position))
                tableEntry.Land = { Count = threat.LandDefStructureCount }
            end
            if threat.AirDefStructureCount > 0 then
                --LOG('Enemy Threat Location with ID '..q..' has '..threat.AirDefStructureCount..' at imap position '..repr(threat.Position))
                tableEntry.Air = { Count = threat.AirDefStructureCount }
            end
            RNGINSERT(firebaseTable, tableEntry)
        end
        local firebaseaggregation = 0
        firebaseaggregationTable = {}
        local complete = RNGGETN(firebaseTable) == 0
        --LOG('Firebase table '..repr(firebaseTable))
        while not complete do
            complete = true
            --LOG('firebase aggregation loop number '..firebaseaggregation)
            for _, v1 in firebaseTable do
                v1.weight = 1
                v1.aggX = v1.Position[1]
                v1.aggZ = v1.Position[2]
            end
            for _, v1 in firebaseTable do
                if not v1.validated then
                    for _, v2 in firebaseTable do
                        if not v2.validated and VDist2Sq(v1.Position[1], v1.Position[2], v2.Position[1], v2.Position[2]) < 3600 then
                            v1.weight = v1.weight + 1
                            v1.aggX = v1.aggX + v2.Position[1]
                            v1.aggZ = v1.aggZ + v2.Position[2]
                        end
                    end
                end
            end
            local best = nil
            for _, v in firebaseTable do
                if (not v.validated) and ((not best) or best.weight < v.weight) then
                    best = v
                end
            end
            local defenseGroup = {Land = best.Land.Count, Air = best.Air.Count}
            best.validated = true
            local x = best.aggX/best.weight
            local z = best.aggZ/best.weight
            for _, v in firebaseTable do
                if (not v.validated) and VDist2Sq(v.Position[1], v.Position[2], best.Position[1], best.Position[2]) < 3600 then
                    defenseGroup.Land = defenseGroup.Land + v.Land.Count
                    defenseGroup.Air = defenseGroup.Air + v.Air.Count
                    v.validated = true
                elseif not v.validated then
                    complete = false
                end
            end
            firebaseaggregation = firebaseaggregation + 1
            RNGINSERT(firebaseaggregationTable, {aggx = x, aggz = z, DefensiveCount = defenseGroup.Land + defenseGroup.Air})
        end

        --LOG('firebaseTable '..repr(firebaseTable))
        for k, v in firebaseaggregationTable do
            if v.DefensiveCount > 5 then
                self.EnemyIntel.EnemyFireBaseDetected = true
                break
            else
                self.EnemyIntel.EnemyFireBaseDetected = false
            end
        end
        --LOG('firebaseaggregationTable '..repr(firebaseaggregationTable))
        if self.EnemyIntel.EnemyFireBaseDetected then
            --LOG('Firebase Detected')
            --LOG('Firebase Table '..repr(self.EnemyIntel.EnemyFireBaseTable))
        end
        self.EnemyIntel.DirectorData.Defense = defensiveUnits
    end

    -- populate the director
    self.EnemyIntel.DirectorData.Strategic = strategicUnits
    self.EnemyIntel.DirectorData.Intel = intelUnits
    self.EnemyIntel.DirectorData.Factory = factoryUnits
    self.EnemyIntel.DirectorData.Energy = energyUnits

    LOG("Finished analysis for: " .. self.Nickname)
    local finishedAnalysisAt = GetSystemTimeSecondsOnlyForProfileUse()
    LOG("Time of analysis: " .. (finishedAnalysisAt - startedAnalysisAt))
end