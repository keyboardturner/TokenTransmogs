local addonName, TokenTransmogs = ...;
local itemData = TokenTransmogs.itemData;

local contextDisplayNames;

local function BuildContextDisplayNames()
	contextDisplayNames = {
		["ANY"] = "Any / Default",
		["UPGRADED"] = "Upgraded",
	};
	for enumName, enumValue in pairs(Enum.ItemCreationContext) do
		contextDisplayNames[enumValue] = enumName;
	end
end

local function GetContextDisplayName(ctx)
	if not contextDisplayNames then BuildContextDisplayNames() end;
	return contextDisplayNames[ctx] or tostring(ctx);
end

local function SortedContextKeys(tbl)
	local keys = {};
	for k in pairs(tbl) do table.insert(keys, k) end;
	table.sort(keys, function(a, b)
		local aNum, bNum = type(a) == "number", type(b) == "number";
		if aNum and bNum then return a < b end;
		if aNum then return true end;
		if bNum then return false end;
		return tostring(a) < tostring(b);
	end);
	return keys;
end

local browserFrame;
local scrollBoxList, scrollBoxBar;
local slotButtons = {};

local TT_CopyBoxMixin = {};

function TT_CopyBoxMixin:OnLoad()
	self:SetAutoFocus(false);
	self:SetFontObject("ChatFontNormal");
	self:SetTextInsets(5, 5, 0, 0);

	self.Label = self:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall");
	self.Label:SetJustifyH("LEFT");
	self.Label:SetText("");
	self.Label:SetWordWrap(false);
	self.Label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2);
	self.Label:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, 2);

	self:SetScript("OnEnterPressed", self.OnEnterPressed);
	self:SetScript("OnKeyDown", self.OnKeyDown);
	self:SetScript("OnTextChanged", self.OnTextChanged);
	self:SetScript("OnEscapePressed", self.ClearFocus);
end

function TT_CopyBoxMixin:SetLabel(text)
	self.Label:SetText(text);
	self.Label:Show();
end

function TT_CopyBoxMixin:OnEnterPressed()
	self:ClearFocus();
end

function TT_CopyBoxMixin:OnKeyDown(key)
	if IsControlKeyDown() and (key == "C" or key == "X") then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
		
		C_Timer.After(0.1, function()
			self:ClearFocus();
		end)
	end
end

function TT_CopyBoxMixin:OnTextChanged(userInput)
	if userInput then
		self:SetText(self.contentString or "");
		self:HighlightText();
	else
		self.contentString = self:GetText();
	end
end

local function CreateLKCopyBox(parent, width)
	local copyBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate");
	copyBox:SetSize(width or 200, 25);
	
	Mixin(copyBox, TT_CopyBoxMixin);
	copyBox:OnLoad();
	
	return copyBox;
end

local function InitializeItemRow(button, data)
	local itemID = data.itemID;

	if not button.tex then
		button.tex = button:CreateTexture(nil, "BACKGROUND");
		button.tex:SetAllPoints();
		button.tex:SetAtlas("PetList-ButtonBackground");

		button.texHL = button:CreateTexture(nil, "OVERLAY");
		button.texHL:SetAllPoints();
		button.texHL:SetAtlas("PetList-ButtonHighlight");
		button.texHL:SetBlendMode("ADD");
		button.texHL:Hide();

		button.icon = button:CreateTexture(nil, "ARTWORK");
		button.icon:SetSize(26, 26);
		button.icon:SetPoint("LEFT", 6, 0);

		button.text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
		button.text:SetPoint("LEFT", button.icon, "RIGHT", 8, 0);
		button.text:SetPoint("RIGHT", -5, 0);
		button.text:SetJustifyH("LEFT");

		button:RegisterForClicks("RightButtonUp");
	end

	button.icon:SetTexture(134400);
	button.text:SetText("Loading " .. itemID .. "...");
	button.text:SetTextColor(0.5, 0.5, 0.5);

	local item = Item:CreateFromItemID(itemID);
	if not item:IsItemEmpty() then
		item:ContinueOnItemLoad(function()
			local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID);
			if itemName then
				button.icon:SetTexture(itemTexture);
				button.text:SetText(itemName);
				local r, g, b = C_Item.GetItemQualityColor(itemQuality or 1);
				button.text:SetTextColor(r, g, b);
			end
		end)
	end

	button:SetScript("OnEnter", function(self)
		self.texHL:Show();
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		GameTooltip:SetItemByID(itemID);
		GameTooltip:Show();
	end)

	button:SetScript("OnLeave", function(self)
		self.texHL:Hide();
		GameTooltip_Hide();
	end)

	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton ~= "RightButton" then return end;

		local tokenInfo = itemData[itemID];
		if not tokenInfo or not tokenInfo.Items then return end;

		local contextKeys = SortedContextKeys(tokenInfo.Items);
		if #contextKeys == 0 then return end;

		MenuUtil.CreateContextMenu(self, function(owner, rootDescription)
			rootDescription:CreateTitle(string.format("Context Override |cff888888(id %d)|r", itemID));

			rootDescription:CreateRadio(
				"Default |cff888888(from item link)|r",
				function() return TokenTransmogs.forcedContexts[itemID] == nil end,
				function() TokenTransmogs.forcedContexts[itemID] = nil end,
				nil
			);

			rootDescription:CreateDivider();

			for _, ctx in ipairs(contextKeys) do
				local label = GetContextDisplayName(ctx);
				rootDescription:CreateRadio(
					label,
					function(data) return TokenTransmogs.forcedContexts[itemID] == data end,
					function(data) TokenTransmogs.forcedContexts[itemID] = data end,
					ctx
				);
			end
		end);
	end);
end

local function CreateBrowserUI()
	if browserFrame then return browserFrame end;

	browserFrame = CreateFrame("Frame", "TokenTransmogsBrowserFrame", UIParent, "ButtonFrameTemplate");
	browserFrame:SetSize(800, 500);
	browserFrame:SetPoint("CENTER");
	browserFrame:SetToplevel(true);
	browserFrame:EnableMouse(true);
	browserFrame:SetMovable(true);
	browserFrame:RegisterForDrag("LeftButton");
	browserFrame:SetScript("OnDragStart", browserFrame.StartMoving);
	browserFrame:SetScript("OnDragStop", browserFrame.StopMovingOrSizing);

	ButtonFrameTemplate_HidePortrait(browserFrame);
	ButtonFrameTemplate_HideButtonBar(browserFrame);
	browserFrame:SetTitle("TokenTransmogs Item Browser");
	tinsert(UISpecialFrames, "TokenTransmogsBrowserFrame");

	local listContainer = CreateFrame("Frame", nil, browserFrame, "InsetFrameTemplate");
	listContainer:SetPoint("TOPLEFT", 10, -60);
	listContainer:SetPoint("BOTTOMLEFT", 10, 5);
	listContainer:SetWidth(300);

	scrollBoxList = CreateFrame("Frame", nil, listContainer, "WowScrollBoxList");
	scrollBoxList:SetPoint("TOPLEFT", 5, -5);
	scrollBoxList:SetPoint("BOTTOMRIGHT", -25, 5);

	scrollBoxBar = CreateFrame("EventFrame", nil, listContainer, "MinimalScrollBar");
	scrollBoxBar:SetPoint("TOPLEFT", scrollBoxList, "TOPRIGHT", 5, 0);
	scrollBoxBar:SetPoint("BOTTOMLEFT", scrollBoxList, "BOTTOMRIGHT", 5, 0);

	local scrollView = CreateScrollBoxListLinearView();
	scrollView:SetElementInitializer("Button", InitializeItemRow);
	scrollView:SetElementExtent(32);
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBoxList, scrollBoxBar, scrollView);

	local tokenItems = {};
	for tokenID, _ in pairs(itemData) do
		table.insert(tokenItems, { itemID = tokenID });
	end
	
	table.sort(tokenItems, function(a, b)
		return a.itemID < b.itemID;
	end)
	
	scrollBoxList:SetDataProvider(CreateDataProvider(tokenItems));

	local tool2Header = browserFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium");
	tool2Header:SetPoint("TOPLEFT", listContainer, "TOPRIGHT", 20, -5);
	tool2Header:SetText("Transmog Set Visual IDs");

	local inputEditBox = CreateFrame("EditBox", "TransmogSetInputBox", browserFrame, "InputBoxTemplate");
	inputEditBox:SetSize(120, 30);
	inputEditBox:SetAutoFocus(false);
	inputEditBox:SetPoint("TOPLEFT", tool2Header, "BOTTOMLEFT", 5, -10);

	inputEditBox.Label = inputEditBox:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
	inputEditBox.Label:SetJustifyH("LEFT")
	inputEditBox.Label:SetText("TransmogSet ID:")
	inputEditBox.Label:SetWordWrap(false)
	inputEditBox.Label:SetPoint("BOTTOMLEFT", inputEditBox, "TOPLEFT", 0, 0)
	inputEditBox.Label:SetPoint("BOTTOMRIGHT", inputEditBox, "TOPRIGHT", 0, 0)

	local slotData = {
		{ fileID = 136516, slotName = "Head", slotID = 1, state = true },
		{ fileID = 136526, slotName = "Shoulders", slotID = 3, state = true },
		{ fileID = 136525, slotName = "Shirt", slotID = 4, state = false },
		{ fileID = 136512, slotName = "Chest", slotID = 5, state = false },
		{ fileID = 136529, slotName = "Waist", slotID = 6, state = true },
		{ fileID = 136517, slotName = "Legs", slotID = 7, state = true },
		{ fileID = 136513, slotName = "Feet", slotID = 8, state = true },
		{ fileID = 136530, slotName = "Wrist", slotID = 9, state = true },
		{ fileID = 136515, slotName = "Hands", slotID = 10, state = true },
		{ fileID = 136512, slotName = "Back", slotID = 15, state = true },
		{ fileID = 136518, slotName = "Main Hand", slotID = 16, state = false },
		{ fileID = 136524, slotName = "Off Hand", slotID = 17, state = false },
		{ fileID = 136520, slotName = "Ranged", slotID = 18, state = false },
		{ fileID = 136527, slotName = "Tabard", slotID = 19, state = false },
	};

	local slotContainer = CreateFrame("Frame", nil, browserFrame)
	slotContainer:SetSize(430, 30)
	slotContainer:SetPoint("TOPLEFT", inputEditBox, "BOTTOMLEFT", 0, -10)

	for i, data in ipairs(slotData) do
		local btn = CreateFrame("Button", nil, slotContainer);
		btn:SetSize(28, 28);
		btn:SetPoint("LEFT", (i-1) * 31, 0);
		
		btn.icon = btn:CreateTexture(nil, "BACKGROUND");
		btn.icon:SetAllPoints();
		btn.icon:SetTexture(data.fileID);
		
		local function UpdateState()
			if data.state then
				btn.icon:SetDesaturated(false);
				btn:SetAlpha(1.0);
			else
				btn.icon:SetDesaturated(true);
				btn:SetAlpha(0.3);
			end
		end
		UpdateState();
		
		btn:SetScript("OnClick", function()
			data.state = not data.state;
			UpdateState();
		end)
		
		btn:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
			GameTooltip:SetText(data.slotName);
			GameTooltip:AddLine("Click to toggle this slot", 1, 1, 1, true);
			GameTooltip:Show();
		end)
		btn:SetScript("OnLeave", function() GameTooltip_Hide() end);
		
		table.insert(slotButtons, {btn = btn, data = data});
	end

	local outputEditBox = CreateLKCopyBox(browserFrame, 430);
	outputEditBox:SetPoint("TOPLEFT", slotContainer, "BOTTOMLEFT", 0, -25);
	outputEditBox:SetLabel("Visual IDs:");

	local btn = CreateFrame("Button", nil, browserFrame, "UIPanelButtonTemplate");
	btn:SetSize(80, 22);
	btn:SetPoint("LEFT", inputEditBox, "RIGHT", 10, 0);
	btn:SetText("Get IDs");
	btn:SetScript("OnClick", function()
		local setID = tonumber(inputEditBox:GetText());
		if not setID then return end
		
		local results = {};
		for _, slotBtn in ipairs(slotButtons) do
			if slotBtn.data.state then
				local sources = C_TransmogSets.GetSourcesForSlot(setID, slotBtn.data.slotID);
				table.insert(results, (sources and sources[1]) and sources[1].visualID or "0");
			end
		end
		outputEditBox:SetText(table.concat(results, ", "));
		outputEditBox:SetFocus();
		outputEditBox:HighlightText();
	end);

	browserFrame:SetScript("OnMouseDown", function(self)
		inputEditBox:ClearFocus()
		outputEditBox:ClearFocus();
	end)

	return browserFrame;
end

SLASH_TOKENTRANSMOGS1 = "/tokentransmogs";
SlashCmdList["TOKENTRANSMOGS"] = function()
	if not browserFrame then
		CreateBrowserUI();
	else
		browserFrame:SetShown(not browserFrame:IsShown());
	end
end