local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')

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
            --LOG('No Rally Point Found. Setting Point between me and enemy Location')
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
                            --LOG('Start Locations :Opponent'..repr(opponentStart)..' Myself :'..repr(factoryPos))
                            local startDistance = VDist2(opponentStart[1], opponentStart[3], factoryPos[1], factoryPos[3])
                            if EntityCategoryContains(categories.AIR, factory) then
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 60})
                                --LOG('Air Rally Position is :'..repr(position))
                                break
                            else
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 30})
                                --LOG('Rally Position is :'..repr(position))
                                break
                            end
                        end
                    end
                end
            else
                --LOG('No Rally Point Found. Setting Random Location')
                position = AIUtils.RandomLocation(position[1],position[3])
            end
            rally = position
        end

        IssueClearFactoryCommands({factory})
        IssueFactoryRallyPoint({factory}, rally)
        self.RallyPoint = rally
        return true
    end,

}

