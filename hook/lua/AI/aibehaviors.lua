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







function CDRHideBehaviorRNG(aiBrain, cdr)
    if cdr:IsIdleState() and not cdr.Active then
        cdr.GoingHome = false
        cdr.Active = false
        cdr.Upgrading = false
        if cdr.CurrentEnemyInnerCircle < 10 and cdr.CurrentEnemyThreat < 50 then
            PerformACUReclaim(aiBrain, cdr, 0)
        end

        local category = false
        local runShield = false
        local runPos = false
        local nmaShield = GetNumUnitsAroundPoint(aiBrain, categories.SHIELD * categories.STRUCTURE, cdr.Position, 100, 'Ally')
        local nmaPD = GetNumUnitsAroundPoint(aiBrain, categories.DIRECTFIRE * categories.DEFENSE, cdr.Position, 100, 'Ally')
        local nmaAA = GetNumUnitsAroundPoint(aiBrain, categories.ANTIAIR * categories.DEFENSE, cdr.Position, 100, 'Ally')

        if nmaShield > 0 then
            category = categories.SHIELD * categories.STRUCTURE
            runShield = true
        elseif nmaAA > 0 then
            category = categories.DEFENSE * categories.ANTIAIR
        elseif nmaPD > 0 then
            category = categories.DEFENSE * categories.DIRECTFIRE
        end

        if category then
            runPos = AIUtils.AIFindDefensiveAreaSorian(aiBrain, cdr, category, 100, runShield)
            IssueClearCommands({cdr})
            IssueMove({cdr}, runPos)
            coroutine.yield(30)
        end

        if not category or not runPos then
            local cdrNewPos = {}
            cdrNewPos[1] = cdr.CDRHome[1] + Random(-6, 6)
            cdrNewPos[2] = cdr.CDRHome[2]
            cdrNewPos[3] = cdr.CDRHome[3] + Random(-6, 6)
            coroutine.yield(1)
            IssueStop({cdr})
            IssueMove({cdr}, cdrNewPos)
            coroutine.yield(30)
        end
    end
    coroutine.yield(5)
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
        platoon:GetPlatoonRatios()
        WaitTicks(30)
    end
end

