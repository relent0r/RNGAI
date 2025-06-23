
local AIDefaultPlansList = import("/lua/aibrainplans.lua").AIPlansList
local AIUtils = import("/lua/ai/aiutilities.lua")
local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local RNGEventCallbacks = import('/mods/RNGAI/lua/AI/RNGEventCallbacks.lua')   
local RNGChat = import("/mods/RNGAI/lua/AI/RNGChat.lua")

local Utilities = import("/lua/utilities.lua")
local ScenarioUtils = import("/lua/sim/scenarioutilities.lua")
local Behaviors = import("/lua/ai/aibehaviors.lua")
local AIBuildUnits = import("/lua/ai/aibuildunits.lua")

local FactoryManager = import("/mods/RNGAI/lua/ai/BuilderFramework/factorybuildermanager.lua")
local PlatoonFormManager = import("/mods/RNGAI/lua/AI/BuilderFramework/platoonformmanager.lua")
local BrainConditionsMonitor = import("/lua/sim/brainconditionsmonitor.lua")
local EngineerManager = import("/mods/RNGAI/lua/AI/BuilderFramework/engineermanager.lua")

local SUtils = import("/lua/ai/sorianutilities.lua")
local TransferUnitsOwnership = import("/lua/simutils.lua").TransferUnitsOwnership
local TransferUnfinishedUnitsAfterDeath = import("/lua/simutils.lua").TransferUnfinishedUnitsAfterDeath
local CalculateBrainScore = import("/lua/sim/score.lua").CalculateBrainScore
local Factions = import('/lua/factions.lua').GetFactions(true)

-- upvalue for performance
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local CategoriesDummyUnit = categories.DUMMYUNIT
local CoroutineYield = coroutine.yield

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local IntelManagerRNG = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua')
local StructureManagerRNG = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua')
local Mapping = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua')
local MAP = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetMap()
local GetMarkersRNG = import("/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua").GetMarkersRNG
local DebugArrayRNG = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').DebugArrayRNG
local AIUtils = import('/lua/ai/AIUtilities.lua')
local NavUtils = import('/lua/sim/NavUtils.lua')
local MarkerUtils = import("/lua/sim/MarkerUtilities.lua")
local AIBehaviors = import('/lua/ai/AIBehaviors.lua')
local PlatoonGenerateSafePathToRNG = import('/lua/AI/aiattackutilities.lua').PlatoonGenerateSafePathToRNG
local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local GetCurrentUnits = moho.aibrain_methods.GetCurrentUnits
local GetThreatAtPosition = moho.aibrain_methods.GetThreatAtPosition
local GetThreatsAroundPosition = moho.aibrain_methods.GetThreatsAroundPosition
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local CanBuildStructureAt = moho.aibrain_methods.CanBuildStructureAt
local GetConsumptionPerSecondMass = moho.unit_methods.GetConsumptionPerSecondMass
local GetConsumptionPerSecondEnergy = moho.unit_methods.GetConsumptionPerSecondEnergy
local GetProductionPerSecondMass = moho.unit_methods.GetProductionPerSecondMass
local GetProductionPerSecondEnergy = moho.unit_methods.GetProductionPerSecondEnergy
local VDist2Sq = VDist2Sq
local GetEconomyTrend = moho.aibrain_methods.GetEconomyTrend
local GetEconomyStoredRatio = moho.aibrain_methods.GetEconomyStoredRatio
local RNGINSERT = table.insert
local RNGGETN = table.getn
local RNGTableEmpty = table.empty
local RNGLOG = import('/mods/RNGAI/lua/AI/RNGDebug.lua').RNGLOG
local StandardBrain = import("/lua/aibrain.lua").AIBrain

