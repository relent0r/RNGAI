-- ***************************************************************************
-- *
-- **  File     :  /lua/sim/BuilderManager.lua
-- **
-- **  Summary  : Manage builders
-- **
-- **  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-- ****************************************************************************
local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local BuilderManager = import("/mods/RNGAI/lua/AI/BuilderFramework/buildermanager.lua").BuilderManager
local Builder = import("/mods/RNGAI/lua/AI/BuilderFramework/builder.lua")
local AIUtils = import("/lua/ai/aiutilities.lua")
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ScenarioUtils = import('/lua/sim/ScenarioUtilities.lua')

local TableGetn = table.getn

---@class FactoryBuilderManager : BuilderManager
---@field Location Vector
---@field Radius number
---@field LocationType LocationType
---@field RallyPoint Vector | false
---@field LocationActive boolean
---@field RandomSamePriority boolean
---@field PlatoonListEmpty boolean
---@field UseCenterPoint boolean
FactoryBuilderManager = Class(BuilderManager) {
    ---@param self FactoryBuilderManager
    ---@param brain AIBrain
    ---@param lType any
    ---@param location Vector
    ---@param radius number
    ---@param useCenterPoint boolean
    ---@return boolean
    Create = function(self, brain, lType, location, radius, useCenterPoint)
        BuilderManager.Create(self,brain, lType, location, radius)

        if not lType or not location or not radius then
            error('*FACTORY BUILDER MANAGER ERROR: Invalid parameters; requires locationType, location, and radius')
            return false
        end

        local builderTypes = { 'Air', 'Land', 'Sea', 'Gate', }
        for k,v in builderTypes do
            self:AddBuilderType(v)
        end

        -- backwards compatibility for mods
        self.Location = self.Location or location
        self.Radius = self.Radius or radius
        self.LocationType = self.LocationType or lType

        self.RallyPoint = false

        self.FactoryList = {}

        self.LocationActive = false
        self.LandBuildRate = 0
        self.AirBuildRate = 0
        self.NavalBuildRate = 0

        self.RandomSamePriority = true
        self.PlatoonListEmpty = true

        self.UseCenterPoint = useCenterPoint or false
        self:ForkThread(self.RallyPointMonitor)
    end,

    ---@param self FactoryBuilderManager
    RallyPointMonitor = function(self)
        local navalLocation = self.Brain.BuilderManagers[self.LocationType].Layer == 'Water'
        while true do
            if self.LocationActive and self.RallyPoint then
                --LOG('*AI DEBUG: Checking Active Rally Point')
                local newRally = false
                local bestDist = 999999999
                local rallyheight = GetTerrainHeight(self.RallyPoint[1], self.RallyPoint[3])
                if self.Brain:GetNumUnitsAroundPoint(categories.STRUCTURE, self.RallyPoint, 15, 'Ally') > 0 then
                    --LOG('*AI DEBUG: Searching for a new Rally Point Location')
                    for x = -30, 30, 5 do
                        for z = -30, 30, 5 do
                            local height = GetTerrainHeight(self.RallyPoint[1] + x, self.RallyPoint[3] + z)
                            if GetSurfaceHeight(self.RallyPoint[1] + x, self.RallyPoint[3] + z) > height or rallyheight > height + 10 or rallyheight < height - 10 then
                                continue
                            end
                            local tempPos = { self.RallyPoint[1] + x, height, self.RallyPoint[3] + z }
                            if navalLocation and not RUtils.PositionInWater(tempPos) then
                                continue
                            end
                            if self.Brain:GetNumUnitsAroundPoint(categories.STRUCTURE, tempPos, 15, 'Ally') > 0 then
                                continue
                            end
                            if not newRally or VDist2(tempPos[1], tempPos[3], self.RallyPoint[1], self.RallyPoint[3]) < bestDist then
                                newRally = tempPos
                                bestDist = VDist2(tempPos[1], tempPos[3], self.RallyPoint[1], self.RallyPoint[3])
                            end
                        end
                    end
                    if newRally then
                        self.RallyPoint = newRally
                        --LOG('*AI DEBUG: Setting a new Rally Point Location')
                        for k,v in self.FactoryList do
                            IssueClearFactoryCommands({v})
                            IssueFactoryRallyPoint({v}, self.RallyPoint)
                        end
                    end
                end
            end
            WaitSeconds(300)
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param builderData BuilderSpec
    ---@param locationType LocationType
    ---@return boolean
    AddBuilder = function(self, builderData, locationType)
        local newBuilder = Builder.CreateFactoryBuilder(self.Brain, builderData, locationType)
        if newBuilder:GetBuilderType() == 'All' then
            for k,v in self.BuilderData do
                self:AddInstancedBuilder(newBuilder, k)
            end
        else
            self:AddInstancedBuilder(newBuilder)
        end
        return newBuilder
    end,

    ---@param self FactoryBuilderManager
    ---@return boolean
    HasPlatoonList = function(self)
        return self.PlatoonListEmpty
    end,

    ---@param self FactoryBuilderManager
    ---@return integer
    GetNumFactories = function(self)
        if self.FactoryList then
            return TableGetn(self.FactoryList)
        end
        return 0
    end,

    ---@param self FactoryBuilderManager
    ---@param category EntityCategory
    ---@return number
    GetNumCategoryFactories = function(self, category)
        if self.FactoryList then
            return EntityCategoryCount(category, self.FactoryList)
        end
        return 0
    end,

    ---@param self FactoryBuilderManager
    ---@param category EntityCategory
    ---@param facCategory EntityCategory
    ---@return integer
    GetNumCategoryBeingBuilt = function(self, category, facCategory)
        return TableGetn(self:GetFactoriesBuildingCategory(category, facCategory))
    end,

    ---@param self FactoryBuilderManager
    ---@param category EntityCategory
    ---@param facCategory EntityCategory
    ---@return table
    GetFactoriesBuildingCategory = function(self, category, facCategory)
        local units = {}
        for k,v in EntityCategoryFilterDown(facCategory, self.FactoryList) do
            if v.Dead then
                continue
            end

            if not v:IsUnitState('Upgrading') and not v:IsUnitState('Building') then
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

    ---@param self FactoryBuilderManager
    ---@param category EntityCategory
    ---@param facCatgory EntityCategory
    ---@return table
    GetFactoriesWantingAssistance = function(self, category, facCatgory)
        local testUnits = self:GetFactoriesBuildingCategory(category, facCatgory)

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

    ---@param self FactoryBuilderManager
    ---@param category EntityCategory
    ---@return UserUnit[]|nil
    GetFactories = function(self, category)
        local retUnits = EntityCategoryFilterDown(category, self.FactoryList)
        return retUnits
    end,

    ---@param self FactoryBuilderManager
    ---@param unit Unit
    AddFactory = function(self,unit)
        if not self:FactoryAlreadyExists(unit) and unit:GetFractionComplete() == 1 then
            table.insert(self.FactoryList, unit)
            unit.DesiresAssist = true
            if EntityCategoryContains(categories.LAND, unit) then
                self:SetupNewFactory(unit, 'Land')
            elseif EntityCategoryContains(categories.AIR, unit) then
                self:SetupNewFactory(unit, 'Air')
            elseif EntityCategoryContains(categories.NAVAL, unit) then
                self:SetupNewFactory(unit, 'Sea')
            else
                self:SetupNewFactory(unit, 'Gate')
            end
            self.LocationActive = true
            if self.LocationType then
                local zone = self.Brain.BuilderManagers[self.LocationType].ZoneID
                if zone then
                    if self.Brain.Zones.Land.zones[zone].engineerplatoonallocated then
                        self.Brain.Zones.Land.zones[zone].engineerplatoonallocated = nil
                    end
                end
                unit.LocationType = self.LocationType
                unit.Zone = zone
            end
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@return boolean
    FactoryAlreadyExists = function(self, factory)
        for k,v in self.FactoryList do
            if v == factory then
                return true
            end
        end
        return false
    end,

    ---@param self FactoryBuilderManager
    ---@param unit Unit
    ---@param bType string
    SetupNewFactory = function(self,unit,bType)
        self:SetupFactoryCallbacks({unit}, bType)
        self:ForkThread(self.DelayRallyPoint, unit)
    end,

    ---@param self FactoryBuilderManager
    ---@param factories string[]
    ---@param bType string
    SetupFactoryCallbacks = function(self,factories,bType)
        for k,v in factories do
            if not v.BuilderManagerData then
                v.BuilderManagerData = { FactoryBuildManager = self, BuilderType = bType, }

                local factoryDestroyed = function(v)
                                            -- Call function on builder manager; let it handle death of factory
                                            self:FactoryDestroyed(v)
                                        end
                import("/lua/scenariotriggers.lua").CreateUnitDestroyedTrigger(factoryDestroyed, v)

                local factoryNewlyCaptured = function(unit, captor)
                                            local aiBrain = captor:GetAIBrain()
                                            --LOG('*AI DEBUG: FACTORY: I was Captured by '..aiBrain.Nickname..'!')
                                            if aiBrain.BuilderManagers then
                                                local facManager = aiBrain.BuilderManagers[captor.BuilderManagerData.LocationType].FactoryManager
                                                if facManager then
                                                    facManager:AddFactory(unit)
                                                end
                                            end
                                        end
                import("/lua/scenariotriggers.lua").CreateUnitCapturedTrigger(nil, factoryNewlyCaptured, v)

                local factoryWorkFinish = function(v, finishedUnit)
                                            -- Call function on builder manager; let it handle the finish of work
                                            self:FactoryFinishBuilding(v, finishedUnit)
                                        end
                import("/lua/scenariotriggers.lua").CreateUnitBuiltTrigger(factoryWorkFinish, v, categories.ALLUNITS)
            end
            self:ForkThread(self.DelayBuildOrder, v, bType, 0.1)
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    FactoryDestroyed = function(self, factory)
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

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@param bType string
    ---@param time number
    DelayBuildOrder = function(self,factory,bType,time)
        if factory.DelayThread then
            return
        end
        --self:GenerateInitialQueue('InitialBuildQueueRNG', factory)
        factory.DelayThread = true
        coroutine.yield(math.random(5,15))
        factory.DelayThread = false
        self:AssignBuildOrder(factory,bType)
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@return string|false
    GetFactoryFaction = function(self, factory)
        if EntityCategoryContains(categories.UEF, factory) then
            return 'UEF'
        elseif EntityCategoryContains(categories.AEON, factory) then
            return 'Aeon'
        elseif EntityCategoryContains(categories.CYBRAN, factory) then
            return 'Cybran'
        elseif EntityCategoryContains(categories.SERAPHIM, factory) then
            return 'Seraphim'
        elseif self.Brain.CustomFactions then
            return self:UnitFromCustomFaction(factory)
        end
        return false
    end,

    ---@param self FactoryBuilderManager
    ---@param factory FactoryBuilderManager
    ---@return Categories|nil
    UnitFromCustomFaction = function(self, factory)
        local customFactions = self.Brain.CustomFactions
        for k,v in customFactions do
            if EntityCategoryContains(v.customCat, factory) then
                return v.cat
            end
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param templateName string
    ---@param factory Unit
    ---@return table
    GetFactoryTemplate = function(self, templateName, factory)
        local template
        if templateName == 'InitialBuildQueueRNG' then
            template = self:GenerateInitialBuildQueue(templateName, factory)
            self.Brain.InitialBuildQueueComplete = true
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
                        --LOG('*AI DEBUG: Replacement unit found!')
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

    ---@param self FactoryBuilderManager
    ---@param template any
    ---@param templateName string
    ---@param faction Unit
    ---@return boolean|table
    GetCustomReplacement = function(self, template, templateName, faction)
        local retTemplate = false
        local templateData = self.Brain.CustomUnits[templateName]
        if templateData and templateData[faction] then
            --LOG('*AI DEBUG: Replacement for '..templateName..' exists.')
            local rand = Random(1,100)
            local possibles = {}
            for k,v in templateData[faction] do
                if rand <= v[2] or template[1] == 'NoOriginalUnit' then
                    --LOG('*AI DEBUG: Insert possibility.')
                    table.insert(possibles, v[1])
                end
            end
            if not table.empty(possibles) then
                rand = Random(1,TableGetn(possibles))
                local customUnitID = possibles[rand]
                --LOG('*AI DEBUG: Replaced with '..customUnitID)
                retTemplate = { customUnitID, template[2], template[3], template[4], template[5] }
            end
        end
        return retTemplate
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@param bType string
    AssignBuildOrder = function(self,factory,bType)
        -- Find a builder the factory can build
        if factory.Dead then
            return
        end
        local builder = self:GetHighestBuilder(bType,{factory})
        if builder then
            local builderType = builder:GetFactoryBuilderType()
            if builderType == 'Category' then
                local buildCategory = builder:GetUnitCategory()
                local unitFaction = categories[factory.Blueprint.FactionCategory]
                local unitIds = EntityCategoryGetUnitList(buildCategory * unitFaction)
                local unitIdCount = TableGetn(unitIds)
                if unitIdCount == 0 then
                    return false
                end
        
                local unitId
                for k = 1, unitIdCount do
                    local candidate = unitIds[k]
                    if factory:CanBuild(candidate) then
                        unitId = candidate
                        break
                    end
                end
                if unitId then
                    IssueBuildFactory({factory}, unitId, 1)
                end
            else
                local template = self:GetFactoryTemplate(builder:GetPlatoonTemplate(), factory)
                --LOG('*AI DEBUG: ARMY '..tostring(self.Brain:GetArmyIndex())..': Factory Builder Manager Building - '..tostring(builder.BuilderName)..' at base '..tostring(self.LocationType))
                self.Brain:BuildPlatoon(template, {factory}, 1)
            end
        else
            -- No builder found setup way to check again
            self:ForkThread(self.DelayBuildOrder, factory, bType, 2)
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@param finishedUnit Unit
    FactoryFinishBuilding = function(self,factory,finishedUnit)
        --RNGLOG('RNG FactorFinishedbuilding')
        if EntityCategoryContains(categories.ENGINEER, finishedUnit) then
            local unitCats = finishedUnit.Blueprint.CategoriesHash
            if unitCats.SUBCOMMANDER then
                local enhancementTable = finishedUnit.Blueprint.Enhancements
                for name, enhancement in pairs(enhancementTable) do
                    if type(enhancement) == "table" and enhancement.BuildCostEnergy then
                        local isEngineeringType = enhancement.NewBuildRate
                        if isEngineeringType and finishedUnit:HasEnhancement(name) then
                            if not finishedUnit['rngdata'] then
                                finishedUnit['rngdata'] = {}
                            end
                            if not finishedUnit['rngdata']['eng'].buildpower then
                                finishedUnit['rngdata']['eng'] = {}
                                finishedUnit['rngdata']['eng'].buildpower = enhancement.NewBuildRate
                                --LOG('Setting sacueng build power')
                                break
                            end
                        end
                    end
                end
            end
            self.Brain.BuilderManagers[self.LocationType].EngineerManager:AddUnit(finishedUnit)
        elseif EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, finishedUnit ) then
            --RNGLOG('Factory Built by factory, attempting to kill factory.')
			if finishedUnit:GetFractionComplete() == 1 then
				self:AddFactory(finishedUnit )			
				factory.Dead = true
                factory.Trash:Destroy()
                --RNGLOG('Destroy Factory')
				return self:FactoryDestroyed(factory)
			end
        elseif EntityCategoryContains(categories.TRANSPORTFOCUS - categories.uea0203, finishedUnit ) then
            self.Brain.TransportRequested = nil
            finishedUnit:ForkThread( import('/lua/ai/transportutilities.lua').AssignTransportToPool, finishedUnit:GetAIBrain() )
            --if self.Brain.ZoneExpansionTransportRequested then
            --    finishedUnit:ForkThread( import('/lua/ai/transportutilities.lua').FindEngineerToTransport, finishedUnit:GetAIBrain() )
            --end
            if self.InitialTransportRequested and self.Brain.amanager.Demand.Air.T1.transport and self.Brain.amanager.Demand.Air.T1.transport > 0 then
                self.Brain.amanager.Demand.Air.T1.transport = 0
                factory:SetPaused(true)
                coroutine.yield(1)
                factory:SetPaused(false)
            end
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
        elseif finishedUnit.Blueprint.CategoriesHash.LAND then
            local unitStats = self.Brain.IntelManager.UnitStats
            local unitCat = finishedUnit.Blueprint.CategoriesHash
            local unitValue = finishedUnit.Blueprint.Economy.BuildCostMass or 0
            if ( unitCat.UEF or unitCat.CYBRAN ) and unitCat.BOT and unitCat.TECH2 and unitCat.DIRECTFIRE or unitCat.SNIPER and unitCat.TECH3 then
                unitStats['RangedBot'].Built.Mass = unitStats['RangedBot'].Built.Mass + unitValue
            end
        elseif finishedUnit.Blueprint.CategoriesHash.NAVAL then
            local unitStats = self.Brain.IntelManager.UnitStats
            local unitCat = finishedUnit.Blueprint.CategoriesHash
            local unitValue = finishedUnit.Blueprint.Economy.BuildCostMass or 0
            if unitCat.CRUISER then
                unitStats['Cruiser'].Built.Mass = unitStats['Cruiser'].Built.Mass + unitValue
            elseif unitCat.CARRIER then
                unitStats['Carrier'].Built.Mass = unitStats['Carrier'].Built.Mass + unitValue
            elseif unitCat.MISSILESHIP then
                unitStats['MissileShip'].Built.Mass = unitStats['MissileShip'].Built.Mass + unitValue
            elseif unitCat.NUKESUB then
                unitStats['NukeSub'].Built.Mass = unitStats['NukeSub'].Built.Mass + unitValue
            end
        end
        self:AssignBuildOrder(factory, factory.BuilderManagerData.BuilderType)
    end,

    -- Check if given factory can build the builder
    ---@param self FactoryBuilderManager
    ---@param builder Builder
    ---@param params FactoryUnit[]
    ---@return boolean
    BuilderParamCheck = function(self, builder, params)

        -- params[1] is factory, no other params
        local builderType = builder:GetFactoryBuilderType()
        if builderType and builderType == 'Category' then
            local buildCategory = builder:GetUnitCategory()
            local unitFaction = categories[params[1].Blueprint.FactionCategory]
            local unitIds = EntityCategoryGetUnitList(buildCategory * unitFaction)
            local unitIdCount = TableGetn(unitIds)
            if unitIdCount == 0 then
                return false
            end
            local unitId
            for k = 1, unitIdCount do
                local candidate = unitIds[k]
                if params[1]:CanBuild(candidate) then
                    unitId = candidate
                    break
                end
            end
            if unitId then
                return true
            end
            return false
        end
        local template = self:GetFactoryTemplate(builder:GetPlatoonTemplate(), params[1])
        if not template then
            WARN('*Factory Builder Error: Could not find template named: ' .. builder:GetPlatoonTemplate())
            return false
        end
        -- This faction doesn't have unit of this type
        if TableGetn(template) == 2 then
            return false
        end
        -- This function takes a table of factories to determine if it can build
        return self.Brain:CanBuildPlatoon(template, params)
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    DelayRallyPoint = function(self, factory)
        WaitSeconds(1)
        if not factory.Dead then
            self:SetRallyPoint(factory)
        end
    end,

    ---@param self FactoryBuilderManager
    ---@param factory Unit
    ---@return boolean
    SetRallyPoint = function(self, factory)
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
            rally = AIUtils.AIGetClosestMarkerLocationRNG(self, rallyType, position[1], position[3])
        elseif self.UseCenterPoint then
            -- use BuilderManager location
            rally = AIUtils.AIGetClosestMarkerLocationRNG(self, rallyType, position[1], position[3])
            local altRally
            if rallyType == 'Naval Rally Point' then
                altRally = RUtils.GetRallyPoint(self.Brain, 'Water', position, 20, 60)
            else
                altRally = RUtils.GetRallyPoint(self.Brain, 'Land', position, 20, 60)
            end
            if altRally and rally then
                local rallyPointDistance = VDist2(position[1], position[3], rally[1], rally[3])
                local zoneDistance = VDist2(position[1], position[3], altRally[1], altRally[3])

                if zoneDistance < rallyPointDistance then
                    rally = altRally
                end
            end
        end

        -- Use factory location if no other rally or if rally point is far away
        if not rally or VDist2(rally[1], rally[3], position[1], position[3]) > 75 then
            -- DUNCAN - added to try and vary the rally points.
            --RNGLOG('No Rally Point Found. Setting Point between me and enemy Location')
            local position = false
            --LOG('Spawn type is '..tostring(ScenarioInfo.Options.TeamSpawn))
            if ScenarioInfo.Options.TeamSpawn == 'fixed' and not RNGAIGLOBALS.CampaignMapFlag then
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
                                --LOG('Settng Air Rally Point')
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 60})
                                rally = position
                                --RNGLOG('Air Rally Position is :'..repr(position))
                                break
                            else
                                position = RUtils.lerpy(opponentStart, factoryPos, {startDistance, startDistance - 30})
                                rally = position
                                --RNGLOG('Rally Position is :'..repr(position))
                                break
                            end
                        end
                    end
                end
            else
                --LOG('No Rally Point Found. Setting Random Location')
                local locationType = self.LocationType
                local factoryPos = self.Brain.BuilderManagers[locationType].Position
                local startDistance = VDist3(self.Brain.MapCenterPoint, factoryPos)
                position = RUtils.lerpy(self.Brain.MapCenterPoint, factoryPos, {startDistance, startDistance - 60})
                --RNGLOG('Position '..repr(position))
            end
            if not rally then
                local locationPos = self.Location
                position = AIUtils.RandomLocation(locationPos[1],locationPos[3])
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
                    --LOG('*AI DEBUG: Replacement unit found!')
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
                else
                    for i=1, 6 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
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
                else
                    for i=1, 6 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
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
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    end
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
                end
            elseif mapSizeX >= 500 and mapSizeZ >= 500 then
                if EnemyIndex and self.Brain.CanPathToEnemyRNG[OwnIndex][EnemyIndex]['MAIN'] == 'LAND' then
                    for i=1, 2 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    if faction == 'SERAPHIM' then
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    end
                else
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    table.insert(queue, 'T1BuildEngineer')
                    table.insert(queue, 'T1BuildEngineer')
                end
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
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    else
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFBot')
                        table.insert(queue, 'T1LandScout')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1LandDFTank')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1BuildEngineer')
                        table.insert(queue, 'T1LandScout')
                    end
                    if self.Brain.StartReclaimCurrent > 500 then
                        for i=1, 2 do
                            table.insert(queue, 'T1BuildEngineer')
                        end
                    end
                else
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                    table.insert(queue, 'T1LandScout')
                    table.insert(queue, 'T1LandDFTank')
                    for i=1, 3 do
                        table.insert(queue, 'T1BuildEngineer')
                    end
                end
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
                }
            end
            return queue
        end
        return false
    end,
}

---@param brain AIBrain
---@param lType string
---@param location Vector
---@param radius number
---@param useCenterPoint boolean
---@return FactoryBuilderManager
function CreateFactoryBuilderManager(brain, lType, location, radius, useCenterPoint)
    local fbm = FactoryBuilderManager()
    fbm:Create(brain, lType, location, radius, useCenterPoint)
    return fbm
end

--- Moved Unsused Imports to bottome for mod support 
local AIBuildUnits = import("/lua/ai/aibuildunits.lua")