TargetControlThread = function (platoon)
    local aiBrain = platoon:GetBrain()
    
    local TargetControlTemplates = {
        structureMode = {
                        'EXPERIMENTAL',
                        'STRUCTURE DEFENSE',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiAirMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND ANTIAIR',
                        'STRUCTURE ANTIAIR',
                        'MOBILE LAND INDIRECTFIRE',
                        'MOBILE LAND DIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },

        antiLandMode = {
                        'EXPERIMENTAL',
                        'MOBILE LAND DIRECTFIRE',
                        'MOBILE LAND INDIRECTFIRE',
                        'STRUCTURE DEFENSE',
                        'MASSEXTRACTION',
                        'ENERGYPRODUCTION',
                        'COMMAND',
                        'MASSFABRICATION',
                        'SHIELD',
                        'STRUCTURE',
                        'ALLUNITS',
                    },
                }
    while aiBrain:PlatoonExists(platoon) do
        if aiBrain.EnemyIntel.EnemyThreatCurrent.DefenseAir > 20 then
            local artillerySquad = platoon:GetSquadUnits('Artillery')
            platoon:SetPrioritizedTargetList('Artillery', TargetControlTemplates.structureMode)
        end
        --RNGLOG('TargetControlThread')
        coroutine.yield(30)
    end
end

function FatBoyBehaviorRNG(self)
    local aiBrain = self:GetBrain()
    AssignExperimentalPrioritiesRNG(self)

    local unit = GetExperimentalUnit(self)
    local target
    local targetUnit = false
    local lastBase = false
    local mainBasePos = aiBrain.BuilderManagers['MAIN'].Position
    local unitPos
    local alpha, x, y, smartPos
    

    local mainWeapon = unit:GetWeapon(1)
    unit.MaxWeaponRange = mainWeapon:GetBlueprint().MaxRadius
    unit.smartPos = {0,0,0}
    unit.Platoons = unit.Platoons or {}
    if mainWeapon.BallisticArc == 'RULEUBA_LowArc' then
        unit.WeaponArc = 'low'
    elseif mainWeapon.BallisticArc == 'RULEUBA_HighArc' then
        unit.WeaponArc = 'high'
    else
        unit.WeaponArc = 'none'
    end
    if not unit.Guards or not aiBrain:PlatoonExists(unit.Guards) then
        unit.Guards = aiBrain:MakePlatoon('', '')
    end

    -- Find target loop
    while unit and not unit.Dead do
        local guards = unit.Guards:GetPlatoonUnits()
        local inWater = InWaterCheck(self)
        --RNGLOG('Start of FATBOY Loop')
        targetUnit, lastBase = FindExperimentalTargetRNG(self)
        if targetUnit then
            --RNGLOG('We have target')
            IssueClearCommands({unit})
            local targetPos = targetUnit:GetPosition()
            if inWater then
                --RNGLOG('We are in water and moving to targetPos')
                IssueMove({unit}, targetPos)
            else
                --RNGLOG('Attack Issued to targetUnit')
                IssueAttack({unit}, targetUnit)
            end
            -- Wait to get in range
            local pos = unit:GetPosition()
            --RNGLOG('About to start base distance loop')
            while VDist2(pos[1], pos[3], lastBase.Position[1], lastBase.Position[3]) > (unit.MaxWeaponRange - 10)
                and not unit.Dead do
                    --RNGLOG('Start of fatboy move to target loop')
                    coroutine.yield(40)
                    inWater = InWaterCheck(self)
                    guards = unit.Guards:GetPlatoonUnits()
                    if guards and (RNGGETN(guards) < 4) and not inWater then
                        if VDist2Sq(pos[1], pos[3], mainBasePos[1], mainBasePos[3]) > 6400 then
                            IssueClearCommands({unit})
                            coroutine.yield(1)
                            FatBoyGuardsRNG(self)
                        end
                    end
                    --RNGLOG('FATBOY guard count :'..table.getn(guards))
                    if unit:IsIdleState() and targetUnit and not targetUnit.Dead then
                        if inWater then
                            IssueMove({unit}, targetPos)
                        else
                            --RNGLOG('Attack Issued')
                            IssueAttack({unit}, targetUnit)
                        end
                    end
                    if inWater then
                        coroutine.yield(10)
                        if unit.Guards then
                            --RNGLOG('In water, disbanding guards')
                            unit.Guards:ReturnToBaseAIRNG()
                        end
                    end
                    
                    if not inWater then
                        --RNGLOG('In water is false')
                        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER - categories.TECH1, unit:GetPosition(), unit.MaxWeaponRange, 'Enemy')
                        if enemyUnitCount > 0 then
                            target = self:FindClosestUnit('attack', 'Enemy', true, categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.TECH1)
                            while unit and not unit.Dead do
                                if target and not target.Dead then
                                    IssueClearCommands({unit})
                                    local targetPosition = target:GetPosition()
                                    if unit.Dead then continue end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(3)
                                        WARN('Warning : Experimental has no max weapon range')
                                        continue
                                    end
                                    unitPos = unit:GetPosition()
                                    alpha = math.atan2(targetPosition[3] - unitPos[3] ,targetPosition[1] - unitPos[1])
                                    x = targetPosition[1] - math.cos(alpha) * (unit.MaxWeaponRange - 15)
                                    y = targetPosition[3] - math.sin(alpha) * (unit.MaxWeaponRange - 15)
                                    smartPos = { x, GetTerrainHeight( x, y), y }
                                    -- check if the move position is new or target has moved
                                    if VDist2( smartPos[1], smartPos[3], unit.smartPos[1], unit.smartPos[3] ) > 0.7 or unit.TargetPos ~= targetPosition then
                                        -- clear move commands if we have queued more than 4
                                        if RNGGETN(unit:GetCommandQueue()) > 2 then
                                            IssueClearCommands({unit})
                                            coroutine.yield(3)
                                        end
                                        -- if our target is dead, jump out of the "for _, unit in self:GetPlatoonUnits() do" loop
                                        IssueMove({unit}, smartPos )
                                        if target.Dead then break end
                                        IssueAttack({unit}, target)
                                        unit.smartPos = smartPos
                                        unit.TargetPos = targetPosition
                                    -- in case we don't move, check if we can fire at the target
                                    else
                                        local dist = VDist2( unit.smartPos[1], unit.smartPos[3], unit.TargetPos[1], unit.TargetPos[3] )
                                        if aiBrain:CheckBlockingTerrain(unitPos, targetPosition, unit.WeaponArc) then
                                            --unit:SetCustomName('Fight micro WEAPON BLOCKED!!! ['..repr(target.UnitId)..'] dist: '..dist)
                                            IssueMove({unit}, targetPosition )
                                            coroutine.yield(30)
                                        else
                                            --unit:SetCustomName('Fight micro SHOOTING ['..repr(target.UnitId)..'] dist: '..dist)
                                        end
                                    end
                                else
                                    break
                                end
                            coroutine.yield(20)
                            end
                        else
                            --RNGLOG('In water is false')
                            IssueClearCommands({unit})
                            IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                            --RNGLOG('Taret Position is'..repr(targetPos))
                            coroutine.yield(40)
                        end
                    else
                        --RNGLOG('In water is true')
                        IssueClearCommands({unit})
                        IssueMove({unit}, {lastBase.Position[1], 0 ,lastBase.Position[3]})
                        --RNGLOG('Taret Position is'..repr(targetPos))
                        coroutine.yield(40)
                    end
                --RNGLOG('End of fatboy moving to target loop')
            end
            --RNGLOG('End of fatboy unit loop')
            IssueClearCommands({unit})
        end
        coroutine.yield(10)
    end
end

