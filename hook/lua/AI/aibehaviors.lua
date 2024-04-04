WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibehaviors.lua' )

local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local UnitRatioCheckRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').UnitRatioCheckRNG
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local lerpy = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').lerpy
local SetArcPoints = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').SetArcPoints
local GeneratePointsAroundPosition = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GeneratePointsAroundPosition
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local MakePlatoon = moho.aibrain_methods.MakePlatoon
local AssignUnitsToPlatoon = moho.aibrain_methods.AssignUnitsToPlatoon
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetMostRestrictiveLayerRNG = import('/lua/ai/aiattackutilities.lua').GetMostRestrictiveLayerRNG
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGTableEmpty = table.empty
local CategoryT2Defense = categories.STRUCTURE * categories.DEFENSE * (categories.TECH2 + categories.TECH3)

--[[
    We can query self.EnemyIntel.ACU to get detail on enemy acu's assuming they've been scouted recently by either air scouts or the AI acu.
    Contains a table of the following data. For RNGAI team mates it can support having details, but not humans or other AI since they don't make the data easily accessable.
    {
        Ally=false,   <- Flag if ally, done at the start of the game.
        Gun=false,   <- Flag if they have the gun upgrade
        Hp=0,   <- HP at the time of scouting
        LastSpotted=0,  <- Timestamp of being spotted
        OnField=false,   <- This currently says they are within x radius of the AI's main base. Will have to change that.
        Position={ },   <- Position they were last seen
        Threat=0   <- The amount of enemy threat they had around them.
    },

    A word about the ACU. In the current FAF balance the Sera blueprint has a MuzzleChargeDelay value of 0.4. This seems to cause the AI to be very inaccurate with its gun. Unknown why.
]]


function DrawACUInfo(cdr)
    while cdr and not cdr.Dead do
        if cdr.Position then
            if cdr.Caution then
                DrawCircle(cdr.Position,80,'ff0000')
                DrawCircle(cdr.Position,35,'ff0000')
            else
                DrawCircle(cdr.Position,80,'aaffaa')
                DrawCircle(cdr.Position,35,'aaffaa')
            end
        end
        if cdr.TargetPosition[1] then
            DrawLine(cdr.Position, cdr.TargetPosition, 'aaffaa')
            DrawCircle(cdr.TargetPosition,20,'f44336')
        end
        if cdr.movetopos[1] then
            DrawLine(cdr.Position, cdr.movetopos, 'aaffaa')
            DrawCircle(cdr.movetopos,30,'aaffaa')
        end
        coroutine.yield( 2 )
    end
end

function drawRect(aiBrain, cdr)
    local counter = 0
    while counter < 20 do
        DrawCircle(cdr:GetPosition(), 10, '0000FF')
        counter = counter + 1
        coroutine.yield(2)
    end
end

ZoneUpdate = function(platoon)
    local aiBrain = platoon:GetBrain()
    local function SetZone(pos, zoneIndex)
        --RNGLOG('Set zone with the following params position '..repr(pos)..' zoneIndex '..zoneIndex)
        if not pos then
            --RNGLOG('No Pos in Zone Update function')
            return false
        end
        local zoneID = MAP:GetZoneID(pos,zoneIndex)
        -- zoneID <= 0 => not in a zone
        if zoneID > 0 then
            platoon.Zone = zoneID
        else
            local searchPoints = RUtils.DrawCirclePoints(4, 5, pos)
            for k, v in searchPoints do
                zoneID = MAP:GetZoneID(v,zoneIndex)
                if zoneID > 0 then
                    --RNGLOG('We found a zone when we couldnt before '..zoneID)
                    platoon.Zone = zoneID
                    break
                end
            end
        end
    end
    if not platoon.MovementLayer then
        AIAttackUtils.GetMostRestrictiveLayerRNG(platoon)
    end
    while aiBrain:PlatoonExists(platoon) do
        if platoon.MovementLayer == 'Land' or platoon.MovementLayer == 'Amphibious' then
            SetZone(GetPlatoonPosition(platoon), aiBrain.Zones.Land.index)
        elseif platoon.MovementLayer == 'Water' then
            --SetZone(PlatoonPosition, aiBrain.Zones.Water.index)
        end
        WaitTicks(30)
    end
