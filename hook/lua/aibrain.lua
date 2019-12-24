
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')
local AIUtils = import('/lua/ai/AIUtilities.lua')

local RNGAIBrainClass = AIBrain
AIBrain = Class(RNGAIBrainClass) {

    OnCreateAI = function(self, planName)
        RNGAIBrainClass.OnCreateAI(self, planName)
        local per = ScenarioInfo.ArmySetup[self.Name].AIPersonality
        LOG('Oncreate')
        if string.find(per, 'RNG') then
            LOG('This is RNG')
            self.RNG = true
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

            if ScenarioInfo.Options.TeamSpawn == 'fixed' then
                -- Spawn locations were fixed. We know exactly where our opponents are.
                -- Don't scout areas owned by us or our allies.
                local numOpponents = 0
                for i = 1, 16 do
                    local army = ScenarioInfo.ArmySetup['ARMY_' .. i]
                    local startPos = ScenarioUtils.GetMarker('ARMY_' .. i).position
                    if army and startPos then
                        table.insert(startLocations, startPos)
                        if army.ArmyIndex ~= myArmy.ArmyIndex and (army.Team ~= myArmy.Team or army.Team == 1) then
                        -- Add the army start location to the list of interesting spots.
                        opponentStarts['ARMY_' .. i] = startPos
                        numOpponents = numOpponents + 1
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
            end
            local massLocations = RUtils.AIGetMassMarkerLocations(aiBrain, true)
        
            for _, start in startLocations do
                markersStartPos = AIUtils.AIGetMarkersAroundLocation(aiBrain, 'Mass', start, 30)
                for _, marker in markersStartPos do
                    --LOG('Start Mass Marker ..'..repr(marker))
                    table.insert(startPosMarkers, marker)
                end
            end
            for k, massMarker in massLocations do
                for c, startMarker in startPosMarkers do
                    if massMarker.Position == startMarker.Position then
                        --LOG('Removing Mass Marker Position : '..repr(massMarker.Position))
                        table.remove(massLocations, k)
                    end
                end
            end
            for k, massMarker in massLocations do
                --LOG('Inserting Mass Marker Position : '..repr(massMarker.Position))
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

    PickEnemy = function(self)
        LOG('Pick enemy')
        RNGAIBrainClass.OnCreateAI(self)
        --RNGAIBrainClass.PickEnemy(self)
        LOG('Pre True'..repr(self.RNG))
        while true do
            LOG('self.rng is'..repr(self.RNG))
            if self.RNG then
                LOG('Selecting RNG')
                self:PickEnemyLogicRNG()
            else
                self:PickEnemyLogic()
            end
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
                    LOG('Eco Structure'..ecoStructThreat)
                    ecoThreat = ecoThreat + ecoStructThreat
                end
            else
                ecoThreat = 1
            end
            -- Doesn't exist yet!!. Check if the ACU's last position is known.
            if RUtils.GetLastACUPosition(self, enemyIndex) then
                acuPos, lastSpotted = RUtils.GetLastACUPosition(enemyIndex)
                LOG('ACU Position is has data'..repr(acuPos))
                LOG('Last Spotted'..lastSpotted)
                LOG(repr(aiBrain.EnemyIntel.ACU))
            else
                LOG('GetLastACUPosition is false')
            end
            
            insertTable.EconomicThreat = ecoThreat
            if insertTable.Enemy then
                insertTable.Position, insertTable.Strength = self:GetHighestThreatPosition(16, true, 'Structures', v:GetArmyIndex())
                LOG('First Enemy Pass Strength is :'..insertTable.Strength)
            else
                insertTable.Position = {startX, 0 ,startZ}
                insertTable.Strength = ecoThreat
                LOG('First Ally Pass Strength is : '..insertTable.Strength..' Ally Position :'..repr(insertTable.Position))
            end
            armyStrengthTable[v:GetArmyIndex()] = insertTable
        end

        local allyEnemy = self:GetAllianceEnemyRNG(armyStrengthTable)
        if allyEnemy  then
            LOG('Ally Enemy is true')
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
                        LOG('Name is'..name)
                        LOG('v.strenth is 0')
                        if name ~= 'civilian' then
                            LOG('Inserted Name is '..name)
                            table.insert(enemyTable, v.Brain)
                        end
                        continue
                    end

                    -- The closer targets are worth more because then we get their mass spots
                    local distanceWeight = 0.1
                    local distance = VDist3(self:GetStartVector3f(), v.Position)
                    local threatWeight = (1 / (distance * distanceWeight)) * v.Strength
                    LOG('armyStrengthTable Strength is :'..v.Strength)
                    LOG('Threat Weight is :'..threatWeight)
                    if not enemy or threatWeight > enemyStrength then
                        enemy = v.Brain
                        enemyStrength = threatWeight
                        LOG('Enemy Strength is'..enemyStrength)
                    end
                end

                if enemy then
                    LOG('Enemy is :'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                else
                    local num = table.getn(enemyTable)
                    LOG('Table number is'..num)
                    local ran = math.random(num)
                    LOG('Random Number is'..ran)
                    enemy = enemyTable[ran]
                    LOG('Random Enemy is'..enemy.Name)
                    self:SetCurrentEnemy(enemy)
                end
            end
        end
    end,

    ParseIntelThreadRNG = function(self)
        if not self.InterestList or not self.InterestList.MustScout then
            error('Scouting areas must be initialized before calling AIBrain:ParseIntelThread.', 2)
        end
        self.EnemyIntel = {}
        self.EnemyIntel.ACU = {}
        for _, v in ArmyBrains do
            self.EnemyIntel.ACU[v:GetArmyIndex()] = {
                Position = {},
                LastSpotted = 0,
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

            WaitTicks(50)
        end
    end,

    GetAllianceEnemyRNG = function(self, strengthTable)
        local returnEnemy = false
        local myIndex = self:GetArmyIndex()
        local highStrength = strengthTable[myIndex].Strength
        local startX, startZ = self:GetArmyStartPos()
        
        LOG('My Own Strength is'..highStrength)
        for _, v in strengthTable do
            -- It's an enemy, ignore
            if v.Enemy then
                continue
            end

            -- Ally too weak
            if v.Strength < highStrength then
                continue
            end

            -- If the brain has an enemy, it's our new enemy
            local enemy = v.Brain:GetCurrentEnemy()
            if enemy and not enemy:IsDefeated() then
                highStrength = v.Strength
                returnEnemy = v.Brain:GetCurrentEnemy()
            end
        end
        if returnEnemy then
            LOG('Ally Enemy Returned is : '..returnEnemy.Nickname)
        else
            LOG('returnEnemy is false')
        end
        return returnEnemy
    end,
}
