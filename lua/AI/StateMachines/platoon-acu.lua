
local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local NavUtils = import("/lua/sim/navutils.lua")
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt

-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local TableEmpty = table.empty
local RNGINSERT = table.insert
local RNGSORT = table.sort

-- constants
local NavigateDistanceThresholdSquared = 20 * 20

---@class AIPlatoonACUBehavior : AIPlatoon
---@field RetreatCount number 
---@field ThreatToEvade Vector | nil
---@field LocationToRaid Vector | nil
---@field OpportunityToRaid Vector | nil
AIPlatoonACUBehavior = Class(AIPlatoon) {

    PlatoonName = 'ACUBehavior',

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
            self.cdr = self:GetPlatoonUnits()[1]
            self.cdr.Active = true
            if self.PlatoonData.LocationType then
                self.LocationType = self.PlatoonData.LocationType
            else
                self.LocationType = 'MAIN'
            end
            --[[local newlyCapturedFunction = function(unit, captor)
                local aiBrain = captor:GetAIBrain()
                --LOG('*AI DEBUG: ENGINEER: I was Captured by '..aiBrain.Nickname..'!')
                if aiBrain.BuilderManagers then
                    local engManager = aiBrain.BuilderManagers[unit.PlatoonHandle.LocationType].EngineerManager
                    if engManager then
                        engManager:AddUnit(unit)
                    end
                end
            end
            import("/lua/scenariotriggers.lua").CreateUnitCapturedTrigger(nil, newlyCapturedFunction, self.cdr)

            local unitConstructionFinished = function(unit, finishedUnit)
                -- Call function on builder manager; let it handle the finish of work
                local aiBrain = unit:GetAIBrain()
                local engManager = aiBrain.BuilderManagers[unit.PlatoonHandle.LocationType].EngineerManager
                LOG('Unit Construction Finished for location '..unit.PlatoonHandle.LocationType)
                if engManager then
                    engManager:UnitConstructionFinished(unit, finishedUnit)
                end
            end
            import("/lua/scenariotriggers.lua").CreateUnitBuiltTrigger(unitConstructionFinished, self.cdr, categories.ALLUNITS)]]

            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        --- The platoon searches for a target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            -- reset state
            local brain = self:GetBrain()
            local cdr = self.cdr
            if self.BuilderData.Expansion then
                local alreadyHaveExpansion = false
                for k, manager in brain.BuilderManagers do
                --RNGLOG('Checking through expansion '..k)
                    if manager.FactoryManager.LocationActive and not table.empty(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                    --RNGLOG('We already have an expansion with a factory')
                        alreadyHaveExpansion = true
                        break
                    end
                end
                if not alreadyHaveExpansion then
                    self:ChangeState(self.Expand)
                    return
                else
                    self.BuilderData = {}
                end
            end
            local multiplier
            local maxRadius
            maxRadius = cdr.HealthPercent * 100
            if ScenarioInfo.Options.AICDRCombat == 'cdrcombatOff' then
                maxRadius = 80
            end
            if brain.CheatEnabled then
                multiplier = brain.EcoManager.EcoMultiplier
            else
                multiplier = 1
            end
            if ScenarioInfo.Options.AICDRCombat ~= 'cdrcombatOff' and brain.EnemyIntel.Phase < 3 then
                if (brain.EconomyOverTimeCurrent.MassIncome > (0.8 * multiplier) and brain.EconomyOverTimeCurrent.EnergyIncome > (12 * multiplier))
                    or (brain.EconomyOverTimeCurrent.EnergyTrendOverTime > 2.0 and brain.EconomyOverTimeCurrent.EnergyIncome > 18) then
                    local enemyAcuClose = false
                    for _, v in brain.EnemyIntel.ACU do
                        if (not v.Unit.Dead) and (not v.Ally) and v.OnField then
                            --RNGLOG('Non Ally and OnField')
                            if v.LastSpotted ~= 0 and (GetGameTimeSeconds() - 30) < v.LastSpotted and v.DistanceToBase < 22500 then
                                --RNGLOG('Enemy ACU seen within 30 seconds and is within 150 of our start position')
                                enemyAcuClose = true
                            end
                        end
                    end
                    if not enemyAcuClose then
                        local alreadyHaveExpansion = false
                        for k, manager in brain.BuilderManagers do
                        --RNGLOG('Checking through expansion '..k)
                            if manager.FactoryManager.LocationActive and next(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                            --RNGLOG('We already have an expansion with a factory')
                                alreadyHaveExpansion = true
                                break
                            end
                        end
                        if not alreadyHaveExpansion then
                            local BaseDMZArea = math.max( ScenarioInfo.size[1]-40, ScenarioInfo.size[2]-40 ) / 2
                            local stageExpansion = IntelManagerRNG.QueryExpansionTable(brain, cdr.Position, BaseDMZArea * 1.5, 'Land', 10, 'acu')
                            if stageExpansion then
                                self.BuilderData = {
                                    Expansion = true,
                                    Position = stageExpansion.Expansion.Position,
                                    ExpansionData = stageExpansion,
                                    CutOff = 15
                                    }
                                self:ChangeState(self.Navigating)
                                return
                            end
                        end
                    end
                end
            end
            if cdr.Health > 5000 and cdr.Phase < 3
                and brain.MapSize <= 10
                and cdr.Initialized
                then
                maxRadius = 512 - GetGameTimeSeconds()/60*6 -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
                brain.ACUSupport.ACUMaxSearchRadius = maxRadius
            elseif cdr.Health > 5000 and GetGameTimeSeconds() > 260 and cdr.Initialized then
                maxRadius = math.max((160 - GetGameTimeSeconds()/60*6), 100) -- reduce the radius by 6 map units per minute. After 30 minutes it's (240-180) = 60
                brain.ACUSupport.ACUMaxSearchRadius = maxRadius
            end
            if VDist2Sq(cdr.CDRHome[1], cdr.CDRHome[3], cdr.Position[1], cdr.Position[3]) > maxRadius * maxRadius then
                --RNGLOG('ACU is beyond maxRadius of '..maxRadius)
                self:ChangeState(self.Retreating)
                return
            end
            local numUnits = GetNumUnitsAroundPoint(brain, categories.LAND + categories.MASSEXTRACTION - categories.SCOUT, cdr.Position, (maxRadius), 'Enemy')
            if numUnits > 1 then
                local target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition
                cdr.Combat = true
                local acuDistanceToBase = VDist3Sq(cdr.Position, cdr.CDRHome)
                if not cdr.SuicideMode and acuDistanceToBase > cdr.MaxBaseRange * cdr.MaxBaseRange and (not cdr:IsUnitState('Building')) then
                    --RNGLOG('OverCharge running but ACU is beyond its MaxBaseRange property')
                    --RNGLOG('cdr retreating due to beyond max range and not building '..(cdr.MaxBaseRange * cdr.MaxBaseRange)..' current distance '..acuDistanceToBase)
                    self.BuilderData = {}
                    self:ChangeState(self.Retreating)
                    return
                end
                if not cdr.SuicideMode then
                    target, acuTarget, highThreatCount, closestThreatDistance, closestThreatUnit, closestUnitPosition = RUtils.AIAdvancedFindACUTargetRNG(brain)
                else
                    --RNGLOG('We are in suicide mode so dont look for a new target')
                end
                if not target and closestThreatDistance < 1600 and closestThreatUnit and not IsDestroyed(closestThreatUnit) then
                    --RNGLOG('No Target Found due to high threat, closestThreatDistance is below 1225 so we will attack that ')
                    target = closestThreatUnit
                end
                if target and not IsDestroyed(target) then
                    self:ChangeState(self.AttackTarget)
                    return
                else
                    --RNGLOG('CDR : No target found')
                    if not cdr.SuicideMode then
                        --RNGLOG('Total highThreatCount '..highThreatCount)
                        if cdr.Phase < 3 and not cdr.HighThreatUpgradePresent and closestThreatUnit and closestUnitPosition then
                            if not closestThreatUnit.Dead then
                                if GetThreatAtPosition(brain, closestUnitPosition, brain.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') > cdr.ThreatLimit * 1.3 and GetEconomyIncome(brain, 'ENERGY') > 80 then
                                    --RNGLOG('HighThreatUpgrade is now required')
                                    cdr.HighThreatUpgradeRequired = true
                                    self:ChangeState(self.EnhancementBuild)
                                    return
                                end
                            end
                        end
                        if not cdr.HighThreatUpgradeRequired and not cdr.GunUpgradeRequired then
                            CDRCheckForCloseMassPoints(brain, cdr)
                        end
                    end
                end
            end
            self:ChangeState(self.EngineerTask)
            return
        end,
    },

    Navigating = State {

        StateName = 'Navigating',

        --- The platoon navigates towards a target, picking up oppertunities as it finds them
        ---@param self AIPlatoonACUBehavior
        Main = function(self)

            -- sanity check
            local destination = self.BuilderData.Position
            if not destination then
                self:LogWarning(string.format('no destination to navigate to'))
                coroutine.yield(10)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            local brain = self:GetBrain()
            local cdr = self.cdr

            IssueClearCommands({cdr})

            local cache = { 0, 0, 0 }

            while not IsDestroyed(self) do
                -- pick random unit for a position on the grid
                local origin = cdr:GetPosition()

                -- generate a direction
                local waypoint, length = NavUtils.DirectionTo('Amphibious', origin, destination, 60)

                -- something odd happened: no direction found
                if not waypoint then
                    self:LogWarning(string.format('no path found'))
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end

                -- we're near the destination, better start raiding it!
                if waypoint == destination then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end

                -- navigate towards waypoint 
                IssueMove({cdr}, waypoint)

                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self) do
                    local position = cdr:GetPosition()

                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < NavigateDistanceThresholdSquared then
                        break
                    end

                    -- check for threats

                    WaitTicks(10)
                end

                -- always wait
                WaitTicks(1)
            end
        end,
    },

    EngineerTask = State {

        StateName = 'EngineerTask',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            if self.LocationType then
                local builderData
                local engManager = brain.BuilderManagers[self.LocationType].EngineerManager
                local builder = engManager:GetHighestBuilder('Any', {self.cdr})
                if builder then
                    builderData = builder:GetBuilderData(self.LocationType)
                    LOG('Builder Data '..repr(builderData))
                    if builderData.Assist then
                        self.BuilderData = builderData
                        self:ChangeState(self.AssistEngineers)
                        return
                    elseif builderData.Construction then
                        self.BuilderData = builderData
                        self:ChangeState(self.StructureBuild)
                        return
                    end
                end
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AssistEngineers = State {

        StateName = 'AssistEngineers',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local assistList
            local assistee = false
            local eng = self.cdr
            if self.BuilderData.Assist then
                for _, cat in self.BuilderData.Assist.BeingBuiltCategories do
                    assistList = RUtils.GetAssisteesRNG(brain, 'MAIN', categories.ENGINEER, cat, categories.ALLUNITS)
                    if not TableEmpty(assistList) then
                        break
                    end
                end
                if not TableEmpty(assistList) then
                    local engPos = eng:GetPosition()
                    -- only have one unit in the list; assist it
                    local low = false
                    local bestUnit = false
                    for _,v in assistList do
                        --DUNCAN - check unit is inside assist range 
                        local unitPos = v:GetPosition()
                        local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                        local NumAssist = RNGGETN(UnitAssist:GetGuards())
                        local dist = VDist2Sq(engPos[1], engPos[3], unitPos[1], unitPos[3])
                        -- Find the closest unit to assist
                        if (not low or dist < low) and NumAssist < 20 and dist < 1600 then
                            low = dist
                            bestUnit = v
                        end
                    end
                    assistee = bestUnit
                    if assistee  then
                        IssueClearCommands({eng})
                        eng.UnitBeingAssist = assistee.UnitBeingBuilt or assistee.UnitBeingAssist or assistee
                        --RNGLOG('* EconAssistBody: Assisting now: ['..eng.UnitBeingAssist:GetBlueprint().BlueprintId..'] ('..eng.UnitBeingAssist:GetBlueprint().Description..')')
                        IssueGuard({eng}, eng.UnitBeingAssist)
                        coroutine.yield(30)
                        while eng and not eng.Dead and not eng:IsIdleState() do
                            if not eng.UnitBeingAssist or eng.UnitBeingAssist.Dead or eng.UnitBeingAssist:BeenDestroyed() then
                                break
                            end
                            -- stop if our target is finished
                            if eng.UnitBeingAssist:GetFractionComplete() == 1 and not eng.UnitBeingAssist:IsUnitState('Upgrading') then
                                IssueClearCommands({eng})
                                break
                            end
                            coroutine.yield(30)
                        end
                    end
                end
            end
            self.BuilderData = nil
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    StructureBuild = State {

        StateName = 'StructureBuild',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local eng = self.cdr
            local engPos = eng:GetPosition()
            if self.BuilderData.Construction then
                if self.BuilderData.Construction.BuildStructures then
                    eng.EngineerBuildQueue = {}
                    local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(eng)
                    local templateKey
                    local baseTmplFile
                    local relative = false
                    if factionIndex < 5 then
                        if self.BuilderData.Construction.BaseTemplateFile and self.BuilderData.Construction.BaseTemplate then
                            templateKey = self.BuilderData.Construction.BaseTemplate
                            baseTmplFile = import(self.BuilderData.Construction.BaseTemplateFile or '/lua/BaseTemplates.lua')
                        else
                            templateKey = 'BaseTemplates'
                            baseTmplFile = import('/lua/BaseTemplates.lua')
                        end
                    else
                        templateKey = 'BaseTemplates'
                        baseTmplFile = import('/lua/BaseTemplates.lua')
                    end
                    local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
                    local baseTmpl = baseTmplFile[(self.BuilderData.Construction.BaseTemplate or 'BaseTemplates')][factionIndex]
                    local buildStructures = self.BuilderData.Construction.BuildStructures
                    if self.BuilderData.Construction.OrderedTemplate then
                        local tmpReference = brain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplFile[templateKey][factionIndex], relative, eng, nil, engPos[1], engPos[3])
                        local reference
                        if tmpReference then
                            reference = eng:CalculateWorldPositionFromRelative(tmpReference)
                        else
                            return
                        end
                        local baseTmplList = RUtils.AIBuildBaseTemplateFromLocationRNG(baseTmpl, reference)
                        for j, template in baseTmplList do
                            for _, v in buildStructures do
                                for l,bType in template do
                                    for m,bString in bType[1] do
                                        if bString == v then
                                            for n,position in bType do
                                                if n > 1 then
                                                    if brain.CustomUnits and brain.CustomUnits[v] then
                                                        local faction = RUtils.GetEngineerFactionRNG(eng)
                                                        buildingTmpl = RUtils.GetTemplateReplacementRNG(brain, v, faction, buildingTmpl)
                                                    end
                                                    local whatToBuild = brain:DecideWhatToBuild(eng, v, buildingTmpl)
                                                    table.insert(eng.EngineerBuildQueue, {whatToBuild, position, false})
                                                    table.remove(bType,n)
                                                    return --DoHackyLogic(buildingType, builder)
                                                else
                                                    --[[
                                                    if n > 1 and not brain:CanBuildStructureAt(whatToBuild, BuildToNormalLocation(position)) then
                                                        RNGLOG('CanBuildStructureAt failed within Ordered Template Build')
                                                    end]]
                                                    
                                                end
                                            end 
                                            break
                                        end 
                                    end 
                                end
                            end
                        end
                    else
                        for _, v in buildStructures do
                            local buildLocation, whatToBuild, borderWarning = RUtils.GetBuildLocationRNG(brain, buildingTmpl, baseTmplFile[templateKey][factionIndex], v, eng, false, nil, nil, true)
                            if buildLocation and whatToBuild then
                                table.insert(eng.EngineerBuildQueue, {whatToBuild, buildLocation, borderWarning})
                            else
                                LOG('No buildLocation or whatToBuild for ACU State Machine')
                            end
                        end
                    end
                    if not TableEmpty(eng.EngineerBuildQueue) then
                        for _, v in eng.EngineerBuildQueue do
                            if v[3] and v[2] and v[1] then
                                IssueBuildMobile({eng}, {v[2][1],GetTerrainHeight(v[2][1], v[2][2]),v[2][2]}, v[1], {})
                            elseif v[2] and v[1] then
                                brain:BuildStructure(eng, v[1], v[2], false)
                            end
                        end
                        while eng:IsUnitState('Building') or 0 < RNGGETN(eng:GetCommandQueue()) do
                            coroutine.yield(5)
                        end
                    end
                end
            end
            self.BuilderData = nil      
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    AttackTarget = State {

        StateName = 'AttackTarget',

        --- The platoon raids the target
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Retreating = State {

        StateName = "Retreating",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local cdr = self.cdr
            if cdr:IsUnitState('Attached') then
                 return false
            end
            --RNGLOG('CDRRetreatRNG has fired')
            local brain = self:GetBrain()
            local closestPlatoon = false
            local closestPlatoonDistance = false
            local closestAPlatPos = false
            local platoonValue = 0
            local base
            local distanceToHome = VDist3Sq(cdr.CDRHome, cdr.Position)
            --RNGLOG('Getting list of allied platoons close by')
            coroutine.yield( 2 )
            if distanceToHome > brain.ACUSupport.ACUMaxSearchRadius then
                base = true
            end
            local supportPlatoon = brain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
            if cdr.Health > 5000 and distanceToHome > 6400 and not base then
                if supportPlatoon then
                    closestPlatoon = supportPlatoon
                    closestAPlatPos = GetPlatoonPosition(supportPlatoon)
                    if closestAPlatPos then
                        closestPlatoonDistance = VDist3Sq(closestAPlatPos, cdr.Position)
                    end
                else
                    local AlliedPlatoons = brain:GetPlatoonsList()
                    for _,aPlat in AlliedPlatoons do
                        if aPlat.PlanName == 'MassRaidRNG' or aPlat.PlanName == 'HuntAIPATHRNG' or aPlat.PlanName == 'TruePlatoonRNG' or aPlat.PlanName == 'GuardMarkerRNG' or aPlat.PlanName == 'ACUSupportRNG' or aPlat.PlanName == 'ZoneControlRNG' then 
                            --RNGLOG('Allied platoon name '..aPlat.PlanName)
                            if aPlat.UsingTransport then 
                                continue 
                            end

                            if not aPlat.MovementLayer then 
                                AIAttackUtils.GetMostRestrictiveLayerRNG(aPlat) 
                            end

                            -- make sure we're the same movement layer type to avoid hamstringing air of amphibious
                            if aPlat.MovementLayer == 'Land' or aPlat.MovementLayer == 'Amphibious' then
                                local aPlatPos = GetPlatoonPosition(aPlat)
                                local aPlatDistance = VDist2Sq(cdr.Position[1],cdr.Position[3],aPlatPos[1],aPlatPos[3])
                                local aPlatToHomeDistance = VDist2Sq(aPlatPos[1],aPlatPos[3],cdr.CDRHome[1],cdr.CDRHome[3])
                                if aPlatDistance > 1600 and aPlatToHomeDistance < distanceToHome then
                                    local threat = aPlat:CalculatePlatoonThreat('Surface', categories.ALLUNITS)
                                    local platoonValue = aPlatDistance * aPlatDistance / threat
                                    if not closestPlatoonDistance then
                                        closestPlatoonDistance = platoonValue
                                    end
                                    --RNGLOG('Platoon Distance '..aPlatDistance)
                                    --RNGLOG('Weighting is '..platoonValue)
                                    if platoonValue <= closestPlatoonDistance then
                                        closestPlatoon = aPlat
                                        closestPlatoonDistance = platoonValue
                                        closestAPlatPos = aPlatPos
                                    end
                                end
                            end
                        end
                    end
                end
            end
            --RNGLOG('No platoon found, trying for base')
            local closestBase = false
            local closestBaseDistance = false
            if brain.BuilderManagers then
                for baseName, base in brain.BuilderManagers do
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                    if RNGGETN(base.FactoryManager.FactoryList) > 0 then
                        --RNGLOG('Retreat Expansion number of factories '..RNGGETN(base.FactoryManager.FactoryList))
                        local baseDistance = VDist3Sq(cdr.Position, base.Position)
                        local homeDistance = VDist3Sq(cdr.CDRHome, base.Position)
                        if homeDistance < distanceToHome and baseDistance > 1225 or (cdr.GunUpgradeRequired and not cdr.Caution) or (cdr.HighThreatUpgradeRequired and not cdr.Caution) or baseName == 'MAIN' then
                            if not closestBaseDistance then
                                closestBaseDistance = baseDistance
                            end
                            if baseDistance <= closestBaseDistance then
                                closestBase = baseName
                                closestBaseDistance = baseDistance
                            end
                        end
                    end
                end
                if cdr.Caution then
                    --RNGLOG('CDR is in caution when retreating')
                end
                --RNGLOG('ClosestDistance is '..closestBaseDistance)
                --RNGLOG('ClosestBase is '..closestBase)
            end
            if closestBase and closestPlatoon then
                if closestBaseDistance < closestPlatoonDistance then
                    --RNGLOG('Closest base is '..closestBase)
                    if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                        --RNGLOG('Retreating to base')
                        cdr.Retreat = false
                        cdr.BaseLocation = true
                        self.BuilderData = {
                            Position = brain.BuilderManagers[closestBase].Position,
                            CutOff = 625
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                else
                    --RNGLOG('Found platoon checking if can graph')
                    if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                        --RNGLOG('Retreating to platoon')
                        if closestBaseDistance then
                            --RNGLOG('Platoon distance from us is '..closestBaseDistance)
                        end
                        cdr.Retreat = false
                        self.BuilderData = {
                            Position = closestAPlatPos,
                            CutOff = 400
                        }
                        self:ChangeState(self.Navigating)
                        return
                    end
                end
            elseif closestBase then
                --RNGLOG('Closest base is '..closestBase)
                if NavUtils.CanPathTo('Amphibious', cdr.Position, brain.BuilderManagers[closestBase].Position) then
                    --RNGLOG('Retreating to base')
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    self.BuilderData = {
                        Position = brain.BuilderManagers[closestBase].Position,
                        CutOff = 625
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            elseif closestPlatoon then
                --RNGLOG('Found platoon checking if can graph')
                if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                    --RNGLOG('Retreating to platoon')
                    if closestPlatoonDistance then
                        --RNGLOG('Platoon distance from us is '..closestPlatoonDistance)
                    end
                    cdr.Retreat = false
                    self.BuilderData = {
                        Position = closestAPlatPos,
                        CutOff = 400
                    }
                    self:ChangeState(self.Navigating)
                    return
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    Expand = State {
        StateName = "Expand",

        --- The platoon retreats from a threat
        ---@param self AIPlatoonACUBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local cdr = self.cdr
            local acuPos = cdr:GetPosition()
            local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
            local factionIndex = ACUFunc.GetEngineerFactionIndexRNG(cdr)
            local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
            local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1Resource', buildingTmpl)
            --LOG('ACU Looping through markers')
            local massMarkerCount = 0
            local adaptiveResourceMarkers = GetMarkersRNG()
            local MassMarker = {}
            cdr.EngineerBuildQueue = {}
            local object = self.BuilderData.ExpansionData
            LOG('Object '..repr(object))
            if object then
                for _, v in adaptiveResourceMarkers do
                    if v.type == 'Mass' then
                        RNGINSERT(MassMarker, {Position = v.position, Distance = VDist3Sq( v.position, object.Expansion.Position ) })
                    end
                end
                RNGSORT(MassMarker, function(a,b) return a.Distance < b.Distance end)
                --LOG('ACU MassMarker table sorted, looking for markers to build')
                for _, v in MassMarker do
                    if v.Distance < 900 and NavUtils.CanPathTo('Amphibious', acuPos, v.Position) and CanBuildStructureAt(brain, 'ueb1103', v.Position) then
                        --LOG('ACU Adding entry to BuildQueue')
                        massMarkerCount = massMarkerCount + 1
                        local newEntry = {whatToBuild, {v.Position[1], v.Position[3], 0}, false, Position=v.Position}
                        RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                    end
                end
                --LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                if RNGGETN(cdr.EngineerBuildQueue) > 0 then
                    for k,v in cdr.EngineerBuildQueue do
                        --LOG('Attempt to build queue item of '..repr(v))
                        while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                            IssueClearCommands({cdr})
                            IssueMove({cdr},v.Position)
                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                IssueClearCommands({cdr})
                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                --LOG('ACU attempting to build in while loop')
                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                    coroutine.yield(10)
                                    if cdr.Caution then
                                        break
                                    end
                                end
                            --LOG('Build Queue item should be finished '..k)
                                cdr.EngineerBuildQueue[k] = nil
                                break
                            end
                            if cdr.Caution then
                                break
                            end

                        --LOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                            coroutine.yield(10)
                        end
                    end
                    cdr.initialized=true
                end
                if RUtils.GrabPosDangerRNG(brain,cdr.Position, 40).enemy > 20 then
                    --LOG('Too dangerous after building extractors, returning')
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                --LOG('Mass markers should be built unless they are already taken')
                cdr.EngineerBuildQueue={}
                if object.Expansion.MassPoints > 1 then
                    --RNGLOG('ACU Object has more than 1 mass points and is called '..object.Expansion.Name)
                    local alreadyHaveExpansion = false
                    for k, manager in brain.BuilderManagers do
                    --RNGLOG('Checking through expansion '..k)
                        if manager.FactoryManager.LocationActive and next(manager.FactoryManager.FactoryList) and k ~= 'MAIN' then
                        --RNGLOG('We already have an expansion with a factory')
                            alreadyHaveExpansion = true
                            break
                        end
                    end
                    if not alreadyHaveExpansion then
                        if not brain.BuilderManagers[object.Expansion.Name] then
                        --RNGLOG('There is no manager at this expansion, creating builder manager')
                            brain:AddBuilderManagers(object.Expansion.Position, 60, object.Expansion.Name, true)
                            local baseValues = {}
                            local highPri = false
                            local markerType = false
                            local abortBuild = false
                            if object.Expansion.Type == 'Blank Marker' then
                                markerType = 'Start Location'
                            else
                                markerType = object.Expansion.Type
                            end

                            for templateName, baseData in BaseBuilderTemplates do
                                local baseValue = baseData.ExpansionFunction(brain, object.Expansion.Position, markerType)
                                RNGINSERT(baseValues, { Base = templateName, Value = baseValue })
                                --SPEW('*AI DEBUG: AINewExpansionBase(): Scann next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                if not highPri or baseValue > highPri then
                                    --SPEW('*AI DEBUG: AINewExpansionBase(): Possible next Base. baseValue= ' .. repr(baseValue) .. ' ('..repr(templateName)..')')
                                    highPri = baseValue
                                end
                            end
                            -- Random to get any picks of same value
                            local validNames = {}
                            for k,v in baseValues do
                                if v.Value == highPri then
                                    RNGINSERT(validNames, v.Base)
                                end
                            end
                            --SPEW('*AI DEBUG: AINewExpansionBase(): validNames for Expansions ' .. repr(validNames))
                            local pick = validNames[ Random(1, RNGGETN(validNames)) ]
                            cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                            --RNGLOG('Adding CDR to expansion manager')
                            brain.BuilderManagers[object.Expansion.Name].EngineerManager:AddUnitRNG(cdr, true)
                            --SPEW('*AI DEBUG: AINewExpansionBase(): ARMY ' .. brain:GetArmyIndex() .. ': Expanding using - ' .. pick .. ' at location ' .. baseName)
                            import('/lua/ai/AIAddBuilderTable.lua').AddGlobalBaseTemplate(brain, object.Expansion.Name, pick)

                            -- The actual factory building part
                            local baseTmplDefault = import('/lua/BaseTemplates.lua')
                            local factoryCount = 0
                            if object.Expansion.MassPoints > 2 then
                                factoryCount = 2
                            elseif object.Expansion.MassPoints > 1 then
                                factoryCount = 1
                            end
                            for i=1, factoryCount do
                                if i == 2 and brain.EconomyOverTimeCurrent.MassEfficiencyOverTime < 0.85 then
                                    break
                                end
                                
                                local whatToBuild = brain:DecideWhatToBuild(cdr, 'T1LandFactory', buildingTmpl)
                                if CanBuildStructureAt(brain, whatToBuild, object.Expansion.Position) then
                                    local newEntry = {whatToBuild, {object.Expansion.Position[1], object.Expansion.Position[3], 0}, false, Position=object.Expansion.Position}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                else
                                    local location = brain:FindPlaceToBuild('T1LandFactory', whatToBuild, baseTmplDefault['BaseTemplates'][factionIndex], true, cdr, nil, object.Expansion.Position[1], object.Expansion.Position[3])
                                    LOG('Findplacetobuild location '..repr(location))
                                    local relativeLoc = {location[1], 0, location[2]}
                                    LOG('Current CDR position '..repr(cdr.Position))
                                    relativeLoc = {relativeLoc[1] + cdr.Position[1], relativeLoc[2] + cdr.Position[2], relativeLoc[3] + cdr.Position[3]}
                                    LOG('Findplacetobuild relative location '..repr(relativeLoc))
                                    local newEntry = {whatToBuild, {relativeLoc[1], relativeLoc[3], 0}, false, Position=relativeLoc}
                                    RNGINSERT(cdr.EngineerBuildQueue, newEntry)
                                end
                                LOG('ACU Build Queue is '..repr(cdr.EngineerBuildQueue))
                                if RNGGETN(cdr.EngineerBuildQueue) > 0 then
                                    for k,v in cdr.EngineerBuildQueue do
                                        LOG('Attempt to build queue item of '..repr(v))
                                        if abortBuild then
                                            cdr.EngineerBuildQueue[k] = nil
                                            break
                                        end
                                        while not cdr.Dead and RNGGETN(cdr.EngineerBuildQueue) > 0 do
                                            IssueClearCommands({cdr})
                                            IssueMove({cdr},v.Position)
                                            if VDist3Sq(cdr:GetPosition(),v.Position) < 144 then
                                                IssueClearCommands({cdr})
                                                RUtils.EngineerTryReclaimCaptureArea(brain, cdr, v.Position, 5)
                                                RUtils.EngineerTryRepair(brain, cdr, v[1], v.Position)
                                                LOG('ACU attempting to build in while loop of type '..repr(v[1]))
                                                brain:BuildStructure(cdr, v[1],v[2],v[3])
                                                while (cdr.Active and not cdr.Dead and 0<RNGGETN(cdr:GetCommandQueue())) or (cdr.Active and cdr:IsUnitState('Building')) or (cdr.Active and cdr:IsUnitState("Moving")) do
                                                    coroutine.yield(10)
                                                    if cdr.Caution then
                                                        break
                                                    end
                                                    if cdr.EnemyCDRPresent and cdr.UnitBeingBuilt then
                                                        if GetNumUnitsAroundPoint(brain, categories.COMMAND, cdr.Position, 25, 'Enemy') > 0 and cdr.UnitBeingBuilt:GetFractionComplete() < 0.5 then
                                                            abortBuild = true
                                                            cdr.EngineerBuildQueue[k] = nil
                                                            break
                                                        end
                                                    end
                                                end
                                            --RNGLOG('Build Queue item should be finished '..k)
                                                cdr.EngineerBuildQueue[k] = nil
                                                break
                                            end
                                        --RNGLOG('Current Build Queue is '..RNGGETN(cdr.EngineerBuildQueue))
                                            coroutine.yield(10)
                                        end
                                    end
                                end
                            end
                            cdr.EngineerBuildQueue={}
                            cdr.BuilderManagerData.EngineerManager:RemoveUnitRNG(cdr)
                            --RNGLOG('Adding CDR back to MAIN manager')
                            brain.BuilderManagers['MAIN'].EngineerManager:AddUnitRNG(cdr, true)
                        elseif brain.BuilderManagers[object.Expansion.Name].FactoryManager:GetNumFactories() == 0 then
                        --RNGLOG('There is a manager here but no factories')
                        end
                    end
                end
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,

    },

    -----------------------------------------------------------------
    -- brain events

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToSupportSquad = function(self, units)
        local cache = { false }
        local count = RNGGETN(units)
        local brain = self:GetBrain()

        if count > 0 then
            local supportUnits = self:GetSquadUnits('Support')
            if supportUnits then
                for _, unit in supportUnits do
                    cache[1] = unit
                    brain:CDRDataThreads(unit)
                end
            end
        end
    end,

}

---@param data { Behavior: 'AIBehaviorACUSimple' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not TableEmpty(units) then
        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonACUBehavior)
        local squadUnits = platoon:GetSquadUnits('Support')
        if squadUnits then
            for _, unit in squadUnits do
                IssueClearCommands(unit)
            end
        end

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end
