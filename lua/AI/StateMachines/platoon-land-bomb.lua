local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local AIAttackUtils = import("/lua/ai/aiattackutilities.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort
local RNGMAX = math.max

---@class AIPlatoonLandBombCombatBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonLandBombCombatBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'LandBombCombatBehavior',
    Debug = false,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonLandBombCombatBehavior
        Main = function(self)
            -- requires expansion markers
            if not import("/lua/sim/markerutilities/expansions.lua").IsGenerated() then
                self:LogWarning('requires generated expansion markers')
                self:ChangeState(self.Error)
                return
            end

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end
            local aiBrain = self:GetBrain()
            self.MergeType = 'LandBombMergeStateMachine'
            StartLandCombatThreads(aiBrain, self)
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.ScoutSupported = true
            self.Home = aiBrain.BuilderManagers[self.LocationType].Position
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = math.max(self.MaxPlatoonWeaponRange+35, 70)
            else
                self.EnemyRadius = math.max(self.MaxPlatoonWeaponRange+35, 55)
            end
            self.WeaponDamage = 1
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandBombCombatBehavior
        Main = function(self)
            if self.Vented then
                --LOG('Vented LandCombatPlatoon Deciding what to do')
            end
            local aiBrain = self:GetBrain()
            local target
            
            if aiBrain.BrainIntel.SuicideModeActive and aiBrain.BrainIntel.SuicideModeTarget and not aiBrain.BrainIntel.SuicideModeTarget.Dead then
                self:LogDebug('Checking for SuicideModeActive')
                local enemyAcuPosition = aiBrain.BrainIntel.SuicideModeTarget:GetPosition()
                local rx = self.Pos[1] - enemyAcuPosition[1]
                local rz = self.Pos[3] - enemyAcuPosition[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, enemyAcuPosition) then
                    self:LogDebug('Found SuicideMode enemy acu')
                    if acuDistance > 6400 then
                        self.BuilderData = {
                            AttackTarget = aiBrain.BrainIntel.SuicideModeTarget,
                            Position = aiBrain.BrainIntel.SuicideModeTarget:GetPosition(),
                            CutOff = 400
                        }
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:ChangeState(self.SuicideLoop)
                        return
                    end
                end
            end
            local requiredCount = 0
            local acuIndex
            local platoonUnits = self:GetPlatoonUnits()
            local currentPlatoonCount = RNGGETN(platoonUnits)
            if not target then
                self:LogDebug('Checking for ACUSnipe Opporunity')
                target, requiredCount, acuIndex = RUtils.CheckACUSnipe(aiBrain, self.MovementLayer)
                if target then
                    self:LogDebug('Found ACUSnipe enemy acu')
                    local hp = aiBrain.EnemyIntel.ACU[acuIndex].HP
                    requiredCount = math.ceil(hp / self.WeaponDamage)
                end
                if not target then
                    if RNGGETN(platoonUnits) >= 2 then
                        self:LogDebug('Checking for Closest enemy acu')
                        target = self:FindClosestUnit('Attack', 'Enemy', true, categories.COMMAND )
                        if target then
                            self:LogDebug('Found closest enemy acu')
                            local hp = target:GetHealth()
                            requiredCount = math.ceil(hp / self.WeaponDamage)
                            self:LogDebug('Count required is '..tostring(requiredCount))
                            self:LogDebug('Current platoon count is '..tostring(currentPlatoonCount))
                            if currentPlatoonCount < requiredCount then
                                self:LogDebug('Trying to merge with other bomb platoons ')
                                StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandBombMergeStateMachine', 80, 35, true)
                            end
                        end
                    end
                end
            end
            if target and not target.Dead and currentPlatoonCount >= requiredCount then
                local targetPos = target:GetPosition()
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                local acuDistance = rx * rx + rz * rz
                if NavUtils.CanPathTo(self.MovementLayer, self.Pos, targetPos) then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = targetPos,
                        CutOff = 400
                    }
                    if acuDistance > 6400 then
                        self:LogDebug('Navigating to target ')
                        self.dest = self.BuilderData.Position
                        self:ChangeState(self.Navigating)
                        return
                    else
                        self:LogDebug('Suicide Loop')
                        self:ChangeState(self.SuicideLoop)
                        return
                    end
                end
            end
            coroutine.yield(25)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    SuicideLoop = State {

        StateName = 'SuicideLoop',

        --- The platoon searches for a target
        ---@param self AIPlatoonLandBombCombatBehavior
        Main = function(self)
            self.ExcludeFromMerge = true
            local aiBrain = self:GetBrain()
            local target = self.BuilderData.AttackTarget
            local targetPos =  self.BuilderData.Position
            local waitTime = RUtils.CenterPlatoonUnitsRNG(self, self.Pos)
            waitTime = waitTime * 10
            self:LogDebug('Wait for platoon center '..tostring(waitTime))
            coroutine.yield(waitTime)
            self:LogDebug('Issuing attack')
            while not IsDestroyed(self) do
                self:LogDebug('Waiting for target')
                if target.Dead then
                    break
                end
                local unitRange = StateUtils.GetUnitMaxWeaponRange(target, 'Direct Fire') or 15
                self:LogDebug('Unit Range is '..tostring(unitRange))
                local targetPos = target:GetPosition()
                local allyUnits = aiBrain:GetNumUnitsAroundPoint(categories.ALLUNITS - categories.SCOUT - categories.INSIGNIFICANTUNIT, targetPos, unitRange , 'Ally')
                if allyUnits > 3 then
                    self:LogDebug('More than 3 units around target, move to attack')
                    local units=GetPlatoonUnits(self)
                    for _,v in units do
                        if v and not v.Dead then
                            IssueClearCommands({v})
                            IssueAttack({v}, target)
                        end
                    end
                else
                    self:LogDebug('Less than 3 units around target, move to lerp')
                    local units=GetPlatoonUnits(self)
                    local currentDistance = VDist3(targetPos, self.Pos)
                    for _,v in units do
                        if v and not v.Dead then
                            IssueClearCommands({v})
                            IssueMove({v}, RUtils.lerpy(self.Pos, targetPos, {currentDistance, currentDistance - unitRange + 10}))
                        end
                    end
                end
                coroutine.yield(30)
            end
            coroutine.yield(30)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Navigating = State {

        StateName = "Navigating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandBombCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local im = IntelManagerRNG.GetIntelManager(aiBrain)
            local builderData = self.BuilderData
            local destination
            local platPos = self:GetPlatoonPosition()
            if not builderData then
                coroutine.yield(10)
                self:LogDebug(string.format('MobileBomb had no builderData in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if not destination then
                coroutine.yield(10)
                self:LogDebug(string.format('MobileBomb had no destination in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local path, reason = AIAttackUtils.PlatoonGeneratePathToRNG(self.MovementLayer, self.Pos, builderData.Position, 300, 20)
            if not path then
                self.BuilderData = {}
                --LOG('No Path in scout navigation, reason is '..repr(reason))
                coroutine.yield(10)
                self:LogDebug(string.format('MobileBomb had no path in navigation'))
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local pathNodesCount = RNGGETN(path)
            for i=1, pathNodesCount do
                local distEnd = false
                local Lastdist
                local dist
                local Stuck = 0
                for _, unit in GetPlatoonUnits(self) do
                    if not unit.Dead then
                        if unit.GetNavigator then
                            local navigator = unit:GetNavigator()
                            if navigator then
                                navigator:SetGoal(path[i])
                            end
                        else
                            IssueMove({unit},path[i])
                        end
                    end
                end
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(25)
                    platPos = self:GetPlatoonPosition()
                    if IsDestroyed(self) or not platPos then
                        return
                    end
                    local px = path[i][1] - platPos[1]
                    local pz = path[i][3] - platPos[3]
                    dist = px * px + pz * pz
                    if dist < 400 then
                        break
                    end
                    if Lastdist ~= dist then
                        Stuck = 0
                        Lastdist = dist
                    else
                        Stuck = Stuck + 1
                        if Stuck > 15 then
                            IssueClearCommands(GetPlatoonUnits(self))
                            break
                        end
                    end
                end
                local dx = destination[1] - platPos[1]
                local dz = destination[3] - platPos[3]
                if dx * dx + dz * dz < 6400 then
                    break
                end
            end
            --LOG('Scout exiting navigating')
            self:LogDebug(string.format('Scout exiting navigating'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonLandBombCombatBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local location = false
            local avoidTargetPos
            local target = StateUtils.GetClosestUnitRNG(aiBrain, self, self.Pos, (categories.MOBILE + categories.STRUCTURE) * (categories.DIRECTFIRE + categories.INDIRECTFIRE),false,  false, 128, 'Enemy')
            if target and not target.Dead then
                local targetRange = StateUtils.GetUnitMaxWeaponRange(target, 'Direct Fire') or 10
                local minTargetRange
                if targetRange then
                    minTargetRange = targetRange + 10
                end
                local avoidRange = math.max(minTargetRange or 60)
                local targetPos = target:GetPosition()
                avoidTargetPos = targetPos
                IssueClearCommands(GetPlatoonUnits(self))
                local rx = self.Pos[1] - targetPos[1]
                local rz = self.Pos[3] - targetPos[3]
                if rx * rx + rz * rz < targetRange * targetRange then
                    self:MoveToLocation(RUtils.AvoidLocation(targetPos, self.Pos, avoidRange), false)
                else
                    local targetCats = target.Blueprint.CategoriesHash
                    local attackStructure = false
                    local platUnits = self:GetPlatoonUnits()
                    if targetCats.STRUCTURE and targetCats.DEFENSE then
                        if targetRange < self.MaxPlatoonWeaponRange then
                            attackStructure = true
                            for _, v in platUnits do
                                --self:LogDebug('Role is '..repr(v.Role))
                                if v.Role == 'Artillery' or v.Role == 'Silo' and not v:IsUnitState("Attacking") then
                                    IssueClearCommands({v})
                                    IssueAttack({v},target)
                                end
                            end
                        end
                    end
                    local zoneRetreat = IntelManagerRNG.GetIntelManager(aiBrain):GetClosestZone(aiBrain, self, false, targetPos, true)
                    if attackStructure then
                        for _, v in platUnits do
                            if v.Role ~= 'Artillery' and v.Role ~= 'Silo' then
                                if zoneRetreat then
                                    IssueMove({v}, aiBrain.Zones.Land.zones[zoneRetreat].pos)
                                else
                                    IssueMove({v}, self.Home)
                                end
                            end
                        end
                    else
                        if zoneRetreat then
                            self:MoveToLocation(aiBrain.Zones.Land.zones[zoneRetreat].pos, false)
                        else
                            self:MoveToLocation(self.Home, false)
                        end
                    end
                end
                coroutine.yield(40)
            end
            if aiBrain.GridPresence:GetInferredStatus(self.Pos) == 'Hostile' then
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), true, 'Enemy')
            else
                location = StateUtils.GetNearExtractorRNG(aiBrain, self, self.Pos, avoidTargetPos, (categories.MASSEXTRACTION + categories.ENGINEER), false, 'Ally')
            end
            if (not location) then
                local closestBase = StateUtils.GetClosestBaseRNG(aiBrain, self, self.Pos)
                if closestBase then
                    --LOG('base only Closest base is '..closestBase)
                    location = aiBrain.BuilderManagers[closestBase].Position
                end
            end
            StateUtils.MergeWithNearbyPlatoonsRNG(self, 'LandBombMergeStateMachine', 80, 35, true)
            self.Retreat = true
            self.BuilderData = {
                Position = location,
                CutOff = 400,
            }
            --LOG('Retreating to platoon')
            self:ChangeState(self.Navigating)
            return
        end,
    },

}



---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if not IsDestroyed(platoon) and units and not RNGTableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonLandBombCombatBehavior)
        platoon.PlatoonData = data.PlatoonData
        local platoonthreat=0
        local platoonhealth=0
        local platoonhealthtotal=0
        local categoryList = {   
            categories.EXPERIMENTAL * categories.LAND,
            categories.ENGINEER,
            categories.MASSEXTRACTION,
            categories.MOBILE * categories.LAND,
            categories.STRUCTURE * categories.ENERGYPRODUCTION,
            categories.ENERGYSTORAGE,
            categories.STRUCTURE * categories.DEFENSE,
            categories.STRUCTURE,
            categories.ALLUNITS,
        }
        if data.Vented then
            --LOG('This is a state machine that was vented from ACU support')
            platoon.Vented = true
        end
        if not platoon.LocationType then
            platoon.LocationType = platoon.PlatoonData.LocationType or 'MAIN'
        end
        local platoonUnits = GetPlatoonUnits(platoon)
        if platoonUnits then
            for _, v in platoonUnits do
                v.PlatoonHandle = platoon
                if not platoon.machinedata then
                    platoon.machinedata = {name = 'TruePlatoon',id=v.EntityId}
                end
                IssueClearCommands({v})
                if EntityCategoryContains(categories.SCOUT, v) then
                    platoon.ScoutPresent = true
                end
                platoonhealth=platoonhealth+StateUtils.GetTrueHealth(v)
                platoonhealthtotal=platoonhealthtotal+StateUtils.GetTrueHealth(v,true)
                local mult=1
                if EntityCategoryContains(categories.INDIRECTFIRE,v) then
                    mult=0.3
                end
                if v.Blueprint.Defense.SurfaceThreatLevel ~= nil then
                    platoonthreat = platoonthreat + v.Blueprint.Defense.SurfaceThreatLevel*StateUtils.GetWeightedHealthRatio(v)*mult
                end
            end
        end
        platoon.Pos=GetPlatoonPosition(platoon)
        platoon.Threat=platoonthreat
        platoon.health=platoonhealth
        platoon.mhealth=platoonhealthtotal
        platoon.rhealth=platoonhealth/platoonhealthtotal
        platoon:OnUnitsAddedToPlatoon()
        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorLandCombat' }
---@param units Unit[]
StartLandCombatThreads = function(brain, platoon)
    brain:ForkThread(LandCombatPositionThread, platoon)
    brain:ForkThread(StateUtils.ZoneUpdate, platoon)
    brain:ForkThread(ThreatThread, platoon)
end

---@param aiBrain AIBrain
---@param platoon AIPlatoon
LandCombatPositionThread = function(aiBrain, platoon)
    local UnitCategories = categories.ANTIAIR
    while aiBrain:PlatoonExists(platoon) do
        local platBiasUnit = RUtils.GetPlatUnitEnemyBias(aiBrain, platoon)
        if platBiasUnit and not platBiasUnit.Dead then
            platoon.Pos=platBiasUnit:GetPosition()
        else
            platoon.Pos=GetPlatoonPosition(platoon)
        end
        coroutine.yield(15)
    end
end

ThreatThread = function(aiBrain, platoon)
    while aiBrain:PlatoonExists(platoon) do
        if IsDestroyed(platoon) then
            return
        end
        local weaponDamage = 0
        local platoonUnits = platoon:GetPlatoonUnits()
        for k, v in platoonUnits do
            if not v.Dead then
                if v.UnitId == 'daa0206' then
                    local damage = v.Blueprint.Weapon[1].DoTPulses * v.Blueprint.Weapon[1].Damage * v.Blueprint.Weapon[1].MuzzleSalvoSize
                    weaponDamage = weaponDamage + damage
                elseif v.UnitId == 'xrl0302' then
                    local damage = v.Blueprint.Weapon[2].Damage
                    weaponDamage = weaponDamage + damage
                end
            end
        end
        platoon.WeaponDamage = weaponDamage * 0.85
        coroutine.yield(35)
    end
end