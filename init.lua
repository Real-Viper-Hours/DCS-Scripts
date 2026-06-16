--[[ 
RVH Core Init
DCS Mission Scripting Framework
]]--

RVH = RVH or {}

--[[ 
Print message to the logs file. See C:\Users\USERNAME\Saved Games\DCS\Logs\dcs.log

Parameters:
    STRING msg

Returns:
    None
]]--
function RVH.log(msg)
    env.info("[RVH] " .. msg)
end


--[[ 
Print message to all users in the top right corner of the screen.
Message remains on screen for the given duration.

Parameters:
    STRING msg
    DOUBLE duration

Returns:
    None
]]--
function RVH.hint(msg, duration)
    duration = duration or 0
    trigger.action.outText("[RVH] " .. msg, duration)
end


--[[ 
Print message to the logs file and to all users' screens.
Message remains on screen for the given duration.

Parameters:
    DOUBLE duration

Returns:
    None
]]--
function RVH.logHint(msg, duration)
    RVH.log(msg)
    RVH.hint(msg, duration)
end


--[[ 
Of a set of groups delete all but one with each group having equal probablity of being picked.

Parameters:
    ARRAY groupNames  

Returns:
    STRING winner.name: Group name of selected group
]]--
function RVH.selectRandomGroup(groupNames)

    if type(groupNames) ~= "table" then
        RVH.log("ERROR: Expected table of group names")
        return nil
    end

    local groups = {}

    for _, name in ipairs(groupNames) do
        local g = Group.getByName(name)
        if g then
            table.insert(groups, { name = name, group = g })
        else
            RVH.log("ERROR: Group not found: " .. tostring(name))
        end
    end

    if #groups == 0 then
        RVH.log("ERROR: No valid groups found")
        return nil
    end

    local winnerIndex = math.random(1, #groups)
    local winner = groups[winnerIndex]

    --RVH.log("Group selected: " .. winner.name)

    for i = 1, #groups do
        if i ~= winnerIndex then
            groups[i].group:destroy()
            --RVH.log("Group deleted: " .. groups[i].name)
        end
    end

    return winner.name
end


--[[ 
Of a set of groups delete all but one with each groups' probablity of being picked based on the given weights.

Example input:
local groups = {
    { name = "SA2", weight = 100 },
    { name = "SA3", weight = 200 },
    { name = "SA6", weight = 100 }
}

Giving the probabilities:
P(SA2) = 25%
P(SA3) = 50%
P(SA6) = 25%

Parameters:
    MAP weightedGroups

Returns:
    STRING winner.name: Group name of selected group
]]--
function RVH.selectRandomGroupWeighted(weightedGroups)

    if type(weightedGroups) ~= "table" then
        RVH.log("ERROR: Expected table")
        return nil
    end

    local pool = {}
    local totalWeight = 0

    for _, entry in ipairs(weightedGroups) do

        if type(entry) ~= "table" then
            RVH.log("ERROR: Invalid entry (not table)")
            goto continue
        end

        local name = entry.name
        local weight = entry.weight or 1

        if type(name) ~= "string" then
            RVH.log("ERROR: Missing/invalid group name")
            goto continue
        end

        if type(weight) ~= "number" then
            RVH.log("ERROR: Invalid weight for " .. name)
            weight = 1
        end

        if weight < 0 then
            RVH.log("ERROR: Negative weight for " .. name)
            weight = 0
        end

        local g = Group.getByName(name)

        if g then
            totalWeight = totalWeight + weight

            table.insert(pool, {
                name = name,
                group = g,
                cumulative = totalWeight
            })
        else
            RVH.log("ERROR: Group not found: " .. tostring(name))
        end

        ::continue::
    end

    if #pool == 0 then
        RVH.log("ERROR: No valid groups found")
        return nil
    end

    if totalWeight <= 0 then
        RVH.log("ERROR: Total weight <= 0")
        return nil
    end

    local roll = math.random() * totalWeight
    local winner

    for _, entry in ipairs(pool) do
        if roll <= entry.cumulative then
            winner = entry
            break
        end
    end

    winner = winner or pool[#pool]

    RVH.log("Group selected: " .. winner.name)

    for _, entry in ipairs(pool) do
        if entry.name ~= winner.name then
            entry.group:destroy()
            --RVH.log("Group deleted: " .. entry.name)
        end
    end

    return winner.name
end


--[[ 
Delete the given group by its name such as 'Aerial-1'

Parameters:
    STRING groupName

Returns:
    BOOL
]]--
function RVH.deleteGroupByName(groupName)

    local group = Group.getByName(groupName)

    if not group then
        RVH.log("ERROR: Group not found: " .. tostring(groupName))
        return false
    end

    group:destroy()

    --RVH.log("Group deleted: " .. groupName)

    return true
end


--[[ 
Delete the given unit by its name such as 'Aerial-1-1'

Parameters:
    STRING unitName

Returns:
    BOOL
]]--
function RVH.deleteUnitByName(unitName)

    local unit = Unit.getByName(unitName)

    if not unit then
        RVH.log("ERROR: Unit not found: " .. tostring(unitName))
        return false
    end

    unit:destroy()

    return true
end


--[[ 
For the given group jumps the given waypoint index to the provided number.
If the group was at steerpoint 2 and the function is called to skip to 5.
1 -> 2 -> 5 -> 6 -> 7 ...    

Waypoint indexing note:
DCS appears to require +1 offset for correct selection in SwitchWaypoint, this is accounted for in the function.

Parameters:
    STRING groupName
    DOUBLE waypointIndex

Returns:
    BOOL
]]--
function RVH.skipToWaypoint(groupName, waypointIndex)

    waypointIndex = waypointIndex + 1

    local group = Group.getByName(groupName)

    if not group then
        RVH.log("ERROR: Group not found: " .. tostring(groupName))
        return false
    end

    local controller = group:getController()

    if not controller then
        RVH.log("ERROR: No controller for group: " .. groupName)
        return false
    end

    controller:setCommand({
        id = "SwitchWaypoint",
        params = {
            fromWaypointIndex = 1,
            goToWaypointIndex = waypointIndex
        }
    })

    return true
end


--[[ 
Returns distance between two points.
Note this is a 2 dimensional calculation which does not consider altitude.

Parameters:
    3DVECTOR p1
    3DVECTOR p2

Returns:
    DOUBLE
]]--
function RVH.getDistanceMeters(p1, p2)
    local dx = p1.x - p2.x
    local dz = p1.z - p2.z
    return math.sqrt(dx * dx + dz * dz)
end


--[[ 
When called selects the group of the first fixed-wing aircraft detected in the given zone,
then assigns the given interceptor group the task of engaging said group.

Note this only detects fixed-wing aircraft.
Note sides are coalition.side.BLUE/RED/NEUTRAL

Example Use:
One time use trigger: PART OF COALITION IN ZONE: AIRPLANE: { RVH.assignBaseDefenseIntercept("InterceptZone", coalition.side.BLUE, "Aerial-9"); }

Parameters:
    STRING zoneName: Name of Trigger Zone 
    SIDE enemySide
    STRING interceptorGroupName

Returns:
    BOOL
]]--
function RVH.assignBaseDefenseIntercept(zoneName, enemySide, interceptorGroupName)

    local zone = trigger.misc.getZone(zoneName)
    if not zone then
        RVH.log("Zone not found: " .. tostring(zoneName))
        return false
    end

    local center = zone.point
    local radius = zone.radius

    local groups = coalition.getGroups(enemySide, Group.Category.AIRPLANE)

    for _, enemyGroup in ipairs(groups) do

        if enemyGroup and enemyGroup:isExist() then

            local pos

            for _, unit in ipairs(enemyGroup:getUnits()) do
                if unit and unit:isExist() then
                    pos = unit:getPoint()
                    break
                end
            end

            if pos then

                local dist = RVH.getDistanceMeters(pos, center)

                if dist <= radius * 1.1 then

                    local interceptor = Group.getByName(interceptorGroupName)

                    if interceptor and interceptor:isExist() then

                        local controller = interceptor:getController()

                        controller:setTask({
                            id = "EngageGroup",
                            params = {
                                groupId = enemyGroup:getID()
                            }
                        })

                        RVH.log(interceptorGroupName ..
                            " intercepting " .. enemyGroup:getName())

                        return true
                    else
                        RVH.log("ERROR: Interceptor not found: " .. tostring(interceptorGroupName))
                    end
                end
            end
        end
    end

    return false
end


function RVH.disableAllATC()
    for _, airbase in pairs(world.getAirbases()) do
        if airbase then
            airbase:setRadioSilentMode(true)
        end
    end
end


function RVH.enableAllATC()
    for _, airbase in pairs(world.getAirbases()) do
        if airbase then
            airbase:setRadioSilentMode(false)
        end
    end
end

--[[
timer.scheduleFunction(function()
    RVH.disableAllATC();
end, nil, timer.getTime() + 1)
]]--