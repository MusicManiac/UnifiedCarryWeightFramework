local ucwfOptions = PZAPI.ModOptions:create("UCWFModOptions", "UCWF - Unified Carry Weight Framework")
ucwfOptions:addTitle("Unified Carry Weight Framework")

ucwfOptions:addTickBox(
	"GatherDetailedDebugUCWF",
	getText("UI_UCWF_Options_GatherDetailedDebug"),
	false,
	getText("UI_UCWF_Options_GatherDetailedDebug_tooltip")
)
