--****************************************************************************
--**  File     :  /lua/sim/EngineerManager.lua
--**  Summary  : Manage engineers for a location
--**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************

local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local BuilderManager = import("/mods/RNGAI/lua/AI/BuilderFramework/buildermanager.lua").BuilderManager
local Builder = import("/mods/RNGAI/lua/AI/BuilderFramework/builder.lua")
local SUtils = import("/lua/ai/sorianutilities.lua")
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local NavUtils = import('/lua/sim/NavUtils.lua')

local TableGetn = table.getn
local WeakValueTable = { __mode = 'v' }

---@class EngineerManager : BuilderManager
---@field Location Vector
---@field Radius number
EngineerManager = Class(BuilderManager) {
        ---@param self EngineerManager
    ---@param brain AIBrain
    ---@param lType LocationType
    ---@param location Vector
    ---@param radius number
    ---@return boolean
    Create = function(self, brain, lType, location, radius)
        BuilderManager.Create(self,brain, lType, location, radius)

        if not lType or not location or not radius then
            error('*PLATOOM FORM MANAGER ERROR: Invalid parameters; requires locationType, location, and radius')
            return false
        end

        -- backwards compatibility for mods
        self.Location = self.Location or location
        self.Radius = self.Radius or radius
        self.LocationType = self.LocationType or lType

        self.ConsumptionUnits = {
            Engineers = { Category = categories.ENGINEER - categories.ENGINEERSTATION, Units = {}, UnitsList = {}, Count = 0, },
            EngineerStations = { Category = categories.ENGINEERSTATION, Units = {}, UnitsList = {}, Count = 0, },
            Fabricators = { Category = categories.MASSFABRICATION * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            EnergyProduction = { Category = categories.ENERGYPRODUCTION * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            Shields = { Category = categories.SHIELD * categories.STRUCTURE, Units = {}, UnitsList = {}, Count = 0, },
            MobileShields = { Category = categories.SHIELD * categories.MOBILE, Units = {}, UnitsList = {}, Count = 0, },
            Intel = { Category = categories.STRUCTURE * (categories.SONAR + categories.RADAR + categories.OMNI), Units = {}, UnitsList = {}, Count = 0, },
            MobileIntel = { Category = categories.MOBILE - categories.ENGINEER - categories.SHIELD, Units = {}, UnitsList = {}, Count = 0, },
            AntiNuke = { Category = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, Units = {}, UnitsList = {}, Count = 0, },
            Strategic = { Category = categories.STRUCTURE * categories.STRATEGIC * categories.TECH3, Units = {}, UnitsList = {}, Count = 0, },
            Experimental = { Category = categories.STRUCTURE * categories.EXPERIMENTAL, Units = {}, UnitsList = {}, Count = 0, },
        }
        self.QueuedStructures = {}
        self.QueuedStructures = {
            TECH1 = {},
            TECH2 = {},
            TECH3 = {},
            EXPERIMENTAL = {},
            SUBCOMMANDER = {},
            COMMAND = {},
            DEFENSE = {},
        }
        self.StructuresBeingBuilt = {}
        self.StructuresBeingBuilt = {
            TECH1 = {},
            TECH2 = {},
            TECH3 = {},
            EXPERIMENTAL = {},
            SUBCOMMANDER = {},
            COMMAND = {},
            DEFENSE = {},
        }
        self:AddBuilderType('Any')
    end,

    -- Builder based functions
    ---@param self EngineerManager
    ---@param builderData table
    ---@param locationType string
    ---@param builderType string
    ---@return any
    AddBuilder = function(self, builderData, locationType, builderType)
        local newBuilder = Builder.CreateEngineerBuilder(self.Brain, builderData, locationType)
        self:AddInstancedBuilder(newBuilder, builderType)
        return newBuilder
    end,

    ---@param self EngineerManager
    ---@param unitType string
    ---@return number
    GetNumUnits = function(self, unitType)
        if self.ConsumptionUnits[unitType] then
            return self.ConsumptionUnits[unitType].Count
        end
        return 0
    end,

    ---@param self EngineerManager
    ---@param unitType string
    ---@param category EntityCategory
    ---@return number
    GetNumCategoryUnits = function(self, unitType, category)
        if self.ConsumptionUnits[unitType] then
            return EntityCategoryCount(category, self.ConsumptionUnits[unitType].UnitsList)
        end
        return 0
    end,

    GetEngineerStateMachineCount = function(self, unitType, stateMachine)
        local stateMachineCount = 0
        if self.ConsumptionUnits[unitType] then
            for _, e in self.ConsumptionUnits[unitType].UnitsList do
                local stateMachineType = e.PlatoonHandle.PlatoonData.StateMachine
                if stateMachineType and stateMachineType == stateMachine then
                    stateMachineCount = stateMachineCount + 1
                end
            end
        end
        return stateMachineCount
    end,

    ---@param self EngineerManager
    ---@param category EntityCategory
    ---@param engCategory EntityCategory
    ---@return integer
    GetNumCategoryBeingBuilt = function(self, category, engCategory)
        return TableGetn(self:GetEngineersBuildingCategory(category, engCategory))
    end,

    ---@param self EngineerManager
    ---@param category EntityCategory
    ---@param engCategory EntityCategory
    ---@return table
    GetEngineersBuildingCategory = function(self, category, engCategory)
        local engs = self:GetUnits('Engineers', engCategory)
        local units = {}
        for k,v in engs do
            if v.Dead then
                continue
            end

            if not v:IsUnitState('Building') then
                continue
            end

            local beingBuiltUnit = v.UnitBeingBuilt
            if not beingBuiltUnit or beingBuiltUnit.Dead then
                continue
            end

            if not EntityCategoryContains(category, beingBuiltUnit) then
                continue
            end

            table.insert(units, v)
        end
        return units
    end,

    ---@param self EngineerManager
    ---@param engineer Unit
    ---@return integer
    GetEngineerFactionIndex = function(self, engineer)
        if EntityCategoryContains(categories.UEF, engineer) then
            return 1
        elseif EntityCategoryContains(categories.AEON, engineer) then
            return 2
        elseif EntityCategoryContains(categories.CYBRAN, engineer) then
            return 3
        elseif EntityCategoryContains(categories.SERAPHIM, engineer) then
            return 4
        else
            return 5
        end
    end,

    ---@param self EngineerManager
    ---@param engineer Unit
    ---@return any
    UnitFromCustomFaction = function(self, engineer)
        local customFactions = self.Brain.CustomFactions
        for k,v in customFactions do
            if EntityCategoryContains(v.customCat, engineer) then
                --LOG('*AI DEBUG: UnitFromCustomFaction: '..k)
                return k
            end
        end
    end,

    ---@param self EngineerManager
    ---@param engineer Unit
    ---@param buildingType string
    ---@return any
    GetBuildingId = function(self, engineer, buildingType)
        local faction = self:GetEngineerFactionIndex(engineer)
        if faction > 4 then
            if self:UnitFromCustomFaction(engineer) then
                faction = self:UnitFromCustomFaction(engineer)
                --LOG('*AI DEBUG: GetBuildingId faction: '..faction)
                return self.Brain:DecideWhatToBuild(engineer, buildingType, self.Brain.CustomFactions[faction])
            end
        else
            return self.Brain:DecideWhatToBuild(engineer, buildingType, import("/lua/buildingtemplates.lua").BuildingTemplates[faction])
        end
    end,

    ---@param self EngineerManager
    ---@param buildingType string
    ---@return table
    GetEngineersQueued = function(self, buildingType)
        local engs = self:GetUnits('Engineers', categories.ALLUNITS)
        local units = {}
        for k,v in engs do
            if v.Dead then
                continue
            end

            if not v.EngineerBuildQueue or table.empty(v.EngineerBuildQueue) then
                continue
            end

            local buildingId = self:GetBuildingId(v, buildingType)
            local found = false
            for num, data in v.EngineerBuildQueue do
                if data[1] == buildingId then
                    found = true
                    break
                end
            end

            if not found then
                continue
            end

            table.insert(units, v)
        end
        return units
    end,

    ---@param self EngineerManager
    ---@param buildingType string
    ---@return table
    GetEngineersBuildQueue = function(self, buildingType)
        local engs = self:GetUnits('Engineers', categories.ALLUNITS)
        local units = {}
        for k,v in engs do
            if v.Dead then
                continue
            end

            if not v.EngineerBuildQueue or table.empty(v.EngineerBuildQueue) then
                continue
            end
            local buildName = v.EngineerBuildQueue[1][1]
            local buildBp = self.Brain:GetUnitBlueprint(buildName)
            local buildingTypes = SUtils.split(buildingType, ' ')
            local found = false
            local count = 0
            for x,z in buildingTypes do
                if buildBp.CategoriesHash[z] then
                    count = count + 1
                end
                if TableGetn(buildingTypes) == count then found = true end
                if found then break end
            end

            if not found then
                continue
            end

            table.insert(units, v)
        end
        return units
    end,

    ---@param self EngineerManager
    ---@param category EntityCategory
    ---@param engCategory EntityCategory
    ---@return table
    GetEngineersWantingAssistance = function(self, category, engCategory)
        local testUnits = self:GetEngineersBuildingCategory(category, engCategory)

        local retUnits = {}
        for k,v in testUnits do
            if v.DesiresAssist == false then
                continue
            end

            if v.NumAssistees and TableGetn(v:GetGuards()) >= v.NumAssistees then
                continue
            end

            table.insert(retUnits, v)
        end
        return retUnits
    end,

    ---@param self EngineerManager
    ---@param unitType string
    ---@param category EntityCategory
    ---@return UserUnit[]|nil
    GetUnits = function(self, unitType, category)
        if self.ConsumptionUnits[unitType] then
            return EntityCategoryFilterDown(category, self.ConsumptionUnits[unitType].UnitsList)
        end
        return {}
    end,

    ---@param self EngineerManager
    ---@param unit Unit
    ---@param finishedUnit Unit
    UnitConstructionFinished = function(self, unit, finishedUnit)
        local aiBrain = self.Brain
        local armyIndex = aiBrain:GetArmyIndex()
        local dontAssignEngineerTask = true
        if finishedUnit:GetAIBrain():GetArmyIndex() == armyIndex and finishedUnit:GetFractionComplete() == 1 then
            if not finishedUnit['rngdata'] then
                finishedUnit['rngdata'] = {}
            end
            if EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit) then
                RUtils.UpdateShieldsProtectingUnit(aiBrain, finishedUnit)
                if finishedUnit.LocationType and finishedUnit.LocationType ~= self.LocationType then
                    local factoryLayer = 'Land'
                    if finishedUnit.Blueprint.CategoriesHash.NAVAL then
                        --LOG('Naval factory with base '..tostring(finishedUnit.LocationType)..' does not belong to the current base, return '..tostring(self.LocationType))
                        factoryLayer = 'Water'
                    end
                    --LOG('Check if factory manager exist')
                    if not aiBrain.BuilderManagers[finishedUnit.LocationType] then
                        --LOG('Builder Manager does not exist, validating requirement')
                        RUtils.ValidateFactoryManager(aiBrain, finishedUnit.LocationType, factoryLayer, finishedUnit)
                    end
                    return
                end
                if finishedUnit.Blueprint.CategoriesHash.NAVAL then
                    --LOG('Adding naval factory to base name '..tostring(self.LocationType))
                end
                aiBrain.BuilderManagers[self.LocationType].FactoryManager:AddFactory(finishedUnit)
            end
            if EntityCategoryContains(categories.SHIELD * categories.STRUCTURE, finishedUnit) then
                RUtils.UpdateUnitsProtectedByShield(aiBrain, finishedUnit)
            elseif EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION * (categories.TECH2 + categories.TECH3 + categories.EXPERIMENTAL), finishedUnit) then
                RUtils.UpdateShieldsProtectingUnit(aiBrain, finishedUnit)
            elseif EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, finishedUnit) then
                RUtils.UpdateShieldsProtectingUnit(aiBrain, finishedUnit)
            elseif EntityCategoryContains(categories.STRUCTURE * categories.STRATEGIC * categories.TECH3, finishedUnit) then
                RUtils.UpdateShieldsProtectingUnit(aiBrain, finishedUnit)
            elseif EntityCategoryContains(categories.MASSEXTRACTION * categories.STRUCTURE, finishedUnit) then
                local unitZone
                if not unitZone and aiBrain.ZonesInitialized then
                    local mexPos = finishedUnit:GetPosition()
                    if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                        unitZone = 'water'
                    else
                        unitZone = MAP:GetZoneID(mexPos,aiBrain.Zones.Land.index)
                    end
                end
                if unitZone ~= 'water' and not RNGAIGLOBALS.CampaignMapFlag then
                    local zone = aiBrain.Zones.Land.zones[unitZone]
                    if zone and zone.bestarmy and zone.bestarmy ~= armyIndex then
                        local playerIndex = zone.bestarmy
                        local bestArmyBrain = ArmyBrains[playerIndex]
                        if bestArmyBrain and bestArmyBrain.Status ~= "Defeat" and IsAlly(playerIndex, armyIndex) then
                            local TransferUnitsOwnership = import("/lua/simutils.lua").TransferUnitsOwnership
                            local AISendChat = import('/lua/AI/sorianutilities.lua').AISendChat
                            AISendChat('allies', aiBrain.Nickname, 'AI '..aiBrain.Nickname..' I believe this extractor is yours, handing over ownership '..aiBrain.Nickname, bestArmyBrain.Nickname)
                            TransferUnitsOwnership({finishedUnit}, playerIndex)
                        end
                    end
                end
            elseif EntityCategoryContains(categories.AIRSTAGINGPLATFORM * categories.STRUCTURE, finishedUnit) then
                self.Brain.BrainIntel.AirStagingRequired = false
            end

            local unitStats = self.Brain.IntelManager.UnitStats
            local unitValue = finishedUnit.Blueprint.Economy.BuildCostMass or 0
            if unitStats then
                local finishedUnitCats = finishedUnit.Blueprint.CategoriesHash
                if finishedUnitCats.MOBILE and finishedUnitCats.LAND and finishedUnitCats.EXPERIMENTAL and not finishedUnitCats.ARTILLERY then
                    unitStats['ExperimentalLand'].Built.Mass = unitStats['ExperimentalLand'].Built.Mass + unitValue
                end
            end
            if EntityCategoryContains(categories.ENGINEER - categories.ENGINEERSTATION, finishedUnit) then
                dontAssignEngineerTask = false
            end
            self:AddUnit(finishedUnit, dontAssignEngineerTask)
        end
    end,

    ---@param self EngineerManager
    ---@param builderName string
    AssignTimeout = function(self, builderName)
        local oldPri = self:GetBuilderPriority(builderName)
        if oldPri then
            self:SetBuilderPriority(builderName, 0, true)
        end
    end,

    ---@param self EngineerManager
    ---@param templateName string
    ---@return table
    GetEngineerPlatoonTemplate = function(self, templateName)
        local templateData = PlatoonTemplates[templateName]
        if not templateData then
            error('*AI ERROR: Invalid platoon template named - ' .. templateName)
        end
        if not templateData.Plan then
            error('*AI ERROR: PlatoonTemplate named: ' .. templateName .. ' does not have a Plan')
        end
        if not templateData.GlobalSquads then
            error('*AI ERROR: PlatoonTemplate named: ' .. templateName .. ' does not have a GlobalSquads')
        end
        local template = {
            templateData.Name,
            templateData.Plan,
            unpack(templateData.GlobalSquads)
        }
        return template
    end,

    ---@param manager EngineerManager
    ---@param unit Unit
    ForkEngineerTask = function(manager, unit)
        if unit.ForkedEngineerTask then
            KillThread(unit.ForkedEngineerTask)
            unit.ForkedEngineerTask = unit:ForkThread(manager.Wait, manager, 3)
        else
            unit.ForkedEngineerTask = unit:ForkThread(manager.Wait, manager, 20)
        end
    end,

    ---@param manager EngineerManager
    ---@param unit Unit
    ---@param delaytime number
    DelayAssign = function(manager, unit, delaytime)
        if unit.ForkedEngineerTask then
            KillThread(unit.ForkedEngineerTask)
        end
        unit.ForkedEngineerTask = unit:ForkThread(manager.Wait, manager, delaytime or 10)
    end,

    ---@param unit Unit
    ---@param manager EngineerManager
    ---@param ticks integer
    Wait = function(unit, manager, ticks)
        coroutine.yield(ticks)
        if not unit.Dead then
            manager:AssignEngineerTask(unit)
        end
    end,

    ---@param manager EngineerManager
    ---@param unit Unit
    EngineerWaiting = function(manager, unit)
        coroutine.yield(50)
        if not unit.Dead then
            manager:AssignEngineerTask(unit)
        end
    end,

    ---@param self EngineerManager
    ---@param builder Unit
    ---@param params any
    ---@return boolean
    BuilderParamCheck = function(self,builder,params)
        local unit = params[1]

        builder:FormDebug()

        -- Check if the category of the unit matches the category of the builder
        local template = self:GetEngineerPlatoonTemplate(builder:GetPlatoonTemplate())
        if not unit.Dead and EntityCategoryContains(template[3][1], unit) and builder:CheckInstanceCount() then
            return true
        end

        -- Nope
        return false
    end,

    CreateFloatingEM = function(self, brain, location)
        BuilderManager.Create(self,brain)

        if not location then
            error('*PLATOOM FORM MANAGER ERROR: Invalid parameters; location')
            return false
        end

        self.Location = location
        self.Radius = 0
        self.LocationType = 'FLOATING'

        self.ConsumptionUnits = {
            Engineers = { Category = categories.ENGINEER, Units = {}, UnitsList = {}, Count = 0, },
        }
        self.QueuedStructures = {}
        self.QueuedStructures = {
            TECH1 = {},
            TECH2 = {},
            TECH3 = {},
            EXPERIMENTAL = {},
            SUBCOMMANDER = {},
            COMMAND = {},
            DEFENSE = {},
        }
        self.StructuresBeingBuilt = {}
        self.StructuresBeingBuilt = {
            TECH1 = {},
            TECH2 = {},
            TECH3 = {},
            EXPERIMENTAL = {},
            SUBCOMMANDER = {},
            COMMAND = {},
            DEFENSE = {},
        }

        self:AddBuilderType('Any')
    end,

    ---@param self EngineerManager
    ---@param unit Unit
    ---@param dontAssign boolean
    AddUnit = function(self, unit, dontAssign)
        --LOG('+ AddUnit')
        if EntityCategoryContains(categories.STRUCTURE * categories.DEFENSE - categories.WALL, unit) then
            if not unit.BuilderManagerData then
                unit.BuilderManagerData = {}
            end
            unit.BuilderManagerData.LocationType = self.LocationType
            RUtils.AddDefenseUnitToSpoke(self.Brain, self.LocationType, unit)
        end
        for k,v in self.ConsumptionUnits do
            if EntityCategoryContains(v.Category, unit) then
                table.insert(v.Units, { Unit = unit, Status = true })
                table.insert(v.UnitsList, unit)
                v.Count = v.Count + 1

                if not unit.BuilderManagerData then
                    unit.BuilderManagerData = {}
                end
                unit.BuilderManagerData.EngineerManager = self
                unit.BuilderManagerData.LocationType = self.LocationType

                if not unit.BuilderManagerData.CallbacksSetup then
                    unit.BuilderManagerData.CallbacksSetup = true
                    -- Callbacks here
                    local deathFunction = function(unit)
                        unit.BuilderManagerData.EngineerManager:RemoveUnit(unit)
                    end

                    import('/lua/scenariotriggers.lua').CreateUnitDestroyedTrigger(deathFunction, unit)

                    local newlyCapturedFunction = function(unit, captor)
                        local aiBrain = captor:GetAIBrain()
                        --LOG('*AI DEBUG: ENGINEER: I was Captured by '..aiBrain.Nickname..'!')
                        if aiBrain.BuilderManagers then
                            local engManager = aiBrain.BuilderManagers[captor.BuilderManagerData.LocationType].EngineerManager
                            if engManager then
                                engManager:AddUnit(unit)
                            end
                        end
                    end

                    import('/lua/scenariotriggers.lua').CreateUnitCapturedTrigger(nil, newlyCapturedFunction, unit)

                    if EntityCategoryContains(categories.ENGINEER - categories.STATIONASSISTPOD, unit) then
                        local unitConstructionFinished = function(unit, finishedUnit)
                            -- Call function on builder manager; let it handle the finish of work
                            local aiBrain = unit:GetAIBrain()
                            local engManager = aiBrain.BuilderManagers[unit.BuilderManagerData.LocationType].EngineerManager
                            if engManager then
                                engManager:UnitConstructionFinished(unit, finishedUnit)
                            end
                        end

                        local unitConstructionStarted = function(unit, startedUnit)
                            local aiBrain = unit:GetAIBrain()
                            local engManager = aiBrain.BuilderManagers[unit.BuilderManagerData.LocationType].EngineerManager
                            if engManager and not startedUnit.LocationType then
                                startedUnit.LocationType = unit.BuilderManagerData.LocationType
                            end
                        end
                        import('/lua/ScenarioTriggers.lua').CreateUnitBuiltTrigger(unitConstructionFinished, unit, categories.ALLUNITS)
                        import('/lua/ScenarioTriggers.lua').CreateStartBuildTrigger(unitConstructionStarted, unit, categories.ALLUNITS)
                    end
                end

                if not dontAssign then
                    self:ForkEngineerTask(unit)
                end
                return
            end
        end
    end,

    ---@param manager EngineerManager
    ---@param unit Unit
    TaskFinished = function(manager, unit)
        if manager.LocationType ~= 'FLOATING' and VDist3(manager.Location, unit:GetPosition()) > manager.Radius and not EntityCategoryContains(categories.COMMAND, unit) then
            manager:ReassignUnit(unit)
        else
            manager:ForkEngineerTask(unit)
        end
    end,

    ---@param self EngineerManager
    ---@param unit Unit
    ReassignUnit = function(self, unit)
        local managers = self.Brain.BuilderManagers
        local bestManager = false
        local distance = false
        local unitPos = unit:GetPosition()
        for k,v in managers do
            if (v.FactoryManager.LocationActive and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0) or v == 'MAIN' then
                local checkDistance = VDist3(v.EngineerManager:GetLocationCoords(), unitPos)
                if not distance then
                    distance = checkDistance
                end
                if checkDistance < v.EngineerManager.Radius and checkDistance < distance then
                    distance = checkDistance
                    bestManager = v.EngineerManager
                end
            end
        end
        if not bestManager then
            if self.Brain.BuilderManagers['FLOATING'].EngineerManager then
                bestManager = self.Brain.BuilderManagers['FLOATING'].EngineerManager
            end
        end
        self:RemoveUnit(unit)
        if bestManager and not unit.Dead then
            bestManager:AddUnit(unit)
        end
    end,

    ---@param self EngineerManager
    ---@param unit Unit
    AssignEngineerTask = function(self, unit)
        --LOG('Engineer trying to have task assigned '..unit.EntityId)
        if unit.Active or unit.Combat or unit.Upgrading then
            --RNGLOG('Unit Still in combat or going home, delay')
            self.AssigningTask = false
            --RNGLOG('CDR Combat Delay')
            self:DelayAssign(unit, 50)
            return
        end
        --LOG('Engineer passed active, combat, or upgrading '..unit.EntityId)
        unit.LastActive = GetGameTimeSeconds()
        if unit.UnitBeingAssist or unit.UnitBeingBuilt then
            --RNGLOG('UnitBeingAssist Delay')
            self:DelayAssign(unit, 50)
            return
        end

        unit.DesiresAssist = false
        unit.NumAssistees = nil
        unit.MinNumAssistees = nil

        if self.AssigningTask then
            --RNGLOG('Assigning Task Delay')
            self:DelayAssign(unit, 50)
            return
        else
            self.AssigningTask = true
        end

        if self:GetLocationBasedBuilder(unit) then
            --LOG('We have a location based builder, stop assignment')
            self.AssigningTask = false
            return
        end

        local builder = self:GetHighestBuilder('Any', {unit})
        --LOG('HighestBuilder is '..repr(builder))

        if builder and ((not unit.Combat) or (not unit.Upgrading) or (not unit.Active)) then
            -- Fork off the platoon here
            local template = self:GetEngineerPlatoonTemplate(builder:GetPlatoonTemplate())
            local hndl = self.Brain:MakePlatoon(template[1], template[2])
            self.Brain:AssignUnitsToPlatoon(hndl, {unit}, 'support', 'none')
            unit.PlatoonHandle = hndl

            --if EntityCategoryContains(categories.COMMAND, unit) then
            --   --RNGLOG('*AI DEBUG: ARMY '..self.Brain.Nickname..': Engineer Manager Forming - '..builder.BuilderName..' - Priority: '..builder:GetPriority())
            --end

            --LOG('*AI DEBUG: ARMY ', repr(self.Brain:GetArmyIndex()),': Engineer Manager Forming - ',repr(builder.BuilderName),' - Priority: ', builder:GetPriority())
            hndl.PlanName = template[2]

            --If we have specific AI, fork that AI thread
            if builder:GetPlatoonAIFunction() then
                hndl:StopAI()
                local aiFunc = builder:GetPlatoonAIFunction()
                hndl:ForkAIThread(import(aiFunc[1])[aiFunc[2]])
            end
            if builder:GetPlatoonAIPlan() then
                hndl.PlanName = builder:GetPlatoonAIPlan()
                hndl:SetAIPlanRNG(hndl.PlanName)
            end

            --If we have additional threads to fork on the platoon, do that as well.
            if builder:GetPlatoonAddPlans() then
                for papk, papv in builder:GetPlatoonAddPlans() do
                    hndl:ForkThread(hndl[papv])
                end
            end

            if builder:GetPlatoonAddFunctions() then
                for pafk, pafv in builder:GetPlatoonAddFunctions() do
                    hndl:ForkThread(import(pafv[1])[pafv[2]])
                end
            end

            if builder:GetPlatoonAddBehaviors() then
                for pafk, pafv in builder:GetPlatoonAddBehaviors() do
                    hndl:ForkThread(import('/lua/ai/AIBehaviors.lua')[pafv])
                end
            end

            hndl.Priority = builder:GetPriority()
            hndl.BuilderName = builder:GetBuilderName()

            hndl:SetPlatoonData(builder:GetBuilderData(self.LocationType))

            if hndl.PlatoonData.DesiresAssist then
                unit.DesiresAssist = hndl.PlatoonData.DesiresAssist
            else
                unit.DesiresAssist = true
            end

            if hndl.PlatoonData.NumAssistees then
                unit.NumAssistees = hndl.PlatoonData.NumAssistees
            end

            if hndl.PlatoonData.MinNumAssistees then
                unit.MinNumAssistees = hndl.PlatoonData.MinNumAssistees
            end
            if hndl.PlatoonData.JobType then
                unit.JobType = hndl.PlatoonData.JobType
            end

            builder:StoreHandle(hndl)
            self.AssigningTask = false
            return
        end
        self.AssigningTask = false
        --RNGLOG('End of AssignEngineerTask Delay')
        self:DelayAssign(unit, 50)
    end,

    GetLocationBasedBuilder = function(self, unit)
        if unit and not unit.Dead then
            local aiBrain = self.Brain
            local engPos = unit:GetPosition()
            local unitCats = unit.Blueprint.CategoriesHash
            local brainIndex = aiBrain:GetArmyIndex()
            local currentCount = GetArmyUnitCostTotal(brainIndex)
            local cap = GetArmyUnitCap(brainIndex)
            local capRatio = currentCount / cap
            local layer = aiBrain.BuilderManagers[self.LocationType].Layer
            if capRatio > 0.90 then
                return
            end
            if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime <= 0.75 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime <= 0.75) then
                --RNGLOG('GreaterThanEconEfficiencyOverTime passed True')
                local EnergyEfficiency = math.min(aiBrain:GetEconomyIncome('ENERGY') / aiBrain:GetEconomyRequested('ENERGY'), 2)
                local MassEfficiency = math.min(aiBrain:GetEconomyIncome('MASS') / aiBrain:GetEconomyRequested('MASS'), 2)
                if (MassEfficiency <= 0.75 and EnergyEfficiency <= 0.75) then
                    return
                end
            end

            if layer ~= 'Water' then
                if self.LocationType == 'FLOATING' then
                    local radarRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 75, 'RADAR')
                    if radarRequestPos then
                        --LOG('Radar Request found')
                        -- Fork a lightweight radar builder platoon
                        local locationPlatoon = aiBrain:MakePlatoon('RadarPlatoon', 'StateMachineAIRNG')
                        aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                        unit.PlatoonHandle = locationPlatoon
                        locationPlatoon.PlanName = 'StateMachineAIRNG'
                        import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'RadarBuild', Position = radarRequestPos, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                        return true
                    end
                end
                if self.LocationType == 'FLOATING' or self.LocationType == 'MAIN' then
                    local tech1PointDefenseRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 75, 'TECH1POINTDEFENSE')
                    if tech1PointDefenseRequestPos then
                        --LOG('T1PD Request found')
                        local locationPlatoon = aiBrain:MakePlatoon('T1PDPlatoon', 'StateMachineAIRNG')
                        aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                        unit.PlatoonHandle = locationPlatoon
                        locationPlatoon.PlanName = 'StateMachineAIRNG'
                        import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'T1PDBuild', Position = tech1PointDefenseRequestPos, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                        return true
                    end
                end
            end
            if layer ~= 'Water' and (unitCats.TECH2 or unitCats.TECH3) then
                if aiBrain.StructureManager and aiBrain.StructureManager.TMDRequired then
                    for _, v in aiBrain.StructureManager.StructuresRequiringTMD do
                        if v.Unit and not v.Unit.Dead then
                            local structurePos = v.Unit:GetPosition()
                            local rx = engPos[1] - structurePos[1]
                            local rz = engPos[3] - structurePos[3]
                            local tmpDistance = rx * rx + rz * rz
                            if tmpDistance < 14400 and not aiBrain.IntelManager:IsExistingStructureRequestPresent(structurePos, 15, 'TMD') then
                                aiBrain.IntelManager:RequestStructureNearPosition(structurePos, 15, 'TMD')
                                --LOG('Request to build structure defense TMD')
                                local tmdRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 120, 'TMD')
                                if tmdRequestPos then
                                    --LOG('Starting state machine for TMD build, locationType is '..tostring(self.LocationType))
                                    local locationPlatoon = aiBrain:MakePlatoon('TMDPlatoon', 'StateMachineAIRNG')
                                    aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                                    unit.PlatoonHandle = locationPlatoon
                                    locationPlatoon.PlanName = 'StateMachineAIRNG'
                                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'TMDBuild', Position = structurePos, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                                    return true
                                end
                            end
                        end
                    end
                end
                local baseZone = aiBrain.BuilderManagers[self.LocationType].ZoneID
                if baseZone then
                    local locationMobileSiloUnits = aiBrain.Zones.Land.zones[baseZone].enemySilos
                    if locationMobileSiloUnits and locationMobileSiloUnits  > 0 then
                        --LOG('Request to build MML defense TMD')
                        local basePos = aiBrain.BuilderManagers[self.LocationType].Position
                        local numUnits = aiBrain:GetNumUnitsAroundPoint( categories.ANTIMISSILE * categories.TECH2, basePos, 65, 'Ally' )
                        if math.ceil(math.max(locationMobileSiloUnits / 2.5, 4)) > numUnits then
                            if not aiBrain.IntelManager:IsExistingStructureRequestPresent(basePos, 65, 'TMD') then
                                aiBrain.IntelManager:RequestStructureNearPosition(basePos, 65, 'TMD')
                                local tmdRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 120, 'TMD')
                                if tmdRequestPos then
                                    local locationPlatoon = aiBrain:MakePlatoon('TMDPlatoon', 'StateMachineAIRNG')
                                    aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                                    unit.PlatoonHandle = locationPlatoon
                                    locationPlatoon.PlanName = 'StateMachineAIRNG'
                                    import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'TMDBuild', Position = basePos, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                                    return true
                                end
                            end
                        end
                    end
                    --[[
                    if aiBrain.StructureManager and aiBrain.StructureManager.ShieldsRequired then
                        local structureManager = aiBrain.StructureManager
                        local locationExtractorUnits = aiBrain.Zones.Land.zones[baseZone].units.EXTRACTOR
                        for _, v in locationExtractorUnits do
                            if v and not v.Dead then
                                local isDefended = structureManager:StructureShieldCheck(v)
                                if not isDefended then
                                    if not aiBrain.IntelManager:IsExistingStructureRequestPresent(basePos, 65, 'SHIELD') then
                                        aiBrain.IntelManager:RequestStructureNearPosition(basePos, 65, 'SHIELD')
                                        local shieldRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 120, 'SHIELD')
                                        if shieldRequestPos then
                                            local locationPlatoon = aiBrain:MakePlatoon('ShieldPlatoon', 'StateMachineAIRNG')
                                            aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                                            unit.PlatoonHandle = locationPlatoon
                                            locationPlatoon.PlanName = 'StateMachineAIRNG'
                                            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'ShieldBuild', Position = basePos, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                                            return true
                                        end
                                    end
                                end
                            end
                        end
                    end]]
                end
            end
            if (aiBrain.EconomyOverTimeCurrent.MassEfficiencyOverTime <= 1.0 and aiBrain.EconomyOverTimeCurrent.EnergyEfficiencyOverTime <= 1.2) then
                --RNGLOG('GreaterThanEconEfficiencyOverTime passed True')
                local EnergyEfficiency = math.min(aiBrain:GetEconomyIncome('ENERGY') / aiBrain:GetEconomyRequested('ENERGY'), 2)
                local MassEfficiency = math.min(aiBrain:GetEconomyIncome('MASS') / aiBrain:GetEconomyRequested('MASS'), 2)
                if (MassEfficiency <= 1.0 and EnergyEfficiency <= 1.2) then
                    return
                end
            end
            local numEnemyUnits = aiBrain.emanager.Nuke.T3
            if unitCats.TECH3 and numEnemyUnits and numEnemyUnits > 0 then
                local currentSMD = self:GetNumUnits('AntiNuke')
                local beingBuiltSmd = self:NumStructuresBeingBuilt('TECH3', { 'STRUCTURE', 'ANTIMISSILE', 'DEFENSE' })
                local queuedSmdCount = self:NumStructuresQueued('TECH3', { 'STRUCTURE', 'ANTIMISSILE', 'DEFENSE' })
                if currentSMD == 0 and beingBuiltSmd == 0 and queuedSmdCount == 0 then
                    if not aiBrain.IntelManager:IsAssignedStructureRequestPresent(self.Location, 120, 'SMD') then
                        local smdRequestPos = aiBrain.IntelManager:AssignEngineerToStructureRequestNearPosition(unit, unit:GetPosition(), 120, 'SMD')
                        if smdRequestPos then
                            local locationPlatoon = aiBrain:MakePlatoon('SMDPlatoon', 'StateMachineAIRNG')
                            aiBrain:AssignUnitsToPlatoon(locationPlatoon, {unit}, 'support', 'none')
                            unit.PlatoonHandle = locationPlatoon
                            locationPlatoon.PlanName = 'StateMachineAIRNG'
                            import("/mods/rngai/lua/ai/statemachines/platoon-engineer-utility.lua").AssignToUnitsMachine({ PlatoonData = { PreAllocatedTask = true, Task = 'SMDBuild', Position = self.Location, LocationType = self.LocationType} }, locationPlatoon, locationPlatoon:GetPlatoonUnits())
                            return true
                        end
                    end
                end
            end
        end
    end,

    NumStructuresQueued = function(self, techCategory, categoriesTable)
        local timeStamp = GetGameTimeSeconds()
        local queuedStructures = self.QueuedStructures[techCategory]
        local structuresQueued = 0
        if queuedStructures then
            for k, v in queuedStructures do
                local itemUnitCats = v.CategoriesHash
                local allMatch = true
                for _, cat in categoriesTable do
                    if not itemUnitCats[cat] then
                        allMatch = false
                        break
                    end
                end
                if allMatch and v.Engineer and not v.Engineer.Dead and v.TimeStamp + 30 > timeStamp then
                    structuresQueued = structuresQueued + 1
                end
            end
        end
        return structuresQueued
    end,

    NumStructuresBeingBuilt = function(self, techCategory, categoriesTable)
        local beingBuiltStructures = self.StructuresBeingBuilt[techCategory]
        local structuresBeingBuilt = 0
        if beingBuiltStructures then
            for k, v in beingBuiltStructures do
                if v.Unit and not v.Unit.Dead then
                    local itemUnitCats = v.Unit.Blueprint.CategoriesHash
                    local allMatch = true
                    for _, cat in categoriesTable do
                        if not itemUnitCats[cat] then
                            allMatch = false
                            break
                        end
                    end
                    if allMatch then
                        --LOG('Found unit with id '..tostring(v.Unit.UnitId)..' completion percent is '..tostring(v.Unit:GetFractionComplete()))
                        structuresBeingBuilt = structuresBeingBuilt + 1
                    end
                end
            end
        end
        return structuresBeingBuilt
    end,

    ---@param self EngineerManager
    ---@param unit Unit
    RemoveUnit = function(self, unit)
        local found = false
        for k,v in self.ConsumptionUnits do
            if EntityCategoryContains(v.Category, unit) then
                for num,sUnit in v.Units do
                    if sUnit.Unit == unit then
                        table.remove(v.Units, num)
                        table.remove(v.UnitsList, num)
                        v.Count = v.Count - 1
                        found = true
                        break
                    end
                end
            end
            if found then
                break
            end
        end
    end,

}

---@param brain AIBrain
---@param lType any
---@param location Vector
---@param radius number
---@return EngineerManager
function CreateEngineerManager(brain, lType, location, radius)
    local em = EngineerManager()
    em:Create(brain, lType, location, radius)
    return em
end

CreateFloatingEngineerManager = function(brain, location)
    local em = EngineerManager()
    --LOG('Starting Floating Engineer Manager...')
    em:CreateFloatingEM(brain, location)
    return em
end


-- kept for mod backwards compatibility
local AIBuildUnits = import("/lua/ai/aibuildunits.lua")