function FatBoyGuardsRNG(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)

    -- Randomly build T3 MMLs, siege bots, and percivals.
    local buildUnits = {'uel0205', 'delk002'}
    local unitToBuild = buildUnits[Random(1, RNGGETN(buildUnits))]
    
    aiBrain:BuildUnit(experimental.ExternalFactory, unitToBuild, 1)
    --RNGLOG('Guard loop pass')
    coroutine.yield(1)

    local unitBeingBuilt = false
    local buildTimeout = 0
    repeat
        unitBeingBuilt = unitBeingBuilt or experimental.ExternalFactory.UnitBeingBuilt
        coroutine.yield(20)
        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER - categories.TECH1, experimental:GetPosition(), 30, 'Enemy')
        if enemyUnitCount > 5 then
            IssueClearCommands({experimental})
            return
        end
        buildTimeout = buildTimeout + 1
        if buildTimeout > 20 then
            --RNGLOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --RNGLOG('Waiting for unitBeingBuilt is be true')
    until experimental.Dead or unitBeingBuilt or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10
    
    local idleTimeout = 0
    repeat
        local enemyUnitCount = aiBrain:GetNumUnitsAroundPoint(categories.MOBILE * categories.LAND - categories.SCOUT - categories.ENGINEER - categories.TECH1, experimental:GetPosition(), 45, 'Enemy')
        if enemyUnitCount > 5 then
            IssueClearCommands({experimental})
            return
        end
        coroutine.yield(30)
        idleTimeout = idleTimeout + 1
        if idleTimeout > 15 then
            --RNGLOG('FATBOY has not built within 40 seconds, breaking out')
            IssueClearCommands({experimental})
            return
        end
        --RNGLOG('Waiting for experimental to go idle')
    until experimental.Dead or experimental:IsIdleState() or aiBrain:GetArmyStat("UnitCap_MaxCap", 0.0).Value - aiBrain:GetArmyStat("UnitCap_Current", 0.0).Value < 10

    if not experimental.Guards or not aiBrain:PlatoonExists(experimental.Guards) then
        experimental.Guards = aiBrain:MakePlatoon('', '')
    end

    if unitBeingBuilt and not unitBeingBuilt.Dead then
        aiBrain:AssignUnitsToPlatoon(experimental.Guards, {unitBeingBuilt}, 'Guard', 'NoFormation')
        IssueClearCommands({unitBeingBuilt})
        IssueGuard({unitBeingBuilt}, experimental)
    end
end

AssignCZARPriorities = function(platoon)
    local experimental = GetExperimentalUnit(platoon)
    --RNGLOG('Assign CZAR Priorities')
    local CZARPriorities = {
        Land = {
            'COMMAND',
            'EXPERIMENTAL ENERGYPRODUCTION STRUCTURE',
            'EXPERIMENTAL STRATEGIC STRUCTURE',
            'EXPERIMENTAL ARTILLERY OVERLAYINDIRECTFIRE',
            'EXPERIMENTAL ORBITALSYSTEM',
            'TECH3 STRATEGIC STRUCTURE',
            'EXPERIMENTAL LAND',
            'TECH2 STRATEGIC STRUCTURE',
            'TECH3 DEFENSE STRUCTURE',
            'TECH2 DEFENSE STRUCTURE',
            'TECH3 ENERGYPRODUCTION STRUCTURE',
            'TECH3 MASSFABRICATION STRUCTURE',
            'TECH2 ENERGYPRODUCTION STRUCTURE',
            'TECH3 MASSEXTRACTION STRUCTURE',
            'TECH3 SHIELD STRUCTURE',
            'TECH2 SHIELD STRUCTURE',
            'TECH3 INTELLIGENCE STRUCTURE',
            'TECH2 INTELLIGENCE STRUCTURE',
            'TECH1 INTELLIGENCE STRUCTURE',
            'TECH2 MASSEXTRACTION STRUCTURE',
            'TECH3 FACTORY LAND STRUCTURE',
            'TECH3 FACTORY AIR STRUCTURE',
            'TECH3 FACTORY NAVAL STRUCTURE',
            'TECH2 FACTORY LAND STRUCTURE',
            'TECH2 FACTORY AIR STRUCTURE',
            'TECH2 FACTORY NAVAL STRUCTURE',
            'TECH1 FACTORY LAND STRUCTURE',
            'TECH1 FACTORY AIR STRUCTURE',
            'TECH1 FACTORY NAVAL STRUCTURE',
            'TECH1 MASSEXTRACTION STRUCTURE',
            'TECH3 STRUCTURE',
            'TECH2 STRUCTURE',
            'TECH1 STRUCTURE',
            'TECH3 MOBILE LAND',
            'TECH2 MOBILE LAND',
            'TECH1 MOBILE LAND',
            'ALLUNITS',
            },
        }
    if experimental then
        for i = 1, experimental:GetWeaponCount() do
            local wep = experimental:GetWeapon(i)
            if wep:GetBlueprint().DisplayName == 'Quantum Beam Generator' then
                --RNGLOG('CZAR main beam weapon found, set unique priorities')
                wep:SetWeaponPriorities(CZARPriorities['Land'])
                break
            end
        end
    end