end

local SurfacePrioritiesRNG = {
    categories.COMMAND,
    categories.EXPERIMENTAL * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH3 * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH2 * categories.ENERGYPRODUCTION * categories.STRUCTURE,
    categories.TECH3 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.INTELLIGENCE * categories.STRUCTURE,
    categories.EXPERIMENTAL * categories.LAND,
    categories.INTELLIGENCE * categories.STRUCTURE,
    categories.TECH3 * categories.DEFENSE * categories.STRUCTURE,
    categories.DEFENSE * categories.STRUCTURE,
    categories.SHIELD * categories.STRUCTURE,
    categories.TECH2 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.FACTORY * categories.STRUCTURE,
    categories.FACTORY * categories.STRUCTURE,
    categories.TECH1 * categories.MASSEXTRACTION * categories.STRUCTURE,
    categories.TECH3 * categories.STRUCTURE,
    categories.STRUCTURE,
    categories.TECH3 * categories.MOBILE * categories.LAND,
    categories.MOBILE * categories.LAND,
    categories.TECH3 * categories.MOBILE * categories.NAVAL,
    categories.MOBILE * categories.NAVAL,
}

AssignExperimentalPrioritiesRNG = function(platoon)
    local experimental = GetExperimentalUnit(platoon)
    if experimental then
        experimental:SetLandTargetPriorities(SurfacePrioritiesRNG)
    end
end

FindExperimentalTargetRNG = function(self)
    local aiBrain = self:GetBrain()
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    if not im.MapIntelStats.ScoutLocationsBuilt then
        -- No target
        return
    end

    local bestUnit = false
    local bestBase = false
    -- If we haven't found a target check the main bases radius for any units, 
    -- Check if there are any high priority units from the main base position. But only if we came online around that position.
    local platPos = self:GetPlatoonPosition()
    if platPos and VDist3Sq(platPos, aiBrain.BuilderManagers['MAIN'].Position) < 22500 then
        if not bestUnit then
            bestUnit = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
            if bestUnit and not bestUnit.Dead then
                bestBase = {}
                bestBase.Position = bestUnit:GetPosition()
                return bestUnit, bestBase
            end
        end
    end

    -- First we look for an acu snipe mission.
    -- Needs more logic for ACU's that are in bases or firebases.
    for k, v in aiBrain.TacticalMonitor.TacticalMissions.ACUSnipe do
        if v.LAND.GameTime and v.LAND.GameTime + 650 > GetGameTimeSeconds() then
            --RNGLOG('ACU Table for index '..k..' table '..repr(aiBrain.EnemyIntel.ACU))
            if RUtils.HaveUnitVisual(aiBrain, aiBrain.EnemyIntel.ACU[k].Unit, true) then
                if not RUtils.PositionInWater(aiBrain.EnemyIntel.ACU[k].Position) then
                    bestUnit = aiBrain.EnemyIntel.ACU[k].Unit
                    --RNGLOG('Experimental strike : ACU Target mission found and target set')
                end
                break
            else
                --RNGLOG('Experimental strike : ACU Target mission found but target not visible')
            end
        end
    end
    if bestUnit and not bestUnit.Dead then
        bestBase = {}
        bestBase.Position = bestUnit:GetPosition()
        return bestUnit, bestBase
    end

    local enemyBases = aiBrain.EnemyIntel.EnemyThreatLocations
    --LOG('FInd Exp unit enemy bases '..repr(enemyBases))
    
    local mostUnits = 0
    local highestMassValue = 0
    -- Now we look at bases of any sort and find the highest mass worth then selecting the most valuable unit in that base.
        
    for _, x in enemyBases do
        for _, z in x do
            if z.StructuresNotMex then
                --RNGLOG('Base Position with '..base.Threat..' threat')
                local unitsAtBase = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, z.Position, 100, 'Enemy')
                local massValue = 0
                local highestValueUnit = 0
                local notDeadUnit = false

                for _, unit in unitsAtBase do
                    if not unit.Dead then
                        if unit.Blueprint.Economy.BuildCostMass then
                            if unit.Blueprint.CategoriesHash.DEFENSE then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 1.5)
                            elseif unit.Blueprint.CategoriesHash.TECH3 and unit.Blueprint.CategoriesHash.ANTIMISSILE and unit.Blueprint.CategoriesHash.SILO then
                                massValue = massValue + (unit.Blueprint.Economy.BuildCostMass * 2)
                            else
                                massValue = massValue + unit.Blueprint.Economy.BuildCostMass
                            end
                        end
                        if massValue > highestValueUnit then
                            highestValueUnit = massValue
                            notDeadUnit = unit
                        end
                        if not notDeadUnit then
                            notDeadUnit = unit
                        end
                    end
                end

                if massValue > 0 then
                    if massValue > highestMassValue then
                        bestBase = z
                        highestMassValue = massValue
                        bestUnit = notDeadUnit
                    elseif massValue == highestMassValue then
                        local myPos = GetPlatoonPosition(self)
                        local dist1 = VDist2Sq(myPos[1], myPos[3], z.Position[1], z.Position[3])
                        local dist2 = VDist2Sq(myPos[1], myPos[3], bestBase.Position[1], bestBase.Position[3])

                        if dist1 < dist2 then
                            bestBase = z
                            bestUnit = notDeadUnit
                        end
                    end
                end
            end
        end
    end
    if bestBase and bestUnit then
        --RNGLOG('Best base '..bestBase.Threat..' threat '..' at '..repr(bestBase.Position))
        return bestUnit, bestBase
    end

    return false, false
