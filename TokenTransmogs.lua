local addonName, TokenTransmogs = ...;

local itemData = TokenTransmogs.itemData

local strmatch = string.match;
local GetAllAppearanceSources = C_TransmogCollection.GetAllAppearanceSources;
local GetAppearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo;
local PlayerHasTransmogItemModifiedAppearance = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance;

--[[
-- debug, do not add to final version
local idEditBox = CreateFrame("EditBox", "AppearanceIDEditBox", UIParent, "InputBoxTemplate");
idEditBox:SetSize(500, 45);
idEditBox:SetAutoFocus(false);
idEditBox:Hide();
idEditBox:SetPoint("CENTER", UIParent, "CENTER");
idEditBox:SetTextInsets(10, 10, 10, 10);
idEditBox:SetFontObject("GameFontHighlight");
idEditBox:SetScript("OnEscapePressed", function(self) self:Hide() end);

local collectedAppearanceIDs = {};

idEditBox:SetScript("OnHide", function(self)
	collectedAppearanceIDs = {};
end)
local function _OnTooltipSetItem(tooltip)
	local _, itemLink = GameTooltip:GetItem();
	if not itemLink then return end;

	local itemAppearanceID, itemModifiedAppearanceID = C_TransmogCollection.GetItemInfo(itemLink);

	if not itemAppearanceID or not itemModifiedAppearanceID then return end;
	tooltip:AddDoubleLine("AppearanceID", itemAppearanceID);
	tooltip:AddDoubleLine("ModifiedAppearanceID", itemModifiedAppearanceID);

	local msg = string.format("AppearanceID: %d, ModifiedAppearanceID: %d", itemAppearanceID, itemModifiedAppearanceID);
	DEFAULT_CHAT_FRAME:AddMessage(msg);

	if not collectedAppearanceIDs[itemAppearanceID] then
		table.insert(collectedAppearanceIDs, itemAppearanceID);
		collectedAppearanceIDs[itemAppearanceID] = true;
	end

	local displayText = table.concat(collectedAppearanceIDs, " ");
	idEditBox:SetText(displayText);
	idEditBox:HighlightText();
	idEditBox:Show();
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, _OnTooltipSetItem);
-- end of debug
--]]


--[[
-- debug, do not add to final version

local inputEditBox = CreateFrame("EditBox", "TransmogSetInputBox", UIParent, "InputBoxTemplate")
inputEditBox:SetSize(300, 45)
inputEditBox:SetAutoFocus(false)
inputEditBox:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
inputEditBox:SetTextInsets(10, 10, 10, 10)
inputEditBox:SetFontObject("GameFontHighlight")

local inputLabel = inputEditBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
inputLabel:SetPoint("BOTTOM", inputEditBox, "TOP", 0, 5)
inputLabel:SetText("Enter Transmog Set ID:")

local outputEditBox = CreateFrame("EditBox", "VisualIDOutputBox", UIParent, "InputBoxTemplate")
outputEditBox:SetSize(500, 45)
outputEditBox:SetAutoFocus(false)
outputEditBox:SetPoint("CENTER", UIParent, "CENTER", 0, -50)
outputEditBox:SetTextInsets(10, 10, 10, 10)
outputEditBox:SetFontObject("GameFontHighlight")
outputEditBox:SetScript("OnEscapePressed", function(self) self:Hide() end)

local outputLabel = outputEditBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
outputLabel:SetPoint("BOTTOM", outputEditBox, "TOP", 0, 0)
outputLabel:SetText("Visual IDs:")

local processBtn = CreateFrame("Button", "ProcessTransmogBtn", UIParent, "UIPanelButtonTemplate")
processBtn:SetSize(100, 30)
processBtn:SetPoint("TOP", inputEditBox, "BOTTOM", 0, -10)
processBtn:SetText("Get IDs")

processBtn:SetScript("OnClick", function()
	outputEditBox:Show()
	local transmogsetID = tonumber(inputEditBox:GetText())
	
	if not transmogsetID then
		outputEditBox:SetText("Invalid ID")
		return
	end
	
	--local slotIDs = {1, 3, 5, 10, 7} -- tier set
	local slotIDs = {1, 3, 5, 6, 7, 8, 9, 10, 15,} -- full set
	local visualIDs = {}
	
	for _, slotID in ipairs(slotIDs) do
		local sources = C_TransmogSets.GetSourcesForSlot(transmogsetID, slotID)
		if sources and sources[1] and sources[1].visualID then
			table.insert(visualIDs, sources[1].visualID)
		else
			table.insert(visualIDs, "N/A")
		end
	end
	
	outputEditBox:SetText(table.concat(visualIDs, ", "))
	outputEditBox:HighlightText()
end)

inputEditBox:SetScript("OnEnterPressed", function(self)
	processBtn:Click()
end)

inputEditBox:Show()
outputEditBox:Show()
processBtn:Show()

--]]

local ANY = "ANY"
local UPGRADED = "UPGRADED"

local ClassListTbl = LocalizedClassList();

local function MatchClassIcon(className)
	for k, v in pairs(ClassListTbl) do
		if v == className then
			local coords = CLASS_ICON_TCOORDS[k];
			return coords
		end
	end
end

local function GetItemClassRequirement(itemLink)
	local data = C_TooltipInfo.GetHyperlink(itemLink)
	local pattern = ITEM_CLASSES_ALLOWED:gsub("%%s", "(.+)")

	for k, v in pairs(data.lines) do
		for key, var in pairs(v) do
			if key == "leftText" and type(var) == "string" then
				local classNameFromString = strmatch(var, pattern);
				if classNameFromString then
					return MatchClassIcon(classNameFromString)
				end
			end
		end
	end
