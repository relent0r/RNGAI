local AIPlatoon = import("/lua/aibrains/platoons/platoon-base.lua").AIPlatoon
local NavUtils = import("/lua/sim/navutils.lua")
local MarkerUtils = import("/lua/sim/markerutilities.lua")
local TransportUtils = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua")
local AIAttackUtils = import('/lua/AI/aiattackutilities.lua')
local AIUtils = import("/lua/ai/aiutilities.lua")
local RNGAIGLOBALS = import("/mods/RNGAI/lua/AI/RNGAIGlobals.lua")
local StateUtils = import('/mods/RNGAI/lua/AI/StateMachineUtilities.lua')
local ALLBPS = __blueprints

local IsDestroyed = IsDestroyed

local RNGGETN = table.getn
local TableEmpty = table.empty
local TableInsert = table.insert
local GetNumUnitsAroundPoint = moho.aibrain_methods.GetNumUnitsAroundPoint
local GetUnitsAroundPoint = moho.aibrain_methods.GetUnitsAroundPoint
local RUtils = import('/mods/RNGAI/lua/AI/RNGUtilities.lua')

-- I'm up to navigating. Specifically the reclaim check.

---@class AIPlatoonAdaptiveReclaimBehavior : AIPlatoon
---@field ThreatToEvade Vector | nil
---@field LocationToReclaim Vector | nil
AIPlatoonAdaptiveReclaimBehavior = Class(AIPlatoon) {

    PlatoonName = 'AdaptiveReclaimBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the EngineerReclaimBehavior StateMachine'))
            local aiBrain = self:GetBrain()
            self.LocationType = self.PlatoonData.LocationType or 'FLOATING'

            local playableArea = import('/mods/RNGAI/lua/FlowAI/framework/mapping/Mapping.lua').GetPlayableAreaRNG()
        
            if not playableArea then
                self.MapSizeX = ScenarioInfo.size[1]
                self.MapSizeZ = ScenarioInfo.size[2]
            else
                self.MapSizeX = playableArea[3]
                self.MapSizeZ = playableArea[4]
            end
            self.InitialRange = 40
            self.BadReclaimables = self.BadReclaimables or {}
            local platoonUnits = self:GetPlatoonUnits()
            self.MergeType = 'EngineerStateMachine'
            for _, eng in platoonUnits do
                if not eng.BuilderManagerData then
                   eng.BuilderManagerData = {}
                end
                if not eng.BuilderManagerData.EngineerManager and aiBrain.BuilderManagers['FLOATING'].EngineerManager then
                   eng.BuilderManagerData.EngineerManager = aiBrain.BuilderManagers['FLOATING'].EngineerManager
                end
                if eng:IsUnitState('Attached') then
                    if aiBrain:GetNumUnitsAroundPoint(categories.TRANSPORTFOCUS, eng:GetPosition(), 10, 'Ally') > 0 then
                        eng:DetachFrom()
                        coroutine.yield(20)
                    end
                end
                self.eng = eng
                break
            end
            local factionIndex = aiBrain:GetFactionIndex()
            local buildingTmplFile = import('/lua/BuildingTemplates.lua')
            local buildingTmpl = buildingTmplFile[('BuildingTemplates')][factionIndex]
            local whatToBuild = aiBrain:DecideWhatToBuild(self.eng, 'T1Resource', buildingTmpl)
            self.ExtractorBuildID = whatToBuild
            self.GenericReclaimLoop = 0
            self.ReclaimTableLoop = 0

            -- requires navigational mesh
            if not NavUtils.IsGenerated() then
                self:LogWarning('requires generated navigational mesh')
                self:ChangeState(self.Error)
                return
            end

            -- Set the movement layer for pathing, included for mods where water or air based engineers may exist
            self.MovementLayer = self:GetNavigationalLayer()
            self:LogDebug(string.format('Starting reclaim logic'))
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    DecideWhatToDo = State {

        StateName = 'DecideWhatToDo',

        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            --self:LogDebug(string.format('Nuke DecideWhatToDo'))
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local engPos = eng:GetPosition()
            if self.PlatoonData.CheckCivUnits then
                self:LogDebug(string.format('We are checking for civilian unit capture'))
                local captureUnit = RUtils.CheckForCivilianUnitCapture(aiBrain, eng, self.MovementLayer)
                if captureUnit then
                    if not eng.CaptureDoneCallbackSet then
                        --self:LogDebug(string.format('No Capture Callback set on engineer, setting '))
                        import('/lua/ScenarioTriggers.lua').CreateUnitStopCaptureTrigger(StateUtils.CaptureDoneRNG, eng)
                        eng.CaptureDoneCallbackSet = true
                    end
                    if not IsDestroyed(captureUnit) and RUtils.GrabPosDangerRNG(aiBrain,captureUnit:GetPosition(), 40, 40, true).enemySurface < 5 then
                        local captureUnitPos = captureUnit:GetPosition()
                        self.BuilderData = {
                            CaptureUnit = captureUnit,
                            Position = captureUnitPos
                        }
                        --self:LogDebug(string.format('Capture Unit Data set'))
                        local rx = engPos[1] - captureUnitPos[1]
                        local rz = engPos[3] - captureUnitPos[3]
                        local captureUnitDistance = rx * rx + rz * rz
                        if captureUnitDistance < 3600 then
                            self:ChangeState(self.CaptureUnit)
                            return
                        else
                            self:ChangeState(self.NavigateToTaskLocation)
                            return
                        end
                    end
                    self.BuilderData = {}
                    coroutine.yield(10)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            if aiBrain.ReclaimEnabled and not aiBrain.StartReclaimTaken then
                self:LogDebug(string.format('We are switching to start reclaiming state'))
                self:ChangeState(self.GetStartReclaim)
                return
            end
            if aiBrain.ReclaimEnabled and self.PlatoonData.ReclaimTable and aiBrain.GridReclaim and not self.BuilderData.ReclaimTableFailed then
                self:LogDebug(string.format('We are switching to ReclaimTable state'))
                self:ChangeState(self.GetReclaimTable)
                return
            end
            if aiBrain.ReclaimEnabled then
                if self.BuilderData.ReclaimTableFailed then
                    self.BuilderData = {}
                end
                self:LogDebug(string.format('We are performing generic reclaim'))
                self:ChangeState(self.GetGenericReclaim)
                return
            end

            coroutine.yield(30)
            self:ExitStateMachine()
            return
        end,
    },

    CheckForExtractorBuild = State {

        StateName = 'CheckForExtractorBuild',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local whatToBuild =self.ExtractorBuildID
            local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, self:GetPlatoonPosition(), 25)
            if bool then
                self:LogDebug(string.format('We found an extractor that we should build on'))
                IssueClearCommands({eng})
                --RNGLOG('Reclaim AI We can build on a mass marker within 30')
                for _,massMarker in markers do
                    RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 2)
                    RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                    if massMarker.BorderWarning then
                        IssueBuildMobile({eng}, massMarker.Position, whatToBuild, {})
                    else
                        aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                    end
                end
                while eng and not eng.Dead and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                    coroutine.yield(20)
                end
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CaptureUnit = State {

        StateName = 'CaptureUnit',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local captureUnit = builderData.CaptureUnit
            local pos = eng:GetPosition()
            local captureUnitCallback = function(unit, captor)
                local aiBrain = captor:GetAIBrain()
                --LOG('*AI DEBUG: ENGINEER: I was Captured by '..aiBrain.Nickname..'!')
                if unit and (unit.Blueprint.CategoriesHash.MOBILE and unit.Blueprint.CategoriesHash.LAND 
                and not unit.Blueprint.CategoriesHash.ENGINEER) then
                    if unit:TestToggleCaps('RULEUTC_ShieldToggle') then
                        --LOG('Enable shield for '..unit.UnitId)
                        unit:SetScriptBit('RULEUTC_ShieldToggle', true)
                        if unit.MyShield then
                            unit.MyShield:TurnOn()
                        end
                    end
                    if unit and not IsDestroyed(unit) then
                        local capturedPlatoon = aiBrain:MakePlatoon('', '')
                        capturedPlatoon.PlanName = 'Captured Platoon'
                        aiBrain:AssignUnitsToPlatoon(capturedPlatoon, {unit}, 'Attack', 'None')
                        import("/mods/rngai/lua/ai/statemachines/platoon-land-combat.lua").AssignToUnitsMachine({ }, capturedPlatoon, unit)
                    end
                end
                captor.CaptureComplete = true
            end
            if captureUnit and not IsDestroyed(captureUnit) then
                self:LogDebug(string.format('We are trying to capture a unit'))
                import('/lua/scenariotriggers.lua').CreateUnitCapturedTrigger(nil, captureUnitCallback, captureUnit)
                IssueClearCommands({eng})
                IssueCapture({eng}, captureUnit)
                while aiBrain:PlatoonExists(self) and not eng.CaptureComplete do
                    coroutine.yield(30)
                end
                eng.CaptureComplete = nil
            end
            self.BuilderData = {}
            self.BuilderData.ConstructionComplete = true
            coroutine.yield(5)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    GetStartReclaim = State {

        StateName = 'GetStartReclaim',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local maxReclaimRadius = (eng.Blueprint.Economy.MaxBuildDistance or 5) * (eng.Blueprint.Economy.MaxBuildDistance or 5)
            local tableSize = RNGGETN(aiBrain.StartReclaimTable)
            self:LogDebug(string.format('Reclaim Table size is '..tostring(tableSize)))
            if tableSize > 0 then
                IssueClearCommands({eng})
                self:LogDebug(string.format('We aretrying to get start reclaim'))
                local reclaimCount = 0
                local firstReclaim = false
                while tableSize > 0 do
                    local reclaimKeysToFlush = {}
                    local tableRebuild = false
                    local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.8
                    self:LogDebug(string.format('Start Reclaim loop, table size is '..tostring(tableSize)))
                    coroutine.yield(1)
                    local engPos = eng:GetPosition()
                    aiBrain.StartReclaimTaken = true
                    local closestReclaimDistance
                    local closestReclaim
                    local closestReclaimKey
                    local highestValue = 0
                    if not firstReclaim then
                        --LOG('This is first reclaim so we are looking for the highest value')
                        for k, r in aiBrain.StartReclaimTable do
                            if r.Reclaim and not IsDestroyed(r.Reclaim) then
                                local reclaimValue
                                if needEnergy then
                                    reclaimValue = r.Reclaim.MaxEnergyReclaim + r.Reclaim.MaxMassReclaim
                                else
                                    reclaimValue = r.Reclaim.MaxMassReclaim
                                end
                                local reclaimDistance = VDist3Sq(engPos, r.Reclaim.CachePosition)
                                if reclaimValue > highestValue or (reclaimValue == highestValue and reclaimDistance < closestDistance) then
                                    self:LogDebug(string.format('We have selected a start reclaim on first reclaim, checking pathable'))
                                    if NavUtils.CanPathTo('Amphibious', engPos, r.Reclaim.CachePosition) then
                                        closestReclaim = r.Reclaim
                                        closestReclaimKey = k
                                        highestValue = reclaimValue
                                        closestDistance = reclaimDistance
                                    else
                                        self:LogDebug(string.format('We cant path to the reclaim cache spot, reclaim key'))
                                        if aiBrain.StartReclaimTable[k] then
                                            table.insert(reclaimKeysToFlush, k)
                                            tableRebuild = true
                                        end
                                    end
                                end
                            elseif aiBrain.StartReclaimTable[k] then
                                table.insert(reclaimKeysToFlush, k)
                                tableRebuild = true
                            end
                        end
                        firstReclaim = true
                    else
                        for k, r in aiBrain.StartReclaimTable do
                            local reclaimDistance
                            if r.Reclaim and not IsDestroyed(r.Reclaim) then
                                reclaimDistance = VDist3Sq(engPos, r.Reclaim.CachePosition)
                                if not closestReclaimDistance or reclaimDistance < closestReclaimDistance then
                                    self:LogDebug(string.format('We have selected a start reclaim, checking pathable'))
                                    if NavUtils.CanPathTo('Amphibious', engPos, r.Reclaim.CachePosition) then
                                        self:LogDebug(string.format('We can path to start reclaim'))
                                        closestReclaim = r.Reclaim
                                        closestReclaimDistance = reclaimDistance
                                        closestReclaimKey = k
                                    else
                                        self:LogDebug(string.format('We cant path to the reclaim cache spot, reclaim key'))
                                        if aiBrain.StartReclaimTable[k] then
                                            table.insert(reclaimKeysToFlush, k)
                                            tableRebuild = true
                                        end
                                    end
                                end
                            elseif aiBrain.StartReclaimTable[k] then
                                table.insert(reclaimKeysToFlush, k)
                                tableRebuild = true
                            end
                            
                        end
                    end
                    if closestReclaim then
                        self:LogDebug(string.format('We have closest reclaim'))
                        --LOG('Closest Reclaim is true we are going to try reclaim it')
                        reclaimCount = reclaimCount + 1
                        --LOG('Reclaim Function - Issuing reclaim')
                        local engPos = eng:GetPosition()
                        local reclaimDist = VDist3(engPos, closestReclaim.CachePosition)
                        local lerpPosition = RUtils.lerpy(engPos, closestReclaim.CachePosition, {reclaimDist, reclaimDist - 4.5})
                        IssueMove({eng}, lerpPosition)
                        coroutine.yield(10)
                        local reclaimTimeout = 0
                        local massOverflow = false
                        while aiBrain:PlatoonExists(self) and closestReclaim and (not IsDestroyed(closestReclaim)) and (reclaimTimeout < 40) do
                            local reclaimDistance = VDist3Sq(engPos, closestReclaim.CachePosition)
                            if reclaimDistance <= (maxReclaimRadius + 9) then
                                IssueReclaim({eng}, closestReclaim)
                            end
                            local brokenPathMovement = false
                            reclaimTimeout = reclaimTimeout + 1
                            --RNGLOG('Waiting for reclaim to no longer exist')
                            if eng:IsUnitState('Reclaiming') and reclaimTimeout > 0 then
                                reclaimTimeout = reclaimTimeout - 1
                            end
                            brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                            if brokenPathMovement and closestReclaim and (not IsDestroyed(closestReclaim)) then
                                local engPos = eng:GetPosition()
                                local reclaimDist = VDist3(engPos, closestReclaim.CachePosition)
                                local lerpPosition = RUtils.lerpy(engPos, closestReclaim.CachePosition, {reclaimDist, reclaimDist - 4})
                                IssueMove({eng}, lerpPosition)
                            end
                            coroutine.yield(10)
                        end
                        self:LogDebug(string.format('We should be setting the following table key to nil '..tostring(closestReclaimKey)))
                        table.insert(reclaimKeysToFlush, closestReclaimKey)
                        tableRebuild = true
                    end
                    reclaimCount = reclaimCount + 1
                    if reclaimCount > 15 then
                        break
                    end
                    coroutine.yield(2)
                    if tableRebuild then
                        for _, v in reclaimKeysToFlush do
                            if aiBrain.StartReclaimTable[v] then
                                aiBrain.StartReclaimTable[v] = nil
                            end
                        end
                        aiBrain.StartReclaimTable = aiBrain:RebuildTable(aiBrain.StartReclaimTable)
                    end
                    tableSize = RNGGETN(aiBrain.StartReclaimTable)
                end
                
                if RNGGETN(aiBrain.StartReclaimTable) == 0 then
                    --RNGLOG('Start Reclaim Taken set to true')
                    aiBrain.StartReclaimTaken = true
                else
                    --RNGLOG('Start Reclaim table not empty, set StartReclaimTaken to false')
                    aiBrain.StartReclaimTaken = false
                end
            else
                aiBrain.StartReclaimTaken = true
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    GetReclaimTable = State {

        StateName = 'GetReclaimTable',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            local function MexBuild(eng, aiBrain)
                local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, eng:GetPosition(), 25)
                if bool then
                    IssueClearCommands({eng})
                    local whatToBuild = eng.AIPlatoonReference.ExtractorBuildID
                    --RNGLOG('Reclaim AI We can build on a mass marker within 30')
                    for _,massMarker in markers do
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 2)
                        RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                        if massMarker.BorderWarning then
                            IssueBuildMobile({eng}, massMarker.Position, whatToBuild, {})
                        else
                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                        end
                    end
                    while eng and not eng.Dead and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                        coroutine.yield(20)
                    end
                end
            end
            local aiBrain = self:GetBrain()
            local eng = self.eng
           
            local searchType
            local reclaimGridInstance = aiBrain.GridReclaim
            local brainGridInstance = aiBrain.GridBrain
            local deathFunction = function(unit)
                if unit.CellAssigned then
                    -- Brain is assigned on unit create, if issues use eng:GetAIBrain()
                    local brainGridInstance = unit.Brain.GridBrain
                    local brainCell = brainGridInstance:ToCellFromGridSpace(unit.CellAssigned[1], unit.CellAssigned[2])
                    -- confirm engineer is removed from cell during debug
                    brainGridInstance:RemoveReclaimingEngineer(brainCell, unit)
                end
            end
            self:LogDebug(string.format('We are trying to get reclaim table'))
            import("/lua/scenariotriggers.lua").CreateUnitDestroyedTrigger(deathFunction, eng)
            if self.PlatoonData.Early then
                searchType = 'MAIN'
            end

            local reclaimTargetX, reclaimTargetZ = RUtils.EngFindReclaimCell(aiBrain, eng, self.MovementLayer, searchType)
            if reclaimTargetX and reclaimTargetZ then
                local brainCell = brainGridInstance:ToCellFromGridSpace(reclaimTargetX, reclaimTargetZ)
                -- Assign engineer to cell
                eng.CellAssigned = {reclaimTargetX, reclaimTargetZ}
                if brainCell then
                    brainGridInstance:AddReclaimingEngineer(brainCell, eng)
                end
                local validLocation = reclaimGridInstance:ToWorldSpace(reclaimTargetX, reclaimTargetZ)

                if validLocation then
                    IssueClearCommands({eng})
                    if AIUtils.EngineerMoveWithSafePathRNG(aiBrain, eng, validLocation, true) then
                        if not eng or eng.Dead or not aiBrain:PlatoonExists(self) then
                            return
                        end
                        local engStuckCount = 0
                        local Lastdist
                        local dist
                        while not eng.Dead and aiBrain:PlatoonExists(self) do
                            coroutine.yield(1)
                            engPos = eng:GetPosition()
                            dist = VDist3Sq(engPos, validLocation)
                            if dist < 144 then
                                --RNGLOG('We are at the grid square location, dist is '..dist)
                                IssueClearCommands({eng})
                                break
                            end
                            if Lastdist ~= dist then
                                engStuckCount = 0
                                Lastdist = dist
                            else
                                engStuckCount = engStuckCount + 1
                                if engStuckCount > 15 and not eng:IsUnitState('Reclaiming') then
                                    break
                                end
                            end
                            if eng:IsIdleState() then
                                IssueMove({eng}, validLocation)
                            end
                            if eng:IsUnitState("Moving") then
                                if GetNumUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy') > 0 then
                                    local enemyEngineer = GetUnitsAroundPoint(aiBrain, categories.LAND * categories.ENGINEER * (categories.TECH1 + categories.TECH2), engPos, 10, 'Enemy')
                                    if enemyEngineer then
                                        local enemyEngPos
                                        for _, unit in enemyEngineer do
                                            if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                                enemyEngPos = unit:GetPosition()
                                                local dx = engPos[1] - enemyEngPos[1]
                                                local dz = engPos[3] - enemyEngPos[3]
                                                local enemyEngPos = dx * dx + dz * dz
                                                if enemyEngPos < 100 then
                                                    IssueClearCommands({eng})
                                                    IssueReclaim({eng}, enemyEngineer[1])
                                                    break
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                            coroutine.yield(25)
                        end
                        if not eng or eng.Dead or not aiBrain:PlatoonExists(self) then
                            coroutine.yield(1)
                            return
                        end
                        local reclaimAvailable = true
                        local maxRetries = 20
                        local reclaimRetryCount = 0
                        while reclaimAvailable and not eng.Dead do
                            engPos = eng:GetPosition()
                            -- reclaim grid for a better reclaim position 9 points with 1 being the current engineer position
                            -- we create a grid of 8 squares around the engineer that it will search after each grid square is reclaim it is removed.
                            local reclaimGrid = {
                                {engPos[1], 0 ,engPos[3]},
                                {engPos[1], 0 ,engPos[3] + 15},
                                {engPos[1] + 15, 0 ,engPos[3] + 15},
                                {engPos[1] + 15, 0, engPos[3]},
                                {engPos[1] + 15, 0, engPos[3] - 15},
                                {engPos[1], 0, engPos[3] - 15},
                                {engPos[1] - 15, 0, engPos[3] - 15},
                                {engPos[1] - 15, 0, engPos[3]},
                                {engPos[1] - 15, 0, engPos[3] + 15},
                                {engPos[1], 0 ,engPos[3] + 25},
                                {engPos[1] + 15, 0 ,engPos[3] + 25},
                                {engPos[1] + 25, 0 ,engPos[3] + 25},
                                {engPos[1] + 25, 0 ,engPos[3] + 15},
                                {engPos[1] + 25, 0, engPos[3]},
                                {engPos[1] + 25, 0, engPos[3] - 15},
                                {engPos[1] + 25, 0, engPos[3] - 25},
                                {engPos[1] + 15, 0, engPos[3] - 25},
                                {engPos[1], 0, engPos[3] - 25},
                                {engPos[1] - 15, 0, engPos[3] - 25},
                                {engPos[1] - 25, 0, engPos[3] - 25},
                                {engPos[1] - 25, 0, engPos[3] - 15},
                                {engPos[1] - 25, 0, engPos[3]},
                                {engPos[1] - 25, 0, engPos[3] + 15},
                                {engPos[1] - 15, 0, engPos[3] + 25},
                                {engPos[1] - 25, 0, engPos[3] + 25},
                            }
                            --LOG('EngineerReclaimGrid '..repr(reclaimGrid))
                            if reclaimGrid and not table.empty( reclaimGrid ) then
                                local reclaimCount = 0
                                local engineerHasReclaimed = false
                                for k, square in reclaimGrid do
                                    local squarePos = {square[1], GetTerrainHeight(square[1], square[3]), square[3]}
                                    if NavUtils.CanPathTo('Amphibious', engPos, squarePos) then
                                        local minX = math.max(square[1] - 8, 0)
                                        local maxX = math.min(square[1] + 8, self.MapSizeX)
                                        local minZ = math.max(square[3] - 8, 0)
                                        local maxZ = math.min(square[3] + 8, self.MapSizeZ) -- Assuming square map size
                                        local rectDef = Rect(minX, minZ, maxX, maxZ)
                                        local reclaimRect = GetReclaimablesInRect(rectDef)
                                        local engReclaiming = false
                                        if reclaimRect then
                                            for c, b in reclaimRect do
                                                if not IsProp(b) or self.BadReclaimables[b] then continue end
                                                -- Start Blacklisted Props
                                                local blacklisted = false
                                                for _, BlackPos in RNGAIGLOBALS.PropBlacklist do
                                                    if b.CachePosition[1] == BlackPos[1] and b.CachePosition[3] == BlackPos[3] then
                                                        blacklisted = true
                                                        break
                                                    end
                                                end
                                                if blacklisted then continue end
                                                if b.MaxMassReclaim and b.MaxMassReclaim >= 5 then
                                                    engReclaiming = true
                                                    engineerHasReclaimed = true
                                                    reclaimCount = reclaimCount + 1
                                                    IssueReclaim({eng}, b)
                                                end
                                            end
                                        end
                                        if engReclaiming then
                                            coroutine.yield(1)
                                            local idleCounter = 0
                                            while not eng.Dead and 0<RNGGETN(eng:GetCommandQueue()) and aiBrain:PlatoonExists(self) do
                                                if not eng:IsUnitState('Reclaiming') and not eng:IsUnitState('Moving') then
                                                    --RNGLOG('We are not reclaiming or moving in the reclaim loop')
                                                    --RNGLOG('But we still have '..RNGGETN(self:GetCommandQueue())..' Commands in the queue')
                                                    idleCounter = idleCounter + 1
                                                    if idleCounter > 10 then
                                                        IssueClearCommands({eng})
                                                        break
                                                    end
                                                end
                                                --RNGLOG('We are reclaiming stuff')
                                                coroutine.yield(30)
                                            end
                                        end
                                    end
                                    MexBuild(eng, aiBrain)
                                    if engineerHasReclaimed then
                                        break
                                    end
                                end
                                if not engineerHasReclaimed then
                                    reclaimAvailable = false
                                end
                                --RNGLOG('reclaim grid loop has finished')
                                --RNGLOG('Total things that should have be issued reclaim are '..reclaimCount)
                            else
                                reclaimAvailable = false
                            end
                            reclaimRetryCount = reclaimRetryCount + 1
                            if reclaimRetryCount > maxRetries then
                                break
                            end
                        end
                    else
                        self:LogDebug(string.format('Eng could not move with safe path'))
                        if eng.CellAssigned then
                            -- Brain is assigned on unit create, if issues use eng:GetAIBrain()
                            local brainGridInstance = aiBrain.GridBrain
                            local brainCell = brainGridInstance:ToCellFromGridSpace(eng.CellAssigned[1], eng.CellAssigned[2])
                            -- confirm engineer is removed from cell during debug
                            brainGridInstance:RemoveReclaimingEngineer(brainCell, eng)
                        end
                        self.ReclaimTableLoop = self.ReclaimTableLoop + 1
                        if self.ReclaimTableLoop == 5 then
                            self.BuilderData = {
                                ReclaimTableFailed = true
                            }
                            coroutine.yield(20)
                            self:ChangeState(self.DecideWhatToDo)
                            return
                        end
                    end
                else
                    self:LogDebug(string.format('ToWorldSpace did not provide valid location'))
                end
            else
                self.BuilderData = {
                    ReclaimTableFailed = true
                }
                coroutine.yield(20)
                self:LogDebug(string.format('Nothing returned from EngFindReclaimCell'))
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    GetGenericReclaim = State {

        StateName = 'GetGenericReclaim',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local function MexBuild(eng, aiBrain)
                local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, eng:GetPosition(), 25)
                if bool then
                    IssueClearCommands({eng})
                    local whatToBuild = eng.AIPlatoonReference.ExtractorBuildID
                    --RNGLOG('Reclaim AI We can build on a mass marker within 30')
                    for _,massMarker in markers do
                        RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 2)
                        RUtils.EngineerTryRepair(aiBrain, eng, whatToBuild, massMarker.Position)
                        if massMarker.BorderWarning then
                            IssueBuildMobile({eng}, massMarker.Position, whatToBuild, {})
                        else
                            aiBrain:BuildStructure(eng, whatToBuild, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                        end
                    end
                    while eng and not eng.Dead and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                        coroutine.yield(20)
                    end
                end
            end
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local engPos = eng:GetPosition()
            local furtherestReclaim
            local closestReclaim
            local closestDistance
            local furtherestDistance
            local x1 = engPos[1] - self.InitialRange
            local x2 = engPos[1] + self.InitialRange
            local z1 = engPos[3] - self.InitialRange
            local z2 = engPos[3] + self.InitialRange
            local rect = Rect(x1, z1, x2, z2)
            local reclaimRect = {}
            local minRec = self.PlatoonData.MinimumReclaim or 5
            reclaimRect = GetReclaimablesInRect(rect)
            if not engPos then
                coroutine.yield(1)
                return
            end
    
            local reclaim = {}
            
            if reclaimRect and not table.empty( reclaimRect ) then
                local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.8
                for k,v in reclaimRect do
                    if not IsProp(v) or self.BadReclaimables[v] then continue end
                    local rpos = v.CachePosition
                    -- Start Blacklisted Props
                    local blacklisted = false
                    for _, BlackPos in RNGAIGLOBALS.PropBlacklist do
                        if rpos[1] == BlackPos[1] and rpos[3] == BlackPos[3] then
                            blacklisted = true
                            break
                        end
                    end
                    if blacklisted then continue end
                    -- End Blacklisted Props
                    if not needEnergy or v.MaxEnergyReclaim then
                        if v.MaxMassReclaim and v.MaxMassReclaim >= minRec then
                            if not self.BadReclaimables[v] then
                                local distance = VDist2(engPos[1], engPos[3], v.CachePosition[1], v.CachePosition[3])
                                if not closestDistance or distance < closestDistance then
                                    closestReclaim = v.CachePosition
                                    closestDistance = distance
                                end
                                if not furtherestDistance or distance > furtherestDistance then -- and distance < closestDistance + 20
                                    if NavUtils.CanPathTo(self.MovementLayer, engPos, v.CachePosition) then
                                        furtherestReclaim = v.CachePosition
                                        furtherestDistance = distance
                                        if furtherestDistance - closestDistance > 20 then
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            else
                self.InitialRange = self.InitialRange + 100
                if self.InitialRange > 300 then
                    RNGAIGLOBALS.PropBlacklist = {}
                    aiBrain.ReclaimEnabled = false
                    aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                    coroutine.yield(1)
                    self:ExitStateMachine()
                    return
                end
                coroutine.yield(2)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if closestDistance == 10000 then
                self.InitialRange = self.InitialRange + 100
                if self.InitialRange > 200 then
                    RNGAIGLOBALS.PropBlacklist = {}
                    aiBrain.ReclaimEnabled = false
                    aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                    coroutine.yield(1)
                    self:ExitStateMachine()
                    return
                end
                coroutine.yield(2)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
            if eng.Dead then 
                return
            end
            IssueClearCommands({eng})
            if not closestReclaim and not furtherestReclaim then
                coroutine.yield(5)
                self:ExitStateMachine()
                return
            end
            if self.lastXtarget == closestReclaim[1] and self.lastYtarget == closestReclaim[3] then
                self.blocked = self.blocked + 1
                if self.blocked > 3 then
                    self.blocked = 0
                    table.insert (RNGAIGLOBALS.PropBlacklist, closestReclaim)
                end
            else
                self.blocked = 0
                self.lastXtarget = closestReclaim[1]
                self.lastYtarget = closestReclaim[3]
                RUtils.StartMoveDestination(eng, closestReclaim)
            end
    
            IssueClearCommands({eng})
            if furtherestReclaim then
                IssueAggressiveMove({eng}, furtherestReclaim)
            else
                IssueAggressiveMove({eng}, closestReclaim)
            end
            local reclaiming = not eng:IsIdleState()
            local max_time = self.PlatoonData.ReclaimTime
            local currentTime = 0
            local idleCount = 0
            while reclaiming do
                coroutine.yield(100)
                if eng.Dead then
                    return
                end
                currentTime = currentTime + 10
                if currentTime > max_time then
                    reclaiming = false
                end
                if eng:IsIdleState() then
                    idleCount = idleCount + 1
                    if idleCount > 5 then
                        reclaiming = false
                    end
                end
                MexBuild(eng, aiBrain)
            end
            if IsDestroyed(self) then
                return
            end
            IssueClearCommands({eng})
            self.GenericReclaimLoop = self.GenericReclaimLoop + 1
            if self.GenericReclaimLoop == 5 then
                coroutine.yield(1)
                self:ExitStateMachine()
                return
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    NavigateToTaskLocation = State {

        StateName = 'NavigateToTaskLocation',

        --- Initial state of any state machine
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            local pos = eng:GetPosition()
            local path, reason = AIAttackUtils.PlatoonGenerateSafePathToRNG(aiBrain, self.MovementLayer, pos, builderData.Position, 30 , 30)
            self:LogDebug(string.format('Navigating to position, path reason is '..tostring(reason)))
            local result, navReason
            local whatToBuildM = self.ExtractorBuildID
            local bUsedTransports
            if reason ~= 'PathOK' then
                self:LogDebug(string.format('Path is not ok '))
                -- we will crash the game if we use CanPathTo() on all engineer movments on a map without markers. So we don't path at all.
                if reason == 'NoGraph' then
                    result = true
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) < 300*300 then
                    --self:LogDebug(string.format('Distance is less than 300'))
                    --SPEW('* AI-RNG: engineerMoveWithSafePath(): executing CanPathTo(). LUA GenerateSafePathTo returned: ('..repr(reason)..') '..VDist2Sq(pos[1], pos[3], destination[1], destination[3]))
                    -- be really sure we don't try a pathing with a destoryed c-object
                    if IsDestroyed(eng) then
                        --SPEW('* AI-RNG: Unit is death before calling CanPathTo()')
                        return
                    end
                    result, navReason = NavUtils.CanPathTo('Amphibious', pos, builderData.Position)
                    --self:LogDebug(string.format('Can we path to it '..tostring(result)))
                end 
            end
            if (not result and reason ~= 'PathOK') or VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 350 * 350
            and eng.PlatoonHandle and not EntityCategoryContains(categories.COMMAND, eng) then

                -- Skip the last move... we want to return and do a build
               eng.WaitingForTransport = true
               bUsedTransports = import("/mods/RNGAI/lua/AI/transportutilitiesrng.lua").SendPlatoonWithTransports(aiBrain, eng.PlatoonHandle, builderData.Position, 2, true)
               eng.WaitingForTransport = false

                if bUsedTransports then
                    --self:LogDebug(string.format('Used a transport'))
                    coroutine.yield(10)
                    if eng.EngineerBuildQueue and table.getn(eng.EngineerBuildQueue) > 0 then
                        self:ChangeState(self.Constructing)
                        return
                    else
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                elseif VDist2Sq(pos[1], pos[3], builderData.Position[1], builderData.Position[3]) > 512 * 512 then
                    -- If over 512 and no transports dont try and walk!
                    self:LogDebug(string.format('No transport available and distance is greater than 512, decide what to do'))
                    coroutine.yield(20)
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end
            if result or reason == 'PathOK' then
                --RNGLOG('* AI-RNG: engineerMoveWithSafePath(): result or reason == PathOK ')
                if reason ~= 'PathOK' then
                    path, reason = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, 'Amphibious', pos, builderData.Position)
                end
                if path then
                    --self:LogDebug(string.format('We are going to walk to the destination (a transport might have brought us)'))
                    --RNGLOG('* AI-RNG: engineerMoveWithSafePath(): path 0 true')
                    -- Move to way points (but not to destination... leave that for the final command)
                    --RNGLOG('We are issuing move commands for the path')
                    local dist
                    local pathLength = RNGGETN(path)
                    --self:LogDebug(string.format('Path length is '..tostring(pathLength)))
                    local brokenPathMovement = false
                    local currentPathNode = 1
                    IssueClearCommands({eng})
                    for i=currentPathNode, pathLength do
                        if i>=3 then
                            local bool,markers=StateUtils.CanBuildOnMassMexPlatoon(aiBrain, path[i], 25)
                            if bool then
                                --local massMarker = RUtils.GetClosestMassMarkerToPos(aiBrain, waypointPath)
                                --RNGLOG('Mass Marker'..repr(massMarker))
                                --RNGLOG('Attempting second mass marker')
                                local buildQueueReset = eng.EngineerBuildQueue or {}
                                eng.EngineerBuildQueue = {}
                                for _,massMarker in markers do
                                    RUtils.EngineerTryReclaimCaptureArea(aiBrain, eng, massMarker.Position, 5)
                                    RUtils.EngineerTryRepair(aiBrain, eng, whatToBuildM, massMarker.Position)
                                    if massMarker.BorderWarning then
                                       --RNGLOG('Border Warning on mass point marker')
                                        IssueBuildMobile({eng}, {massMarker.Position[1], massMarker.Position[3], 0}, whatToBuildM, {})
                                        local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, true, PathPoint=i}
                                        RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                    else
                                        aiBrain:BuildStructure(eng, whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false)
                                        local newEntry = {whatToBuildM, {massMarker.Position[1], massMarker.Position[3], 0}, false,Position=massMarker.Position, false, PathPoint=i}
                                        RNGINSERT(eng.EngineerBuildQueue, newEntry)
                                    end
                                end
                                if buildQueueReset then
                                    for k, v in buildQueueReset do
                                        RNGINSERT(eng.EngineerBuildQueue, v)
                                    end
                                end
                            end
                        end
                        if (i - math.floor(i/2)*2)==0 or VDist3Sq(builderData.Position,path[i])<40*40 then 
                            if i==pathLength then
                                local distanceToDest = VDist3Sq(pos, builderData.Position)
                                local engMovePos = RUtils.lerpy(pos, builderData.Position, {math.sqrt(distanceToDest), math.sqrt(distanceToDest) - 5})
                                IssueMove({eng}, engMovePos)
                            end
                            continue 
                        end
                        --self:LogDebug(string.format('We are issuing the move command to path node '..tostring(i)))
                        IssueMove({eng}, path[i])
                    end
                    if eng.EngineerBuildQueue then
                        for k, v in eng.EngineerBuildQueue do
                            if eng.EngineerBuildQueue[k].PathPoint then
                                continue
                            end
                            if eng.EngineerBuildQueue[k][5] then
                                IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                            else
                                aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                            end
                        end
                    end
                    while not IsDestroyed(eng) do
                        local reclaimed
                        if brokenPathMovement and eng.EngineerBuildQueue and not table.empty(eng.EngineerBuildQueue) then
                            pos = eng:GetPosition()
                            local queuePointTaken = {}
                            local skipPath = false
                            for i=currentPathNode, pathLength do
                                for k, v in eng.EngineerBuildQueue do
                                    if v.PathPoint and (v.PathPoint == i or i > v.PathPoint and not queuePointTaken[k]) then
                                        if eng.EngineerBuildQueue[k][5] then
                                            --RNGLOG('BorderWarning build')
                                            --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                            IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                        else
                                            --RNGLOG('Found build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                            aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                        end
                                        queuePointTaken[k] = true
                                        skipPath = true
                                    end
                                end
                                if not skipPath then
                                    IssueMove({eng}, path[i])
                                end
                                skipPath = false
                            end
                            for k, v in eng.EngineerBuildQueue do
                                if queuePointTaken[k] and eng.EngineerBuildQueue[k]  then
                                    --RNGLOG('QueuePoint already taken, skipping for position '..repr(eng.EngineerBuildQueue[k][2]))
                                    continue
                                end
                                if eng.EngineerBuildQueue[k][5] then
                                    --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                                else
                                    --RNGLOG('Found end build command at point '..repr(eng.EngineerBuildQueue[k][2]))
                                    aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                                end
                            end
                            if reclaimed then
                                coroutine.yield(20)
                            end
                            reclaimed = false
                            brokenPathMovement = false
                        end
                        pos = eng:GetPosition()
                        if currentPathNode <= pathLength then
                            dist = VDist3Sq(pos, path[currentPathNode])
                            if dist < 100 or (currentPathNode+1 <= pathLength and dist > VDist3Sq(pos, path[currentPathNode+1])) then
                                currentPathNode = currentPathNode + 1
                            end
                        end
                        if VDist3Sq(builderData.Position, pos) < 3600 then
                            --self:LogDebug(string.format('We are within 60 units of destination, break from while loop'))
                            break
                        end
                        coroutine.yield(15)
                        if IsDestroyed(eng) then
                            return
                        end
                        if eng:IsIdleState() then
                          self:LogDebug(string.format('We are idle for some reason, go back to decide what to do'))
                          self:ChangeState(self.DecideWhatToDo)
                          return
                        end
                        if eng.EngineerBuildQueue then
                            if ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.MASSEXTRACTION and ALLBPS[eng.EngineerBuildQueue[1][1]].CategoriesHash.TECH1 then
                                if not eng:IsUnitState('Reclaiming') then
                                    brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                                    reclaimed = true
                                end
                            end
                        end
                        if eng:IsUnitState("Moving") then
                            if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy') > 0 then
                                local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, pos, 45, 'Enemy')
                                local reclaimUnit
                                for _, eunit in enemyUnits do
                                    local enemyUnitPos = eunit:GetPosition()
                                    if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, eunit) then
                                        if VDist3Sq(enemyUnitPos, pos) < 144 then
                                            if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                                if VDist3Sq(pos, enemyUnitPos) < 100 then
                                                    IssueClearCommands({eng})
                                                    IssueReclaim({eng}, eunit)
                                                    brokenPathMovement = true
                                                    reclaimUnit = eunit
                                                    coroutine.yield(25)
                                                    break
                                                end
                                            end
                                        end
                                    elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, eunit) then
                                        if VDist3Sq(enemyUnitPos, pos) < 81 then
                                            if eunit and not eunit.Dead and eunit:GetFractionComplete() == 1 then
                                                if VDist3Sq(pos, enemyUnitPos) < 100 then
                                                    IssueClearCommands({eng})
                                                    IssueReclaim({eng}, eunit)
                                                    brokenPathMovement = true
                                                    reclaimUnit = eunit
                                                    coroutine.yield(25)
                                                    break
                                                end
                                            end
                                        else
                                            IssueClearCommands({eng})
                                            IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, pos, 50))
                                            brokenPathMovement = true
                                            reclaimUnit = eunit
                                            coroutine.yield(45)
                                        end
                                    end
                                    
                                end
                                if brokenPathMovement and reclaimUnit and eng:IsUnitState('Reclaiming') then
                                    while not IsDestroyed(reclaimUnit) and not IsDestroyed(eng) do
                                        coroutine.yield(20)
                                    end
                                end
                            end
                        end
                    end
                else
                    if reason == 'TooMuchThreat' then
                        coroutine.yield(30)
                        self:ExitStateMachine()
                        return
                    end
                    IssueMove({eng}, builderData.Position)
                end
                if IsDestroyed(self) then
                    return
                end
                coroutine.yield(10)
                self:ChangeState(self.DecideWhatToDo)
                return
            end
        end,
    },

    Retreating = State {

        StateName = 'Retreating',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng

            local engPos = eng:GetPosition()
            local enemyUnits = brain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, engPos, 45, 'Enemy')
            local action = false
            for _, unit in enemyUnits do
                local enemyUnitPos = unit:GetPosition()
                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2)
                    - categories.COMMAND, unit) then
                    if VDist2Sq(engPos[1], engPos[3], enemyUnitPos[1], enemyUnitPos[3]) < 144 then
                        if unit and not IsDestroyed(unit) and unit:GetFractionComplete() == 1 then
                            if VDist2Sq(engPos[1], engPos[3], enemyUnitPos[1], enemyUnitPos[3]) < 156 then
                                IssueClearCommands({ eng })
                                IssueReclaim({ eng }, unit)
                                action = true
                                break
                            end
                        end
                    end
                elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, unit) then
                    if VDist2Sq(engPos[1], engPos[3], enemyUnitPos[1], enemyUnitPos[3]) < 81 then
                        if unit and not IsDestroyed(unit) and unit:GetFractionComplete() == 1 then
                            if VDist2Sq(engPos[1], engPos[3], enemyUnitPos[1], enemyUnitPos[3]) < 156 then
                                IssueClearCommands({ eng })
                                IssueReclaim({ eng }, unit)
                                action = true
                                break
                            end
                        end
                    else
                        IssueClearCommands({ eng })
                        IssueMove({ eng }, AIUtils.ShiftPosition(enemyUnitPos, engPos, 50, false))
                        coroutine.yield(60)
                        action = true
                    end
                end
            end
            self:ChangeState(self.Searching)
            return
        end,
    },

    Transporting = State {

        StateName = 'Transporting',

        --- The platoon avoids danger or attempts to reclaim if they are too close to avoid
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            local brain = self:GetBrain()
            local usedTransports = TransportUtils.SendPlatoonWithTransports(brain, self, self.LocationToReclaim, 3, false)
            if usedTransports then
                ----self:LogDebug(string.format('Engineer used transports'))
                self:ChangeState(self.Navigating)
            else
                ----self:LogDebug(string.format('Engineer tried but didnt use transports'))
                self:ChangeState(self.Searching)
            end
            return
        end,
    },

    Constructing = State {

        StateName = 'Constructing',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            local eng = self.eng
            local aiBrain = self:GetBrain()
            --self:LogDebug(string.format('Current build queue length '..tostring(table.getn(eng.EngineerBuildQueue))))
            if self.UsedTransports then
                if eng.EngineerBuildQueue and RNGGETN(eng:GetCommandQueue()) == 0 and table.getn(eng.EngineerBuildQueue) > 0 then
                    for k, v in eng.EngineerBuildQueue do
                        if eng.EngineerBuildQueue[k][5] then
                            IssueBuildMobile({eng}, {eng.EngineerBuildQueue[k][2][1], 0, eng.EngineerBuildQueue[k][2][2]}, eng.EngineerBuildQueue[k][1], {})
                        else
                            aiBrain:BuildStructure(eng, eng.EngineerBuildQueue[k][1], {eng.EngineerBuildQueue[k][2][1], eng.EngineerBuildQueue[k][2][2], 0}, eng.EngineerBuildQueue[k][3])
                        end
                    end
                end
                self.UsedTransports = false
            end
            --LOG('Engineer build queue length is '..table.getn(eng.EngineerBuildQueue))
            while not IsDestroyed(eng) and (0<RNGGETN(eng:GetCommandQueue()) or eng:IsUnitState('Building') or eng:IsUnitState("Moving")) do
                coroutine.yield(1)
                --RNGLOG('MexBuildAI waiting for mex build completion')
                local platPos = self:GetPlatoonPosition()
                if eng:IsUnitState("Moving") or eng:IsUnitState("Capturing") then
                    if aiBrain:GetNumUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy') > 0 then
                        local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE, platPos, 30, 'Enemy')
                        if enemyUnits then
                            local enemyUnitPos
                            for _, unit in enemyUnits do
                                enemyUnitPos = unit:GetPosition()
                                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER * (categories.TECH1 + categories.TECH2) - categories.COMMAND, unit) then
                                    if unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        if VDist3Sq(platPos, enemyUnitPos) < 156 then
                                            IssueClearCommands({eng})
                                            IssueReclaim({eng}, unit)
                                            coroutine.yield(60)
                                            self:ChangeState(self.DecideWhatToDo)
                                            return
                                        end
                                    end
                                elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, unit) then
                                    --RNGLOG('MexBuild found enemy unit, try avoid it')
                                    if VDist3Sq(platPos, enemyUnitPos) < 156 and unit and not unit.Dead and unit:GetFractionComplete() == 1 then
                                        --RNGLOG('MexBuild found enemy engineer or scout, try reclaiming')
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, unit)
                                        coroutine.yield(60)
                                        coroutine.yield(10)
                                        self:ChangeState(self.DecideWhatToDo)
                                        return
                                    else
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyUnitPos, platPos, 50))
                                        coroutine.yield(60)
                                        coroutine.yield(10)
                                        self:ChangeState(self.DecideWhatToDo)
                                        return
                                    end
                                end
                            end
                        end
                    end
                end
                coroutine.yield(20)
            end
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    CompleteBuild = State {

        StateName = 'CompleteBuild',

        --- Check for reclaim or assist or expansion specific things based on distance from base.
        ---@param self AIPlatoonEngineerBehavior
        Main = function(self)
            coroutine.yield(10)
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

}

