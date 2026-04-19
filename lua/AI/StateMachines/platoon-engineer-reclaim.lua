local AIPlatoonRNG = import("/mods/rngai/lua/ai/statemachines/platoon-base-rng.lua").AIPlatoonRNG
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
AIPlatoonAdaptiveReclaimBehavior = Class(AIPlatoonRNG) {

    PlatoonName = 'AdaptiveReclaimBehavior',

    Start = State {

        StateName = 'Start',

        --- Initial state of any state machine
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            self:LogDebug(string.format('Welcome to the EngineerReclaimBehavior StateMachine'))
            --LOG('Welcome to the EngineerReclaimBehavior StateMachine')
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
            local builderData = self.BuilderData
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
            if builderData and builderData.StateWanted == 'GetReclaimTable' then
                self:LogDebug(string.format('We are switching to ReclaimTable state and we already had it set'))
                self:ChangeState(self.GetReclaimTable)
                return
            end
                if builderData and builderData.StateWanted == 'GetReclaimTable' then
                self:LogDebug(string.format('We are switching to ReclaimTable state and we already had it set'))
                self:ChangeState(self.GetReclaimTable)
                return
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
            --LOG('We did not perform a reclaim table state, self.BuilderData.ReclaimTableFailed is '..tostring(self.BuilderData.ReclaimTableFailed)..' reclaim table '..tostring(self.PlatoonData.ReclaimTable))
            if aiBrain.ReclaimEnabled then
                if self.BuilderData.ReclaimTableFailed then
                    self.BuilderData = {}
                end
                self:LogDebug(string.format('We are performing generic reclaim'))
                self:ChangeState(self.GetGenericReclaim)
                return
            end

            coroutine.yield(30)
            --LOG('Exiting state machine after decidewhattodo')
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
            --LOG('Start reclaim table size is '..tostring(tableSize))
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
                                            TableInsert(reclaimKeysToFlush, k)
                                            tableRebuild = true
                                        end
                                    end
                                end
                            elseif aiBrain.StartReclaimTable[k] then
                                TableInsert(reclaimKeysToFlush, k)
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
                                            TableInsert(reclaimKeysToFlush, k)
                                            tableRebuild = true
                                        end
                                    end
                                end
                            elseif aiBrain.StartReclaimTable[k] then
                                TableInsert(reclaimKeysToFlush, k)
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
                        while aiBrain:PlatoonExists(self) and closestReclaim and (not IsDestroyed(closestReclaim)) and (reclaimTimeout < 80) do
                            -- word of warning here, used vdist2sq because if you use 3 then reclaim thats under water may not be within range.
                            local reclaimDistance = VDist2Sq(engPos[1], engPos[3] ,closestReclaim.CachePosition[1], closestReclaim.CachePosition[3])
                            local bp = closestReclaim.Blueprint
                            local boxSize = (bp.SizeX + bp.SizeZ) * 0.25
                            if reclaimDistance <= (maxReclaimRadius + (boxSize * boxSize) + 9) then
                                IssueReclaim({eng}, closestReclaim)
                            end
                            local brokenPathMovement = false
                            reclaimTimeout = reclaimTimeout + 1
                            --LOG('Waiting for reclaim to no longer exist, timeout is '..tostring(reclaimTimeout))
                            if eng:IsUnitState('Reclaiming') and reclaimTimeout > 0 then
                                reclaimTimeout = reclaimTimeout - 1
                            end
                            brokenPathMovement = RUtils.PerformEngReclaim(aiBrain, eng, 1)
                            if brokenPathMovement and closestReclaim and (not IsDestroyed(closestReclaim)) then
                                local engPos = eng:GetPosition()
                                local reclaimDist = VDist3(engPos, closestReclaim.CachePosition)
                                local lerpPosition = RUtils.lerpy(engPos, closestReclaim.CachePosition, {reclaimDist, reclaimDist - 4})
                                IssueMove({eng}, lerpPosition)
                            end
                            coroutine.yield(10)
                        end
                        self:LogDebug(string.format('We should be setting the following table key to nil '..tostring(closestReclaimKey)))
                        TableInsert(reclaimKeysToFlush, closestReclaimKey)
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
            local reclaimTargetX, reclaimTargetZ
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
            if self.BuilderData.CellAssigned and self.BuilderData.Position then
                reclaimTargetX, reclaimTargetZ = self.BuilderData.CellAssigned[1], self.BuilderData.CellAssigned[2]
                self.BuilderData = {}
            end
            if not reclaimTargetX and not reclaimTargetZ  then
                reclaimTargetX, reclaimTargetZ = RUtils.EngFindReclaimCell(aiBrain, eng, self.MovementLayer, searchType)
            end
            if reclaimTargetX and reclaimTargetZ then
                self:LogDebug(string.format('GetReclaimTable We have a reclaimtargetx and reclaimtargetz '))
                local brainCell = brainGridInstance:ToCellFromGridSpace(reclaimTargetX, reclaimTargetZ)
                -- Assign engineer to cell
                eng.CellAssigned = {reclaimTargetX, reclaimTargetZ}
                if brainCell then
                    brainGridInstance:AddReclaimingEngineer(brainCell, eng)
                end
                local validLocation = reclaimGridInstance:ToWorldSpace(reclaimTargetX, reclaimTargetZ)

                if validLocation then
                    local engPos = eng:GetPosition()
                    self:LogDebug(string.format('GetReclaimTable We have a valid location '))
                    IssueClearCommands({eng})
                    self:LogDebug(string.format('Trying to move with safe path '))
                    local reclaimGridDist = VDist3Sq(engPos, validLocation)
                    if reclaimGridDist > 2025 then
                        self.BuilderData = {
                            Position = validLocation,
                            StateWanted = 'GetReclaimTable',
                            CellAssigned = {reclaimTargetX, reclaimTargetZ}
                        }
                        self:ChangeState(self.NavigateToLocation)
                        return
                    end
                    self:LogDebug(string.format('EngineerMoveWithSafePathRNG  returned  true'))
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
                        self:LogDebug(string.format('Engineer is moving to validLocation, distance is '..tostring(dist)))
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
                            local leeway = 2.0
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
                                            local bPos = b.CachePosition or b:GetPosition()
                                            if not bPos[1] then
                                                continue
                                            end
                                            
                                            if bPos[1] < (minX - leeway) or bPos[1] > (maxX + leeway)
                                            or bPos[3] < (minZ - leeway) or bPos[3] > (maxZ + leeway) then
                                                continue
                                            end
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
                    --[[
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
                    ]]
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
            if self.PlatoonData.Early then
                self.PlatoonData.Early = false
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
                local needEnergy = aiBrain:GetEconomyStoredRatio('ENERGY') < 0.5
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
                --LOG('Increasing initial reclaim range, is currently '..tostring(self.InitialRange))
                if self.InitialRange > 500 then
                    RNGAIGLOBALS.PropBlacklist = {}
                    aiBrain.ReclaimEnabled = false
                    aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                    coroutine.yield(1)
                    --LOG('Exiting state machine after initial range got too large')
                    self:ExitStateMachine()
                    return
                else
                    coroutine.yield(5)
                    self:ChangeState(self.GetGenericReclaim)
                    return
                end
            end
            if closestDistance == 10000 then
                self.InitialRange = self.InitialRange + 100
                if self.InitialRange > 200 then
                    RNGAIGLOBALS.PropBlacklist = {}
                    aiBrain.ReclaimEnabled = false
                    aiBrain.ReclaimLastCheck = GetGameTimeSeconds()
                    coroutine.yield(1)
                    --LOG('Exiting state machine after closest distance hit 10000')
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
                if self.InitialRange < 250 then
                    self.InitialRange = self.InitialRange + 100
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                --LOG('Exiting state machine after no closest or furtherest reclaim, current range is '..tostring(self.InitialRange))
                self:ExitStateMachine()
                return
            end
            if self.lastXtarget == closestReclaim[1] and self.lastYtarget == closestReclaim[3] then
                self.blocked = self.blocked + 1
                if self.blocked > 3 then
                    self.blocked = 0
                    TableInsert(RNGAIGLOBALS.PropBlacklist, closestReclaim)
                end
            else
                self.blocked = 0
                self.lastXtarget = closestReclaim[1]
                self.lastYtarget = closestReclaim[3]
                RUtils.StartMoveDestination(eng, closestReclaim)
            end
    
            IssueClearCommands({eng})
            local reclaimTarget = furtherestReclaim or closestReclaim
            if reclaimTarget then
                local canPath = NavUtils.CanPathTo(self.MovementLayer, engPos, reclaimTarget)
                if not canPath then
                    self.BuilderData = {
                        Position = reclaimTarget,
                        StateWanted = 'GetGenericReclaim',
                        }
                    self:ChangeState(self.NavigateToLocation)
                    return
                end
            end
            if reclaimTarget then
                IssueAggressiveMove({eng}, reclaimTarget)
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
            end
            if IsDestroyed(self) then
                return
            end
            IssueClearCommands({eng})
            self.GenericReclaimLoop = self.GenericReclaimLoop + 1
            if self.GenericReclaimLoop == 5 then
                coroutine.yield(1)
                self:LogDebug(string.format('GenericReclaimLoop hit 5 loops, exiting state machine'))
                self:ExitStateMachine()
                return
            end
            self:ChangeState(self.DecideWhatToDo)
            return
        end,
    },

    NavigateToLocation = State {
        StateName = 'NavigateToLocation',
        --- Refactored navigation logic integrating EngineerMoveWithSafePathRNG
        ---@param self AIPlatoonAdaptiveReclaimBehavior
        Main = function(self)
            local aiBrain = self:GetBrain()
            local eng = self.eng
            local builderData = self.BuilderData
            
            if not builderData or not builderData.Position then
                self:LogDebug('NavigateToLocation: No destination provided in BuilderData')
                self:ChangeState(self.DecideWhatToDo)
                return
            end

            local destination = builderData.Position
            local startPos = eng:GetPosition()
            
            -- 1. Path Generation & Transport Evaluation
            local canPath = NavUtils.CanPathTo(self.MovementLayer, startPos, destination)
            local navigateDist = VDist2Sq(startPos[1], startPos[3], destination[1], destination[3])
            local maxWalkTime = 180
            local minPlatoonSpeed = self['rngdata'].MinPlatoonSpeed or 1.9
            local walkDistThreshold = minPlatoonSpeed * maxWalkTime
            local walkDistThresholdSq = walkDistThreshold * walkDistThreshold
            local needsTransport = false

            -- Transport trigger: Unpathable or distance > 300 (threshold from original function)
            if not canPath  or navigateDist > (350 * 350) then
                needsTransport = true
            end

            -- 2. Transport Handling
            if needsTransport or navigateDist > walkDistThresholdSq then
                local transportType = canPath and 'Reclaim' or 'ReclaimNoPath'
                self:LogDebug('Requesting transport for navigation')
                eng['rngdata'].WaitingForTransport = true
                local requestId, requestData = StateUtils.RequestTransportRNG(self, destination, transportType)
                
                if requestId then
                    local estWait = (requestData and requestData.EstimatedWait) or 30
                    local walkTime = (math.sqrt(navigateDist) / (eng.Blueprint.Physics.MaxSpeed or 2.5))
                    --LOG('estWait '..tostring(estWait)..' walk time '..tostring(walkTime))
                    if not canPath or walkTime > estWait then
                        local timeout = 0
                        local maxWaitTime = math.max(estWait, 150)
                        local reclaimPerformed = false
                        while not eng.Dead and not eng:IsUnitState('Attached') and timeout < maxWaitTime do
                            if not reclaimPerformed and estWait > 20 then
                                reclaimPerformed = RUtils.PerformEngAreaReclaim(aiBrain, eng, 60)
                                reclaimPerformed = true
                            end
                            coroutine.yield(20)
                            local manager = aiBrain:GetPlatoonUniquelyNamed('TransportPool')
                            if manager and not manager:GetRequestById(requestId) then
                                LOG('Request ID is not present in the transport pool manager')
                                coroutine.yield(15)
                                local transport = self['rngdata'].AssignedTransport
                                if not transport or transport.Dead then
                                    -- Request disappeared but we aren't attached? Transport probably died.
                                    LOG('Request is no longer in manager and we are not attached, break')
                                    break
                                end
                            end
                            timeout = timeout + 2
                        end
                        eng['rngdata'].WaitingForTransport = false
                        
                        -- If we successfully used a transport, transition to check if we have a build queue or return to decision
                        if eng:IsUnitState('Attached') then
                            while not eng.Dead and (eng:IsUnitState('Attached') or eng:IsUnitState('TransportLoading')) do
                                coroutine.yield(20)
                            end
                            -- Post-drop check
                            coroutine.yield(10)
                            if eng.EngineerBuildQueue and table.getn(eng.EngineerBuildQueue) > 0 then
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
                                self:ChangeState(self.Constructing)
                            else
                                self:ChangeState(self.DecideWhatToDo)
                            end
                            return
                        else
                            if eng:IsUnitState('Building') then
                                self:ChangeState(self.Constructing)
                                return
                            end
                        end
                    end
                end
                eng['rngdata'].WaitingForTransport = false
                
                -- If transport failed and distance is extreme, abort
                if navigateDist > 409600 then -- 640 * 640
                    self:LogDebug('No transport and distance too great. Aborting.')
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
            end

            -- 3. Path Execution (Walking)
            if canPath then

                local path, reason, distance, threats  = AIAttackUtils.EngineerGenerateSafePathToRNG(aiBrain, self.MovementLayer, startPos, destination)

                IssueClearCommands({eng})
                if path then
                    local pathLength = table.getn(path)
                    for i = 1, pathLength do
                        IssueMove({eng}, path[i])
                    end
                else
                    if reason == 'TooMuchThreat' and table.getn(threats) > 0 then
                        self:LogDebug(string.format('Too much threat to travel'))
                        coroutine.yield(30)
                        self:ExitStateMachine()
                        return
                    end
                end
                IssueMove({eng}, destination)

                -- 4. The Monitoring Loop (Threat detection and Opportunistic Reclaim)
                local currentPathNode = 1
                local pathLength = path and table.getn(path) or 0
                local movementTimeout = 0
                local lastPos = eng:GetPosition()

                while not eng.Dead and aiBrain:PlatoonExists(self) do
                    local currentPos = eng:GetPosition()
                    local distToDestSq = VDist3Sq(currentPos, destination)

                    -- Arrival check
                    if distToDestSq < 100 then break end

                    -- Path node tracking
                    if path and currentPathNode <= pathLength then
                        local nodeDistSq = VDist3Sq(currentPos, path[currentPathNode])
                        if nodeDistSq < 64 or (currentPathNode + 1 <= pathLength and nodeDistSq > VDist3Sq(currentPos, path[currentPathNode+1])) then
                            currentPathNode = currentPathNode + 1
                        end
                    end
                    local actionTaken = false

                    -- Opportunistic Threat/Reclaim Logic (from original function)
                    local enemyUnits = aiBrain:GetUnitsAroundPoint(categories.LAND * categories.MOBILE + categories.MASSEXTRACTION, currentPos, 45, 'Enemy')
                    if not table.empty(enemyUnits) then
                        for _, enemy in enemyUnits do
                            if not enemy.Dead and enemy:GetFractionComplete() == 1 then
                                local enemyPos = enemy:GetPosition()
                                local enemyDistSq = VDist3Sq(currentPos, enemyPos)

                                -- Case A: Reclaimable weak units (Scouts/Engineers)
                                if EntityCategoryContains(categories.SCOUT + categories.ENGINEER - categories.COMMAND, enemy) then
                                    if enemyDistSq < 144 then
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, enemy)
                                        actionTaken = true
                                        -- Wait for reclaim to finish or unit to move away
                                        while not enemy.Dead and not eng.Dead and VDist3Sq(eng:GetPosition(), enemy:GetPosition()) < 169 do
                                            coroutine.yield(20)
                                        end
                                        break
                                    end
                                -- Case B: Dangerous Mobile Land
                                elseif EntityCategoryContains(categories.LAND * categories.MOBILE - categories.SCOUT, enemy) then
                                    if enemyDistSq < 100 then
                                        IssueClearCommands({eng})
                                        IssueReclaim({eng}, enemy) -- Last ditch effort
                                        actionTaken = true
                                        coroutine.yield(20)
                                        break
                                    else
                                        -- Avoidance maneuver
                                        IssueClearCommands({eng})
                                        IssueMove({eng}, RUtils.AvoidLocation(enemyPos, currentPos, 50))
                                        actionTaken = true
                                        coroutine.yield(40)
                                        break
                                    end
                                -- Case C: Capture enemy Mexes
                                elseif EntityCategoryContains(categories.MASSEXTRACTION, enemy) and enemyDistSq < 225 then
                                    IssueClearCommands({eng})
                                    IssueCapture({eng}, enemy)
                                    actionTaken = true
                                    while not enemy.Dead and not eng.Dead and enemy:GetAIBrain() ~= aiBrain do
                                        coroutine.yield(20)
                                    end
                                    break
                                end
                            end
                        end
                    end
                    actionTaken = RUtils.PerformEngReclaim(aiBrain, eng, 5)
                    if actionTaken then
                        IssueClearCommands({eng})
                        if path then
                            for i = currentPathNode, pathLength do
                                IssueMove({eng}, path[i])
                            end
                        end
                        IssueMove({eng}, destination)
                    end

                    

                    if IsDestroyed(eng) then
                        return
                    end
                    if eng:IsIdleState() then
                        movementTimeout = movementTimeout + 1
                        if movementTimeout > 10 then 
                            self:LogDebug('Navigation timeout: Unit idle too long')
                            break 
                        end
                    else
                        movementTimeout = 0
                    end

                    coroutine.yield(15)
                end
            end

            self:ChangeState(self.DecideWhatToDo)
        end,
    },

    WaitingForTransport = State {

        StateName = "WaitingForTransport",

        Main = function(self, data)
            local eng = self.eng
            if not eng or eng.Dead then return end
            --LOG('Engineer has moved into a WaitingForTransport State')
            self:LogDebug(string.format('Engineer has entered  WaitingForTransport  state'))

            -- 1. THE HALT
            -- We do NOT IssueClearCommands here if we have a build queue!
            -- Instead, we just IssueStop to kill current movement.
            IssueClearCommands({eng})
            self:LogDebug(string.format('Engineer has issued  a stop'))
            local transportPlatoon = self['rngdata'].AssignedTransport
            if not transportPlatoon then
                self:LogDebug(string.format('transportPlatoon is nil'))
            end
            -- 2. THE IDLE LOOP
            while not IsDestroyed(self) and not eng.Dead do
                self:LogDebug(string.format('Engineer is waiting inside the idle loop'))
                -- If we are attached, we just wait to be dropped
                if not transportPlatoon or transportPlatoon.Dead then
                    self:ChangeState(self.DecideWhatToDo)
                    return
                end
                if eng:IsUnitState('Attached') then
                    coroutine.yield(40)
                elseif eng:IsUnitState('TransportLoading') then
                    coroutine.yield(10)
                else
                    -- Optional: Nudge toward the transport if it's landing nearby
                    if eng:IsUnitState('Building') then
                        self:ChangeState(self.Constructing)
                        return
                    end
                    self:LogDebug(string.format('Engineer is something else inside the idle loop '..tostring(eng.EntityId)))
                    -- If the transport is lost, resume whatever we were doing
                    if not transportPlatoon or transportPlatoon.Dead then
                        self:LogDebug(string.format('Engineer considered the transport lost or maybe its already returned to the manage pool'))
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                    if eng:IsIdleState() and self['rngdata'].TransportUnloaded then
                        self['rngdata'].TransportUnloaded = false
                        self:ChangeState(self.DecideWhatToDo)
                        return
                    end
                end
                coroutine.yield(20)
            end
            self:LogDebug(string.format('Engineer is exiting WaitingForTransport state'))
            self['rngdata'].AssignedTransport =  nil
            self:ChangeState(self.DecideWhatToDo)
            return
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
                    eng.BuildFailedCount = 0
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