end


local ClassVisual = {};

function ClassVisual:GetClassIconMarkup(classID)
	if not self.classIconMarkups then
		self.classIconMarkups = {};
	end

	if self.classIconMarkups[classID] == nil then
		local _, fileName = GetClassInfo(classID);

		local useAtlas = false;		--CharacterCreateIcons are 128x128 they doesn't look good when down-scaled
		local iconSize = 0;			--0: follow font size

		if useAtlas then
			local atlas = "classicon-"..fileName;
			if C_Texture.GetAtlasInfo(atlas) then
				self.classIconMarkups[classID] = string.format("|A:%s:%s:%s|a", atlas, iconSize, iconSize);
			else
				self.classIconMarkups[classID] = false;
			end
		else
			self.classIconMarkups[classID] = string.format("|Tinterface\\icons\\classicon_%s:%s:%s:0:0:64:64:4:60:4:60|t", fileName, iconSize, iconSize);
		end
	end

	return self.classIconMarkups[classID]
end


local _ItemContextNameTranslator = EnumUtil.GenerateNameTranslation(Enum.ItemCreationContext)
local ItemContextNameTranslator = function(itemContext)
	if not itemContext then
		return ANY
	end
	return _ItemContextNameTranslator(itemContext)
end

local function GetItemContextFromLink(itemLink)
	if not itemLink then return end;
	local _, linkData = LinkUtil.ExtractLink(itemLink);
	--DevTools_Dump(strsplittable(":", linkData));
	local itemContext = select(12, strsplit(":", linkData));
	itemContext = tonumber(itemContext);
	if not itemContext then return end;
	return itemContext;
end

local function GetCollectionInfoForToken(itemLink)
	if not itemLink then return end;
	local tokenID = tonumber(strmatch(itemLink, "item:(%d+)"));
	local itemInfo = tokenID and itemData[tokenID];
	if itemInfo then
		local itemContext = GetItemContextFromLink(itemLink);
		if not itemContext then 
			itemContext = ANY;
		end
		
		local listsToProcess = {}
		if itemInfo.Items[itemContext] then
			table.insert(listsToProcess, { list = itemInfo.Items[itemContext], isUpgraded = false })
		end
		if itemInfo.Items[UPGRADED] and itemContext ~= UPGRADED then
			table.insert(listsToProcess, { list = itemInfo.Items[UPGRADED], isUpgraded = true })
		end

		if #listsToProcess == 0 then return end;

		local classGroup = itemInfo.Classes;
		local linkReceived = true;
		
		local collectionInfo = {};

		for _, data in ipairs(listsToProcess) do
			local appearances = data.list;
			local isUpgraded = data.isUpgraded;

			for i, appearanceID in ipairs(appearances) do
				local sources = GetAllAppearanceSources(appearanceID);
				if not sources then return end

				local displayLink = GetAppearanceSourceInfo(sources[1]).itemLink;
				if displayLink then
					if not strmatch(displayLink, "%[(.+)%]") then
						linkReceived = false;
					end
				end

				local classID = classGroup and classGroup[i] or nil;
				local iconMarkup = ""
				if classID then
					local baseClassID, tag = classID, nil
					if type(classID) == "string" then
						baseClassID, tag = string.match(classID, "^(%d+)%-(%w+)")
						baseClassID = tonumber(baseClassID)
					else
						baseClassID = classID
					end

					if baseClassID then
						iconMarkup = ClassVisual:GetClassIconMarkup(baseClassID) or ""
					end

					if tag == "pvp" then
						iconMarkup = iconMarkup .. " |A:questlog-questtypeicon-pvp:15:15|a"
					end
				end
				
				if iconMarkup == "" then
					local requiredClass = GetItemClassRequirement(displayLink);
					if not requiredClass then
						iconMarkup = "";
					else
						iconMarkup = "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:15:15:0:0:512:512:".. requiredClass[1]*512 ..":".. requiredClass[2]*512 ..":".. requiredClass[3]*512 ..":".. requiredClass[4]*512 .."|t"
					end
				end

				if isUpgraded then
					iconMarkup = "|A:CovenantSanctum-Upgrade-Icon-Available:15:15|a " .. iconMarkup
				end

				local collected = false;
				for _, sourceID in ipairs(sources) do
					if PlayerHasTransmogItemModifiedAppearance(sourceID) then
						collected = true;
						break
					end
				end

				local collectedColor = collected and GREEN_FONT_COLOR or RED_FONT_COLOR;
				local collectedText = collected and COLLECTED or FOLLOWERLIST_LABEL_UNCOLLECTED;
				collectedText = collectedColor:WrapTextInColorCode(collectedText);

				table.insert(collectionInfo, {
					classID = classID,
					link = displayLink,
					collected = collected,
					leftText = iconMarkup .. " " .. (displayLink or ""),
					rightText = collectedText
				});
			end
		end

		return collectionInfo, linkReceived
	end
end

KBTUI_GetCollectionInfoForToken = GetCollectionInfoForToken;	--Globals

local function OnTooltipSetItem(tooltip)
	if not tooltip or not tooltip.GetItem then return end;		--Change GameTooltip to tooltip so it covers ItemRefTooltip
	local _, itemLink = tooltip:GetItem();
	if not itemLink then return end;

	local collectionInfo, linkReceived = GetCollectionInfoForToken(itemLink);
	if collectionInfo then
		for _, info in ipairs(collectionInfo) do
			tooltip:AddDoubleLine(info.leftText, info.rightText);
		end

		if not linkReceived then
			if tooltip.RefreshDataNextUpdate then
				tooltip:RefreshDataNextUpdate();
			end
		end

		tooltip:Show();
	end
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnTooltipSetItem);