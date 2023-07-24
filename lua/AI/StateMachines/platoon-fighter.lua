local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG


-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local TableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort

---@class AIPlatoonACUBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonFighterBehavior = Class(AIPlatoon) {

    PlatoonName = 'FighterBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonACUBehavior
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
            local brain = self:GetBrain()
            StartFighterThreads(brain, self)

            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            self.Home = brain.BuilderManagers[self.LocationType].Position
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            if self.CurrentEnemyThreat > self.CurrentPlatoonThreat and not self.BuilderData.ProtectACU then
                self:ChangeState(self.Retreating)
                return
            end
            
        end,

    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local position = self:GetPlatoonPosition()
            local AlliedPlatoons = brain:GetPlatoonsList()
            local closestPlatoon = false
            local closestPlatoonDistance = false
            local closestAPlatPos = false
            for _,aPlat in AlliedPlatoons do
                if aPlat.SyncId == self.SyncId then
                    continue
                end
                local aPlatAirThreat = self:CalculatePlatoonThreat('Air', categories.ALLUNITS)
                if aPlatAirThreat > self.CurrentEnemyThreat / 2 then
                    local aPlatPos = GetPlatoonPosition(aPlat)
                    local aPlatDistance = VDist2Sq(position[1],position[3],aPlatPos[1],aPlatPos[3])
                    local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],self.Home[1],self.Home[3])
                    if aPlatToHomeDistance < distanceToHome then
                        local platoonValue = aPlatDistance * aPlatDistance / aPlatAirThreat
                        --RNGLOG('Platoon Distance '..aPlatDistance)
                        --RNGLOG('Weighting is '..platoonValue)
                        if not closestPlatoonDistance or platoonValue <= closestPlatoonDistance then
                            closestPlatoon = aPlat
                            closestPlatoonDistance = platoonValue
                            closestAPlatPos = aPlatPos
                        end
                    end
                end
            end
            local closestBase = false
            local closestBaseDistance = false
            if brain.BuilderManagers then
                for baseName, base in brain.BuilderManagers do
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                    if RNGGETN(base.FactoryManager.FactoryList) > 0 then
                        --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                        local baseDistance = VDist3Sq(position, base.Position)
                        local homeDistance = VDist3Sq(self.Home, base.Position)
                        if homeDistance < distanceToHome or baseName == 'MAIN' then
                            if not closestBaseDistance or baseDistance <= closestBaseDistance then
                                closestBase = baseName
                                closestBaseDistance = baseDistance
                            end
                        end
                    end
                end
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    --RNGLOG('Closest base is '..closestBase)
                    --RNGLOG('Closest base is '..closestBase)
                    self.BuilderData = {
                        Retreat = true,
                        Position = brain.BuilderManagers[closestBase].Position,
                        Action = 'Loiter'
                    }
                    self:ChangeState(self.MoveToPosition)
                    return
                else
                    --RNGLOG('Found platoon checking if can graph')
                    if closestAPlatPos then
                        --RNGLOG('Closest base is '..closestBase)
                        --RNGLOG('Closest base is '..closestBase)
                        self.BuilderData = {
                            Retreat = true,
                            Position = brain.BuilderManagers[closestBase].Position,
                            Action = 'Loiter'
                        }
                        self:ChangeState(self.MoveToPosition)
                        return
                    end
                end
            elseif closestBase then
                --RNGLOG('Closest base is '..closestBase)
                self.BuilderData = {
                    Retreat = true,
                    Position = brain.BuilderManagers[closestBase].Position,
                    Action = 'Loiter'
                }
                self:ChangeState(self.MoveToPosition)
                return
            elseif closestPlatoon then
                --RNGLOG('Found platoon checking if can graph')
                if closestAPlatPos then
                    self.BuilderData = {
                        Retreat = true,
                        Position = closestAPlatPos,
                        Action = 'Loiter'
                    }
                    self:ChangeState(self.MoveToPosition)
                    return
                end
            end

        end,
    },

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        local count = RNGGETN(units)
        local brain = self:GetBrain()
        if count > 0 then
            local supportUnits = self:GetSquadUnits('Support')
            if supportUnits then
                for _, unit in supportUnits do
                    IssueClearCommands(unit)
                    if not unit.Dead and v:TestToggleCaps('RULEUTC_StealthToggle') then
                        unit:SetScriptBit('RULEUTC_StealthToggle', false)
                    end
                    if not unit.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                        unit:SetScriptBit('RULEUTC_CloakToggle', false)
                    end
                end
            end
        end
    end,

}



---@param data { Behavior: 'AIBehaviorFighterSimple' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not TableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonFighterBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands(unit)
                if not unit.Dead and v:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and v:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end

---@param data { Behavior: 'AIBehaviorFighterSimple' }
---@param units Unit[]
StartFighterThreads = function(brain, platoon)
    brain:ForkThread(StartFighterThreads, platoon)
end

---@param brain AIBrain
---@param platoon AIPlatoon
FighterThreatThreads = function(brain, platoon)
    coroutine.yield(10)
    local UnitCategories = categories.ANTIAIR
    while brain:PlatoonExists(platoon) do
        local platPos = platoon:GetPlatoonPosition()
        local enemyThreat
        if GetNumUnitsAroundPoint(aiBrain, UnitCategories, platPos, 80, 'Enemy') > 0 then
            local enemyUnits = GetUnitsAroundPoint(brain, UnitCategories, platoon:GetPlatoonPosition(), 80, 'Enemy')
            for _, v in enemyUnits do
                if v and not IsDestroyed(v) then
                    if v.Blueprint.Defense.AirThreatLevel then
                        enemyThreat = enemyThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end
            end
            platoon.CurrentEnemyThreat = enemyThreat
            platoon.CurrentPlatoonThreat = platoon:CalculatePlatoonThreat('Air', categories.ALLUNITS)
            if platoon.CurrentEnemyThreat > platoon.CurrentPlatoonThreat and not platoon.BuilderData.ProtectACU then
                platoon:ChangeState(platoon.DecideWhatToDo)
            end
        end
        coroutine.yield(20)
    end
end