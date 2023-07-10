
local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local NavUtils = import("/lua/sim/navutils.lua")
local MarkerUtils = import("/lua/sim/markerutilities.lua")
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint

-- upvalue scope for performance
local Random = Random
local IsDestroyed = IsDestroyed

local TableGetn = table.getn
local TableEmpty = table.empty

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
            
            local maxRadius
            maxRadius = cdr.HealthPercent * 100
            if ScenarioInfo.Options.AICDRCombat == 'cdrcombatOff' then
                --RNGLOG('cdrcombat is off setting max radius to 60')
                maxRadius = 80
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
            -- reset state
            self.OpportunityToRaid = nil
            self.ThreatToEvade = nil

            -- sanity check
            local destination = self.LocationToRaid
            if not destination then
                self:LogWarning(string.format('no destination to navigate to'))
                self:ChangeState(self.Searching)
                return
            end

            self:Stop()

            local cache = { 0, 0, 0 }
            local brain = self:GetBrain()

            while not IsDestroyed(self) do
                -- pick random unit for a position on the grid
                local units, unitCount = self:GetPlatoonUnits()
                local origin = self:GetPlatoonPosition()

                -- generate a direction
                local waypoint, length = NavUtils.DirectionTo('Land', origin, destination, 60)

                -- something odd happened: no direction found
                if not waypoint then
                    self:LogWarning(string.format('no path found'))
                    self:ChangeState(self.Searching)
                    return
                end

                -- we're near the destination, better start raiding it!
                if waypoint == destination then
                    self:ChangeState(self.RaidingTarget)
                    return
                end

                -- navigate towards waypoint 
                local dx = origin[1] - waypoint[1]
                local dz = origin[3] - waypoint[3]
                local d = math.sqrt(dx * dx + dz * dz)
                self:IssueFormMoveToWaypoint(units, origin, waypoint)

                -- check for opportunities
                local wx = waypoint[1]
                local wz = waypoint[3]
                while not IsDestroyed(self) do
                    local position = self:GetPlatoonPosition()

                    -- check if we're near our current waypoint
                    local dx = position[1] - wx
                    local dz = position[3] - wz
                    if dx * dx + dz * dz < NavigateDistanceThresholdSquared then
                        break
                    end

                    -- check for threats
                    local threat = brain:GetThreatAtPosition(position, 1, true, 'AntiSurface')
                    if threat > 0 then
                        local threatTable = brain:GetThreatsAroundPosition(position, 1, true, 'AntiSurface')
                        if threatTable and not TableEmpty(threatTable) then
                            local info = threatTable[Random(1, TableGetn(threatTable))]
                            self.ThreatToEvade = { info[1], GetSurfaceHeight(info[1], info[2]), info[2] }
                            DrawCircle(self.ThreatToEvade, 5, 'ff0000')
                            self:ChangeState(self.Retreating)
                            return
                        end
                    end

                    -- check for opportunities
                    local oppertunity = brain:GetThreatAtPosition(position, 2, true, 'Economy')
                    if oppertunity > 0 then
                        local opportunities = brain:GetThreatsAroundPosition(position, 2, true, 'Economy')
                        if opportunities and not TableEmpty(opportunities) then
                            for k = 1, TableGetn(opportunities) do
                                local info = opportunities[k]
                                cache[1] = info[1]
                                cache[3] = info[2]

                                local threat = brain:GetThreatAtPosition(cache, 0, true, 'AntiSurface')
                                if threat == 0 then
                                    self.OpportunityToRaid = { info[1], GetSurfaceHeight(info[1], info[2]), info[2] }
                                    self:ChangeState(self.RaidingOpportunity)
                                    return
                                end
                            end
                        end
                    end

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
                    if TableGetn(assistList) > 0 then
                        break
                    end
                end
                if TableGetn(assistList) > 0 then
                    local engPos = eng:GetPosition()
                    -- only have one unit in the list; assist it
                    local low = false
                    local bestUnit = false
                    for _,v in assistList do
                        --DUNCAN - check unit is inside assist range 
                        local unitPos = v:GetPosition()
                        local UnitAssist = v.UnitBeingBuilt or v.UnitBeingAssist or v
                        local NumAssist = TableGetn(UnitAssist:GetGuards())
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
            if self.BuilderData.Construction then
                if self.BuilderData.Construction.BuildStructures then
                    eng.EngineerBuildQueue = {}
                    local factionIndex = brain:GetFactionIndex()
                    local templateKey
                    local baseTmplFile
                    if factionIndex < 5 then
                        templateKey = 'ACUBaseTemplate'
                        baseTmplFile = import(self.BuilderData.Construction.BaseTemplateFile or '/lua/BaseTemplates.lua')
                    else
                        templateKey = 'BaseTemplates'
                        baseTmplFile = import('/lua/BaseTemplates.lua')
                    end
                    local buildingTmplFile = import(self.BuilderData.Construction.BuildingTemplateFile or '/lua/BuildingTemplates.lua')
                    local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
                    local baseTmpl = baseTmplFile[(self.BuilderData.Construction.BaseTemplate or 'BaseTemplates')][factionIndex]
                    local buildStructures = self.BuilderData.Construction.BuildStructures
                    if self.BuilderData.Construction.OrderedTemplate then
                        local tmpReference = brain:FindPlaceToBuild('T2EnergyProduction', 'uab1201', baseTmplDefault['BaseTemplates'][factionIndex], relative, eng, nil, relativeTo[1], relativeTo[3])
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
                                                    if n > 1 and not aiBrain:CanBuildStructureAt(whatToBuild, BuildToNormalLocation(position)) then
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
                    if TableGetn(eng.EngineerBuildQueue) > 0 then
                        for _, v in eng.EngineerBuildQueue do
                            if v[3] and v[2] and v[1] then
                                IssueBuildMobile({eng}, {v[2][1],GetTerrainHeight(v[2][1], v[2][2]),v[2][2]}, v[1], {})
                            elseif v[2] and v[3] then
                                aiBrain:BuildStructure(eng, v[1], v[2], false)
                            end
                        end
                        while eng:IsUnitState('Building') or 0 < TableGetn(eng:GetCommandQueue()) do
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
            if cdr:IsUnitState('Attached') then
                 return false
            end
            --RNGLOG('CDRRetreatRNG has fired')
            local closestPlatoon = false
            local closestPlatoonDistance = false
            local closestAPlatPos = false
            local platoonValue = 0
            local distanceToHome = VDist3Sq(cdr.CDRHome, cdr.Position)
            --RNGLOG('Getting list of allied platoons close by')
            coroutine.yield( 2 )
            local supportPlatoon = aiBrain:GetPlatoonUniquelyNamed('ACUSupportPlatoon')
            if cdr.Health > 5000 and distanceToHome > 6400 and not base then
                if supportPlatoon then
                    closestPlatoon = supportPlatoon
                    closestAPlatPos = GetPlatoonPosition(supportPlatoon)
                    if closestAPlatPos then
                        closestPlatoonDistance = VDist3Sq(closestAPlatPos, cdr.Position)
                    end
                else
                    local AlliedPlatoons = aiBrain:GetPlatoonsList()
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
            if aiBrain.BuilderManagers then
                for baseName, base in aiBrain.BuilderManagers do
                --RNGLOG('Base Name '..baseName)
                --RNGLOG('Base Position '..repr(base.Position))
                --RNGLOG('Base Distance '..VDist2Sq(cdr.Position[1], cdr.Position[3], base.Position[1], base.Position[3]))
                    if TableGetn(base.FactoryManager.FactoryList) > 0 then
                        --RNGLOG('Retreat Expansion number of factories '..TableGetn(base.FactoryManager.FactoryList))
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
                    if NavUtils.CanPathTo('Amphibious', cdr.Position, aiBrain.BuilderManagers[closestBase].Position) then
                        --RNGLOG('Retreating to base')
                        cdr.Retreat = false
                        cdr.BaseLocation = true
                        CDRMoveToPosition(aiBrain, cdr, aiBrain.BuilderManagers[closestBase].Position, 625, true)
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
                        CDRMoveToPosition(aiBrain, cdr, closestAPlatPos, 400, true, true, closestPlatoon)
                        return
                    end
                end
            elseif closestBase then
                --RNGLOG('Closest base is '..closestBase)
                if NavUtils.CanPathTo('Amphibious', cdr.Position, aiBrain.BuilderManagers[closestBase].Position) then
                    --RNGLOG('Retreating to base')
                    cdr.Retreat = false
                    cdr.BaseLocation = true
                    CDRMoveToPosition(aiBrain, cdr, aiBrain.BuilderManagers[closestBase].Position, 625, true)
                end
            elseif closestPlatoon then
                --RNGLOG('Found platoon checking if can graph')
                if closestAPlatPos and NavUtils.CanPathTo('Amphibious', cdr.Position,closestAPlatPos) then
                    --RNGLOG('Retreating to platoon')
                    if closestPlatoonDistance then
                        --RNGLOG('Platoon distance from us is '..closestPlatoonDistance)
                    end
                    cdr.Retreat = false
                    CDRMoveToPosition(aiBrain, cdr, closestAPlatPos, 400, true, true, closestPlatoon)
                end
            else
                --RNGLOG('No platoon or base to retreat to')
            end


        end,
    },

    -----------------------------------------------------------------
    -- brain events

    ---@param self AIPlatoon
    ---@param units Unit[]
    OnUnitsAddedToSupportSquad = function(self, units)
        local cache = { false }
        local count = TableGetn(units)
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