end

CzarBehaviorRNG = function(self)
    local experimental = GetExperimentalUnit(self)
    local aiBrain = self:GetBrain()
    if not experimental then
        return
    end

    if not EntityCategoryContains(categories.uaa0310, experimental) then
        return
    end
    --RNGLOG('Assign CZAR Priorities')
    AssignCZARPriorities(self)
    local cmd = {}
    local targetUnit, targetBase = FindExperimentalTargetRNG(self)
    local oldTargetUnit = nil
    while not experimental.Dead do
        if (targetUnit and not targetUnit.Dead and targetUnit ~= oldTargetUnit) or not self:IsCommandsActive(cmd) then
            if targetUnit and VDist3(targetUnit:GetPosition(), self:GetPlatoonPosition()) > 100 then
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = ExpPathToLocation(aiBrain, self, 'Air', targetUnit:GetPosition(), false, 62500)
                cmd = self:AttackTarget(targetUnit)
            else
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = self:AttackTarget(targetUnit)
            end
        end

        local nearCommander = CommanderOverrideCheck(self)
        local oldCommander = nil
        while nearCommander and not experimental.Dead and not experimental:IsIdleState() do
            if nearCommander and nearCommander ~= oldCommander and nearCommander ~= targetUnit then
                IssueClearCommands({experimental})
                coroutine.yield(5)

                cmd = self:AttackTarget(nearCommander)
                targetUnit = nearCommander
            end
            coroutine.yield(10)

            oldCommander = nearCommander
            nearCommander = CommanderOverrideCheck(self)
        end
        coroutine.yield(10)

        oldTargetUnit = targetUnit
        targetUnit, targetBase = FindExperimentalTargetRNG(self)
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

WreckBaseRNG = function(self, base)
    for _, priority in SurfacePrioritiesRNG do
        local numUnitsAtBase = 0
        local notDeadUnit = false
        local unitsAtBase = self:GetBrain():GetUnitsAroundPoint(priority, base.Position, 100, 'Enemy')
        for _, unit in unitsAtBase do
            if not unit.Dead then
                notDeadUnit = unit
                numUnitsAtBase = numUnitsAtBase + 1
            end
        end

        if numUnitsAtBase > 0 then
            return notDeadUnit, base
        end
    end
    return false, false
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

function BehemothBehaviorRNG(self, id)
    AssignExperimentalPrioritiesRNG(self)

    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)
    local data = self.PlatoonData
    local targetUnit = false
    local lastBase = false
    local cmd
    local categoryList = {}

    if data.PrioritizedCategories then
        for k,v in data.PrioritizedCategories do
            RNGINSERT(categoryList, ParseEntityCategory(v))
        end
        RNGINSERT(categoryList, categories.ALLUNITS)
        self:SetPrioritizedTargetList('Attack', categoryList)
    end
    AIAttackUtils.GetMostRestrictiveLayerRNG(self)
    self:ConfigurePlatoon()
    local airUnit = EntityCategoryContains(categories.AIR, experimental)
    -- Don't forget we have the unit ID for specialized behaviors.
    -- Find target loop
    while experimental and not experimental.Dead do
        if lastBase then
            targetUnit, lastBase = WreckBaseRNG(self, lastBase)
        elseif not lastBase then
            targetUnit, lastBase = FindExperimentalTargetRNG(self)
        end

        if targetUnit and not targetUnit.Dead then
            IssueClearCommands({experimental})
            local targetPos = targetUnit:GetPosition()
            if VDist3Sq(experimental:GetPosition(), targetPos) < 6400 then
                IssueMove({experimental}, targetPos)
            else
                ExpMoveToPosition(aiBrain, self, targetUnit, experimental, false)
            end
            --RNGLOG('Exp unit has pathed to location using micro')
        end

        -- Walk to and kill target loop
        while not experimental.Dead and not experimental:IsIdleState() do
            local nearCommander = CommanderOverrideCheck(self)
            if nearCommander and nearCommander ~= targetUnit then
                --RNGLOG('Exp unit ACU spotted, trying to attack')
                IssueClearCommands({experimental})
                IssueAttack({experimental}, nearCommander)
                targetUnit = nearCommander
            end
            -- If no target jump out
            if not targetUnit or targetUnit.Dead then break end
            local unitPos = GetPlatoonPosition(self)
            local targetPos = targetUnit:GetPosition()
            if VDist2Sq(unitPos[1], unitPos[3], targetPos[1], targetPos[3]) < 6400 then
                if targetUnit and not targetUnit.Dead and aiBrain:CheckBlockingTerrain(unitPos, targetPos, 'none') then
                    --RNGLOG('Exp unit WEAPON BLOCKED, moving to better position')
                    IssueClearCommands({experimental})
                    IssueMove({experimental}, targetPos )
                    coroutine.yield(50)
                end
            end

            -- Check if we or the target are under a shield
            local closestBlockingShield = false
            if not airUnit then
                closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
            end
            closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)

            -- Kill shields loop
            while closestBlockingShield and not closestBlockingShield.Dead do
                IssueClearCommands({experimental})
                local shieldPosition = closestBlockingShield:GetPosition()
                --RNGLOG('Exp unit found closest blocking shield moving to attack')
                if VDist3Sq(experimental:GetPosition(), shieldPosition) < 6400 then
                    IssueMove({experimental}, shieldPosition)
                else
                    ExpMoveToPosition(aiBrain, self, closestBlockingShield, experimental, true)
                end
                coroutine.yield(10)
                if closestBlockingShield and not closestBlockingShield.Dead then
                    IssueAttack({experimental}, closestBlockingShield)
                end

                -- Wait for shield to die loop
                while not closestBlockingShield.Dead and not experimental.Dead do
                    coroutine.yield(20)
                    unitPos = GetPlatoonPosition(self)
                    shieldPosition = closestBlockingShield:GetPosition()
                    if VDist2Sq(unitPos[1], unitPos[3], shieldPosition[1], shieldPosition[3]) < 6400 then
                        --RNGLOG('Exp unit moving to shield position')
                        IssueClearCommands({experimental})
                        IssueMove({experimental}, shieldPosition)
                        if closestBlockingShield and not closestBlockingShield.Dead then
                            IssueAttack({experimental}, closestBlockingShield)
                        end
                    end
                    coroutine.yield(30)
                    
                end

                closestBlockingShield = false
                if not airUnit then
                    closestBlockingShield = GetClosestShieldProtectingTarget(experimental, experimental)
                end
                closestBlockingShield = closestBlockingShield or GetClosestShieldProtectingTarget(experimental, targetUnit)
                coroutine.yield(1)
                if not targetUnit or targetUnit.Dead then break end
            end
            coroutine.yield(10)
        end
        coroutine.yield(10)
        --RNGLOG('Exp unit restarting full exp loop')
    end
