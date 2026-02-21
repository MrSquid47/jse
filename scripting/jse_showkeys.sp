#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR	"AI"
#define PLUGIN_VERSION	"0.1.9"

#define UPDATE_URL		"http://jumpacademy.tf/plugins/jse/showkeys/updatefile.txt"

#include <clientprefs>
#include <multicolors>
#include <sourcemod>
#include <sdktools>
#include <smlib/clients>
#include <tf2>
#include <tf2_stocks>

#undef REQUIRE_PLUGIN
#include <updater>

#define TEXT_HOLD_TIME 	0.5
#define TEXT_WAIT_FRAME	3

#define DEFAULT_KEY_COORD_X 0.58
#define DEFAULT_KEY_COORD_Y 0.40

#define DEFAULT_ANG_COORD_X 0.47
#define DEFAULT_ANG_COORD_Y 0.52

#define DEFAULT_RGBA 255

#define LASTUPDATE_TICK_KEY 0
#define LASTUPDATE_BTN 1
#define LASTUPDATE_TICK_ANG 2

#define ANGVALUE_VERTICAL 0 
#define ANGVALUE_HORIZONTAL 1
#define ANGVALUE_HEIGHT 2

enum Mode {
	DISPLAY,
	EDIT_KEY_COORDS,
	EDIT_ANG_COORDS,
	EDIT_KEY_COLORS,
	EDIT_ANG_COLORS
}

Handle g_hKeysHudText;
Handle g_hAngHudText;

Mode g_iMode[MAXPLAYERS + 1] = {DISPLAY, ...};
int g_iFocus[MAXPLAYERS + 1][2];

bool g_bKeysEnabled[MAXPLAYERS + 1] =  { false, ... };
int g_iKeysTarget[MAXPLAYERS + 1] =  { 0, ... };

bool g_bAngEnabled[MAXPLAYERS + 1] =  { false, ... };
int g_iAngTarget[MAXPLAYERS + 1] =  { 0, ... };
bool g_bAngValues[MAXPLAYERS + 1][3];

float g_fKeysHUDCoords[MAXPLAYERS + 1][2];
int g_iKeysHUDColors[MAXPLAYERS + 1][4];
int g_iKeysHUDColorsAlphaMultiplied[MAXPLAYERS + 1][3];

float g_fAngHUDCoords[MAXPLAYERS + 1][2];
int g_iAngHUDColors[MAXPLAYERS + 1][4];
int g_iAngHUDColorsAlphaMultiplied[MAXPLAYERS + 1][3];

int g_iLastUpdate[MAXPLAYERS + 1][3];

Cookie g_hCookieKeysEnabled;
Cookie g_hCookieKeysCoords;
Cookie g_hCookieKeysColor;
Cookie g_hCookieAngEnabled;
Cookie g_hCookieAngCoords;
Cookie g_hCookieAngColor;
Cookie g_hCookieAngDisplayVert;
Cookie g_hCookieAngDisplayHoriz;
Cookie g_hCookieAngDisplayHght;

public Plugin myinfo = {
	name = "Jump Server Essentials - Show Keys",
	author = PLUGIN_AUTHOR,
	description = "JSE show keypresses module",
	version = PLUGIN_VERSION,
	url = "https://jumpacademy.tf"
};

