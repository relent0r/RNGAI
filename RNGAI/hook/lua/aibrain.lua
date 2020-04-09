WARN('['..string.gsub(debug.getinfo(1).source, ".*\\(.*.lua)", "%1")..', line:'..debug.getinfo(1).currentline..'] * RNGAI: offset aibrain.lua' )

local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/AIUtilities.lua')

local GetEconomyIncome = moho.aibrain_methods.GetEconomyIncome
local GetEconomyRequested = moho.aibrain_methods.GetEconomyRequested
local GetEconomyStored = moho.aibrain_methods.GetEconomyStored
local GetListOfUnits = moho.aibrain_methods.GetListOfUnits
local VDist2Sq = VDist2Sq
local WaitTicks = coroutine.yield

local RNGAIBrainClass = AIBrain
AIBrain = Class(RNGAIBrainClass) {

    OnCreateAI = function(self, planName)
        RNGAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        --LOG('Oncreate')
        if string.find(per, 'RNG') then
            LOG('* AI-RNG: This is RNG')
            self.RNG = true

            -- Structure Upgrade properties
            self.UpgradeMode = 'Normal'
            self.UpgradeIssued = 0
		    self.UpgradeIssuedLimit = 2
            self.UpgradeIssuedPeriod = 225

            -- ACU Support Data
            self.ACUSupport = {}
            self.ACUSupport.Supported = false
            self.ACUSupport.PlatoonCount = 0
            self.ACUSupport.Position = {}
            self.ACUSupport.TargetPosition = false
            self.ACUSupport.ReturnHome = true

            -- Misc
            self.ReclaimEnabled = true
            self.ReclaimLastCheck = 0
        end
    end,

    OnSpawnPreBuiltUnits = function(self)
        if not self.RNG then
            return RNGAIBrainClass.OnSpawnPreBuiltUnits(self)
        end
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
                if unit ~= nil then
                    if not self.StructurePool then
                        RUtils.CheckCustomPlatoons(self)
                    end
                    local StructurePool = self.StructurePool
                    self:AssignUnitsToPlatoon(StructurePool, {unit}, 'Support', 'none' )
                    local upgradeID = unitBp.General.UpgradesTo or false
                    --LOG('* AI-RNG: BlueprintID to upgrade to is : '..unitBp.General.UpgradesTo)
                    if upgradeID and __blueprints[upgradeID] then
                        RUtils.StructureUpgradeInitialize(unit, self)
                    end
                    local unitTable = StructurePool:GetPlatoonUnits()
                    --LOG('* AI-RNG: StructurePool now has :'..table.getn(unitTable))
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

    InitializeSkirmishSystems = function(self)
        if not self.RNG then
            return RNGAIBrainClass.InitializeSkirmishSystems(self)
        end
        LOG('* AI-RNG: Custom Skirmish System for '..ScenarioInfo.ArmySetup[self.Name].AIPersonality)
        -- Make sure we don't do anything for the human player!!!
        if self.BrainType == 'Human' then
            return
        end

        -- TURNING OFF AI POOL PLATOON, I MAY JUST REMOVE THAT PLATOON FUNCTIONALITY LATER
        local poolPlatoon = self:GetPlatoonUniquelyNamed('ArmyPool')
        if poolPlatoon then
            poolPlatoon:TurnOffPoolAI()
        end

        -- Stores handles to all builders for quick iteration and updates to all
        self.BuilderHandles = {}

        -- Condition monitor for the whole brain
        self.ConditionsMonitor = BrainConditionsMonitor.CreateConditionsMonitor(self)

        -- Economy monitor for new skirmish - stores out econ over time to get trend over 10 seconds
        self.EconomyData = {}
        self.EconomyTicksMonitor = 50
        self.EconomyCurrentTick = 1
        self.EconomyMonitorThread = self:ForkThread(self.EconomyMonitor)
        self.LowEnergyMode = false
        self.EcoManager = {
            EcoManagerTime = 30,
            EcoManagerStatus = 'ACTIVE',
            ExtractorUpgradeLimit = {
                TECH1 = 1,
                TECH2 = 1
            },
            ExtractorsUpgrading = {TECH1 = 0, TECH2 = 0},
        }
        self.EcoManager.PriorityTable = {
            ENGINEER = 11,
            SHIELD = 9,
            AIR = 10,
            LAND = 5,
            RADAR = 6,
            MASSEXTRACTION = 4,
            MASSFABRICATION = 8,
            NUKE = 7,
        }
        

        --Tactical Monitor
        self.TacticalMonitor = {
            TacticalMonitorStatus = 'ACTIVE',
            TacticalLocationFound = false,
            TacticalLocations = {},
            TacticalTimeout = 53,
            TacticalMonitorTime = 180,
            TacticalMassLocations = {},
            TacticalUnmarkedMassGroups = {},
            TacticalSACUMode = false,
        }
        -- Intel Data
        self.EnemyIntel = {}
        self.EnemyIntel.ACU = {}
        self.EnemyIntel.EnemyStartLocations = {}
        self.EnemyIntel.EnemyThreatLocations = {}
        self.EnemyIntel.EnemyThreatRaw = {}
        self.EnemyIntel.EnemyThreatCurrent = {
            Air = 0,
            Land = 0,
            Experimental = 0,
        }

        self.BrainIntel = {}
        self.BrainIntel.SelfThreat = {}
        self.BrainIntel.Average = {
            Air = 0,
            Land = 0,
            Experimental = 0,
        }
        self.BrainIntel.SelfThreat.Air = {}
        

        -- Add default main location and setup the builder managers
        self.NumBases = 0 -- AddBuilderManagers will increase the number

        self.BuilderManagers = {}
        SUtils.AddCustomUnitSupport(self)
        self:AddBuilderManagers(self:GetStartVector3f(), 100, 'MAIN', false)

        if RUtils.InitialMassMarkersInWater(self) then
            LOG('* AI-RNG: Map has mass markers in water')
            self.MassMarkersInWater = true
        else
            LOG('* AI-RNG: Map does not have mass markers in water')
            self.MassMarkersInWater = false
        end
        RUtils.TacticalMassLocations(self)
        RUtils.MarkTacticalMassLocations(self)
        local MassGroupMarkers = RUtils.GenerateMassGroupMarkerLocations(self)
        if table.getn(MassGroupMarkers) > 0 then
            RUtils.CreateMarkers('Unmarked Expansion', MassGroupMarkers)
        end
        -- Begin the base monitor process

        self:BaseMonitorInitializationRNG()

        local plat = self:GetPlatoonUniquelyNamed('ArmyPool')
        plat:ForkThread(plat.BaseManagersDistressAIRNG)

        self.DeadBaseThread = self:ForkThread(self.DeadBaseMonitor)
        self.EnemyPickerThread = self:ForkThread(self.PickEnemyRNG)
        self:ForkThread(self.EcoManagerThreadRNG)
    end,
    
    BaseMonitorThreadRNG = function(self)
        while true do
            if self.BaseMonitor.BaseMonitorStatus == 'ACTIVE' then
                self:BaseMonitorCheckRNG()
            end
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
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
            BaseMonitorTime = spec.BaseMonitorTime or 11,
            -- Default distance a platoon will travel to help around the base
            DefaultDistressRange = spec.DefaultDistressRange or 75,
            -- Default how often platoons will check if the base is under duress
            PlatoonDefaultReactionTime = spec.PlatoonDefaultReactionTime or 5,
            -- Default duration for an alert to time out
            DefaultAlertTimeout = spec.DefaultAlertTimeout or 10,

            PoolDistressThreshold = 1,

            -- Monitor platoons for help
            PlatoonDistressTable = {},
            PlatoonDistressThread = false,
            PlatoonAlertSounded = false,
        }
        self:ForkThread(self.BaseMonitorThreadRNG)
        self:ForkThread(self.TacticalMonitorInitializationRNG)
    end,

    BaseMonitorCheckRNG = function(self)
        
        local gameTime = GetGameTimeSeconds()
        if gameTime < 300 then
            -- default monitor spec
        elseif gameTime > 300 then
            self.BaseMonitor.PoolDistressRange = 130
            self.AlertLevel = 5
        end

        local vecs = self:GetStructureVectors()
        if table.getn(vecs) > 0 then
            -- Find new points to monitor
            for k, v in vecs do
                local found = false
                for subk, subv in self.BaseMonitor.BaseMonitorPoints do
                    if v[1] == subv.Position[1] and v[3] == subv.Position[3] then
                        found = true
                        -- if we found this point already stored, we don't need to continue searching the rest
                        break
                    end
                end
                if not found then
                    table.insert(self.BaseMonitor.BaseMonitorPoints,
                        {
                            Position = v,
                            Threat = self:GetThreatAtPosition(v, 0, true, 'Overall'),
                            Alert = false
                        }
                    )
                end
            end
            -- Remove any points that we dont monitor anymore
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                local found = false
                for subk, subv in vecs do
                    if v.Position[1] == subv[1] and v.Position[3] == subv[3] then
                        found = true
                        break
                    end
                end
                -- If point not in list and the num units around the point is small
                if not found and self:GetNumUnitsAroundPoint(categories.STRUCTURE, v.Position, 16, 'Ally') <= 1 then
                    table.remove(self.BaseMonitor.BaseMonitorPoints, k)
                end
            end
            -- Check monitor points for change
            local alertThreat = self.BaseMonitor.AlertLevel
            for k, v in self.BaseMonitor.BaseMonitorPoints do
                if not v.Alert then
                    v.Threat = self:GetThreatAtPosition(v.Position, 0, true, 'Overall')
                    if v.Threat > alertThreat then
                        v.Alert = true
                        table.insert(self.BaseMonitor.AlertsTable,
                            {
                                Position = v.Position,
                                Threat = v.Threat,
                            }
                        )
                        self.BaseMonitor.AlertSounded = true
                        self:ForkThread(self.BaseMonitorAlertTimeout, v.Position)
                        self.BaseMonitor.ActiveAlerts = self.BaseMonitor.ActiveAlerts + 1
                    end
                end
            end
        end
    end,

    BuildScoutLocationsRNG = function(self)
        local aiBrain = self
        local opponentStarts = {}
        local startLocations = {}
        local startPosMarkers = {}
        local allyStarts = {}
        

        if not aiBrain.InterestList then
            aiBrain.InterestList = {}
            aiBrain.IntelData.HiPriScouts = 0
            aiBrain.IntelData.AirHiPriScouts = 0
            aiBrain.IntelData.AirLowPriScouts = 0
            

            -- Add each enemy's start location to the InterestList as a new sub table
            aiBrain.InterestList.HighPriority = {}
            aiBrain.InterestList.LowPriority = {}
            aiBrain.InterestList.MustScout = {}

            local myArmy = ScenarioInfo.ArmySetup[self.Name]
            if aiBrain.EnemyIntel.EnemyThreatLocations then
                for _, v in aiBrain.EnemyIntel.EnemyThreatLocations do
                    -- Add any threat locations found in the must scout table
                    table.insert(aiBrain.InterestList.MustScout, 
                        {
                            Position = v.Position,
                            LastScouted = 0,
                        }
                    )
                end
            end
            if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                -- Spawn locations were fixed. We know exactly where our opponents are.
                -- Don't scout areas owned by us or our allies.
                local numOpponents = 0
                local enemyStarts = {}
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        table.insert(startLocations, startPos)
                        if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                        -- Add the army start location to the list of interesting spots.
                        opponentStarts['ARMY_' .. i] = startPos
                        numOpponents = numOpponents + 1
                        table.insert(enemyStarts, startPos)
                        table.insert(aiBrain.InterestList.HighPriority,
                            {
                                Position = startPos,
                                LastScouted = 0,
                            }
                        )
                        else
                            allyStarts['ARMY_' .. i] = startPos
                        end
                    end
                end

                aiBrain.NumOpponents = numOpponents

                -- For each vacant starting location, check if it is closer to allied or enemy start locations (within 100 ogrids)
                -- If it is closer to enemy territory, flag it as high priority to scout.
                local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
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
                            table.insert(aiBrain.InterestList.LowPriority,
                                {
                                    Position = loc.Position,
                                    LastScouted = 0,
                                }
                            )
                        end
                    end
                end
                aiBrain.EnemyIntel.EnemyStartLocations = enemyStarts
            else -- Spawn locations were random. We don't know where our opponents are. Add all non-ally start locations to the scout list
                local numOpponents = 0
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position

                    if army and startPos then
                        if army.ArmyIndex == myArmy.ArmyIndex or (army.Team == myArmy.Team and army.Team ~= 1) then
                            allyStarts['ARMY_' .. i] = startPos
                        else
                            numOpponents = numOpponents + 1
                        end
                    end
                end

                aiBrain.NumOpponents = numOpponents

                -- If the start location is not ours or an ally's, it is suspicious
                local starts = AIUtils.AIGetMarkerLocations(aiBrain, 'Start Location')
                for _, loc in starts do
                    -- If vacant
                    if not allyStarts[loc.Name] then
                        table.insert(aiBrain.InterestList.LowPriority,
                            {
                                Position = loc.Position,
                                LastScouted = 0,
                            }
                        )
                        table.insert(startLocations, startPos)
                    end
                end
                -- Set Start Locations for brain to reference
                aiBrain.EnemyIntel.EnemyStartLocations = startLocations
            end
            
            
            --LOG('* AI-RNG: EnemyStartLocations : '..repr(aiBrain.EnemyIntel.EnemyStartLocations))
            local massLocations = RUtils.AIGetMassMarkerLocations(aiBrain, true)
        
            for _, start in startLocations do
                markersStartPos = AIUtils.AIGetMarkersAroundLocation(aiBrain, 'Mass', start, 30)
                for _, marker in markersStartPos do
                    --LOG('* AI-RNG: Start Mass Marker ..'..repr(marker))
                    table.insert(startPosMarkers, marker)
                end
            end
            for k, massMarker in massLocations do
                for c, startMarker in startPosMarkers do
                    if massMarker.Position == startMarker.Position then
                        --LOG('* AI-RNG: Removing Mass Marker Position : '..repr(massMarker.Position))
                        table.remove(massLocations, k)
                    end
                end
            end
            for k, massMarker in massLocations do
                --LOG('* AI-RNG: Inserting Mass Marker Position : '..repr(massMarker.Position))
                table.insert(aiBrain.InterestList.LowPriority,
                        {
                            Position = massMarker.Position,
                            LastScouted = 0,
                        }
                    )
            end
            aiBrain:ForkThread(self.ParseIntelThreadRNG)
        end
    end,

    PickEnemyRNG = function(self)
        while true do
            self:PickEnemyLogicRNG()
            WaitTicks(1200)
        end
    end,

    PickEnemyLogicRNG = function(self)
        local armyStrengthTable = {}
        local selfIndex = self:GetArmyIndex()
        local enemyBrains = {}
        for _, v in ArmyBrains do
            local insertTable = {
                Enemy = true,
                Strength = 0,
                Position = false,
                EconomicThreat = 0,
                ACUPosition = {},
                ACULastSpotted = 0,
                Brain = v,
            }
            -- Share resources with friends but don't regard their strength
            if IsAlly(selfIndex, v:GetArmyIndex()) then
                self:SetResourceSharing(true)
                insertTable.Enemy = false
            elseif not IsEnemy(selfIndex, v:GetArmyIndex()) then
                insertTable.Enemy = false
            end
            if insertTable.Enemy == true then
                table.insert(enemyBrains, v)
            end
            local acuPos = {}
            -- Gather economy information of army to guage economy value of the target
            local enemyIndex = v:GetArmyIndex()
            local startX, startZ = v:GetArmyStartPos()
            local ecoThreat = 0

            if insertTable.Enemy == false then
                local ecoStructures = self:GetUnitsAroundPoint(categories.STRUCTURE * (categories.MASSEXTRACTION + categories.MASSPRODUCTION), {startX, 0 ,startZ}, 120, 'Ally')
                local GetBlueprint = moho.entity_methods.GetBlueprint
                for _, v in ecoStructures do
                    local bp = v:GetBlueprint()
                    local ecoStructThreat = bp.Defense.EconomyThreatLevel
                    --LOG('* AI-RNG: Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
            else
                ecoThreat = 1
            end
            -- Doesn't exist yet!!. Check if the ACU's last position is known.
            --LOG('* AI-RNG: Enemy Index is :'..enemyIndex)
            local acuPos, lastSpotted = RUtils.GetLastACUPosition(self, enemyIndex)
            --LOG('* AI-RNG: ACU Position is has data'..repr(acuPos))
            insertTable.ACUPosition = acuPos
            insertTable.ACULastSpotted = lastSpotted
            
            insertTable.EconomicThreat = ecoThreat
            if insertTable.Enemy then
                insertTable.Position, insertTable.Strength = self:GetHighestThreatPosition(16, true, 'Structures', v:GetArmyIndex())
                --LOG('* AI-RNG: First Enemy Pass Strength is :'..insertTable.Strength)
            else
                insertTable.Position = {startX, 0 ,startZ}
                insertTable.Strength = ecoThreat
                --LOG('* AI-RNG: First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
            end
            armyStrengthTable[v:GetArmyIndex()] = insertTable
        end

        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        
        if allyEnemy  then
            --LOG('* AI-RNG: Ally Enemy is true or ACU is close')
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
                    -- Dont' target self
                    if k == selfIndex then
                        continue
                    end

                    -- Ignore allies
                    if not v.Enemy then
                        continue
                    end

                    -- If we have a better candidate; ignore really weak enemies
                    if enemy and v.Strength < 20 then
                        continue
                    end

                    if v.Strength == 0 then
                        name = v.Brain.Nickname
                        --LOG('* AI-RNG: Name is'..name)
                        --LOG('* AI-RNG: v.strenth is 0')
                        if name ~= 'civilian' then
                            --LOG('* AI-RNG: Inserted Name is '..name)
                            table.insert(enemyTable, v.Brain)
                        end
                        continue
                    end

                    -- The closer targets are worth more because then we get their mass spots
                    local distanceWeight = 0.1
                    local distance = VDist3(self:GetStartVector3f(), v.Position)
                    local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                    --LOG('* AI-RNG: armyStrengthTable Strength is :'..v.Strength)
                    --LOG('* AI-RNG: Threat Weight is :'..threatWeight)
                    if not enemy or threatWeight > enemyStrength then
                        enemy = v.Brain
                        enemyStrength = threatWeight
                        --LOG('* AI-RNG: Enemy Strength is'..enemyStrength)
                    end
                end

                if enemy then
                    LOG('* AI-RNG: Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = table.getn(enemyTable)
                    --LOG('* AI-RNG: Table number is'..num)
                    local ran = math.random(num)
                    --LOG('* AI-RNG: Random Number is'..ran)
                    enemy = enemyTable[ran]
                    LOG('* AI-RNG: Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
            end
        end
    end,

    ParseIntelThreadRNG = function(self)
        if not self.InterestList or not self.InterestList.MustScout then
            error('Scouting areas must be initialized before calling AIBrain:ParseIntelThread.', 2)
        end
        for _, v in ArmyBrains do
            self.EnemyIntel.ACU[v:GetArmyIndex()] = {
                Position = {},
                LastSpotted = 0,
                Threat = 0,
            }
        end
        while true do
            local structures = self:GetThreatsAroundPosition(self.BuilderManagers.MAIN.Position, 16, true, 'StructuresNotMex')
            for _, struct in structures do
                local dupe = false
                local newPos = {struct[1], 0, struct[2]}

                for _, loc in self.InterestList.HighPriority do
                    if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                        dupe = true
                        break
                    end
                end

                if not dupe then
                    -- Is it in the low priority list?
                    for i = 1, table.getn(self.InterestList.LowPriority) do
                        local loc = self.InterestList.LowPriority[i]
                        if VDist2Sq(newPos[1], newPos[3], loc.Position[1], loc.Position[3]) < 10000 then
                            -- Found it in the low pri list. Remove it so we can add it to the high priority list.
                            table.remove(self.InterestList.LowPriority, i)
                            break
                        end
                    end

                    table.insert(self.InterestList.HighPriority,
                        {
                            Position = newPos,
                            LastScouted = GetGameTimeSeconds(),
                        }
                    )
                    -- Sort the list based on low long it has been since it was scouted
                    table.sort(self.InterestList.HighPriority, function(a, b)
                        if a.LastScouted == b.LastScouted then
                            local MainPos = self.BuilderManagers.MAIN.Position
                            local distA = VDist2(MainPos[1], MainPos[3], a.Position[1], a.Position[3])
                            local distB = VDist2(MainPos[1], MainPos[3], b.Position[1], b.Position[3])

                            return distA < distB
                        else
                            return a.LastScouted < b.LastScouted
                        end
                    end)
                end
            end
            WaitTicks(70)
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local startX, startZ = self:GetArmyStartPos()
        local ACUDist = nil
        
        --LOG('* AI-RNG: My Own Strength is'..highStrength)
        for _, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                --LOG('* AI-RNG: ACU Position is :'..repr(v.ACUPosition))
                if v.ACUPosition[1] then
                    ACUDist = VDist2(startX, startZ, v.ACUPosition[1], v.ACUPosition[3])
                    --LOG('* AI-RNG: Enemy ACU Distance in Alliance Check is'..ACUDist)
                    if ACUDist < 180 then
                        LOG('* AI-RNG: Enemy ACU is close switching Enemies to :'..v.Brain.Nickname)
                        returnEnemy = v.Brain
                        return returnEnemy
                    elseif v.Threat < 200 and ACUDist < 240 then
                        LOG('* AI-RNG: Enemy ACU has low threat switching Enemies to :'..v.Brain.Nickname)
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
            LOG('* AI-RNG: Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            LOG('* AI-RNG: returnEnemy is false')
        end
        return returnEnemy
    end,

    GetBaseMonitorSpec = function(self)

    end,

    GetUpgradeSpec = function(self, unit)
        local upgradeSpec = {}
        if EntityCategoryContains(categories.MASSEXTRACTION, unit) then
            if self.UpgradeMode == 'Aggressive' then
                upgradeSpec.MassLowTrigger = 0.60
                upgradeSpec.EnergyLowTrigger = 1.0
                upgradeSpec.MassHighTrigger = 1.8
                upgradeSpec.EnergyHighTrigger = 9999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 90
                upgradeSpec.EnemyThreatLimit = 100
                return upgradeSpec
            elseif self.UpgradeMode == 'Normal' then
                upgradeSpec.MassLowTrigger = 0.68
                upgradeSpec.EnergyLowTrigger = 0.8
                upgradeSpec.MassHighTrigger = 2.0
                upgradeSpec.EnergyHighTrigger = 9999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 90
                upgradeSpec.EnemyThreatLimit = 5
                return upgradeSpec
            elseif self.UpgradeMode == 'Caution' then
                upgradeSpec.MassLowTrigger = 1.0
                upgradeSpec.EnergyLowTrigger = 1.2
                upgradeSpec.MassHighTrigger = 2.2
                upgradeSpec.EnergyHighTrigger = 9999
                upgradeSpec.UpgradeCheckWait = 18
                upgradeSpec.InitialDelay = 90
                upgradeSpec.EnemyThreatLimit = 0
                return upgradeSpec
            end
        else
            --LOG('* AI-RNG: Unit is not Mass Extractor')
            upgradeSpec = false
            return upgradeSpec
        end
    end,

    BaseMonitorPlatoonDistressRNG = function(self, platoon, threat)
        if not self.BaseMonitor then
            return
        end

        local found = false
        if self.BaseMonitor.PlatoonAlertSounded == false then
            table.insert(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
        else
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                -- If already calling for help, don't add another distress call
                if v.Platoon == platoon then
                    continue
                end
                -- Add platoon to list desiring aid
                table.insert(self.BaseMonitor.PlatoonDistressTable, {Platoon = platoon, Threat = threat})
            end
        end
        --LOG('* AI-RNG: New Entry Added to platoon distress'..repr(self.BaseMonitor.PlatoonDistressTable))
        -- Create the distress call if it doesn't exist
        if not self.BaseMonitor.PlatoonDistressThread then
            self.BaseMonitor.PlatoonDistressThread = self:ForkThread(self.BaseMonitorPlatoonDistressThreadRNG)
        end
    end,

    BaseMonitorPlatoonDistressThreadRNG = function(self)
        self.BaseMonitor.PlatoonAlertSounded = true
        while true do
            local numPlatoons = 0
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local threat = self:GetThreatAtPosition(v.Platoon:GetPlatoonPosition(), 0, true, 'AntiSurface')
                    local myThreat = self:GetThreatAtPosition(v.Platoon:GetPlatoonPosition(), 0, true, 'Overall', self:GetArmyIndex())
                    --LOG('* AI-RNG: Threat of attacker'..threat)
                    --LOG('* AI-RNG: Threat of platoon'..myThreat)
                    -- Platoons still threatened
                if threat and threat > (myThreat * 1.5) then
                    --LOG('* AI-RNG: Created Threat Alert')
                        v.Threat = threat
                        numPlatoons = numPlatoons + 1
                    -- Platoon not threatened
                    else
                        self.BaseMonitor.PlatoonDistressTable[k] = nil
                        v.Platoon.DistressCall = false
                    end
                else
                    self.BaseMonitor.PlatoonDistressTable[k] = nil
                end
            end

            -- If any platoons still want help; continue sounding
            if numPlatoons > 0 then
                self.BaseMonitor.PlatoonAlertSounded = true
            else
                self.BaseMonitor.PlatoonAlertSounded = false
            end
            WaitSeconds(self.BaseMonitor.BaseMonitorTime)
        end
    end,

    BaseMonitorDistressLocationRNG = function(self, position, radius, threshold)
        local returnPos = false
        local highThreat = false
        local distance
        if self.BaseMonitor.CDRDistress
                and Utilities.XZDistanceTwoVectors(self.BaseMonitor.CDRDistress, position) < radius
                and self.BaseMonitor.CDRThreatLevel > threshold then
            -- Commander scared and nearby; help it
            return self.BaseMonitor.CDRDistress
        end
        if self.BaseMonitor.AlertSounded then
            for k, v in self.BaseMonitor.AlertsTable do
                local tempDist = Utilities.XZDistanceTwoVectors(position, v.Position)

                -- Too far away
                if tempDist > radius then
                    continue
                end

                -- Not enough threat in location
                if v.Threat < threshold then
                    continue
                end

                -- Threat lower than or equal to a threat we already have
                if v.Threat <= highThreat then
                    continue
                end

                -- Get real height
                local height = GetTerrainHeight(v.Position[1], v.Position[3])
                local surfHeight = GetSurfaceHeight(v.Position[1], v.Position[3])
                if surfHeight > height then
                    height = surfHeight
                end

                -- currently our winner in high threat
                returnPos = {v.Position[1], height, v.Position[3]}
                distance = tempDist
            end
        end
        if self.BaseMonitor.PlatoonAlertSounded then
            for k, v in self.BaseMonitor.PlatoonDistressTable do
                if self:PlatoonExists(v.Platoon) then
                    local platPos = v.Platoon:GetPlatoonPosition()
                    local tempDist = Utilities.XZDistanceTwoVectors(position, platPos)

                    -- Platoon too far away to help
                    if tempDist > radius then
                        continue
                    end

                    -- Area not scary enough
                    if v.Threat < threshold then
                        continue
                    end

                    -- Further away than another call for help
                    if tempDist > distance then
                        continue
                    end

                    -- Our current winners
                    returnPos = platPos
                    distance = tempDist
                end
            end
        end
        return returnPos
    end,

    TacticalMonitorInitializationRNG = function(self, spec)
        --LOG('* AI-RNG: Tactical Monitor Is Initializing')
        local ALLBPS = __blueprints
        self:ForkThread(self.TacticalMonitorThreadRNG, ALLBPS)
    end,

    TacticalMonitorThreadRNG = function(self, ALLBPS)
        LOG('Monitor Tick Count :'..self.TacticalMonitor.TacticalMonitorTime)
        while true do
            if self.TacticalMonitor.TacticalMonitorStatus == 'ACTIVE' then
                --LOG('* AI-RNG: Tactical Monitor Is Active')
                self:TacticalMonitorRNG(ALLBPS)
            end
            WaitTicks(self.TacticalMonitor.TacticalMonitorTime)
        end
    end,

    TacticalMonitorRNG = function(self, ALLBPS)
        -- Tactical Monitor function. Keeps an eye on the battlefield and takes points of interest to investigate.
        WaitTicks(Random(1,7))
        LOG('* AI-RNG: Tactical Monitor Threat Pass')
        local enemyBrains = {}
        local enemyStarts = self.EnemyIntel.EnemyStartLocations
        local timeout = self.TacticalMonitor.TacticalTimeout
        local gameTime = GetGameTimeSeconds()
        --LOG('Current Threat Location Table'..repr(self.EnemyIntel.EnemyThreatLocations))
        if table.getn(self.EnemyIntel.EnemyThreatLocations) > 0 then
            for k, v in self.EnemyIntel.EnemyThreatLocations do
                --LOG('Game time : Insert Time : Timeout'..gameTime..':'..v.InsertTime..':'..timeout)
                if (gameTime - v.InsertTime) > timeout then
                    self.EnemyIntel.EnemyThreatLocations[k] = nil
                end
            end
            if self.EnemyIntel.EnemyThreatLocations then
                self.EnemyIntel.EnemyThreatLocations = self:RebuildTable(self.EnemyIntel.EnemyThreatLocations)
            end
        end
        -- Rebuild the self threat tables
        --LOG('SelfThreat Table count:'..table.getn(self.BrainIntel.SelfThreat))
        --LOG('SelfThreat Table present:'..repr(self.BrainIntel.SelfThreat))
        if self.BrainIntel.SelfThreat then
            for k, v in self.BrainIntel.SelfThreat.Air do
                --LOG('Game time : Insert Time : Timeout'..gameTime..':'..v.InsertTime..':'..timeout)
                if (gameTime - v.InsertTime) > timeout then
                    self.BrainIntel.SelfThreat.Air[k] = nil
                end
            end
            if self.BrainIntel.SelfThreat.Air then
                self.BrainIntel.SelfThreat.Air = self:RebuildTable(self.BrainIntel.SelfThreat.Air)
            end
        end
        -- debug, remove later on
        if enemyStarts then
            --LOG('* AI-RNG: Enemy Start Locations :'..repr(enemyStarts))
        end
        local selfIndex = self:GetArmyIndex()
        local potentialThreats = {}
        local threatTypes = {
            'Land',
            'Air',
            'Naval',
            --'AntiSurface'
        }
        -- Get threats for each threat type listed on the threatTypes table. Full map scan.
        for _, t in threatTypes do
            rawThreats = self:GetThreatsAroundPosition(self.BuilderManagers.MAIN.Position, 16, true, t)
            for _, raw in rawThreats do
                local threatRow = {posX=raw[1], posZ=raw[2], rThreat=raw[3], rThreatType=t}
                table.insert(potentialThreats, threatRow)
            end
        end
        --LOG('Potential Threats :'..repr(potentialThreats))
        local phaseTwoThreats = {}
        local threatLimit = 20
        -- Set a raw threat table that is replaced on each loop so we can get a snapshot of current enemy strength across the map.
        self.EnemyIntel.EnemyThreatRaw = potentialThreats

        -- Remove threats that are too close to the enemy base so we are focused on whats happening in the battlefield.
        -- Also set if the threat is on water or not
        -- Set the time the threat was identified so we can flush out old entries
        -- If you want the full map thats what EnemyThreatRaw is for.
        if table.getn(potentialThreats) > 0 then
            local threatLocation = {}
            for _, threat in potentialThreats do
                --LOG('* AI-RNG: Threat is'..repr(threat))
                if threat.rThreat > threatLimit then
                    for _, pos in enemyStarts do
                        --LOG('* AI-RNG: Distance Between Threat and Start Position :'..VDist2Sq(threat.posX, threat.posZ, pos[1], pos[3]))
                        if VDist2Sq(threat.posX, threat.posZ, pos[1], pos[3]) < 10000 then
                            --LOG('* AI-RNG: Tactical Potential Interest Location Found at :'..repr(threat))
                            if RUtils.PositionOnWater(self, threat.posX, threat.posZ) then
                                onWater = true
                            else
                                onWater = false
                            end
                            threatLocation = {Position = {threat.posX, threat.posZ}, EnemyBaseRadius = true, Threat=threat.rThreat, ThreatType=threat.rThreatType, PositionOnWater=onWater}
                            table.insert(phaseTwoThreats, threatLocation)
                        else
                            --LOG('* AI-RNG: Tactical Potential Interest Location Found at :'..repr(threat))
                            if RUtils.PositionOnWater(self, threat.posX, threat.posZ) then
                                onWater = true
                            else
                                onWater = false
                            end
                            threatLocation = {Position = {threat.posX, threat.posZ}, EnemyBaseRadius = false, Threat=threat.rThreat, ThreatType=threat.rThreatType, PositionOnWater=onWater}
                            table.insert(phaseTwoThreats, threatLocation)
                        end
                    end
                end
            end
            --LOG('* AI-RNG: Pre Sorted Potential Valid Threat Locations :'..repr(phaseTwoThreats))
            for Index_1, value_1 in phaseTwoThreats do
                for Index_2, value_2 in phaseTwoThreats do
                    -- no need to check against self
                    if Index_1 == Index_2 then 
                        continue
                    end
                    -- check if we have the same position
                    --LOG('* AI-RNG: checking '..repr(value_1.Position)..' == '..repr(value_2.Position))
                    if value_1.Position[1] == value_2.Position[1] and value_1.Position[2] == value_2.Position[2] then
                        --LOG('* AI-RNG: eual position '..repr(value_1.Position)..' == '..repr(value_2.Position))
                        if value_1.EnemyBaseRadius == false then
                            --LOG('* AI-RNG: deleating '..repr(value_1))
                            phaseTwoThreats[Index_1] = nil
                            break
                        elseif value_2.EnemyBaseRadius == false then
                            --LOG('* AI-RNG: deleating '..repr(value_2))
                            phaseTwoThreats[Index_2] = nil
                            break
                        else
                            --LOG('* AI-RNG: Both entires have true, deleting nothing')
                        end
                    end
                end
            end
            --LOG('* AI-RNG: second table pass :'..repr(potentialThreats))
            for _, threat in phaseTwoThreats do
                if threat.EnemyBaseRadius == false then
                    threat.InsertTime = GetGameTimeSeconds()
                    table.insert(self.EnemyIntel.EnemyThreatLocations, threat)
                else
                    --LOG('* AI-RNG: Removing Threat within Enemy Base Radius')
                end
            end
            LOG('* AI-RNG: Final Valid Threat Locations :'..repr(self.EnemyIntel.EnemyThreatLocations))
        end

        -- Get AI strength
        local brainUnits = GetListOfUnits( self, categories.MOBILE, false, false)
        local airthreat = 0
        local bp

		
		-- calculate my present airvalue			
		for _,v in EntityCategoryFilterDown( (categories.AIR * categories.MOBILE) - categories.TRANSPORTFOCUS - categories.SATELLITE, brainUnits ) do
            -- previous method of getting unit ID before the property was added.
            --local unitbpId = v:GetUnitId()
            --LOG('Unit blueprint id test only on dev branch:'..v.UnitId)
			bp = ALLBPS[v.UnitId].Defense

			airthreat = airthreat + bp.AirThreatLevel + bp.SubThreatLevel + bp.SurfaceThreatLevel
        end
        if airthreat > 0 then
            local airSelfThreat = {Threat = airthreat, InsertTime = GetGameTimeSeconds()}
            table.insert(self.BrainIntel.SelfThreat.Air, airSelfThreat)
            LOG('Total Air Unit Threat :'..airthreat)
            --LOG('Current Self Air Threat Table :'..repr(self.BrainIntel.SelfThreat.Air))
            local averageSelfThreat = 0
            for k, v in self.BrainIntel.SelfThreat.Air do
                averageSelfThreat = averageSelfThreat + v.Threat
            end
            self.BrainIntel.Average.Air = averageSelfThreat / table.getn(self.BrainIntel.SelfThreat.Air)
            LOG('Current Self Average Air Threat Table :'..repr(self.BrainIntel.Average.Air))
        end

        if table.getn(self.EnemyIntel.EnemyThreatRaw) > 0 then
            local totalAirThreat = 0
            for k, v in self.EnemyIntel.EnemyThreatRaw do
                if v.rThreatType == 'Air' then
                    totalAirThreat = totalAirThreat + v.rThreat
                end
            end
            self.EnemyIntel.EnemyThreatCurrent.Air = totalAirThreat
            LOG('Current Enemy Air Threat :'..self.EnemyIntel.EnemyThreatCurrent.Air)
        end
    end,

    EcoManagerThreadRNG = function(self)
        while true do
            if self.EcoManager.EcoManagerStatus == 'ACTIVE' then
                --LOG('* AI-RNG: Tactical Monitor Is Active')
                self:EcoExtractorManagerRNG()
                self:EcoPowerManagerRNG()
            end
            WaitTicks(self.EcoManager.EcoManagerTime)
        end
    end,

    EcoExtractorManagerRNG = function(self)
    -- A straight shooter with upper management written all over him
        WaitTicks(Random(1,7))
        local upgradingExtractors = RUtils.ExtractorsBeingUpgraded(self)
        self.EcoManager.ExtractorsUpgrading.TECH1 = upgradingExtractors.TECH1
        self.EcoManager.ExtractorsUpgrading.TECH2 = upgradingExtractors.TECH2
        --LOG('Extractors Upgrading :'..repr(self.EcoManager.ExtractorsUpgrading))

    end,

    EcoPowerManagerRNG = function(self)
    -- Watches for low power states
        if GetGameTimeSeconds() < 300 then
            return
        end
        local powerStateCaution = self:EcoManagerPowerStateCheck()
        local unitTypePaused = false
        
        if powerStateCaution then
            LOG('Power State Caution is true')
            local powerCycle = 0
            local unitTypePaused = {}
            while powerStateCaution do
                local priorityNum = 0
                local priorityUnit = false
                powerCycle = powerCycle + 1
                for k, v in self.EcoManager.PriorityTable do
                    local priorityUnitAlreadySet = false
                    for l, b in unitTypePaused do
                        if k == b then
                            priorityUnitAlreadySet = true
                        end
                    end
                    if priorityUnitAlreadySet then
                        --LOG('priorityUnit already in unitTypePaused, skipping')
                        continue
                    end
                    if v > priorityNum then
                        priorityNum = v
                        priorityUnit = k
                    end
                end
                LOG('Doing anti power stall stuff for :'..priorityUnit)
                if priorityUnit == 'ENGINEER' then
                    local unitAlreadySet = false
                    for k, v in unitTypePaused do
                        if priorityUnit == v then
                            unitAlreadySet = true
                        end
                    end
                    if not unitAlreadySet then
                        table.insert(unitTypePaused, priorityUnit)
                    end
                    --LOG('Engineer added to unitTypePaused')
                    local Engineers = self:GetListOfUnits(categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                    self:EcoSelectorManagerRNG(priorityUnit, Engineers, 'pause')
                elseif priorityUnit == 'AIR' then
                    local unitAlreadySet = false
                    for k, v in unitTypePaused do
                        if priorityUnit == v then
                            unitAlreadySet = true
                        end
                    end
                    if not unitAlreadySet then
                        table.insert(unitTypePaused, priorityUnit)
                    end
                    local AirFactories = self:GetListOfUnits(categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                    self:EcoSelectorManagerRNG(priorityUnit, AirFactories, 'pause')
                elseif priorityUnit == 'SHIELD' then
                    local unitAlreadySet = false
                    for k, v in unitTypePaused do
                        if priorityUnit == v then
                            unitAlreadySet = true
                        end
                    end
                    if not unitAlreadySet then
                        table.insert(unitTypePaused, priorityUnit)
                    end
                    local Shields = self:GetListOfUnits(categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                    self:EcoSelectorManagerRNG(priorityUnit, Shields, 'pause')
                elseif priorityUnit == 'MASSFABRICATION' then
                    local unitAlreadySet = false
                    for k, v in unitTypePaused do
                        if priorityUnit == v then
                            unitAlreadySet = true
                        end
                    end
                    if not unitAlreadySet then
                        table.insert(unitTypePaused, priorityUnit)
                    end
                    local MassFabricators = self:GetListOfUnits(categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                    self:EcoSelectorManagerRNG(priorityUnit, MassFabricators, 'pause')
                elseif priorityUnit == 'NUKE' then
                    local unitAlreadySet = false
                    for k, v in unitTypePaused do
                        if priorityUnit == v then
                            unitAlreadySet = true
                        end
                    end
                    if not unitAlreadySet then
                        table.insert(unitTypePaused, priorityUnit)
                    end
                    local Nukes = self:GetListOfUnits(categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                    self:EcoSelectorManagerRNG(priorityUnit, Nukes, 'pause')
                end
                WaitTicks(20)
                powerStateCaution = self:EcoManagerPowerStateCheck()
                if powerStateCaution then
                    LOG('Power State Caution still true after first pass')
                    if powerCycle > 5 then
                        LOG('Power Cycle Threashold met, waiting longer')
                        WaitTicks(100)
                        powerCycle = 0
                    end
                else
                    LOG('Power State Caution is now false')
                end
                --LOG('unitTypePaused table is :'..repr(unitTypePaused))
            end
            for k, v in unitTypePaused do
                if v == 'ENGINEER' then
                    local Engineers = self:GetListOfUnits(categories.ENGINEER - categories.STATIONASSISTPOD - categories.COMMAND - categories.SUBCOMMANDER, false, false)
                    self:EcoSelectorManagerRNG(v, Engineers, 'unpause')
                elseif v == 'AIR' then
                    local AirFactories = self:GetListOfUnits(categories.STRUCTURE * categories.FACTORY * categories.AIR, false, false)
                    self:EcoSelectorManagerRNG(v, AirFactories, 'unpause')
                elseif v == 'SHIELD' then
                    local Shields = self:GetListOfUnits(categories.STRUCTURE * categories.SHIELD - categories.EXPERIMENTAL, false, false)
                    self:EcoSelectorManagerRNG(v, Shields, 'unpause')
                elseif v == 'MASSFABRICATION' then
                    local MassFabricators = self:GetListOfUnits(categories.STRUCTURE * categories.MASSFABRICATION, false, false)
                    self:EcoSelectorManagerRNG(v, MassFabricators, 'unpause')
                elseif v == 'NUKE' then
                    local Nukes = self:GetListOfUnits(categories.STRUCTURE * categories.NUKE * (categories.TECH3 + categories.EXPERIMENTAL), false, false)
                    self:EcoSelectorManagerRNG(v, Nukes, 'unpause')
                end
            end
            powerStateCaution = false
        end
    end,

    EcoManagerPowerStateCheck = function(self)

        local energyIncome = self:GetEconomyIncome('ENERGY')
        local energyRequest = self:GetEconomyRequested('ENERGY')
        local energyStorage = self:GetEconomyStored('ENERGY')
        local stallTime = energyStorage / ((energyRequest * 10) - (energyIncome * 10))
        LOG('Energy Income :'..(energyIncome * 10)..' Energy Requested :'..(energyRequest * 10)..' Energy Storage :'..energyStorage)
        LOG('Time to stall for '..stallTime)
        if stallTime >= 0.0 then
            if stallTime < 20 then
                return true
            elseif stallTime > 20 then
                return false
            end
        end
        return false
    end,
    
    EcoSelectorManagerRNG = function(self, priorityUnit, units, action)

        for k, v in units do
            if v.Dead then continue end
            if priorityUnit == 'ENGINEER' then
                --LOG('Priority Unit Is Engineer')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Engineer')
                    v:SetPaused(false)
                    continue
                end
                if not v.PlatoonHandle.PlatoonData.Assist.AssisteeType then continue end
                if not v.UnitBeingAssist then continue end
                if v:IsPaused() then continue end
                if not EntityCategoryContains(categories.STRUCTURE * categories.ENERGYPRODUCTION, v.UnitBeingAssist) then
                    --LOG('Pausing Engineer')
                    v:SetPaused(true)
                end
            elseif priorityUnit == 'AIR' then
                --LOG('Priority Unit Is AIR')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Air Factory')
                    v:SetPaused(false)
                    continue
                end
                if not v.UnitBeingBuilt then continue end
                if EntityCategoryContains(categories.ENGINEER * categories.TECH1, v.UnitBeingBuilt) then continue end
                if table.getn(units) == 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing AIR')
                v:SetPaused(true)
            elseif priorityUnit == 'MASSFABRICATION' or priorityUnit == 'SHIELD' then
                --LOG('Priority Unit Is MASSFABRICATION or SHIELD')
                if action == 'unpause' then
                    if v.MaintenanceConsumption then continue end
                    --LOG('Unpausing MASSFABRICATION or SHIELD')
                    v:OnProductionUnpaused()
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if not v.MaintenanceConsumption then continue end
                --LOG('pausing MASSFABRICATION or SHIELD')
                v:OnProductionPaused()
            elseif priorityUnit == 'NUKE' then
                --LOG('Priority Unit Is Nuke')
                if action == 'unpause' then
                    if not v:IsPaused() then continue end
                    --LOG('Unpausing Nuke')
                    v:SetPaused(false)
                    continue
                end
                if v.Dead then continue end
                if v:GetFractionComplete() ~= 1 then continue end
                if v:IsPaused() then continue end
                --LOG('pausing Nuke')
                v:SetPaused(true)
            end
        end
    end,

    
}