end

function ExpMoveToPosition(aiBrain, platoon, target, unit, ignoreUnits)
    local targetPos
    local destination
    local LandRadiusScanCategory = categories.ALLUNITS - categories.NAVAL - categories.AIR - categories.SCOUT - categories.WALL - categories.INSIGNIFICANTUNIT
    local LandRadiusDetectionCategory = (categories.STRUCTURE * categories.DEFENSE) + (categories.MOBILE * categories.LAND - categories.SCOUT)
    local TargetSearchPriorities = {
        categories.EXPERIMENTAL * categories.LAND,
        categories.STRUCTURE * categories.DEFENSE * categories.DIRECTFIRE,
        categories.STRUCTURE * categories.DEFENSE * categories.INDIRECTFIRE,
        categories.MOBILE * categories.LAND * categories.TECH3,
        categories.MOBILE * categories.LAND,
        categories.STRUCTURE - categories.WALL,
    }
    local function VariableKite(platoon,unit,target, maxDistance)
        local function KiteDist(pos1,pos2,distance)
            local vec={}
            local dist=VDist3(pos1,pos2)
            for i,k in pos2 do
                if type(k)~='number' then continue end
                vec[i]=k+distance/dist*(pos1[i]-k)
            end
            return vec
        end
        local function CheckRetreat(pos1,pos2,target)
            local vel = {}
            vel[1], vel[2], vel[3]=target:GetVelocity()
            local dotp=0
            for i,k in pos2 do
                if type(k)~='number' then continue end
                dotp=dotp+(pos1[i]-k)*vel[i]
            end
            return dotp<0
        end
        if target.Dead then return end
        if unit.Dead then return end
            
        local pos=unit:GetPosition()
        local tpos=target:GetPosition()
        local dest
        local mod=6
        if CheckRetreat(pos,tpos,target) then
            mod=8
        end
        if maxDistance then
            mod = 0
        end
        if unit.MaxWeaponRange then
            dest=KiteDist(pos,tpos,unit.MaxWeaponRange-math.random(1,5)-mod)
        else
            dest=KiteDist(pos,tpos,platoon.MaxPlatoonWeaponRange+5-math.random(1,3)-mod)
        end
        if VDist3Sq(pos,dest)>8 then
            IssueMove({unit},dest)
            coroutine.yield(2)
            return mod
        else
            coroutine.yield(2)
            return mod
        end
    end
    if target and not target.Dead then
        destination = target:GetPosition()
    end
    local path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(platoon.MovementLayer, unit:GetPosition(), destination, 250)
    if path then
        local pathLength = RNGGETN(path)
        local pathCheckRequired = false
        for i=1, pathLength do
            if pathCheckRequired then
                if VDist3Sq(unit:GetPosition(), path[pathLength]) < VDist3Sq(path[i], path[pathLength]) then
                    --RNGLOG('Experimental is closer to end of path than the current path iteration, skipping forward')
                    continue
                else
                    --RNGLOG('Experimental is further to end of path than the current path iteration, pathCheckRequired being set to false')
                    pathCheckRequired = false
                end
            end
            IssueMove({unit}, path[i])
            local unitPosition
            local lastDist
            local dist
            local stuck = 0
            while unit and not unit.Dead do
                unitPosition = unit:GetPosition()
                if not unitPosition then return end
                dist = VDist3Sq(path[i], unitPosition)
                if dist < 400 then
                    IssueClearCommands({unit})
                    break
                end
                if lastDist ~= dist then
                    stuck = 0
                    lastDist = dist
                else
                    stuck = stuck + 1
                    if stuck > 15 then
                        IssueClearCommands({unit})
                        break
                    end
                end
                if not ignoreUnits and not RUtils.PositionInWater(unit:GetPosition()) then
                    local enemyUnitCount = GetNumUnitsAroundPoint(aiBrain, LandRadiusDetectionCategory, unitPosition, 70, 'Enemy')
                    if enemyUnitCount > 0 then
                        pathCheckRequired = true
                        local target, acuInRange, acuUnit, totalThreat = RUtils.AIFindBrainTargetInCloseRangeRNG(aiBrain, platoon, unitPosition, 'Attack', 70, LandRadiusScanCategory, TargetSearchPriorities, false)
                        --RNGLOG('Experimental is detecting a total threat of '..totalThreat)
                        if acuInRange then
                            target = acuUnit
                        end
                        if totalThreat['AntiSurface'] > 20 then
                            local retreatTrigger = 0
                            local retreatTimeout = 0
                            while unit and not unit.Dead do
                                if target and not target.Dead then
                                    if unit.Dead then return end
                                    if not unit.MaxWeaponRange then
                                        coroutine.yield(3)
                                        WARN('Warning : Experimental has no max weapon range')
                                        unit.MaxWeaponRange = 20
                                        continue
                                    end
                                    IssueClearCommands({unit})
                                    retreatTrigger = VariableKite(platoon,unit,target, false)
                                else
                                    IssueClearCommands({unit})
                                    IssueMove({unit},path[i])
                                    break
                                end
                                if retreatTrigger > 5 then
                                    retreatTimeout = retreatTimeout + 1
                                end
                                coroutine.yield(60)
                                if target and not target.Dead then
                                    --IssueClearCommands({unit})
                                    IssueMove({unit},target:GetPosition())
                                    coroutine.yield(40)
                                end
                                if retreatTimeout > 3 then
                                    --RNGLOG('platoon stopped chasing unit')
                                    break
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            if target.Dead then
                break
            end
        end
        if not target.Dead then
            IssueMove({unit}, destination)
        end
    else
        --RNGLOG('Exp unit has no path to target')
    end
