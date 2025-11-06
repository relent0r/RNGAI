-- Function to calculate the average position of a group of players
function calculateAveragePosition(players)
    local totalX, totalY = 0, 0
    for _, player in ipairs(players) do
        totalX = totalX + player.x
        totalY = totalY + player.y
    end
    local averageX = totalX / #players
    local averageY = totalY / #players
    return {x = averageX, y = averageY}
end

-- Function to find the midpoint between two points
function findMidpoint(point1, point2)
    local midX = (point1.x + point2.x) / 2
    local midY = (point1.y + point2.y) / 2
    return {x = midX, y = midY}
end

-- Function to generate a line of positions between two points
function generateLineOfPositions(point1, point2, numPositions)
    local line = {}
    local dx = (point2.x - point1.x) / numPositions
    local dy = (point2.y - point1.y) / numPositions
    for i = 1, numPositions do
        local newX = point1.x + dx * i
        local newY = point1.y + dy * i
        table.insert(line, {x = newX, y = newY})
    end
    return line
end

-- Example usage
-- Define player positions (replace these with your actual player positions)
local team1Players = {{x = 10, y = 20}, {x = 15, y = 25}, {x = 20, y = 30}}
local team2Players = {{x = 30, y = 40}, {x = 35, y = 45}, {x = 40, y = 50}}

-- Calculate average positions of each team
local averagePositionTeam1 = calculateAveragePosition(team1Players)
local averagePositionTeam2 = calculateAveragePosition(team2Players)

-- Find the midpoint between the two teams
local midpoint = findMidpoint(averagePositionTeam1, averagePositionTeam2)

-- Generate a line of positions between the two midpoints
local lineOfPositions = generateLineOfPositions(averagePositionTeam1, averagePositionTeam2, 5)

-- Print the results
print("Midpoint:", midpoint.x, midpoint.y)
print("Line of positions:")
for i, position in ipairs(lineOfPositions) do
    print("Position", i, ":", position.x, position.y)
end

-- Function to determine which side of the line a point lies on
function determineSideOfLine(point, lineStart, lineEnd)
    local crossProduct = (point.x - lineStart.x) * (lineEnd.y - lineStart.y) - (point.y - lineStart.y) * (lineEnd.x - lineStart.x)
    if crossProduct > 0 then
        return "green" -- Point is on the green side of the line
    elseif crossProduct < 0 then
        return "red" -- Point is on the red side of the line
    else
        return "on the line" -- Point is exactly on the line
    end
end

-- Example usage
-- Define the line between the two midpoints
local lineStart = averagePositionTeam1
local lineEnd = averagePositionTeam2

-- Determine which side of the line a point is on
local testPoint = {x = 25, y = 35} -- Example test point, replace with your actual point
local side = determineSideOfLine(testPoint, lineStart, lineEnd)

-- Print the result
print("Test point is on the:", side, "side of the line")

-- This required reintegration
local distressLocation = aiBrain:BaseMonitorDistressLocationRNG(position, distressRange, aiBrain.BaseMonitor.PoolDistressThreshold, 'Land')

function Testrallypointpositions(pos)
    LOG('Land Factory')
    local rallyPointOptions = NavUtils.DirectionsFrom('Land', factoryPos, 30)
    local fx = factoryPos[1] - opponentStart[1]
    local fz = factoryPos[3] - opponentStart[3]
    local factoryDistance = fx * fx + fz * fz
    for _, v in rallyPointOptions do
        local rx = v[1] - opponentStart[1]
        local rz = v[3] - opponentStart[3]
        local rallyDistance = rx * rx + rz * rz
        local frx = v[1] - factoryPos[1]
        local frz = v[3] - factoryPos[3]
        local rallyFactoryPosDistance = frx * frx + frz * frz
        if rallyFactoryPosDistance > 64 and rallyFactoryPosDistance < 60 * 60 and rallyDistance < factoryDistance and self.Brain:GetNumUnitsAroundPoint(categories.STRUCTURE, v, 8, 'Ally') < 1 then
            LOG('Found point at distance of '..math.sqrt(rallyFactoryPosDistance))
            position = v
            break
        end
    end
    --RNGLOG('Air Rally Position is :'..repr(position))
end

