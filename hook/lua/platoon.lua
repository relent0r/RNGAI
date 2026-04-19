WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset platoon.lua' )

local NavUtils = import('/lua/sim/NavUtils.lua')
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local AIUtils = import('/lua/ai/aiutilities.lua')
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local GetPlatoonUnits = moho.platoon_methods.GetPlatoonUnits
local GetPlatoonPosition = moho.platoon_methods.GetPlatoonPosition
local GetPosition = moho.entity_methods.GetPosition
local PlatoonExists = moho.aibrain_methods.PlatoonExists
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local RNGGETN = table.getn
local RNGINSERT = table.insert
local RNGCOPY = table.copy
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local RNGTableEmpty = table.empty

RNGAIPlatoonClass = Platoon
Platoon = Class(RNGAIPlatoonClass) {
    
    DummyPlatoonAIRNG = function(self)
        coroutine.yield(10)
    end,
    
    RepairAIRNG = function(self)
        local aiBrain = self:GetBrain()
        if not self.PlatoonData or not self.PlatoonData.LocationType then
            self:PlatoonDisband()
            return
        end
        local eng = self:GetPlatoonUnits()[1]
        local repairingUnit = false
        local engineerManager = aiBrain.BuilderManagers[self.PlatoonData.LocationType].EngineerManager
        if not engineerManager then
            self:PlatoonDisband()
            return
        end
        local Structures = AIUtils.GetOwnUnitsAroundPoint(aiBrain, categories.STRUCTURE - (categories.TECH1 - categories.FACTORY), engineerManager:GetLocationCoords(), engineerManager:GetLocationRadius())
        for k,v in Structures do
            -- prevent repairing a unit while reclaim is in progress (see ReclaimStructuresAI)
            if not v.Dead and not v.ReclaimInProgress and v:GetHealthPercent() < .8 then
                self:Stop()
                IssueRepair(self:GetPlatoonUnits(), v)
                repairingUnit = v
                break
            end
        end
        local count = 0
        repeat
            coroutine.yield(20)
            if not aiBrain:PlatoonExists(self) then
                return
            end
            if repairingUnit.ReclaimInProgress then
                self:Stop()
                self:PlatoonDisband()
            end
            count = count + 1
            if eng:IsIdleState() then break end
        until count >= 30
        self:PlatoonDisband()
    end,

    ReclaimUnitsAIRNG = function(self)
        self:Stop()
        local aiBrain = self:GetBrain()
        local index = aiBrain:GetArmyIndex()
        local data = self.PlatoonData
        local pos = GetPlatoonPosition(self)
        local radius = data.Radius or 500
        local positionUnits = {}
        if not data.Categories then
            error('PLATOON.LUA ERROR- ReclaimUnitsAI requires Categories field',2)
        end

        local checkThreat = false
        if data.ThreatMin and data.ThreatMax and data.ThreatRings then
            checkThreat = true
        end
        while PlatoonExists(aiBrain, self) do
            coroutine.yield(1)
            local target = AIAttackUtils.AIFindUnitRadiusThreatRNG(aiBrain, 'Enemy', data.Categories, pos, radius, data.ThreatMin, data.ThreatMax, data.ThreatRings)
            if target and not target.Dead then
                local targetPos = target:GetPosition()
                local blip = target:GetBlip(index)
                local platoonUnits = self:GetPlatoonUnits()
                if blip then
                    IssueClearCommands(platoonUnits)
                    positionUnits = GetUnitsAroundPoint(aiBrain, data.Categories[1], targetPos, 10, 'Enemy')
                    --RNGLOG('Number of units found by reclaim ai is '..RNGGETN(positionUnits))
                    if RNGGETN(positionUnits) > 1 then
                        --RNGLOG('Reclaim Units AI got more than one at target position')
                        for k, v in positionUnits do
                            IssueReclaim(platoonUnits, v)
                        end
                    else
                        --RNGLOG('Reclaim Units AI got a single target at position')
                        IssueReclaim(platoonUnits, target)
                    end
                    -- Set ReclaimInProgress to prevent repairing (see RepairAI)
                    target.ReclaimInProgress = true
                    local allIdle
                    repeat
                        coroutine.yield(30)
                        if not PlatoonExists(aiBrain, self) then
                            return
                        end
                        if target and not target.ReclaimInProgress then
                            target.ReclaimInProgress = true
                        end
                        allIdle = true
                        for k,v in self:GetPlatoonUnits() do
                            if not v.Dead and not v:IsIdleState() then
                                allIdle = false
                                break
                            end
                        end
                    until allIdle or blip:BeenDestroyed() or blip:IsKnownFake(index) or blip:IsMaybeDead(index)
                else
                    coroutine.yield(20)
                end
            else
                local location = AIUtils.RandomLocation(aiBrain:GetArmyStartPos())
                self:MoveToLocation(location, false)
                coroutine.yield(40)
                self:PlatoonDisband()
            end
            coroutine.yield(30)
        end
    end,

    ReturnToBaseAIRNG = function(self, mainBase)

        local aiBrain = self:GetBrain()

        if not PlatoonExists(aiBrain, self) or not GetPlatoonPosition(self) then
            return
        end

        local bestBase = false
        local bestBaseName = ""
        local bestDistSq = 999999999
        local platPos = GetPlatoonPosition(self)
        if not self.MovementLayer then
            AIAttackUtils.GetMostRestrictiveLayerRNG(self)
        end

        if not mainBase then
            for baseName, base in aiBrain.BuilderManagers do
                if self.MovementLayer == 'Water' then
                    if base.Layer ~= 'Water' then
                        continue
                    end
                end
                local distSq = VDist2Sq(platPos[1], platPos[3], base.Position[1], base.Position[3])
                if distSq < bestDistSq then
                    bestBase = base
                    bestBaseName = baseName
                    bestDistSq = distSq
                end

            end
        else
            bestBase = aiBrain.BuilderManagers['MAIN']
        end
        
        if bestBase then
            local movePosition
            local usedTransports
            if bestBase.FactoryManager and bestBase.FactoryManager.RallyPoint then
                movePosition = bestBase.FactoryManager.RallyPoint
            else
                movePosition = bestBase.Position
            end
            if self.MovementLayer == 'Air' then
                IssueClearCommands(GetPlatoonUnits(self))
                self:MoveToLocation(movePosition, false)
                --RNGLOG('Air Unit Return to base provided position :'..repr(bestBase.Position))
                while PlatoonExists(aiBrain, self) do
                    coroutine.yield(1)
                    platPos = self:GetPlatoonPosition()
                    --RNGLOG('Air Unit Distance from platoon to bestBase position for Air units is'..VDist2Sq(platPos[1], platPos[3], bestBase.Position[1], bestBase.Position[3]))
                    --RNGLOG('Air Unit Platoon Position is :'..repr(platPos))
                    local distSq = VDist2Sq(platPos[1], platPos[3], movePosition[1], movePosition[3])
                    if distSq < 3600 then
                        break
                    end
                    coroutine.yield(15)
                end
            else
                -- A small note on the unitPathing flag. There are situations where a platoon will have return to base triggered and the platoon itself
                -- will be spread out, in this scenario the platoon position could be in an unpathable area and a transport is not available.
                -- This will result in the platoon disbanding in the middle of no where. So we double check if one of the units can path before we
                -- go down that route.
                local path, reason
                local unitPathing = false
                if not NavUtils.CanPathTo(self.MovementLayer, GetPlatoonPosition(self), movePosition) then
                    if not NavUtils.CanPathTo(self.MovementLayer, GetPlatoonUnits(self)[1]:GetPosition(), movePosition) then
                        usedTransports = StateUtils.RequestTransportRNG(self, movePosition)
                    else 
                        unitPathing = true
                    end
                end
                if not usedTransports then
                    if unitPathing then
                        path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonUnits(self)[1]:GetPosition(), movePosition, 500, 30)
                    else
                        path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, GetPlatoonPosition(self), movePosition, 500, 30)
                    end
                    IssueClearCommands(self)
                    if path then
                        local pathLength = RNGGETN(path)
                        for i=1, pathLength do
                            self:MoveToLocation(path[i], false)
                            local Lastdist
                            local dist
                            local Stuck = 0
                            while PlatoonExists(aiBrain, self) do
                                coroutine.yield(1)
                                platPos = GetPlatoonPosition(self)
                                local dist = VDist3Sq(platPos, path[i])
                                if dist < 400 then
                                    --RNGLOG('returntobase platoon closer than 400 '..dist)
                                    IssueClearCommands(GetPlatoonUnits(self))
                                    break
                                end
                                if Lastdist ~= dist then
                                    Stuck = 0
                                    Lastdist = dist
                                else
                                    Stuck = Stuck + 1
                                    if Stuck > 15 then
                                        self:Stop()
                                        break
                                    end
                                end
                                Lastdist = dist
                                coroutine.yield(20)
                            end
                        end
                    end
                end
                if VDist3Sq(platPos, movePosition) > 400 then
                    self:MoveToLocation(movePosition, false)
                    coroutine.yield(80)
                end
            end
        end
        coroutine.yield(20)
        self:PlatoonDisband()
    end,

    BaseManagersDistressAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local defenseUnits = categories.MOBILE - categories.NAVAL - categories.ENGINEER - categories.TRANSPORTFOCUS - categories.SONAR - categories.EXPERIMENTAL - categories.daa0206 - categories.xrl0302
        while PlatoonExists(aiBrain, self) do
            coroutine.yield(1)
            local distressRange = aiBrain.BaseMonitor.PoolDistressRange
            local reactionTime = aiBrain.BaseMonitor.PoolReactionTime

            local platoonUnits = GetPlatoonUnits(self)

            for locName, locData in aiBrain.BuilderManagers do
                if not locData.DistressCall then
                    local position = locData.EngineerManager.Location
                    if position then
                        local radius = locData.EngineerManager.Radius
                        local distressRange = locData.BaseSettings.DistressRange or aiBrain.BaseMonitor.PoolDistressRange
                        local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold, 'Land')

                        -- Distress !
                        if distressLocation then
                            --RNGLOG('*AI DEBUG: ARMY '.. aiBrain:GetArmyIndex() ..': --- POOL DISTRESS RESPONSE ---')

                            -- Grab the units at the location
                            local group = self:GetPlatoonUnitsAroundPoint(defenseUnits , position, radius)

                            -- Move the group to the distress location and then back to the location of the base
                            IssueClearCommands(group)
                            IssueAggressiveMove(group, distressLocation)
                            IssueMove(group, position)

                            -- Set distress active for duration
                            locData.DistressCall = true
                            self:ForkThread(self.UnlockBaseManagerDistressLocation, locData)
                        end
                    end
                end
            end
            WaitSeconds(aiBrain.BaseMonitor.PoolReactionTime)
        end
    end,

    SetAIPlanRNG = function(self, plan, currentPlan, planData)
        if not self[plan] then return end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        self.PlanName = plan
        self.OldPlan = currentPlan
        self.planData = planData
        self.BuilderName = plan
        self:ForkAIThread(self[plan])
    end,
    -- For Debugging

    PlatoonDisband = function(self)
        local aiBrain = self:GetBrain()
        if not aiBrain.RNG then
            return RNGAIPlatoonClass.PlatoonDisband(self)
        end
        if self.ArmyPool then
            WARN('AI WARNING: Platoon trying to disband ArmyPool')
            --LOG(reprsl(debug.traceback()))
            return
        end
        if self.BuilderHandle then
            self.BuilderHandle:RemoveHandle(self)
        end
        for k,v in self:GetPlatoonUnits() do
            v.PlatoonHandle = nil
            v.AssistSet = nil
            v.AssistPlatoon = nil
            v.UnitBeingAssist = nil
            v.ReclaimInProgress = nil
            v.CaptureInProgress = nil
            v.JobType = nil
            if not v.Dead and v:IsPaused() then
                v:SetPaused( false )
            end
            if not v.Dead and v.BuilderManagerData then
                if self.CreationTime == GetGameTimeSeconds() and v.BuilderManagerData.EngineerManager then
                    if self.BuilderName then
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - ' .. self.BuilderName .. ' - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                        v.BuilderManagerData.EngineerManager:AssignTimeout(v, self.BuilderName)
                    else
                        --LOG('*PlatoonDisband: ERROR - Platoon disbanded same tick as created - Army: ' .. aiBrain:GetArmyIndex() .. ' - Location: ' .. repr(v.BuilderManagerData.LocationType))
                    end
                    v.BuilderManagerData.EngineerManager:DelayAssign(v)
                elseif v.BuilderManagerData.EngineerManager then
                    v.BuilderManagerData.EngineerManager:TaskFinished(v)
                end
            end
            if not v.Dead then
                if not EntityCategoryContains(categories.FACTORY, v) then
                    IssueStop({v})
                    IssueClearCommands({v})
                end
            end
        end
        if self.AIThread then
            self.AIThread:Destroy()
        end
        aiBrain:DisbandPlatoon(self)
    end,

    PlatoonMergeRNG = function(self)
        --RNGLOG('Platoon Merge Started')
        local aiBrain = self:GetBrain()
        local destinationPlan = self.PlatoonData.PlatoonPlan
        local location = self.PlatoonData.LocationType
        --RNGLOG('Location Type is '..location)
        --RNGLOG('at position '..repr(aiBrain.BuilderManagers[location].Position))
        --RNGLOG('Destiantion Plan is '..destinationPlan)
        if not destinationPlan then
            return
        end
        local mergedPlatoon
        local units = GetPlatoonUnits(self)
        --RNGLOG('Number of units are '..RNGGETN(units))
        local platoonList = aiBrain:GetPlatoonsList()
        for k, platoon in platoonList do
            if platoon.PlanName == destinationPlan and platoon.Location == location then
                --RNGLOG('Setting mergedPlatoon to platoon')
                mergedPlatoon = platoon
                break
            end
        end
        if not mergedPlatoon then
            --RNGLOG('Platoon Merge is creating platoon for '..destinationPlan..' at location '..location..' location position '..repr(aiBrain.BuilderManagers[location].Position))
            mergedPlatoon = aiBrain:MakePlatoon(destinationPlan..'Platoon'..location, destinationPlan)
            mergedPlatoon.PlanName = destinationPlan
            mergedPlatoon.BuilderName = destinationPlan..'Platoon'..location
            mergedPlatoon.Location = location
            mergedPlatoon.CenterPosition = aiBrain.BuilderManagers[location].Position
        end
        --RNGLOG('Platoon Merge is assigning units to platoon')
        aiBrain:AssignUnitsToPlatoon(mergedPlatoon, units, 'attack', 'none')
        self:PlatoonDisbandNoAssign()
    end,

    TransferAIRNG = function(self)
        local aiBrain = self:GetBrain()
        local moveToLocation = false
        if self.PlatoonData.MoveToLocationType == 'ActiveExpansion' then
            moveToLocation = aiBrain.BrainIntel.ActiveExpansion
        else
            moveToLocation = self.PlatoonData.MoveToLocationType
        end
        --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..')')
        coroutine.yield(5)
        if not aiBrain.BuilderManagers[moveToLocation] then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Location ('..moveToLocation..') has no BuilderManager!')
            self:PlatoonDisband()
            return
        end
        local eng = GetPlatoonUnits(self)[1]
        if eng and not eng.Dead and eng.BuilderManagerData.EngineerManager then
            --RNGLOG('* AI-RNG: * TransferAIRNG: Moving transfer-units to - ' .. moveToLocation)
            
            if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, aiBrain.BuilderManagers[moveToLocation].Position) then
                --RNGLOG('* AI-RNG: * TransferAIRNG: '..repr(self.BuilderName))
                eng.BuilderManagerData.EngineerManager:RemoveUnit(eng)
                --RNGLOG('* AI-RNG: * TransferAIRNG: AddUnit units to - BuilderManagers: '..moveToLocation..' - ' .. aiBrain.BuilderManagers[moveToLocation].EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) )
                aiBrain.BuilderManagers[moveToLocation].EngineerManager:AddUnit(eng, true)
                -- Move the unit to the desired base after transfering BuilderManagers to the new LocationType
            end
        end
        if PlatoonExists(aiBrain, self) then
            self:PlatoonDisband()
        end
    end,

    StateMachineAIRNG = function(self)
        local machineType = self.PlatoonData.StateMachine

        if machineType == 'ACU' then
            --LOG('Starting ACU State')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'AirFeeder' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-feeder.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandFeeder' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-feeder.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandCombat' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandAssault' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-assault.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandScout' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-scout.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'AirScout' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-scout.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'Gunship' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-gunship.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'Bomber' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-bomber.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'ZoneControl' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol.lua").AssignToUnitsMachine({ZoneType = self.PlatoonData.ZoneType, PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'ZoneControlDefense' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-zonecontrol-defense.lua").AssignToUnitsMachine({ZoneType = self.PlatoonData.ZoneType, PlatoonData = self.PlatoonData}, self, self:GetPlatoonUnits())
        elseif machineType == 'MobileBomb' then
            import("/mods/rngai/lua/ai/statemachines/platoon-land-bomb.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'Fighter' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-fighter.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'FatBoy' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-fatboy.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'NavalExperimental' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-naval-combat.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'NavalZoneControl' then
            import("/mods/rngai/lua/ai/statemachines/platoon-naval-zonecontrol.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'NavalCombat' then
            import("/mods/rngai/lua/ai/statemachines/platoon-naval-combat.lua").AssignToUnitsMachine({PlatoonData = self.PlatoonData  }, self, self:GetPlatoonUnits())
        elseif machineType == 'LandExperimental' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-land-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'AirExperimental' then
            import("/mods/rngai/lua/ai/statemachines/platoon-experimental-air-combat.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'TorpedoBomber' then
            import("/mods/rngai/lua/ai/statemachines/platoon-air-torpedo.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'StaticArtillery' then
            --LOG('Static Artillery has been selected')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-artillery.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'MexBuild' then
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-resource.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'ReclaimEngineer' then
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-reclaim.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'AssistManagerEngineer' then
            local aiBrain = self:GetBrain()
            local platoonName = 'AssistManagerStateMachine_'..self.PlatoonData.LocationType
            local assistManagerPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not assistManagerPlatoonAvailable then
                assistManagerPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                assistManagerPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(assistManagerPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-assist-manager.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, assistManagerPlatoonAvailable, platoonUnits)
        elseif machineType == 'ACUSupport' then
            local aiBrain = self:GetBrain()
            local platoonName = 'ACUSupportPlatoon'
            local acuSupportPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not acuSupportPlatoonAvailable then
                acuSupportPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                acuSupportPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(acuSupportPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-acu-support.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, acuSupportPlatoonAvailable, platoonUnits)
        elseif machineType == 'StrategicArtillery' then
            local aiBrain = self:GetBrain()
            local platoonName = 'ArtilleryStateMachine_'..self.PlatoonData.LocationType
            local artilleryPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not artilleryPlatoonAvailable then
                artilleryPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                artilleryPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(artilleryPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-artillery.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, artilleryPlatoonAvailable, platoonUnits)
        elseif machineType == 'Novax' then
            local aiBrain = self:GetBrain()
            local platoonName = 'NovaxStateMachine'
            local novaxPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not novaxPlatoonAvailable then
                novaxPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                novaxPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(novaxPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-novax.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, novaxPlatoonAvailable, platoonUnits)
        elseif machineType == 'Nuke' then
            local aiBrain = self:GetBrain()
            local platoonName = 'NukeStateMachine'
            local nukePlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not nukePlatoonAvailable then
                nukePlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                nukePlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(nukePlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-nuke.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, nukePlatoonAvailable, platoonUnits)
        elseif machineType == 'PreAllocatedTask' or machineType == 'EngineerBuilder' then
            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())
        elseif machineType == 'TML' then
            local aiBrain = self:GetBrain()
            local platoonName = 'TMLStateMachine_'..self.PlatoonData.LocationType
            local tmlPlatoonAvailable = aiBrain:GetPlatoonUniquelyNamed(platoonName)
            if not tmlPlatoonAvailable then
                tmlPlatoonAvailable = aiBrain:MakePlatoon(platoonName, '')
                tmlPlatoonAvailable:UniquelyNamePlatoon(platoonName)
            end
            local platoonUnits = self:GetPlatoonUnits()
            aiBrain:AssignUnitsToPlatoon(tmlPlatoonAvailable, platoonUnits, 'attack', 'None')
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-tml.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, tmlPlatoonAvailable, platoonUnits)
        elseif machineType == 'Optics' then
            import("/mods/rngai/lua/ai/statemachines/platoon-structure-optics.lua").AssignToUnitsMachine({ PlatoonData = self.PlatoonData }, self, self:GetPlatoonUnits())

        end
        WaitTicks(50)
    end,

}