--[[ PrivateAuras preview hook for Options Highlight Indicator (test mode) ]]--

local Grid2 = Grid2
local Grid2Options = Grid2Options

local TEST_STATUS_NAME = "/@@@test@@@/"

local function IsIndicatorTestModeEnabled(indicator)
	local testStatus = Grid2.statuses and Grid2.statuses[TEST_STATUS_NAME]
	return testStatus and testStatus.indicators and testStatus.indicators[indicator]
end

local function StopPrivateAurasPreview()
	for _, indicator in Grid2:IterateIndicators('privateauras') do
		if indicator.StopPreview then indicator:StopPreview() end
	end
end

hooksecurefunc(Grid2Options, "ToggleIndicatorTestMode", function(_, indicator)
	StopPrivateAurasPreview()
	if indicator and indicator.dbx and indicator.dbx.type == 'privateauras' then
		local previewIndicator = Grid2:GetIndicatorByName(indicator.name) or indicator
		if previewIndicator and previewIndicator.PreviewHighlight and IsIndicatorTestModeEnabled(previewIndicator) then
			previewIndicator:PreviewHighlight()
		end
	end
end)

hooksecurefunc(Grid2Options, "ToggleTestMode", function()
	StopPrivateAurasPreview()
end)
