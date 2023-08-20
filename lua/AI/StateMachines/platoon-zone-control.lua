local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')

---@class AIPlatoonBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonBehavior = Class(AIPlatoon) {

    PlatoonName = 'ZoneControlBehavior',

    ---@param self AIPlatoon
    OnDestroy = function(self)
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        self.Trash:Destroy()
    end,

    PlatoonDisbandNoAssign = function(self)
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        for k,v in self:GetPlatoonUnits() do
            v.PlatoonHandle = nil
        end
        self:GetBrain():DisbandPlatoon(self)
    end,

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonBehavior
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
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            if aiBrain.EnemyIntel.Phase > 1 then
                self.EnemyRadius = 70
            else
                self.EnemyRadius = 55
            end
            if type(self.PlatoonData.MaxPathDistance) == 'string' then
                self.MaxPathDistance = aiBrain.OperatingAreas[self.PlatoonData.MaxPathDistance]
            else
                self.MaxPathDistance = self.PlatoonData.MaxPathDistance or 200
            end
            self.MaxPlatoonWeaponRange = false
            self.ScoutUnit = false
            self.atkPri = {}
            self.CurrentPlatoonThreat = false
            self.ZoneType = self.PlatoonData.ZoneType or 'control'
            RUtils.ConfigurePlatoon(self)

        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local platPos = self:GetPlatoonPosition()
            local threat=RUtils.GrabPosDangerRNG(aiBrain,platPos,self.EnemyRadius)
            if threat.ally and threat.enemy and threat.ally*1.1 < threat.enemy then
                self.retreat=true
                self:ChangeState(self.Retreating)
                return
            else
                self.retreat=false
            end
            if self.BuilderData.AttackTarget and not IsDestroyed(self.BuilderData.AttackTarget) then
                local targetPos = self.BuilderData.AttackTarget:GetPosition()
                local ax = platPos[1] - targetPos[1]
                local az = platPos[3] - targetPos[3]
                if ax * ax + az * az < self.EnemyRadius * self.EnemyRadius then
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local target
            if not target and not targetZone then
                if StateUtils.SimpleTarget(self,aiBrain) then
                    self:ChangeState(self.CombatLoop)
                    return
                end
            end
            local targetZone
            if not target then
                target = RUtils.CheckHighPriorityTarget(aiBrain, nil, self)
                if target and RUtils.HaveUnitVisual(aiBrain, highPriorityTarget, true) then
                    self.BuilderData = {
                        AttackTarget = target,
                        Position = target:GetPosition()
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            if not targetZone then
                targetZone = IntelManagerRNG.GetIntelManager(aiBrain):SelectZoneRNG(aiBrain, self, self.ZoneType)
                if targetZone then
                    self.BuilderData = {
                        TargetZone = targetZone,
                        Position = aiBrain.Zones.Land.zones[targetZone].pos
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
        end,
    },


}

---@param data { Behavior: 'AIBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not table.empty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonBehavior)
        local platoonUnits = platoon:GetPlatoonUnits()
        if platoonUnits then
            for _, unit in platoonUnits do
                IssueClearCommands(unit)
                unit.PlatoonHandle = platoon
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_StealthToggle') then
                    unit:SetScriptBit('RULEUTC_StealthToggle', false)
                end
                if not unit.Dead and unit:TestToggleCaps('RULEUTC_CloakToggle') then
                    unit:SetScriptBit('RULEUTC_CloakToggle', false)
                end
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end