--[[
	PrivateAuras indicator preview (Highlight Indicator / test mode)

	This feature is intentionally isolated in its own file so it can be removed
	or not loaded to disable the preview behavior entirely.
]]--

local Grid2 = Grid2
local Grid2Frame = Grid2Frame
local CreateFrame = CreateFrame
local GetTime = GetTime
local STANDARD_TEXT_FONT = STANDARD_TEXT_FONT
local InCombatLockdown = InCombatLockdown

local ceil = math.ceil
local floor = math.floor
local max = math.max
local min = math.min
local random = math.random

local function HideTestModeAuras(f)
	local testAuras = f and f.testAuras
	if testAuras then
		for i = 1, #testAuras do
			local aura = testAuras[i]
			if aura then
				if aura.icon then aura.icon:Hide() end
				if aura.cooldown then aura.cooldown:Hide() end
				if aura.stackText then aura.stackText:Hide() end
			end
		end
	end
end

local function SetPreviewTexCoord(texture)
	if Grid2Frame.db.shared and Grid2Frame.db.shared.displayZoomedIcons then
		texture:SetTexCoord(0.05, 0.95, 0.05, 0.95)
	else
		texture:SetTexCoord(0, 1, 0, 1)
	end
end

local previewTextures = {
	[[Interface\Icons\ability_warlock_soulswap]],
	[[Interface\Icons\inv_cosmicvoid_groundsate]],
	[[Interface\Icons\spell_holy_holybolt]],
	[[Interface\Icons\Ability_Paladin_BeaconofLight]],
	[[Interface\Icons\ability_shootwand]],
	[[Interface\Icons\Spell_Nature_Regeneration]],
}

local function ShuffleTextures(textureList)
	for i = #textureList, 2, -1 do
		local j = random(1, i)
		textureList[i], textureList[j] = textureList[j], textureList[i]
	end
end

local function BuildShuffledTextureOrder(iconCount)
	local order, pool = {}, {}
	for i = 1, #previewTextures do
		pool[i] = previewTextures[i]
	end
	if #pool == 0 then return order end
	ShuffleTextures(pool)
	for i = 1, iconCount do
		local idx = ((i - 1) % #pool) + 1
		order[i] = pool[idx]
		if idx == #pool and i < iconCount then
			ShuffleTextures(pool)
		end
	end
	return order
end

local function ClearPreviewFrames(f)
	local previewFrames = f.previewFrames
	if previewFrames then
		for i = 1, #previewFrames do
			local preview = previewFrames[i]
			if preview then
				preview:Hide()
				if preview.cooldown then preview.cooldown:Hide() end
				if preview.durationText then preview.durationText:Hide() end
				if preview.stackText then preview.stackText:Hide() end
				preview:SetScript("OnUpdate", nil)
			end
		end
	end
end

local function ReflowPreviewFrames(f, iconSize)
	local previewFrames = f.previewFrames
	local auraFrames = f.auraFrames
	if not previewFrames or not auraFrames then return end
	local writeIndex = 1
	for i = 1, #previewFrames do
		local preview = previewFrames[i]
		if preview and preview:IsShown() then
			local auraFrame = auraFrames[writeIndex]
			if auraFrame then
				preview:ClearAllPoints()
				preview:SetPoint("CENTER", auraFrame, "CENTER")
				preview:SetSize(iconSize, iconSize)
				preview:SetFrameLevel(auraFrame:GetFrameLevel() + 10)
				preview:SetFrameStrata(auraFrame:GetFrameStrata())
			end
			writeIndex = writeIndex + 1
		end
	end
end

local function CreatePreviewFrame(parentFrame)
	local preview = CreateFrame("Frame", nil, parentFrame)
	preview.icon = preview:CreateTexture(nil, "ARTWORK")
	preview.icon:SetAllPoints()
	preview.cooldown = CreateFrame("Cooldown", nil, preview, "CooldownFrameTemplate")
	preview.cooldown:SetAllPoints()
	preview.cooldown:SetDrawEdge(true)
	preview.cooldown:SetDrawSwipe(true)
	preview.cooldown:SetReverse(true)
	preview.cooldown:SetHideCountdownNumbers(false)
	preview.coolText = preview.cooldown:GetCountdownFontString()

	preview.durationText = preview:CreateFontString(nil, "OVERLAY")
	preview.durationText:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
	preview.durationText:SetTextColor(1, 1, 1, 1)
	preview.durationText:Hide()

	preview.stackText = preview:CreateFontString(nil, "OVERLAY")
	preview.stackText:SetFont(STANDARD_TEXT_FONT, 8, "OUTLINE")
	preview.stackText:SetTextColor(1, 1, 1, 1)
	preview.stackText:Hide()

	return preview
end

local function ApplyPreviewRuntimeOptions(frame, iconSize)
	local indicator = frame._indicator
	if not indicator then return end

	local dbx = indicator.dbx
	local showCooldown = not (dbx and dbx.disableCooldown)
	local showCoolText = not (dbx and dbx.disableCooldownNumbers)
	local showStack = showCooldown and showCoolText

	if frame.cooldown then
		if showCooldown ~= frame._previewShowCooldown then
			frame._previewShowCooldown = showCooldown
			if showCooldown then
				frame.cooldown:SetCooldown(frame._durationStart, frame._duration)
				frame.cooldown:SetDrawSwipe(true)
				frame.cooldown:SetDrawEdge(true)
				frame.cooldown:SetReverse(true)
				frame.cooldown:Show()
			else
				frame.cooldown:Hide()
			end
		end
		if showCooldown then
			if showCoolText ~= frame._previewShowCoolText then
				frame._previewShowCoolText = showCoolText
				frame.cooldown:SetHideCountdownNumbers(not showCoolText)
				if showCoolText and frame.coolText and iconSize then
					local fontSize = iconSize < 1 and 10 or max(9, floor(iconSize * 0.42))
					frame.coolText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
					frame.coolText:SetTextColor(1, 1, 1, 1)
					frame.coolText:ClearAllPoints()
					frame.coolText:SetPoint("CENTER", frame.cooldown, "CENTER", 0, 0)
				end
			end
		end
	end

	local durationAnchor = indicator.auraAnchor and indicator.auraAnchor.durationAnchor
	local showDuration = not not durationAnchor
	if frame.durationText then
		if showDuration ~= frame._previewShowDuration then
			frame._previewShowDuration = showDuration
			if not showDuration then
				frame.durationText:Hide()
			end
		end
		if showDuration then
			local rp = durationAnchor.relativePoint or "CENTER"
			local p = durationAnchor.point or "CENTER"
			local ox = durationAnchor.offsetX or 0
			local oy = durationAnchor.offsetY or 0
			local sig = p .. "|" .. rp .. "|" .. tostring(ox) .. "|" .. tostring(oy)
			if sig ~= frame._previewDurationSig then
				frame._previewDurationSig = sig
				frame.durationText:ClearAllPoints()
				frame.durationText:SetPoint(p, frame, rp, ox, oy)
			end
			local timerFontSize = frame._timerFontSize
				or (iconSize and (iconSize < 1 and 10 or max(9, floor(iconSize * 0.42))))
				or 10
			frame.durationText:SetFont(STANDARD_TEXT_FONT, timerFontSize, "OUTLINE")
			frame.durationText:SetTextColor(1, 1, 1, 1)
			frame.durationText:Show()
		end
	end

	if frame.stackText then
		if showStack ~= frame._previewShowStack then
			frame._previewShowStack = showStack
			if showStack then
				local stackFontSize = frame._stackFontSize
					or (iconSize and max(8, floor((frame._timerFontSize or 10) * 0.8)))
					or 8
				frame.stackText:SetFont(STANDARD_TEXT_FONT, stackFontSize, "OUTLINE")
				frame.stackText:SetTextColor(1, 1, 1, 1)
				frame.stackText:ClearAllPoints()
				frame.stackText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
				local now = GetTime()
				local elapsedTime = now - (frame._durationStart or now)
				local stacks = min(8, floor(elapsedTime / 3) + 1)
				frame.stackText:SetText(stacks)
				frame.stackText:Show()
			else
				frame.stackText:SetText("")
				frame.stackText:Hide()
			end
		end
	end
end

local function PreviewPrivateAurasFrame(self, parent)
	local f = parent and parent[self.name]
	if not f or InCombatLockdown() then return end

	f.previewFrames = f.previewFrames or {}
	local auraFrames = f.auraFrames
	local previewFrames = f.previewFrames

	local iconSize = self.iconSize > 1 and self.iconSize or self.iconSize * parent:GetHeight()
	iconSize = self.borderScale and iconSize or 32

	local showCooldown = not self.dbx.disableCooldown
	local showCoolText = not self.dbx.disableCooldownNumbers
	local durationAnchor = self.auraAnchor and self.auraAnchor.durationAnchor

	local textureOrder = BuildShuffledTextureOrder(self.maxIcons)
	ClearPreviewFrames(f)
	HideTestModeAuras(f)

	for i = 1, self.maxIcons do
		local auraFrame = auraFrames[i]
		if auraFrame then
			local preview = previewFrames[i]
			if not preview then
				preview = CreatePreviewFrame(f)
				previewFrames[i] = preview
			end
			preview:ClearAllPoints()
			preview:SetPoint("CENTER", auraFrame, "CENTER")
			preview:SetSize(iconSize, iconSize)
			preview:SetFrameLevel(auraFrame:GetFrameLevel() + 10)
			preview:SetFrameStrata(auraFrame:GetFrameStrata())

			local tex = textureOrder[i] or previewTextures[((i - 1) % #previewTextures) + 1]
			preview.icon:SetTexture(tex)
			SetPreviewTexCoord(preview.icon)
			preview.icon:SetVertexColor(1, 1, 1, 1)

			local duration = random(8, 30)
			local startTime = GetTime()
			local timerFontSize = iconSize < 1 and 10 or max(9, floor(iconSize * 0.42))
			local stackFontSize = max(8, floor(timerFontSize * 0.8))

			if showCooldown then
				preview.cooldown:SetCooldown(startTime, duration)
				preview.cooldown:SetHideCountdownNumbers(not showCoolText)
				preview.cooldown:SetDrawSwipe(true)
				preview.cooldown:SetDrawEdge(true)
				preview.cooldown:SetReverse(true)
				preview.cooldown:Show()
				if showCoolText and preview.coolText then
					local fontSize = iconSize < 1 and 10 or max(9, floor(iconSize * 0.42))
					preview.coolText:SetFont(STANDARD_TEXT_FONT, fontSize, "OUTLINE")
					preview.coolText:SetTextColor(1, 1, 1, 1)
					preview.coolText:ClearAllPoints()
					preview.coolText:SetPoint("CENTER", preview.cooldown, "CENTER", 0, 0)
				end
			else
				preview.cooldown:Hide()
			end

			if preview.stackText and showCooldown and showCoolText then
				preview.stackText:SetFont(STANDARD_TEXT_FONT, stackFontSize, "OUTLINE")
				preview.stackText:SetTextColor(1, 1, 1, 1)
				preview.stackText:ClearAllPoints()
				preview.stackText:SetPoint("BOTTOMRIGHT", preview, "BOTTOMRIGHT", -1, 1)
				preview.stackText:SetText(1)
				preview.stackText:Show()
			elseif preview.stackText then
				preview.stackText:Hide()
			end

			if durationAnchor and preview.durationText then
				preview.durationText:SetFont(STANDARD_TEXT_FONT, timerFontSize, "OUTLINE")
				preview.durationText:SetTextColor(1, 1, 1, 1)
				preview.durationText:ClearAllPoints()
				local rp = durationAnchor.relativePoint or "CENTER"
				local p = durationAnchor.point or "CENTER"
				local ox = durationAnchor.offsetX or 0
				local oy = durationAnchor.offsetY or 0
				preview.durationText:SetPoint(p, preview, rp, ox, oy)
				preview.durationText:SetText(max(0, duration - 1))
				preview.durationText:Show()
			elseif preview.durationText then
				preview.durationText:Hide()
			end

			preview._duration = duration
			preview._durationStart = startTime
			preview._expiresAt = startTime + duration
			preview._indicator = self
			preview._timerFontSize = timerFontSize
			preview._stackFontSize = stackFontSize
			preview._previewShowCooldown = nil
			preview._previewShowCoolText = nil
			preview._previewShowDuration = nil
			preview._previewShowStack = nil
			preview._previewDurationSig = nil

			local acc = 0
			preview:SetScript("OnUpdate", function(frame, elapsed)
				acc = acc + elapsed
				if acc < 0.2 then return end
				acc = 0
				local now = GetTime()
				HideTestModeAuras(f)
				ApplyPreviewRuntimeOptions(frame, iconSize)
				if now >= frame._expiresAt then
					HideTestModeAuras(f)
					if frame.durationText then
						frame.durationText:SetText("")
						frame.durationText:Hide()
					end
					if frame.stackText then
						frame.stackText:SetText("")
						frame.stackText:Hide()
					end
					if frame.cooldown then frame.cooldown:Hide() end
					frame:Hide()
					ReflowPreviewFrames(f, iconSize)
					frame:SetScript("OnUpdate", nil)
					return
				end
				local elapsedTime = now - frame._durationStart
				local rem = frame._expiresAt - now
				if frame.durationText and frame.durationText:IsShown() then
					frame.durationText:SetText(max(0, ceil(rem) - 1))
				end
				if frame.stackText and frame.stackText:IsShown() then
					local stacks = min(8, floor(elapsedTime / 3) + 1)
					frame.stackText:SetText(stacks)
				end
			end)

			preview:Show()
			auraFrame:Show()
		end
	end

	for i = self.maxIcons + 1, #previewFrames do
		if previewFrames[i] then previewFrames[i]:Hide() end
	end
end

local function PreviewPrivateAuras(self)
	for parent in next, Grid2Frame.activatedFrames do
		PreviewPrivateAurasFrame(self, parent)
	end
end

local function StopPreviewPrivateAuras(self)
	for parent in next, Grid2Frame.activatedFrames do
		local f = parent[self.name]
		if f and f.previewFrames then
			ClearPreviewFrames(f)
		end
	end
end

local function AttachPreview(indicator)
	if indicator._privateAurasPreviewAttached then return end
	indicator._privateAurasPreviewAttached = true
	indicator.PreviewHighlight = PreviewPrivateAuras
	indicator.StopPreview = StopPreviewPrivateAuras
end

do
	local origSetup = Grid2.setupFunc and Grid2.setupFunc["privateauras"]
	if origSetup then
		Grid2.setupFunc["privateauras"] = function(indicatorKey, dbx)
			local indicator = origSetup(indicatorKey, dbx)
			AttachPreview(indicator)
			return indicator
		end
	end
end