end

function AirStagingThreadRNG(unit)
    local aiBrain = unit:GetAIBrain()
    --LOG('Starting Air Staging thread')

    while not unit.Dead do
        local numUnits = 0
        local refueledUnits = {}
        --LOG('Current refueling count '..table.getn(unit.Refueling))
        for k, v in unit.Refueling do
            if not v.Dead then
                if (not v:GetFuelRatio() < 1) and (not v:GetHealthPercent() < 1) then
                    numUnits = numUnits + 1
                    RNGINSERT(refueledUnits, {Unit = v, Key = k})
                end
            end
        end
        --LOG('Number of Units ready to deploy '..numUnits)
        if numUnits > 0 then
            --RNGLOG('Number of units in refueldedUnits '..table.getn(refueledUnits))
            local tableRebuild = false
            for k, v in refueledUnits do
                if not v.Unit.Dead then
                    local pos = unit:GetPosition()
                    if v.Unit:IsIdleState() and not v.Unit:IsUnitState('Attached') then
                        v.Unit.Loading = false
                        local plat
                        if not v.Unit.PreviousStateMachine then
                            if not v.Unit.PlanName then
                                --RNGLOG('Air Refuel unit has no plan, assigning ')
                                plat = aiBrain:MakePlatoon('', 'FeederPlatoon')
                            else
                            --RNGLOG('Air Refuel unit has plan name of '..v.Unit.PlanName)
                                plat = aiBrain:MakePlatoon('', 'FeederPlatoon')
                            end
                            if v.Unit.PlatoonData then
                            --RNGLOG('Air Refuel unit has platoon data, reassigning ')
                                plat.PlatoonData = {}
                                plat.PlatoonData = v.Unit.PlatoonData
                            end
                            v.Unit.TimeStamp = nil
                            aiBrain:AssignUnitsToPlatoon(plat, {v.Unit}, 'Attack', 'GrowthFormation')
                            unit.Refueling[v.Key] = nil
                            tableRebuild = true
                            --LOG('table removed from refueling not state machine')
                        else
                            unit.Refueling[v.Key] = nil
                            tableRebuild = true
                            --LOG('table removed from refueling')
                        end
                    elseif v.Unit:IsUnitState('Attached') then
                        IssueClearCommands({unit})
                        IssueTransportUnload({unit}, {pos[1] + 5, pos[2], pos[3] + 5})
                        --RNGLOG('Attempting to add to AirHuntAI Platoon')
                        v.Unit.Loading = false
                        if not v.Unit.PreviousStateMachine then
                            local plat
                            if not v.Unit.PlanName then
                                --RNGLOG('Force Unload Air Refuel unit has no plan, assigning ')
                                plat = aiBrain:MakePlatoon('', 'FeederPlatoon')
                            else
                            --RNGLOG('Force Unload Air Refuel unit has plan name of '..v.Unit.PlanName)
                                plat = aiBrain:MakePlatoon('', 'FeederPlatoon')
                            end
                            if v.Unit.PlatoonData then
                            --RNGLOG('Air Refuel unit has platoon data, reassigning ')
                                plat.PlatoonData = {}
                                plat.PlatoonData = v.PlatoonData
                            end
                            aiBrain:AssignUnitsToPlatoon(plat, {v.Unit}, 'Attack', 'GrowthFormation')
                            unit.Refueling[v.Key] = nil
                            tableRebuild = true
                            --LOG('table removed from refueling not state machine')
                        else
                            unit.Refueling[v.Key] = nil
                            tableRebuild = true
                            --LOG('table removed from refueling')
                        end
                    end
                else
                    unit.Refueling[v.Key] = nil
                    tableRebuild = true
                end
            end
            if tableRebuild then
                unit.Refueling = aiBrain:RebuildTable(unit.Refueling)
                --LOG('Refueling table after removal '..repr(unit.Refueling))
            end
        end
        coroutine.yield(60)
    end
