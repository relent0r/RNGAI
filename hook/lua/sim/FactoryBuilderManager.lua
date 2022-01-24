local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG

RNGFactoryBuilderManager = FactoryBuilderManager
FactoryBuilderManager = Class(RNGFactoryBuilderManager) {
    
    

    SetRallyPoint = function(self, factory)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.SetRallyPoint(self, factory)
        end

        local position = factory:GetPosition()
        local rally = false

        if self.RallyPoint then
            IssueClearFactoryCommands({factory})
            IssueFactoryRallyPoint({factory}, self.RallyPoint)
            return true
        end

        local rallyType = 'Rally Point'
        if EntityCategoryContains(categories.NAVAL, factory) then
            rallyType = 'Naval Rally Point'
        end

        if not self.UseCenterPoint then
            -- Find closest marker to averaged location
            rally = AIUtils.AIGetClosestMarkerLocation(self, rallyType, position[1], position[3])
        elseif self.UseCenterPoint then
            -- use BuilderManager location
            rally = AIUtils.AIGetClosestMarkerLocation(self, rallyType, position[1], position[3])
            local expPoint = AIUtils.AIGetClosestMarkerLocation(self, 'Expansion Area', position[1], position[3])

            if expPoint and rally then
                local rallyPointDistance = VDist2(position[1], position[3], rally[1], rally[3])
                local expansionDistance = VDist2(position[1], position[3], expPoint[1], expPoint[3])

                if expansionDistance < rallyPointDistance then
                    rally = expPoint
                end
            end
        end

        -- Use factory location if no other rally or if rally point is far away
        if not rally or VDist2(rally[1], rally[3], position[1], position[3]) > 75 then
            -- DUNCAN - added to try and vary the rally points.
            --RNGLOG('No Rally Point Found. Setting Point between me and enemy Location')
            local position = false
            if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                -- Spawn locations were fixed. We know exactly where our opponents are.
                -- We're Going to set out land rally point in the direction of the enemy
                local numOpponents = 0
                local enemyStarts = {}
                local myArmy = ScenarioInfo.ArmySetup[self.Brain.Name]
                local locationType = self.LocationType

                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                            -- Add the army start location to the list of interesting spots.
                            local opponentStart = startPos
                            
                            local factoryPos = self.Brain.BuilderManagers[locationType].Position
                            --RNGLOG('Start Locations :Opponent'..repr(opponentStart)..' Myself :'..repr(factoryPos))
                            local startDistance = VDist2(opponentStart[1], opponentStart[3], factoryPos[1], factoryPos[3])
                            if EntityCategoryContains(categories.AIR, factory) then
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 60})
                                --RNGLOG('Air Rally Position is :'..repr(position))
                                break
                            else
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 30})
                                --RNGLOG('Rally Position is :'..repr(position))
                                break
                            end
                        end
                    end
                end
            else
                --RNGLOG('No Rally Point Found. Setting Random Location')
                position = AIUtils.RandomLocation(position[1],position[3])
            end
            rally = position
        end

        IssueClearFactoryCommands({factory})
        IssueFactoryRallyPoint({factory}, rally)
        self.RallyPoint = rally
        return true
    end,

    DelayBuildOrder = function(self,factory,bType,time)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.DelayBuildOrder(self,factory,bType,time)
        end
        local guards = factory:GetGuards()
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBodyRNG)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        if factory.DelayThread then
            return
        end
        factory.DelayThread = true
        coroutine.yield(math.random(10,30))
        factory.DelayThread = false
        if factory.Offline then
            while factory.Offline and factory and (not factory.Dead) do
                --RNGLOG('Factory is offline, wait inside delaybuildorder')
                coroutine.yield(25)
            end
            self:AssignBuildOrder(factory,bType)
        else
            self:AssignBuildOrder(factory,bType)
        end
    end,

    FactoryFinishBuilding = function(self,factory,finishedUnit)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.FactoryFinishBuilding(self,factory,finishedUnit)
        end
        --RNGLOG('RNG FactorFinishedbuilding')
        if EntityCategoryContains(categories.ENGINEER, finishedUnit) then
            self.Brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(finishedUnit)
        elseif EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit ) then
            --RNGLOG('Factory Built by factory, attempting to kill factory.')
			if finishedUnit:GetFractionComplete() == 1 then
               --LOG('RNG FactoryFinishBuilding has fired')
				self:AddFactory(finishedUnit )			
				factory.Dead = true
                factory.Trash:Destroy()
                --RNGLOG('Destroy Factory')
				return self:FactoryDestroyed(factory)
			end
		end
        --self.Brain:RemoveConsumption(self.LocationType, factory)
        self:AssignBuildOrder(factory, factory.BuilderManagerData.BuilderType)
    end,

    FactoryDestroyed = function(self, factory)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.FactoryDestroyed(self, factory)
        end
        --RNGLOG('Factory Destroyed '..factory.UnitId)
        --RNGLOG('We have '..table.getn(self.FactoryList) ' at the start of the FactoryDestroyed function')
        local guards = factory:GetGuards()
        local factoryDestroyed = false
        for k,v in guards do
            if not v.Dead and v.AssistPlatoon then
                if self.Brain:PlatoonExists(v.AssistPlatoon) then
                    v.AssistPlatoon:ForkThread(v.AssistPlatoon.EconAssistBodyRNG)
                else
                    v.AssistPlatoon = nil
                end
            end
        end
        for k,v in self.FactoryList do
            if (not v.Sync.id) or v.Dead then
                --RNGLOG('Removing factory from FactoryList'..v.UnitId)
                self.FactoryList[k] = nil
                factoryDestroyed = true
            end
        end
        if factoryDestroyed then
            --RNGLOG('Performing table rebuild')
            self.FactoryList = self:RebuildTable(self.FactoryList)
        end
        --RNGLOG('We have '..table.getn(self.FactoryList) ' at the end of the FactoryDestroyed function')
        for k,v in self.FactoryList do
            if not v.Dead then
                return
            end
        end
        self.LocationActive = false
        --self.Brain:RemoveConsumption(self.LocationType, factory)
    end,

}

