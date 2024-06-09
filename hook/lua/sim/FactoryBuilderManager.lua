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
            rally = AIUtils.AIGetClosestMarkerLocationRNG(self, rallyType, position[1], position[3])
        elseif self.UseCenterPoint then
            -- use BuilderManager location
            rally = AIUtils.AIGetClosestMarkerLocationRNG(self, rallyType, position[1], position[3])
            local zone = self.Brain.IntelManager:GetClosestZone(self.Brain, false, {position[1], 0, position[3]}, false, false, 2)
            local expPoint = self.Brain.Zones.Land.zones[zone].pos

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
                local locationType = self.LocationType
                local factoryPos = self.Brain.BuilderManagers[locationType].Position
                local startDistance = VDist3(self.Brain.MapCenterPoint, factoryPos)
                position = RUtils.lerpy(self.Brain.MapCenterPoint, factoryPos, {startDistance, startDistance - 60})
                --RNGLOG('Position '..repr(position))
                position = AIUtils.RandomLocation(position[1],position[3])
            end
            rally = position
        end

        IssueClearFactoryCommands({factory})
        IssueFactoryRallyPoint({factory}, rally)
        self.RallyPoint = rally
        if self.Layer == 'Water' then
            --LOG('Water created rally point at position '..repr(rally))
        end
        return true
    end,

    DelayBuildOrder = function(self,factory,bType,time)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.DelayBuildOrder(self,factory,bType,time)
        end
        if factory.DelayThread then
            return
        end
        --self:GenerateInitialQueue('InitialBuildQueueRNG', factory)
        factory.DelayThread = true
        coroutine.yield(math.random(5,15))
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

    AddFactory = function(self,unit)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.AddFactory(self,unit)
        end
        if not self:FactoryAlreadyExists(unit) and unit:GetFractionComplete() == 1 then
            table.insert(self.FactoryList, unit)
            unit.DesiresAssist = true
            if EntityCategoryContains(categories.LAND, unit) then
                self:SetupNewFactory(unit, 'Land')
            elseif EntityCategoryContains(categories.AIR, unit) then
                self:SetupNewFactory(unit, 'Air')
            elseif EntityCategoryContains(categories.NAVAL, unit) then
                --LOG('New naval factory setup for base '..self.LocationType)
                self:SetupNewFactory(unit, 'Sea')
            else
                self:SetupNewFactory(unit, 'Gate')
            end
            self.LocationActive = true
            if self.LocationType then
                local zone = self.Brain.BuilderManagers[self.LocationType].Zone
                LOG('Factory manager is in zone '..tostring(zone))
                if zone then
                    if self.Brain.Zones.Land.zones[zone].engineerplatoonallocated then
                        self.Brain.Zones.Land.zones[zone].engineerplatoonallocated = nil
                    end
                end
            end
        end
    end,

    FactoryFinishBuilding = function(self,factory,finishedUnit)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.FactoryFinishBuilding(self,factory,finishedUnit)
        end
        --RNGLOG('RNG FactorFinishedbuilding')
        if EntityCategoryContains(categories.ENGINEER, finishedUnit) then
            self.Brain.BuilderManagers[self.LocationType].EngineerManager:AddUnitRNG(finishedUnit)
        elseif EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit ) then
            --RNGLOG('Factory Built by factory, attempting to kill factory.')
			if finishedUnit:GetFractionComplete() == 1 then
				self:AddFactory(finishedUnit )			
				factory.Dead = true
                factory.Trash:Destroy()
                --RNGLOG('Destroy Factory')
				return self:FactoryDestroyed(factory)
			end
        elseif self.Brain.TransportPool and EntityCategoryContains(categories.TRANSPORTFOCUS - categories.uea0203, finishedUnit ) then
            self.Brain.TransportRequested = nil
            finishedUnit:ForkThread( import('/lua/ai/transportutilities.lua').AssignTransportToPool, finishedUnit:GetAIBrain() )
		elseif finishedUnit.Blueprint.CategoriesHash.AIR then
            local unitStats = self.Brain.IntelManager.UnitStats
            local unitValue = finishedUnit.Blueprint.Economy.BuildCostMass or 0
            if unitStats then
                if finishedUnit.Blueprint.CategoriesHash.GROUNDATTACK and not finishedUnit.Blueprint.CategoriesHash.EXPERIMENTAL then
                    unitStats['Gunship'].Built.Mass = unitStats['Gunship'].Built.Mass + unitValue
                elseif finishedUnit.Blueprint.CategoriesHash.BOMBER and not finishedUnit.Blueprint.CategoriesHash.EXPERIMENTAL and not finishedUnit.Blueprint.CategoriesHash.BOMB then
                    unitStats['Bomber'].Built.Mass = unitStats['Bomber'].Built.Mass + unitValue
                end
            end
        end
        self:AssignBuildOrder(factory, factory.BuilderManagerData.BuilderType)
    end,

    FactoryDestroyed = function(self, factory)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.FactoryDestroyed(self, factory)
        end
        local factoryDestroyed = false
        for k,v in self.FactoryList do
            if (not v.EntityId) or v.Dead then
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
        if self.LocationType == 'MAIN' then
            return
        end
        self.LocationActive = false
        --self.Brain:RemoveConsumption(self.LocationType, factory)
    end,

    GenerateInitialBuildQueue = function(self, templateName, factory)
        --RNGLOG('Generating Intial Queue for build')
        local faction = self:GetFactoryFaction(factory)
        --RNGLOG('Faction is '..faction)
        local backupqueue = {
            'T1BuildEngineer',
            'T1LandScout',
            'T1LandDFTank',
            'T1LandArtillery',
            'T1LandAA',
        }
        local queue = self:GenerateInitialBO(factory)
        if not queue then
            queue = backupqueue
        end
        local template = {
            'InitialBuildQueueRNG',
            '',
        }
        for k, v in queue do
            local templateData = PlatoonTemplates[v]
            local customData = self.Brain.CustomUnits[v]
            for c, b in templateData.FactionSquads[faction] do
                if customData and customData[faction] then
                    -- LOG('*AI DEBUG: Replacement unit found!')
                    local replacement = self:GetCustomReplacement(b, v, faction)
                    if replacement then
                        table.insert(template, replacement)
                    else
                        table.insert(template, b)
                    end
                else
                    table.insert(template, b)
                end
            end
        end
        --RNGLOG('Generated Template is '..repr(template))
        return template
    end,

    GenerateInitialBO = function(self, factory)
        local faction = self:GetFactoryFaction(factory)
        local queue = {
            'T1BuildEngineer',
            'T1BuildEngineer',
        }
        if faction then
            local EnemyIndex
            local mapSizeX, mapSizeZ = GetMapSize()
            local OwnIndex = self.Brain:GetArmyIndex()
            local EnemyArmy = self.Brain:GetCurrentEnemy()
            if EnemyArmy then
                EnemyIndex = EnemyArmy:GetArmyIndex()
            end
            if mapSizeX >= 4000 and mapSizeZ >= 4000 then
                --RNGLOG('20 KM Map Check true')
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    end
                    if self.Brain.BrainIntel.RestrictedMassMarker > 6 then
                        for i=1, 4 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    else
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                else
                    for i=1, 6 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandDFTank')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandAA')
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
                table.insert(queue, 'T1LandScout')
                table.insert(queue, 'T1LandScout')
            elseif mapSizeX >= 2000 and mapSizeZ >= 2000 then
                --RNGLOG('20 KM Map Check true')
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    end
                    if self.Brain.BrainIntel.RestrictedMassMarker > 6 then
                        for i=1, 4 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    else
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                else
                    for i=1, 6 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandDFTank')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandAA')
                    table.insert(queue, 'T1LandAA')
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
                table.insert(queue, 'T1LandScout')
                table.insert(queue, 'T1LandScout')
            elseif mapSizeX >= 1000 and mapSizeZ >= 1000 then
                --RNGLOG('20 KM Map Check true')
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 2 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                    end
                    if self.Brain.BrainIntel.RestrictedMassMarker > 6 then
                        for i=1, 4 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    else
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                else
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandDFTank')
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandAA')
                    for i=1, 4 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
                table.insert(queue, 'T1LandScout')
                table.insert(queue, 'T1LandScout')
            elseif mapSizeX >= 500 and mapSizeZ >= 500 then
                LOG('10 KM Map Check true')
                LOG('Restricted Mass Markers '..tostring(self.Brain.BrainIntel.RestrictedMassMarker))
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 1 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    if self.Brain.BrainIntel.RestrictedMassMarker > 6 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    LOG('Start Reclaim Current '..tostring(self.Brain.StartReclaimCurrent))
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    else
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.BrainIntel.RestrictedMassMarker > 8 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                    table.insert(queue, 'T1LandScout')
                else
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.BrainIntel.RestrictedMassMarker > 8 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    end
                    table.insert(queue, 'T1LandAA')
                end
                table.insert(queue, 'T1LandScout')
                table.insert(queue, 'T1LandScout')
            elseif mapSizeX >= 200 and mapSizeZ >= 200 then
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 1 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    else
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                    end
                    for i=1, 2 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1LandArtillery')
                    table.insert(queue, 'T1LandAA')
                    table.insert(queue, 'T1LandScout')
                else
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                    if self.Brain.EnemyIntel.CivilianClosestPD > 0 and self.Brain.EnemyIntel.ClosestEnemyBase > 0 then
                        if self.Brain.EnemyIntel.CivilianClosestPD < 62500 and self.Brain.EnemyIntel.CivilianClosestPD < self.Brain.EnemyIntel.ClosestEnemyBase then
                            for i=1, 2 do
                                table.insert(queue, 'T1LandArtillery')
                            end
                        end
                    end
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1LandAA')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1LandAA')
                end
                table.insert(queue, 'T1LandScout')
                table.insert(queue, 'T1LandScout')
            else
                queue = {
                    'T1BuildEngineer',
                    'T1BuildEngineer',
                    'T1BuildEngineer',
                    'T1LandDFTank',
                    'T1LandScout',
                    'T1LandDFTank',
                    'T1LandDFTank',
                    'T1LandScout',
                    'T1LandDFTank',
                    'T1BuildEngineer',
                    'T1BuildEngineer',
                    'T1LandDFTank',
                    'T1LandDFTank',
                    'T1LandDFTank',
                    'T1LandArtillery',
                    'T1LandAA',
                    'T1LandScout',
                    'T1LandScout',
                    'T1LandScout',
                }
            end
            return queue
        end
        return false
    end,

    GetFactoryTemplate = function(self, templateName, factory)
        if not self.Brain.RNG then
            return RNGFactoryBuilderManager.GetFactoryTemplate(self, templateName, factory)
        end
        local template
        if templateName == 'InitialBuildQueueRNG' then
            template = self:GenerateInitialBuildQueue(templateName, factory)

        else
            local templateData = PlatoonTemplates[templateName]
            if not templateData then
                SPEW('*AI WARNING: No templateData found for template '..templateName..'. ')
                return false
            end
            if not templateData.FactionSquads then
                SPEW('*AI ERROR: PlatoonTemplate named: ' .. templateName .. ' does not have a FactionSquads')
                return false
            end
            template = {
                templateData.Name,
                '',
            }

            local faction = self:GetFactoryFaction(factory)
            local customData = self.Brain.CustomUnits[templateName]
            if faction and templateData.FactionSquads[faction] then
                for k,v in templateData.FactionSquads[faction] do
                    if customData and customData[faction] then
                        -- LOG('*AI DEBUG: Replacement unit found!')
                        local replacement = self:GetCustomReplacement(v, templateName, faction)
                        if replacement then
                            table.insert(template, replacement)
                        else
                            table.insert(template, v)
                        end
                    else
                        table.insert(template, v)
                    end
                end
            elseif faction and customData and customData[faction] then
                --LOG('*AI DEBUG: New unit found for '..templateName..'!')
                local Squad = nil
                if templateData.FactionSquads then
                    -- get the first squad from the template
                    for k,v in templateData.FactionSquads do
                        -- use this squad as base template for the replacement
                        Squad = table.copy(v[1])
                        -- flag this template as dummy
                        Squad[1] = "NoOriginalUnit"
                        break
                    end
                end
                -- if we don't have a template use a dummy.
                if not Squad then
                    -- this will only happen if we have a empty template. Warn the programmer!
                    SPEW('*AI WARNING: No faction squad found for '..templateName..'. using Dummy! '..tostring(templateData.FactionSquads) )
                    Squad = { "NoOriginalUnit", 1, 1, "attack", "none" }
                end
                local replacement = self:GetCustomReplacement(Squad, templateName, faction)
                if replacement then
                    table.insert(template, replacement)
                end
            end
        end
        return template
    end,

}