---@param data { Behavior: 'AIPlatoonAdaptiveReclaimBehavior' }
---@param units Unit[]
AssignToUnitsMachine = function(data, platoon, units)
    if units and not TableEmpty(units) then

        -- meet platoon requirements
        import("/lua/sim/navutils.lua").Generate()
        import("/lua/sim/markerutilities.lua").GenerateExpansionMarkers()
        -- create the platoon
        setmetatable(platoon, AIPlatoonAdaptiveReclaimBehavior)
        platoon.PlatoonData = data.PlatoonData
        local engineers = platoon:GetPlatoonUnits()
        if engineers then
            local platoonCount = 0
            for _, eng in engineers do
                platoonCount = platoonCount + 1
                if platoonCount > 1 then
                    eng.PlatoonHandle = nil
                    eng.AssistSet = nil
                    eng.AssistPlatoon = nil
                    eng.UnitBeingAssist = nil
                    eng.ReclaimInProgress = nil
                    eng.CaptureInProgress = nil
                    if not eng.Dead and eng:IsPaused() then
                        eng:SetPaused(false)
                    end
                    if not eng.Dead and eng.BuilderManagerData then
                        if eng.BuilderManagerData.EngineerManager then
                            eng.BuilderManagerData.EngineerManager:TaskFinished(eng)
                        end
                    end
                    if not eng.Dead then
                        IssueStop({ eng })
                        IssueClearCommands({ eng })
                    end
                end
            end
        end

        if platoon.PlatoonData.SearchType == 'MAIN' then
            platoon.SearchRadius = platoon:GetBrain().IMAPConfig.Rings
        end

        -- TODO: to be removed until we have a better system to populate the platoons
        platoon:OnUnitsAddedToPlatoon()

        -- start the behavior
        ChangeState(platoon, platoon.Start)
    end
end
