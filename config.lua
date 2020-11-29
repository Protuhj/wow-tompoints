-- Create options UI

local uniquealyzer = 0;
local function createCheckbutton(parent, x_loc, y_loc, displayname)
	uniquealyzer = uniquealyzer + 1;
	
	local checkbutton = CreateFrame("CheckButton", "TomPoints_cb" .. uniquealyzer, parent, "ChatConfigCheckButtonTemplate");
	checkbutton:SetPoint("TOPLEFT", x_loc, y_loc);
	getglobal(checkbutton:GetName() .. 'Text'):SetText(displayname);

	return checkbutton;
end

-- Create the Blizzard addon option frame
local panel = CreateFrame("Frame", "TomPointsBlizzOptions");
panel:RegisterEvent("VARIABLES_LOADED");
-- Handle the events as they happen
panel:SetScript("OnEvent", function(self, event, ...)
	if (event == "VARIABLES_LOADED") then
		TomPoints_cb1:SetChecked(addonConfig["AlwaysCreateMapPin"]);
		TomPoints_cb2:SetChecked(addonConfig["ShareAsPin"]);
		TomPoints_cb3:SetChecked(addonConfig["ReplaceBlizzardLinks"]);
        self:UnregisterEvent("VARIABLES_LOADED");
	end
end)
panel.name = "TomPoints";
InterfaceOptions_AddCategory(panel);

local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge");
fs:SetPoint("TOPLEFT", 10, -15);
fs:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 10, -45);
fs:SetJustifyH("LEFT");
fs:SetJustifyV("TOP");
fs:SetText("TomPoints");
local cb1 = createCheckbutton(panel, 10, -45, "Always create a Map Pin when clicking a waypoint link");
cb1.tooltip = "If you have TomTom, this will also create a Map Pin at the location";
cb1:SetScript("OnClick", 
   function(self, button, down)
    addonConfig["AlwaysCreateMapPin"] = self:GetChecked();
   end
);

local cb2 = createCheckbutton(panel, 10, -65, "Share Map Pin links when linking waypoints (shift+click them with chat box active)");
cb2.tooltip = "If this is unchecked, waypoints will be shared as their raw coordinates";
cb2:SetScript("OnClick", 
   function(self, button, down)
    addonConfig["ShareAsPin"] = self:GetChecked();
   end
);

local cb3 = createCheckbutton(panel, 10, -85, "Replace Blizzard Map Pin links with TomPoints links");
cb3.tooltip = "This allows pin links to be shareable from chat instead of the map";
cb3:SetScript("OnClick", 
   function(self, button, down)
    addonConfig["ReplaceBlizzardLinks"] = self:GetChecked();
   end
);
local infoLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
infoLabel:SetPoint("TOPLEFT", 35, -105);
infoLabel:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 35, -165);
infoLabel:SetJustifyH("LEFT");
infoLabel:SetJustifyV("TOP");
local text = "If you see a link with an " .. CreateAtlasMarkup("warlockportalalliance", 15, 15) .. " icon at the beginning, that means the waypoint is in a different zone.";
text = text .. "|n|nExample: |cff149bfd|Hgarrmission:TomPoints: |h[" .. CreateAtlasMarkup("warlockportalalliance", 15, 15) .. " 23.45 45.22]|h|r"
infoLabel:SetText(text);