end

GetNukeStrikePositionRNG = function(aiBrain, platoon)
    if not aiBrain or not platoon then
        return nil
    end
    local function GetMissileDetails(ALLBPS, unitId)
        if ALLBPS[unitId].Weapon[1].DamageType == 'Nuke' and ALLBPS[unitId].Weapon[1].ProjectileId then
            local projBp = ALLBPS[unitId].Weapon[1].ProjectileId
            return ALLBPS[projBp].Economy.BuildCostMass, ALLBPS[unitId].Weapon[1].NukeInnerRingRadius
        end
        return false
    end
    -- Look for commander first
    local ALLBPS = __blueprints
    local AIFindNumberOfUnitsBetweenPointsRNG = import('/lua/ai/aiattackutilities.lua').AIFindNumberOfUnitsBetweenPointsRNG
    local im = IntelManagerRNG.GetIntelManager(aiBrain)
    local platoonPosition = GetPlatoonPosition(platoon)
    -- minimumValue : I want to make sure that whatever we shoot at it either an ACU or is worth more than the missile we just built.
    local minimumValue = 0
    local targetPositions = {}
    local validPosition = false
    local missileCost
    local missileRadius
    for _, sml in GetPlatoonUnits(platoon) do
        if sml and not sml.Dead then
            local smlMissileCost, smlMissileRadius = GetMissileDetails(ALLBPS, sml.UnitId)
            if not missileCost or smlMissileCost > missileCost then
                missileCost = smlMissileCost
            end
            if not missileRadius or smlMissileRadius > missileRadius then
                missileRadius = smlMissileRadius
            end
        end
    end
    --RNGLOG('SML Missile cost is '..missileCost)
    --RNGLOG('SML Missile radius is '..missileRadius)
    if not missileRadius or not missileCost then
        -- fallback incase its a strange launcher
        missileRadius = 30
        missileCost = 12000
    end
    

    for k, v in aiBrain.EnemyIntel.ACU do
        if (not v.Unit.Dead) and (not v.Ally) and v.HP ~= 0 and v.LastSpotted ~= 0 then
            if RUtils.HaveUnitVisual(aiBrain, v.Unit, true) then
                RNGINSERT(targetPositions, {v.Position, type = 'COMMAND'})
            end
        end
    end

    --RNGLOG(' ACUs detected are '..table.getn(targetPositions))

    if not table.empty(targetPositions) then
        for _, pos in targetPositions do
            local antinukes = AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, platoonPosition, pos[1], categories.ANTIMISSILE * categories.SILO, 90, 'Enemy')
            if antinukes < 1 then
                validPosition = pos[1]
                break
            end
        end
        if validPosition then
            --RNGLOG('Valid Nuke Target Position with no Anti Nukes is '..repr(validPosition))
            return validPosition
        end
    end

    if not im.MapIntelStats.ScoutLocationsBuilt then
        -- No target
        return aiBrain:GetHighestThreatPosition(0, true, 'Economy')
    end

    -- Now look through the bases for the highest economic threat and largest cluster of units
    local targetShortList = {}
    local enemyBases = aiBrain.EnemyIntel.EnemyThreatLocations
    local bestBaseThreat = nil
    local maxBaseThreat = 0
    for _, x in enemyBases do
        for _, z in x do
            if z.StructuresNotMex then
                local posThreat = aiBrain:GetThreatAtPosition(z.Position, aiBrain.BrainIntel.IMAPConfig.Rings, true, 'Economy')
                RNGINSERT(targetShortList, { threat = posThreat, position = z.Position, massvalue = 0 })
            end
        end
    end
    RNGSORT( targetShortList, function(a,b) return a.threat > b.threat  end )

    --RNGLOG('targetShortList 1st pass '..repr(targetShortList))

    if table.getn(targetShortList) == 0 then
        -- No threat
        return
    end

    -- Look for a cluster of structures
    local SMDPositions = {}
    local highestValue = -1
    local bestThreat = 1
    for _, target in targetShortList do
        if target.threat > 0 then
            local numunits = 0
            local massValue = 0
            local unitsAtLocation = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, target.position, missileRadius, 'Enemy')
            for k, v in unitsAtLocation do
                numunits = numunits + 1
                local unitPos = v:GetPosition()
                local completion = v:GetFractionComplete()
                if EntityCategoryContains(categories.TECH3 * categories.ANTIMISSILE * categories.SILO, v) then
                    --RNGLOG('Found SMD')
                    if not aiBrain.EnemyIntel.SMD[v.EntityId] then
                        aiBrain.EnemyIntel.SMD[v.EntityId] = {object = v, Position=unitPos , Detected=GetGameTimeSeconds()}
                    end
                    if completion == 1 then
                        if aiBrain.EnemyIntel.SMD[v.EntityId].Detected + 240 < GetGameTimeSeconds() then
                            RNGINSERT(SMDPositions, { Position = unitPos, Radius = v.Blueprint.Weapon[1].MaxRadius * v.Blueprint.Weapon[1].MaxRadius, EntityId = v.EntityId})
                        end
                        --RNGLOG('AntiNuke present at location')
                    end
                    if 3 > platoon.ReadySMLCount then
                        break
                    end
                end
                if completion > 0.4 then
                    if v.Blueprint.Economy.BuildCostMass then
                        massValue = massValue + v.Blueprint.Economy.BuildCostMass
                    end
                end
            end
            target.massvalue = massValue
        end
    end
    RNGSORT( targetShortList, function(a,b) return a.massvalue > b.massvalue  end )
    for _, finalTarget in targetShortList do
        local bestPos = {0, 0, 0}
        local maxValue = 0
        if finalTarget.massvalue > (missileCost / 2) then
            local lookAroundTable = {-2, -1, 0, 1, 2}
            local squareRadius = (ScenarioInfo.size[1] / 16) / RNGGETN(lookAroundTable)
            local smdCovered = false
            for ix, offsetX in lookAroundTable do
                for iz, offsetZ in lookAroundTable do
                    local searchPos = {finalTarget.position[1] + offsetX*squareRadius, 0, finalTarget.position[3]+offsetZ*squareRadius}
                    local unitsAtLocation = aiBrain:GetUnitsAroundPoint(categories.STRUCTURE, searchPos, missileRadius, 'Enemy')
                    local currentValue = 0
                    for _, v in unitsAtLocation do
                        if v.Blueprint.Economy.BuildCostMass then
                            currentValue = currentValue + v.Blueprint.Economy.BuildCostMass
                        end
                    end
                    if currentValue > maxValue then
                        maxValue = currentValue
                        for _, v in SMDPositions do
                            --RNGLOG('Distance of SMD from strike position '..VDist3Sq(searchPos, v.Position)..' radius of smd is '..v.Radius)
                            if v.object and not IsDestroyed(v.object) and VDist3Sq(searchPos, v.Position) < v.Radius then
                                smdCovered = true
                                break
                            end
                        end
                        if not smdCovered then
                            local antinukes = AIFindNumberOfUnitsBetweenPointsRNG( aiBrain, platoonPosition, searchPos, categories.ANTIMISSILE * categories.SILO, 90, 'Enemy')
                            --RNGLOG('No smd covering position, check for smds between points, count is  '..antinukes)
                            if antinukes > 0 then
                                smdCovered = true
                                break
                            end
                        bestPos = table.copy(unitsAtLocation[1]:GetPosition())
                        end
                    end
                end
                if smdCovered then
                    break
                end
            end
        end
        if bestPos[1] ~= 0 and bestPos[3] ~= 0 then
            --RNGLOG('Best pos found with a mass value of '..maxValue)
            --RNGLOG('Best pos position is '..repr(bestPos))
            return bestPos
        end
    end
    return nil
