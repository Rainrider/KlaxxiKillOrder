local addon, ns = ...

local Debug = function() end

local KLAXXI_ENCOUNTER_ID = 1593

local klaxxiBosses = {
	[71158] = 1, -- Rik'kal the Dissector
	[71152] = 2, -- Skeer the Bloodseeker
	[71155] = 3, -- Korven the Prime
	[71153] = 4, -- Hisek the Swarmkeeper
	[71154] = 5, -- Ka'roz the Locust
	[71157] = 6, -- Xaril the Poisoned Mind
	[71160] = 7, -- Iyyokuk the Lucid
	[71156] = 8, -- Kaz'tik the Manipulator
	[71161] = 9, -- Kil'ruk the Wind-Reaver
}

local klaxxiPriorities = {
	-- boss1, boss2, boss3, skull, cross
	--[[
		example:
			{1, 2, 4, 1, 2}
		bosses active:
			1, 2 and 4 (Rik'kal, Skeer and Hisek)
		skull target:
			1 (Rik'kal)
		cross target:
			2 (Skeer)
	--]]
	["nhc"] = {
		{1, 2, 4, 1, 2},
		{2, 4, 5, 2, 3},
		{3, 4, 5, 3, 4},
		{4, 5, 7, 4, 5},
		{5, 6, 7, 5, 6},
		{6, 7, 8, 6, 7},
		{7, 8, 9, 7, 8},
		{8, 9, 0, 8, 9},
		{9, 0, 0, 9, 0},
  	},
	["hc"] = {
		{1, 2, 4, 2, 1}, -- 1
		{1, 4, 5, 1, 3}, -- 2
		{3, 4, 5, 3, 4}, -- 3
		{4, 5, 7, 4, 6}, -- 4
		{5, 6, 7, 6, 8}, -- 5
		{5, 7, 8, 8, 7}, -- 6
		{5, 7, 9, 7, 5}, -- 7
		{5, 9, 0, 5, 9}, -- 8
		{9, 0, 0, 9, 0}, -- 9
	},
}

local priorities = {}

local GetNummericGUID

local MarkBoss = function(i, rtID)
	local unit = "boss" .. i
	if GetRaidTargetIndex(unit) ~= rtID then
		SetRaidTarget(unit, rtID)
		Debug("Marked", UnitName(unit), string.format("\124TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:0\124t", rtID))
	end
end

local frame = CreateFrame("Frame", addon, UIParent)
frame:SetScript("OnEvent", function(self, event, ...) self[event](self, ...) end)
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("ENCOUNTER_START")

local Command = function(msg)
	local _, _, difficultyID, _, _, _, _, instanceMapID = GetInstanceInfo()
	if instanceMapID == 1136 then
		frame:ENCOUNTER_START(KLAXXI_ENCOUNTER_ID, nil, difficultyID)
	end
end

function frame:ADDON_LOADED(name)
	if name ~= addon then return end

	SLASH_KlaxxiKillOrder1 = "/kko"
	SLASH_KlaxxiKillOrder2 = "/klaxxikillorder"
	SlashCmdList[name] = Command

	if AdiDebug then
		Debug = AdiDebug:Embed(self, name)
	end
	local toc = select(4, GetBuildInfo())
	if toc < 60000 then
		GetNummericGUID = function(unit)
			return tonumber(string.sub(UnitGUID(unit), 6, 10), 16)
		end
	else
		GetNummericGUID = function(unit)
			return (select(6, strsplit("-", UnitGUID(unit))))
		end
	end

	self:UnregisterEvent("ADDON_LOADED")
end

function frame:ENCOUNTER_START(encounterID, _, difficultyID)
	if encounterID ~= KLAXXI_ENCOUNTER_ID then return end

	local _, _, isHeroic = GetDifficultyInfo(difficultyID)
	priorities = isHeroic and klaxxiPriorities["hc"] or klaxxiPriorities["nhc"]

	Debug("ENCOUNTER_START", encounterID, difficultyID, isHeroic)

	self:RegisterEvent("ENCOUNTER_END")
	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
end

function frame:ENCOUNTER_END()
	self:UnregisterEvent("ENCOUNTER_END")
	self:UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
end

function frame:INSTANCE_ENCOUNTER_ENGAGE_UNIT()
	Debug("INSTANCE_ENCOUNTER_ENGAGE_UNIT")

	local activeBosses = {}

	-- the klaxxi encounter has only 4 boss frames
	-- the 4th boss frame shows who joins the fight next
	for i = 1, 4 do
		local unit = "boss" .. i
		if UnitExists(unit) then
			activeBosses[klaxxiBosses[GetNummericGUID(unit)]] = i
			Debug("Boss", i, (UnitName(unit)))
		end
	end

	local match
	for i = 1, #priorities do
		local boss1, boss2, boss3, skull, cross = unpack(priorities[i])
		if activeBosses[boss1] and (boss2 == 0 or activeBosses[boss2]) and (boss3 == 0 or activeBosses[boss3]) then
			MarkBoss(activeBosses[skull], 8)
			if cross ~= 0 then
				MarkBoss(activeBosses[cross], 7)
			end
			match = i
			break
		end
	end
	Debug("Matched priorities:", match)
end