end

GetStartingReclaim = function(aiBrain)
    --RNGLOG('Reclaim Start Check')
    local startReclaim
    local posX, posZ = aiBrain:GetArmyStartPos()
    --RNGLOG('Start Positions X'..posX..' Z '..posZ)
    local minRec = 70
    local reclaimTable = {}
    local reclaimScanArea = math.max(ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40) / 4
    local reclaimMassTotal = 0
    local reclaimEnergyTotal = 0
    --RNGLOG('Reclaim Scan Area is '..reclaimScanArea)
    reclaimScanArea = math.max(50, reclaimScanArea)
    reclaimScanArea = math.min(120, reclaimScanArea)
    --Wait 10 seconds for the wrecks to become reclaim
    --coroutine.yield(100)
    
    startReclaim = GetReclaimablesInRect(posX - reclaimScanArea, posZ - reclaimScanArea, posX + reclaimScanArea, posZ + reclaimScanArea)
    --RNGLOG('Initial Reclaim Table size is '..table.getn(startReclaim))
    if startReclaim and RNGGETN(startReclaim) > 0 then
        for k,v in startReclaim do
            if not IsProp(v) then continue end
            if v.MaxMassReclaim or v.MaxEnergyReclaim  then
                if v.MaxMassReclaim > minRec or v.MaxEnergyReclaim > minRec then
                    --RNGLOG('High Value Reclaim is worth '..v.MaxMassReclaim)
                    local rpos = v.CachePosition
                    if VDist2( rpos[1], rpos[3], posX, posZ ) < reclaimScanArea then
                        --RNGLOG('Reclaim distance is '..VDist2( rpos[1], rpos[3], posX, posZ ))
                        RNGINSERT(reclaimTable, { Reclaim = v })
                    end
                    --RNGLOG('Distance to reclaim from main pos is '..VDist2( rpos[1], rpos[3], posX, posZ ))
                end
                reclaimMassTotal = reclaimMassTotal + v.MaxMassReclaim
                reclaimEnergyTotal = reclaimEnergyTotal + v.MaxEnergyReclaim
            end
        end
        --RNGLOG('Sorting Reclaim table by distance ')
        --It feels pointless to sort this table, its the engineer itself that wants the closest not the base.
        --RNGSORT(reclaimTable, function(a,b) return a.Distance < b.Distance end)
        --RNGLOG('Final Reclaim Table size is '..table.getn(reclaimTable))
        aiBrain.StartReclaimTable = reclaimTable
        aiBrain.StartMassReclaimTotal = reclaimMassTotal
        aiBrain.StartEnergyReclaimTotal = reclaimEnergyTotal
    end
    if aiBrain.RNGDEBUG then
        RNGLOG('Total Starting Mass Reclaim is '..aiBrain.StartMassReclaimTotal)
        RNGLOG('Total Starting Energy Reclaim is '..aiBrain.StartEnergyReclaimTotal)
        RNGLOG('Complete Get Starting Reclaim')
    end
end