end

function AirUnitRefitRNG(self)
    for k, v in self:GetPlatoonUnits() do
        if not v.Dead and not v.RefitThread then
            v.RefitThreat = v:ForkThread(AirUnitRefitThreadRNG, self:GetPlan(), self.PlatoonData)
        end
    end
end

function AirUnitRefitThreadRNG(unit, plan, data)
    unit.PlanName = plan
    if data then
        unit.PlatoonData = data
    end

    local aiBrain = unit:GetAIBrain()
    while not unit.Dead do
        local fuel = unit:GetFuelRatio()
        local health = unit:GetHealthPercent()
        if not unit.Loading and (fuel < 0.2 or health < 0.4) then
            -- Find air stage
            --RNGLOG('AirStaging behavior triggered ')
            if aiBrain:GetCurrentUnits(categories.AIRSTAGINGPLATFORM) > 0 then
                local unitPos = unit:GetPosition()
                local plats = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.AIRSTAGINGPLATFORM, unitPos, 400)
                --RNGLOG('AirStaging Units found '..table.getn(plats))
                if not table.empty(plats) then
                    local closest, distance
                    for _, v in plats do
                        if not v.Dead then
                            local roomAvailable = false
                            if not EntityCategoryContains(categories.CARRIER, v) then
                                roomAvailable = v:TransportHasSpaceFor(unit)
                            end
                            if roomAvailable then
                                local platPos = v:GetPosition()
                                local tempDist = VDist2Sq(unitPos[1], unitPos[3], platPos[1], platPos[3])
                                if not closest or tempDist < distance then
                                    closest = v
                                    distance = tempDist
                                end
                            end
                        end
                    end
                    if closest then
                        local plat = aiBrain:MakePlatoon('', '')
                        aiBrain:AssignUnitsToPlatoon(plat, {unit}, 'Attack', 'None')
                        IssueClearCommands({unit})
                        IssueTransportLoad({unit}, closest)
                        --RNGLOG('Transport load issued')
                        if EntityCategoryContains(categories.AIRSTAGINGPLATFORM, closest) and not closest.AirStaging then
                            --RNGLOG('Air Refuel Forking AirStaging Thread for fighter')
                            closest.AirStaging = closest:ForkThread(AirStagingThreadRNG)
                            closest.Refueling = {}
                        elseif EntityCategoryContains(categories.CARRIER, closest) and not closest.CarrierStaging then
                            closest.CarrierStaging = closest:ForkThread(CarrierStagingThread)
                            closest.Refueling = {}
                        end
                        RNGINSERT(closest.Refueling, unit)
                        unit.Loading = true
                    end
                else
                    --RNGLOG('No AirStaging Units found in range')
                end
            else
                aiBrain.BrainIntel.AirStagingRequired = true
            end
        end
        coroutine.yield(15)
    end