public void OnPluginStart() {
	CreateConVar("jse_showkeys_version", PLUGIN_VERSION, "Jump Server Essentials show keys version -- Do not modify",  FCVAR_NOTIFY | FCVAR_DONTRECORD);

	// Show Keys
	RegConsoleCmd("sm_showkeys", cmdShowKeys, "Toggle showing keypresses on HUD");
	RegConsoleCmd("sm_skeys", cmdShowKeys, "Toggle showing keypresses on HUD");

	RegConsoleCmd("sm_showkeys_options", cmdShowKeysOptions, "Change show keys HUD options");
	RegConsoleCmd("sm_skeys_options", cmdShowKeysOptions, "Change show keys HUD options");

	RegConsoleCmd("sm_showkeys_coords", cmdShowKeysCoords, "Change show keys HUD coordinates");
	RegConsoleCmd("sm_skeys_coords", cmdShowKeysCoords, "Change show keys HUD coordinates");

	RegConsoleCmd("sm_showkeys_colors", cmdShowKeysColors, "Change show keys HUD colors");
	RegConsoleCmd("sm_skeys_colors", cmdShowKeysColors, "Change show keys HUD colors");

	// Show Angles
	RegConsoleCmd("sm_showang", cmdShowAng, "Toggle showing angles on HUD");
	RegConsoleCmd("sm_sang", cmdShowAng, "Toggle showing angles on HUD");

	RegConsoleCmd("sm_showang_options", cmdShowAngOptions, "Change show angles HUD options");
	RegConsoleCmd("sm_sang_options", cmdShowAngOptions, "Change show angles HUD options");

	RegConsoleCmd("sm_showang_coords", cmdShowAngCoords, "Change show angles HUD coordinates");
	RegConsoleCmd("sm_sang_coords", cmdShowAngCoords, "Change show angles HUD coordinates");

	RegConsoleCmd("sm_showang_colors", cmdShowAngColors, "Change show angles HUD colors");
	RegConsoleCmd("sm_sang_colors", cmdShowAngColors, "Change show angles HUD colors");

	RegConsoleCmd("sm_showang_values", cmdShowAngValues, "Change show angles displayed values");
	RegConsoleCmd("sm_sang_values", cmdShowAngValues, "Change show angles displayed values");

	// Force keys
	RegAdminCmd("sm_forceshowkeys", cmdForceShowKeys, ADMFLAG_GENERIC, "Force toggle showing keypresses on HUD");
	RegAdminCmd("sm_fskeys", cmdForceShowKeys, ADMFLAG_GENERIC, "Force toggle showing keypresses on HUD");

	HookEvent("player_spawn", Event_PlayerSpawn);

	// Cookies
	g_hCookieKeysEnabled = new Cookie("jse_showkeys_enabled", "Show keys enable toggle", CookieAccess_Private);
	g_hCookieKeysCoords = new Cookie("jse_showkeys_coords", "Show keys HUD coordinates", CookieAccess_Private);
	g_hCookieKeysColor = new Cookie("jse_showkeys_color", "Show keys HUD text color", CookieAccess_Private);
	g_hCookieAngEnabled = new Cookie("jse_showang_enabled", "Show angles enable toggle", CookieAccess_Private);
	g_hCookieAngCoords = new Cookie("jse_showang_coords", "Show angles HUD coordinates", CookieAccess_Private);
	g_hCookieAngColor = new Cookie("jse_showang_color", "Show angles HUD text color", CookieAccess_Private);
	g_hCookieAngDisplayVert = new Cookie("jse_showang_display_vert", "Show angles display vertical value", CookieAccess_Private);
	g_hCookieAngDisplayHoriz = new Cookie("jse_showang_display_horiz", "Show angles display horizontal value", CookieAccess_Private);
	g_hCookieAngDisplayHght = new Cookie("jse_showang_display_hght", "Show angles display height value", CookieAccess_Private);

	SetCookieMenuItem(CookieMenuHandler_Options, 0, "Show Keys");

	g_hKeysHudText = CreateHudSynchronizer();
	g_hAngHudText = CreateHudSynchronizer();

	LoadTranslations("core.phrases");
	LoadTranslations("common.phrases");
	LoadTranslations("jse_showkeys.phrases");

	if (LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErrMax) {
	RegPluginLibrary("jse_showkeys");
	CreateNative("ForceShowKeys", Native_ForceShowKeys);
	CreateNative("ResetShowKeys", Native_ResetShowKeys);

	return APLRes_Success;
}

public void OnMapStart() {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public void OnLibraryAdded(const char[] sName) {
	if (StrEqual(sName, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public void OnClientCookiesCached(int iClient) {
	if (IsFakeClient(iClient)) {
		return;
	}

	if (!GetCookieBool(iClient, g_hCookieAngDisplayVert, g_bAngValues[iClient][ANGVALUE_VERTICAL])) {
		g_bAngValues[iClient][ANGVALUE_VERTICAL] = true;
	}

	if (!GetCookieBool(iClient, g_hCookieAngDisplayHoriz, g_bAngValues[iClient][ANGVALUE_HORIZONTAL])) {
		g_bAngValues[iClient][ANGVALUE_HORIZONTAL] = true;
	}

	if (!GetCookieBool(iClient, g_hCookieAngDisplayHght, g_bAngValues[iClient][ANGVALUE_HEIGHT])) {
		g_bAngValues[iClient][ANGVALUE_HEIGHT] = true;
	}

	if (!GetCookieBool(iClient, g_hCookieAngDisplayVert, g_bKeysEnabled[iClient])) {
		g_bKeysEnabled[iClient] = false;
	}

	if (!GetCookieBool(iClient, g_hCookieKeysEnabled, g_bKeysEnabled[iClient])) {
		g_bKeysEnabled[iClient] = false;
	}

	if (!GetCookieBool(iClient, g_hCookieAngEnabled, g_bAngEnabled[iClient])) {
		g_bAngEnabled[iClient] = false;
	}

	if (!GetCookieFloat2D(iClient, g_hCookieKeysCoords, g_fKeysHUDCoords[iClient][0], g_fKeysHUDCoords[iClient][1])) {
		g_fKeysHUDCoords[iClient] =  view_as<float>({ DEFAULT_KEY_COORD_X, DEFAULT_KEY_COORD_Y });
	}

	if (!GetCookieFloat2D(iClient, g_hCookieAngCoords, g_fAngHUDCoords[iClient][0], g_fAngHUDCoords[iClient][1])) {
		g_fAngHUDCoords[iClient] =  view_as<float>({ DEFAULT_ANG_COORD_X, DEFAULT_ANG_COORD_Y });
	}

	if (GetCookieRGBA(iClient, g_hCookieKeysColor, g_iKeysHUDColors[iClient][0], g_iKeysHUDColors[iClient][1], g_iKeysHUDColors[iClient][2], g_iKeysHUDColors[iClient][3])) {
		g_iKeysHUDColorsAlphaMultiplied[iClient][0] = Math_Clamp(RoundToNearest(g_iKeysHUDColors[iClient][0] * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);
		g_iKeysHUDColorsAlphaMultiplied[iClient][1] = Math_Clamp(RoundToNearest(g_iKeysHUDColors[iClient][1] * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);
		g_iKeysHUDColorsAlphaMultiplied[iClient][2] = Math_Clamp(RoundToNearest(g_iKeysHUDColors[iClient][2] * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);
	} else {
		g_iKeysHUDColors[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
		g_iKeysHUDColorsAlphaMultiplied[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
	}

	if (GetCookieRGBA(iClient, g_hCookieAngColor, g_iAngHUDColors[iClient][0], g_iAngHUDColors[iClient][1], g_iAngHUDColors[iClient][2], g_iAngHUDColors[iClient][3])) {
		g_iAngHUDColorsAlphaMultiplied[iClient][0] = Math_Clamp(RoundToNearest(g_iAngHUDColors[iClient][0] * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);
		g_iAngHUDColorsAlphaMultiplied[iClient][1] = Math_Clamp(RoundToNearest(g_iAngHUDColors[iClient][1] * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);
		g_iAngHUDColorsAlphaMultiplied[iClient][2] = Math_Clamp(RoundToNearest(g_iAngHUDColors[iClient][2] * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);
	} else {
		g_iAngHUDColors[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
		g_iAngHUDColorsAlphaMultiplied[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
	}

	g_iMode[iClient] = DISPLAY;
	g_iFocus[iClient] =  { 0, 0 };
	g_iKeysTarget[iClient] = 0;
	g_iAngTarget[iClient] = 0;

	g_iLastUpdate[iClient] =  { 0, 0, 0 };
}

public Action OnPlayerRunCmd(int iClient, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon, int &iSubType, int &iCmdNum, int &iTickCount, int &iSeed, int iMouse[2]) {
	if (!IsClientInGame(iClient)) {
		return Plugin_Continue;
	}

	switch (g_iMode[iClient]) {
		case DISPLAY: {
			int iObsTarget = iClient;
			int iBtns = iButtons;

			if (g_iKeysTarget[iClient]) {
				if (IsClientInGame(g_iKeysTarget[iClient])) {
					iObsTarget = g_iKeysTarget[iClient];
					iBtns = GetClientButtons(iObsTarget);
				} else {
					g_iKeysTarget[iClient] = 0;
				}
			} else if (TF2_GetClientTeam(iClient) == TFTeam_Spectator) {
				Obs_Mode iObserverMode = Client_GetObserverMode(iClient);
				if (iObserverMode == OBS_MODE_IN_EYE || iObserverMode == OBS_MODE_CHASE) {
					iObsTarget = Client_GetObserverTarget(iClient);
					if (!Client_IsValid(iObsTarget)) {
						return Plugin_Continue;
					}
						iBtns = GetClientButtons(iObsTarget);
				} else if (iObsTarget == iClient) {
					return Plugin_Continue;
				}
			}

			if (g_bKeysEnabled[iClient] && (g_iLastUpdate[iObsTarget][LASTUPDATE_BTN] != iButtons || (iTickCount - g_iLastUpdate[iObsTarget][LASTUPDATE_TICK_KEY] >= TEXT_WAIT_FRAME))) {
				g_iLastUpdate[iObsTarget][LASTUPDATE_BTN] = iButtons;
				g_iLastUpdate[iObsTarget][LASTUPDATE_TICK_KEY] = iTickCount;

				if (iBtns & (IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_ATTACK | IN_ATTACK2 | IN_DUCK | IN_JUMP)) {
					char sM1[16], sM2[16];
					char sJump[16], sDuck[16];
					char sForward[4], sBack[4], sLeft[4], sRight[4];

					FormatEx(sForward,	sizeof(sForward),	iBtns & IN_FORWARD		? "W" : "\t\t\t");
					FormatEx(sBack,		sizeof(sBack),		iBtns & IN_BACK			? "S" : "\t");
					FormatEx(sLeft,		sizeof(sLeft),		iBtns & IN_MOVELEFT		? "A" : "\t\t");
					FormatEx(sRight,	sizeof(sRight),		iBtns & IN_MOVERIGHT	? "D" : "\t\t");

					FormatEx(sM1, sizeof(sM1), iBtns & IN_ATTACK  ? "%T" : "\t\t\t", "Mouse1", iClient);
					FormatEx(sM2, sizeof(sM2), iBtns & IN_ATTACK2 ? "%T" : "\t\t\t", "Mouse2", iClient);

					FormatEx(sJump, sizeof(sJump), iBtns & IN_JUMP? "%T" : NULL_STRING, "Jump", iClient);
					FormatEx(sDuck, sizeof(sDuck), iBtns & IN_DUCK? "%T" : NULL_STRING, "Duck", iClient);

					char sKeys[128];
					FormatEx(sKeys, sizeof(sKeys), "%10s%8s%s\n%8s%2s%2s%6s%s", sM1, sForward, sJump, sM2, sLeft, sBack, sRight, sDuck);

					SetHudTextParams(g_fKeysHUDCoords[iClient][0] - 0.05, g_fKeysHUDCoords[iClient][1], TEXT_HOLD_TIME, g_iKeysHUDColorsAlphaMultiplied[iClient][0], g_iKeysHUDColorsAlphaMultiplied[iClient][1], g_iKeysHUDColorsAlphaMultiplied[iClient][2], 255, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(iClient, g_hKeysHudText, sKeys);
				} else {
					SetHudTextParams(0.0, 0.0, 0.0, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0);
					ShowSyncHudText(iClient, g_hKeysHudText, NULL_STRING);
				}
			}

			if (g_bAngEnabled[iClient] && (iTickCount - g_iLastUpdate[iObsTarget][LASTUPDATE_TICK_ANG] >= TEXT_WAIT_FRAME)) {
				g_iLastUpdate[iObsTarget][LASTUPDATE_TICK_ANG] = iTickCount;

				char sAngBuf[128];

				float fEyeAng[3];
				char sEyeAng[2][32];
				char sEyeAngFrac[2][32];

				GetClientEyeAngles(iObsTarget, fEyeAng);
				GetFloatWhole(fEyeAng[0], 3, sEyeAng[0], 32);
				GetFloatWhole(fEyeAng[1], 4, sEyeAng[1], 32);
				GetFloatFraction(fEyeAng[0], 2, sEyeAngFrac[0], 32);
				GetFloatFraction(fEyeAng[1], 2, sEyeAngFrac[1], 32);

				float fOrigin[3], fHit[3], fHitTrig[3], fTraceAng[3];
				int iHeight;
				float fMins[3], fMaxs[3];
				GetEntPropVector(iClient, Prop_Data, "m_vecMins", fMins);
				GetEntPropVector(iClient, Prop_Data, "m_vecMaxs", fMaxs);
				GetClientAbsOrigin(iClient, fOrigin);
				fTraceAng[0] = fOrigin[0];
				fTraceAng[1] = fOrigin[1];
				fTraceAng[2] = -999999.0;
				
				// Trace
				TR_TraceHullFilter(fOrigin, fTraceAng, fMins, fMaxs, MASK_ALL, FilterHeight);
				if(TR_DidHit())
					TR_GetEndPosition(fHit);

				// Trigger Trace
				TR_EnumerateEntitiesHull(fOrigin, fTraceAng, fMins, fMaxs, PARTITION_TRIGGER_EDICTS, EnumerateHeight);
				if(TR_DidHit())
					TR_GetEndPosition(fHitTrig);

				if (fHitTrig[2] > fHit[2])
					fHit[2] = fHitTrig[2];

				iHeight = RoundToNearest(fOrigin[2] - fHit[2]);

				char sLabelAng[32], sLabelHght[32], sValVert[32], sValHoriz[32], sValHght[32];
				Format(sLabelAng, sizeof(sLabelAng), "Ang: ");
				Format(sLabelHght, sizeof(sLabelHght), "\nHeight: ");
				Format(sValVert, sizeof(sValVert), "%s.%s ", sEyeAng[0], sEyeAngFrac[0]);
				Format(sValHoriz, sizeof(sValHoriz), "%s.%s", sEyeAng[1], sEyeAngFrac[1]);
				Format(sValHght, sizeof(sValHght), "%i", iHeight);

				if (g_bAngValues[iClient][ANGVALUE_VERTICAL] || g_bAngValues[iClient][ANGVALUE_HORIZONTAL])
					Format(sAngBuf, sizeof(sAngBuf), "%s%s", sAngBuf, sLabelAng);
				
				if (g_bAngValues[iClient][ANGVALUE_VERTICAL])
					Format(sAngBuf, sizeof(sAngBuf), "%s%s", sAngBuf, sValVert);

				if (g_bAngValues[iClient][ANGVALUE_HORIZONTAL])
					Format(sAngBuf, sizeof(sAngBuf), "%s%s", sAngBuf, sValHoriz);

				if (g_bAngValues[iClient][ANGVALUE_HEIGHT])
					Format(sAngBuf, sizeof(sAngBuf), "%s%s%s", sAngBuf, sLabelHght, sValHght);

				SetHudTextParams(g_fAngHUDCoords[iClient][0] - 0.05, g_fAngHUDCoords[iClient][1], TEXT_HOLD_TIME, g_iAngHUDColorsAlphaMultiplied[iClient][0], g_iAngHUDColorsAlphaMultiplied[iClient][1], g_iAngHUDColorsAlphaMultiplied[iClient][2], 255, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(iClient, g_hAngHudText, sAngBuf);
			}
		}

		case EDIT_KEY_COORDS, EDIT_ANG_COORDS, EDIT_KEY_COLORS, EDIT_ANG_COLORS: {
			switch (g_iMode[iClient]) {
				case EDIT_KEY_COORDS: {
					g_fKeysHUDCoords[iClient][0] = Math_Clamp(g_fKeysHUDCoords[iClient][0] + 0.0005 * iMouse[0], 0.05, 0.9);
					g_fKeysHUDCoords[iClient][1] = Math_Clamp(g_fKeysHUDCoords[iClient][1] + 0.0005 * iMouse[1], 0.0, 1.0);

					if (iButtons & IN_ATTACK) {
						SetCookieFloat2D(iClient, g_hCookieKeysCoords, g_fKeysHUDCoords[iClient][0], g_fKeysHUDCoords[iClient][1]);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					} else if (iButtons & IN_ATTACK2) {
						GetCookieFloat2D(iClient, g_hCookieKeysCoords, g_fKeysHUDCoords[iClient][0], g_fKeysHUDCoords[iClient][1]);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					} else if (iButtons & IN_ATTACK3) {
						g_fKeysHUDCoords[iClient] = view_as<float>({DEFAULT_KEY_COORD_X, DEFAULT_KEY_COORD_Y});

						SetCookieFloat2D(iClient, g_hCookieKeysCoords, DEFAULT_KEY_COORD_X, DEFAULT_KEY_COORD_Y);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					}
				}
				
				case EDIT_ANG_COORDS: {
					g_fAngHUDCoords[iClient][0] = Math_Clamp(g_fAngHUDCoords[iClient][0] + 0.0005 * iMouse[0], 0.05, 0.9);
					g_fAngHUDCoords[iClient][1] = Math_Clamp(g_fAngHUDCoords[iClient][1] + 0.0005 * iMouse[1], 0.0, 1.0);

					if (iButtons & IN_ATTACK) {
						SetCookieFloat2D(iClient, g_hCookieAngCoords, g_fAngHUDCoords[iClient][0], g_fAngHUDCoords[iClient][1]);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					} else if (iButtons & IN_ATTACK2) {
						GetCookieFloat2D(iClient, g_hCookieAngCoords, g_fAngHUDCoords[iClient][0], g_fAngHUDCoords[iClient][1]);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					} else if (iButtons & IN_ATTACK3) {
						g_fAngHUDCoords[iClient] = view_as<float>({DEFAULT_ANG_COORD_X, DEFAULT_ANG_COORD_Y});

						SetCookieFloat2D(iClient, g_hCookieAngCoords, DEFAULT_ANG_COORD_X, DEFAULT_ANG_COORD_Y);
						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
					}
				}

				case EDIT_KEY_COLORS: {
					static char sBuffer[254];
					static char sBar[4][64];

					g_iKeysHUDColorsAlphaMultiplied[iClient][0] = Math_Clamp(RoundToNearest((g_iKeysHUDColors[iClient][0] + 0.05 * iMouse[0]) * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);
					g_iKeysHUDColorsAlphaMultiplied[iClient][1] = Math_Clamp(RoundToNearest((g_iKeysHUDColors[iClient][1] + 0.05 * iMouse[0]) * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);
					g_iKeysHUDColorsAlphaMultiplied[iClient][2] = Math_Clamp(RoundToNearest((g_iKeysHUDColors[iClient][2] + 0.05 * iMouse[0]) * g_iKeysHUDColors[iClient][3] / 255.0), 0, 255);

					g_iKeysHUDColors[iClient][g_iFocus[iClient][0]] = Math_Clamp(RoundToNearest(g_iKeysHUDColors[iClient][g_iFocus[iClient][0]] + 0.05 * iMouse[0]), 0, 255);


					for (int i = 0; i < 4; i++) {
						sBar[i][0] = '\0';

						int j = 0;
						for (j = 1; j <= RoundToFloor(float(g_iKeysHUDColors[iClient][i])/8.0) && j <= 32; j++) {
							sBar[i][j-1] = '|';
						}
						sBar[i][j] = '\0';

					}

					Handle hMessage = StartMessageOne("KeyHintText", iClient);
					BfWriteByte(hMessage, 1);
					FormatEx(sBuffer, sizeof(sBuffer),	"%60s\n\n" ...
														"%sR: %02X  %s\n" ... 
														"%sG: %02X  %s\n" ... 
														"%sB: %02X  %s\n" ...
														"%sA: %02X  %s",
														"Show Keys Color",
														(g_iFocus[iClient][0] == 0 ? ">" : "  "), g_iKeysHUDColors[iClient][0], sBar[0],
														(g_iFocus[iClient][0] == 1 ? ">" : "  "), g_iKeysHUDColors[iClient][1], sBar[1],
														(g_iFocus[iClient][0] == 2 ? ">" : "  "), g_iKeysHUDColors[iClient][2], sBar[2],
														(g_iFocus[iClient][0] == 3 ? ">" : "  "), g_iKeysHUDColors[iClient][3], sBar[3]);

					BfWriteString(hMessage, sBuffer);
					EndMessage();

					if (iButtons & IN_ATTACK) {

						int iTick = GetGameTickCount();
						if (iTick - g_iFocus[iClient][1] > 10) {
							g_iFocus[iClient][0] = g_iFocus[iClient][0] + 1;

							if (g_iFocus[iClient][0] == 4) {
								SetCookieRGBA(iClient, g_hCookieKeysColor, g_iKeysHUDColors[iClient][0], g_iKeysHUDColors[iClient][1], g_iKeysHUDColors[iClient][2], g_iKeysHUDColors[iClient][3]);
								g_iMode[iClient] = DISPLAY;

								CreateTimer(0.2, Timer_Unfreeze, iClient);
								hMessage = StartMessageOne("KeyHintText", iClient);
								BfWriteByte(hMessage, 1);
								BfWriteString(hMessage, " ");
								EndMessage();
							}


							g_iFocus[iClient][0] = g_iFocus[iClient][0] % 4;
							g_iFocus[iClient][1] = iTick;
						}
					} else if (iButtons & IN_ATTACK2) {
						int iTick = GetGameTickCount();
						if (iTick - g_iFocus[iClient][1] > 10) {
							g_iFocus[iClient][0] = Math_Min(g_iFocus[iClient][0] - 1, 0);
							g_iFocus[iClient][1] = iTick;
						}

					} else if (iButtons & IN_ATTACK3) {
						g_iKeysHUDColors[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
						g_iKeysHUDColorsAlphaMultiplied[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
						SetCookieRGBA(iClient, g_hCookieKeysColor, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA);

						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
						hMessage = StartMessageOne("KeyHintText", iClient);
						BfWriteByte(hMessage, 1);
						BfWriteString(hMessage, " ");
						EndMessage();
					}
				}

				case EDIT_ANG_COLORS: {
					static char sBuffer[254];
					static char sBar[4][64];

					g_iAngHUDColorsAlphaMultiplied[iClient][0] = Math_Clamp(RoundToNearest((g_iAngHUDColors[iClient][0] + 0.05 * iMouse[0]) * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);
					g_iAngHUDColorsAlphaMultiplied[iClient][1] = Math_Clamp(RoundToNearest((g_iAngHUDColors[iClient][1] + 0.05 * iMouse[0]) * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);
					g_iAngHUDColorsAlphaMultiplied[iClient][2] = Math_Clamp(RoundToNearest((g_iAngHUDColors[iClient][2] + 0.05 * iMouse[0]) * g_iAngHUDColors[iClient][3] / 255.0), 0, 255);

					g_iAngHUDColors[iClient][g_iFocus[iClient][0]] = Math_Clamp(RoundToNearest(g_iAngHUDColors[iClient][g_iFocus[iClient][0]] + 0.05 * iMouse[0]), 0, 255);


					for (int i = 0; i < 4; i++) {
						sBar[i][0] = '\0';

						int j = 0;
						for (j = 1; j <= RoundToFloor(float(g_iAngHUDColors[iClient][i])/8.0) && j <= 32; j++) {
							sBar[i][j-1] = '|';
						}
						sBar[i][j] = '\0';

					}

					Handle hMessage = StartMessageOne("KeyHintText", iClient);
					BfWriteByte(hMessage, 1);
					FormatEx(sBuffer, sizeof(sBuffer),	"%60s\n\n" ...
														"%sR: %02X  %s\n" ... 
														"%sG: %02X  %s\n" ... 
														"%sB: %02X  %s\n" ...
														"%sA: %02X  %s",
														"Show Ang Color",
														(g_iFocus[iClient][0] == 0 ? ">" : "  "), g_iAngHUDColors[iClient][0], sBar[0],
														(g_iFocus[iClient][0] == 1 ? ">" : "  "), g_iAngHUDColors[iClient][1], sBar[1],
														(g_iFocus[iClient][0] == 2 ? ">" : "  "), g_iAngHUDColors[iClient][2], sBar[2],
														(g_iFocus[iClient][0] == 3 ? ">" : "  "), g_iAngHUDColors[iClient][3], sBar[3]);

					BfWriteString(hMessage, sBuffer);
					EndMessage();

					if (iButtons & IN_ATTACK) {

						int iTick = GetGameTickCount();
						if (iTick - g_iFocus[iClient][1] > 10) {
							g_iFocus[iClient][0] = g_iFocus[iClient][0] + 1;

							if (g_iFocus[iClient][0] == 4) {
								SetCookieRGBA(iClient, g_hCookieAngColor, g_iAngHUDColors[iClient][0], g_iAngHUDColors[iClient][1], g_iAngHUDColors[iClient][2], g_iAngHUDColors[iClient][3]);
								g_iMode[iClient] = DISPLAY;

								CreateTimer(0.2, Timer_Unfreeze, iClient);
								hMessage = StartMessageOne("KeyHintText", iClient);
								BfWriteByte(hMessage, 1);
								BfWriteString(hMessage, " ");
								EndMessage();
							}


							g_iFocus[iClient][0] = g_iFocus[iClient][0] % 4;
							g_iFocus[iClient][1] = iTick;
						}
					} else if (iButtons & IN_ATTACK2) {
						int iTick = GetGameTickCount();
						if (iTick - g_iFocus[iClient][1] > 10) {
							g_iFocus[iClient][0] = Math_Min(g_iFocus[iClient][0] - 1, 0);
							g_iFocus[iClient][1] = iTick;
						}

					} else if (iButtons & IN_ATTACK3) {
						g_iAngHUDColors[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
						g_iAngHUDColorsAlphaMultiplied[iClient] =  { DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA };
						SetCookieRGBA(iClient, g_hCookieAngColor, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA, DEFAULT_RGBA);

						g_iMode[iClient] = DISPLAY;

						CreateTimer(0.2, Timer_Unfreeze, iClient);
						hMessage = StartMessageOne("KeyHintText", iClient);
						BfWriteByte(hMessage, 1);
						BfWriteString(hMessage, " ");
						EndMessage();
					}
				}
			}


			char sM1[16], sM2[16];
			char sJump[16], sDuck[16];

			FormatEx(sM1, sizeof(sM1), "%T", "Mouse1", iClient);
			FormatEx(sM2, sizeof(sM2), "%T", "Mouse2", iClient);

			FormatEx(sJump, sizeof(sJump), "%T", "Jump", iClient);
			FormatEx(sDuck, sizeof(sDuck), "%T", "Duck", iClient);

			char sKeys[128], sAng[128];
			FormatEx(sKeys, sizeof(sKeys), "%10s%8s%s\n%8s%2s%2s%6s%s", sM1, "W", sJump, sM2, "A", "S", "D", sDuck);
			FormatEx(sAng, sizeof(sAng), "Ang: 		0.00 			0.00\nHeight: 0");

			if (g_bKeysEnabled[iClient] || g_iMode[iClient] == EDIT_KEY_COORDS || g_iMode[iClient] == EDIT_KEY_COLORS) {
				SetHudTextParams(g_fKeysHUDCoords[iClient][0] - 0.05, g_fKeysHUDCoords[iClient][1], TEXT_HOLD_TIME, g_iKeysHUDColorsAlphaMultiplied[iClient][0], g_iKeysHUDColorsAlphaMultiplied[iClient][1], g_iKeysHUDColorsAlphaMultiplied[iClient][2], 255, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(iClient, g_hKeysHudText, sKeys);
			}

			if (g_bAngEnabled[iClient] || g_iMode[iClient] == EDIT_ANG_COORDS || g_iMode[iClient] == EDIT_ANG_COLORS) {
				SetHudTextParams(g_fAngHUDCoords[iClient][0] - 0.05, g_fAngHUDCoords[iClient][1], TEXT_HOLD_TIME, g_iAngHUDColorsAlphaMultiplied[iClient][0], g_iAngHUDColorsAlphaMultiplied[iClient][1], g_iAngHUDColorsAlphaMultiplied[iClient][2], 255, 0, 0.0, 0.0, 0.0);
				ShowSyncHudText(iClient, g_hAngHudText, sAng);
			}
		}
	}

	return Plugin_Continue;
}

// Custom callbacks

public Action Event_PlayerSpawn(Event hEvent, const char[] sName, bool bDontBroadcast) {
	int iClient = GetClientOfUserId(hEvent.GetInt("userid"));
	if (!iClient) {
		return Plugin_Handled;
	}

	g_iMode[iClient] = DISPLAY;

	return Plugin_Continue;
}

public Action Timer_Unfreeze(Handle hTimer, any aData) {
	SetEntityFlags(aData, GetEntityFlags(aData) & ~(FL_ATCONTROLS | FL_FROZEN));

	return Plugin_Handled;
}

// Natives
public int Native_ForceShowKeys(Handle hPlugin, int iArgC) {
	int iClient = GetNativeCell(1);
	if (iClient >= 1 && iClient <= MaxClients) {
		g_iKeysTarget[iClient] = GetNativeCell(2);
		g_bKeysEnabled[iClient] = true;
	}

	return 0;
}

public int Native_ResetShowKeys(Handle hPlugin, int iArgC) {
	int iClient = GetNativeCell(1);
	if (iClient >= 1 && iClient <= MaxClients) {
		if (!GetCookieBool(iClient, g_hCookieKeysEnabled, g_bKeysEnabled[iClient])) {
			g_bKeysEnabled[iClient] = false;
		}

		g_iKeysTarget[iClient] = 0;
	}

	return 0;
}

// Commands

public Action cmdShowKeys(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	if (iArgC == 0) {
		g_bKeysEnabled[iClient] = !g_bKeysEnabled[iClient];
		CPrintToChat(iClient, "{dodgerblue}[jse] {white}Show keys %s.", g_bKeysEnabled[iClient] ? "enabled" : "disabled");
		g_iKeysTarget[iClient] = 0;
	} else {
		char sArg1[32];
		GetCmdArg(1, sArg1, sizeof(sArg1));

		int iTarget = FindTarget(iClient, sArg1, false, false);
		if (iTarget != -1) {
			g_iKeysTarget[iClient] = iTarget;
			g_bKeysEnabled[iClient] = true;
			CPrintToChat(iClient, "{dodgerblue}[jse] {white}Showing keys for {limegreen}%N{white}.", iTarget);
		} else {
			g_bKeysEnabled[iClient] = false;
		}
	}

	if (!g_bKeysEnabled[iClient]) {
		g_iKeysTarget[iClient] = 0;
	}

	g_hCookieKeysEnabled.Set(iClient, g_bKeysEnabled[iClient] ? "1" : "0");

	return Plugin_Handled;
}

public Action cmdShowKeysCoords(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	switch (g_iMode[iClient]) {
		case EDIT_KEY_COORDS: {
			g_iMode[iClient] = DISPLAY;
			SetEntityFlags(iClient, GetEntityFlags(iClient) & ~(FL_ATCONTROLS | FL_FROZEN));
		}
		case DISPLAY: {
			g_iMode[iClient] = EDIT_KEY_COORDS;
			SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_ATCONTROLS | FL_FROZEN);
		}
	}

	return Plugin_Handled;
}

public Action cmdShowKeysColors(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	switch (g_iMode[iClient]) {
		case EDIT_KEY_COLORS: {
			g_iMode[iClient] = DISPLAY;
			SetEntityFlags(iClient, GetEntityFlags(iClient) & ~(FL_ATCONTROLS | FL_FROZEN));
		}
		case DISPLAY: {
			g_iMode[iClient] = EDIT_KEY_COLORS;
			g_iFocus[iClient] =  { 0, 0 };

			SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_ATCONTROLS | FL_FROZEN);
		}
	}

	return Plugin_Handled;
}

public Action cmdShowKeysOptions(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	SendKeysOptionsPanel(iClient);
	return Plugin_Handled;
}

public Action cmdShowAng(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	if (iArgC == 0) {
		g_bAngEnabled[iClient] = !g_bAngEnabled[iClient];
		CPrintToChat(iClient, "{dodgerblue}[jse] {white}Show angles %s.", g_bAngEnabled[iClient] ? "enabled" : "disabled");
		g_iAngTarget[iClient] = 0;
	} else {
		char sArg1[32];
		GetCmdArg(1, sArg1, sizeof(sArg1));

		int iTarget = FindTarget(iClient, sArg1, false, false);
		if (iTarget != -1) {
			g_iAngTarget[iClient] = iTarget;
			g_bAngEnabled[iClient] = true;
			CPrintToChat(iClient, "{dodgerblue}[jse] {white}Showing angles for {limegreen}%N{white}.", iTarget);
		} else {
			g_bAngEnabled[iClient] = false;
		}
	}

	if (!g_bAngEnabled[iClient]) {
		g_iAngTarget[iClient] = 0;
	}

	g_hCookieAngEnabled.Set(iClient, g_bAngEnabled[iClient] ? "1" : "0");

	return Plugin_Handled;
}

public Action cmdShowAngCoords(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	switch (g_iMode[iClient]) {
		case EDIT_ANG_COORDS: {
			g_iMode[iClient] = DISPLAY;
			SetEntityFlags(iClient, GetEntityFlags(iClient) & ~(FL_ATCONTROLS | FL_FROZEN));
		}
		case DISPLAY: {
			g_iMode[iClient] = EDIT_ANG_COORDS;
			SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_ATCONTROLS | FL_FROZEN);
		}
	}

	return Plugin_Handled;
}

public Action cmdShowAngColors(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	switch (g_iMode[iClient]) {
		case EDIT_ANG_COLORS: {
			g_iMode[iClient] = DISPLAY;
			SetEntityFlags(iClient, GetEntityFlags(iClient) & ~(FL_ATCONTROLS | FL_FROZEN));
		}
		case DISPLAY: {
			g_iMode[iClient] = EDIT_ANG_COLORS;
			g_iFocus[iClient] =  { 0, 0 };

			SetEntityFlags(iClient, GetEntityFlags(iClient) | FL_ATCONTROLS | FL_FROZEN);
		}
	}

	return Plugin_Handled;
}

public Action cmdShowAngOptions(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	SendAngOptionsPanel(iClient);
	return Plugin_Handled;
}

public Action cmdShowAngValues(int iClient, int iArgC) {
	if (!iClient) {
		ReplyToCommand(iClient, "[jse] You cannot run this command from server console.");
		return Plugin_Handled;
	}

	SendAngValuesPanel(iClient);
	return Plugin_Handled;
}

public Action cmdForceShowKeys(int iClient, int iArgC) {
	if (iArgC != 2) {
		ReplyToCommand(iClient, "[jse] Usage: sm_forceshowkeys <target> <0/1>");
		return Plugin_Handled;
	}

	char sArg1[32];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	char sArg2[32];
	GetCmdArg(2, sArg2, sizeof(sArg2));

	bool bEnabled = StringToInt(sArg2) != 0;

	int iTarget = FindTarget(iClient, sArg1, false, false);
	if (iTarget != -1) {
		g_iKeysTarget[iTarget] = 0;
		g_bKeysEnabled[iTarget] = bEnabled;

		CPrintToChat(iTarget, "{dodgerblue}[jse] {white}Show keys %s.", bEnabled ? "enabled" : "disabled");
		CPrintToChat(iClient, "{dodgerblue}[jse] {white}Show keys %s for {limegreen}%N{white}.", bEnabled ? "enabled" : "disabled", iTarget);

		g_hCookieKeysEnabled.Set(iTarget, bEnabled ? "1" : "0");
	}

	return Plugin_Handled;
}

// Stock

stock bool GetCookieBool(int iClient, Cookie hCookie, bool &bValue) {
	char sBuffer[8];
	hCookie.Get(iClient, sBuffer, sizeof(sBuffer));

	if (sBuffer[0]) {
		bValue = StringToInt(sBuffer) != 0;
		return true;
	}

	return false;
}

stock bool GetCookieFloat2D(int iClient, Cookie hCookie, float &fValueA, float &fValueB) {
	char sBuffer[32];
	hCookie.Get(iClient, sBuffer, sizeof(sBuffer));

	char sFloatBuffers[2][32];
	if (ExplodeString(sBuffer, " ", sFloatBuffers, sizeof(sFloatBuffers), sizeof(sFloatBuffers[]), false) != 2) {
		return false;
	}

	fValueA = StringToFloat(sFloatBuffers[0]);
	fValueB = StringToFloat(sFloatBuffers[1]);

	return true;
}

stock bool GetCookieRGBA(int iClient, Cookie hCookie, int &iValueA, int &iValueB, int &iValueC, int &iValueD) {
	char sBuffer[32];
	hCookie.Get(iClient, sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) != 8) {
		return false;
	}

	int iColor = StringToInt(sBuffer, 16);

	iValueA = (iColor >> 24) & 0xFF;
	iValueB = (iColor >> 16) & 0xFF;
	iValueC = (iColor >>  8) & 0xFF;
	iValueD = (iColor      ) & 0xFF;

	return true;
}

stock void SetCookieFloat2D(int iClient, Cookie hCookie, float fValueA, float fValueB) {
	char sBuffer[32];
	FormatEx(sBuffer, sizeof(sBuffer), "%.4f %.4f", fValueA, fValueB);

	hCookie.Set(iClient, sBuffer);
}

stock void SetCookieRGBA(int iClient, Cookie hCookie, int iValueA, int iValueB, int iValueC, int iValueD) {
	char sBuffer[9];
	FormatEx(sBuffer, sizeof(sBuffer), "%02X%02X%02X%02X", iValueA & 0xFF, iValueB & 0xFF, iValueC & 0xFF, iValueD & 0xFF);

	hCookie.Set(iClient, sBuffer);
}

stock void GetFloatFraction(float fNum, int iDigits, char[] sBuf, int iBufLen) {
	char sNum[32];
	char sFrac[32];
	FloatToString(fNum, sNum, sizeof(sNum));
	int j = 0;
	for (int i = FindCharInString(sNum, '.') + 1; i < strlen(sNum); i++) {
		if (j >= iDigits)
			break;
		sFrac[j] = sNum[i];
		j++;
	}
	sFrac[j] = 0;

	strcopy(sBuf, iBufLen, sFrac);
}

stock void GetFloatWhole(float fNum, int iDigits, char[] sBuf, int iBufLen) {
	char sNum[32];
	char sWhole[32];
	FloatToString(fNum, sNum, sizeof(sNum));
	int j = iDigits - 1;
	for (int i = FindCharInString(sNum, '.') - 1; j >= 0; i--) {
		if (i < 0) {
			sWhole[j] = '	';
		} else {
			sWhole[j] = sNum[i];
		}
		j--;
	}
	sWhole[iDigits] = 0;

	strcopy(sBuf, iBufLen, sWhole);
}

stock void ToggleAngValue(int iClient, int iVal) {
	bool bNoDisable;
	int iDispCount = view_as<int>(g_bAngValues[iClient][ANGVALUE_VERTICAL]) + view_as<int>(g_bAngValues[iClient][ANGVALUE_HORIZONTAL]) + view_as<int>(g_bAngValues[iClient][ANGVALUE_HEIGHT]);
	if (iDispCount < 2)
		bNoDisable = true;

	if (g_bAngValues[iClient][iVal] && !bNoDisable) {
		g_bAngValues[iClient][iVal] = false;
	} else if (!g_bAngValues[iClient][iVal]) {
		g_bAngValues[iClient][iVal] = true;
	}

	switch (iVal) {
		case ANGVALUE_VERTICAL:
			SetClientCookie(iClient, g_hCookieAngDisplayVert, g_bAngValues[iClient][ANGVALUE_VERTICAL] ? "1" : "0");
		case ANGVALUE_HORIZONTAL:
			SetClientCookie(iClient, g_hCookieAngDisplayHoriz, g_bAngValues[iClient][ANGVALUE_HORIZONTAL] ? "1" : "0");
		case ANGVALUE_HEIGHT:
			SetClientCookie(iClient, g_hCookieAngDisplayHght, g_bAngValues[iClient][ANGVALUE_HEIGHT] ? "1" : "0");
	}

	FakeClientCommand(iClient, "sm_showang_values");
}

// Menus

public void CookieMenuHandler_Options(int iClient, CookieMenuAction iAction, any aInfo, char[] sBuffer, int iMaxLength) {
	if (iAction == CookieMenuAction_SelectOption) {
		SendOptionsPanel(iClient);
	}
}

void SendOptionsPanel(int iClient) {
	Menu hMenu = new Menu(MenuHandler_Options);
	hMenu.SetTitle("Show Keys Menu");

	hMenu.AddItem(NULL_STRING, "Show Keys");
	hMenu.AddItem(NULL_STRING, "Show Angles");

	hMenu.Display(iClient, 0);
}

void SendKeysOptionsPanel(int iClient) {
	Menu hMenu = new Menu(MenuHandler_KeysOptions);
	hMenu.SetTitle("Show Keys Settings");

	hMenu.AddItem(NULL_STRING, "Move");
	hMenu.AddItem(NULL_STRING, "Recolor");

	hMenu.Display(iClient, 0);
}

void SendAngOptionsPanel(int iClient) {
	Menu hMenu = new Menu(MenuHandler_AngOptions);
	hMenu.SetTitle("Show Angles Settings");

	hMenu.AddItem(NULL_STRING, "Move");
	hMenu.AddItem(NULL_STRING, "Recolor");
	hMenu.AddItem(NULL_STRING, "Values");

	hMenu.Display(iClient, 0);
}

void SendAngValuesPanel(int iClient) {
	Menu hMenu = new Menu(MenuHandler_AngValues);
	hMenu.SetTitle("Show Angles Values");

	char sVert[32], sHoriz[32], sHght[32];
	Format(sVert, sizeof(sVert), "[%s] Vertical", g_bAngValues[iClient][ANGVALUE_VERTICAL] ? "x" : "  ");
	Format(sHoriz, sizeof(sVert), "[%s] Horizontal", g_bAngValues[iClient][ANGVALUE_HORIZONTAL] ? "x" : "  ");
	Format(sHght, sizeof(sVert), "[%s] Height", g_bAngValues[iClient][ANGVALUE_HEIGHT] ? "x" : "  ");

	hMenu.AddItem(NULL_STRING, sVert);
	hMenu.AddItem(NULL_STRING, sHoriz);
	hMenu.AddItem(NULL_STRING, sHght);

	hMenu.Display(iClient, 0);
}

public int MenuHandler_Options(Menu hMenu, MenuAction iAction, int iClient, int iOption) {
	switch (iAction) {
		case MenuAction_Select: {
			switch (iOption) {
				case 0: {
					FakeClientCommand(iClient, "sm_showkeys_options");
				}
				case 1: {
					FakeClientCommand(iClient, "sm_showang_options");
				}
			}
		}

		case MenuAction_End: {
			delete hMenu;
		}

	}

	return 0;
}

public int MenuHandler_KeysOptions(Menu hMenu, MenuAction iAction, int iClient, int iOption) {
	switch (iAction) {
		case MenuAction_Select: {
			switch (iOption) {
				case 0: {
					// Move
					FakeClientCommand(iClient, "sm_showkeys_coords");
				}
				case 1: {
					// Recolor
					FakeClientCommand(iClient, "sm_showkeys_colors");
				}
			}
		}

		case MenuAction_End: {
			delete hMenu;
		}

	}

	return 0;
}

public int MenuHandler_AngOptions(Menu hMenu, MenuAction iAction, int iClient, int iOption) {
	switch (iAction) {
		case MenuAction_Select: {
			switch (iOption) {
				case 0: {
					// Move
					FakeClientCommand(iClient, "sm_showang_coords");
				}
				case 1: {
					// Recolor
					FakeClientCommand(iClient, "sm_showang_colors");
				}
				case 2: {
					// Values
					FakeClientCommand(iClient, "sm_showang_values");
				}
			}
		}

		case MenuAction_End: {
			delete hMenu;
		}

	}

	return 0;
}

public int MenuHandler_AngValues(Menu hMenu, MenuAction iAction, int iClient, int iOption) {
	switch (iAction) {
		case MenuAction_Select: {
			switch (iOption) {
				case 0: {
					ToggleAngValue(iClient, ANGVALUE_VERTICAL);
				}
				case 1: {
					ToggleAngValue(iClient, ANGVALUE_HORIZONTAL);
				}
				case 2: {
					ToggleAngValue(iClient, ANGVALUE_HEIGHT);
				}
			}
		}

		case MenuAction_End: {
			delete hMenu;
		}

	}

	return 0;
}

// Trace Filters

public bool FilterHeight(int iEntity, int iContentsMask) {
	if (iEntity != 0 && iEntity <= MaxClients)
		return false;

	char sName[64];
	GetEntityClassname(iEntity, sName, sizeof(sName) );	
	if(StrContains(sName, "projectile" ) != -1)
		return false;
	
	return true;
}

public bool EnumerateHeight(int iEntity) {
	char sName[64];
	GetEntityClassname(iEntity, sName, sizeof(sName) );	
	if(StrContains(sName, "trigger_teleport" ) != -1)
	{
		TR_ClipCurrentRayToEntity(MASK_ALL, iEntity);
		
		if (TR_DidHit()) {
			return false;
		}
	}

	return true;
}