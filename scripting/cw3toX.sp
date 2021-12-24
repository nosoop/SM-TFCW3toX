#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#include <dhooks>
#include <sdkhooks>

#include <tf_econ_data>
#include <tf2utils>
#include <cwx>

public Plugin myinfo = {
	name = "[TF2] Custom Weapons X - Custom Weapons 3 Attribute Adapter",
	author = "nosoop",
	description = "Allows use of Custom Weapons 3 attributes in CWX.",
	version = "0.0.0",
	url = "https://github.com/nosoop/SM-TFCW3ToX"
};

#define CW3_LAST_SLOT 4

#define MAX_CW3_ATTR_NAME_LENGTH 64
#define MAX_CW3_PLUGIN_NAME_LENGTH 64
#define MAX_CW3_ATTR_VALUE_LENGTH PLATFORM_MAX_PATH + 64

GlobalForward g_FwdAddAttribute;
GlobalForward g_FwdWeaponRemoved;

DynamicHook g_HookWearableEquip;
DynamicHook g_HookWearableRemove;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	RegPluginLibrary("cw3-attributes");
	
	CreateNative("CW3_AddAttribute", Native_CW3AddAttribute);
	CreateNative("CW3_ResetAttribute", Native_CW3ResetAttribute);
}

public void OnPluginStart() {
	Handle hGameConf = LoadGameConfigFile("tf2.cw3toX");
	if (!hGameConf) {
		SetFailState("Failed to load gamedata (tf2.cw3toX).");
	}
	
	Handle dtWeaponDetach = DHookCreateFromConf(hGameConf,
			"CBaseCombatCharacter::Weapon_Detach()");
	if (!dtWeaponDetach) {
		SetFailState("Failed to create detour " ... "CBaseCombatCharacter::Weapon_Detach()");
	}
	DHookEnableDetour(dtWeaponDetach, false, OnPlayerWeaponRemoved);
	
	g_HookWearableEquip = DynamicHook.FromConf(hGameConf, "CBasePlayer::EquipWearable()");
	if (!g_HookWearableEquip) {
		SetFailState("Failed to create virtual hook " ... "CBasePlayer::EquipWearable()");
	}
	
	g_HookWearableRemove = DynamicHook.FromConf(hGameConf, "CBasePlayer::RemoveWearable()");
	if (!g_HookWearableRemove) {
		SetFailState("Failed to create virtual hook " ... "CBasePlayer::RemoveWearable()");
	}
	
	delete hGameConf;
	
	g_FwdAddAttribute = CreateGlobalForward("CW3_OnAddAttribute", ET_Event, Param_Cell,
			Param_Cell, Param_String, Param_String, Param_String, Param_Cell);
	g_FwdWeaponRemoved = CreateGlobalForward("CW3_OnWeaponRemoved", ET_Ignore, Param_Cell,
			Param_Cell);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnPluginEnd() {
	// clear CW3 attributes from slots
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		
		for (int s; s <= CW3_LAST_SLOT; s++) {
			CallCW3WeaponRemoved(i, s);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquipPost);
	
	g_HookWearableEquip.HookEntity(Hook_Post, client, OnPlayerWearableEquipped);
	g_HookWearableRemove.HookEntity(Hook_Post, client, OnPlayerWearableRemoved);
}

void OnWeaponEquipPost(int client, int weapon) {
	ProcessEquippedItem(client, weapon);
}

MRESReturn OnPlayerWeaponRemoved(int client, DHookParam hParams) {
	int weapon = hParams.Get(1);
	ProcessRemovedItem(client, weapon);
	return MRES_Ignored;
}

MRESReturn OnPlayerWearableEquipped(int client, DHookParam hParams) {
	int wearable = hParams.Get(1);
	ProcessEquippedItem(client, wearable);
	return MRES_Ignored;
}

MRESReturn OnPlayerWearableRemoved(int client, DHookParam hParams) {
	int wearable = hParams.Get(1);
	ProcessRemovedItem(client, wearable);
	return MRES_Ignored;
}

/**
 * Handles an item that was equipped by a player.  Item can be a weapon or cosmetic.
 */
void ProcessEquippedItem(int client, int item) {
	int slot = GetItemWeaponSlot(item);
	if (slot < 0 || slot > CW3_LAST_SLOT) {
		return;
	}
	
	char uid[64];
	if (CWX_GetItemUIDFromEntity(item, uid, sizeof(uid))) {
		KeyValues attributeData = CWX_GetItemExtData(uid, "cw3_attributes");
		if (attributeData) {
			char attrib[MAX_CW3_ATTR_NAME_LENGTH];
			char value[MAX_CW3_ATTR_VALUE_LENGTH];
			char pluginName[MAX_CW3_PLUGIN_NAME_LENGTH];
			
			attributeData.GotoFirstSubKey();
			do
			{
				attributeData.GetSectionName(attrib, sizeof(attrib));
				attributeData.GetString("plugin", pluginName, sizeof(pluginName));
				attributeData.GetString("value", value, sizeof(value));
				bool whileActive = !!attributeData.GetNum("while active");
				
				CallCW3AddAttribute(client, slot, attrib, pluginName, value, whileActive);
			} while(attributeData.GotoNextKey());
			delete attributeData;
		}
	}
	// TODO maybe support CW3 here? I think they should be initialized at this point
}

/**
 * Handles an item that has been removed from a player.
 */
void ProcessRemovedItem(int client, int item) {
	int slot = GetItemWeaponSlot(item);
	if (slot < 0 || slot > CW3_LAST_SLOT) {
		return;
	}
	
	CallCW3WeaponRemoved(client, slot);
}

/**
 * Returns the weapon slot associated with an item.  Custom Weapons 3 attributes depend on
 * wearables being in the slot that would normally be occupied by a weapon.
 */
int GetItemWeaponSlot(int item) {
	if (!IsValidEntity(item)) {
		return -1;
	} else if (TF2Util_IsEntityWearable(item)) {
		int itemdef = GetEntProp(item, Prop_Send, "m_iItemDefinitionIndex");
		
		// hack: we assume this slot matches the weapon slot it would be in
		// normally you shouldn't mix loadout slots and weapon slots
		return TF2Econ_GetItemDefaultLoadoutSlot(itemdef);
	} else if (TF2Util_IsEntityWeapon(item)) {
		return TF2Util_GetWeaponSlot(item);
	}
	return -1;
}

bool CallCW3AddAttribute(int client, int slot, const char[] attrib, const char[] plugin,
		const char[] value, bool whileActive) {
	Call_StartForward(g_FwdAddAttribute);
	Call_PushCell(slot);
	Call_PushCell(client);
	Call_PushString(attrib);
	Call_PushString(plugin);
	Call_PushString(value);
	Call_PushCell(whileActive);
	
	Action result;
	Call_Finish(result);
	
	if (!result) {
		LogMessage("WARNING! Attribute %s (value \"%s\" plugin \"%s\") "
				... "seems to have been ignored by all attribute plugins. It's either an "
				... "invalid attribute, incorrect plugin, an error occured in the att. plugin, "
				... "or the att. plugin forgot to return Plugin_Handled.",
				attrib, value, plugin);
		return false;
	}
	return true;
}

void CallCW3WeaponRemoved(int client, int slot) {
	Call_StartForward(g_FwdWeaponRemoved);
	Call_PushCell(slot);
	Call_PushCell(client);
	
	Call_Finish();
}

int Native_CW3AddAttribute(Handle plugin, int argc) {
	int slot = GetNativeCell(1);
	int client = GetNativeCell(2);
	bool whileActive = GetNativeCell(6);
	
	char attrib[MAX_CW3_ATTR_NAME_LENGTH];
	GetNativeString(3, attrib, sizeof(attrib));
	
	char value[MAX_CW3_ATTR_VALUE_LENGTH];
	GetNativeString(5, value, sizeof(value));
	
	char pluginName[MAX_CW3_PLUGIN_NAME_LENGTH];
	GetNativeString(4, pluginName, sizeof(pluginName));
	
	return CallCW3AddAttribute(client, slot, attrib, pluginName, value, whileActive);
}

int Native_CW3ResetAttribute(Handle plugin, int argc) {
	int client = GetNativeCell(1);
	int slot = GetNativeCell(2);
	
	CallCW3WeaponRemoved(client, slot);
}