function RNGUtils.SelectBestHighValueUnit(aiBrain, blueprints)
    if not blueprints or table.getn(blueprints) == 0 then
        return nil
    end

    -- If only one choice, return it directly
    if table.getn(blueprints) == 1 then
        return blueprints[1]
    end

    local context = aiBrain.StrategicContext.HighValuePreferences or {}
    local bestUnit = nil
    local bestScore = -math.huge

    for _, bpId in blueprints do
        local bp = __blueprints[bpId]
        local score = 0

        -- Unit classification
        if EntityCategoryContains(categories.AIR, bp.BlueprintId) then
            score = score + (context.Air or 0)
        elseif EntityCategoryContains(categories.LAND, bp.BlueprintId) then
            score = score + (context.Land or 0)
        elseif EntityCategoryContains(categories.NAVAL, bp.BlueprintId) then
            score = score + (context.Naval or 0)
        elseif EntityCategoryContains(categories.NUKE, bp.BlueprintId) then
            score = score + (context.Nuke or 0)
        elseif EntityCategoryContains(categories.ARTILLERY, bp.BlueprintId) then
            score = score + (context.Artillery or 0)
        end

        -- Bonus: take into account known traits
        if bp.Economy.BuildCostMass then
            score = score + math.min(bp.Economy.BuildCostMass / 10000, 1.0)
        end
        if bp.Weapon and bp.Weapon[1] and bp.Weapon[1].MaxRadius then
            score = score + (bp.Weapon[1].MaxRadius / 1000)
        end

        if score > bestScore then
            bestScore = score
            bestUnit = bpId
        end
    end

    return bestUnit
end

function RNGUtils.EvaluateStrategicContext_Global(aiBrain)
    local ctx = {
        Air = 0.5,
        Land = 0.5,
        Naval = 0.5,
        Artillery = 0.5,
        Nuke = 0.5,
    }

    local E = aiBrain.EnemyIntel.EnemyThreatCurrent
    local S = aiBrain.BrainIntel.SelfThreat

    -- Safety ratio helper
    local function ThreatRatio(selfThreat, enemyThreat)
        return (selfThreat + 1) / (enemyThreat + 1)
    end

    -- Air context: compare our air & AA vs their air & AA
    local airOffenseRatio = ThreatRatio(S.AirNow, E.Air)
    local airDefenseRatio = ThreatRatio(S.AntiAirNow, E.AirSurface + E.AirAntiNavy + E.Air)
    local airBalance = (airOffenseRatio + airDefenseRatio) * 0.5

    if airBalance > 1.3 then
        ctx.Air = 0.8
    elseif airBalance > 0.8 then
        ctx.Air = 0.6
    else
        ctx.Air = 0.3
    end

    -- Land context: direct comparison
    local landBalance = ThreatRatio(S.LandNow, E.Land)
    if landBalance > 1.3 then
        ctx.Land = 0.8
    elseif landBalance > 0.8 then
        ctx.Land = 0.6
    else
        ctx.Land = 0.3
    end

    -- Naval context: surface and sub combined
    local navalBalance = ThreatRatio(S.NavalNow + S.NavalSubNow, E.Naval + E.NavalSub)
    if navalBalance > 1.3 then
        ctx.Naval = 0.8
    elseif navalBalance > 0.8 then
        ctx.Naval = 0.6
    else
        ctx.Naval = 0.3
    end

    -- Artillery context: encourage if enemy has high static defense
    local staticDefense = E.DefenseSurface + E.DefenseAir + E.DefenseSub
    local defenseRatio = staticDefense / (S.LandNow + 1)
    if defenseRatio > 1.2 then
        ctx.Artillery = 0.8
    elseif defenseRatio > 0.8 then
        ctx.Artillery = 0.6
    else
        ctx.Artillery = 0.4
    end

    -- Nuke context: fallback if stalemate
    local globalStalemate = (ctx.Land < 0.4 and ctx.Naval < 0.4)
    if globalStalemate then
        ctx.Nuke = 0.7
    elseif defenseRatio > 1.0 then
        ctx.Nuke = 0.6
    else
        ctx.Nuke = 0.4
    end

    aiBrain.StrategicContext = aiBrain.StrategicContext or {}
    aiBrain.StrategicContext.Global = ctx
end