local RNGAIBrainClass = import("/lua/aibrains/base-ai.lua").AIBrain
AIBrain = Class(RNGAIBrainClass) {

    --- Called after `BeginSession`, at this point all props, resources and initial units exist in the map
    ---@param self AIBrainAdaptive
    OnBeginSession = function(self)
        StandardBrain.OnBeginSession(self)
        if not(ScenarioInfo.type == "skirmish") then
            RNGAIGLOBALS.CampaignMapFlag = true
        end

        -- requires navigational mesh
        import("/lua/sim/NavUtils.lua").Generate()

        -- requires these markers to exist
        if not RNGAIGLOBALS.CampaignMapFlag then
            import("/lua/sim/MarkerUtilities.lua").GenerateExpansionMarkers()
            import("/lua/sim/markerutilities.lua").GenerateNavalAreaMarkers()
        end
        --import("/lua/sim/MarkerUtilities.lua").GenerateRallyPointMarkers()

        -- requires these datastructures to understand the game
        
        self.GridReclaim = import("/lua/ai/gridreclaim.lua").Setup(self)
        self.GridBrain = import("/lua/ai/gridbrain.lua").Setup()
        self.GridDeposits = import("/lua/ai/griddeposits.lua").Setup()
        --self.GridRecon = import("/lua/ai/gridrecon.lua").Setup(self)
        self.GridPresence = import("/lua/AI/GridPresence.lua").Setup(self)
    end,

    OnCreateAI = function(self, planName)
        LOG('Oncreate AI from RNG')
        StandardBrain.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        if string.find(per, 'RNG') then
            self.RNG = true
            self.RNGDEBUG = false
            RNGAIGLOBALS.RNGAIPresent = true
            ForkThread(RUtils.AIWarningChecks, self)
        end
        if string.find(per, 'RNGStandardExperimental') then
            self.RNGEXP = true
            self.RNGDEBUG = false
        end
        local civilian = false
        for name, data in ScenarioInfo.ArmySetup do
            if name == self.Name then
                civilian = data.Civilian
                break
            end
        end

        if not civilian then
            -- Flag this brain as a possible brain to have skirmish systems enabled on
            self.SkirmishSystems = true
            local cheatPos = string.find(per, 'cheat')
            if cheatPos then
                AIUtils.SetupCheat(self, true)
                ScenarioInfo.ArmySetup[self.Name].AIPersonality = string.sub(per, 1, cheatPos - 1)
            end

            self.CurrentPlan = self.AIPlansList[self:GetFactionIndex()][1]
            self:ForkThread(self.InitialAIThread)

            self.PlatoonNameCounter = {}
            self.PlatoonNameCounter['AttackForce'] = 0
            self.BaseTemplates = {}
            self.RepeatExecution = true
            self.IntelData = {
                ScoutCounter = 0,
            }

            -- Flag enemy starting locations with threat?
            if ScenarioInfo.type == 'skirmish' then
                self:AddInitialEnemyThreatRNG(200, 0.005)
            end
        end

        self.UnitBuiltTriggerList = {}
        self.FactoryAssistList = {}
        self.DelayEqualBuildPlattons = {}
    end,

    ---@param self BaseAIBrain
    InitialAIThread = function(self)
        -- delay the AI so it can't reclaim the start area before it's cleared from the ACU landing blast.
        WaitTicks(30)
        self:ExecuteInitialAIBaseSetup()
    end,

    ---@param self AIBrain
    ExecuteInitialAIBaseSetup = function(self)
        local AIAddBuilderTable = import('/mods/RNGAI/lua/ai/aiaddbuildertable.lua')
        local base = false
        local returnVal = 0
        local aiType = false
    
        for k,v in BaseBuilderTemplates do
            if v.FirstBaseFunction then
                local baseVal, baseType = v.FirstBaseFunction(self)
                -- LOG('*DEBUG: testing ' .. k .. ' - Val ' .. baseVal)
                if baseVal > returnVal then
                    returnVal = baseVal
                    base = k
                    aiType = baseType
                end
            end
        end
        if base then
            WaitSeconds(1)
            if not self.BuilderManagers.MAIN.FactoryManager:HasBuilderList() then
                self:SetResourceSharing(true)
                ScenarioInfo.ArmySetup[self.Name].AIBase = base
                ScenarioInfo.ArmySetup[self.Name].AIPersonality = aiType
                LOG('*AI DEBUG: ARMY ', tostring(self:GetArmyIndex()), ': Initiating Archetype using ' .. base)
                AIAddBuilderTable.AddGlobalBaseTemplate(self, 'MAIN', base)
                self:ForceManagerSort()
        
                -- Get units out of pool and assign them to the managers
                local mainManagers = self.BuilderManagers.MAIN
                local pool = self:GetPlatoonUniquelyNamed('ArmyPool')
                for k,v in pool:GetPlatoonUnits() do
                    if EntityCategoryContains(categories.ENGINEER, v) then
                        mainManagers.EngineerManager:AddUnit(v)
                    elseif EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, v) then
                        mainManagers.FactoryManager:AddFactory(v)
                    end
                end
                self:ForkThread(self.UnitCapWatchThread)
            end
            if self.PBM then
                self:PBMSetEnabled(false)
            end
        end
    end,

    --- Modeled after GPGs LowMass and LowEnergy functions.
    --- Runs the whole game and kills off units when the AI hits unit cap.
    ---@param self AIBrain
    UnitCapWatchThread = function(self)
        local function GetFromNested(table, paths)
            local total = 0
            for _, path in ipairs(paths) do
                local current = table
                local validPath = true
                for _, key in ipairs(path) do
                    if current[key] == nil then
                        validPath = false
                        break
                    end
                    current = current[key]
                end
                -- If the path is valid, add the final value (or 0 if nil)
                if validPath then
                    total = total + (current or 0)
                else
                    LOG('*AI DEBUG: Invalid Path passed to GetFromNested '..tostring(repr(path)))
                    total = total + 0
                end
            end
            return total
        end

        local cullTable = {
            Walls = {
                categories = categories.WALL * categories.STRUCTURE * categories.DEFENSE,
                compare = false,
                compareType = 'getunits',
                cullRatio = 0.3,
                checkAttached = false
            },
            T1LandScouts = {
                categories = categories.MOBILE * categories.TECH1 * categories.SCOUT * categories.LAND,
                compare = false,
                compareType = 'amanager',
                compareFrom = {{'Land', 'T1', 'scout'}},
                cullRatio = 0.3,
                checkAttached = true
            },
            T1AirScouts = {
                categories = categories.MOBILE * categories.TECH1 * categories.SCOUT * categories.AIR,
                compare = false,
                compareType = 'amanager',
                compareFrom = {{'Air', 'T1', 'scout'}},
                cullRatio = 0.3,
                checkAttached = true
            },
            T1AirAntiAir = {
                categories = categories.AIR * categories.TECH1 * categories.ANTIAIR * categories.MOBILE,
                compare = true,
                compareType = 'amanager',
                compareFrom = {{'Air', 'T1', 'interceptor'}},
                compareTo = {{'Air', 'T3', 'asf'}, {'Air', 'T2', 'fighter'}},
                cullRatio = 0.2,
                checkAttached = true
            },
            T1LandTanks = {
                categories = categories.MOBILE * categories.TECH1 * categories.LAND * categories.DIRECTFIRE - categories.ANTIAIR,
                compare = false,
                compareType = 'amanager',
                compareFrom = {{'Land', 'T1', 'tank'}},
                cullRatio = 0.3,
                checkAttached = true
            },
            T1LandArtillery = {
                categories = categories.MOBILE * categories.TECH1 * categories.LAND * categories.INDIRECTFIRE - categories.ANTIAIR,
                compare = false,
                compareType = 'amanager',
                compareFrom = {{'Land', 'T1', 'arty'}},
                cullRatio = 0.3,
                checkAttached = true
            },
            T1LandAA = {
                categories = categories.MOBILE * categories.TECH1 * categories.LAND * categories.ANTIAIR,
                compare = false,
                compareType = 'amanager',
                compareFrom = {{'Land', 'T1', 'aa'}},
                cullRatio = 0.3,
                checkAttached = true
            },
            T1LandEngineer = {
                categories = categories.MOBILE * categories.TECH1 * categories.LAND * categories.ENGINEER - categories.COMMAND,
                compare = true,
                compareType = 'amanager',
                compareFrom = {{'Engineer', 'T1', 'engineer'}},
                compareTo = {{'Engineer', 'T2', 'engineer'},{'Engineer', 'T3', 'engineer'}},
                cullRatio = 0.3,
                checkAttached = true,
                checkEngineer = true
            },
        }

        while true do
            WaitSeconds(30)
            local brainIndex = self:GetArmyIndex()
            local currentCount = GetArmyUnitCostTotal(brainIndex)
            local cap = GetArmyUnitCap(brainIndex)
            local capRatio = currentCount / cap
            local maxCullNumber = 30
            if capRatio > 0.85 then
                --LOG('We are over our ratio cap')
                local cullPressure = math.min((capRatio - 0.75) / 0.2, 1)
                local dynamicRatioThreshold = 2.0 - (capRatio - 0.75) * 9
                local currentUnits = self.amanager.Current
                local culledUnitCount = 0
                for k, cullType in cullTable do
                    if cullType.compareType == 'amanager' then
                        if cullType.compare then
                            local compareFrom = GetFromNested(currentUnits, cullType.compareFrom)
                            local compareTo = GetFromNested(currentUnits, cullType.compareTo)
                            if compareTo > 0 and compareFrom > 0 then
                                local ratio = compareFrom / compareTo
                                if ratio > dynamicRatioThreshold then
                                    local toCull = math.min(compareTo, math.ceil(compareTo * ratio * cullType.cullRatio * cullPressure))
                                    --LOG('Amanager Units type '..tostring(k)..' to cull'..tostring(toCull))
                                    if toCull > 0 then
                                        culledUnitCount = culledUnitCount + self:CullUnitsOfCategory(cullType.categories, toCull, cullType.checkAttached, cullType.checkEngineer)
                                        --LOG('culledUnitCount '..tostring(culledUnitCount))
                                    end
                                end
                            end
                        else
                            local units = GetFromNested(currentUnits, cullType.compareFrom)
                            if units > 0 then
                                local toCull = math.min(units, math.ceil(units * cullType.cullRatio * cullPressure))
                                --LOG('Getunits Units type '..tostring(k)..' to cull'..tostring(toCull))
                                if toCull > 0 then
                                    culledUnitCount = culledUnitCount + self:CullUnitsOfCategory(cullType.categories, toCull, cullType.checkAttached, cullType.checkEngineer)
                                    --LOG('culledUnitCount '..tostring(culledUnitCount))
                                end
                            end
                        end
                    elseif cullType.compareType == 'getunits' then
                        if cullType.compare then
                            local compareFrom = self:GetCurrentUnits(cullType.compareFrom)
                            local compareTo = self:GetCurrentUnits(cullType.compareTo)
                            if compareTo > 0 and compareFrom > 0 then
                                local ratio = compareFrom / compareTo
                                if ratio > dynamicRatioThreshold then
                                    local toCull = math.min(compareTo, math.ceil(compareTo * ratio * cullType.cullRatio * cullPressure))
                                    --LOG('Getunits Units type '..tostring(k)..' to cull'..tostring(toCull))
                                    if toCull > 0 then
                                        culledUnitCount = culledUnitCount + self:CullUnitsOfCategory(cullType.categories, toCull, cullType.checkAttached, cullType.checkEngineer)
                                        --LOG('culledUnitCount '..tostring(culledUnitCount))
                                    end
                                end
                            end
                        else
                            local units = self:GetCurrentUnits(cullType.categories)
                            if units > 0 then
                                local toCull = math.min(units, math.ceil(units * cullType.cullRatio * cullPressure))
                                --LOG('Getunits Units type '..tostring(k)..' to cull'..tostring(toCull))
                                if toCull > 0 then
                                    culledUnitCount = culledUnitCount + self:CullUnitsOfCategory(cullType.categories, toCull, cullType.checkAttached, cullType.checkEngineer)
                                    --LOG('culledUnitCount '..tostring(culledUnitCount))
                                end
                            end
                        end
                    end
                    if culledUnitCount >= maxCullNumber then
                        break
                    end
                end
                -- Add more hand-tuned rules here, like engineers, scouts, mobile bombs, etc.
                if culledUnitCount > 0 then
                    --LOG(string.format("UnitCapWatch culled %d units to reduce unit cap pressure", culledUnitCount))
                end
            end
        end
    end,

    CullUnitsOfCategory = function(self, category, toCull, checkAttached, checkEngineer)
        local units = self:GetListOfUnits(category, true)
        local culledUnitCount = 0
        for k, v in units do
            if not v.Dead then
                if checkAttached and v:IsUnitState('Attached') then
                    continue
                end
                if checkEngineer and not v:IsIdleState() then
                    continue
                end
                culledUnitCount = culledUnitCount + 1
                v:Kill()
                if culledUnitCount >= toCull then
                    return culledUnitCount
                end
            end
        end
        return culledUnitCount
    end,

        ---## Scouting help...
    --- Creates an influence map threat at enemy bases so the AI will start sending attacks before scouting gets up.
    ---@param self BaseAIBrain
    ---@param amount number amount of threat to add to each enemy start area
    ---@param decay number rate that the threat should decay
    ---@return nil
    AddInitialEnemyThreatRNG = function(self, amount, decay)
        local aiBrain = self
        local myArmy = ScenarioInfo.ArmySetup[self.Name]
        local threatTypes = {
            'AntiAir',
            'AntiSurface',
            'StructuresNotMex'
        }

        if ScenarioInfo.Options.TeamSpawn == 'fixed' then
            -- Spawn locations were fixed. We know exactly where our opponents are.
            for i = 1, 16 do
                local token = 'ARMY_' .. i
                local army = ScenarioInfo.ArmySetup[token]

                if army then
                    if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                        if startPos then
                            for _, t in threatTypes do
                                self:AssignThreatAtPosition(startPos, amount, decay, t)
                            end
                        end
                    end
                end
            end
        end
    end,

        --- Called after `SetupSession` but before `BeginSession` - no initial units, props or resources exist at this point
    ---@param self AIBrainAdaptive
    ---@param planName string
    CreateBrainShared = function(self, planName)
        StandardBrain.CreateBrainShared(self, planName)

        local aiScenarioPlans = self:ImportScenarioArmyPlans(planName)

        self.DefaultPlan = true
        self.AIPlansList = import("/mods/RNGAI/lua/AI/aibrainplans.lua").AIPlansList

        self.RepeatExecution = false
        self.ConstantEval = true
    end,

    OnSpawnPreBuiltUnits = function(self)
        local factionIndex = self:GetFactionIndex()
        local resourceStructures = nil
        local initialUnits = nil
        local posX, posY = self:GetArmyStartPos()

        if factionIndex == 1 then
            resourceStructures = {'UEB1103', 'UEB1103', 'UEB1103', 'UEB1103'}
            initialUnits = {'UEB0101', 'UEB1101', 'UEB1101', 'UEB1101', 'UEB1101'}
        elseif factionIndex == 2 then
            resourceStructures = {'UAB1103', 'UAB1103', 'UAB1103', 'UAB1103'}
            initialUnits = {'UAB0101', 'UAB1101', 'UAB1101', 'UAB1101', 'UAB1101'}
        elseif factionIndex == 3 then
            resourceStructures = {'URB1103', 'URB1103', 'URB1103', 'URB1103'}
            initialUnits = {'URB0101', 'URB1101', 'URB1101', 'URB1101', 'URB1101'}
        elseif factionIndex == 4 then
            resourceStructures = {'XSB1103', 'XSB1103', 'XSB1103', 'XSB1103'}
            initialUnits = {'XSB0101', 'XSB1101', 'XSB1101', 'XSB1101', 'XSB1101'}
        end

        if resourceStructures then
            -- Place resource structures down
            for k, v in resourceStructures do
                local unit = self:CreateResourceBuildingNearest(v, posX, posY)
                local unitBp = unit:GetBlueprint()
                if unit ~= nil and unitBp.Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
            end
        end

        if initialUnits then
            -- Place initial units down
            for k, v in initialUnits do
                local unit = self:CreateUnitNearSpot(v, posX, posY)
                if unit ~= nil and unit:GetBlueprint().Physics.FlattenSkirt then
                    unit:CreateTarmac(true, true, true, false, false)
                end
            end
        end

        self.PreBuilt = true
    end,

    EvaluateDefaultProductionRatios = function(self)
        local scenarioMapSizeX, scenarioMapSizeZ = GetMapSize()
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        local mapSizeX, mapSizeZ

        if not playableArea then
            mapSizeX = scenarioMapSizeX
            mapSizeZ = scenarioMapSizeZ
        else
            mapSizeX = playableArea[3]
            mapSizeZ = playableArea[4]
        end

        if mapSizeX > 1000 and mapSizeZ > 1000 then
            if self.RNGEXP then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.4
                    self.DefaultProductionRatios['Naval'] = 0.0
                else
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.3
                    self.DefaultProductionRatios['Naval'] = 0.2
                end
            elseif self.BrainIntel.PlayerRole.AirPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.25
                end
            elseif self.BrainIntel.PlayerRole.SpamPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.70
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.50
                    self.DefaultProductionRatios['Air'] = 0.20
                    self.DefaultProductionRatios['Naval'] = 0.25
                else
                    self.DefaultProductionRatios['Land'] = 0.65
                    self.DefaultProductionRatios['Air'] = 0.20
                    self.DefaultProductionRatios['Naval'] = 0.10
                end
            elseif self.BrainIntel.PlayerRole.NavalPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.45
                else
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.15
                    self.DefaultProductionRatios['Naval'] = 0.40
                end
            else
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.60
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.5
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.25
                end
            end
        elseif mapSizeX > 500 and mapSizeZ > 500 then
            if self.RNGEXP then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.50
                    self.DefaultProductionRatios['Air'] = 0.4
                    self.DefaultProductionRatios['Naval'] = 0.0
                else
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.3
                    self.DefaultProductionRatios['Naval'] = 0.2
                end
            elseif self.BrainIntel.PlayerRole.AirPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.3
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.3
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.3
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.25
                end
            elseif self.BrainIntel.PlayerRole.SpamPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.7
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.6
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.25
                else
                    self.DefaultProductionRatios['Land'] = 0.65
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.10
                end
            elseif self.BrainIntel.PlayerRole.NavalPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.45
                else
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.15
                    self.DefaultProductionRatios['Naval'] = 0.40
                end
            else
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.65
                    self.DefaultProductionRatios['Air'] = 0.35
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.6
                    self.DefaultProductionRatios['Air'] = 0.2
                    self.DefaultProductionRatios['Naval'] = 0.2
                end

            end
        elseif mapSizeX > 200 and mapSizeZ > 200 then
            if self.RNGEXP then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.55
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.0
                else
                    self.DefaultProductionRatios['Land'] = 0.2
                    self.DefaultProductionRatios['Air'] = 0.3
                    self.DefaultProductionRatios['Naval'] = 0.2
                end
            elseif self.BrainIntel.PlayerRole.AirPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.40
                    self.DefaultProductionRatios['Naval'] = 0.25
                end
            elseif self.BrainIntel.PlayerRole.SpamPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.8
                    self.DefaultProductionRatios['Air'] = 0.2
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.7
                    self.DefaultProductionRatios['Air'] = 0.1
                    self.DefaultProductionRatios['Naval'] = 0.2
                else
                    self.DefaultProductionRatios['Land'] = 0.65
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.10
                end
            elseif self.BrainIntel.PlayerRole.NavalPlayer then
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.5
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.45
                else
                    self.DefaultProductionRatios['Land'] = 0.35
                    self.DefaultProductionRatios['Air'] = 0.15
                    self.DefaultProductionRatios['Naval'] = 0.40
                end
            else
                if self.MapWaterRatio < 0.10 then
                    self.DefaultProductionRatios['Land'] = 0.70
                    self.DefaultProductionRatios['Air'] = 0.30
                    self.DefaultProductionRatios['Naval'] = 0.0
                elseif self.MapWaterRatio > 0.60 then
                    self.DefaultProductionRatios['Land'] = 0.4
                    self.DefaultProductionRatios['Air'] = 0.25
                    self.DefaultProductionRatios['Naval'] = 0.35
                else
                    self.DefaultProductionRatios['Land'] = 0.65
                    self.DefaultProductionRatios['Air'] = 0.15
                    self.DefaultProductionRatios['Naval'] = 0.15
                end
            end
        end
    end,

    EvaluateDefaultEconomyRatios = function(self)

        if self.MapSize <= 10 and self.RNGEXP then
            self.EconomyUpgradeSpendDefault = 0.40
            self.EconomyUpgradeSpend = 0.35
        elseif self.MapSize <= 10 then
            self.EconomyUpgradeSpendDefault = 0.25
            self.EconomyUpgradeSpend = 0.25
        elseif self.RNGEXP then
            self.EconomyUpgradeSpendDefault = 0.45
            self.EconomyUpgradeSpend = 0.40
        else
            self.EconomyUpgradeSpendDefault = 0.30
            self.EconomyUpgradeSpend = 0.30
        end
    end,

    ConfigureDefaultBrainData = function(self)
        self.NoRush = {
            Active = false,
            Radius = 0
            }
        self.MapWaterRatio = self:GetMapWaterRatio()

        self.MapSize = 10
        local mapSizeX, mapSizeZ = GetMapSize()
        self.MapDimension = math.max(mapSizeX, mapSizeZ)
        self.DefaultProductionRatios = {
            Land = 0,
            Air = 0,
            Naval = 0
        }
        if mapSizeX > 1000 and mapSizeZ > 1000 then
            self.MapSize = 20
        elseif mapSizeX > 500 and mapSizeZ > 500 then
            self.MapSize = 10
        elseif mapSizeX > 200 and mapSizeZ > 200 then
            self.MapSize = 5
        end
        self.EconomyUpgradeSpendDefault = 0.0
        self.EconomyUpgradeSpend = 0.0
        self.DefaultProductionRatios['Land'] = 0.0
        self.DefaultProductionRatios['Air'] = 0.0
        self.DefaultProductionRatios['Naval'] = 0.0
        self:EvaluateDefaultProductionRatios()
        self:EvaluateDefaultEconomyRatios()

        self.MapCenterPoint = { (ScenarioInfo.size[1] / 2), GetSurfaceHeight((ScenarioInfo.size[1] / 2), (ScenarioInfo.size[2] / 2)) ,(ScenarioInfo.size[2] / 2) }

        -- Condition monitor for the whole brain
        self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

        -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
        self.EconomyData = {}
        self.GraphZones = { 
            FirstRun = true,
            HasRun = false
        }
        self.EconomyTicksMonitor = 80
        self.EconomyCurrentTick = 1
        self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitorRNG)
        self.ExtractorUpgradeThread = false
        self.EconomyOverTimeCurrent = {}
        self.ACUData = {}
        --self.EconomyOverTimeThread = self:ForkThread(self.EconomyOverTimeRNG)
        self.EngineerAssistManagerActive = false
        self.EngineerAssistRatioDefault = 0.15
        self.EngineerAssistRatio = 0.15
        self.EngineerAssistManagerEngineerCount = 0
        self.EngineerAssistManagerEngineerCountDesired = 0
        self.EngineerAssistManagerBuildPowerDesired = 5
        self.EngineerAssistManagerBuildPowerRequired = 0
        self.EngineerAssistManagerBuildPower = 0
        self.EngineerAssistManagerBuildPowerTech1 = 0
        self.EngineerAssistManagerBuildPowerTech2 = 0
        self.EngineerAssistManagerBuildPowerTech3 = 0
        self.EngineerAssistManagerFocusCategory = false
        self.EngineerAssistManagerFocusAirUpgrade = false
        self.EngineerAssistManagerFocusHighValue = false
        self.EngineerAssistManagerFocusLandUpgrade = false
        self.EngineerAssistManagerPriorityTable = {}
        self.EngineerDistributionTable = {
            BuildPower = 0,
            BuildStructure = 0,
            Assist = 0,
            Reclaim = 0,
            ReclaimStructure = 0,
            Expansion = 0,
            Repair = 0,
            Mass = 0,
            Total = 0
        }
        self.ProductionRatios = {
            Land = self.DefaultProductionRatios['Land'],
            Air = self.DefaultProductionRatios['Air'],
            Naval = self.DefaultProductionRatios['Naval'],
        }
        self.earlyFlag = true
        self.CanPathToEnemyRNG = {}
        self.cmanager = {
            income = {
                r  = {
                    m = 0,
                    e = 0,
                },
                t = {
                    m = 0,
                    e = 0,
                },
            },
            spend = {
                m = 0,
                e = 0,
            },
            buildpower = {
                eng = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                    com = 0,
                    sacu = 0
                }
            },
            categoryspend = {
                eng = 0,
                fact = {
                    Land = 0,
                    LandUpgrading=0,
                    Air = 0,
                    AirUpgrading=0,
                    Naval = 0,
                    NavalUpgrading=0
                },
                silo = 0,
                mex = {
                      T1 = 0,
                      T2 = 0,
                      T3 = 0
                      },
            },
            storage = {
                current = {
                    m = 0,
                    e = 0,
                },
                max = {
                    m = 0,
                    e = 0,
                },
            },
        }
        self.amanager = {
            Current = {
                Land = {
                    T1 = {
                        scout=0,
                        tank=0,
                        arty=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        stealth=0,
                        mobilebomb=0,
                        amphib=0,
                        bot=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        armoured=0
                    },
                    T4 = {
                        experimentalland=0,
                    }
                },
                Air = {
                    T1 = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0
                    },
                    T2 = {
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                    },
                    T3 = {
                        scout=0,
                        asf=0,
                        bomber=0,
                        gunship=0,
                        torpedo=0,
                        transport=0
                    }
                },
                Naval = {
                    T1 = {
                        frigate=0,
                        sub=0,
                        shard=0
                    },
                    T2 = {
                        destroyer=0,
                        cruiser=0,
                        subhunter=0,
                        shield=0
                    },
                    T3 = {
                        battleship=0,
                        nukesub=0,
                        battlecrusier=0,
                        missileship=0,
                        shield=0
                    }
                },
                Engineer = {
                    T1 = {
                        engineer = 0
                    },
                    T2 = {
                        engineer = 0,
                        engcombat = 0
                    },
                    T3 = {
                        engineer = 0,
                        sacucombat = 0,
                        sacuras = 0,
                        sacueng = 0,
                        sacutele = 0
                    },
                },
            },
            Total = {
                Land = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Air = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                },
                Naval = {
                    T1 = 0,
                    T2 = 0,
                    T3 = 0,
                }
            },
            Type = {
                Land = {
                    scout=0,
                    tank=0,
                    sniper=0,
                    arty=0,
                    mml=0,
                    aa=0,
                    shield=0,
                    bot=0,
                    mobilebomb=0,
                    armoured=0
                },
                Air = {
                    scout=0,
                    interceptor=0,
                    bomber=0,
                    gunship=0,
                    fighter=0,
                    mercy=0,
                    torpedo=0,
                    asf=0,
                    transport=0,
                },
                Naval = {
                    frigate=0,
                    sub=0,
                    cruiser=0,
                    destroyer=0,
                    battleship=0,
                    shard=0,
                    shield=0
                },
            },
            Ratios = {
                [1] = {
                    Land = {
                        T1 = {
                            scout=10,
                            tank=75,
                            arty=10,
                            aa=5,
                            total=0
                        },
                        T2 = {
                            tank=50,
                            mml=0,
                            bot=35,
                            aa=5,
                            shield=10,
                            total=0
                        },
                        T3 = {
                            tank=40,
                            armoured=60,
                            mml=0,
                            arty=0,
                            aa=5,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=5,
                            interceptor=95,
                            bomber=0,
                            total=0
                        },
                        T2 = {
                            bomber=0,
                            gunship=0,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=0,
                            asf=70,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [2] = {
                    Land = {
                        T1 = {
                            scout=10,
                            tank=75,
                            arty=10,
                            aa=5,
                            total=0
                        },
                        T2 = {
                            tank=75,
                            mml=0,
                            aa=5,
                            shield=15,
                            total=0
                        },
                        T3 = {
                            tank=50,
                            arty=0,
                            aa=5,
                            sniper=45,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=5,
                            interceptor=95,
                            bomber=0,
                            total=0
                        },
                        T2 = {
                            fighter=100,
                            gunship=0,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=0,
                            asf=75,
                            bomber=15,
                            gunship=10,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            shard= 0,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [3] = {
                    Land = {
                        T1 = {
                            scout=10,
                            tank=75,
                            arty=15,
                            aa=5,
                            total=0
                        },
                        T2 = {
                            tank=50,
                            mml=0,
                            bot=35,
                            aa=5,
                            stealth=5,
                            mobilebomb=0,
                            total=0
                        },
                        T3 = {
                            tank=40,
                            armoured=60,
                            arty=0,
                            aa=5,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=5,
                            interceptor=85,
                            bomber=0,
                            gunship=10,
                            total=0
                        },
                        T2 = {
                            bomber=0,
                            gunship=0,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=0,
                            asf=75,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [4] = {
                    Land = {
                        T1 = {
                            scout=10,
                            tank=75,
                            arty=15,
                            aa=5,
                            total=0
                        },
                        T2 = {
                            tank=85,
                            mml=0,
                            aa=5,
                            total=0
                        },
                        T3 = {
                            tank=40,
                            arty=0,
                            aa=5,
                            sniper=45,
                            shield=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=5,
                            interceptor=95,
                            bomber=0,
                            total=0
                        },
                        T2 = {
                            bomber=0,
                            gunship=0,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=0,
                            asf=85,
                            bomber=15,
                            torpedo=0,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=70,
                            sub=30,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            battleship=80,
                            total=0
                        }
                    },
                },
                [5] = {
                    Land = {
                        T1 = {
                            scout=10,
                            tank=75,
                            arty=10,
                            aa=5,
                            total=0
                        },
                        T2 = {
                            tank=55,
                            mml=0,
                            bot=25,
                            aa=5,
                            shield=15,
                            total=0
                        },
                        T3 = {
                            tank=40,
                            armoured=45,
                            mml=0,
                            arty=0,
                            aa=10,
                            total=0
                        }
                    },
                    Air = {
                        T1 = {
                            scout=5,
                            interceptor=95,
                            bomber=0,
                            total=0
                        },
                        T2 = {
                            bomber=0,
                            gunship=0,
                            torpedo=0,
                            total=0
                        },
                        T3 = {
                            scout=0,
                            asf=75,
                            bomber=15,
                            gunship=10,
                            total=0
                        }
                    },
                    Naval = {
                        T1 = {
                            frigate=15,
                            sub=60,
                            total=0
                        },
                        T2 = {
                            destroyer=70,
                            cruiser=30,
                            subhunter=10,
                            total=0
                        },
                        T3 = {
                            scout=11,
                            asf=55,
                            bomber=15,
                            gunship=10,
                            transport=5,
                            total=0
                        }
                    },
                },
            },
            Demand = {
                Land = {
                    T1 = {
                        scout=0,
                        tank=0,
                        arty=0,
                        aa=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        amphib=0,
                        aa=0,
                        shield=0,
                        stealth=0,
                        mobilebomb=0,
                        bot=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0,
                        armoured=0
                    },
                    T4 = {
                        experimentalland = 0,
                    }
                },
                Air = {
                    T1 = {
                        scout=0,
                        interceptor=0,
                        bomber=0,
                        gunship=0
                    },
                    T2 = {
                        bomber=0,
                        gunship=0,
                        fighter=0,
                        mercy=0,
                        torpedo=0,
                    },
                    T3 = {
                        scout=0,
                        asf=0,
                        bomber=0,
                        gunship=0,
                        torpedo=0,
                        transport=0
                    }
                },
                Naval = {
                    T1 = {
                        frigate=0,
                        sub=0,
                        shard=0
                    },
                    T2 = {
                        tank=0,
                        mml=0,
                        aa=0,
                        shield=0
                    },
                    T3 = {
                        tank=0,
                        sniper=0,
                        arty=0,
                        mml=0,
                        aa=0,
                        shield=0
                    }
                },
                Engineer = {
                    T1 = {
                        engineer = 0
                    },
                    T2 = {
                        engineer = 0,
                        engcombat = 0
                    },
                    T3 = {
                        engineer = 0,
                        sacucombat = 0,
                        sacuras = 0,
                        sacueng = 0,
                        sacutele = 0
                    },
                },
                Bases = {
                }
            },
        }
        self.smanager = {
            Current = {
                Structure = {
                    fact = {
                        Land =
                        {
                            T1 = 0,
                            T2 = 0,
                            T3 = 0
                        },
                        Air = {
                            T1=0,
                            T2=0,
                            T3=0
                        },
                        Naval= {
                            T1=0,
                            T2=0,
                            T3=0
                        }
                    },
                    --The mex list is indexed by zone so the AI can easily calculate how many mexes it has per zone.
                    mex = {
                        
                    },
                    pgen = {
                        T1=0,
                        T2=0,
                        T3=0
                    },
                    hydro = {

                    },
                    silo = {
                        T2=0,
                        T3=0
                    },
                    fabs= {
                        T2=0,
                        T3=0
                    },
                    intel= {
                        Optics=0
                    },
                    radar= {
                        T1=0,
                        T2=0,
                        T3=0,
                    },
                    experimental= {
                        novax=0
                    }
                }
            },
            Demand = {
                Structure = {
                    intel = {
                        Optics=0
                    },
                    experimental = {
                        novax=0
                    }
                }
            }

        }
        self.emanager = {
            enemy = {},
            mex = {},
            Artillery = {
                T3 = 0,
                T4 = 0
            },
            Nuke = {
                T3 = 0,
                T4 = 0
            },
            Satellite = {
                T4 = 0
            }
        }

        self.LowEnergyMode = false
        self.EcoManager = {
            ApproxFactoryMassConsumption = 0,
            ApproxLandFactoryMassConsumption = 0,
            ApproxAirFactoryMassConsumption = 0,
            ApproxNavalFactoryMassConsumption = 0,
            EcoManagerTime = 30,
            EcoManagerStatus = 'ACTIVE',
            ExtractorValues = {
                TECH1 = {
                    ConsumptionValue = 10,
                    TeamValue = 0,
                },
                TECH2 = {
                    ConsumptionValue = 24,
                    TeamValue = 0,
                },
            },
            TotalExtractors = {TECH1 = 0, TECH2 = 0},
            ExtractorsUpgrading = {TECH1 = 0, TECH2 = 0},
            ExtractorsUpgradingDistanceTable = {},
            CoreMassMarkerCount = 0,
            TotalCoreExtractors = 0,
            CoreExtractorT3Percentage = 0,
            CoreExtractorT2Count = 0,
            CoreExtractorT3Count = 0,
            EcoMultiplier = 1,
            BuildMultiplier = 1,
            EcoMassUpgradeTimeout = 90,
            EcoPowerPreemptive = false,
            MinimumPowerRequired = 0,
        }
        self.EcoManager.PowerPriorityTable = {
            ENGINEER = 14,
            STATIONPODS = 13,
            TML = 12,
            SHIELD = 8,
            AIR_TECH1 = 9,
            AIR_TECH2 = 7,
            AIR_TECH3 = 5,
            NAVAL_TECH1 = 8,
            NAVAL_TECH2 = 6,
            NAVAL_TECH3 = 4,
            RADAR = 3,
            MASSFABRICATION = 10,
            NUKE = 11,
            LAND_TECH1 = 1,
            LAND_TECH2 = 2,
            LAND_TECH3 = 3,
        }
        self.EcoManager.MassPriorityTable = {
            TML = 19,
            STATIONPODS = 17,
            ENGINEER = 18,
            NUKE = 16,
            INTEL = 15,
        }

        self.DefensiveSupport = {}

        --Tactical Monitor
        self.TacticalMonitor = {
            TacticalMonitorStatus = 'ACTIVE',
            TacticalLocationFound = false,
            TacticalLocations = {},
            TacticalTimeout = 37,
            TacticalMonitorTime = 160,
            TacticalMassLocations = {},
            TacticalUnmarkedMassGroups = {},
            TacticalSACUMode = false,
            TacticalMissions = {
                ACUSnipe = {},
                MassStrike = {}
            }
        }
        -- Intel Data
        self.EnemyIntel = {}
        self.BrainIntel = {}
        self.BrainIntel.PlayerRole = {
            AirPlayer = false,
            NavalPlayer = false,
            ExperimentalPlayer = false,
            SpamPlayer = false
        }
        self.BrainIntel.PlayerStrategy = {
            T3AirRush = false
        }
        self.BrainIntel.SuicideModeActive = false
        self.BrainIntel.SuicideModeTarget = false
        self.BrainIntel.TeamCount = 0
        self.BrainIntel.SMLReady = false
        self.BrainIntel.SMLTargetPositions = {}
        self.EnemyIntel.NavalRange = {
            Position = {},
            Range = 0,
        }
        if self.RNGEXP then
            self.BrainIntel.PlayerRole.ExperimentalPlayer = true
        end
        self.MassMarkersInWater = false
        self.EnemyIntel.FrigateRaid = false
        self.EnemyIntel.FrigateRaidMarkers = {}
        self.EnemyIntel.EnemyCount = 0
        self.EnemyIntel.ClosestEnemyBase = 0
        self.EnemyIntel.ACUEnemyClose = false
        self.EnemyIntel.HighPriorityTargetAvailable = false
        self.EnemyIntel.ACU = {}
        self.EnemyIntel.HighestPhase = 1
        self.EnemyIntel.NavalPhase = 1
        self.EnemyIntel.LandPhase = 1
        self.EnemyIntel.AirPhase = 1
        self.EnemyIntel.TML = {}
        self.EnemyIntel.SMD = {}
        self.EnemyIntel.SML = {}
        self.EnemyIntel.NavalSML = {}
        self.EnemyIntel.Experimental = {}
        self.EnemyIntel.Artillery = {}
        self.EnemyIntel.DirectorData = {
            Strategic = {},
            Energy = {},
            Intel = {},
            Defense = {},
            Mass = {},
            Factory = {},
            Combat = {},
        }
        --RNGLOG('Director Data'..repr(self.EnemyIntel.DirectorData))
        --RNGLOG('Director Energy Table '..repr(self.EnemyIntel.DirectorData.Energy))
        self.EnemyIntel.EnemyStartLocations = {}
        self.EnemyIntel.EnemyThreatLocations = {}
        self.EnemyIntel.ChokeFlag = false
        self.EnemyIntel.EnemyFireBaseDetected = false
        self.EnemyIntel.EnemyAirFireBaseDetected = false
        self.EnemyIntel.ChokePoints = {}
        self.EnemyIntel.EnemyThreatCurrent = {
            Air = 0,
            AntiAir = 0,
            AirSurface = 0,
            Land = 0,
            Experimental = 0,
            Extractor = 0,
            ExtractorCount = 0,
            Naval = 0,
            NavalSub = 0,
            DefenseAir = 0,
            DefenseSurface = 0,
            DefenseSub = 0,
        }
        self.EnemyIntel.EnemyIMAPThreatCurrent = {
            Air = 0,
            AntiAir = 0,
            AirSurface = 0,
            Experimental = 0,
            StructuresNotMex = 0,
            Naval = 0,
            Land = 0,
        }
        self.EnemyIntel.CivilianCaptureUnits = {}
        local selfStartPosX, selfStartPosY = self:GetArmyStartPos()
        self.BrainIntel.StartPos = { selfStartPosX, GetSurfaceHeight(selfStartPosX, selfStartPosY), selfStartPosY }
        self.BrainIntel.MapOwnership = 0
        self.BrainIntel.PlayerZoneControl = 0
        self.BrainIntel.AirStagingRequired = false
        self.BrainIntel.CurrentIntelAngle = RUtils.GetAngleToPosition(self.BrainIntel.StartPos, self.MapCenterPoint)
        self.BrainIntel.IMAPConfig = {
            OgridRadius = 0,
            IMAPSize = 0,
            ResolveBlocks = 0,
            ThresholdMult = 0,
            Rings = 0,
        }
        self.BrainIntel.AllyCount = 0
        self.BrainIntel.AllyStartLocations = {}
        self.BrainIntel.ACUDefensivePositionKeyTable = {}
        self.BrainIntel.LandPhase = 1
        self.BrainIntel.AirPhase = 1
        self.BrainIntel.NavalPhase = 1
        self.BrainIntel.NavalBaseLabels = {}
        self.BrainIntel.MassMarker = 0
        self.BrainIntel.RestrictedMassMarker = 0
        self.BrainIntel.MassSharePerPlayer = 0
        self.BrainIntel.MassMarkerTeamShare = 0
        self.BrainIntel.AirAttackMode = false
        self.BrainIntel.SelfThreat = {}
        self.BrainIntel.Average = {
            Air = 0,
            Land = 0,
            Experimental = 0,
        }
        self.BrainIntel.SelfThreat = {
            Air = {},
            Extractor = 0,
            ExtractorCount = 0,
            MassMarker = 0,
            MassMarkerBuildable = 0,
            MassMarkerBuildableTable = {},
            AllyExtractorTable = {},
            AllyExtractorCount = 0,
            AllyExtractor = 0,
            AllyLandThreat = 0,
            AllyAirThreat = 0,
            AllyAntiAirThreat = 0,
            AntiAirNow = 0,
            AirNow = 0,
            AirSubNow = 0,
            LandNow = 0,
            NavalNow = 0,
            NavalSubNow = 0,
        }
        self.BrainIntel.ActiveExpansion = false
        -- Structure Upgrade properties
        self.UpgradeIssued = 0
        self.EarlyQueueCompleted = false
        self.IntelTriggerList = {}
        
        self.UpgradeIssuedPeriod = 100

        if self.CheatEnabled then
            self.EcoManager.EcoMultiplier = tonumber(ScenarioInfo.Options.CheatMult)
            self.EcoManager.BuildMultiplier = tonumber(ScenarioInfo.Options.BuildMult)
            self.BrainIntel.OmniCheatEnabled = ScenarioInfo.Options.OmniCheat == 'on'
        end
       --LOG('Build Multiplier now set, this impacts many economy checks that look at income '..self.EcoManager.EcoMultiplier)

        -- Table to holding the starting reclaim
        self.StartReclaimTable = {}
        self.StartMassReclaimTotal = 0
        self.StartReclaimCurrent = 0
        self.StartReclaimTaken = false
        self.Zones = { }

        self.UpgradeMode = 'Normal'

        -- ACU Support Data
        self.ACUSupport = {}
        self.ACUSupport.EnemyACUClose = 0
        self.ACUSupport.Supported = false
        self.ACUSupport.PlatoonCount = 0
        self.ACUSupport.Platoons = {}
        self.ACUSupport.Position = {}
        self.ACUSupport.TargetPosition = false
        self.ACUSupport.ReturnHome = true

        -- Misc
        self.ReclaimEnabled = true
        self.ReclaimLastCheck = 0

    end,

    InitializeSkirmishSystems = function(self)
        --LOG('Initialize Skirmish Systems')
        --RNGLOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon.ArmyPool = true
            poolPlatoon:TurnOffPoolAI()
        end
        self:ForkThread(self.SetupPlayableArea)
        self:ConfigureDefaultBrainData()
        --local mapSizeX, mapSizeZ = GetMapSize()
        --RNGLOG('Map X size is : '..mapSizeX..'Map Z size is : '..mapSizeZ)
        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}
        
        
        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)
        -- Generates the zones and updates the resource marker table with Zone IDs
        --IntelManagerRNG.GenerateMapZonesRNG(self)

        self:IMAPConfigurationRNG()
        -- Begin the base monitor process
        self:NoRushCheck()

        self:BaseMonitorInitializationRNG()

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)
        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitorRNG)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.SetupACUData)
        self:ForkThread(self.CivilianUnitCheckRNG)
        self:ForkThread(self.EcoPowerManagerRNG)
        self:ForkThread(self.EcoPowerPreemptiveRNG)
        self:ForkThread(self.EcoMassManagerRNG)
        self:ForkThread(self.BasePerimeterMonitorRNG)
        self:ForkThread(self.EnemyChokePointTestRNG)
        self:ForkThread(self.EngineerAssistManagerBrainRNG)
        self:ForkThread(self.AllyEconomyHelpThread)
        self:ForkThread(self.HeavyEconomyRNG)
        self:ForkThread(IntelManagerRNG.LastKnownThread)
        self:ForkThread(RUtils.CanPathToCurrentEnemyRNG)
        self:ForkThread(Mapping.SetMarkerInformation)
        self:ForkThread(self.SetupIntelTriggersRNG)
        self:ForkThread(IntelManagerRNG.InitialNavalAttackCheck)
        self.ZonesInitialized = false
        self:ForkThread(self.ZoneSetup)
        self.IntelManager = IntelManagerRNG.CreateIntelManager(self)
        self.IntelManager:Run()
        self.StructureManager = StructureManagerRNG.CreateStructureManager(self)
        self.StructureManager:Run()
        self:ForkThread(IntelManagerRNG.CreateIntelGrid, self.IntelManager)
        self:ForkThread(self.CreateFloatingEngineerBase, self.BrainIntel.StartPos)
        self:ForkThread(self.SetMinimumBasePower)
        self:ForkThread(self.CalculateMassMarkersRNG)
        self:ForkThread(self.AdjustEconomicAllocation)
        self:ForkThread(self.SendGameStartTaunt)
        if self.RNGDEBUG then
            self:ForkThread(self.LogDataThreadRNG)
        end
    end,

    SendGameStartTaunt = function(self)
        coroutine.yield(160)
        self:ForkThread(RNGChat.ConsiderRandomTaunt, 'GameStart')
    end,

    LogDataThreadRNG = function(self)
        coroutine.yield(50)
        
        coroutine.yield(300)
        while true do
            local factionIndex = self:GetFactionIndex()
            RNGLOG('-- Eco Stats --')
            RNGLOG('AI '..self.Nickname)
            RNGLOG('EnergyIncome --'..self.EconomyOverTimeCurrent.EnergyIncome)
            RNGLOG('MassIncome --'..self.EconomyOverTimeCurrent.MassIncome)
            RNGLOG('EnergyRequested --'..self.EconomyOverTimeCurrent.EnergyRequested)
            RNGLOG('MassRequested --'..self.EconomyOverTimeCurrent.MassRequested)
            RNGLOG('EnergyEfficiencyOverTime --'..self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime)
            RNGLOG('MassEfficiencyOverTime --'..self.EconomyOverTimeCurrent.MassEfficiencyOverTime)
            RNGLOG('EnergyTrendOverTime --'..self.EconomyOverTimeCurrent.EnergyTrendOverTime)
            RNGLOG('MassTrendOverTime --'..self.EconomyOverTimeCurrent.MassTrendOverTime)
            RNGLOG('Mass Storage --'..GetEconomyStored(self, 'MASS'))
            RNGLOG('Energy Storage --'..GetEconomyStored(self, 'ENERGY'))
            RNGLOG('Mass Storage Ratio --'..GetEconomyStoredRatio(self, 'MASS'))
            RNGLOG('Energy Storage Ratio --'..GetEconomyStoredRatio(self, 'MASS'))
            RNGLOG('---------------')
            RNGLOG('Current Land Factory Spend '..self.cmanager.categoryspend.fact['Land'])
            RNGLOG('Ratio Land Spend Target '..(self.cmanager.income.r.m * self.ProductionRatios['Land']))
            RNGLOG('Current Air Factory Spend '..self.cmanager.categoryspend.fact['Air'])
            RNGLOG('Ratio Air Spend Target '..(self.cmanager.income.r.m * self.ProductionRatios['Air']))
            RNGLOG('Current Naval Factory Spend '..self.cmanager.categoryspend.fact['Naval'])
            RNGLOG('Ratio Naval Spend Target '..(self.cmanager.income.r.m * self.ProductionRatios['Naval']))
            RNGLOG('---------------')
            RNGLOG('Current income from extractors '..self.cmanager.income.r.m)
            RNGLOG('self.cmanager.buildpower.eng '..repr(self.cmanager.buildpower.eng))
            if self.cmanager.income.r.m > 55 and self.cmanager.buildpower.eng.T2 < 75 then
                RNGLOG('Dynamic T2 Engineer builder should be activated for T3 extractor push')
            end
            if self.cmanager.income.r.m > 110 and self.cmanager.buildpower.eng.T3 < 225 then
                RNGLOG('Dynamic T3 Engineer builder should be activated for experimental extractor push')
            end
            if self.EngineerAssistManagerFocusHighValue then
                RNGLOG('We should be pushing for an experimental and we only have one in progress')
            end
            RNGLOG('Core T3 Extractor Count '..self.EcoManager.CoreExtractorT3Count)
            if self.EcoManager.CoreMassPush then
                RNGLOG('We should be pushing for 3 core t3 extractors')
            end
            RNGLOG('Current T1 Mobile AA count '..self.amanager.Current['Land']['T1']['aa'])
            RNGLOG('Current T2 Mobile AA count '..self.amanager.Current['Land']['T2']['aa'])
            RNGLOG('Current T3 Mobile AA count '..self.amanager.Current['Land']['T3']['aa'])
            RNGLOG('Current engineer assist build power required '..self.EngineerAssistManagerBuildPowerRequired)
            RNGLOG('Approx Factory Mass Consumption '..self.EcoManager.ApproxFactoryMassConsumption)
            RNGLOG('Ally Count is '..self.BrainIntel.AllyCount)
            RNGLOG('Enemy Count is '..self.EnemyIntel.EnemyCount)
            RNGLOG('Eco Costing Multiplier is '..self.EcoManager.EcoMultiplier)
            RNGLOG('Current Self Sub Threat :'..self.BrainIntel.SelfThreat.NavalSubNow)
            RNGLOG('Current Enemy Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.NavalSub)
            RNGLOG('Current Self Naval Threat :'..self.BrainIntel.SelfThreat.NavalNow)
            RNGLOG('Current Self Land Threat :'..self.BrainIntel.SelfThreat.LandNow)
            RNGLOG('Current Enemy Land Threat :'..self.EnemyIntel.EnemyThreatCurrent.Land)
            RNGLOG('Current Self Air Threat :'..self.BrainIntel.SelfThreat.AirNow)
            RNGLOG('Current Self Air Sub Threat :'..self.BrainIntel.SelfThreat.AirSubNow)
            RNGLOG('Current Self AntiAir Threat :'..self.BrainIntel.SelfThreat.AntiAirNow)
            RNGLOG('Current Enemy Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.Air)
            RNGLOG('Current Enemy AntiAir Threat :'..self.EnemyIntel.EnemyThreatCurrent.AntiAir)
            RNGLOG('Current Enemy Extractor Threat :'..self.EnemyIntel.EnemyThreatCurrent.Extractor)
            RNGLOG('Current Enemy Extractor Count :'..self.EnemyIntel.EnemyThreatCurrent.ExtractorCount)
            RNGLOG('Current Self Extractor Threat :'..self.BrainIntel.SelfThreat.Extractor)
            RNGLOG('Current Self Extractor Count :'..self.BrainIntel.SelfThreat.ExtractorCount)
            RNGLOG('Current Ally Extractor Count :'..self.BrainIntel.SelfThreat.AllyExtractorCount)
            RNGLOG('Current Mass Share Per Player Count :'..self.BrainIntel.MassSharePerPlayer)
            RNGLOG('Team Count '..self.BrainIntel.TeamCount)
            RNGLOG('Current Extractor share per team is '..(self.BrainIntel.SelfThreat.MassMarker / self.BrainIntel.TeamCount))
            RNGLOG('Current Mass Marker Count :'..self.BrainIntel.SelfThreat.MassMarker)
            RNGLOG('Current mass share per player '..self.BrainIntel.MassSharePerPlayer)
            RNGLOG('Current Defense Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseAir)
            RNGLOG('Current Defense Sub Threat :'..self.EnemyIntel.EnemyThreatCurrent.DefenseSub)
            if not RNGTableEmpty(self.EnemyIntel.SMD) then
                RNGLOG('SMD Table')
                RNGLOG(repr(self.EnemyIntel.SMD))
            end
            if not RNGTableEmpty(self.EnemyIntel.TML) then
                RNGLOG('TML Table')
                RNGLOG(reprs(self.EnemyIntel.TML))
                RNGLOG('Recent Angle '..self.BasePerimeterMonitor['MAIN'].RecentTMLAngle)
            end
            --RNGLOG('Perimeter Monitor Stats '..repr(self.BasePerimeterMonitor['MAIN']))
            local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(self)
            --RNGLOG('Unit Stats '..repr(im.UnitStats))
            RNGLOG('IntelCoverage Percentage '..repr(im.MapIntelStats.IntelCoverage))
            RNGLOG('Tactical Snipe Missions ')
            for k, v in self.TacticalMonitor.TacticalMissions.ACUSnipe do
                if table.getn(v.AIR) > 0 then
                    LOG(repr(v.AIR))
                end
                if table.getn(v.LAND) > 0 then
                    LOG(repr(v.LAND))
                end
            end
            RNGLOG('Enemy Build Power Table '..repr(im.EnemyBuildStrength))
            coroutine.yield(100)
        end
    end,

    SetupACUData = function(self)
        local selfIndex = self:GetArmyIndex()
        for _, v in ArmyBrains do
            local armyIndex = v:GetArmyIndex()
            self.TacticalMonitor.TacticalMissions.ACUSnipe[armyIndex] = {
                LAND = {},
                AIR = {}
            }
            self.EnemyIntel.ACU[armyIndex] = {
                Position = {},
                DistanceToBase = 0,
                LastSpotted = 0,
                Threat = 0,
                HP = 0,
                OnField = false,
                CloseCombat = false,
                Unit = {},
                Gun = false,
                Ally = IsAlly(selfIndex, armyIndex),
                IntelGrid = {}
            }
            self.EnemyIntel.DirectorData[armyIndex] = {
                Strategic = {},
                Energy = {},
                Mass = {},
                Factory = {},
                Combat = {},
            }
        end
    end,

    SetupPlayableArea = function(self)
        local playableArea
        while not playableArea do
            playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
            if playableArea then
                local BaseRestrictedArea, BaseMilitaryArea, BaseDMZArea, BaseEnemyArea = import('/mods/RNGAI/lua/AI/RNGUtilities.lua').GetOpAreaRNG()
                self.OperatingAreas = {
                    BaseRestrictedArea = BaseRestrictedArea,
                    BaseMilitaryArea = BaseMilitaryArea,
                    BaseDMZArea = BaseDMZArea,
                    BaseEnemyArea = BaseEnemyArea,
                }
                LOG('Operating Areas set '..repr(self.OperatingAreas))
                self.MapPlayableSize = math.max(playableArea[3], playableArea[4])
            end
            coroutine.yield(3)
        end
    end,

    NoRushCheck = function(self)
        -- Sets brain flags for NoRush options
        -- Other functions should be looking at these brain flags for decision making.

        if ScenarioInfo.Options.NoRushOption and not(ScenarioInfo.Options.NoRushOption == 'Off') then
            self.NoRush.Active = true
            self.NoRush.Radius = ScenarioInfo.norushradius
            self:ForkThread(self.NoRushMonitor)
        end
    end,

    NoRushMonitor = function(self)
        while self.NoRush.Active do
            coroutine.yield(5)
            if self:GetNoRushTicks() <= 0 then
                if self.RNGDEBUG then
                    RNGLOG('NoRush has ended, setting brain flag')
                end
                self.NoRush.Active = false
            end
        end
    end,

    drawMainRestricted = function(self)
        coroutine.yield(100)
        local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(self)
        RNGLOG('Starting drawMainRestricted')
        while true do
            DrawCircle(self.BuilderManagers['MAIN'].Position, BaseRestrictedArea, '0000FF')
            DrawCircle(self.BuilderManagers['MAIN'].Position, BaseRestrictedArea/2, 'FF0000')
            WaitTicks(2)
        end
    end,

    drawMarker = function(self, position)
        --RNGLOG('Starting drawMainRestricted')
        local counter = 0
        while counter < 60 do
            DrawCircle(position, 10, '0000FF')
            counter = counter + 1
            WaitTicks(2)
        end
    end,

    ZoneSetup = function(self)
        WaitTicks(1)
        self.Zones.Land = MAP:GetZoneSet('RNGLandResourceSet',1)
        self.Zones.Naval = MAP:GetZoneSet('RNGNavalResourceSet',2)
        self.ZoneCount = {
            Land = table.getn(self.Zones.Land.zones),
            Naval = table.getn(self.Zones.Naval.zones)
        }
        self.ZonesInitialized = true
        --self:ForkThread(import('/mods/RNGAI/lua/AI/RNGDebug.lua').DrawReclaimGrid)
        --self:ForkThread(import('/mods/RNGAI/lua/AI/RNGDebug.lua').DrawIntelGrid)
    end,

    WaitForZoneInitialization = function(self)
        while not self.ZonesInitialized do
           --RNGLOG('Zones table is empty, waiting')
            coroutine.yield(20)
        end
    end,

    SetMinimumBasePower = function(self)
        self:WaitForZoneInitialization()
        local totalPowerRequired = 0
        local multiplier
        if self.CheatEnabled then
            multiplier = self.EcoManager.EcoMultiplier
        else
            multiplier = 1
        end
        if self.BuilderManagers['MAIN'].ZoneID then
            local homeZone = self.BuilderManagers['MAIN'].Zone
            if self.Zones.Land.zones[homeZone].resourcevalue > 0 then
                local homeExtractors = self.Zones.Land.zones[homeZone].resourcevalue
                local extractorPowerRequired = homeExtractors * (20 * multiplier) + (60 * multiplier)
                totalPowerRequired = math.min(extractorPowerRequired, (260 * multiplier))
            end
        end
        self.EcoManager.MinimumPowerRequired = math.max(totalPowerRequired,200)
    end,

    SetPathableZonesForBase = function(self, position, baseName)
        --LOG('SetPathableZoneForBaseStarting for '..baseName)
        local zoneTable = {
            PathableLandZoneCount = 0,
            PathableAmphibZoneCount = 0,
            Zones = {}
        }
        self:WaitForZoneInitialization()
        local baseMilitaryAreaSq = math.min((self.OperatingAreas['BaseMilitaryArea'] * self.OperatingAreas['BaseMilitaryArea']), 65536)
        if self.Zones.Land.zones then
            for k, v in self.Zones.Land.zones do
                if NavUtils.CanPathTo('Land', position, v.pos) then
                    zoneTable.PathableLandZoneCount = zoneTable.PathableLandZoneCount + 1
                    local pathDistance
                    local bx = position[1] - v.pos[1]
                    local bz = position[3] - v.pos[3]
                    local zoneDistance = bx * bx + bz * bz
                    if zoneDistance < baseMilitaryAreaSq then
                        local path, msg, distance = NavUtils.PathTo('Land', position, v.pos)
                        if path and distance then
                            pathDistance = distance
                        end
                    end
                    if not pathDistance then
                        pathDistance = math.sqrt(zoneDistance)
                    end
                    RNGINSERT(zoneTable.Zones, {PathType = 'Land', ZoneID = v.id, PathDistance = pathDistance})
                elseif NavUtils.CanPathTo('Amphibious', position, v.pos) then
                    zoneTable.PathableAmphibZoneCount = zoneTable.PathableAmphibZoneCount + 1
                    local pathDistance
                    local bx = position[1] - v.pos[1]
                    local bz = position[3] - v.pos[3]
                    local zoneDistance = bx * bx + bz * bz
                    if zoneDistance < baseMilitaryAreaSq then
                        local path, msg, distance = NavUtils.PathTo('Amphibious', position, v.pos)
                        if path and distance then
                            pathDistance = distance
                        end
                    end
                    if not pathDistance then
                        pathDistance = math.sqrt(zoneDistance)
                    end
                    RNGINSERT(zoneTable.Zones, {PathType = 'Amphibious', ZoneID = v.id, PathDistance = pathDistance})
                end
            end
        else
            WARN('AI DEBUG: No land zones found for expansion base marker to check')
        end
        if not self.amanager.Demand.Bases[baseName] then
            self.amanager.Demand.Bases[baseName] = {
                Land = {
                    T1 = {
                        arty = 0,
                        aa = 0
                    },
                    T2 = {
                        mml = 0,
                        aa = 0
                    },
                    T3 = {
                        arty = 0,
                        mml = 0,
                        aa = 0
                    },
                    T4 = {
                        experimentalland = 0
                    }
                },
                Naval = {
                    T1 = {
                        frigate = 0,
                        sub = 0
                    },
                    T2 = {
                        destroyer = 0,
                        cruiser = 0
                    },
                    T3 = {
                        missileship = 0,
                        battleship = 0,
                        nukesub = 0,
                        subhunter = 0,
                        carrier = 0
                    }
                },
                Engineer = {
                    T1 = {
                        engineer = 0
                    },
                    T2 = {
                        engineer = 0,
                        engcombat = 0
                    },
                    T3 = {
                        engineer = 0,
                        sacucombat = 0,
                        sacuras = 0,
                        sacueng = 0,
                        sacutele = 0
                    },
                }
            }
        end
        self.BuilderManagers[baseName].PathableZones = zoneTable
        --LOG('Pathable zone table for base name '..baseName..' '..repr(self.BuilderManagers[baseName].PathableZones))
    end,


    EconomyMonitorRNG = function(self)
        -- This over time thread is based on Sprouto's LOUD AI.
        --LOG('RNG EconomyMonitor Starting')
        self.EconomyData = { ['EnergyIncome'] = {}, ['EnergyRequested'] = {}, ['EnergyStorage'] = {}, ['EnergyTrend'] = {}, ['MassIncome'] = {}, ['MassRequested'] = {}, ['MassStorage'] = {}, ['MassTrend'] = {}, ['Period'] = 300 }
        -- number of sample points
        -- local point
        local samplerate = 10
        local samples = self.EconomyData['Period'] / samplerate
    
        -- create the table to store the samples
        for point = 1, samples do
            self.EconomyData['EnergyIncome'][point] = 0
            self.EconomyData['EnergyRequested'][point] = 0
            self.EconomyData['EnergyStorage'][point] = 0
            self.EconomyData['EnergyTrend'][point] = 0
            self.EconomyData['MassIncome'][point] = 0
            self.EconomyData['MassRequested'][point] = 0
            self.EconomyData['MassStorage'][point] = 0
            self.EconomyData['MassTrend'][point] = 0
        end    
    
        local RNGMIN = math.min
        local RNGMAX = math.max
    
        -- array totals
        local eIncome = 0
        local mIncome = 0
        local eRequested = 0
        local mRequested = 0
        local eStorage = 0
        local mStorage = 0
        local eTrend = 0
        local mTrend = 0
    
        -- this will be used to multiply the totals
        -- to arrive at the averages
        local samplefactor = 1/samples
    
        local EcoData = self.EconomyData
    
        local EcoDataEnergyIncome = EcoData['EnergyIncome']
        local EcoDataMassIncome = EcoData['MassIncome']
        local EcoDataEnergyRequested = EcoData['EnergyRequested']
        local EcoDataMassRequested = EcoData['MassRequested']
        local EcoDataEnergyTrend = EcoData['EnergyTrend']
        local EcoDataMassTrend = EcoData['MassTrend']
        local EcoDataEnergyStorage = EcoData['EnergyStorage']
        local EcoDataMassStorage = EcoData['MassStorage']
        
        local e,m
    
        while true do
    
            for point = 1, samples do
    
                -- remove this point from the totals
                eIncome = eIncome - EcoDataEnergyIncome[point]
                mIncome = mIncome - EcoDataMassIncome[point]
                eRequested = eRequested - EcoDataEnergyRequested[point]
                mRequested = mRequested - EcoDataMassRequested[point]
                eTrend = eTrend - EcoDataEnergyTrend[point]
                mTrend = mTrend - EcoDataMassTrend[point]
                
                -- insert the new data --
                EcoDataEnergyIncome[point] = GetEconomyIncome( self, 'ENERGY')
                EcoDataMassIncome[point] = GetEconomyIncome( self, 'MASS')
                EcoDataEnergyRequested[point] = GetEconomyRequested( self, 'ENERGY')
                EcoDataMassRequested[point] = GetEconomyRequested( self, 'MASS')
    
                e = GetEconomyTrend( self, 'ENERGY')
                m = GetEconomyTrend( self, 'MASS')
    
                if e then
                    EcoDataEnergyTrend[point] = e
                else
                    EcoDataEnergyTrend[point] = 0.1
                end
                
                if m then
                    EcoDataMassTrend[point] = m
                else
                    EcoDataMassTrend[point] = 0.1
                end
    
                -- add the new data to totals
                eIncome = eIncome + EcoDataEnergyIncome[point]
                mIncome = mIncome + EcoDataMassIncome[point]
                eRequested = eRequested + EcoDataEnergyRequested[point]
                mRequested = mRequested + EcoDataMassRequested[point]
                eTrend = eTrend + EcoDataEnergyTrend[point]
                mTrend = mTrend + EcoDataMassTrend[point]
                
                -- calculate new OverTime values --
                self.EconomyOverTimeCurrent.EnergyIncome = eIncome * samplefactor
                self.EconomyOverTimeCurrent.MassIncome = mIncome * samplefactor
                self.EconomyOverTimeCurrent.EnergyRequested = eRequested * samplefactor
                self.EconomyOverTimeCurrent.MassRequested = mRequested * samplefactor
                self.EconomyOverTimeCurrent.EnergyEfficiencyOverTime = RNGMIN( (eIncome * samplefactor) / (eRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.MassEfficiencyOverTime = RNGMIN( (mIncome * samplefactor) / (mRequested * samplefactor), 2)
                self.EconomyOverTimeCurrent.EnergyTrendOverTime = eTrend * samplefactor
                self.EconomyOverTimeCurrent.MassTrendOverTime = mTrend * samplefactor
                
                coroutine.yield(samplerate)
            end
        end
    end,
    
    AddBuilderManagers = function(self, position, radius, baseName, useCenter)
        local MarkerUtilities = import("/lua/sim/markerutilities.lua")
        local baseRestrictedArea = self.OperatingAreas['BaseRestrictedArea']

        -- Set the layer of the builder manager so that factory managers and platoon managers know if we should be graphing to land or naval production.
        -- Used for identifying if we can graph to an enemy factory for multi landmass situations
        local baseLayer = 'Land'
        if RUtils.PositionInWater(position) then
			baseLayer = 'Water'
        end
        self.BuilderManagers[baseName] = {
            FactoryManager = FactoryManager.CreateFactoryBuilderManager(self, baseName, position, radius, useCenter),
            PlatoonFormManager = PlatoonFormManager.CreatePlatoonFormManager(self, baseName, position, radius, useCenter),
            EngineerManager = EngineerManager.CreateEngineerManager(self, baseName, position, radius),
            PathableZones = {},
            BuilderHandles = {},
            CoreResources = {},
            ReclaimData = {},
            Position = position,
            Location = position, -- backwards compatibility for now
            Layer = baseLayer,
            GraphArea = false,
            BaseType = RUtils.GetBaseType(baseName) or 'MAIN',
        }
        self.NumBases = self.NumBases + 1
        if baseLayer == 'Water' then
            LOG('Created Water base of name '..baseName)
        end
        self:ForkThread(self.SetPathableZonesForBase, position, baseName)
        self:ForkThread(RUtils.SetCoreResources, position, baseName)
        self:ForkThread(self.GetGraphArea, position, baseName, baseLayer)
        self:ForkThread(self.GetBaseZone, position, baseName, baseLayer)
        self:ForkThread(self.GetDefensivePointTable, baseName, 'BaseRestrictedArea', position, baseLayer)
    end,

    GetBaseZone = function(self, position, baseName, baseLayer)
        -- This will set the zone of the factory manager so we don't need to look it up every time
        -- Needs to wait a while for the GraphArea properties to be populated
        local zoneId
        local zoneSet = false
        while not zoneSet do
            if baseLayer then
                if baseLayer == 'Water' then
                    zoneId = MAP:GetZoneID(position,self.Zones.Naval.index)
                else
                    zoneId = MAP:GetZoneID(position,self.Zones.Land.index)
                    --LOG('Requested land zone for base, zone returned was '..tostring(zone))
                end
            end
            if not zoneId then
                WARN('Missing zone for builder manager land node or no path markers')
            end
            if zoneId then
                self.BuilderManagers[baseName].ZoneID = zoneId
                if zoneId > -1 then
                    if baseLayer == 'Water' then
                        if not self.Zones.Naval.zones[zoneId] then
                        end
                        self.Zones.Naval.zones[zoneId].BuilderManager = self.BuilderManagers[baseName]
                        self.BuilderManagers[baseName].Zone = self.Zones.Naval.zones[zoneId]
                    else
                        if not self.Zones.Land.zones[zoneId] then
                        end
                        self.Zones.Land.zones[zoneId].BuilderManager = self.BuilderManagers[baseName]
                        self.BuilderManagers[baseName].Zone = self.Zones.Land.zones[zoneId]
                        LOG('BuilderManager zone is set')
                    end
                    return
                else
                    WARN('No Zone found at provided position '..tostring(position[1])..':'..tostring(position[3]))
                end
                LOG('Zone is '..self.BuilderManagers[baseName].ZoneID)
                zoneSet = true
            else
                LOG('No zone for builder manager')
            end
            coroutine.yield(10)
        end
    end,

    CreateFloatingEngineerBase = function(self, position)
        if self.RNGDEBUG then
            RNGLOG('Creating Floating base setup at pos '..repr(position))
        end
        coroutine.yield(80)
        local baseLayer = 'Land'
        position[2] = GetTerrainHeight( position[1], position[3] )
        if GetSurfaceHeight( position[1], position[3] ) > position[2] then
            position[2] = GetSurfaceHeight( position[1], position[3] )
            baseLayer = 'Water'
        end
        self.BuilderManagers['FLOATING'] = {
            FactoryManager = StructureManagerRNG.CreateDummyManager(self),
            EngineerManager = EngineerManager.CreateFloatingEngineerManager(self, position),
            PlatoonFormManager = StructureManagerRNG.CreateDummyManager(self),
            BuilderHandles = {},
            Position = position,
            Layer = baseLayer,
            BaseType = 'FLOATING'
            }
        if self.RNGDEBUG then
            RNGLOG('Floating base setup, adding global base template')
        end
        import('/mods/RNGAI/lua/ai/aiaddbuildertable.lua').AddGlobalBaseTemplate(self, 'FLOATING', 'FloatingBaseTemplate')
    end,

    GetGraphArea = function(self, position, baseName, baseLayer)
        -- This will set the graph area of the factory manager so we don't need to look it up every time
        -- Needs to wait a while for the GraphArea properties to be populated
        --LOG('Get Graph Area for baseLayer '..repr(baseLayer))
        --LOG('baseName is '..repr(baseName))
        local graphAreaSet = false
        while not graphAreaSet do
            local graphArea
            local amphibGraphArea
            if baseLayer then
                if baseLayer == 'Water' then
                    graphArea = NavUtils.GetLabel('Water', position)
                    amphibGraphArea = NavUtils.GetLabel('Amphibious', position)
                    --LOG('GetLabel returned the following graph area for position '..repr(position)..' on water '..repr(graphArea))
                else
                    graphArea = NavUtils.GetLabel('Land', position)
                    amphibGraphArea = NavUtils.GetLabel('Amphibious', position)
                    --LOG('GetLabel returned the following graph area for position '..repr(position)..' on land '..repr(graphArea))
                end
                
            end
            if not graphArea then
                WARN('Missing Label for builder manager. Expansion position may be on large incline/decline')
                
                --LOG('baseName '..repr(baseName))
                --LOG('Position '..repr(position))
            end
            if graphArea then
                --LOG('Graph Area for buildermanager is '..graphArea)
                graphAreaSet = true
                self.BuilderManagers[baseName].GraphArea = graphArea
                self.BuilderManagers[baseName].AmphibGraphArea = amphibGraphArea
            end
            if not graphAreaSet then
                --LOG('Graph Area not set yet')
                coroutine.yield(30)
            end
        end
    end,

    GetDefensivePointTable = function(self, baseName, area, position, layer)
        -- This will set the graph area of the factory manager so we don't need to look it up every time
        local defensivePointTableSet = false
        while not defensivePointTableSet do
            if self.OperatingAreas[area] then
                local range = self.OperatingAreas[area]
                self:ForkThread(RUtils.GenerateDefensiveSpokeTable, baseName, range, position, layer)
                defensivePointTableSet = true
            end
            coroutine.yield(3)
        end
    end,

    CalculateMassMarkersRNG = function(self)
        coroutine.yield(math.random(10,20))
        while not self.MarkersInfectedRNG do
            RNGLOG('Waiting for markers to be infected in order to CalculateMassMarkers')
            coroutine.yield(20)
        end
        local MassMarker = {}
        local massMarkerBuildable = 0
        local markerCount = 0
        local restrictedMarkers = 0
        local graphCheck = false
        local coreMassMarkers = 0
        local massMarkers = GetMarkersRNG()
        local baseRestrictedArea = self.OperatingAreas['BaseRestrictedArea']
        local maximumGraphValue = 0
        
        for _, v in massMarkers do
            if v.type == 'Mass' then
                if v.GraphArea and not self.GraphZones.FirstRun and not self.GraphZones.HasRun then
                    graphCheck = true
                    if not self.GraphZones[v.GraphArea] then
                        self.GraphZones[v.GraphArea] = {}
                        self.GraphZones[v.GraphArea].MassMarkers = {}
                        self.GraphZones[v.GraphArea].FriendlyLandAntiAirThreat = 0
                        self.GraphZones[v.GraphArea].FriendlySurfaceDirectFireThreat = 0
                        self.GraphZones[v.GraphArea].FriendlySurfaceInDirectFireThreat = 0
                        self.GraphZones[v.GraphArea].FriendlyAntiNavalThreat = 0
                        if self.GraphZones[v.GraphArea].MassMarkersInGraph == nil then
                            self.GraphZones[v.GraphArea].MassMarkersInGraph = 0
                        end
                    end
                    RNGINSERT(self.GraphZones[v.GraphArea].MassMarkers, v)
                    self.GraphZones[v.GraphArea].MassMarkersInGraph = self.GraphZones[v.GraphArea].MassMarkersInGraph + 1
                    local massPointDistance = VDist3Sq(v.position, self.BrainIntel.StartPos)
                    if massPointDistance < 2500 then
                        coreMassMarkers = coreMassMarkers + 1
                    end
                    if massPointDistance < baseRestrictedArea * baseRestrictedArea then
                        restrictedMarkers = restrictedMarkers + 1
                    end
                    
                end
                if CanBuildStructureAt(self, 'ueb1103', v.position) then
                    massMarkerBuildable = massMarkerBuildable + 1
                    RNGINSERT(MassMarker, v)
                end
                markerCount = markerCount + 1
            end
            if not v.zoneid and self.ZonesInitialized then
                if RUtils.PositionOnWater(v.position[1], v.position[3]) then
                    -- tbd define water based zones
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Naval.index)
                else
                    v.zoneid = MAP:GetZoneID(v.position,self.Zones.Land.index)
                end
            end
        end
        for _, v in self.GraphZones do
            if v.MassMarkersInGraph and v.MassMarkersInGraph > maximumGraphValue then
                maximumGraphValue = v.MassMarkersInGraph
            end
        end
        if maximumGraphValue then
            self.IntelManager.MapMaximumValues.MaximumGraphValue = maximumGraphValue
        end
        if graphCheck then
            self.GraphZones.HasRun = true
            self.EcoManager.CoreMassMarkerCount = coreMassMarkers
            self.BrainIntel.RestrictedMassMarker = restrictedMarkers
            self.BrainIntel.MassSharePerPlayer = markerCount / (self.EnemyIntel.EnemyCount + self.BrainIntel.AllyCount)
        end
        self.BrainIntel.SelfThreat.MassMarker = markerCount
        self.BrainIntel.SelfThreat.MassMarkerBuildable = massMarkerBuildable
        self.BrainIntel.SelfThreat.MassMarkerBuildableTable = MassMarker
        --RNGLOG('Team count '..self.BrainIntel.TeamCount)
        if self.BrainIntel.SelfThreat.MassMarker and self.BrainIntel.TeamCount > 0 then
            self.BrainIntel.MassMarkerTeamShare = markerCount / self.BrainIntel.TeamCount
        end
        --RNGLOG('MassMarkerTeamShare '..self.BrainIntel.MassMarkerTeamShare)
        --RNGLOG('self.BrainIntel.SelfThreat.MassMarker '..self.BrainIntel.SelfThreat.MassMarker)
        --RNGLOG('self.BrainIntel.SelfThreat.MassMarkerBuildable '..self.BrainIntel.SelfThreat.MassMarkerBuildable)
    end,

    BaseMonitorThreadRNG = function(self)
        while true do
            if self.BaseMonitor.BaseMonitorStatus == 'ACTIVE' then
                self:BaseMonitorCheckRNG()
                self:BasesReclaimCheckRNG()
            end
            coroutine.yield(40)
        end
    end,

    BaseMonitorInitializationRNG = function(self, spec)
        self.BaseMonitor = {
            BaseMonitorStatus = 'ACTIVE',
            BaseMonitorPoints = {},
            AlertSounded = false,
            AlertsTable = {},
            AlertLocation = false,
            AlertSoundedThreat = 0,
            ActiveAlerts = 0,

            PoolDistressRange = 75,
            PoolReactionTime = 7,

            -- Variables for checking a radius for enemy units
            UnitRadiusThreshold = spec.UnitRadiusThreshold or 3,
            UnitCategoryCheck = spec.UnitCategoryCheck or (categories.MOBILE - (categories.SCOUT + categories.ENGINEER)),
            UnitCheckRadius = spec.UnitCheckRadius or 40,

            -- Threat level must be greater than this number to sound a base alert
            AlertLevel = spec.AlertLevel or 0,
            -- Delay time for checking base
            BaseMonitorTime = 11,
            -- Default distance a platoon will travel to help around the base
            DefaultDistressRange = spec.DefaultDistressRange or 75,
            -- Default how often platoons will check if the base is under duress
            PlatoonDefaultReactionTime = spec.PlatoonDefaultReactionTime or 5,
            -- Default duration for an alert to time out
            DefaultAlertTimeout = spec.DefaultAlertTimeout or 5,

            PoolDistressThreshold = 1,

            -- Monitor platoons for help
            PlatoonDistressTable = {},
            PlatoonReinforcementTable = {},
            ZoneAlertTable = {},
            PlatoonDistressThread = false,
            PlatoonAlertSounded = false,
            PlatoonReinforcementRequired = false,
            ZoneAlertSounded = false,
        }
        self:ForkThread(self.BaseMonitorThreadRNG)
        self:ForkThread(self.TacticalMonitorInitializationRNG)
        self:ForkThread(self.TacticalAnalysisThreadRNG)
        self:ForkThread(self.BaseMonitorZoneThreatThreadRNG)
    end,

    DeadBaseMonitorRNG = function(self)
        while true do
            WaitSeconds(5)
            local needSort = false
            for k, v in self.BuilderManagers do
                if k ~= 'MAIN' and k ~= 'FLOATING' and v.EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) <= 0 and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) <= 0 then
                    if v.EngineerManager then
                        v.EngineerManager:SetEnabled(false)
                        v.EngineerManager:Destroy()
                    end
                    if v.FactoryManager then
                        v.FactoryManager:SetEnabled(false)
                        v.FactoryManager:Destroy()
                    end
                    if v.PlatoonFormManager then
                        v.PlatoonFormManager:SetEnabled(false)
                        v.PlatoonFormManager:Destroy()
                    end
                    self.BuilderManagers[k] = nil
                    self.NumBases = self.NumBases - 1
                    needSort = true
                end
            end
            if needSort then
                self.BuilderManagers = self:RebuildTable(self.BuilderManagers)
            end
        end
    end,

    GetStructureVectorsRNG = function(self)
        -- This will get the closest IMAPposition  based on where the structure is. Though I don't think it works on 5km maps because the imap grid is different.
        local structures = GetListOfUnits(self, categories.STRUCTURE - categories.DEFENSE - categories.WALL - categories.MASSEXTRACTION, false)
        local tempGridPoints = {}
        local indexChecker = {}
        for k, v in structures do
            if not v.Dead then
                local pos = AIUtils.GetUnitBaseStructureVector(v)
                if pos then
                    if not indexChecker[pos[1]] then
                        indexChecker[pos[1]] = {}
                    end
                    if not indexChecker[pos[1]][pos[3]] then
                        indexChecker[pos[1]][pos[3]] = true
                        RNGINSERT(tempGridPoints, pos)
                    end
                end
            end
        end
        return tempGridPoints
    end,

    BaseMonitorCheckRNG = function(self)
        
        local gameTime = GetGameTimeSeconds()
        if gameTime < 300 then
            -- default monitor spec
        elseif gameTime > 300 then
            self.BaseMonitor.PoolDistressRange = 130
            self.AlertLevel = 5
        end
        local alertThreat = self.BaseMonitor.AlertLevel
        if self.BasePerimeterMonitor then
            for k, v in self.BasePerimeterMonitor do
                if self.BasePerimeterMonitor[k].LandUnits > 0 then
                    if self.BasePerimeterMonitor[k].LandThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Land'] then
                            self.BaseMonitor.AlertsTable[k]['Land'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].LandThreat, Type = 'Land' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Land')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
                if self.BasePerimeterMonitor[k].AntiSurfaceAirUnits > 0 then
                    if self.BasePerimeterMonitor[k].AirThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Air'] then
                            self.BaseMonitor.AlertsTable[k]['Air'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].AirThreat, Type = 'Air' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Air')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
                if self.BasePerimeterMonitor[k].NavalUnits > 0 then
                    if self.BasePerimeterMonitor[k].NavalThreat > alertThreat then
                        if not self.BaseMonitor.AlertsTable[k] then
                            self.BaseMonitor.AlertsTable[k] = {}
                        end
                        if not self.BaseMonitor.AlertsTable[k]['Naval'] then
                            self.BaseMonitor.AlertsTable[k]['Naval'] = { Location = k, Position = self.BuilderManagers[k].FactoryManager.Location, Threat = self.BasePerimeterMonitor[k].NavalThreat, Type = 'Naval' }
                            self.BaseMonitor.AlertSounded = true
                            self:ForkThread(self.BaseMonitorAlertTimeoutRNG, self.BuilderManagers[k].FactoryManager.Location, k, 'Naval')
                            self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                        end
                    end
                end
            end
        end
    end,

    BasesReclaimCheckRNG = function(self)
        local reclaimGridInstance = self.GridReclaim
        local brainGridInstance = self.GridBrain
        for k, v in self.BuilderManagers do
            if k ~= 'FLOATING' and v.FactoryManager.LocationActive then
                local engineerManager = v.EngineerManager
                local currentReclaimPlatoonCount = engineerManager and engineerManager:GetEngineerStateMachineCount('Engineers', 'ReclaimEngineer') or 0
                local gx, gz = reclaimGridInstance:ToGridSpace(v.Position[1],v.Position[3])
                local cells, count = reclaimGridInstance:FilterAndSortInRadius(gx, gz, self.BrainIntel.IMAPConfig.Rings, 50)
                local maxEngineersRequired = 0
                local totalMassRequired = 0
                local totalEnergyRequired = 0
                local reclaimAvailable = false
                for k = 1, count do
                    local cell = cells[k] --[[@as AIGridReclaimCell]]
                    if cell.TotalMass > 0 or cell.TotalEnergy > 0 then
                        local centerOfCell = reclaimGridInstance:ToWorldSpace(cell.X, cell.Z)
                        totalMassRequired = totalMassRequired + cell.TotalMass
                        totalEnergyRequired = totalEnergyRequired + cell.TotalEnergy
                        -- Setup a path check for the cell, but make it a flag since the base position never changes. Where will I put this data? GridBrain?
                        --[[if NavUtils.CanPathTo('AMPHIBIOUS', v.Position, centerOfCell) then
                        end]]
                    end
                end
                local maxEngineersRequired = math.max(math.ceil(totalMassRequired / 300), math.ceil(totalEnergyRequired / 700))
                --LOG('Base Reclaim Check for '..tostring(k)..' : Engineers Required '..tostring(maxEngineersRequired )..' current reclaim engineers '..tostring(currentReclaimPlatoonCount))
                if totalMassRequired > 500 or totalEnergyRequired > 1500 then
                    v.ReclaimData.ReclaimAvailable = true
                    v.ReclaimData.EngineersRequired = math.max(12, (maxEngineersRequired - currentReclaimPlatoonCount))
                else 
                    v.ReclaimData.ReclaimAvailable = false
                    v.ReclaimData.EngineersRequired = maxEngineersRequired - currentReclaimPlatoonCount
                end
                if k == 'MAIN' then
                    self.StartMassReclaimTotal = totalMassRequired
                    self.StartEnergyReclaimTotal = totalEnergyRequired
                end
            end
        end
    end,

    BaseMonitorAlertTimeoutRNG = function(self, pos, location, type)
        local timeout = self.BaseMonitor.DefaultAlertTimeout
        local threat
        local threshold = self.BaseMonitor.AlertLevel
        local myThreat
        local alertBreak = false
        --RNGLOG('Base monitor raised for '..location..' of type '..type)
        repeat
            WaitSeconds(timeout)
           --RNGLOG('BaseMonitorAlert Timeout Reached')
            if type == 'Land' then
                if self.BasePerimeterMonitor[location].LandUnits and self.BasePerimeterMonitor[location].LandUnits > 0 and self.BasePerimeterMonitor[location].LandThreat > threshold then
                   --RNGLOG('Land Units at base '..self.BasePerimeterMonitor[location].LandUnits)
                   --RNGLOG('Land Threats at base '..self.BasePerimeterMonitor[location].LandThreat)
                    threat = self.BasePerimeterMonitor[location].LandThreat
                    self.BaseMonitor.AlertsTable[location]['Land'].Threat = self.BasePerimeterMonitor[location].LandThreat
                   --RNGLOG('Still land units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Land'] = nil
                    alertBreak = true
                end
            elseif type == 'Air' then
                if self.BasePerimeterMonitor[location].AirUnits and self.BasePerimeterMonitor[location].AirUnits > 0 and self.BasePerimeterMonitor[location].AirThreat > threshold then
                   --RNGLOG('Air Units at base '..self.BasePerimeterMonitor[location].AirUnits)
                   --RNGLOG('Air Threats at base '..self.BasePerimeterMonitor[location].AirThreat)
                    threat = self.BasePerimeterMonitor[location].AirThreat
                    self.BaseMonitor.AlertsTable[location]['Air'].Threat = self.BasePerimeterMonitor[location].AirThreat
                   --RNGLOG('Still air units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Air'] = nil
                    alertBreak = true
                end
            elseif type == 'Naval' then
                if self.BasePerimeterMonitor[location].NavalUnits and self.BasePerimeterMonitor[location].NavalUnits > 0 and self.BasePerimeterMonitor[location].NavalThreat > threshold then
                   --RNGLOG('Naval Units at base '..self.BasePerimeterMonitor[location].NavalUnits)
                   --RNGLOG('Naval Threats at base '..self.BasePerimeterMonitor[location].NavalThreat)
                    threat = self.BasePerimeterMonitor[location].NavalThreat
                    self.BaseMonitor.AlertsTable[location]['Naval'].Threat = self.BasePerimeterMonitor[location].NavalThreat
                   --RNGLOG('Still naval units present, restart AlertTimeout')
                    continue
                else
                   --RNGLOG('No Longer alert threat, cancel base alert')
                    self.BaseMonitor.AlertsTable[location]['Naval'] = nil
                    alertBreak = true
                end
            end
        until alertBreak
        --RNGLOG('Base monitor finished for '..location..' of type '..type)
        --RNGLOG('Alert Table for location '..repr(self.BaseMonitor.AlertsTable[location]))
        if self.BaseMonitor.AlertsTable[location][type] then
            WARNING('BaseMonitor Alert Table exist when it possibly shouldnt'..repr(self.BaseMonitor.AlertsTable[location][type]))
        end
        self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts - 1
        if self.BaseMonitor.ActiveAlerts == 0 then
            self.BaseMonitor.AlertSounded = false
        end
        --RNGLOG('Number of active alerts = '..self.BaseMonitor.ActiveAlerts)
    end,

    BuildScoutLocationsRNG = function(self)
        if self.RNGDEBUG then
            RNGLOG('Building Scout Locations for '..self.Nickname)
        end
        while not self.MarkersInfectedRNG do
            RNGLOG('Waiting for markers to be infected in order to build scout locations')
            coroutine.yield(20)
        end
        local function DrawCirclePoints(points, radius, center)
            local extractorPoints = {}
            local slice = 2 * math.pi / points
            for i=1, points do
                local angle = slice * i
                local newX = center[1] + radius * math.cos(angle)
                local newY = center[3] + radius * math.sin(angle)
                table.insert(extractorPoints, { newX, 0 , newY})
            end
            return extractorPoints
        end
        local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(self)
        while not im.MapIntelGrid do
            RNGLOG('Waiting for MapIntelGrid to exist...')
            coroutine.yield(30)
        end
        local baseRestrictedArea = self.OperatingAreas['BaseRestrictedArea']
        local baseMilitaryArea = self.OperatingAreas['BaseMilitaryArea']
        local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        --RNGLOG('playableArea '..repr(playableArea) )
        local opponentStarts = {}
        local startLocations = {}
        local startPosMarkers = {}
        local allyStarts = {}
        local numOpponents = 0
        local enemyStarts = {}
        local allyTempStarts = {}
        local realMapSizeX = playableArea[3] - playableArea[1]
        local realMapSizeZ = playableArea[4] - playableArea[2]
        local recommendedAirScouts = math.floor((realMapSizeX + realMapSizeZ) / 250)
        if self.amanager.Demand.Air.T1.scout then
            self.amanager.Demand.Air.T1.scout = recommendedAirScouts
        end
        if self.amanager.Demand.Air.T3.scout then
            self.amanager.Demand.Air.T3.scout = recommendedAirScouts
        end
        --RNGLOG('T1 Scout requirements set to '..self.amanager.Demand.Air.T1.scout)
        --RNGLOG('T3 Scout requirements set to '..self.amanager.Demand.Air.T3.scout)

        if not im.MapIntelStats.ScoutLocationsBuilt then
            self.IntelData.HiPriScouts = 0
            self.IntelData.LowPriScouts = 0
            self.IntelData.AirHiPriScouts = 0
            self.IntelData.AirLowPriScouts = 0
            if RNGAIGLOBALS.CampaignMapFlag then
                local myIndex = self:GetArmyIndex()
                for index,brain in ArmyBrains do
                    local armyIndex = brain:GetArmyIndex()
                    if IsEnemy(myIndex, armyIndex) then
                        numOpponents = numOpponents + 1
                        local potentialStartPos = RUtils.CalculatePotentialBrainStartPosition(self, brain)
                        if potentialStartPos then
                            local enemyDistance = VDist3Sq(self.BrainIntel.StartPos, potentialStartPos)
                            if self.EnemyIntel.ClosestEnemyBase == 0 or enemyDistance < self.EnemyIntel.ClosestEnemyBase then
                                self.EnemyIntel.ClosestEnemyBase = enemyDistance
                            end
                            enemyStarts[armyIndex] = {Position = potentialStartPos, Index = index, Distance = enemyDistance, WaterLabels = {}}
                        end
                    elseif IsAlly(myIndex, armyIndex) then
                        local startPosX, startPosZ = brain:GetArmyStartPos()
                        local startPos = { startPosX, GetSurfaceHeight(startPosX, startPosZ), startPosZ }
                        allyTempStarts[armyIndex] = {Position = startPos, Index = armyIndex, WaterLabels = {}}
                        allyStarts['ARMY_' .. armyIndex] = startPos
                    end
                end
                self.EnemyIntel.EnemyStartLocations = enemyStarts
                self.BrainIntel.AllyStartLocations = allyTempStarts
            else
                local myArmy = ScenarioInfo.ArmySetup[self.Name]
                for c, t in self.Zones.Land.zones do
                    local gridXID, gridZID = im:GetIntelGrid(t.pos)
                    if im.MapIntelGrid[gridXID][gridZID].Enabled then
                        im.MapIntelGrid[gridXID][gridZID].MustScout = true
                        --RNGLOG('Intel Grid ID : X'..gridXID..' Y: '..gridZID)
                        --RNGLOG('Grid Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                        --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                    end
                end
                if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                    -- Spawn locations were fixed. We know exactly where our opponents are.
                    -- Don't scout areas owned by us or our allies.
                    for i = 1, 16 do
                        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                        if army and startPos then
                            RNGINSERT(startLocations, {Position = startPos, Index = army.ArmyIndex})
                            if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                                -- Add the army start location to the list of interesting spots.
                                opponentStarts['ARMY_' .. i] = startPos
                                numOpponents = numOpponents + 1
                                -- I would rather use army ndexes for the table keys of the enemyStarts so I can easily reference them in queries. To be pondered.
                                local enemyDistance = VDist3Sq(self.BrainIntel.StartPos, startPos)
                                enemyStarts[army.ArmyIndex] = {Position = startPos, Index = army.ArmyIndex, Distance = enemyDistance, WaterLabels = {}}
                                local gridXID, gridZID = im:GetIntelGrid(startPos)
                                if im.MapIntelGrid[gridXID][gridZID].Enabled then
                                    im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 150
                                    im.MapIntelGrid[gridXID][gridZID].MustScout = true
                                    --LOG('Enemy start location set to require scouting')
                                    --LOG('Intel Grid ID : X'..gridXID..' Y: '..gridZID)
                                    --LOG('Grid Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                                    --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                                end
                                if self.EnemyIntel.ClosestEnemyBase == 0 or enemyDistance < self.EnemyIntel.ClosestEnemyBase then
                                    self.EnemyIntel.ClosestEnemyBase = enemyDistance
                                end
                            else
                                allyTempStarts[army.ArmyIndex] = {Position = startPos, Index = army.ArmyIndex, WaterLabels = {}}
                                allyStarts['ARMY_' .. i] = startPos
                            end
                        end
                    end

                    self.NumOpponents = numOpponents

                    -- For each vacant starting location, check if it is closer to allied or enemy start locations (within 100 ogrids)
                    -- If it is closer to enemy territory, flag it as high priority to scout.
                    local starts = AIUtils.AIGetMarkerLocationsRNG(self, 'Start Location')
                    for _, loc in starts do
                        -- If vacant
                        if not opponentStarts[loc.Name] and not allyStarts[loc.Name] then
                            local closestDistSq = 999999999
                            local closeToEnemy = false

                            for _, pos in opponentStarts do
                                local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                                -- Make sure to scout for bases that are near equidistant by giving the enemies 100 ogrids
                                if distSq-10000 < closestDistSq then
                                    closestDistSq = distSq-10000
                                    closeToEnemy = true
                                end
                            end

                            for _, pos in allyStarts do
                                local distSq = VDist2Sq(pos[1], pos[3], loc.Position[1], loc.Position[3])
                                if distSq < closestDistSq then
                                    closestDistSq = distSq
                                    closeToEnemy = false
                                    break
                                end
                            end

                            if closeToEnemy then
                                local gridXID, gridZID = im:GetIntelGrid(loc.Position)
                                if im.MapIntelGrid[gridXID][gridZID].Enabled then
                                    im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                                    --RNGLOG('Intel Grid ID : X'..gridXID..' Y: '..gridZID)
                                    --RNGLOG('Grid Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                                    --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                                end
                            end
                        end
                    end
                    self.EnemyIntel.EnemyStartLocations = enemyStarts
                    self.BrainIntel.AllyStartLocations = allyTempStarts
                else -- Spawn locations were random. We don't know where our opponents are. Add all non-ally start locations to the scout list
                    for i = 1, 16 do
                        local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                        local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                        if army and startPos then
                            if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                                allyStarts['ARMY_' .. i] = startPos
                                local allyDistance = VDist3Sq(self.BrainIntel.StartPos, startPos)
                                allyTempStarts[army.ArmyIndex] = {Position = startPos, Index = army.ArmyIndex, Distance = allyDistance }
                                --allyTempStarts[army.ArmyIndex] = {Position = startPos}
                            else
                                numOpponents = numOpponents + 1
                                local enemyDistance = VDist3Sq(self.BrainIntel.StartPos, startPos)
                                enemyStarts[army.ArmyIndex] = {Position = startPos, Index = army.ArmyIndex, Distance = enemyDistance }
                                --startLocations[army.ArmyIndex] = {Position = startPos}
                            end
                        end
                    end

                    self.NumOpponents = numOpponents

                    -- If the start location is not ours or an ally's, it is suspicious
                    local starts = AIUtils.AIGetMarkerLocationsRNG(self, 'Start Location')
                    for _, loc in starts do
                        -- If vacant
                        if not allyStarts[loc.Name] then
                            local gridXID, gridZID = im:GetIntelGrid(loc.Position)
                            if im.MapIntelGrid[gridXID][gridZID].Enabled then
                                im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                                im.MapIntelGrid[gridXID][gridZID].MustScout = true
                                --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                            end
                        end
                    end
                    -- Set Start Locations for brain to reference
                    --RNGLOG('Start Locations are '..repr(startLocations))
                    self.EnemyIntel.EnemyStartLocations = enemyStarts
                    self.BrainIntel.AllyStartLocations = allyTempStarts
                    -- Create structure threat so inferred threat logic will function at game start
                    for _, v in enemyStarts do
                        self:AssignThreatAtPosition(v.Position, 200, 0.005, 'StructuresNotMex')
                    end
                end
            end
            local perimeterMap = {
                baseRestrictedArea, 
                baseMilitaryArea
            }
            for i=1, 2 do
                local tempPoints = DrawCirclePoints(8, perimeterMap[i], {self.BrainIntel.StartPos[1], 0 , self.BrainIntel.StartPos[3]})
                for _, v in tempPoints do
                    --RNGLOG('TempPoints '..repr(v))
                    if v[1] - playableArea[1] <= 8 or v[1] >= playableArea[3] - 8 or v[3] - playableArea[2] <= 8 or v[3] >= playableArea[4] - 8 then
                    --if v[1] <= 15 or v[1] >= playableArea[1] - 15 or v[3] <= 15 or v[3] >= playableArea[2] - 15 then
                        continue
                    end
                    if i == 1 then
                        local gridXID, gridZID = im:GetIntelGrid(v)
                        if im.MapIntelGrid[gridXID][gridZID].Enabled then
                            if im.MapIntelGrid[gridXID][gridZID].ScoutPriority < 50 then
                                im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                            end
                            im.MapIntelGrid[gridXID][gridZID].Perimeter = 'Restricted'
                            if not im.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked then
                                im:IntelGridSetGraph('MAIN', gridXID, gridZID, self.BrainIntel.StartPos, v)
                            end
                            --RNGLOG('Intel Grid ID : X'..gridXID..' Y: '..gridZID)
                            --RNGLOG('Perimeter Grid Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                            --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                        end
                    elseif i == 2 then
                        local gridXID, gridZID = im:GetIntelGrid(v)
                        if im.MapIntelGrid[gridXID][gridZID].Enabled then
                            if im.MapIntelGrid[gridXID][gridZID].ScoutPriority < 50 then
                                im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                            end
                            im.MapIntelGrid[gridXID][gridZID].Perimeter = 'Military'
                            if not im.MapIntelGrid[gridXID][gridZID].Graphs.MAIN.GraphChecked then
                                im:IntelGridSetGraph('MAIN', gridXID, gridZID, self.BrainIntel.StartPos, v)
                            end
                            --RNGLOG('Intel Grid ID : X'..gridXID..' Y: '..gridZID)
                            --RNGLOG('Perimeter Grid Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                            --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                        end
                    end
                end
            end
            if self.RNGDEBUG then
                RNGLOG('Number of Naval Zones '..table.getn(self.Zones.Naval.zones))
            end
            for k, zone in self.Zones.Naval.zones do
                --RNGLOG('* AI-RNG: Inserting Mass Marker Position : '..repr(massMarker.Position))
                    local gridXID, gridZID = im:GetIntelGrid(zone.pos)
                    if im.MapIntelGrid[gridXID][gridZID].Enabled then
                        im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                        --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                    end
            end
            if self.RNGDEBUG then
                RNGLOG('Number of Land Zones '..table.getn(self.Zones.Land.zones))
            end
            for k, zone in self.Zones.Land.zones do
                if VDist3Sq(self.BrainIntel.StartPos , zone.pos) > 900 then
                    --RNGLOG('* AI-RNG: Inserting Mass Marker Position : '..repr(massMarker.Position))
                    local gridXID, gridZID = im:GetIntelGrid(zone.pos)
                    if im.MapIntelGrid[gridXID][gridZID].Enabled then
                        im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                        --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                    end
                end
            end
            im.MapIntelStats.ScoutLocationsBuilt = true
            if self.RNGDEBUG then
                RNGLOG('* AI-RNG: EnemyStartLocations : '..repr(self.EnemyIntel.EnemyStartLocations))
            end
            self:ForkThread(self.ParseIntelThreadRNG)
        end
    end,

    PickEnemyRNG = function(self)
        while true do
            self:PickEnemyLogicRNG()
            coroutine.yield(1200)
        end
    end,

    PickEnemyLogicRNG = function(self)
        local armyStrengthTable = {} 
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local allyCount = 0
        local enemyCount = 0
        local MainPos = self.BuilderManagers.MAIN.Position
        local teams = {}
        local teamKey = 1
        for _, v in ArmyBrains do
            if v.Status ~= "Defeat" then
                local insertTable = {
                    Enemy = true,
                    Strength = 0,
                    Position = false,
                    Distance = false,
                    EconomicThreat = 0,
                    ACUPosition = {},
                    ACULastSpotted = 0,
                    Brain = v,
                    Team = false,
                }
                local armyIndex = v:GetArmyIndex()
                -- Share resources with friends but don't regard their strength
                if ArmyIsCivilian(armyIndex) then
                    local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', armyIndex)
                    --RNGLOG('User Structure threat for index '..v:GetArmyIndex()..' '..repr(enemyStructureThreat))
                    continue
                elseif IsAlly(selfIndex, armyIndex) then
                    self:SetResourceSharing(true)
                    allyCount = allyCount + 1
                    insertTable.Enemy = false
                    insertTable.Team = v.Team
                elseif not IsEnemy(selfIndex, armyIndex) then
                    insertTable.Enemy = false
                end
                if insertTable.Enemy == true then
                    enemyCount = enemyCount + 1
                    insertTable.Team = v.Team
                    RNGINSERT(enemyBrains, v)
                end
                if not ArmyIsCivilian(armyIndex) then
                    --RNGLOG('Army is not civilian')
                    --RNGLOG('ArmySetup '..repr(ScenarioInfo.ArmySetup))
                    local army
                    
                    for c,b in ScenarioInfo.ArmySetup do
                        if b.ArmyIndex == armyIndex then
                            army = b
                        end
                    end
                    if army.Team and army.Team ~= 1 then
                        --RNGLOG('Army is team '..army.Team)
                        teams[army.Team] = true
                    elseif IsEnemy(selfIndex, armyIndex) then
                        --RNGLOG('Army has no team and is enemy')
                        if army.Team then
                            --RNGLOG('Team presented is '..army.Team)
                        end
                        if not teams[teamKey] then
                            --RNGLOG('Settings teams index 2 to true')
                            teams[teamKey] = true
                            teamKey = teamKey + 1
                        else
                            teamKey = teamKey + 1
                            teams[teamKey] = true
                        end
                    elseif IsAlly(selfIndex, armyIndex) then
                        --RNGLOG('Army has no team and is ally')
                        if not teams[teamKey] then
                            --RNGLOG('Settings teams index 2 to true')
                            teams[teamKey] = true
                            teamKey = teamKey + 1
                        else
                            teamKey = teamKey + 1
                            teams[teamKey] = true
                        end
                    end
                end

                local acuPos = {}
                -- Gather economy information of army to guage economy value of the target
                local enemyIndex = v:GetArmyIndex()
                local startX, startZ = v:GetArmyStartPos()
                local ecoThreat = 0

                if insertTable.Enemy == false then
                    local ecoStructures = GetUnitsAroundPoint(self, categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                    for _, v in ecoStructures do
                        --RNGLOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                        ecoThreat = ecoThreat + v.Blueprint.Defense.EconomyThreatLevel
                    end
                else
                    ecoThreat = 1
                end
                -- Doesn't exist yet!!. Check if the ACU's last position is known.
                --RNGLOG('* AI-RNG: Enemy Index is :'..enemyIndex)
                local acuPos, lastSpotted = RUtils.GetLastACUPosition(self, enemyIndex)
                --RNGLOG('* AI-RNG: ACU Position is has data'..repr(acuPos))
                insertTable.ACUPosition = acuPos
                insertTable.ACULastSpotted = lastSpotted
                
                insertTable.EconomicThreat = ecoThreat
                if insertTable.Enemy then
                    local enemyTotalStrength = 0
                    local highestEnemyThreat = 0
                    local threatPos = {}
                    local enemyStructureThreat = self:GetThreatsAroundPosition(MainPos, 16, true, 'Structures', enemyIndex)
                    for _, threat in enemyStructureThreat do
                        enemyTotalStrength = enemyTotalStrength + threat[3]
                        if threat[3] > highestEnemyThreat then
                            highestEnemyThreat = threat[3]
                            threatPos = {threat[1],0,threat[2]}
                        end
                    end
                    if enemyTotalStrength > 0 then
                        insertTable.Strength = enemyTotalStrength
                        insertTable.Position = threatPos
                    end

                    --RNGLOG('Enemy Index is '..enemyIndex)
                    --RNGLOG('Enemy name is '..v.Nickname)
                    --RNGLOG('* AI-RNG: First Enemy Pass Strength is :'..insertTable.Strength)
                    --RNGLOG('* AI-RNG: First Enemy Pass Position is :'..repr(insertTable.Position))
                    if insertTable.Strength == 0 then
                        --RNGLOG('Enemy Strength is zero, using enemy start pos')
                        insertTable.Position = {startX, 0 ,startZ}
                    end
                else
                    insertTable.Position = {startX, 0 ,startZ}
                    insertTable.Strength = ecoThreat
                    --RNGLOG('* AI-RNG: First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
                end
                armyStrengthTable[v:GetArmyIndex()] = insertTable
            end
        end
        self.BrainIntel.TeamCount = 0
        --RNGLOG('teams table '..repr(teams))
        for _, v in teams do
            if v then
                self.BrainIntel.TeamCount = self.BrainIntel.TeamCount + 1
            end
        end
        self.EnemyIntel.EnemyCount = enemyCount
        self.BrainIntel.AllyCount = allyCount
        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        
        if allyEnemy  then
            --RNGLOG('* AI-RNG: Ally Enemy is true or ACU is close')
            self:SetCurrentEnemy(allyEnemy)
        else
            local findEnemy = false
            if not self:GetCurrentEnemy() then
                findEnemy = true
            else
                local cIndex = self:GetCurrentEnemy():GetArmyIndex()
                -- If our enemy has been defeated or has less than 20 strength, we need a new enemy
                if self:GetCurrentEnemy():IsDefeated() or armyStrengthTable[cIndex].Strength < 20 then
                    findEnemy = true
                end
            end
            local enemyTable = {}
            if findEnemy then
                local enemyStrength = false
                local enemy = false

                for k, v in armyStrengthTable do
                    if v.Brain.Status ~= 'Defeat' then
                        -- Dont' target self
                        if v.Enemy and k ~= selfIndex then
                            -- If we have a better candidate; ignore really weak enemies
                            if enemy and v.Strength < 20 then
                                continue
                            end

                            if v.Strength == 0 then
                                local name = v.Brain.Nickname
                                --RNGLOG('* AI-RNG: Name is'..name)
                                --RNGLOG('* AI-RNG: v.strenth is 0')
                                if name ~= 'civilian' then
                                    --RNGLOG('* AI-RNG: Inserted Name is '..name)
                                    RNGINSERT(enemyTable, v.Brain)
                                end
                                continue
                            end

                            -- The closer targets are worth more because then we get their mass spots
                            local distanceWeight = 0.1
                            local distance = VDist3(self:GetStartVector3f(), v.Position)
                            local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                            --RNGLOG('* AI-RNG: armyStrengthTable Strength is :'..v.Strength)
                            --RNGLOG('* AI-RNG: Threat Weight is :'..threatWeight)
                            if not enemy or threatWeight > enemyStrength then
                                enemy = v.Brain
                                enemyStrength = threatWeight
                                --RNGLOG('* AI-RNG: Enemy Strength is'..enemyStrength)
                            end
                        end
                    end
                end

                if enemy then
                    --RNGLOG('* AI-RNG: Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = RNGGETN(enemyTable)
                    --RNGLOG('* AI-RNG: Table number is'..num)
                    local ran = math.random(num)
                    --RNGLOG('* AI-RNG: Random Number is'..ran)
                    enemy = enemyTable[ran]
                    --RNGLOG('* AI-RNG: Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
                
            end
        end
        local selfEnemy = self:GetCurrentEnemy()
        if selfEnemy then
            local enemyIndex = selfEnemy:GetArmyIndex()
            local closest
            local expansionName
            local mainDist = VDist2Sq(self.BrainIntel.StartPos[1], self.BrainIntel.StartPos[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            for k, v in self.BuilderManagers do
                --RNGLOG('build k is '..k)
                if v.Layer ~= 'Water' then
                    if v.FactoryManager.LocationActive and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) > 0 then
                        if NavUtils.CanPathTo('Land', self.BuilderManagers[k].Position, armyStrengthTable[enemyIndex].Position) then
                            local exDistance = VDist2Sq(self.BuilderManagers[k].Position[1], self.BuilderManagers[k].Position[3], armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
                            --RNGLOG('Distance to Enemy for '..k..' is '..exDistance)
                            if not closest or (exDistance < closest) and (mainDist > exDistance) then
                                expansionName = k
                                closest = exDistance
                            end
                        end
                    end
                end
            end
            if closest and expansionName then
                self.BrainIntel.ActiveExpansion = expansionName
            end
            local waterNodePos, waterNodeName, waterNodeDist = AIUtils.AIGetClosestMarkerLocationRNG(self, 'Water Path Node', armyStrengthTable[enemyIndex].Position[1], armyStrengthTable[enemyIndex].Position[3])
            if waterNodePos then
                --RNGLOG('Enemy Closest water node pos is '..repr(waterNodePos))
                self.EnemyIntel.NavalRange.Position = waterNodePos
                --RNGLOG('Enemy Closest water node pos distance is '..waterNodeDist)
                self.EnemyIntel.NavalRange.Range = waterNodeDist
            end
            self.emanager.enemy.Position = armyStrengthTable[enemyIndex].Position
            --RNGLOG('Current Naval Range table is '..repr(self.EnemyIntel.NavalRange))
        end
    end,

    ParseIntelThreadRNG = function(self)
        local im = import('/mods/RNGAI/lua/IntelManagement/IntelManager.lua').GetIntelManager(self)
        
        if not im.MapIntelStats.ScoutLocationsBuilt then
            error('Scouting areas must be initialized before calling AIBrain:ParseIntelThread.', 2)
        end
        while true do
            if self:GetCurrentEnemy() then
                local enemyX, enemyZ = self:GetCurrentEnemy():GetArmyStartPos()
                local CenterPointAngle = RUtils.GetAngleToPosition(self.BrainIntel.StartPos, self.MapCenterPoint)
                local EnemyAngle = RUtils.GetAngleToPosition(self.BrainIntel.StartPos, {enemyX, GetSurfaceHeight(enemyX, enemyZ), enemyZ})
                --RNGLOG('CenterPointAngle '..CenterPointAngle..' EnemyAngle '..EnemyAngle)
                --RNGLOG('Average should be '..((CenterPointAngle + EnemyAngle) / 2))
                self.BrainIntel.CurrentIntelAngle = (CenterPointAngle + EnemyAngle) / 2
            end
            local structures = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, 'StructuresNotMex')
            local gameTime = GetGameTimeSeconds()
            for _, struct in structures do
                local newPos = {struct[1], 0, struct[2]}
                local gridXID, gridZID = im:GetIntelGrid(newPos)
                if im.MapIntelGrid[gridXID][gridZID].ScoutPriority == 0 then
                    im.MapIntelGrid[gridXID][gridZID].MustScout = true
                    im.MapIntelGrid[gridXID][gridZID].ScoutPriority = 50
                end
            end
            for k, v in self.EnemyIntel.ACU do
                local dupe = false
                if not v.Ally and v.HP ~= 0 and v.LastSpotted ~= 0 and v.Position[1] then
                    --RNGLOG('ACU last spotted '..(GetGameTimeSeconds() - v.LastSpotted)..' seconds ago')
                    if v.LastSpotted + 60 < GetGameTimeSeconds() then
                        local gridXID, gridZID = im:GetIntelGrid(v.Position)
                        if not im.MapIntelGrid[gridXID][gridZID].MustScout then
                            im.MapIntelGrid[gridXID][gridZID].MustScout = true
                        end
                        --RNGLOG('ACU Spotted at : X'..gridXID..' Y: '..gridZID)
                        --RNGLOG('ACU Location Details '..repr(im.MapIntelGrid[gridXID][gridZID]))
                        --self:ForkThread(self.drawMarker, im.MapIntelGrid[gridXID][gridZID].Position)
                    end
                end
            end
            coroutine.yield(70)
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local ACUDist = nil
        self.EnemyIntel.ACUEnemyClose = false
        
        --RNGLOG('* AI-RNG: My Own Strength is'..highStrength)
        for k, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                -- dont log this until you want to get a dump of the brain.
                --RNGLOG('EnemyStrength Tables :'..repr(v))
                --LOG('Start pos '..repr(self.BrainIntel.StartPos))
                if v.ACUPosition[1] then
                    if VDist3Sq(v.ACUPosition, self.BrainIntel.StartPos) < 19600 then
                       --RNGLOG('* AI-RNG: Enemy ACU is close switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    elseif self.EnemyIntel.ACU[k].Threat and self.EnemyIntel.ACU[k].Threat < 20 and self.EnemyIntel.ACU[k].OnField then
                       --RNGLOG('* AI-RNG: Enemy ACU has low threat switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    end
                end
                continue
            end

            -- Ally too weak
            if v.Strength < highStrength then
                continue
            end

            -- If the brain has an enemy, it's our new enemy
            
            local enemy = v.Brain:GetCurrentEnemy()
            if enemy and not enemy:IsDefeated() and v.Strength > 0 then
                highStrength = v.Strength
                returnEnemy = v.Brain:GetCurrentEnemy()
            end
        end
        if returnEnemy then
            --RNGLOG('* AI-RNG: Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            --RNGLOG('* AI-RNG: returnEnemy is false')
        end
        return returnEnemy
    end,

    BaseMonitorZoneThreatRNG = function(self, zoneid, threat)
        --RNGLOG('Create zone alert for zoneid '..zoneid..' with a threat of '..threat)
        if not self.BaseMonitor then
            return
        end

        local found = false
        --RNGLOG('Zone Alert table current size '..table.getn(self.BaseMonitor.ZoneAlertTable))
        if self.BaseMonitor.ZoneAlertSounded == false then
            --RNGLOG('ZoneAlertSounded is currently false')
            self.BaseMonitor.ZoneAlertTable[zoneid].Threat = threat
        else
            for k, v in self.BaseMonitor.ZoneAlertTable do
                -- If already calling for help, don't add another distress call
                if k == zoneid and v.Threat > 0 then
                   --RNGLOG('Zone ID '..zoneid..'already exist as '..k..' skipping')
                    found = true
                    break
                end
            end
            if not found then
               --RNGLOG('Alert doesnt already exist, adding')
                self.BaseMonitor.ZoneAlertTable[zoneid].Threat = threat
            end
        end
        --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.ZoneAlertTable))
    end,

    PlatoonReinforcementRequestRNG = function(self, platoon, threatType, location, currentLabel)
        if not self.BaseMonitor then
            return
        end

        local found = false
        if self.BaseMonitor.PlatoonReinforcementRequired == false then
            RNGINSERT(self.BaseMonitor.PlatoonReinforcementTable, {Platoon = platoon, ThreatType = threatType, LocationType = location, PlatoonLabel = currentLabel, UnitsAssigned = {}})
            self.BaseMonitor.PlatoonReinforcementRequired = true
        else
            for k, v in self.BaseMonitor.PlatoonReinforcementTable do
                -- If already calling for help, don't add another distress call
                if table.equal(v.Platoon, platoon) then
                    --RNGLOG('platoon.BuilderName '..platoon.BuilderName..'already exist as '..v.Platoon.BuilderName..' skipping')
                    found = true
                    break
                end
            end
            if not found then
                --RNGLOG('Platoon doesnt already exist, adding')
                RNGINSERT(self.BaseMonitor.PlatoonReinforcementTable, {Platoon = platoon, ThreatType = threatType, LocationType = location, UnitsAssigned = {}})
            end
        end
        --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonReinforcementTable))
    end,

    BasePerimeterMonitorRNG = function(self)
        --[[ 
        This monitors base perimeters for enemy units
        I did this to replace using multiple calls on builder conditions for defensive triggers, but it also generates the base alerting system data.
        The resulting table will look like something like this
        ARMY_3={
            AirThreat=0,
            AirUnits=0,
            AntiSurfaceAirUnits=0,
            StructureAntiSurface=0,
            LandThreat=0,
            LandUnits=0,
            NavalThreat=0,
            NavalUnits=0
            },
        ]]
        self:WaitForZoneInitialization()
        coroutine.yield(Random(5,20))
        local baseRestrictedArea = self.OperatingAreas['BaseRestrictedArea']
        local baseMilitaryArea = self.OperatingAreas['BaseMilitaryArea']
        local perimeterMonitorRadius
        self.BasePerimeterMonitor = {}
        if self.RNGDEBUG then
            self:ForkThread(self.drawMainRestricted)
        end
        while true do
            for k, v in self.BuilderManagers do
                local landUnits = 0
                local airUnits = 0
                local antiSurfaceAir = 0
                local navalUnits = 0
                local landThreat = 0
                local airThreat = 0
                local antiAirUnits = 0
                local antiAirThreat = 0
                local structureUnits = 0
                local structureThreat = 0
                local navalThreat = 0
                local enemyLandAngle
                local enemyLandDistance = 0
                local enemySurfaceAirAngle
                local enemyAirAngle
                local enemyNavalAngle
                local zoneThreatTable
                local unitCat
                local unitWeaponMaxRange = 20
                local unitBp
                if k == 'MAIN' then
                    perimeterMonitorRadius = baseRestrictedArea * 1.3
                else
                    perimeterMonitorRadius = baseRestrictedArea
                end
                if v.FactoryManager.LocationActive and self.BuilderManagers[k].FactoryManager and not RNGTableEmpty(self.BuilderManagers[k].FactoryManager.FactoryList) then
                    if not self.BasePerimeterMonitor[k] then
                        self.BasePerimeterMonitor[k] = {}
                        self.BasePerimeterMonitor[k].HighestLandThreat = 0
                    end
                    local enemyUnits = self:GetUnitsAroundPoint(categories.ALLUNITS - categories.SCOUT - categories.INSIGNIFICANTUNIT, self.BuilderManagers[k].FactoryManager.Location, perimeterMonitorRadius , 'Enemy')
                    for _, unit in enemyUnits do
                        if unit and not unit.Dead then
                            unitBp = unit.Blueprint
                            unitCat = unitBp.CategoriesHash
                            if unitCat.MOBILE then
                                if unitCat.LAND or unitCat.AMPHIBIOUS or unitCat.COMMAND then
                                    landUnits = landUnits + 1
                                    if unitCat.COMMAND then
                                        landThreat = landThreat + unit:EnhancementThreatReturn()
                                    else
                                        landThreat = landThreat + unit.Blueprint.Defense.SurfaceThreatLevel
                                    end
                                    if unitBp.Weapon[1].WeaponCategory == 'Direct Fire' then
                                        if not unitWeaponMaxRange or unitBp.Weapon[1].MaxRadius > unitWeaponMaxRange then
                                            unitWeaponMaxRange = unitBp.Weapon[1].MaxRadius
                                        end
                                    end
                                    if unit.Blueprint.Defense.AirThreatLevel then
                                        airThreat = airThreat + unit.Blueprint.Defense.AirThreatLevel
                                    end
                                    if landUnits == 1 then
                                        local unitPos = unit:GetPosition()
                                        enemyLandAngle = RUtils.GetAngleToPosition(self.BuilderManagers[k].Position, unitPos)
                                        local ex = self.BuilderManagers[k].Position[1] - unitPos[1]
                                        local ez = self.BuilderManagers[k].Position[3] - unitPos[3]
                                        local posDistance = ex * ex + ez * ez
                                        enemyLandDistance = posDistance
                                    end
                                    continue
                                end
                                if unitCat.MOBILE and unitCat.AIR and (unitCat.GROUNDATTACK or unitCat.BOMBER) then
                                    antiSurfaceAir = antiSurfaceAir + 1
                                    airThreat = airThreat + unit.Blueprint.Defense.AirThreatLevel
                                    if antiSurfaceAir == 1 then
                                        local unitPos = unit:GetPosition()
                                        enemySurfaceAirAngle = RUtils.GetAngleToPosition(self.BuilderManagers[k].Position, unitPos)
                                    end
                                    continue
                                end
                                if unitCat.AIR then
                                    airUnits = airUnits + 1
                                    airThreat = airThreat + unit.Blueprint.Defense.AirThreatLevel
                                    if airUnits == 1 then
                                        local unitPos = unit:GetPosition()
                                        enemyAirAngle = RUtils.GetAngleToPosition(self.BuilderManagers[k].Position, unitPos)
                                    end
                                    if unitCat.ANTIAIR then
                                        antiAirUnits = antiAirUnits + 1
                                        antiAirThreat = antiAirThreat + unit.Blueprint.Defense.AirThreatLevel
                                    end
                                    continue
                                end
                                if unitCat.NAVAL then
                                    navalUnits = navalUnits + 1
                                    navalThreat = navalThreat + unit.Blueprint.Defense.SurfaceThreatLevel + unit.Blueprint.Defense.AirThreatLevel + unit.Blueprint.Defense.SubThreatLevel
                                    if navalUnits == 1 then
                                        local unitPos = unit:GetPosition()
                                        enemyNavalAngle = RUtils.GetAngleToPosition(self.BuilderManagers[k].Position, unitPos)
                                    end
                                    continue
                                end
                            elseif unitCat.STRUCTURE then
                                if unitCat.DIRECTFIRE and unitCat.DEFENSE then
                                    structureUnits = structureUnits + 1
                                    structureThreat = structureThreat + unit.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                    end
                    if v.ZoneID then
                        local zones
                        if v.Layer == 'Water' then
                            zoneThreatTable = RUtils.CalculateThreatWithDynamicDecay(self, k, 'Water', v.ZoneID, baseMilitaryArea, 0, baseRestrictedArea, 1.2, 1)
                        else
                            zoneThreatTable = RUtils.CalculateThreatWithDynamicDecay(self, k, 'Land', v.ZoneID, baseMilitaryArea, 0, baseRestrictedArea, 1.2, 1)
                        end
                    end
                    self.BasePerimeterMonitor[k].LandUnits = landUnits
                    if enemyLandAngle then
                        self.BasePerimeterMonitor[k].RecentLandAngle = enemyLandAngle
                        self.BasePerimeterMonitor[k].RecentLandDistance = enemyLandDistance
                    end
                    self.BasePerimeterMonitor[k].AirUnits = airUnits
                    if enemySurfaceAirAngle then
                        self.BasePerimeterMonitor[k].RecentSurfaceAirAngle = enemySurfaceAirAngle
                    end
                    self.BasePerimeterMonitor[k].AntiSurfaceAirUnits = antiSurfaceAir
                    if enemyAirAngle then
                        self.BasePerimeterMonitor[k].RecentAirAngle = enemyAirAngle
                    end
                    self.BasePerimeterMonitor[k].NavalUnits = navalUnits
                    if enemyNavalAngle then
                        self.BasePerimeterMonitor[k].RecentNavalAngle = enemyNavalAngle
                    end
                    self.BasePerimeterMonitor[k].AntiAirUnits = antiAirUnits
                    self.BasePerimeterMonitor[k].AntiAirThreat = antiAirThreat
                    self.BasePerimeterMonitor[k].NavalThreat = navalThreat
                    self.BasePerimeterMonitor[k].AirThreat = airThreat
                    self.BasePerimeterMonitor[k].LandThreat = landThreat
                    self.BasePerimeterMonitor[k].StructureThreat = structureThreat
                    self.BasePerimeterMonitor[k].StructureUnits = structureUnits
                    if landThreat > self.BasePerimeterMonitor[k].HighestLandThreat then
                        self.BasePerimeterMonitor[k].HighestLandThreat = landThreat
                    end
                    self.BasePerimeterMonitor[k].ZoneThreatTable = zoneThreatTable
                    self.BasePerimeterMonitor[k].MaxEnemyWeaponRange = unitWeaponMaxRange
                else
                    if self.BasePerimeterMonitor[k] then
                        self.BasePerimeterMonitor[k] = nil
                    end
                end
                coroutine.yield(2)
            end
            coroutine.yield(20)
        end
    end,

    BaseMonitorZoneThreatThreadRNG = function(self)
        self:WaitForZoneInitialization()
        for k, v in self.Zones.Land.zones do
            self.BaseMonitor.ZoneAlertTable[k] = { Threat = 0 }
        end
        --RNGLOG('ZoneAlertTable '..repr(self.BaseMonitor.ZoneAlertTable))
        local Zones = {
            'Land',
        }
        --LOG('BaseMonitorZoneThreatThreadRNG Starting')
        while true do
            local numAlerts = 0
            --LOG('BaseMonitorZoneThreatThreadRNG Looping through zone alert table')
            for k, v in self.BaseMonitor.ZoneAlertTable do
                if v.Threat > 0 then
                    local threat = 0
                    local myThreat = 0
                    if RUtils.PositionOnWater(self.Zones.Land.zones[k].pos[1], self.Zones.Land.zones[k].pos[3]) then
                        threat = GetThreatAtPosition(self, self.Zones.Land.zones[k].pos, self.BrainIntel.IMAPConfig.Rings, true, 'AntiSub')
                        local unitsAtPosition = GetUnitsAroundPoint(self, categories.ANTINAVY * categories.MOBILE,  self.Zones.Land.zones[k].pos, 60, 'Ally')
                        for k, v in unitsAtPosition do
                            if v and not v.Dead then
                                --RNGLOG('Unit ID is '..v.UnitId)
                                local bp = ALLBPS[v.UnitId].Defense
                                --RNGLOG(repr(ALLBPS[v.UnitId].Defense))
                                if bp.SubThreatLevel ~= nil then
                                    myThreat = myThreat + bp.SubThreatLevel
                                end
                            end
                        end
                    else
                        threat = self.Zones.Land.zones[k].enemylandthreat
                        if threat > 0 then
                            local unitsAtPosition = GetUnitsAroundPoint(self, categories.LAND * categories.MOBILE,  self.Zones.Land.zones[k].pos, 60, 'Ally')
                            for k, v in unitsAtPosition do
                                if v and not v.Dead then
                                    myThreat = myThreat + v.Blueprint.Defense.SurfaceThreatLevel
                                end
                            end
                        end
                    end
                    if threat and threat > (myThreat * 1.3) then
                       --RNGLOG('* AI-RNG: Created Threat Alert')
                        v.Threat = threat
                        numAlerts = numAlerts + 1
                    -- Platoon not threatened
                    else
                        --LOG('Setting ZoneAlertTable key of '..k..' to nil')
                        self.BaseMonitor.ZoneAlertTable[k].Threat = 0
                    end
                end
                coroutine.yield(1)
            end
            if numAlerts > 0 then
                --LOG('BaseMonitorZoneThreatThreadRNG numAlerts'..numAlerts)
                self.BaseMonitor.ZoneAlertSounded = true
            else
                self.BaseMonitor.ZoneAlertSounded = false
            end
            --self.BaseMonitor.ZoneAlertTable = self:RebuildTable(self.BaseMonitor.ZoneAlertTable)
            --RNGLOG('Platoon Distress Table'..repr(self.BaseMonitor.PlatoonDistressTable))
            --RNGLOG('BaseMonitor time is '..self.BaseMonitor.BaseMonitorTime)
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorDistressLocationRNG = function(self, position, radius, threshold, movementLayer)
        local returnPos = false
        local returnThreat = 0
        local threatPriority = 0
        local distance

        
        if not IsDestroyed(self.CDRUnit) and self.CDRUnit.Caution and VDist2(self.CDRUnit.Position[1], self.CDRUnit.Position[3], position[1], position[3]) < radius
            and self.CDRUnit.CurrentEnemyThreat * 1.3 > self.CDRUnit.CurrentFriendlyThreat then
            -- Commander scared and nearby; help it
            return self.CDRUnit.Position
        end
        if self.BaseMonitor.AlertSounded then
            --RNGLOG('Base Alert Sounded')
            --RNGLOG('There are '..table.getn(self.BaseMonitor.AlertsTable)..' alerts currently')
            --RNGLOG('There are '..self.BaseMonitor.ActiveAlerts.. ' Active alerts')
            --RNGLOG('Movement layer is '..movementLayer)
            local priorityValue = 0
            local threatLayer = false
            if movementLayer == 'Land' or movementLayer == 'Amphibious' or movementLayer == 'Air' then
                threatLayer = 'Land'
            elseif movementLayer == 'Water' then
                threatLayer = 'Naval'
            else
                WARNING('Unknown movement layer passed to BaseMonitorDistressLocations')
            end
            for k, v in self.BaseMonitor.AlertsTable do
                for c, n in v do
                    if c == threatLayer then
                        --RNGLOG('Found Alert of type '..threatLayer)
                        local tempDist = VDist2(position[1], position[3], n.Position[1], n.Position[3])
                        -- stops strange things if the distance is zero
                        if tempDist < 1 then
                            tempDist = 1
                        end
                        if tempDist > radius then
                            continue
                        end
                        -- Not enough threat in location
                        if n.Threat < threshold then
                            continue
                        end
                        priorityValue = 2500 / tempDist * n.Threat
                        if priorityValue > threatPriority then
                            --RNGLOG('We are replacing the following in base monitor')
                            --RNGLOG('threatPriority was '..priorityValue)
                            --RNGLOG('Threat at position was '..n.Threat)
                            --RNGLOG('With position '..repr(n.Position))
                            threatPriority = priorityValue
                            returnPos = n.Position
                            returnThreat = n.Threat
                        end
                    end
                end
            end
        end
        if self.BaseMonitor.PlatoonAlertSounded then
            --RNGLOG('Platoon Alert Sounded')
            local priorityValue = 0
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local platPos = v.Platoon:GetPlatoonPosition()
                    if not platPos then
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        continue
                    end
                    local tempDist = VDist2(position[1], position[3], platPos[1], platPos[3])
                    -- stops strange things if the distance is zero
                    if tempDist < 1 then
                        tempDist = 1
                    end
                    -- Platoon too far away to help
                    if tempDist > radius then
                        continue
                    end

                    -- Area not scary enough
                    if v.Threat < threshold then
                        continue
                    end
                    priorityValue = 2500 / tempDist * v.Threat
                    if priorityValue > threatPriority then
                        --RNGLOG('We are replacing the following in platoon monitor')
                        --RNGLOG('threatPriority was '..threatPriority)
                        --RNGLOG('Position was '..returnThreat)
                        --RNGLOG('With position '..repr(platPos))
                        threatPriority = priorityValue
                        returnPos = platPos
                        returnThreat = v.Threat
                    end
                end
            end
        end
        if self.BaseMonitor.ZoneAlertSounded then
            --RNGLOG('Zone Alert Sounded')
            local priorityValue = 0
            for k, v in self.BaseMonitor.ZoneAlertTable do
                local zonePos = self.Zones.Land.zones[k].pos
                if not zonePos then
                    --RNGLOG('No zone pos, alert table key is getting set to nil')
                    coroutine.yield(1)
                    continue
                end
                local tempDist = VDist2(position[1], position[3], zonePos[1], zonePos[3])
                -- stops strange things if the distance is zero
                if tempDist < 1 then
                    tempDist = 1
                end
                -- Platoon too far away to help
                if tempDist > radius then
                    continue
                end

                -- Area not scary enough
                if v.Threat < threshold then
                    continue
                end
                priorityValue = 2500 / tempDist * v.Threat
                if priorityValue > threatPriority then
                    --RNGLOG('We are replacing the following in platoon monitor')
                    --RNGLOG('threatPriority was '..threatPriority)
                    --RNGLOG('Position was '..returnThreat)
                    --RNGLOG('With position '..repr(platPos))
                    threatPriority = priorityValue
                    returnPos = zonePos
                    returnThreat = v.Threat
                end
            end
        end
        if returnPos then
        -- Get real height
            local height = GetTerrainHeight(returnPos[1], returnPos[3])
            local surfHeight = GetSurfaceHeight(returnPos[1], returnPos[3])
            if surfHeight > height then
                height = surfHeight
            end
            returnPos = {returnPos[1], height, returnPos[3]}
            --RNGLOG('BaseMonitorDistressLocation returning the following')
            --RNGLOG('Return Position '..repr(returnPos))
            --RNGLOG('Return Threat '..returnThreat)
            return returnPos, returnThreat
        end
        coroutine.yield(2)
    end,

    TacticalMonitorInitializationRNG = function(self, spec)
        --RNGLOG('* AI-RNG: Tactical Monitor Is Initializing')
        coroutine.yield(10)
        local ALLBPS = __blueprints
        self:ForkThread(self.TacticalMonitorThreadRNG, ALLBPS)
    end,

    SetupIntelTriggersRNG = function(self)
        -- Since I forgot how this worked really easily.
        coroutine.yield(10)
        --RNGLOG('Try to create intel trigger for enemy')
        self:SetupArmyIntelTrigger({
            CallbackFunction = self.ACUDetectionRNG, 
            Type = 'LOSNow', 
            Category = categories.COMMAND,
            Blip = false, 
            Value = true,
            OnceOnly = false, 
        })
        self:SetupArmyIntelTrigger({
            CallbackFunction = self.ACUDetectionRNG, 
            Type = 'Radar', 
            Category = categories.COMMAND,
            Blip = false, 
            Value = true,
            OnceOnly = false, 
        })
    end,

    OnIntelChange = function(self, blip, reconType, val)
        if val then
            if reconType == 'LOSNow' or reconType == 'Radar' then
                if self.IntelTriggerList then
                    for k, v in self.IntelTriggerList do
                        if EntityCategoryContains(v.Category, blip:GetBlueprint().BlueprintId)
                            and (not v.Blip or v.Blip == blip:GetSource()) then
                            v.CallbackFunction(self, blip)
                            if v.OnceOnly then
                                self.IntelTriggerList[k] = nil
                            end
                        end
                    end
                end
            end
        end
    end,

    ACUDetectionRNG = function(self, blip)
        if blip then
            local unit = blip:GetSource()
            if not unit.Dead then
                local enemyIndex = unit:GetAIBrain():GetArmyIndex()
                if not self.EnemyIntel.ACU[enemyIndex].VisualThread then
                    self.EnemyIntel.ACU[enemyIndex].VisualThread = self:ForkThread(self.ACUVisualThread, enemyIndex, unit)
                end
            end
        end
    end,

    ACUVisualThread = function(self, index, unit)
        local function CDRGunCheck(cdr)
            if cdr['rngdata']['HasGunUpgrade'] then
                --LOG('CDR Gun check is returning true for unit '..tostring(cdr.UnitId))
                return true
            end
            return false
        end
        local dmzRange = self.OperatingAreas['BaseDMZArea']
        local acuTable = self.EnemyIntel.ACU
        if not unit.Dead then
            local timeOut = 0
            while timeOut < 3 do
                local currentGameTime = GetGameTimeSeconds()
                if not IsDestroyed(unit) and RUtils.HaveUnitVisual(self, unit, true) then
                    local acuPos = unit:GetPosition()
                    acuTable[index].Unit = unit
                    acuTable[index].Position = acuPos
                    acuTable[index].DistanceToBase = VDist3Sq(acuPos, self.BrainIntel.StartPos)
                    acuTable[index].HP = unit:GetHealth()
                    if not unit['rngdata']['HasGunUpgrade'] and not unit['rngdata']['IsUpgradingGun'] then
                        if unit:IsUnitState('Enhancing') then
                            RUtils.ValidateEnhancingUnit(unit)
                        end
                    end
                    if not acuTable[index].Range or acuTable[index].LastSpotted + 15 < currentGameTime then
                        if CDRGunCheck(unit) then
                            acuTable[index].Range = unit.Blueprint.Weapon[1].MaxRadius + 8
                            acuTable[index].Gun = true
                        else
                            acuTable[index].Range = unit.Blueprint.Weapon[1].MaxRadius
                            acuTable[index].Gun = false
                        end
                    end
                    if acuTable[index].DistanceToBase < (dmzRange * dmzRange) then
                        acuTable[index].OnField = true
                    else
                        acuTable[index].OnField = false
                    end
                    if acuTable[index].DistanceToBase < 22500 then
                        self.EnemyIntel.ACUEnemyClose = true
                    else
                        self.EnemyIntel.ACUEnemyClose = false
                    end
                    acuTable[index].LastSpotted = currentGameTime
                else
                    timeOut = timeOut + 1
                end
                --LOG('Maintaining ACU Visual')
                --LOG(repr(self.EnemyIntel.ACU[index]))
                coroutine.yield(10)
            end
            acuTable[index].VisualThread = false
            return
        end
    end,

    TacticalMonitorThreadRNG = function(self, ALLBPS)
        --RNGLOG('Monitor Tick Count :'..self.TacticalMonitor.TacticalMonitorTime)
        coroutine.yield(Random(2,10))
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                --RNGLOG('* AI-RNG: Tactical Monitor Is Active')
                self:SelfThreatCheckRNG(ALLBPS)
                self:EnemyThreatCheckRNG(ALLBPS)
                self:TacticalMonitorRNG(ALLBPS)
            end
            local managerCount = 0
            for _, v in self.BuilderManagers do
                managerCount = managerCount + 1
            end
            --LOG('Current builder manager count '..managerCount)
            coroutine.yield(self.TacticalMonitor.TacticalMonitorTime)
        end
    end,

    TacticalAnalysisThreadRNG = function(self)
        local ALLBPS = __blueprints
        coroutine.yield(Random(150,200))
        local im = IntelManagerRNG.GetIntelManager(self)
        while true do
            local multiplier = self.EcoManager.EcoMultiplier
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                --RNGLOG('Run TacticalThreatAnalysisRNG')
                self:ForkThread(IntelManagerRNG.TacticalThreatAnalysisRNG, self)
            end
            --self:CalculateMassMarkersRNG()
            local enemyCount = 0
            if self.EnemyIntel.EnemyCount > 0 then
                enemyCount = self.EnemyIntel.EnemyCount
            end
            if enemyCount == 0 then
                enemyCount = 1
            end
            if self.BrainIntel.AirPhase < 2 then
                if self.smanager.Current.Structure.fact.Air.T2 > 0 then
                    self.BrainIntel.AirPhase = 2
                end
            elseif self.BrainIntel.AirPhase < 3 then
                if self.smanager.Current.Structure.fact.Air.T3 > 0 then
                    self.BrainIntel.AirPhase = 3
                end
            end
            if self.BrainIntel.LandPhase < 2 then
                if self.smanager.Current.Structure.fact.Land.T2 > 0 then
                    self.BrainIntel.LandPhase = 2
                end
            elseif self.BrainIntel.LandPhase < 3 then
                if self.smanager.Current.Structure.fact.Land.T3 > 0 then
                    self.BrainIntel.LandPhase = 3
                end
            end
            if self.BrainIntel.NavalPhase < 2 then
                if self.smanager.Current.Structure.fact.Naval.T2 > 0 then
                    self.BrainIntel.NavalPhase = 2
                end
            elseif self.BrainIntel.NavalPhase < 3 then
                if self.smanager.Current.Structure.fact.Naval.T3 > 0 then
                    self.BrainIntel.NavalPhase = 3
                end
            end
            self.BrainIntel.HighestPhase = math.max(self.BrainIntel.LandPhase,self.BrainIntel.AirPhase,self.BrainIntel.NavalPhase)
            
            --Lets ponder this one some more
            if self.BrainIntel.LandPhase > 2 then
                --LOG('LandPhase greater than 2')
                --LOG('Incomine '..tostring(self.cmanager.income.r.m))
                --LOG('Core extractor count '..tostring(self.EcoManager.CoreExtractorT3Count))
                --LOG('Number of high value buildng '..tostring(RUtils.GetNumberUnitsBeingBuilt(self, (categories.EXPERIMENTAL + categories.TECH3 * categories.STRATEGIC))))
                if not self.RNGEXP and self.cmanager.income.r.m > (120 * multiplier) and self.EcoManager.CoreExtractorT3Count > 2 and RUtils.GetNumberUnitsBeingBuilt(self, (categories.EXPERIMENTAL + categories.TECH3 * categories.STRATEGIC)) >= 1 then
                    --LOG('Land Phase > 2 and eco is above 120 and number units building for exp is 1')
                    self.EngineerAssistManagerFocusHighValue = true
                elseif self.RNGEXP and self.cmanager.income.r.m > (90 * multiplier) and self.EcoManager.CoreExtractorT3Count > 2 and RUtils.GetNumberUnitsBeingBuilt(self, (categories.EXPERIMENTAL + categories.TECH3 * categories.STRATEGIC)) >= 1 then
                    self.EngineerAssistManagerFocusHighValue = true
                else
                    self.EngineerAssistManagerFocusHighValue = false
                end
            end
            coroutine.yield(600)
        end
    end,

    EnemyThreatCheckRNG = function(self, ALLBPS)
        local function CDRGunCheck(cdr)
            if cdr['rngdata']['HasGunUpgrade'] then
                --LOG('CDR Gun check is returning true for unit '..tostring(cdr.UnitId))
                return true
            end
            return false
        end
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        local enemyAirThreat = 0
        local enemyAntiAirThreat = 0
        local enemyAirSurfaceThreat = 0
        local enemyNavalThreat = 0
        local enemyLandThreat = 0
        local enemyNavalSubThreat = 0
        local enemyExtractorthreat = 0
        local enemyExtractorCount = 0
        local enemyDefenseAir = 0
        local enemyDefenseSurface = 0
        local enemyDefenseSub = 0
        local enemyACUGun = 0

        --RNGLOG('Starting Threat Check at'..GetGameTick())
        for index, brain in ArmyBrains do
            if IsEnemy(selfIndex, brain:GetArmyIndex()) then
                RNGINSERT(enemyBrains, brain)
            end
        end
        if not RNGTableEmpty(enemyBrains) then
            for k, enemy in enemyBrains do

                local gunBool = false
                local acuHealth = 0
                local lastSpotted = 0
                local enemyIndex = enemy:GetArmyIndex()
                if not ArmyIsCivilian(enemyIndex) then
                    local enemyAir = GetListOfUnits( enemy, categories.MOBILE * categories.AIR - categories.TRANSPORTFOCUS - categories.SATELLITE - categories.INSIGNIFICANTUNIT, false, false)
                    for _,v in enemyAir do
                        -- previous method of getting unit ID before the property was added.
                        --local unitbpId = v:GetUnitId()
                        enemyAirThreat = enemyAirThreat + v.Blueprint.Defense.AirThreatLevel + v.Blueprint.Defense.SubThreatLevel + v.Blueprint.Defense.SurfaceThreatLevel
                        enemyAntiAirThreat = enemyAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                        enemyAirSurfaceThreat = enemyAirSurfaceThreat + v.Blueprint.Defense.SurfaceThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyExtractors = GetListOfUnits( enemy, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                    for _,v in enemyExtractors do
                        enemyExtractorthreat = enemyExtractorthreat + v.Blueprint.Defense.EconomyThreatLevel
                        enemyExtractorCount = enemyExtractorCount + 1
                    end
                    coroutine.yield(1)
                    local enemyNaval = GetListOfUnits( enemy, categories.NAVAL * ( categories.MOBILE + categories.DEFENSE ), false, false )
                    for _,v in enemyNaval do
                        enemyNavalThreat = enemyNavalThreat + v.Blueprint.Defense.AirThreatLevel + v.Blueprint.Defense.SubThreatLevel + v.Blueprint.Defense.SurfaceThreatLevel
                        enemyNavalSubThreat = enemyNavalSubThreat + v.Blueprint.Defense.SubThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyLand = GetListOfUnits( enemy, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND - categories.INSIGNIFICANTUNIT , false, false)
                    for _,v in enemyLand do
                        enemyLandThreat = enemyLandThreat + v.Blueprint.Defense.SurfaceThreatLevel
                    end
                    coroutine.yield(1)
                    local enemyDefense = GetListOfUnits( enemy, categories.STRUCTURE * categories.DEFENSE - categories.SHIELD, false, false )
                    for _,v in enemyDefense do
                        enemyDefenseAir = enemyDefenseAir + v.Blueprint.Defense.AirThreatLevel
                        enemyDefenseSurface = enemyDefenseSurface + v.Blueprint.Defense.SurfaceThreatLevel
                        enemyDefenseSub = enemyDefenseSub + v.Blueprint.Defense.SubThreatLevel
                    end
                    coroutine.yield(1)
                    if self.CheatEnabled then
                        local enemyACU = GetListOfUnits( enemy, categories.COMMAND, false, false )
                        if enemyACU[1] then
                            acuHealth = enemyACU[1]:GetHealth()
                            self.EnemyIntel.ACU[enemyIndex].HP = acuHealth
                        end
                    end
                end
            end
        end

        self.EnemyIntel.EnemyThreatCurrent.Air = enemyAirThreat
        self.EnemyIntel.EnemyThreatCurrent.AntiAir = enemyAntiAirThreat
        self.EnemyIntel.EnemyThreatCurrent.AirSurface = enemyAirSurfaceThreat
        self.EnemyIntel.EnemyThreatCurrent.Extractor = enemyExtractorthreat
        self.EnemyIntel.EnemyThreatCurrent.ExtractorCount = enemyExtractorCount
        self.EnemyIntel.EnemyThreatCurrent.Naval = enemyNavalThreat
        self.EnemyIntel.EnemyThreatCurrent.NavalSub = enemyNavalSubThreat
        self.EnemyIntel.EnemyThreatCurrent.Land = enemyLandThreat
        self.EnemyIntel.EnemyThreatCurrent.DefenseAir = enemyDefenseAir
        self.EnemyIntel.EnemyThreatCurrent.DefenseSurface = enemyDefenseSurface
        self.EnemyIntel.EnemyThreatCurrent.DefenseSub = enemyDefenseSub
        --RNGLOG('Completing Threat Check'..GetGameTick())
    end,

    SelfThreatCheckRNG = function(self, ALLBPS)
        -- Get AI strength
        local selfIndex = self:GetArmyIndex()
        local GetPosition = moho.entity_methods.GetPosition
        coroutine.yield(1)
        local allyBrains = {}
        for index, brain in ArmyBrains do
            if index ~= self:GetArmyIndex() then
                if IsAlly(selfIndex, brain:GetArmyIndex()) then
                    RNGINSERT(allyBrains, brain)
                end
            end
        end
        local allyExtractors = {}
        local allyExtractorCount = 0
        local allyExtractorthreat = 0
        local allyLandThreat = 0
        local allyAirThreat = 0
        local allyAntiAirThreat = 0
        local allyNavalThreat = 0
        local unitCat
        --RNGLOG('Number of Allies '..RNGGETN(allyBrains))
        coroutine.yield(1)
        if not RNGTableEmpty(allyBrains) then
            for k, ally in allyBrains do
                local allyExtractorList = GetListOfUnits( ally, categories.STRUCTURE * categories.MASSEXTRACTION, false, false)
                for _,v in allyExtractorList do
                    if not v.Dead then
                        unitCat = v.Blueprint.CategoriesHash
                        if not v.zoneid and self.ZonesInitialized then
                            --LOG('unit has no zone')
                            local mexPos = GetPosition(v)
                            if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                                -- tbd define water based zones
                                v.zoneid = MAP:GetZoneID(v.position,self.Zones.Naval.index)
                            else
                                v.zoneid = MAP:GetZoneID(mexPos,self.Zones.Land.index)
                                --LOG('Unit zone is '..unit.zoneid)
                            end
                        end
                        if not allyExtractors[v.zoneid] then
                            --LOG('Trying to add unit to zone')
                            allyExtractors[v.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                        end
                        if unitCat.TECH1 then
                            allyExtractors[v.zoneid].T1=allyExtractors[v.zoneid].T1+1
                        elseif unitCat.TECH2 then
                            allyExtractors[v.zoneid].T2=allyExtractors[v.zoneid].T2+1
                        elseif unitCat.TECH3 then
                            allyExtractors[v.zoneid].T3=allyExtractors[v.zoneid].T3+1
                        end

                        allyExtractorthreat = allyExtractorthreat + v.Blueprint.Defense.EconomyThreatLevel
                        allyExtractorCount = allyExtractorCount + 1
                    end
                end
                local allyLandList = GetListOfUnits( ally, categories.MOBILE * categories.LAND * (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.COMMAND , false, false)
                
                for _,v in allyLandList do
                    allyLandThreat = allyLandThreat + v.Blueprint.Defense.SurfaceThreatLevel
                end

                local allyAirList = GetListOfUnits( ally, categories.MOBILE * categories.AIR , false, false)
                
                for _,v in allyAirList do
                    allyAirThreat = allyAirThreat + v.Blueprint.Defense.AirThreatLevel
                    if v.Blueprint.CategoriesHash.ANTIAIR then
                        allyAntiAirThreat = allyAntiAirThreat + v.Blueprint.Defense.AirThreatLevel
                    end
                end

                local allyNavalList = GetListOfUnits( ally, categories.MOBILE * categories.NAVAL , false, false)
                
                for _,v in allyNavalList do
                    allyNavalThreat = allyNavalThreat + (v.Blueprint.Defense.SurfaceThreatLevel + v.Blueprint.Defense.SubThreatLevel)
                end
            end
        end
        self.BrainIntel.SelfThreat.AllyExtractorTable = allyExtractors
        self.BrainIntel.SelfThreat.AllyExtractorCount = allyExtractorCount + self.BrainIntel.SelfThreat.ExtractorCount
        self.BrainIntel.SelfThreat.AllyExtractor = allyExtractorthreat + self.BrainIntel.SelfThreat.Extractor
        self.BrainIntel.SelfThreat.AllyLandThreat = allyLandThreat
        self.BrainIntel.SelfThreat.AllyAirThreat = allyAirThreat
        self.BrainIntel.SelfThreat.AllyAntiAirThreat = allyAntiAirThreat
        self.BrainIntel.SelfThreat.AllyNavalThreat = allyNavalThreat
        --RNGLOG('AllyExtractorCount is '..self.BrainIntel.SelfThreat.AllyExtractorCount)
        --RNGLOG('SelfExtractorCount is '..self.BrainIntel.SelfThreat.ExtractorCount)
        --RNGLOG('AllyExtractorThreat is '..self.BrainIntel.SelfThreat.AllyExtractor)
        --RNGLOG('SelfExtractorThreat is '..self.BrainIntel.SelfThreat.Extractor)
        coroutine.yield(1)
    end,

    IMAPConfigurationRNG = function(self)
        -- Used to configure imap values, used for setting threat ring sizes depending on map size to try and get a somewhat decent radius
        local maxmapdimension = math.max(ScenarioInfo.size[1],ScenarioInfo.size[2])

        if maxmapdimension == 256 then
            self.BrainIntel.IMAPConfig.OgridRadius = 22.5
            self.BrainIntel.IMAPConfig.IMAPSize = 32
            self.BrainIntel.IMAPConfig.Rings = 2
        elseif maxmapdimension == 512 then
            self.BrainIntel.IMAPConfig.OgridRadius = 22.5
            self.BrainIntel.IMAPConfig.IMAPSize = 32
            self.BrainIntel.IMAPConfig.Rings = 2
        elseif maxmapdimension == 1024 then
            self.BrainIntel.IMAPConfig.OgridRadius = 45.0
            self.BrainIntel.IMAPConfig.IMAPSize = 64
            self.BrainIntel.IMAPConfig.Rings = 1
        elseif maxmapdimension == 2048 then
            self.BrainIntel.IMAPConfig.OgridRadius = 89.5
            self.BrainIntel.IMAPConfig.IMAPSize = 128
            self.BrainIntel.IMAPConfig.Rings = 0
        else
            self.BrainIntel.IMAPConfig.OgridRadius = 180.0
            self.BrainIntel.IMAPConfig.IMAPSize = 256
            self.BrainIntel.IMAPConfig.Rings = 0
        end
        self.IMAPConfig = {}
        self.IMAPConfig.Rings = self.BrainIntel.IMAPConfig.Rings
    end,

    TacticalMonitorRNG = function(self, ALLBPS)
        -- Tactical Monitor function. Keeps an eye on the battlefield and takes points of interest to investigate.
        coroutine.yield(Random(1,7))
        --RNGLOG('* AI-RNG: Tactical Monitor Threat Pass')
        local enemyBrains = {}
        local multiplier
        local enemyStarts = self.EnemyIntel.EnemyStartLocations
        local factionIndex = self:GetFactionIndex()
        local startX, startZ = self:GetArmyStartPos()
        --RNGLOG('Upgrade Mode is  '..self.UpgradeMode)
        if self.CheatEnabled then
            multiplier = self.EcoManager.EcoMultiplier
        else
            multiplier = 1
        end
        local gameTime = GetGameTimeSeconds()
        --RNGLOG('gameTime is '..gameTime..' Upgrade Mode is '..self.UpgradeMode)
        if self.BrainIntel.SelfThreat.AirNow < (self.EnemyIntel.EnemyThreatCurrent.Air / self.EnemyIntel.EnemyCount) then
            --RNGLOG('Less than enemy air threat, increase mobile aa numbers')
            self.amanager.Ratios[factionIndex].Land.T1.aa = 15
            self.amanager.Ratios[factionIndex].Land.T2.aa = 15
            self.amanager.Ratios[factionIndex].Land.T2.aa = 15
        else
            --RNGLOG('More than enemy air threat, decrease mobile aa numbers')
            self.amanager.Ratios[factionIndex].Land.T1.aa = 5
            self.amanager.Ratios[factionIndex].Land.T2.aa = 5
            self.amanager.Ratios[factionIndex].Land.T2.aa = 5
        end

        local selfIndex = self:GetArmyIndex()
        local potentialThreats = {}
        local threatTypes = {
            'Land',
            'AntiAir',
            'Air',
            'Naval',
            'StructuresNotMex',
            'Experimental',
            'AntiSurface'
        }
        local threatTotals = {
            Air = 0,
            AntiAir = 0,
            AntiSurface = 0,
            Experimental = 0,
            StructuresNotMex = 0,
            Naval = 0,
            Land = 0,
        }
        -- Get threats for each threat type listed on the threatTypes table. Full map scan.
        local currentGameTime = GetGameTimeSeconds()
        local eThreatLocations = self.EnemyIntel.EnemyThreatLocations

        for _, t in threatTypes do
            local rawThreats = GetThreatsAroundPosition(self, self.BuilderManagers.MAIN.Position, 16, true, t)
            for _, raw in rawThreats do
                local position = {raw[1], GetSurfaceHeight(raw[1], raw[2]),raw[2]}
                if not eThreatLocations[raw[1]] then
                    eThreatLocations[raw[1]] = {}
                end
                if not eThreatLocations[raw[1]][raw[2]] then
                    eThreatLocations[raw[1]][raw[2]] = {}
                end
                eThreatLocations[raw[1]] = eThreatLocations[raw[1]] or { }
                eThreatLocations[raw[1]][raw[2]] = eThreatLocations[raw[1]][raw[2]] or { }
                eThreatLocations[raw[1]][raw[2]][t] = raw[3]
                eThreatLocations[raw[1]][raw[2]].Position = eThreatLocations[raw[1]][raw[2]].Position or position
                eThreatLocations[raw[1]][raw[2]].UpdateTime = currentGameTime
                --local threatRow = {posX=raw[1], posZ=raw[2], rThreat=raw[3], rThreatType=t}
                threatTotals[t] = threatTotals[t] + raw[3]
                --RNGINSERT(potentialThreats, threatRow)
            end
            coroutine.yield(1)
        end
        --RNGLOG('Threat Table')
        --RNGLOG(repr(potentialThreats))
        --RNGLOG('Potential Threats :'..repr(potentialThreats))
        --LOG('Threat Totals in tactical monitor '..repr(threatTotals))
        coroutine.yield(2)
        local phaseTwoThreats = {}
        local threatLimit = 20

        -- Remove threats that are too close to the enemy base so we are focused on whats happening in the battlefield.
        -- Also set if the threat is on water or not
        -- Set the time the threat was identified so we can flush out old entries
        if not RNGTableEmpty(eThreatLocations) then
            for _, x in eThreatLocations do
                for _, z in x do
                    --RNGLOG('* AI-RNG: Threat is'..repr(threat))
                    if not z.PositionOnWater then
                        --RNGLOG('* AI-RNG: Tactical Potential Interest Location Found at :'..repr(threat))
                        if RUtils.PositionOnWater(z.Position) then
                            z.PositionOnWater = true
                        else
                            z.PositionOnWater = false
                            if not z.LandLabel then
                                z.LandLabel = NavUtils.GetLabel('Land', z.Position) or 0
                                --LOG('Land Label from threats set as '..z.LandLabel)
                            end
                        end
                    end
                end
            end
            --RNGLOG('* AI-RNG: second table pass :'..repr(potentialThreats))
            --RNGLOG('* AI-RNG: Final Valid Threat Locations :'..repr(self.EnemyIntel.EnemyThreatLocations))
        end
        coroutine.yield(2)
    end,

    CheckDirectorTargetAvailable = function(self, threatType, platoonThreat, platoonType, strikeDamage, platoonDPS, platoonPosition)
        local potentialTarget = false
        local targetType = false
        local potentialTargetValue = 0
        local requiredCount = 0
        local enemyACUIndexes = {}
        local im = IntelManagerRNG.GetIntelManager(self)

        if platoonType == 'GUNSHIP' or platoonType == 'BOMBER' then
            for k, v in self.TacticalMonitor.TacticalMissions.ACUSnipe do
                if v.AIR and v.AIR.GameTime and v.AIR.GameTime + 300 > GetGameTimeSeconds() then
                    if RUtils.HaveUnitVisual(self, self.EnemyIntel.ACU[k].Unit, true) then
                        if self.EnemyIntel.ACU[k].HP > 0 then
                            local acuHP = self.EnemyIntel.ACU[k].HP
                            if platoonType == 'GUNSHIP' and platoonDPS then
                                if ((acuHP / platoonDPS) < 15 or acuHP < 2500) then
                                    potentialTarget = self.EnemyIntel.ACU[k].Unit
                                    requiredCount = v.AIR.CountRequired
                                    break
                                end
                            elseif platoonType == 'BOMBER' and strikeDamage then
                                if strikeDamage > acuHP * 0.80 or acuHP < 2500 then
                                    potentialTarget = self.EnemyIntel.ACU[k].Unit
                                    requiredCount = v.AIR.CountRequired
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
            
        if not potentialTarget then
            for k, v in self.EnemyIntel.ACU do
                if not v.Ally and v.HP ~= 0 and v.LastSpotted ~= 0 then
                    if platoonType == 'GUNSHIP' and platoonDPS then
                        if ((v.HP / platoonDPS) < 15 or v.HP < 2000) and v.LastSpotted + 120 < GetGameTimeSeconds() then
                            RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position } )
                            --RNGLOG('ACU Added to target check in director')
                            local gridX, gridY = im:GetIntelGrid(v.Position)
                            local scoutRequired = true
                            if im.MapIntelGrid[gridX][gridY].MustScout and im.MapIntelGrid[gridX][gridY].ACUIndexes[k] then
                                scoutRequired = false
                            end
                            if scoutRequired then
                                im.MapIntelGrid[gridX][gridY].MustScout = true
                                im.MapIntelGrid[gridX][gridY].ACUIndexes[k] = true
                                --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(im.MapIntelGrid[gridX][gridY]))
                            end
                        end
                    elseif platoonType == 'BOMBER' and strikeDamage then
                        if (self.CDRUnit.Caution and self.CDRUnit.EnemyCDRPresent and VDist3Sq(v.Position, self.BrainIntel.StartPos) < (self.EnemyIntel.ClosestEnemyBase /2)) or self.BrainIntel.SuicideModeActive then
                            RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position })
                            local gridX, gridY = im:GetIntelGrid(v.Position)
                            local scoutRequired = true
                            if im.MapIntelGrid[gridX][gridY].MustScout and im.MapIntelGrid[gridX][gridY].ACUIndexes[k] then
                                scoutRequired = false
                            end
                            if scoutRequired then
                                im.MapIntelGrid[gridX][gridY].MustScout = true
                                im.MapIntelGrid[gridX][gridY].ACUIndexes[k] = true
                                --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(im.MapIntelGrid[gridX][gridY]))
                            end
                        elseif strikeDamage > v.HP * 0.80 then
                            RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position })
                            local gridX, gridY = im:GetIntelGrid(v.Position)
                            local scoutRequired = true
                            if im.MapIntelGrid[gridX][gridY].MustScout and im.MapIntelGrid[gridX][gridY].ACUIndexes[k] then
                                scoutRequired = false
                            end
                            if scoutRequired then
                                im.MapIntelGrid[gridX][gridY].MustScout = true
                                im.MapIntelGrid[gridX][gridY].ACUIndexes[k] = true
                                --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(im.MapIntelGrid[gridX][gridY]))
                            end
                        end
                    elseif platoonType == 'SATELLITE' and platoonDPS then
                        if ((v.HP / platoonDPS) < 15 or v.HP < 2000) and v.LastSpotted + 120 < GetGameTimeSeconds() then
                            if RUtils.HaveUnitVisual(self, v.Unit, true) then
                                local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Position, 46, 'Enemy')
                                LOG('Director total shield health from acu check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                                if (totalShieldHealth / platoonDPS) < 12 then
                                    RNGINSERT(enemyACUIndexes, { Index = k, Position = v.Position } )
                                    local gridX, gridY = im:GetIntelGrid(v.Position)
                                    local scoutRequired = true
                                    if im.MapIntelGrid[gridX][gridY].MustScout and im.MapIntelGrid[gridX][gridY].ACUIndexes[k] then
                                        scoutRequired = false
                                    end
                                    if scoutRequired then
                                        im.MapIntelGrid[gridX][gridY].MustScout = true
                                        im.MapIntelGrid[gridX][gridY].ACUIndexes[k] = true
                                        --RNGLOG('ScoutRequired for EnemyIntel.ACU '..repr(im.MapIntelGrid[gridX][gridY]))
                                    end
                                end
                            end
                        end
                        for _, v in self.EnemyIntel.Experimental do
                            if v.object and not v.object.Dead then
                                local unitCats = v.object.Blueprint.CategoriesHash
                                if unitCats.MOBILE and unitCats.LAND and not RUtils.ShieldProtectingTargetRNG(self, v.object, nil) then
                                    potentialTarget = v.object
                                    potentialTargetValue = 5000
                                end
                            end
                        end
                    end
                end
            end

            if not RNGTableEmpty(enemyACUIndexes) then
                for k, v in enemyACUIndexes do
                    if RUtils.HaveUnitVisual(self, self.EnemyIntel.ACU[v.Index].Unit, true) then
                        potentialTarget = self.EnemyIntel.ACU[v.Index].Unit
                        potentialTargetValue = 10000
                        --RNGLOG('Enemy ACU returned as potential target for Director')
                    end
                end
            end
        end
        local shieldedUnits = {}
        

        if not potentialTarget then
            if self.RNGDEBUG then
                RNGLOG('Director searching for EnemyIntel Target')
            end
            if self.EnemyIntel.DirectorData.Intel and not RNGTableEmpty(self.EnemyIntel.DirectorData.Intel) then
                if self.RNGDEBUG then
                    RNGLOG('Director looking at intel table')
                    RNGLOG('Director number of intel items '..table.getn(self.EnemyIntel.DirectorData.Intel))
                end
                for k, v in self.EnemyIntel.DirectorData.Intel do
                    --RNGLOG('Intel Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    local shielded = false
                    if (platoonType == 'SATELLITE' or platoonType == 'GUNSHIP') and platoonDPS then
                        local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Object:GetPosition(), 46, 'Enemy')
                        LOG('Director total shield health from intel check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                        if (totalShieldHealth / platoonDPS) > 12 then
                            shielded = true
                        end
                    elseif RUtils.ShieldProtectingTargetRNG(self, v.Object, nil) then
                        table.insert(shieldedUnits, v)
                        shielded = true
                    end

                    if v.Value > potentialTargetValue and v.Object and (not v.Object.Dead) and not shielded then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        --RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        --RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                    --RNGLOG('This air platoon had no platoonDPS value')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Energy and not RNGTableEmpty(self.EnemyIntel.DirectorData.Energy) then
                if self.RNGDEBUG then
                    RNGLOG('Director looking at energy table')
                    RNGLOG('Director number of energy items '..table.getn(self.EnemyIntel.DirectorData.Intel))
                end
                for k, v in self.EnemyIntel.DirectorData.Energy do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    local shielded = false
                    if (platoonType == 'SATELLITE' or platoonType == 'GUNSHIP') and platoonDPS then
                        local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Object:GetPosition(), 46, 'Enemy')
                        LOG('Director total shield health from energy check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                        if (totalShieldHealth / platoonDPS) > 12 then
                            shielded = true
                        end
                    elseif RUtils.ShieldProtectingTargetRNG(self, v.Object, nil) then
                        table.insert(shieldedUnits, v)
                        shielded = true
                    end
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and not shielded then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        --RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        --RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    --RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Factory and not RNGTableEmpty(self.EnemyIntel.DirectorData.Factory) then
                if self.RNGDEBUG then
                    RNGLOG('Director looking at factory table')
                    RNGLOG('Director number of factory items '..table.getn(self.EnemyIntel.DirectorData.Factory))
                end
                for k, v in self.EnemyIntel.DirectorData.Factory do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    local shielded = false
                    if (platoonType == 'SATELLITE' or platoonType == 'GUNSHIP') and platoonDPS then
                        local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Object:GetPosition(), 46, 'Enemy')
                        LOG('Director total shield health from factory check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                        if (totalShieldHealth / platoonDPS) > 12 then
                            shielded = true
                        end
                    elseif RUtils.ShieldProtectingTargetRNG(self, v.Object, nil) then
                        table.insert(shieldedUnits, v)
                        shielded = true
                    end
                    
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and not shielded then
                        local unitCats = v.Object.Blueprint.CategoriesHash
                        if unitCats.TECH2 or unitCats.TECH3 then
                            if threatType and platoonThreat then
                                if threatType == 'AntiAir' then
                                    if v.Air > platoonThreat then
                                        continue
                                    end
                                    if platoonType == 'BOMBER' and strikeDamage then
                                        if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                            --RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                            continue
                                        end
                                    elseif platoonType == 'GUNSHIP' and platoonDPS then
                                        if (v.HP / platoonDPS) > 15 then
                                            --RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                            continue
                                        end
                                    else
                                        --RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                    end
                                elseif threatType == 'Land' then
                                    if v.Land > platoonThreat then
                                        continue
                                    end
                                end
                            end
                            potentialTargetValue = v.Value
                            potentialTarget = v.Object
                        end
                    end
                end
            end
            if self.EnemyIntel.DirectorData.Strategic and not RNGTableEmpty(self.EnemyIntel.DirectorData.Strategic) then
                if self.RNGDEBUG then
                    RNGLOG('Director looking at strategic table')
                    RNGLOG('Director number of strategic items '..table.getn(self.EnemyIntel.DirectorData.Strategic))
                end
                for k, v in self.EnemyIntel.DirectorData.Strategic do
                    --RNGLOG('Energy Target Data ')
                    --RNGLOG('Air Threat Around unit is '..v.Air)
                    --RNGLOG('Land Threat Around unit is '..v.Land)
                    --RNGLOG('Enemy Index of unit is '..v.EnemyIndex)
                    --RNGLOG('Unit ID is '..v.Object.UnitId)
                    local shielded = false
                    if (platoonType == 'SATELLITE' or platoonType == 'GUNSHIP') and platoonDPS then
                        local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Object:GetPosition(), 46, 'Enemy')
                        LOG('Director total shield health from strategic check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                        if (totalShieldHealth / platoonDPS) > 12 then
                            shielded = true
                        end
                    elseif RUtils.ShieldProtectingTargetRNG(self, v.Object, nil) then
                        table.insert(shieldedUnits, v)
                        shielded = true
                    end
                    if v.Value > potentialTargetValue and v.Object and not v.Object.Dead and not shielded then
                        if threatType and platoonThreat then
                            if threatType == 'AntiAir' then
                                if v.Air > platoonThreat then
                                    continue
                                end
                                if platoonType == 'BOMBER' and strikeDamage then
                                    if strikeDamage > 0 and v.HP / 3 > strikeDamage then
                                        --RNGLOG('Not enough strike damage HP vs strikeDamage '..v.HP..' '..strikeDamage)
                                        continue
                                    end
                                elseif platoonType == 'GUNSHIP' and platoonDPS then
                                    if (v.HP / platoonDPS) > 15 then
                                        --RNGLOG('Not enough dps to kill in under 10 seconds '..v.HP..' '..platoonDPS)
                                        continue
                                    end
                                else
                                    --RNGLOG('This Air platoon had no gunship or bomber value set wtf')
                                end
                            elseif threatType == 'Land' then
                                if v.Land > platoonThreat then
                                    continue
                                end
                            end
                        end
                        potentialTargetValue = v.Value
                        potentialTarget = v.Object
                    end
                end
            end
        end
        if self.RNGDEBUG then
            RNGLOG('Director no target after EnemyIntel Check')
        end
        if not potentialTarget then
            local closestMex = false
            local airThreat = false
            local targetSelected = false
            for i=im.MapIntelGridXMin, im.MapIntelGridXMax do
                for k=im.MapIntelGridZMin, im.MapIntelGridZMax do
                    if not RNGTableEmpty(im.MapIntelGrid[i][k].EnemyUnits) then
                        for k, v in im.MapIntelGrid[i][k].EnemyUnits do
                            if v.type == 'mex' and not v.object.Dead then
                                if EntityCategoryContains(categories.TECH2 + categories.TECH3, v.object) then
                                    if platoonType == 'BOMBER' and strikeDamage and strikeDamage > 0 and v.object:GetHealth() / 3 < strikeDamage then
                                        local positionThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, threatType)
                                        if not airThreat or positionThreat < airThreat then
                                            airThreat = positionThreat
                                            closestMex = v.object
                                            if airThreat == 0 then
                                                targetSelected = true
                                                break
                                            end
                                        end
                                    elseif platoonType == 'GUNSHIP' and platoonDPS and (v.object:GetHealth() / platoonDPS) <= 15 then
                                        local positionThreat = GetThreatAtPosition(self, v.Position, self.BrainIntel.IMAPConfig.Rings, true, threatType)
                                        if not airThreat or positionThreat < airThreat then
                                            airThreat = positionThreat
                                            closestMex = v.object
                                            if airThreat == 0 then
                                                targetSelected = true
                                                break
                                            end
                                        end
                                    elseif platoonType == 'SATELLITE' and platoonDPS then
                                        if RUtils.HaveUnitVisual(self, v.object, true) then
                                            local shielded = false
                                            local totalShieldHealth = RUtils.GetShieldHealthAroundPosition(self, v.Object:GetPosition(), 46, 'Enemy')
                                            LOG('Director total shield health from extractor check '..tostring(totalShieldHealth)..' platoonDPS '..tostring(platoonDPS))
                                            if (totalShieldHealth / platoonDPS) > 12 then
                                                shielded = true
                                            end
                                            if not shielded then
                                                closestMex = v.object
                                                targetSelected = true
                                                break
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if targetSelected then
                        break
                    end
                end
                if targetSelected then
                    break
                end
            end
            if closestMex then
                --RNGLOG('We have a mex to target from the director')
                potentialTarget = closestMex
            else
                if self.RNGDEBUG then
                    RNGLOG('Director no target after mex Check')
                end
            end
        end
        if potentialTarget and not potentialTarget.Dead then
           --RNGLOG('Target being returned is '..potentialTarget.UnitId)
            if strikeDamage then
               --RNGLOG('Strike Damage for target is '..strikeDamage)
            else
               --RNGLOG('No Strike Damage was passed for this target strike')
            end
            return potentialTarget
        else
            --do things with shieldedUnits here to try and get another target but it will require measuring shield numbers and health vs platoon dps
            if self.RNGDEBUG then
                RNGLOG('Director no target after director search')
            end
        end
        return false
    end,

    EcoMassManagerRNG = function(self)
    -- Watches for low power states
        coroutine.yield(Random(1,7))
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 150 then
                    coroutine.yield(50)
                    continue
                end
                local massStateCaution, deficit = self:EcoManagerMassStateCheck()
                local unitTypePaused = false
                
                if massStateCaution then
                    --LOG('Mass Deficit at start is '..tostring(deficit))
                    --RNGLOG('massStateCaution State Caution is true')
                    local massCycle = 0
                    local unitTypePaused = {}
                    local resourcesSaved = 0
                    while massStateCaution do
                        local massPriorityTable = {}
                        local priorityNum = 0
                        local priorityUnit = false
                        --RNGLOG('Threat Stats Self + ally :'..self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat..'Enemy : '..self.EnemyIntel.EnemyThreatCurrent.Land)
                        massPriorityTable = self.EcoManager.MassPriorityTable
                        if (self.BrainIntel.SelfThreat.LandNow + self.BrainIntel.SelfThreat.AllyLandThreat) > (self.EnemyIntel.EnemyThreatCurrent.Land * 1.1) and self.BasePerimeterMonitor['MAIN'].LandUnits < 1 then
                            massPriorityTable.LAND_TECH1 = 12
                            massPriorityTable.LAND_TECH2 = 9
                            massPriorityTable.LAND_TECH3 = 6
                        else
                            massPriorityTable.LAND_TECH1 = nil
                            massPriorityTable.LAND_TECH2 = nil
                            massPriorityTable.LAND_TECH3 = nil
                        end
                        if (self.BrainIntel.SelfThreat.AirNow + self.BrainIntel.SelfThreat.AllyAirThreat) > (self.EnemyIntel.EnemyThreatCurrent.Air * 1.1) or self.CDRUnit.Caution then
                            massPriorityTable.AIR_TECH1 = 13
                            massPriorityTable.AIR_TECH2 = 10
                            massPriorityTable.AIR_TECH3 = 7
                        else
                            massPriorityTable.AIR_TECH1 = nil
                            massPriorityTable.AIR_TECH2 = nil
                            massPriorityTable.AIR_TECH3 = nil
                        end
                        if (self.BrainIntel.SelfThreat.NavalNow + self.BrainIntel.SelfThreat.AllyNavalThreat) > (self.EnemyIntel.EnemyThreatCurrent.Naval * 1.1) then
                            --LOG('My naval threat is higher so well pause naval factories mine is :'..tostring(self.BrainIntel.SelfThreat.NavalNow))
                            --LOG('Allies is '..tostring(self.BrainIntel.SelfThreat.AllyNavalThreat))
                            --LOG('enemies is :'..tostring((self.EnemyIntel.EnemyThreatCurrent.Naval * 1.1)))
                            massPriorityTable.NAVAL_TECH1 = 14
                            massPriorityTable.NAVAL_TECH2 = 11
                            massPriorityTable.NAVAL_TECH3 = 8
                        else
                            massPriorityTable.NAVAL_TECH1 = nil
                            massPriorityTable.NAVAL_TECH2 = nil
                            massPriorityTable.NAVAL_TECH3 = nil
                        end
                        massCycle = massCycle + 1
                        for k, v in massPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --RNGLOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v and v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --RNGLOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'MASS')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'AIR_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.AIR) * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'LAND_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'NAVAL_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'MASS')
                        elseif priorityUnit == 'MASSEXTRACTION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            --RNGLOG('Number of mass extractors'..RNGGETN(Extractors))
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Extractors, 'pause', 'MASS')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'MASS')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'MASS')
                        end
                        massStateCaution = self:EcoManagerMassStateCheck()
                        deficit = math.max(deficit - resourcesSaved, 0)
                        --LOG('Mass Resources saved on this loop '..tostring(resourcesSaved))
                        --LOG('Mass Deficit during loop is now '..tostring(deficit))
                        if resourcesSaved >= deficit then
                            coroutine.yield(15)
                            massStateCaution = self:EcoManagerMassStateCheck()
                            --LOG('We should be out of our mass stall, checked again and powerStateCaution is '..tostring(massStateCaution))
                        end
                        if massStateCaution then
                            --RNGLOG('Power State Caution still true after first pass')
                            if massCycle > 8 then
                                --RNGLOG('Power Cycle Threashold met, waiting longer')
                                coroutine.yield(100)
                                massCycle = 0
                            end
                        else
                            --RNGLOG('Power State Caution is now false')
                        end
                        coroutine.yield(5)
                        --RNGLOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'MASS')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'MASS')
                        elseif v == 'AIR_TECH1' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'AIR_TECH2' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'AIR_TECH3' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'MASS')
                        elseif v == 'LAND_TECH1' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'LAND_TECH2' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'LAND_TECH3' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL_TECH1' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL_TECH2' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'NAVAL_TECH3' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'MASS')
                        elseif v == 'MASSEXTRACTION' then
                            local Extractors = GetListOfUnits(self, categories.STRUCTURE * categories.MASSEXTRACTION - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Extractors, 'unpause', 'MASS')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'MASS')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'MASS')
                        end
                    end
                    massStateCaution = false
                end
            end
            coroutine.yield(20)
        end
    end,

    EcoManagerMassStateCheck = function(self)
        if GetEconomyTrend(self, 'MASS') <= 0.0 and GetEconomyStored(self, 'MASS') <= 150 then
            local deficit =  GetEconomyRequested(self,'MASS') - GetEconomyIncome(self,'MASS')
            return true, deficit
        end
        return false
    end,

    EcoManagerPowerStateCheck = function(self)
        if (GetEconomyTrend(self, 'ENERGY') <= 0.0 and GetEconomyStoredRatio(self, 'ENERGY') <= 0.2) or ((self.CDRUnit.Caution or self.BrainIntel.SuicideModeActive) and (GetEconomyStored(self, 'ENERGY') <= 3500 or GetCurrentUnits(self, categories.STRUCTURE * categories.ENERGYSTORAGE) > 0 and GetEconomyStored(self, 'ENERGY') <= 7000)) then
            local deficit = GetEconomyRequested(self,'ENERGY') - GetEconomyIncome(self,'ENERGY')
            return true, deficit
        end
        return false
    end,
    
    EcoPowerManagerRNG = function(self)
        -- Watches for low power states
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                if GetGameTimeSeconds() < 150 then
                    coroutine.yield(50)
                    continue
                end
                local powerStateCaution, deficit = self:EcoManagerPowerStateCheck()
                local unitTypePaused = false
                
                if powerStateCaution then
                    --RNGLOG('Power State Caution is true')
                    --LOG('Power Deficit at start is '..tostring(deficit))
                    self.EngineerAssistManagerFocusPower = true
                    local powerCycle = 0
                    local unitTypePaused = {}
                    local resourcesSaved = 0
                    while powerStateCaution do
                        local priorityNum = 0
                        local priorityUnit = false
                        local runningDeficit = 0
                        powerCycle = powerCycle + 1
                        for k, v in self.EcoManager.PowerPriorityTable do
                            local priorityUnitAlreadySet = false
                            for l, b in unitTypePaused do
                                if k == b then
                                    priorityUnitAlreadySet = true
                                end
                            end
                            if priorityUnitAlreadySet then
                                --RNGLOG('priorityUnit already in unitTypePaused, skipping')
                                continue
                            end
                            if v > priorityNum then
                                priorityNum = v
                                priorityUnit = k
                            end
                        end
                        --RNGLOG('Doing anti power stall stuff for :'..priorityUnit)
                        if priorityUnit == 'ENGINEER' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            --RNGLOG('Engineer added to unitTypePaused')
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND , false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause', 'ENERGY')
                        elseif priorityUnit == 'STATIONPODS' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, StationPods, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'AIR_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'LAND_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local LandFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.LAND) * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, LandFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL_TECH1' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH1, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL_TECH2' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH2, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NAVAL_TECH3' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local NavalFactories = GetListOfUnits(self, (categories.STRUCTURE * categories.FACTORY * categories.NAVAL) * categories.TECH3, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, NavalFactories, 'pause', 'ENERGY')
                        elseif priorityUnit == 'SHIELD' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Shields, 'pause', 'ENERGY')
                        elseif priorityUnit == 'TML' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, TMLs, 'pause', 'ENERGY')
                        elseif priorityUnit == 'RADAR' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Radars = GetListOfUnits(self, categories.STRUCTURE * (categories.RADAR + categories.SONAR), false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Radars, 'pause', 'ENERGY')
                        elseif priorityUnit == 'MASSFABRICATION' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, MassFabricators, 'pause', 'ENERGY')
                        elseif priorityUnit == 'NUKE' then
                            local unitAlreadySet = false
                            for k, v in unitTypePaused do
                                if priorityUnit == v then
                                    unitAlreadySet = true
                                end
                            end
                            if not unitAlreadySet then
                                RNGINSERT(unitTypePaused, priorityUnit)
                            end
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            resourcesSaved = resourcesSaved + self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause', 'ENERGY')
                        end
                        coroutine.yield(5)
                        powerStateCaution = self:EcoManagerPowerStateCheck()
                        deficit = math.max(deficit - resourcesSaved, 0)
                        --LOG('Energy Resources saved on this loop '..tostring(resourcesSaved))
                        --LOG('Energy Deficit during loop is now '..tostring(deficit))
                        if resourcesSaved >= deficit then
                            coroutine.yield(15)
                            powerStateCaution = self:EcoManagerPowerStateCheck()
                            --LOG('We should be out of our power stall, checked again and powerStateCaution is '..tostring(powerStateCaution))
                        end
                        if powerStateCaution then
                            --RNGLOG('Power State Caution still true after first pass')
                            if powerCycle > 11 then
                                --RNGLOG('Power Cycle Threashold met, waiting longer')
                                coroutine.yield(100)
                                powerCycle = 0
                            end
                        end
                        --RNGLOG('unitTypePaused table is :'..repr(unitTypePaused))
                    end
                    for k, v in unitTypePaused do
                        if v == 'ENGINEER' then
                            local Engineers = GetListOfUnits(self, ( categories.ENGINEER + categories.SUBCOMMANDER ) - categories.STATIONASSISTPOD - categories.COMMAND, false, false)
                            self:EcoSelectorManagerRNG(v, Engineers, 'unpause', 'ENERGY')
                        elseif v == 'STATIONPODS' then
                            local StationPods = GetListOfUnits(self, categories.STATIONASSISTPOD, false, false)
                            self:EcoSelectorManagerRNG(v, StationPods, 'unpause', 'ENERGY')
                        elseif v == 'AIR_TECH1' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'AIR_TECH2' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'AIR_TECH3' then
                            local AirFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, AirFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND_TECH1' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND_TECH2' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'LAND_TECH3' then
                            local LandFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, LandFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL_TECH1' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL_TECH2' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'NAVAL_TECH3' then
                            local NavalFactories = GetListOfUnits(self, categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3, false, false)
                            self:EcoSelectorManagerRNG(v, NavalFactories, 'unpause', 'ENERGY')
                        elseif v == 'SHIELD' then
                            local Shields = GetListOfUnits(self, categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                            self:EcoSelectorManagerRNG(v, Shields, 'unpause', 'ENERGY')
                        elseif v == 'MASSFABRICATION' then
                            local MassFabricators = GetListOfUnits(self, categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                            self:EcoSelectorManagerRNG(v, MassFabricators, 'unpause', 'ENERGY')
                        elseif v == 'RADAR' then
                            local Radars = GetListOfUnits(self, categories.STRUCTURE * (categories.RADAR + categories.SONAR + categories.OMNI), false, false)
                            self:EcoSelectorManagerRNG(v, Radars, 'unpause', 'ENERGY')
                        elseif v == 'NUKE' then
                            local Nukes = GetListOfUnits(self, categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                            self:EcoSelectorManagerRNG(v, Nukes, 'unpause', 'ENERGY')
                        elseif v == 'TML' then
                            local TMLs = GetListOfUnits(self, categories.STRUCTURE * categories.TACTICALMISSILEPLATFORM, false, false)
                            self:EcoSelectorManagerRNG(v, TMLs, 'unpause', 'ENERGY')
                        end
                    end
                    powerStateCaution = false
                else
                    self.EngineerAssistManagerFocusPower = false
                end
            end
            coroutine.yield(20)
        end
    end,

    EcoPowerPreemptiveRNG = function(self)
        local function GetMissileConsumption(ALLBPS, unitId, buildMultiplier)
            if ALLBPS[unitId].Weapon[1].ProjectileId then
                local projBp = ALLBPS[unitId].Weapon[1].ProjectileId
                --RNGLOG('EcoPowerPreemptive return consumption number is '..(ALLBPS[projBp].Economy.BuildCostEnergy / ALLBPS[projBp].Economy.BuildTime * (ALLBPS[unitId].Economy.BuildRate * buildMultiplier)))
                return ALLBPS[projBp].Economy.BuildCostEnergy / ALLBPS[projBp].Economy.BuildTime * (ALLBPS[unitId].Economy.BuildRate * buildMultiplier)
            end
            return false

        end
        local ALLBPS = __blueprints
        local multiplier = self.EcoManager.BuildMultiplier
        coroutine.yield(Random(1,7))
        while true do
            coroutine.yield(50)
            local buildingTable = GetListOfUnits(self, categories.ENGINEER + categories.STRUCTURE * (categories.FACTORY + categories.RADAR + categories.MASSEXTRACTION + categories.SHIELD), false)
            local potentialPowerConsumption = 0
            local unitCat
            for k, v in buildingTable do
                if not v.Dead and not v.BuildCompleted then
                    unitCat = v.Blueprint.CategoriesHash
                    if unitCat.ENGINEER then
                        if v.UnitBeingBuilt and not v.UnitBeingBuilt.Dead then
                            local beingBuiltUnitCats = ALLBPS[v.UnitBeingBuilt.UnitId].CategoriesHash
                            if beingBuiltUnitCats.NUKE and v:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Nuke Launcher being built')
                                potentialPowerConsumption = potentialPowerConsumption + GetMissileConsumption(ALLBPS, v.UnitBeingBuilt.UnitId, multiplier)
                                continue
                            end
                            if beingBuiltUnitCats.TECH3 and beingBuiltUnitCats.ANTIMISSILE and v:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Anti Nuke Launcher being built')
                                potentialPowerConsumption = potentialPowerConsumption + GetMissileConsumption(ALLBPS, v.UnitBeingBuilt.UnitId, multiplier)
                                continue
                            end
                            if beingBuiltUnitCats.TECH3 and beingBuiltUnitCats.MASSFABRICATION and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Mass Fabricator being built')
                                if ALLBPS[v.UnitBeingBuilt.UnitId].Economy.MaintenanceConsumptionPerSecondEnergy then
                                    --RNGLOG('Fabricator being built, energy consumption will be '..ALLBPS[v.UnitBeingBuilt].Economy.MaintenanceConsumptionPerSecondEnergy)
                                    potentialPowerConsumption = potentialPowerConsumption + ALLBPS[v.UnitBeingBuilt.UnitId].Economy.MaintenanceConsumptionPerSecondEnergy
                                end
                                continue
                            end
                            if beingBuiltUnitCats.STRUCTURE and beingBuiltUnitCats.SHIELD and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Shield being built')
                                if ALLBPS[v.UnitBeingBuilt.UnitId].Economy.MaintenanceConsumptionPerSecondEnergy then
                                    --RNGLOG('Shield being built, energy consumption will be '..ALLBPS[v.UnitBeingBuilt].Economy.MaintenanceConsumptionPerSecondEnergy)
                                    potentialPowerConsumption = potentialPowerConsumption + ALLBPS[v.UnitBeingBuilt.UnitId].Economy.MaintenanceConsumptionPerSecondEnergy
                                end
                                continue
                            end
                            if beingBuiltUnitCats.STRUCTURE and beingBuiltUnitCats.FACTORY and beingBuiltUnitCats.AIR and beingBuiltUnitCats.TECH3 and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Shield being built')
                                potentialPowerConsumption = potentialPowerConsumption + (1000 * multiplier)
                                continue
                            end
                            if beingBuiltUnitCats.STRUCTURE and beingBuiltUnitCats.FACTORY and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Shield being built')
                                potentialPowerConsumption = potentialPowerConsumption + (120 * multiplier)
                                continue
                            end
                            if beingBuiltUnitCats.STRUCTURE and beingBuiltUnitCats.RADAR and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Shield being built')
                                potentialPowerConsumption = potentialPowerConsumption + (60 * multiplier)
                                continue
                            end
                            if beingBuiltUnitCats.STRUCTURE and beingBuiltUnitCats.DEFENSE and beingBuiltUnitCats.DIRECTFIRE and v.UnitBeingBuilt:GetFractionComplete() < 0.8 then
                                --RNGLOG('EcoPowerPreemptive : Shield being built')
                                potentialPowerConsumption = potentialPowerConsumption + (60 * multiplier)
                                continue
                            end
                        end
                    elseif unitCat.FACTORY then
                        if unitCat.TECH3 and unitCat.AIR then
                                if v:GetFractionComplete() < 0.7 then
                                    --RNGLOG('EcoPowerPreemptive : T3 Air Being Built')
                                    potentialPowerConsumption = potentialPowerConsumption + (1000 * multiplier)
                                    continue
                                else
                                    v.BuildCompleted = true
                                end
                        elseif unitCat.TECH2 and unitCat.AIR then
                            if v:GetFractionComplete() < 0.7 then
                                --RNGLOG('EcoPowerPreemptive : T2 Air Being Built')
                                potentialPowerConsumption = potentialPowerConsumption + (200 * multiplier)
                                continue
                            else
                                v.BuildCompleted = true
                            end
                        elseif unitCat.TECH3 and unitCat.LAND then
                            if v:GetFractionComplete() < 0.7 then
                                --RNGLOG('EcoPowerPreemptive : T3 Air Being Built')
                                potentialPowerConsumption = potentialPowerConsumption + (250 * multiplier)
                                continue
                            else
                                v.BuildCompleted = true
                            end
                        elseif unitCat.TECH2 and unitCat.LAND then
                            if v:GetFractionComplete() < 0.7 then
                                --RNGLOG('EcoPowerPreemptive : T2 Air Being Built')
                                potentialPowerConsumption = potentialPowerConsumption + (70 * multiplier)
                                continue
                            else
                                v.BuildCompleted = true
                            end
                        end
                    elseif unitCat.MASSEXTRACTION then
                        if v.UnitId.General.UpgradesTo and v:GetFractionComplete() < 0.7 then
                            --RNGLOG('EcoPowerPreemptive : Extractors being upgraded')
                            potentialPowerConsumption = potentialPowerConsumption + (ALLBPS[v.UnitId.General.UpgradesTo].Economy.BuildCostEnergy / ALLBPS[v.UnitId.General.UpgradesTo].Economy.BuildTime * (ALLBPS[v.UnitId].Economy.BuildRate * multiplier))
                            continue
                        else
                            v.BuildCompleted = true
                        end
                    elseif unitCat.STRUCTURE and (unitCat.RADAR or unitCat.SONAR or unitCat.SHIELD) then
                        if v.UnitId.General.UpgradesTo and v:GetFractionComplete() < 0.7 then
                            --RNGLOG('EcoPowerPreemptive : Radar being upgraded next power consumption is '..ALLBPS[v.UnitId.General.UpgradesTo].Economy.MaintenanceConsumptionPerSecondEnergy)
                            if v:IsUnitState('Upgrading') then
                                --RNGLOG('Unit is upgrading, check power consumption during upgrade')
                                potentialPowerConsumption = potentialPowerConsumption + (ALLBPS[v.UnitId.General.UpgradesTo].Economy.BuildCostEnergy / ALLBPS[v.UnitId.General.UpgradesTo].Economy.BuildTime * (ALLBPS[v.UnitId].Economy.BuildRate * multiplier))
                            end
                            potentialPowerConsumption = potentialPowerConsumption + ALLBPS[v.UnitId.General.UpgradesTo].Economy.MaintenanceConsumptionPerSecondEnergy
                            continue
                        else
                            v.BuildCompleted = true
                        end
                    end
                end
            end
            if potentialPowerConsumption > 0 then
                --RNGLOG('PowerConsumption of things being built '..potentialPowerConsumption)
                --RNGLOG('Energy Income Over Time '..self.EconomyOverTimeCurrent.EnergyIncome * 10)
                --RNGLOG('Energy Requested Over Time '..self.EconomyOverTimeCurrent.EnergyRequested * 10)
                --RNGLOG('Potential Extra Power Consumption '..potentialPowerConsumption)
                if (GetEconomyIncome(self,'ENERGY') * 10) - (GetEconomyRequested(self,'ENERGY') * 10) - potentialPowerConsumption < 0 then
                    --RNGLOG('Powerconsumption will not support what we are currently building')
                    self.EcoManager.EcoPowerPreemptive = true
                    continue
                end
            end
            self.EcoManager.EcoPowerPreemptive = false
        end
    end,
    
    EcoSelectorManagerRNG = function(self, priorityUnit, units, action, type)
        --RNGLOG('Eco selector manager for '..priorityUnit..' is '..action..' Type is '..type)
        local engineerCats
        local totalResourceSaved = 0
        if self.BrainIntel.MapOwnership > 50 then
            engineerCats = categories.STRUCTURE * (categories.ENERGYPRODUCTION + categories.TACTICALMISSILEPLATFORM + (categories.TECH3 * categories.ANTIMISSILE) + categories.ENERGYSTORAGE + categories.SHIELD + categories.GATE + categories.OPTICS)
        else
            engineerCats = categories.STRUCTURE * (categories.ENERGYPRODUCTION + categories.TACTICALMISSILEPLATFORM + (categories.TECH3 * categories.ANTIMISSILE) + categories.MASSSTORAGE + categories.ENERGYSTORAGE + categories.SHIELD + categories.GATE + categories.OPTICS)
        end
        
        for k, v in units do
            if not v.Dead then  
                if v:GetFractionComplete() ~= 1 then continue end
                if priorityUnit == 'ENGINEER' then
                    --RNGLOG('Priority Unit Is Engineer')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Engineer')
                        v:SetPaused(false)
                        continue
                    end
                    if v.PlatoonHandle.PlatoonData.Construction.NoPause then continue end
                    if type == 'MASS' and EntityCategoryContains( engineerCats , v.UnitBeingBuilt) then
                        if EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingBuilt) then
                            if self:GetEconomyTrend('MASS') <= 0 and self:GetEconomyStored('MASS') == 0 and self:GetEconomyTrend('ENERGY') > 2 then
                                if type == 'MASS' then
                                    totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                                elseif type == 'ENERGY' then
                                    totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                                end
                                v:SetPaused(true)
                            end
                        else
                            if type == 'MASS' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                            elseif type == 'ENERGY' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                            end
                            v:SetPaused(true)
                        end
                        continue
                    elseif type == 'ENERGY' and EntityCategoryContains( engineerCats , v.UnitBeingBuilt) then
                        if not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingBuilt) then
                            if type == 'MASS' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                            elseif type == 'ENERGY' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                            end
                            v:SetPaused(true)
                        end
                        continue
                    end
                    if not v.PlatoonHandle.PlatoonData.Assist.AssisteeType then continue end
                    if not v.UnitBeingAssist then continue end
                    if v:IsPaused() then continue end
                    if type == 'ENERGY' and not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                        --RNGLOG('Pausing Engineer')
                        if type == 'MASS' then
                            totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                        elseif type == 'ENERGY' then
                            totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                        end
                        v:SetPaused(true)
                        continue
                    elseif type == 'MASS' then
                        if EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                            if self:GetEconomyTrend('MASS') <= 0 and self:GetEconomyStored('MASS') == 0 and self:GetEconomyTrend('ENERGY') > 2 then
                                if type == 'MASS' then
                                    totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                                elseif type == 'ENERGY' then
                                    totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                                end
                                v:SetPaused(true)
                            end
                        else
                            if type == 'MASS' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                            elseif type == 'ENERGY' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                            end
                            v:SetPaused(true)
                        end
                        continue
                    end
                elseif priorityUnit == 'STATIONPODS' then
                    --RNGLOG('Priority Unit Is STATIONPODS')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing STATIONPODS Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if EntityCategoryContains(categories.ENGINEER * categories.TECH1, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing STATIONPODS')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'AIR_TECH1' then
                    --RNGLOG('Priority Unit Is AIR')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Air Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].AirThreat > 0 then
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.ENGINEER then continue end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.TRANSPORTFOCUS and self:GetCurrentUnits(categories.TRANSPORTFOCUS) < 1 then continue end
                    --if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing AIR')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'AIR_TECH2' then
                    --RNGLOG('Priority Unit Is AIR')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Air Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].AirThreat > 0 then
                        continue
                    end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.ENGINEER then continue end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.TRANSPORTFOCUS and self:GetCurrentUnits(categories.TRANSPORTFOCUS) < 1 then continue end
                    --if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing AIR')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'AIR_TECH3' then
                    --RNGLOG('Priority Unit Is AIR')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Air Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].AirThreat > 0 then
                        continue
                    end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.ENGINEER then continue end
                    if v.UnitBeingBuilt.Blueprint.CategoriesHash.TRANSPORTFOCUS and self:GetCurrentUnits(categories.TRANSPORTFOCUS) < 1 then continue end
                    --if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing AIR')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'NAVAL_TECH1' then
                    --RNGLOG('Priority Unit Is NAVAL')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Naval Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].NavalThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing NAVAL')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'NAVAL_TECH2' then
                    --RNGLOG('Priority Unit Is NAVAL')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Naval Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].NavalThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing NAVAL')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'NAVAL_TECH3' then
                    --RNGLOG('Priority Unit Is NAVAL')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Naval Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].NavalThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) == 1 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing NAVAL')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'LAND_TECH1' then
                    --RNGLOG('Priority Unit Is LAND')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Land Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].LandThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) <= 2 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing LAND')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'LAND_TECH2' then
                    --RNGLOG('Priority Unit Is LAND')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Land Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].LandThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) <= 2 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing LAND')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'LAND_TECH3' then
                    --RNGLOG('Priority Unit Is LAND')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Land Factory')
                        v:SetPaused(false)
                        continue
                    end
                    if not v.UnitBeingBuilt then continue end
                    if v.LocationType and self.BasePerimeterMonitor[v.LocationType] and self.BasePerimeterMonitor[v.LocationType].LandThreat > 0 then
                        continue
                    end
                    if EntityCategoryContains(categories.ENGINEER, v.UnitBeingBuilt) then continue end
                    if RNGGETN(units) <= 2 then continue end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing LAND')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'MASSFABRICATION' then
                    --RNGLOG('Priority Unit Is MASSFABRICATION or SHIELD')
                    if action == 'unpause' then
                        if v.MaintenanceConsumption then continue end
                        --RNGLOG('Unpausing MASSFABRICATION or SHIELD')
                        v:SetPaused(false)
                        continue
                    end
                    
                    if not v.MaintenanceConsumption then continue end
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                elseif priorityUnit == 'RADAR' then
                    --RNGLOG('Priority Unit Is MASSFABRICATION or SHIELD')
                    if action == 'unpause' then
                        if v.MaintenanceConsumption then continue end
                        --RNGLOG('Unpausing MASSFABRICATION or SHIELD')
                        v:SetPaused(false)
                        v:OnScriptBitClear(3)
                        continue
                    end
                    
                    if not v.MaintenanceConsumption then continue end
                    --RNGLOG('pausing MASSFABRICATION or SHIELD '..v.UnitId)
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    v:OnScriptBitSet(3)
                elseif priorityUnit == 'SHIELD' then
                    --RNGLOG('Priority Unit Is MASSFABRICATION or SHIELD')
                    if v.MyShield and v.MyShield:GetMaxHealth() > 0 then
                        if action == 'unpause' then
                            --RNGLOG('Unpausing MASSFABRICATION or SHIELD')
                            v:EnableShield()
                            continue
                        end
                        --RNGLOG('pausing MASSFABRICATION or SHIELD '..v.UnitId)
                        v:DisableShield()
                    end
                elseif priorityUnit == 'NUKE' then
                    --RNGLOG('Priority Unit Is Nuke')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing Nuke')
                        v:SetPaused(false)
                        continue
                    end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing Nuke')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'TML' then
                    --RNGLOG('Priority Unit Is TML')
                    if action == 'unpause' then
                        if not v:IsPaused() then continue end
                        --RNGLOG('Unpausing TML')
                        v:SetPaused(false)
                        continue
                    end
                    if v.LimitPause then
                        continue
                    end
                    if v:IsPaused() then continue end
                    --RNGLOG('pausing TML')
                    if type == 'MASS' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(v)
                    elseif type == 'ENERGY' then
                        totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(v)
                    end
                    v:SetPaused(true)
                    continue
                elseif priorityUnit == 'MASSEXTRACTION' and action == 'unpause' then
                    if not v:IsPaused() then continue end
                    v:SetPaused( false )
                    --RNGLOG('Unpausing Extractor')
                    continue
                elseif priorityUnit == 'MASSEXTRACTION' and action == 'pause' then
                    local upgradingBuilding = {}
                    local upgradingBuildingNum = 0
                    --RNGLOG('Mass Extractor pause action, gathering upgrading extractors')
                    for k, v in units do
                        if v
                            and not v.Dead
                            and not v:BeenDestroyed()
                            and not v:GetFractionComplete() < 1
                        then
                            if v:IsUnitState('Upgrading') then
                                if not v:IsPaused() then
                                    RNGINSERT(upgradingBuilding, v)
                                    --RNGLOG('Upgrading Extractor not paused found')
                                    upgradingBuildingNum = upgradingBuildingNum + 1
                                end
                            end
                        end
                    end
                    --RNGLOG('Mass Extractor pause action, checking if more than one is upgrading')
                    local upgradingTableSize = RNGGETN(upgradingBuilding)
                    --RNGLOG('Number of upgrading extractors is '..upgradingBuildingNum)
                    if upgradingBuildingNum > 1 then
                        --RNGLOG('pausing all but one upgrading extractor')
                        --RNGLOG('UpgradingTableSize is '..upgradingTableSize)
                        for i=1, (upgradingTableSize - 1) do
                            if type == 'MASS' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondMass(upgradingBuilding[i])
                            elseif type == 'ENERGY' then
                                totalResourceSaved = totalResourceSaved + GetConsumptionPerSecondEnergy(upgradingBuilding[i])
                            end
                            upgradingBuilding[i]:SetPaused( true )
                            --UpgradingBuilding:SetCustomName('Upgrading paused')
                            --RNGLOG('Upgrading paused')
                        end
                    end
                end
            end
        end
        return totalResourceSaved
    end,

    EnemyChokePointTestRNG = function(self)
        local selfIndex = self:GetArmyIndex()
        local selfStartPos = self.BuilderManagers['MAIN'].Position
        local enemyTestTable = {}

        coroutine.yield(Random(80,100))
        if self.EnemyIntel.EnemyCount > 0 then
            for index, brain in ArmyBrains do
                if IsEnemy(selfIndex, index) and not ArmyIsCivilian(index) then
                    local posX, posZ = brain:GetArmyStartPos()
                    self.EnemyIntel.ChokePoints[index] = {
                        CurrentPathThreat = 0,
                        NoPath = false,
                        StartPosition = {posX, 0, posZ},
                        ClosestThreatPos = {},
                        ClosestThreat = 0
                    }
                end
            end
        end

        while true do
            --LOG('Performing chokepoint loop')
            if self.EnemyIntel.EnemyCount > 0 then
                --LOG('Enemy count is '..tostring(self.EnemyIntel.EnemyCount))
                local chokePointInvalid = true
                for k, v in self.EnemyIntel.ChokePoints do
                    --LOG('Checkpoint check '..tostring(k)..' detail is '..tostring(repr(v)))
                    local path, reason, distance, threats = PlatoonGenerateSafePathToRNG(self, 'Land', selfStartPos, v.StartPosition, 1500, 20 )
                    if not v.NoPath and not path and reason == 'TooMuchThreat' then
                        --LOG('Path to enemy base has too much threat')
                        local closestThreatDistance
                        local closestThreatPosition
                        local cloestThreat
                        local totalThreat = 0
                        if self.EnemyIntel.EnemyCount > 0 then
                            self.EnemyIntel.ChokePoints[k].NoPath = true
                            --LOG('No path due to chokepoint is now true')
                            for _, v in threats do
                                local dx = v[1] - selfStartPos[1]
                                local dz = v[2] - selfStartPos[2]
                                local threatDist = dx * dx + dz * dz
                                if not closestThreatDistance or threatDist < closestThreatDistance then
                                    closestThreatDistance = threatDist
                                    closestThreatPosition = {v[1], 0, v[2]}
                                    cloestThreat = v[3]
                                end
                                totalThreat = totalThreat + v[3]
                            end
                            --LOG('Land Now Should be Greater than EnemyThreatcurrent divided by enemies')
                            --LOG('LandNow '..self.BrainIntel.SelfThreat.LandNow)
                            --LOG('EnemyThreatCurrent for Land is '..self.EnemyIntel.EnemyThreatCurrent.Land)
                            --LOG('Enemy Count is '..self.EnemyIntel.EnemyCount)
                            --LOG('EnemyThreatcurrent divided by enemies '..(self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount))
                            --LOG('EnemyDenseThreatSurface '..self.EnemyIntel.EnemyThreatCurrent.DefenseSurface..' should be greater than LandNow'..self.BrainIntel.SelfThreat.LandNow)
                            --LOG('Total Threat '..totalThreat..' Should be greater than LandNow '..self.BrainIntel.SelfThreat.LandNow)
                            if self.EnemyIntel.EnemyFireBaseDetected then
                                --LOG('Firebase flag is true')
                            else
                                --LOG('Firebase flag is false')
                            end
                            if self.BrainIntel.SelfThreat.LandNow > (self.EnemyIntel.EnemyThreatCurrent.Land / self.EnemyIntel.EnemyCount) 
                            and (self.EnemyIntel.EnemyThreatCurrent.DefenseSurface + self.EnemyIntel.EnemyThreatCurrent.DefenseAir) > self.BrainIntel.SelfThreat.LandNow
                            and totalThreat > self.BrainIntel.SelfThreat.LandNow 
                            and self.EnemyIntel.EnemyFireBaseDetected then
                                self.EnemyIntel.ChokeFlag = true
                                --LOG('ChokeFlag is true')
                            elseif self.EnemyIntel.ChokeFlag then
                                --LOG('ChokeFlag is false')
                                self.EnemyIntel.ChokeFlag = false
                            end
                        end

                        if closestThreatPosition then
                            self.EnemyIntel.ChokePoints[k].ClosestThreatPos = closestThreatPosition
                            --LOG('ClosestThreatPos is '..tostring(closestThreatPosition[1])..':'..tostring(closestThreatPosition[3]))
                            self.EnemyIntel.ChokePoints[k].CurrentPathThreat = totalThreat
                            --LOG('Total Path threat is '..tostring(totalThreat))
                            self.EnemyIntel.ChokePoints[k].ClosestThreat = cloestThreat
                        end
                    elseif v.NoPath and path then
                        self.EnemyIntel.ChokePoints[k].NoPath = false
                        self.EnemyIntel.ChokeFlag = false
                        --LOG('ChokeFlag is false')
                    end
                    --LOG('Current enemy chokepoint data for index '..tostring(k))
                    --LOG(tostring(repr(self.EnemyIntel.ChokePoints[k])))
                    coroutine.yield(20)
                end
            end
            coroutine.yield(1200)
        end
    end,

    EngineerAssistManagerBrainRNG = function(self, type)

        local buildPowerTable = {
            TECH1 = 5,
            TECH2 = 13,
            TECH3 = 32.5
        }

        coroutine.yield(900)
        local state
        while true do
            local massStorage = GetEconomyStored( self, 'MASS')
            local energyStorage = GetEconomyStored( self, 'ENERGY')
            local gameTime = GetGameTimeSeconds()
            local multiplier = self.EcoManager.BuildMultiplier
            local CoreMassNumberAchieved = false
            local minAssistPower = 0
            local currentAssistRatio = self.EngineerAssistRatio
            if self.cmanager.income.r.m then
                minAssistPower = math.ceil(math.max(self.cmanager.income.r.m * currentAssistRatio, 5))
            end
            local strategyAssist = self.BrainIntel.PlayerStrategy.T3AirRush
            if strategyAssist then
                if self.BrainIntel.PlayerStrategy.T3AirRush then
                    state = 'T3AirRush'
                    --LOG('Assist Focus is T3 Air Rush')
                    --LOG('Current assist ratio '..tostring(self.EngineerAssistRatio))
                    --LOG('Current assist power '..tostring(self.EngineerAssistManagerBuildPower))
                    --LOG('Current required '..tostring(self.EngineerAssistManagerBuildPowerRequired))
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'lowincome structure * energyproduction'}, 
                        {cat = categories.FACTORY * categories.AIR - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'AirUpgrade air hsq upgrade'}, 
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'AirUpgrade mass'}, 
                        {cat = categories.STRUCTURE * (categories.DEFENSE + categories.TECH2 * categories.ARTILLERY), type = 'Completion', debug = 'lowincome structure * defense or arty' }
                    }
                end
                self.EngineerAssistManagerBuildPowerRequired = minAssistPower
                --LOG('Setting T3AirRush build power required')
                if self.EngineerAssistManagerBuildPower < minAssistPower then
                    self.EngineerAssistManagerActive = true
                end
            else
                if (gameTime < 300 and self.EconomyOverTimeCurrent.MassIncome < 2.5) then
                    state = 'Energy'
                    --LOG('Assist Focus is Factory and Energy Completion')
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'lowincome structure * factory'},
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'lowincome structure * energyproduction'}, 
                        {cat = categories.STRUCTURE * (categories.DEFENSE + categories.TECH2 * categories.ARTILLERY), type = 'Completion', debug = 'lowincome structure * defense or arty' }
                    }
                elseif self.EcoManager.EcoPowerPreemptive or self.EconomyOverTimeCurrent.EnergyTrendOverTime < 25.0 or self.EngineerAssistManagerFocusPower then
                    state = 'Energy'
                    --LOG('Assist Focus is Energy')
                    self.EngineerAssistManagerFocusCategory = categories.STRUCTURE * categories.ENERGYPRODUCTION
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3 , type = 'Completion', debug = 'energy structure * energyproduction t3'}, 
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2, type = 'Completion', debug = 'energy structure * energyproduction t2'}, 
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'energy structure * energyproduction t1'}, 
                        {cat = categories.FACTORY * ( categories.LAND + categories.AIR ) - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'energy factory * land air'},
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'energy factory'},
                    }
                elseif self.EngineerAssistManagerFocusSnipe then
                    state = 'Snipe'
                    --LOG('Assist Focus is Snipe')
                    self.EngineerAssistManagerFocusCategory = categories.STRUCTURE * categories.FACTORY
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.daa0206, type = 'Completion', debug = 'snipe daa0206'},
                        {cat = categories.xrl0302, type = 'Completion', debug = 'snipe xrl0302'},
                        {cat = categories.AIR * (categories.BOMBER + categories.GROUNDATTACK), type = 'Completion', debug = 'snipe air bombergunship'},
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'snipe structure * energyproduction'},
                        {cat = categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'snipe upgrade factory'}, 
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'snipe mass upgrade'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'snipe factory'},
                        {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion', debug = 'snipe mass storage'}
                    }
                elseif self.EngineerAssistManagerFocusHighValue then
                    state = 'Experimental'
                    --LOG('Assist Focus is High Value')
                    self.EngineerAssistManagerFocusCategory = categories.EXPERIMENTAL + categories.TECH3 * categories.STRATEGIC
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, type = 'Completion', debug = 'HighValue smd'},
                        {cat = categories.MOBILE * categories.EXPERIMENTAL + categories.STRUCTURE * categories.EXPERIMENTAL + categories.STRUCTURE * categories.TECH3 * categories.STRATEGIC, type = 'Completion', debug = 'HighValue experimental'},
                        {cat = categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'HighValue hq factory upgrade'}, 
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'HighValue mass'}, 
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'HighValue structure * energyproduction'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'HighValue factory'},
                        {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion', debug = 'HighValue mass storage'}
                    }
                elseif self.EngineerAssistManagerFocusAirUpgrade then
                    state = 'Air'
                    --LOG('Assist Focus is Air Upgrade')
                    self.EngineerAssistManagerFocusCategory = categories.FACTORY * categories.AIR - categories.SUPPORTFACTORY
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.FACTORY * categories.AIR - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'AirUpgrade air hsq upgrade'}, 
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'AirUpgrade mass'}, 
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'AirUpgrade structure * energyproduction'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'AirUpgrade factory'},
                        {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion', debug = 'AirUpgrade experimental'},
                        {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion', debug = 'AirUpgrade mass storage'} 
                    }
                elseif self.EngineerAssistManagerFocusLandUpgrade then
                    state = 'Land'
                    --LOG('Assist Focus is Land upgrade')
                    self.EngineerAssistManagerFocusCategory = categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.FACTORY * categories.LAND - categories.SUPPORTFACTORY, type = 'Upgrade', debug = 'LandUpgrade hq factory'}, 
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'LandUpgrade mass'}, 
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'LandUpgrade structure * energy'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'LandUpgrade factory'},
                        {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion', debug = 'LandUpgrade experimental'},
                        {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion', debug = 'LandUpgrade mass storage'}
                    }
                else
                    state = 'Mass'
                    --LOG('Assist Focus is Mass and everything')
                    self.EngineerAssistManagerPriorityTable = {
                        {cat = categories.STRUCTURE * categories.DEFENSE * categories.ANTIMISSILE * categories.TECH3, type = 'Completion', debug = 'Mass smd'},
                        {cat = categories.MASSEXTRACTION, type = 'Upgrade', debug = 'Mass mass'},
                        {cat = categories.STRUCTURE * categories.MASSSTORAGE, type = 'Completion', debug = 'Mass mass storage'},
                        {cat = categories.MOBILE * categories.EXPERIMENTAL, type = 'Completion', debug = 'Mass mobile experimental'},
                        {cat = categories.STRUCTURE * categories.EXPERIMENTAL, type = 'Completion', debug = 'Mass structure experimental'},
                        {cat = categories.STRUCTURE * categories.TECH3 * categories.STRATEGIC, type = 'Completion', debug = 'Mass strategic'},
                        {cat = categories.STRUCTURE * categories.ENERGYPRODUCTION, type = 'Completion', debug = 'Mass energy'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Upgrade', debug = 'Mass factory upgrade'}, 
                        {cat = categories.STRUCTURE * categories.FACTORY, type = 'Completion', debug = 'Mass factory complete'}, 
                        {cat = categories.STRUCTURE * categories.SHIELD, type = 'Completion', debug = 'Mass shield complete'}, 
                        {cat = categories.STRUCTURE * categories.SHIELD, type = 'Upgrade', debug = 'Mass shield upgrade'},
                    }
                end
                --LOG('Current EngineerAssistManager build power '..self.EngineerAssistManagerBuildPower..' build power required '..self.EngineerAssistManagerBuildPowerRequired)
                --LOG('Min Assist Power is '..tostring(minAssistPower))
                --LOG('EngineerAssistManagerRNGMass Storage is : '..massStorage)
                --LOG('EngineerAssistManagerRNG Energy Storage is : '..energyStorage)
                if self.RNGEXP and self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.9 and self.EngineerAssistManagerBuildPower < minAssistPower then
                    self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired + 5
                    self.EngineerAssistManagerActive = true
                elseif not CoreMassNumberAchieved and self.EcoManager.CoreMassPush and self.EngineerAssistManagerBuildPower <= 75 then
                    --RNGLOG('CoreMassPush is true')
                    self.EngineerAssistManagerBuildPowerRequired = 75
                elseif self.EngineerAssistManagerFocusHighValue and self.EngineerAssistManagerBuildPower <= math.ceil(math.max((150 * multiplier), minAssistPower)) then
                    --LOG('EngineerAssistManagerFocusHighValue is true')
                    self.EngineerAssistManagerBuildPowerRequired = math.ceil(math.max((150 * multiplier), minAssistPower))
                elseif massStorage > 150 and energyStorage > 150 and self.EngineerAssistManagerBuildPower < math.max(minAssistPower, 5) and not self.EngineerAssistManagerFocusHighValue and not self.EcoManager.CoreMassPush then
                    if self.EngineerAssistManagerBuildPowerRequired < math.max(minAssistPower, 5) then
                        self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired + 5
                    end
                    --RNGLOG('EngineerAssistManager is Active due to storage and builder power being less than minAssistPower')
                    self.EngineerAssistManagerActive = true
                elseif self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.8 and self.EngineerAssistManagerBuildPower <= 0 and self.EngineerAssistManagerBuildPowerRequired < 6 then
                    --RNGLOG('EngineerAssistManagerBuildPower being set to 5')
                    self.EngineerAssistManagerActive = true
                    self.EngineerAssistManagerBuildPowerRequired = 5
                elseif self.EngineerAssistManagerBuildPower == self.EngineerAssistManagerBuildPowerRequired and self.EconomyOverTimeCurrent.MassEfficiencyOverTime > 0.8 then
                    --RNGLOG('EngineerAssistManagerBuildPower matches EngineerAssistManagerBuildPowerRequired, not add or removal')
                    coroutine.yield(30)
                else
                    if self.EngineerAssistManagerBuildPowerRequired > math.max(minAssistPower, 5) then
                        --LOG('Decreasing build power by 1 due to lower requirements')
                        --LOG('minAssistPower '..minAssistPower)
                        --LOG('Current build power '..self.EngineerAssistManagerBuildPower)
                        --LOG('Current build power required '..self.EngineerAssistManagerBuildPowerRequired)
                        self.EngineerAssistManagerBuildPowerRequired = self.EngineerAssistManagerBuildPowerRequired - 2.5
                    end
                    --self.EngineerAssistManagerActive = false
                end
            end
            if not CoreMassNumberAchieved and self.EcoManager.CoreExtractorT3Count > 2 then
                CoreMassNumberAchieved = true
                if not self.EngineerAssistManagerFocusHighValue and not self.EcoManager.CoreMassPush and self.EngineerAssistManagerBuildPowerRequired > minAssistPower then
                    self.EngineerAssistManagerBuildPowerRequired = minAssistPower
                end
            end
            --LOG('Current build power required '..tostring(self.EngineerAssistManagerBuildPowerRequired))
            --LOG('Current Build Power '..tostring(self.EngineerAssistManagerBuildPower))
            --LOG('MinAssist Build Power '..tostring(minAssistPower))
            coroutine.yield(10)
        end
    end,

    AllyEconomyHelpThread = function(self)
        local selfIndex = self:GetArmyIndex()
        local SUtils = import('/lua/AI/sorianutilities.lua')
        coroutine.yield(180)
        while true do
            if GetEconomyStoredRatio(self, 'ENERGY') > 0.95 and GetEconomyTrend(self, 'ENERGY') > 100 then
                for index, brain in ArmyBrains do
                    if index ~= selfIndex then
                        if not ArmyIsCivilian(index) and IsAlly(selfIndex, index) then
                            if GetEconomyStoredRatio(brain, 'ENERGY') < 0.01 then
                                --RNGLOG('Transfer Energy to team mate')
                                local amount
                                amount = GetEconomyStored( self, 'ENERGY') / 8
                                SUtils.AISendChat('allies', self.Nickname, 'AI '..self.Nickname..' Sending '..amount..' energy to '..brain.Nickname, ArmyBrains[index].Nickname)
                                self:TakeResource('Energy', amount)
                                brain:GiveResource( 'Energy', amount)
                            end
                        end
                    end
                end
            end
            coroutine.yield(100)
        end
    end,

    HeavyEconomyRNG = function(self)

        coroutine.yield(Random(80,100))
        --RNGLOG('Heavy Economy thread starting '..self.Nickname)
        while self.Status ~= "Defeat" do
            --RNGLOG('heavy economy loop started')
            self:HeavyEconomyForkRNG()
            coroutine.yield(50)
        end
    end,

    HeavyEconomyForkRNG = function(self)
        local units = GetListOfUnits(self, categories.SELECTABLE, false, true)
        local factionIndex = self:GetFactionIndex()
        local GetPosition = moho.entity_methods.GetPosition
        local ALLBPS = __blueprints
        --RNGLOG('units grabbed')
        local factories = {Land={T1=0,T2=0,T3=0},Air={T1=0,T2=0,T3=0},Naval={T1=0,T2=0,T3=0}}
        local extractors = { }
        local hydros = { }
        local fabs = {T2=0,T3=0}
        local radars = {T1=0,T2=0,T3=0}
        local intels = {Optics=0}
        local coms = {acu=0,sacu=0}
        local pgens = {T1=0,T2=0,T3=0,hydro=0}
        local silo = {T2=0,T3=0}
        local armyLand={T1={scout=0,tank=0,arty=0,aa=0},T2={tank=0,mml=0,amphib=0,aa=0,shield=0,bot=0,stealth=0,mobilebomb=0},T3={tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,armoured=0}, T4={experimentalland=0}}
        local armyLandType={scout=0,tank=0,sniper=0,arty=0,mml=0,aa=0,shield=0,bot=0,armoured=0,experimentalland=0}
        local armyLandTiers={T1=0,T2=0,T3=0,T4=0}
        local armyAir={T1={scout=0,interceptor=0,bomber=0,gunship=0,transport=0},T2={fighter=0,bomber=0,gunship=0,mercy=0,transport=0,torpedo=0},T3={scout=0,asf=0,bomber=0,gunship=0,torpedo=0,transport=0}}
        local armyAirType={scout=0,interceptor=0,bomber=0,asf=0,gunship=0,fighter=0,torpedo=0,transport=0,mercy=0}
        local armyAirTiers={T1=0,T2=0,T3=0}
        local armyNaval={T1={frigate=0,sub=0,shard=0},T2={destroyer=0,cruiser=0,subhunter=0,transport=0},T3={battleship=0,carrier=0,missileship=0,subkiller=0,battlecruiser=0,nukesub=0}}
        local armyNavalType={frigate=0,sub=0,shard=0,destroyer=0,cruiser=0,subhunter=0,battleship=0,carrier=0,missileship=0,subkiller=0,battlecruiser=0,nukesub=0}
        local armyNavalTiers={T1=0,T2=0,T3=0}
        local armyEngineer={T1={engineer=0},T2={engineer=0,engcombat=0},T3={engineer=0,sacueng=0,sacucombat=0,sacuras=0,sacutele=0}}
        local launcherspend = {T2=0,T3=0}
        local facspend = {Land=0,Air=0,Naval=0,LandUpgrading=0,AirUpgrading=0,NavalUpgrading=0}
        local mexspend = {T1=0,T2=0,T3=0}
        local engspend = {T1=0,T2=0,T3=0,com=0}
        local engbuildpower = {T1=0,T2=0,T3=0,com=0,sacu=0}
        local zoneIncome = {}
        local rincome = {m=0,e=0}
        local tincome = {m=GetEconomyIncome(self, 'MASS')*10,e=GetEconomyIncome(self, 'ENERGY')*10}
        local storage = {max = {m=GetEconomyStored(self, 'MASS')/GetEconomyStoredRatio(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')/GetEconomyStoredRatio(self, 'ENERGY')},current={m=GetEconomyStored(self, 'MASS'),e=GetEconomyStored(self, 'ENERGY')}}
        local tspend = {m=0,e=0}
        local mainBaseExtractors = {T1=0,T2=0,T3=0}
        local engineerDistribution = { BuildPower = 0, BuildStructure = 0, Assist = 0, Reclaim = 0, Expansion = 0, Mass = 0, Repair = 0, ReclaimStructure = 0, Total = 0 }
        local totalLandThreat = 0
        local totalAirThreat = 0
        local totalAirSubThreat = 0
        local totalAntiAirThreat = 0
        local totalEconomyThreat = 0
        local totalNavalThreat = 0
        local totalNavalSubThreat = 0
        local totalExtractorCount = 0
        for _,z in self.amanager.Ratios[factionIndex] do
            for _,c in z do
                c.total=0
                for i,v in c do
                    if i=='total' then continue end
                    c.total=c.total+v
                end
            end
        end
        local unitCat
        local currentLandFactoryCount = 0
        local currentUpgradingLandFactories = 0

        for _,unit in units do
            if unit and not unit.Dead then
                if unit:GetFractionComplete() == 1 then 
                    unitCat = unit.Blueprint.CategoriesHash
                    local spendm=GetConsumptionPerSecondMass(unit)
                    local spende=GetConsumptionPerSecondEnergy(unit)
                    local producem=GetProductionPerSecondMass(unit)
                    local producee=GetProductionPerSecondEnergy(unit)
                    local unitUpgrading = false
                    tspend.m=tspend.m+spendm
                    tspend.e=tspend.e+spende
                    rincome.m=rincome.m+producem
                    rincome.e=rincome.e+producee
                    if unitCat.MASSEXTRACTION then
                        totalEconomyThreat = totalEconomyThreat + unit.Blueprint.Defense.EconomyThreatLevel
                        totalExtractorCount = totalExtractorCount + 1
                        if not unit.zoneid and self.ZonesInitialized then
                            --LOG('unit has no zone')
                            local mexPos = GetPosition(unit)
                            if RUtils.PositionOnWater(mexPos[1], mexPos[3]) then
                                unit.zoneid = MAP:GetZoneID(mexPos,self.Zones.Naval.index)
                            else
                                unit.zoneid = MAP:GetZoneID(mexPos,self.Zones.Land.index)
                                unit.teamvalue = self.Zones.Land.zones[unit.zoneid].teamvalue or 1
                                --LOG('Unit zone is '..unit.zoneid)
                            end
                        end
                        if unit.zoneid then
                            if not zoneIncome[unit.zoneid] then
                                zoneIncome[unit.zoneid] = 0
                            end
                            zoneIncome[unit.zoneid] = zoneIncome[unit.zoneid] + producem
                        end
                        if not extractors[unit.zoneid] then
                            --LOG('Trying to add unit to zone')
                            extractors[unit.zoneid] = {T1 = 0,T2 = 0,T3 = 0,}
                        end
                        if unitCat.TECH1 then
                            extractors[unit.zoneid].T1=extractors[unit.zoneid].T1+1
                            mexspend.T1=mexspend.T1+spendm
                            if unit.MAINBASE then
                                mainBaseExtractors.T1 = mainBaseExtractors.T1 + 1
                            end
                        elseif unitCat.TECH2 then
                            extractors[unit.zoneid].T2=extractors[unit.zoneid].T2+1
                            mexspend.T2=mexspend.T2+spendm
                            if unit.MAINBASE then
                                mainBaseExtractors.T2 = mainBaseExtractors.T2 + 1
                            end
                        elseif unitCat.TECH3 then
                            extractors[unit.zoneid].T3=extractors[unit.zoneid].T3+1
                            mexspend.T3=mexspend.T3+spendm
                            if unit.MAINBASE then
                                mainBaseExtractors.T3 = mainBaseExtractors.T3 + 1
                            end
                        end
                    elseif unitCat.COMMAND or unitCat.SUBCOMMANDER then
                        if unitCat.COMMAND then
                            coms.acu = coms.acu + 1
                            engspend.com = engspend.com + spendm
                            engbuildpower.com = engbuildpower.com + unit.Blueprint.Economy.BuildRate
                        elseif unitCat.SUBCOMMANDER then
                            coms.sacu = coms.sacu + 1
                            engspend.com = engspend.com + spendm
                            engbuildpower.sacu = engbuildpower.sacu + unit.Blueprint.Economy.BuildRate
                        end
                    elseif unitCat.MASSFABRICATION then
                        if unitCat.TECH2 then
                            fabs.T2=fabs.T2+1
                        elseif unitCat.TECH3 then
                            fabs.T3=fabs.T3+1
                        end
                    elseif unitCat.ENGINEER then
                        if unit.JobType then
                            if not engineerDistribution[unit.JobType] then
                                engineerDistribution[unit.JobType] = 0
                            end
                            --LOG('Engineer Job Type '..unit.JobType)
                            engineerDistribution[unit.JobType] = engineerDistribution[unit.JobType] + 1
                            engineerDistribution.Total = engineerDistribution.Total + 1
                        end
                        if unitCat.TECH1 then
                            engspend.T1=engspend.T1+spendm
                            engbuildpower.T1 = engbuildpower.T1 + unit.Blueprint.Economy.BuildRate
                            armyEngineer.T1.engineer = armyEngineer.T1.engineer + 1
                        elseif unitCat.TECH2 then
                            engspend.T2=engspend.T2+spendm
                            engbuildpower.T2 = engbuildpower.T2 + unit.Blueprint.Economy.BuildRate
                            if unit.Blueprint.Weapon[1].WeaponCategory and unit.Blueprint.Weapon[1].WeaponCategory == "Direct Fire" then
                                armyEngineer.T2.engcombat = armyEngineer.T2.engcombat + 1
                            else
                                armyEngineer.T2.engineer = armyEngineer.T2.engineer + 1
                            end
                        elseif unitCat.TECH3 then
                            engspend.T3=engspend.T3+spendm
                            if unitCat.SUBCOMMANDER then
                                if unit['rngdata']['eng'].buildpower then
                                    engbuildpower.T3 = engbuildpower.T3 + unit['rngdata']['eng'].buildpower
                                end
                            else
                                engbuildpower.T3 = engbuildpower.T3 + unit.Blueprint.Economy.BuildRate
                                armyEngineer.T3.engineer = armyEngineer.T3.engineer + 1
                            end
                        end
                    elseif unitCat.FACTORY then
                        if unit:IsUnitState('Upgrading') then
                            unitUpgrading = true
                        end
                        if unitCat.LAND then
                            facspend.Land=facspend.Land+spendm
                            if unitUpgrading then
                                facspend.LandUpgrading=facspend.LandUpgrading+spendm
                            end
                            if unitCat.TECH1 then
                                factories.Land.T1=factories.Land.T1+1
                            elseif unitCat.TECH2 then
                                factories.Land.T2=factories.Land.T2+1
                            elseif unitCat.TECH3 then
                                factories.Land.T3=factories.Land.T3+1
                            end
                        elseif unitCat.AIR then
                            facspend.Air=facspend.Air+spendm
                            if unitUpgrading then
                                facspend.AirUpgrading=facspend.AirUpgrading+spendm
                            end
                            if unitCat.TECH1 then
                                factories.Air.T1=factories.Air.T1+1
                            elseif unitCat.TECH2 then
                                factories.Air.T2=factories.Air.T2+1
                            elseif unitCat.TECH3 then
                                factories.Air.T3=factories.Air.T3+1
                            end
                        elseif unitCat.NAVAL then
                            facspend.Naval=facspend.Naval+spendm
                            if unitUpgrading then
                                facspend.NavalUpgrading=facspend.NavalUpgrading+spendm
                            end
                            if unitCat.TECH1 then
                                factories.Naval.T1=factories.Naval.T1+1
                            elseif unitCat.TECH2 then
                                factories.Naval.T2=factories.Naval.T2+1
                            elseif unitCat.TECH3 then
                                factories.Naval.T3=factories.Naval.T3+1
                            end
                        end
                    elseif unitCat.ENERGYPRODUCTION then
                        if unitCat.HYDROCARBON then
                            --LOG('HydroCarbon detected, adding zone data')
                            if not unit.zoneid and self.ZonesInitialized then
                                --LOG('unit has no zone')
                                local hydroPos = GetPosition(unit)
                                unit.zoneid = MAP:GetZoneID(hydroPos,self.Zones.Land.index)
                                --LOG('Unit zone is '..unit.zoneid)
                            end
                            if not hydros[unit.zoneid] then
                                --LOG('Trying to add unit to zone')
                                hydros[unit.zoneid] = { hydrocarbon = 0 }
                            end
                            hydros[unit.zoneid].hydrocarbon=hydros[unit.zoneid].hydrocarbon+1
                        elseif unitCat.TECH1 then
                            pgens.T1=pgens.T1+1
                        elseif unitCat.TECH2 then
                            pgens.T2=pgens.T2+1
                        elseif unitCat.TECH3 then
                            pgens.T3=pgens.T3+1
                        end
                    elseif unitCat.LAND then
                        if not unitCat.EXPERIMENTAL then
                            totalLandThreat = totalLandThreat + unit.Blueprint.Defense.SurfaceThreatLevel
                        end
                        if unitCat.TECH1 then
                            armyLandTiers.T1=armyLandTiers.T1+1
                            if unitCat.SCOUT then
                                armyLand.T1.scout=armyLand.T1.scout+1
                                armyLandType.scout=armyLandType.scout+1
                            elseif unitCat.DIRECTFIRE and not unitCat.ANTIAIR then
                                armyLand.T1.tank=armyLand.T1.tank+1
                                armyLandType.tank=armyLandType.tank+1
                            elseif unitCat.INDIRECTFIRE and not unitCat.ANTIAIR then
                                armyLand.T1.arty=armyLand.T1.arty+1
                                armyLandType.arty=armyLandType.arty+1
                            elseif unitCat.ANTIAIR then
                                armyLand.T1.aa=armyLand.T1.aa+1
                                armyLandType.aa=armyLandType.aa+1
                            end
                        elseif unitCat.TECH2 then
                            armyLandTiers.T2=armyLandTiers.T2+1
                            if unitCat.DIRECTFIRE and not unitCat.BOT and not unitCat.ANTIAIR then
                                if unitCat.AMPHIBIOUS or unitCat.HOVER then
                                    armyLand.T2.amphib=armyLand.T2.amphib+1
                                else
                                    armyLand.T2.tank=armyLand.T2.tank+1
                                end
                                armyLandType.tank=armyLandType.tank+1
                            elseif unitCat.DIRECTFIRE and unitCat.BOT and unitCat.BOMB then
                                armyLand.T2.mobilebomb=armyLand.T2.mobilebomb+1
                                armyLandType.tank=armyLandType.tank+1
                            elseif unitCat.DIRECTFIRE and unitCat.BOT and not unitCat.ANTIAIR then
                                armyLand.T2.bot=armyLand.T2.bot+1
                                armyLandType.bot=armyLandType.bot+1
                            elseif unitCat.SILO then
                                armyLand.T2.mml=armyLand.T2.mml+1
                                armyLandType.mml=armyLandType.mml+1
                            elseif unitCat.ANTIAIR then
                                armyLand.T2.aa=armyLand.T2.aa+1
                                armyLandType.aa=armyLandType.aa+1
                            elseif unitCat.SHIELD then
                                armyLand.T2.shield=armyLand.T2.shield+1
                                armyLandType.shield=armyLandType.shield+1
                            end
                        elseif unitCat.TECH3 then
                            armyLandTiers.T3=armyLandTiers.T3+1
                            if unitCat.SNIPER then
                                armyLand.T3.sniper=armyLand.T3.sniper+1
                                armyLandType.sniper=armyLandType.sniper+1
                            elseif unitCat.DIRECTFIRE and EntityCategoryContains(categories.xel0305 + categories.xrl0305, unit) then
                                armyLand.T3.armoured=armyLand.T3.armoured+1
                                armyLandType.armoured=armyLandType.armoured+1
                            elseif unitCat.DIRECTFIRE and not unitCat.ANTIAIR then
                                armyLand.T3.tank=armyLand.T3.tank+1
                                armyLandType.tank=armyLandType.tank+1
                            elseif unitCat.SILO then
                                armyLand.T3.mml=armyLand.T3.mml+1
                                armyLandType.mml=armyLandType.mml+1
                            elseif unitCat.INDIRECTFIRE then
                                armyLand.T3.arty=armyLand.T3.arty+1
                                armyLandType.arty=armyLandType.arty+1
                            elseif unitCat.ANTIAIR then
                                armyLand.T3.aa=armyLand.T3.aa+1
                                armyLandType.aa=armyLandType.aa+1
                            elseif unitCat.SHIELD then
                                armyLand.T3.shield=armyLand.T3.shield+1
                                armyLandType.shield=armyLandType.shield+1
                            end
                        elseif unitCat.EXPERIMENTAL then
                            armyLandTiers.T4=armyLandTiers.T4+1
                            if unitCat.MOBILE and unitCat.LAND and unitCat.EXPERIMENTAL and not unitCat.ARTILLERY then
                                armyLand.T4.experimentalland=armyLand.T4.experimentalland+1
                                armyLandType.experimentalland=armyLandType.experimentalland+1
                            end
                        end
                    elseif unitCat.AIR then
                        if not unitCat.EXPERIMENTAL then
                            totalAirThreat = totalAirThreat + unit.Blueprint.Defense.AirThreatLevel + unit.Blueprint.Defense.SurfaceThreatLevel + unit.Blueprint.Defense.SubThreatLevel
                            totalAirSubThreat = totalAirSubThreat + unit.Blueprint.Defense.SubThreatLevel
                        end
                        if unitCat.TECH1 then
                            armyAirTiers.T1=armyAirTiers.T1+1
                            if unitCat.SCOUT then
                                armyAir.T1.scout=armyAir.T1.scout+1
                                armyAirType.scout=armyAirType.scout+1
                            elseif unitCat.ANTIAIR then
                                totalAntiAirThreat = totalAntiAirThreat + unit.Blueprint.Defense.AirThreatLevel
                                armyAir.T1.interceptor=armyAir.T1.interceptor+1
                                armyAirType.interceptor=armyAirType.interceptor+1
                            elseif unitCat.BOMBER then
                                armyAir.T1.bomber=armyAir.T1.bomber+1
                                armyAirType.bomber=armyAirType.bomber+1
                            elseif unitCat.GROUNDATTACK and not unitCat.EXPERIMENTAL then
                                armyAir.T1.gunship=armyAir.T1.gunship+1
                                armyAirType.gunship=armyAirType.gunship+1
                            elseif unitCat.TRANSPORTFOCUS then
                                armyAir.T1.transport=armyAir.T1.transport+1
                                armyAirType.transport=armyAirType.transport+1
                            end
                        elseif unitCat.TECH2 then
                            armyAirTiers.T2=armyAirTiers.T2+1
                            if unitCat.BOMBER and not unitCat.ANTINAVY and not EntityCategoryContains(categories.daa0206, unit) then
                                armyAir.T2.bomber=armyAir.T2.bomber+1
                                armyAirType.bomber=armyAirType.bomber+1
                            elseif EntityCategoryContains(categories.xaa0202, unit)then
                                totalAntiAirThreat = totalAntiAirThreat + unit.Blueprint.Defense.AirThreatLevel
                                armyAir.T2.fighter=armyAir.T2.fighter+1
                                armyAirType.fighter=armyAirType.fighter+1
                            elseif unitCat.GROUNDATTACK and not unitCat.EXPERIMENTAL then
                                armyAir.T2.gunship=armyAir.T2.gunship+1
                                armyAirType.gunship=armyAirType.gunship+1
                            elseif unitCat.ANTINAVY and not unitCat.EXPERIMENTAL then
                                armyAir.T2.torpedo=armyAir.T2.torpedo+1
                                armyAirType.torpedo=armyAirType.torpedo+1
                            elseif EntityCategoryContains(categories.daa0206, unit) then
                                armyAir.T2.mercy=armyAir.T2.mercy+1
                                armyAirType.mercy=armyAirType.mercy+1
                            elseif unitCat.TRANSPORTFOCUS then
                                armyAir.T2.transport=armyAir.T2.transport+1
                                armyAirType.transport=armyAirType.transport+1
                            end
                        elseif unitCat.TECH3 then
                            armyAirTiers.T3=armyAirTiers.T3+1
                            if unitCat.SCOUT then
                                armyAir.T3.scout=armyAir.T3.scout+1
                                armyAirType.scout=armyAirType.scout+1
                            elseif unitCat.ANTIAIR and not unitCat.BOMBER and not unitCat.GROUNDATTACK then
                                totalAntiAirThreat = totalAntiAirThreat + unit.Blueprint.Defense.AirThreatLevel
                                armyAir.T3.asf=armyAir.T3.asf+1
                                armyAirType.asf=armyAirType.asf+1
                            elseif unitCat.BOMBER and not unitCat.ANTINAVY then
                                armyAir.T3.bomber=armyAir.T3.bomber+1
                                armyAirType.bomber=armyAirType.bomber+1
                            elseif unitCat.GROUNDATTACK and not unitCat.EXPERIMENTAL then
                                armyAir.T3.gunship=armyAir.T3.gunship+1
                                armyAirType.gunship=armyAirType.gunship+1
                            elseif unitCat.TRANSPORTFOCUS then
                                armyAir.T3.transport=armyAir.T3.transport+1
                                armyAirType.transport=armyAirType.transport+1
                            elseif unitCat.ANTINAVY and not unitCat.EXPERIMENTAL then
                                armyAir.T3.torpedo=armyAir.T3.torpedo+1
                                armyAirType.torpedo=armyAirType.torpedo+1
                            end
                        end
                    elseif unitCat.NAVAL then
                        if not unitCat.EXPERIMENTAL then
                            totalNavalThreat = totalNavalThreat + unit.Blueprint.Defense.AirThreatLevel + unit.Blueprint.Defense.SubThreatLevel + unit.Blueprint.Defense.SurfaceThreatLevel
                            totalNavalSubThreat = totalNavalSubThreat + unit.Blueprint.Defense.SubThreatLevel
                        end
                        if unitCat.TECH1 then
                            armyNavalTiers.T1=armyNavalTiers.T1+1
                            if unitCat.FRIGATE then
                                armyNaval.T1.frigate=armyNaval.T1.frigate+1
                                armyNavalType.frigate=armyNavalType.frigate+1
                            elseif unitCat.T1SUBMARINE then
                                armyNaval.T1.sub=armyNaval.T1.sub+1
                                armyNavalType.sub=armyNavalType.sub+1
                            elseif EntityCategoryContains(categories.uas0102, unit) then
                                armyNaval.T1.shard=armyNaval.T1.shard+1
                                armyNavalType.shard=armyNavalType.shard+1
                            end
                        elseif unitCat.TECH2 then
                            armyNavalTiers.T2=armyNavalTiers.T2+1
                            if unitCat.DESTROYER then
                                armyNaval.T2.destroyer=armyNaval.T2.destroyer+1
                                armyNavalType.destroyer=armyNavalType.destroyer+1
                            elseif unitCat.CRUISER then
                                armyNaval.T2.cruiser=armyNaval.T2.cruiser+1
                                armyNavalType.cruiser=armyNavalType.cruiser+1
                            elseif unitCat.T2SUBMARINE or EntityCategoryContains(categories.xes0102, unit) then
                                armyNaval.T2.subhunter=armyNaval.T2.subhunter+1
                                armyNavalType.subhunter=armyNavalType.subhunter+1
                            end
                        elseif unitCat.TECH3 then
                            armyNavalTiers.T3=armyNavalTiers.T3+1
                            if EntityCategoryContains(categories.NUKE * categories.SUBMERSIBLE,unit) then
                                armyNaval.T3.nukesub=armyNaval.T3.nukesub+1
                                armyNavalType.nukesub=armyNavalType.nukesub+1
                            elseif EntityCategoryContains(categories.xss0304,unit) then
                                armyNaval.T3.subkiller=armyNaval.T3.subkiller+1
                                armyNavalType.subkiller=armyNavalType.subkiller+1
                            elseif EntityCategoryContains(categories.xes0307,unit) then
                                armyNaval.T3.battlecruiser=armyNaval.T3.battlecruiser+1
                                armyNavalType.battlecruiser=armyNavalType.battlecruiser+1
                            elseif EntityCategoryContains(categories.xas0306,unit) then
                                armyNaval.T3.missileship=armyNaval.T3.missileship+1
                                armyNavalType.missileship=armyNavalType.missileship+1
                            elseif EntityCategoryContains(categories.CARRIER,unit) then
                                armyNaval.T3.carrier=armyNaval.T3.carrier+1
                                armyNavalType.carrier=armyNavalType.carrier+1
                            elseif EntityCategoryContains(categories.BATTLESHIP - categories.EXPERIMENTAL,unit) then
                                armyNaval.T3.battleship=armyNaval.T3.battleship+1
                                armyNavalType.battleship=armyNavalType.battleship+1
                            end
                        end
                    elseif unitCat.SILO then
                        if unitCat.TECH2 then
                            silo.T2=silo.T2+1
                            launcherspend.T2=launcherspend.T2+spendm
                        elseif unitCat.TECH3 then
                            silo.T3=silo.T3+1
                            launcherspend.T3=launcherspend.T3+spendm
                        end
                    elseif unitCat.STRUCTURE and unitCat.INTELLIGENCE then
                        if unitCat.TECH2 and unitCat.RADAR then
                            radars.T1=radars.T1+1
                        elseif unitCat.TECH2 and unitCat.RADAR then
                            radars.T2=radars.T2+1
                        elseif unitCat.TECH3 and unitCat.OMNI then
                            radars.T3=radars.T3+1
                        elseif unitCat.TECH3 and unitCat.OPTICS then
                            intels.Optics=intels.Optics+1
                        end
                    end
                end
            end
        end
        self.cmanager.income.r.m=rincome.m
        self.cmanager.income.r.e=rincome.e
        self.cmanager.income.t.m=tincome.m
        self.cmanager.income.t.e=tincome.e
        self.cmanager.spend.m=tspend.m
        self.cmanager.spend.e=tspend.e
        self.cmanager.buildpower.eng=engbuildpower
        self.cmanager.categoryspend.eng=engspend
        self.cmanager.categoryspend.fact=facspend
        self.cmanager.categoryspend.silo=launcherspend
        self.cmanager.categoryspend.mex=mexspend
        self.cmanager.storage.current.m=storage.current.m
        self.cmanager.storage.current.e=storage.current.e
        if storage.current.m>0 and storage.current.e>0 then
            self.cmanager.storage.max.m=storage.max.m
            self.cmanager.storage.max.e=storage.max.e
        end
        self.amanager.Current.Land=armyLand
        self.amanager.Total.Land=armyLandTiers
        self.amanager.Type.Land=armyLandType
        self.amanager.Current.Air=armyAir
        self.amanager.Total.Air=armyAirTiers
        self.amanager.Type.Air=armyAirType
        self.amanager.Current.Naval=armyNaval
        self.amanager.Total.Naval=armyNavalTiers
        self.amanager.Type.Naval=armyNavalType
        self.BrainIntel.SelfThreat.LandNow = totalLandThreat
        self.BrainIntel.SelfThreat.AirNow = totalAirThreat
        self.BrainIntel.SelfThreat.AirSubNow = totalAirSubThreat
        self.BrainIntel.SelfThreat.AntiAirNow = totalAntiAirThreat
        self.BrainIntel.SelfThreat.NavalNow = totalNavalThreat
        self.BrainIntel.SelfThreat.NavalSubNow = totalNavalSubThreat
        self.BrainIntel.SelfThreat.ExtractorCount = totalExtractorCount
        self.BrainIntel.SelfThreat.Extractor = totalEconomyThreat
        self.EngineerDistributionTable = engineerDistribution
        self.smanager.Current.Structure={fact=factories,mex=extractors,silo=silo,fabs=fabs,pgen=pgens,hydrocarbon=hydros, intel=intels, radar=radars}
        local totalCoreExtractors = mainBaseExtractors.T1 + mainBaseExtractors.T2 + mainBaseExtractors.T3
        if totalCoreExtractors > 0 then
            --RNGLOG('Mainbase T1 Extractors '..mainBaseExtractors.T1)
            --RNGLOG('Mainbase T2 Extractors '..mainBaseExtractors.T2)
            --RNGLOG('Mainbase T3 Extractors '..mainBaseExtractors.T3)
            self.EcoManager.CoreExtractorT3Percentage = mainBaseExtractors.T3 / totalCoreExtractors
            self.EcoManager.CoreExtractorT2Count = mainBaseExtractors.T2 or 0
            self.EcoManager.CoreExtractorT3Count = mainBaseExtractors.T3 or 0
            self.EcoManager.TotalCoreExtractors = totalCoreExtractors or 0
        end
        for k, v in self.Zones.Land.zones do
            if zoneIncome[v.id] then
                v.zoneincome = zoneIncome[v.id]
            end
        end
    end,


    GetManagerCount = function(self, type)
        local count = 0
        for k, v in self.BuilderManagers do
            if k ~= 'FLOATING' then
                if type then
                --RNGLOG('BuilderManager Type is '..k)
                    if type == 'Start Location' and not (string.find(k, 'ARMY_') or string.find(k, 'Large Expansion')) then
                        continue
                    elseif type == 'Naval Area' and not (string.find(k, 'Naval Area')) then
                        continue
                    elseif type == 'Expansion Area' and (not (string.find(k, 'Expansion Area') or string.find(k, 'EXPANSION_AREA')) or string.find(k, 'Large Expansion')) then
                        continue
                    end
                end
                if v.EngineerManager:GetNumCategoryUnits('Engineers', categories.ALLUNITS) <= 0 and v.FactoryManager:GetNumCategoryFactories(categories.ALLUNITS) <= 0 then
                    continue
                end
                count = count + 1
            end
        end
       --RNGLOG('Type is '..type..' Count is '..count)
        return count
    end,

    

    CivilianUnitCheckRNG = function(self)
        -- This will momentarily reveal civilian structures at the start of the game so that the AI can detect threat from PD's
        --RNGLOG('Reveal Civilian PD')
        coroutine.yield(2)
        local AIIndex = self:GetArmyIndex()
        local minimumRadius = 256
        for i,v in ArmyBrains do
            local brainIndex = v:GetArmyIndex()
            if ArmyIsCivilian(brainIndex) then
                --RNGLOG('Found Civilian brain')
                local real_state = IsAlly(AIIndex, brainIndex) and 'Ally' or IsEnemy(AIIndex, brainIndex) and 'Enemy' or 'Neutral'
                --RNGLOG('Set Alliance to Ally')
                SetAlliance(AIIndex, brainIndex, 'Ally')
                coroutine.yield(11)
                --RNGLOG('Set Alliance back to '..real_state)
                SetAlliance(AIIndex, brainIndex, real_state)
            end
        end
        local civUnits = {}
        local baseEnemyArea = self.OperatingAreas['BaseEnemyArea']
        local allyUnits = GetUnitsAroundPoint(self, categories.MOBILE + (categories.DIRECTFIRE + categories.INDIRECTFIRE) - categories.UNSELECTABLE - categories.UNTARGETABLE, self.BrainIntel.StartPos, baseEnemyArea, 'Neutral')
        for _, v in allyUnits do
            local unitPos = v:GetPosition()
            --LOG('Unit found '..v.UnitId..' distance to base '..VDist3(unitPos, self.BrainIntel.StartPos))
            if not IsDestroyed(v) and v:IsCapturable() and ArmyIsCivilian(v:GetArmy()) and NavUtils.CanPathTo('Amphibious', self.BrainIntel.StartPos, unitPos) then
                if GetThreatAtPosition(self, unitPos, self.BrainIntel.IMAPConfig.Rings, true, 'AntiSurface') < 1 then
                    RNGINSERT(civUnits, {Risk = 'Low', Unit = v, Position = unitPos, EngineerAssigned = false, CaptureAttempts = 0})
                else
                    RNGINSERT(civUnits, {Risk = 'High', Unit = v, Position = unitPos, EngineerAssigned = false, CaptureAttempts = 0})
                end
            end
        end
        if not table.empty(civUnits) then
            self.EnemyIntel.CivilianCaptureUnits = civUnits
        end
        local enemyUnits = GetUnitsAroundPoint(self, categories.STRUCTURE * categories.DEFENSE * (categories.DIRECTFIRE + categories.INDIRECTFIRE), self.BrainIntel.StartPos, baseEnemyArea, 'Enemy')
        local closestCivPD
        for _, v in enemyUnits do
            local unitPos = v:GetPosition()
            local civPDClose = false
            if not IsDestroyed(v) and ArmyIsCivilian(v:GetArmy()) and NavUtils.CanPathTo('Land', self.BrainIntel.StartPos, unitPos) then
                local rx = unitPos[1] - self.BrainIntel.StartPos[1]
                local rz = unitPos[3] - self.BrainIntel.StartPos[3]
                local tmpDistance = rx * rx + rz * rz
                if not closestCivPD or tmpDistance < closestCivPD then
                    closestCivPD = tmpDistance
                end
            end
        end
        if closestCivPD then
            self.EnemyIntel.CivilianClosestPD = closestCivPD
        end
        --LOG('Civ units '..repr(civUnits))
    end,

        --- Called by a unit of this army when it is killed
    ---@param self AIBrain
    ---@param unit Unit
    ---@param instigator Unit | Projectile | nil
    ---@param damageType DamageType
    ---@param overkillRatio number
    OnUnitKilled = function(self, unit, instigator, damageType, overkillRatio)
        IntelManagerRNG.ProcessSourceOnDeath(self, unit, instigator, damageType)
    end,

    GetCallBackCheck = function(self, unit)
        local function AntiNavalRetreat(unit, instigator)
                --RNGLOG('AntiNavy Threat is '..repr(unit.PlatoonHandle.CurrentPlatoonThreatAntiNavy))
                if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) and instigator.Blueprint.CategoriesHash.ANTINAVY 
                and unit.PlatoonHandle and unit.PlatoonHandle.CurrentPlatoonThreatAntiNavy == 0 and (not unit.PlatoonHandle.RetreatOrdered) then
                    --RNGLOG('Naval Callback AntiNavy We want to retreat '..unit.UnitId)
                    unit.PlatoonHandle.RetreatOrdered = true
                end
            end
        local function AntiNavalRetreatState(unit, instigator)
            --RNGLOG('AntiNavy Threat is '..repr(unit.PlatoonHandle.CurrentPlatoonThreatAntiNavy))
            if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) and instigator.Blueprint.CategoriesHash.ANTINAVY 
            and unit.PlatoonHandle and unit.PlatoonHandle.CurrentPlatoonThreatAntiNavy == 0 and unit.PlatoonHandle.StateName ~= 'Retreating' then
                unit.PlatoonHandle:LogDebug(string.format('Naval retreat callback fired'))
                unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.Retreating)
            end
        end
        local function AntiAirRetreat(unit, instigator)
            --RNGLOG('AntiNavy Threat is '..repr(unit.PlatoonHandle.CurrentPlatoonThreatAntiAir))
            if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) and instigator.Blueprint.CategoriesHash.ANTINAVY and instigator.Blueprint.CategoriesHash.AIR
            and unit.PlatoonHandle and unit.PlatoonHandle.CurrentPlatoonThreatAntiAir == 0 and (not unit.PlatoonHandle.RetreatOrdered) then
                --RNGLOG('Naval Callback AntiAir We want to retreat '..unit.UnitId)
                unit.PlatoonHandle.RetreatOrdered = true
            end
        end
        local function AntiAirRetreatState(unit, instigator)
            --RNGLOG('AntiNavy Threat is '..repr(unit.PlatoonHandle.CurrentPlatoonThreatAntiAir))
            if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) and (instigator.Blueprint.CategoriesHash.ANTINAVY or instigator.Blueprint.CategoriesHash.BOMBER or instigator.Blueprint.CategoriesHash.GROUNDATTACK) and instigator.Blueprint.CategoriesHash.AIR and not instigator.Blueprint.CategoriesHash.TRANSPORTFOCUS
            and unit.PlatoonHandle and unit.PlatoonHandle.CurrentPlatoonThreatAntiAir == 0 and unit.PlatoonHandle.StateName ~= 'Retreating' then
                unit.PlatoonHandle:LogDebug(string.format('Naval retreat callback fired'))
                unit.PlatoonHandle:ChangeStateExt(unit.PlatoonHandle.Retreating)
            end
        end
        local function ACUDamageDetail(unit, instigator)
            --RNGLOG('ACU Damaged by unit '..repr(instigator.UnitId))
            if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) then
                if instigator.Blueprint.Defense.SurfaceThreatLevel 
                and instigator.Blueprint.Defense.SurfaceThreatLevel > 0 and instigator.Blueprint.CategoriesHash.AIR
                and (not unit.EnemyAirPresent) then
                --RNGLOG('ACU EnemyAir is now present '..instigator.UnitId)
                    unit.EnemyAirPresent = true
                elseif instigator.Blueprint.Defense.SubThreatLevel 
                and instigator.Blueprint.Defense.SubThreatLevel > 0 and instigator.Blueprint.CategoriesHash.ANTINAVY
                and (not unit.EnemyNavalPresent) then
                    unit.EnemyNavalPresent = true
                end
            end
        end
        local function AntiAirTransport(unit, instigator)
            --RNGLOG('AntiNavy Threat is '..repr(unit.PlatoonHandle.CurrentPlatoonThreatAntiAir))
            if instigator and instigator.IsUnit and (not IsDestroyed(instigator)) and instigator.Blueprint.CategoriesHash.ANTIAIR
            and unit.PlatoonHandle and (not unit.PlatoonHandle.DistressCall) then
                --RNGLOG('Naval Callback AntiAir We want to retreat '..unit.UnitId)
                unit.PlatoonHandle.DistressCall = true
            end
        end
        if unit.Blueprint.CategoriesHash.TECH1 and unit.Blueprint.CategoriesHash.FRIGATE then
            --RNGLOG('Naval Callback Setting up callback '..unit.UnitId)
            if unit.AIPlatoonReference then
                unit:AddOnDamagedCallback( AntiNavalRetreatState, nil, 100)
            else
                unit:AddOnDamagedCallback( AntiNavalRetreat, nil, 100)
            end
            if not unit.Blueprint.CategoriesHash.ANTIAIR then
                if unit.AIPlatoonReference then
                    unit:AddOnDamagedCallback( AntiAirRetreatState, nil, 100)
                else
                    unit:AddOnDamagedCallback( AntiAirRetreat, nil, 100)
                end
            end
        end
        if unit.Blueprint.CategoriesHash.TECH2 and unit.Blueprint.CategoriesHash.CRUISER then
            --RNGLOG('Naval Callback Setting up callback '..unit.UnitId)
            if unit.AIPlatoonReference then
                unit:AddOnDamagedCallback( AntiNavalRetreatState, nil, 100)
            else
                unit:AddOnDamagedCallback( AntiNavalRetreat, nil, 100)
            end
        end
        if unit.Blueprint.CategoriesHash.TECH2 and unit.Blueprint.CategoriesHash.DESTROYER then
            --RNGLOG('Naval Callback Setting up callback '..unit.UnitId)
            if unit.AIPlatoonReference then
                unit:AddOnDamagedCallback( AntiAirRetreatState, nil, 100)
            else
                unit:AddOnDamagedCallback( AntiAirRetreat, nil, 100)
            end
        end
        if unit.Blueprint.CategoriesHash.TECH3 and unit.Blueprint.CategoriesHash.BATTLESHIP then
            --RNGLOG('Naval Callback Setting up callback '..unit.UnitId)
            if unit.AIPlatoonReference then
                unit:AddOnDamagedCallback( AntiAirRetreatState, nil, 100)
                unit:AddOnDamagedCallback( AntiNavalRetreatState, nil, 100)
            else
                unit:AddOnDamagedCallback( AntiAirRetreat, nil, 100)
                unit:AddOnDamagedCallback( AntiNavalRetreat, nil, 100)
            end
        end
        if unit.Blueprint.CategoriesHash.COMMAND then
            unit:AddOnDamagedCallback( ACUDamageDetail, nil, 100)
        end
    end,

    CDRDataThreads = function(self, unit)
        local ACUFunc = import('/mods/RNGAI/lua/AI/RNGACUFunctions.lua')
        local im = IntelManagerRNG.GetIntelManager(self)
        local acuUnits = GetListOfUnits(self, categories.COMMAND, false)
        for _, v in acuUnits do
            if not IsDestroyed(v) then
                self:GetCallBackCheck(v)
                if not self.CDRUnit or self.CDRUnit.Dead then
                    self.CDRUnit = v
                end
                if  not self.ACUData[v.EntityId] then
                    self.ACUData[v.EntityId] = {}
                    self.ACUData[v.EntityId].CDRHealthThread = v:ForkThread(ACUFunc.CDRHealthThread)
                    self.ACUData[v.EntityId].CDRBrainThread = v:ForkThread(ACUFunc.CDRBrainThread)
                    self.ACUData[v.EntityId].CDRThreatAssessment = v:ForkThread(ACUFunc.CDRThreatAssessmentRNG)
                    self.ACUData[v.EntityId].CDRUnit = v
                end
            end
        end
        --RUtils.GenerateChokePointLines(self)
    end,

        ---@deprecated
    ---@param self AIBrain
    InitializePlatoonBuildManager = function(self)
       --('Starting PlatoonBuildManager')
        --LOG('Initialize Skirmish Systems')
        --RNGLOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon.ArmyPool = true
            poolPlatoon:TurnOffPoolAI()
        end
        self:ForkThread(self.SetupPlayableArea)
        self:ConfigureDefaultBrainData()
        --local mapSizeX, mapSizeZ = GetMapSize()
        --RNGLOG('Map X size is : '..mapSizeX..'Map Z size is : '..mapSizeZ)
        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}
        
        
        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        --LOG('Adding builder managers at '..repr(self:GetStartVector3f()))
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)
        -- Generates the zones and updates the resource marker table with Zone IDs
        --IntelManagerRNG.GenerateMapZonesRNG(self)

        self:IMAPConfigurationRNG()
        -- Begin the base monitor process
        self:NoRushCheck()

        self:BaseMonitorInitializationRNG()

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)
        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitorRNG)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.SetupACUData)
        self:ForkThread(self.CivilianUnitCheckRNG)
        self:ForkThread(self.EcoPowerManagerRNG)
        self:ForkThread(self.EcoPowerPreemptiveRNG)
        self:ForkThread(self.EcoMassManagerRNG)
        self:ForkThread(self.BasePerimeterMonitorRNG)
        self:ForkThread(self.EnemyChokePointTestRNG)
        self:ForkThread(self.EngineerAssistManagerBrainRNG)
        self:ForkThread(self.AllyEconomyHelpThread)
        self:ForkThread(self.HeavyEconomyRNG)
        self:ForkThread(IntelManagerRNG.LastKnownThread)
        self:ForkThread(RUtils.CanPathToCurrentEnemyRNG)
        self:ForkThread(Mapping.SetMarkerInformation)
        self:ForkThread(self.SetupIntelTriggersRNG)
        self:ForkThread(IntelManagerRNG.InitialNavalAttackCheck)
        self.ZonesInitialized = false
        self:ForkThread(self.ZoneSetup)
        self.IntelManager = IntelManagerRNG.CreateIntelManager(self)
        self.IntelManager:Run()
        self.StructureManager = StructureManagerRNG.CreateStructureManager(self)
        self.StructureManager:Run()
        self:ForkThread(IntelManagerRNG.CreateIntelGrid, self.IntelManager)
        self:ForkThread(self.CreateFloatingEngineerBase, self.BrainIntel.StartPos)
        self:ForkThread(self.SetMinimumBasePower)
        self:ForkThread(self.CalculateMassMarkersRNG)
        if self.RNGDEBUG then
            self:ForkThread(self.LogDataThreadRNG)
        end
        self:ForkThread(self.WatchForCampaignStart)
    end,

    WatchForCampaignStart = function(self)
        local hasRun = false
        while not hasRun do
            coroutine.yield(30)
            local mainManagers = self.BuilderManagers.MAIN
            local pool = self:GetPlatoonUniquelyNamed('ArmyPool')
            --LOG('ArmyPool current has '..table.getn(pool:GetPlatoonUnits())..' in it')
            for k,v in pool:GetPlatoonUnits() do
                if EntityCategoryContains(categories.ENGINEER, v) then
                    hasRun = true
                    mainManagers.EngineerManager:AddUnit(v)
                elseif EntityCategoryContains(categories.FACTORY * categories.STRUCTURE, v) then
                    hasRun = true
                    mainManagers.FactoryManager:AddFactory(v)
                end
            end
        end
        self:ForkThread(self.MonitorCampaignAIPBMLocations)
        --LOG('ACU Should be present now')
    end,

    MonitorCampaignAIPBMLocations = function(self)
        while self.Status ~= 'Defeat' do
            coroutine.yield(100)
            local myIndex = self:GetArmyIndex()
            for index,brain in ArmyBrains do
                local armyIndex = brain:GetArmyIndex()
                if IsEnemy(myIndex, armyIndex) then
                    if brain.PBM.Locations then
                        local bestLocation
                        local bestLocationThreat
                        for _, v in brain.PBM.Locations do
                            local threat = GetThreatAtPosition(self, v.Location, self.BrainIntel.IMAPConfig.Rings, true, 'StructuresNotMex')
                            if not bestLocationThreat or threat > bestLocationThreat then
                                bestLocationThreat = threat
                                bestLocation = v.Location
                            end
                        end
                        if bestLocation then
                            if self.EnemyIntel.EnemyStartLocations[armyIndex] then
                                local enemyPos = self.EnemyIntel.EnemyStartLocations[armyIndex].Position
                                if enemyPos and enemyPos[1] ~= bestLocation[1] and enemyPos[3] ~= bestLocation[3] then
                                    local enemyDistance = VDist3Sq(self.BrainIntel.StartPos, bestLocation)
                                    if self.EnemyIntel.ClosestEnemyBase == 0 or enemyDistance < self.EnemyIntel.ClosestEnemyBase then
                                        self.EnemyIntel.ClosestEnemyBase = enemyDistance
                                    end
                                    self.EnemyIntel.EnemyStartLocations[armyIndex] = {Position = bestLocation, Index = armyIndex, Distance = enemyDistance, WaterLabels = {}}
                                    --LOG('Changed enemy start pos to '..tostring(self.EnemyIntel.EnemyStartLocations[armyIndex].Position[1])..':'..tostring(self.EnemyIntel.EnemyStartLocations[armyIndex].Position[3]))
                                end
                            else
                                local enemyDistance = VDist3Sq(self.BrainIntel.StartPos, bestLocation)
                                if self.EnemyIntel.ClosestEnemyBase == 0 or enemyDistance < self.EnemyIntel.ClosestEnemyBase then
                                    self.EnemyIntel.ClosestEnemyBase = enemyDistance
                                end
                                self.EnemyIntel.EnemyStartLocations[armyIndex] = {Position = bestLocation, Index = armyIndex, Distance = enemyDistance, WaterLabels = {}}
                                --LOG('Set enemy start pos to '..tostring(self.EnemyIntel.EnemyStartLocations[armyIndex].Position[1])..':'..tostring(self.EnemyIntel.EnemyStartLocations[armyIndex].Position[3]))
                            end
                        end
                    end
                end
            end
        end
    end,

    AdjustEconomicAllocation = function (self)
        coroutine.yield(50)
    
        while self.Status ~= 'Defeat' do
            coroutine.yield(30)
    
            -- Configurable ratios for economy spend and assist
            local economySpendRatio = 0.05 -- Reserve 5% of the economy for economic upgrades
            local assistRatio = 0.05 -- Reserve 5% of the economy for assisting tasks
            local economyUpgradeSpend = self.EconomyUpgradeSpendDefault or 0.05
            local engineerAssistRatio = self.EngineerAssistRatioDefault or 0.05
            if self.BrainIntel.HighestPhase > 1 then
                economyUpgradeSpend = economyUpgradeSpend + (0.03 * self.BrainIntel.HighestPhase)
            end
            if self.BrainIntel.PlayerStrategy.T3AirRush then
                engineerAssistRatio = engineerAssistRatio + 0.2
            end

            local economyUpgradeSpendMin = 0.02 -- Minimum economy allocation
            local economyUpgradeSpendMax = 0.45 -- Maximum economy allocation
            local engineerAssistRatioMin = 0.02 -- Minimum assist allocation
            local engineerAssistRatioMax = 0.60 -- Maximum assist allocation
            local brainIntel = self.BrainIntel
            local highestPhase =  math.max(brainIntel.LandPhase, brainIntel.AirPhase, brainIntel.NavalPhase)
            local ignoreZoneControl = not brainIntel.PlayerRole.AirPlayer and not brainIntel.PlayerRole.ExperimentalPlayer
    
            local isNavalMap = false
            if self.MapWaterRatio > 0.50 then
                local currentEnemy = self:GetCurrentEnemy()
                if currentEnemy then
                    local enemyIndex = currentEnemy:GetArmyIndex()
                    local ownIndex = self:GetArmyIndex()
                    local labelCount = brainIntel.NavalBaseLabelCount
                    if self.CanPathToEnemyRNG[ownIndex][enemyIndex]['MAIN'] ~= 'LAND' and self.MapWaterRatio > 0.50 and labelCount and labelCount > 0 then
                        isNavalMap = true
                    end
                end
            end
            local playerBiases = {
                Default = { Land = 1.0, Air = 1.0, Naval = 1.0 },
                Land = { Land = 1.5, Air = 0.8, Naval = 0.7 },
                Air = { Land = 0.7, Air = 1.5, Naval = 0.8 },
                Naval = { Land = 0.7, Air = 0.8, Naval = 1.5 },
                ChokePoint = { Land = 0.3, Air = 1.0, Naval = 1.0 }
            }
            local currentBias = brainIntel.PlayerRole.AirPlayer and playerBiases.Air or brainIntel.PlayerRole.SpamPlayer and playerBiases.Land or isNavalMap and playerBiases.Naval 
            or self.EnemyIntel.ChokeFlag and playerBiases.ChokePoint or playerBiases.Default
    
            local minAllocation = 0.20
            local maxShiftLandRatio = 0.70
            local maxShiftAirRatio = 0.70
            local maxShiftNavalRatio = 0.70
            if brainIntel.PlayerRole.SpamPlayer then
                maxShiftLandRatio = 0.80
                economyUpgradeSpend = 0.05
                engineerAssistRatio = 0.05
            elseif brainIntel.PlayerZoneControl < 0.70 and highestPhase < 2 and not ignoreZoneControl then
                economyUpgradeSpend = 0.05
                engineerAssistRatio = 0.05
            end
            local landBias = 0.3 -- Reduction for land allocation on naval maps
            local navalBias = 1.5 -- Boost for naval allocation on naval maps
            local threatFactorThreshold = 1.3 -- Threshold for reallocating excess
    
            -- Factory production capabilities
            local sm = import('/mods/RNGAI/lua/StructureManagement/StructureManager.lua').GetStructureManager(self)
            local smFactories = sm.Factories
            local hasLandProduction = smFactories.LAND[1].Total > 0 or smFactories.LAND[2].Total > 0 or smFactories.LAND[3].Total > 0
            local hasAirProduction = smFactories.AIR[1].Total > 0 or smFactories.AIR[2].Total > 0 or smFactories.AIR[3].Total > 0
            local hasNavalProduction = smFactories.NAVAL[1].Total > 0 or smFactories.NAVAL[2].Total > 0 or smFactories.NAVAL[3].Total > 0
    
            -- Total Income
            local totalIncome = self.cmanager.income.r.m
            local extractorValues = self.EcoManager.ExtractorValues
            local maxEconomyAllocation = (extractorValues.TECH1.TeamValue * extractorValues.TECH1.ConsumptionValue) + (extractorValues.TECH2.TeamValue * extractorValues.TECH2.ConsumptionValue)
            if maxEconomyAllocation > 0 and totalIncome > 0 then
                economyUpgradeSpendMax = math.min(self.EconomyUpgradeSpend, maxEconomyAllocation / totalIncome)
            end
    
            -- Threat Ratios
            local myThreat = brainIntel.SelfThreat
            local enemyThreat = self.EnemyIntel.EnemyThreatCurrent
    
            -- First, calculate the excess allocation for all categories:
            local excessAllocation = 0

            -- Check for land excess
            if hasLandProduction and ((myThreat.LandNow + myThreat.AllyLandThreat) > enemyThreat.Land * threatFactorThreshold) then
                local landExcess = math.max(0, (self.ProductionRatios.Land - minAllocation))
                excessAllocation = excessAllocation + landExcess
                self.ProductionRatios.Land = minAllocation
            end

            -- Check for air excess
            if hasAirProduction and (myThreat.AntiAirNow + myThreat.AllyAirThreat > enemyThreat.AntiAir * threatFactorThreshold) then
                local airExcess = math.max(0, (self.ProductionRatios.Air - minAllocation))
                excessAllocation = excessAllocation + airExcess
                self.ProductionRatios.Air = minAllocation
            end

            -- Check for naval excess
            if hasNavalProduction and (myThreat.NavalNow + myThreat.AllyNavalThreat > enemyThreat.Naval * threatFactorThreshold) then
                local navalExcess = math.max(0, (self.ProductionRatios.Naval - minAllocation))
                excessAllocation = excessAllocation + navalExcess
                self.ProductionRatios.Naval = minAllocation
            end

            -- Now, redistribute the excess to the economy and assist ratios
            local additionalEconomyRatio = excessAllocation * 0.5 -- 50% to economy
            local newEconomySpend = economyUpgradeSpend + additionalEconomyRatio

            -- Nudge economyUpgradeSpend
            if newEconomySpend > self.EconomyUpgradeSpendDefault or newEconomySpend > economyUpgradeSpendMax then
                -- Nudge upward toward max if excess is available
                economyUpgradeSpend = math.min(newEconomySpend, economyUpgradeSpendMax)
                if economyUpgradeSpend < newEconomySpend then
                    excessAllocation = excessAllocation + math.max(0, (newEconomySpend - economyUpgradeSpend))
                end
            else
                -- Nudge downward toward default or min if no excess
                economyUpgradeSpend = math.max(newEconomySpend, economyUpgradeSpendMin)
            end

            -- Now, we calculate the production ratios with the redistribution and necessary clamping

            -- Calculate available budget for production (after reserving for economy and assist)
            local totalThreatRatio = myThreat.LandNow + myThreat.AllyLandThreat + myThreat.AntiAirNow + myThreat.AllyAntiAirThreat + myThreat.NavalNow + myThreat.AllyNavalThreat + enemyThreat.Land + enemyThreat.AntiAir + enemyThreat.Naval
            local availableRatio = 1 - economyUpgradeSpend  -- Now we are only reserving for economy upgrades here
            if totalThreatRatio == 0 then
                totalThreatRatio = 1  -- To avoid division by zero
            end
            
            -- Calculate the production allocation first
            local reservedProductionRatio = economyUpgradeSpend  -- Reserve for economy upgrades only, not engineer assist
            local productionAllocation = math.max(1 - reservedProductionRatio, 0)  -- What’s left for production
            
            -- Normalize default production ratios to fit within productionAllocation
            local normalizedLandRatio = self.DefaultProductionRatios['Land'] * productionAllocation
            local normalizedAirRatio = self.DefaultProductionRatios['Air'] * productionAllocation
            local normalizedNavalRatio = self.DefaultProductionRatios['Naval'] * productionAllocation
            
            -- Calculate the new production ratios, clamping them as needed
            local newLandRatio = hasLandProduction and math.max(
                minAllocation,
                math.min(
                    normalizedLandRatio + (
                        (enemyThreat.Land > myThreat.LandNow and (enemyThreat.Land - (myThreat.LandNow + myThreat.AllyLandThreat)) / totalThreatRatio or 0)
                        * maxShiftLandRatio
                        * currentBias.Land
                    ),
                    maxShiftLandRatio
                )
            ) or 0
            
            local newAirRatio = hasAirProduction and math.max(
                minAllocation,
                math.min(
                    normalizedAirRatio - (
                        (myThreat.AntiAirNow > enemyThreat.AntiAir and (myThreat.AntiAirNow - (enemyThreat.AntiAir + myThreat.AllyAntiAirThreat)) / totalThreatRatio or 0)
                        * maxShiftAirRatio
                        * currentBias.Air
                    ),
                    maxShiftAirRatio
                )
            ) or 0
            
            local newNavalRatio = hasNavalProduction and math.max(
                minAllocation,
                math.min(
                    normalizedNavalRatio + (
                        (enemyThreat.Naval > myThreat.NavalNow and (enemyThreat.Naval - (myThreat.NavalNow + myThreat.AllyNavalThreat)) / totalThreatRatio or 0)
                        * maxShiftNavalRatio
                        * currentBias.Naval
                    ),
                    maxShiftNavalRatio
                )
            ) or 0
            
            -- Now we have production ratios, let's calculate the excess resources for engineer assists
            local totalProductionRatio = newLandRatio + newAirRatio + newNavalRatio
            
            -- Normalize the production ratios and apply availableRatio and maxShiftRatios clamping
            if totalProductionRatio > 0 then
                newLandRatio = math.min((newLandRatio / totalProductionRatio) * availableRatio, maxShiftLandRatio)
                newAirRatio = math.min((newAirRatio / totalProductionRatio) * availableRatio, maxShiftAirRatio)
                newNavalRatio = math.min((newNavalRatio / totalProductionRatio) * availableRatio, maxShiftNavalRatio)
            end

            local landMaxRatio = 0
            local airMaxRatio = 0
            local navalMaxRatio = 0
            if totalIncome > 0 then
                landMaxRatio = self.EcoManager.ApproxLandFactoryMassConsumption / totalIncome
                airMaxRatio = self.EcoManager.ApproxAirFactoryMassConsumption / totalIncome
                navalMaxRatio = self.EcoManager.ApproxNavalFactoryMassConsumption / totalIncome
            end

            -- Adjust Land Ratio
            if newLandRatio > landMaxRatio then
                local excessRatio = newLandRatio - landMaxRatio
                excessAllocation = excessAllocation + excessRatio
            end

            -- Adjust Air Ratio
            if newAirRatio > airMaxRatio then
                local excessRatio = newAirRatio - airMaxRatio
                excessAllocation = excessAllocation + excessRatio
            end

            -- Adjust Naval Ratio
            if newNavalRatio > navalMaxRatio then
                local excessRatio = newNavalRatio - navalMaxRatio
                excessAllocation = excessAllocation + excessRatio
            end
            
            -- Now that production has been allocated, we can handle the engineer assist
            local newAssistRatio = engineerAssistRatio + excessAllocation -- Use remaining allocation for assists
            
            -- Nudge engineerAssistRatio
            if newAssistRatio > self.EngineerAssistRatioDefault then
                -- Nudge upward toward max if excess is available
                engineerAssistRatio = math.min(newAssistRatio, engineerAssistRatioMax)
            else
                -- Nudge downward toward default or min if no excess
                engineerAssistRatio = math.max(newAssistRatio, engineerAssistRatioMin)
            end

            -- Assign the final production ratios
            self.ProductionRatios.Land = newLandRatio
            self.ProductionRatios.Air = newAirRatio
            self.ProductionRatios.Naval = newNavalRatio
            self.EngineerAssistRatio = engineerAssistRatio
    
            -- Logging
            --[[
            LOG('AI Name '..tostring(self.Nickname))
            LOG('Current Best Army ownership is '..tostring(brainIntel.PlayerZoneControl))
            LOG('Current game time '..tostring(GetGameTimeSeconds()))
            LOG('Are we a naval map '..tostring(isNavalMap))
            LOG('Has Land Production: '..tostring(hasLandProduction))
            LOG('Has Air Production: '..tostring(hasAirProduction))
            LOG('Has Naval Production: '..tostring(hasNavalProduction))
            LOG('Map water ratio '..tostring(self.MapWaterRatio))
            LOG('----- Threat Metrics -----')
            LOG('self.EnemyIntel.EnemyThreatCurrent.Land '..tostring(enemyThreat.Land))
            LOG('self.EnemyIntel.EnemyThreatCurrent.AntiAir '..tostring(enemyThreat.AntiAir))
            LOG('self.EnemyIntel.EnemyThreatCurrent.Naval '..tostring(enemyThreat.Naval))
            LOG('self.BrainIntel.SelfThreat.LandNow '..tostring(myThreat.LandNow))
            LOG('self.BrainIntel.SelfThreat.AllyLandThreat '..tostring(myThreat.AllyLandThreat))
            LOG('self.BrainIntel.SelfThreat.AntiAirNow '..tostring(myThreat.AntiAirNow))
            LOG('self.BrainIntel.SelfThreat.AllyAntiAirThreat '..tostring(myThreat.AllyAntiAirThreat))
            LOG('self.BrainIntel.SelfThreat.NavalNow '..tostring(myThreat.NavalNow))
            LOG('self.BrainIntel.SelfThreat.AllyNavalThreat '..tostring(myThreat.AllyNavalThreat))
            LOG('----- Production Metrics -----')
            LOG('Default Land Ratio '..tostring(self.DefaultProductionRatios['Land']))
            LOG('Default Air Ratio '..tostring(self.DefaultProductionRatios['Air']))
            LOG('Default Naval Ratio '..tostring(self.DefaultProductionRatios['Naval']))
            LOG('ECOLOG: GameTime: '..tostring(GetGameTimeSeconds()))
            LOG('ECOLOG: ProductionRatiosLand: '..tostring(self.ProductionRatios.Land))
            LOG('ECOLOG: ProductionRatiosAir: '..tostring(self.ProductionRatios.Air))
            LOG('ECOLOG: ProductionRatiosNaval: '..tostring(self.ProductionRatios.Naval))
            LOG('----- Economy Metrics -----')
            LOG('self.EcoManager.TotalExtractors.TECH1 '..tostring(self.EcoManager.TotalExtractors.TECH1))
            LOG('self.EcoManager.TotalExtractors.TECH2 '..tostring(self.EcoManager.TotalExtractors.TECH2))
            LOG('self.EcoManager.ExtractorsUpgrading.TECH1 '..tostring(self.EcoManager.ExtractorsUpgrading.TECH1))
            LOG('self.EcoManager.ExtractorsUpgrading.TECH2 '..tostring(self.EcoManager.ExtractorsUpgrading.TECH2))
            LOG('self.EcoManager.TotalMexSpend '..tostring(self.EcoManager.TotalMexSpend))
            LOG('In theory we can allocate this much spend max '..tostring((self.EcoManager.ExtractorValues.TECH1.TeamValue * self.EcoManager.ExtractorValues.TECH1.ConsumptionValue) + (self.EcoManager.ExtractorValues.TECH2.TeamValue * self.EcoManager.ExtractorValues.TECH2.ConsumptionValue)))
            LOG('EconomyUpdate Spend Max Ratio is '..tostring(economyUpgradeSpendMax))
            LOG('----- Spend Metrics ------')
            LOG('ECOLOG: RequestedSpendLand * totalIncome: '..tostring(self.ProductionRatios.Land * totalIncome))
            LOG('ECOLOG: RequestedSpendAir * totalIncome: '..tostring(self.ProductionRatios.Air * totalIncome))
            LOG('ECOLOG: RequestedSpendNaval * totalIncome: '..tostring(self.ProductionRatios.Naval * totalIncome))
            LOG('ECOLOG: Economy Spend Ratio: '..tostring(economyUpgradeSpend))
            LOG('ECOLOG: Current Spend desired: '..tostring(self.cmanager.income.r.m*self.EconomyUpgradeSpend))
            LOG('ECOLOG: Current Extractor upgrade Spend to allocate: '..tostring(economyUpgradeSpend * totalIncome))
            LOG('ECOLOG: Current Extractor upgrade Spend actual: '..tostring(self.EcoManager.TotalMexSpend))
            LOG('ECOLOG: Assist Ratio: '..tostring(engineerAssistRatio))
            LOG('Assist Economy allocation: '..tostring(engineerAssistRatio * totalIncome))
            LOG('Builder Power '..tostring(self.EngineerAssistManagerBuildPower))
            LOG('Required '..tostring(self.EngineerAssistManagerBuildPowerRequired))
            LOG('Excess Allocation at the end of loop was '..tostring(excessAllocation))
            LOG('Current Bias '..tostring(repr(currentBias)))
            ]]
        end
    end,

    -- These are all callbacks
    ---@param self BaseAIBrain
    ---@param unit Unit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStopBeingBuilt = function(self, unit, builder, layer)
        if unit.GetFractionComplete and unit:GetFractionComplete() == 1 then
            ForkThread(RNGEventCallbacks.OnStopBeingBuilt, self, unit, builder, layer) 
        end
    end,
    



}