end

AhwassaBehaviorRNG = function(self)
    local aiBrain = self:GetBrain()
    local experimental = GetExperimentalUnit(self)
    if not experimental then
        return
    end

    if not EntityCategoryContains(categories.xsa0402, experimental) then
        return
    end

    AssignExperimentalPriorities(self)

    local targetLocation = GetHighestThreatClusterLocation(aiBrain, experimental)
    local oldTargetLocation = nil
    while not experimental.Dead do
        if targetLocation and targetLocation ~= oldTargetLocation then
            IssueClearCommands({experimental})
            IssueAttack({experimental}, targetLocation)
            coroutine.yield(250)
        end
        coroutine.yield(10)

        oldTargetLocation = targetLocation
        targetLocation = GetHighestThreatClusterLocation(aiBrain, experimental)
    end
end

function AirStagingThreadRNG(unit)
    local aiBrain = unit:GetAIBrain()
    --LOG('Starting Air Staging thread')

    while not unit.Dead do
        local numUnits = 0
        local refueledUnits = {}
        LOG('Current refueling count '..table.getn(unit.Refueling))
        for k, v in unit.Refueling do
            if not v.Dead then
                if (not v:GetFuelRatio() < 1) and (not v:GetHealthPercent() < 1) then
                    numUnits = numUnits + 1
                    RNGINSERT(refueledUnits, {Unit = v, Key = k})
                end
            end
        end
        LOG('Number of Units ready to deploy '..numUnits)
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