--[[ Handles Lists of Units
 * Create as a list of unit with some functions.
 * Can get total unit cost, a random unit, units in area etc..
 * Elements can have custom data.
--]]

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitLosState = Spring.GetUnitLosState

local UnitListHandler = {}

local function DisSQ(x1,z1,x2,z2)
	return (x1 - x2)^2 + (z1 - z2)^2
end

local function InternalGetUnitPosition(data, static, losCheckAllyTeamID)
	if static then
		if data.x then
			return data.x, data.y, data.z
		else
			local x,y,z = spGetUnitPosition(data.unitID)
			data.x = x
			data.y = y
			data.z = z
			return x, y, z
		end
	end
	if losCheckAllyTeamID then
		local los = spGetUnitLosState(data.unitID, losCheckAllyTeamID, false)
		if los and (los.los or los.radar) and los.typed then
			local x,y,z = spGetUnitPosition(data.unitID)
			return x, y, z
		end
	else
		local x,y,z = spGetUnitPosition(data.unitID)
		return x, y, z
	end
	return false
end

function UnitListHandler.CreateUnitList(losCheckAllyTeamID, static)
	-- static is whether the unit list only contains stationary units
	local unitMap = {}
	local unitList = {}
	local unitCount = 0
	local totalCost = 0
	
	-- Indiviual Unit Position Functions
	function GetUnitPosition(unitID)
		if unitMap[unitID] then
			local index = unitMap[unitID]
			return InternalGetUnitPosition(unitList[index], static, losCheckAllyTeamID)
		end
	end
	
	function HasUnitMoved(unitID, range)
		if static or not unitMap[unitID] then
			return false
		end
		local index = unitMap[unitID]
		local data = unitList[index]
		local x,_,z = InternalGetUnitPosition(data, static, losCheckAllyTeamID)
		if x then
			if not data.oldX then
				data.oldX = x
				data.oldZ = z
				return true
			end
			if DisSQ(x,z,data.oldX,data.oldZ) > range^2 then
				data.oldX = x
				data.oldZ = z
				return true
			end
			return false
		end
		return true
	end
	
	-- Position checks over all units in the list
	function GetNearestUnit(x,z,condition)
		local minDisSq = false
		local closeID = false
		local closeX = false
		local closeZ = false
		for i = 1, unitCount do
			local data = unitList[i]
			local ux,_,uz = InternalGetUnitPosition(data, static, losCheckAllyTeamID)
			if ux and condition and condition(data.unitID, ux, uz, data.customData, data.cost) then
				local thisDisSq = DisSQ(x,z,ux,uz)
				if not minDisSq or minDisSq > thisDisSq then
					minDisSq = thisDisSq
					closeID = data.unitID
					closeX = x
					closeZ = z
				end
			end
		end
		return closeID, closeX, closeZ
	end
	
	function IsPositionNearUnit(x, z, radius, condition)
		local radiusSq = radius^2
		for i = 1, unitCount do
			local data = unitList[i]
			local ux,_,uz = InternalGetUnitPosition(data, static, losCheckAllyTeamID)
			if ux and condition and condition(data.unitID, ux, uz, data.customData, data.cost) then
				local thisDisSq = DisSQ(x,z,ux,uz)
				if thisDisSq < radiusSq then
					return true
				end
			end
		end
		return false
	end
	
	-- Unit cust data handling
	function OverwriteUnitData(unitID, newData)
		if unitMap[unitID] then
			local index = unitMap[unitID]
			unitList[index].customData = newData
		end
	end
	
	function GetUnitData(unitID)
		-- returns a table but don't edit it!
		if unitMap[unitID] then
			local index = unitMap[unitID]
			return unitList[index].customData or {}
		end
	end
	
	function SetUnitDataValue(unitID, key, value)
		if unitMap[unitID] then
			local index = unitMap[unitID]
			if not unitList[index].customData then
				unitList[index].customData = {}
			end
			unitList[index].customData[key] = value
		end
	end
	
	-- Unit addition and removal handling
	function AddUnit(unitID, cost, newData)
		if unitMap[unitID] then
			if newData then 
				OverwriteUnitData(unitID, newData)
			end
			return false
		end
		
		cost = cost or 0
		
		-- Add unit to list
		unitCount = unitCount + 1
		unitList[unitCount] = {
			unitID = unitID,
			cost = cost,
			customData = newData,
		}
		unitMap[unitID] = unitCount
		totalCost = totalCost + cost
		return true
	end
	
	function RemoveUnit(unitID)
		if unitMap[unitID] then
			local index = unitMap[unitID]
			
			totalCost = totalCost - unitList[index].cost

			-- Copy the end of the list to this index
			unitList[index] = unitList[unitCount]
			unitMap[unitList[index].unitID] = index
			
			-- Remove the end of the list
			unitList[unitCount] = nil
			unitCount = unitCount - 1
			unitMap[unitID] = nil
			return true
		end
		return false
	end
	
	function ValidUnitID(unitID)
		return (unitMap[unitID] and true) or false
	end
	
	-- Cost Handling
	function GetUnitCost(unitID)
		if unitMap[unitID] then
			local index = unitMap[unitID]
			return unitList[index].cost
		end
	end
	
	function GetTotalCost()
		return totalCost
	end
	
	-- To use Iterator, write "for unitID, data in unitList.Iterator() do"
	function Iterator()
		local i = 0
		return function ()
			i = i + 1
			if i <= unitCount then 
				return unitList[i].unitID, unitList[i].customData 
			end
		end
	end
	
	local newUnitList = {
		GetUnitPosition = GetUnitPosition,
		GetNearestUnit = GetNearestUnit,
		HasUnitMoved = HasUnitMoved,
		IsPositionNearUnit = IsPositionNearUnit,
		OverwriteUnitData = OverwriteUnitData,
		GetUnitData = GetUnitData,
		SetUnitDataValue = SetUnitDataValue,
		AddUnit = AddUnit,
		RemoveUnit = RemoveUnit,
		GetUnitCost = GetUnitCost,
		GetTotalCost = GetTotalCost,
		ValidUnitID = ValidUnitID,
		Iterator = Iterator,
	}
	
	return newUnitList
end
	
return UnitListHandler