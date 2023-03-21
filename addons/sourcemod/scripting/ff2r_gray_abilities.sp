/*
	"rage_condition"
	{
		"slot"			"0"		// Ability slot

		"cond"			"33"	// Condition index
		"duration"		"-1.0"	// Duration, -1.0 for infinite
		
		"plugin_name"	"ff2r_gray_abilities"
	}


	"rage_summon"
	{
		"slot"			"0"	// Ability slot

		"amount"		"3"	// Amount of bosses to summon
		"bossdeath"		"2"	// Reaction on owner's death, 0 = Nothing, 1 = MvM Gate Stun, 2 = MvM Gate Bonk Stun, 3 = Death
		
		"character"		"graymann/scoutgiant"	// Character filename or 
		"character"							// a copy of boss config (similar to rage_cloneattack)
		{
			"name"		"Giant Scout"
		}
		
		"plugin_name"	"ff2r_gray_abilities"
	}


	"rage_reaction"
	{
		"slot"					"0"	// Ability slot

		"enemyplayer"			"MP_CONCEPT_MVM_SENTRY_BUSTER"			// Enemy player reaction (SpeakResponseConcept)
		"enemyannouncer"		"sound_reaction_sentrybuster"			// Enemy team's announcer (Boss Sound)
		"enemyannounceragain"	"sound_reaction_sentrybuster_another"	// Enemy team's announcer repeated (Boss Sound)

		"allyplayer"			""	// Ally player reaction (SpeakResponseConcept)
		"allyannouncer"			""	// Ally team's announcer (Boss Sound)
		"allyannounceragain"	""	// Ally team's announcer repeated (Boss Sound)
		
		"plugin_name"			"ff2r_gray_abilities"
	}


	"special_spawn_ability"
	{
		"low"			"11"	// ALowest ability slot to activate on upon respawning
		"high"			"11"	// ALowest ability slot to activate on upon respawning
		
		"plugin_name"	"ff2r_gray_abilities"
	}


	"special_passive_respawns"
	{
		"enemy"			"false"	// Spawn on the enemy team instead

		"modes"
		{
			// Different modes, if more than one exists, adds a reload cycle ability
			"0"
			{
				// Display name
				"name"		"Summoning: Offensive"
				"name_en"	"Summoning: Offensive"

				// Description
				"desc"		"Scout, Soldier, Pyro"
				"desc_en"	"Scout, Soldier, Pyro"

				"summons"
				{
					// Random summon pool
					"0"
					{
						"amount"		"5"	// Amount of bosses to summon
						"bossdeath"		"2"	// Reaction on owner's death, 0 = Nothing, 1 = MvM Gate Stun, 2 = MvM Gate Bonk Stun, 3 = Death

						"character"		"graymann/scoutbot"	// Character filename or 
						"character"							// a copy of boss config (similar to rage_cloneattack)
						{
							"name"		"Scout"
						}
					}
				}
			}
		}
		
		"plugin_name"	"ff2r_gray_abilities"
	}


	"special_robot_effects"
	{
		"giant"			"false"	// Use giant robot logic

		"voice"			"true"	// Replace voice lines
		"bleed"			"true"	// Replace bleeding effect
		"death"			"true"	// Replace death effects
		
		"plugin_name"	"ff2r_gray_abilities"
	}


	"special_summon_bomb"
	{
		"time"			"n*10 + 60"	// Boss lifetime until a bomb to spawns for the next summon
		
		"plugin_name"	"ff2r_gray_abilities"
	}
*/

#include <sourcemod>
#include <sdkhooks>
#include <tf2_stocks>
#include <dhooks>
#include <morecolors>
#include <cfgmap>
#include <ff2r>
#include <tf2items>
#include <tf2attributes>
#include <tf_ontakedamage>
#undef REQUIRE_PLUGIN
#tryinclude <tf2utils>
#tryinclude <tf_custom_attributes>

#pragma semicolon 1
#pragma newdecls required

#include "freak_fortress_2/formula_parser.sp"

#define PLUGIN_VERSION	"Custom"

#define MAXTF2PLAYERS			36
#define FAR_FUTURE				100000000.0
#define TF_TEAM_PVE_INVADERS	3

#define TF2U_LIBRARY	"nosoop_tf2utils"
#define TCA_LIBRARY		"tf2custattr"

#if defined __nosoop_tf2_utils_included
bool TF2ULoaded;
#endif

#if defined __tf_custom_attributes_included
bool TCALoaded;
#endif

Handle SDKEquipWearable;
Handle SDKGetMaxHealth;
Handle SDKSetSpeed;
DynamicHook GetSceneSoundToken;
DynamicHook DeathSound;
Handle SyncHud;

int PlayersAlive[4];
bool SpecTeam;

bool SceneSoundMvMChange;
int SceneSoundTeamChange = -1;
bool SceneSoundBossChange;

int TakeDamageHook;
bool TakeDamageMvMChange;
int TakeDamageTeamChange = -1;
bool TakeDamageBossChange;

bool DeathSoundMvMChange;
int DeathSoundTeamChange = -1;
bool DeathSoundBossChange;

int SceneSoundHookPre[MAXTF2PLAYERS];
int SceneSoundHookPost[MAXTF2PLAYERS];
bool TakeDamageHooked[MAXTF2PLAYERS];
int DeathSoundHookPre[MAXTF2PLAYERS];
int DeathSoundHookPost[MAXTF2PLAYERS];
bool RobotGiant[MAXTF2PLAYERS];

int MinionLastTeam[MAXTF2PLAYERS] = {-1, ...};
int MinionOwner[MAXTF2PLAYERS];
int MinionDeathType[MAXTF2PLAYERS];
bool MinionIdle[MAXTF2PLAYERS];
bool MinionBlacklist[MAXTF2PLAYERS];

public Plugin myinfo =
{
	name		=	"Freak Fortress 2: Rewrite - Gray Abilities",
	author		=	"Batfoxkid",
	description	=	"This AI kinda sus!",
	version		=	PLUGIN_VERSION,
	url			=	"https://github.com/Batfoxkid/Freak-Fortress-2-Rewrite"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	#if defined __nosoop_tf2_utils_included
	MarkNativeAsOptional("TF2Util_GetPlayerWearableCount");
	MarkNativeAsOptional("TF2Util_GetPlayerWearable");
	MarkNativeAsOptional("TF2Util_GetPlayerMaxHealthBoost");
	MarkNativeAsOptional("TF2Util_EquipPlayerWearable");
	#endif
	
	#if defined __tf_custom_attributes_included
	MarkNativeAsOptional("TF2CustAttr_SetString");
	#endif
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("ff2_rewrite.phrases");
	
	GameData gamedata = new GameData("sm-tf2.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(gamedata.GetOffset("RemoveWearable") - 1);
	PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
	SDKEquipWearable = EndPrepSDKCall();
	if(!SDKEquipWearable)
		LogError("[Gamedata] Could not find RemoveWearable");
	
	delete gamedata;
	
	gamedata = new GameData("sdkhooks.games");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Virtual, "GetMaxHealth");
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_ByValue);
	SDKGetMaxHealth = EndPrepSDKCall();
	if(!SDKGetMaxHealth)
		LogError("[Gamedata] Could not find GetMaxHealth");
	
	delete gamedata;
	
	gamedata = new GameData("ff2");
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(gamedata, SDKConf_Signature, "CTFPlayer::TeamFortress_SetSpeed");
	SDKSetSpeed = EndPrepSDKCall();
	if(!SDKSetSpeed)
		LogError("[Gamedata] Could not find CTFPlayer::TeamFortress_SetSpeed");
	
	GetSceneSoundToken = CreateHook(gamedata, "CTFPlayer::GetSceneSoundToken");
	DeathSound = CreateHook(gamedata, "CTFPlayer::DeathSound");
	
	delete gamedata;
	
	#if defined __nosoop_tf2_utils_included
	TF2ULoaded = LibraryExists(TF2U_LIBRARY);
	#endif
	
	#if defined __tf_custom_attributes_included
	TCALoaded = LibraryExists(TCA_LIBRARY);
	#endif
	
	SyncHud = CreateHudSynchronizer();
	
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Post);
	//HookEvent("object_deflected", OnObjectDeflected, EventHookMode_Post);
	//HookEvent("teamplay_round_win", OnRoundEnd, EventHookMode_PostNoCopy);
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			OnClientPutInServer(client);
			
			BossData cfg = FF2R_GetBossData(client);
			if(cfg)
			{
				FF2R_OnBossCreated(client, cfg, false);
				FF2R_OnBossEquipped(client, true);
			}
		}
	}
}

DynamicHook CreateHook(GameData gamedata, const char[] name)
{
	DynamicHook hook = DynamicHook.FromConf(gamedata, name);
	if(!hook)
		LogError("[Gamedata] Could not find %s", name);
	
	return hook;
}

public void OnPluginEnd()
{
	//OnMapEnd();
	
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client))
		{
			if(FF2R_GetBossData(client))
				FF2R_OnBossRemoved(client);
		}
	}
}

public void OnClientPutInServer(int client)
{
}

public void OnClientDisconnect(int client)
{
}

public void FF2R_OnBossCreated(int client, BossData boss, bool setup)
{
	AbilityData ability = boss.GetAbility("special_robot_effects");
	if(ability.IsMyPlugin())
	{
		RobotGiant[client] = ability.GetBool("giant", false);

		if(!SceneSoundHookPre[client] && GetSceneSoundToken && ability.GetBool("voice", true))
		{
			SceneSoundHookPre[client] = GetSceneSoundToken.HookEntity(Hook_Pre, client, OnGetSceneSoundTokenPre);
			SceneSoundHookPost[client] = GetSceneSoundToken.HookEntity(Hook_Pre, client, OnGetSceneSoundTokenPost);
		}

		if(!TakeDamageHooked[client] && ability.GetBool("bleed", true))
		{
			SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlivePre);
			SDKHook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);

			bool found;
			for(int i = 1; i <= MaxClients; i++)
			{
				if(TakeDamageHooked[i])
				{
					found = true;
					break;
				}
			}

			if(!found)
				HookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
			
			TakeDamageHooked[client] = true;
		}

		if(!DeathSoundHookPre[client] && DeathSound && ability.GetBool("death", true))
		{
			DeathSoundHookPre[client] = DeathSound.HookEntity(Hook_Pre, client, OnDeathSoundPre);
			DeathSoundHookPost[client] = DeathSound.HookEntity(Hook_Pre, client, OnDeathSoundPost);
		}
	}
}

public void FF2R_OnBossRemoved(int client)
{
	if(SceneSoundHookPre[client])
	{
		DynamicHook.RemoveHook(SceneSoundHookPre[client]);
		DynamicHook.RemoveHook(SceneSoundHookPost[client]);
		SceneSoundHookPre[client] = 0;
		SceneSoundHookPost[client] = 0;
	}

	if(TakeDamageHooked[client])
	{
		SDKUnhook(client, SDKHook_OnTakeDamageAlive, OnTakeDamageAlivePre);
		SDKUnhook(client, SDKHook_OnTakeDamageAlivePost, OnTakeDamageAlivePost);
		TakeDamageHooked[client] = false;

		bool found;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(TakeDamageHooked[i])
			{
				found = true;
				break;
			}
		}

		if(!found)
			UnhookEvent("player_hurt", OnPlayerHurt, EventHookMode_Post);
	}

	if(DeathSoundHookPre[client])
	{
		DynamicHook.RemoveHook(DeathSoundHookPre[client]);
		DynamicHook.RemoveHook(DeathSoundHookPost[client]);
		DeathSoundHookPre[client] = 0;
		DeathSoundHookPost[client] = 0;
	}
}

public void FF2R_OnBossEquipped(int client, bool weapons)
{
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
	if(!StrContains(ability, "rage_condition", false))
	{
		TF2_AddCondition(client, view_as<TFCond>(cfg.GetInt("condition")), cfg.GetFloat("duration", -1.0));
	}
	else if(!StrContains(ability, "rage_reaction", false))
	{
		Rage_Reaction(client, cfg);
	}
	else if(!StrContains(ability, "rage_summon", false))
	{
		Rage_Summon(client, cfg);
	}
}

void Rage_Reaction(int client, AbilityData cfg)
{
	char reactionEnemy[64], reactionAlly[64], announcerEnemy[64], announcerAlly[64];
	cfg.GetString("enemyplayer", reactionEnemy, sizeof(reactionEnemy));
	cfg.GetString("allyplayer", reactionAlly, sizeof(reactionAlly));
	cfg.GetString("enemyannouncer", announcerEnemy, sizeof(announcerEnemy));
	cfg.GetString("allyannouncer", announcerAlly, sizeof(announcerAlly));

	if(cfg.GetInt("_useagain"))
	{
		cfg.GetString("enemyannounceragain", announcerEnemy, sizeof(announcerEnemy), announcerEnemy);
		cfg.GetString("allyannounceragain", announcerAlly, sizeof(announcerAlly), announcerAlly);
	}
	else
	{
		cfg.SetInt("_useagain", 1);
	}

	int team = GetClientTeam(client);

	int[] enemies = new int[MaxClients];
	int[] allies = new int[MaxClients];
	int enemyCount, allyCount;
	for(int target = 1; target <= MaxClients; target++)
	{
		if(IsClientInGame(target))
		{
			if(team == GetClientTeam(target))
			{
				if(reactionAlly[0] && IsPlayerAlive(target))
				{
					SetVariantString(reactionAlly);
					AcceptEntityInput(target, "SpeakResponseConcept");
				}

				allies[allyCount++] = target;
			}
			else
			{
				if(reactionEnemy[0] && IsPlayerAlive(target))
				{
					SetVariantString(reactionEnemy);
					AcceptEntityInput(target, "SpeakResponseConcept");
				}

				enemies[enemyCount++] = target;
			}
		}
	}

	if(announcerAlly[0] && allyCount)
		FF2R_EmitBossSound(allies, allyCount, announcerAlly, client, _, _, _, _, _, 1.0);

	if(announcerEnemy[0] && enemyCount)
		FF2R_EmitBossSound(enemies, enemyCount, announcerEnemy, client, _, _, _, _, _, 1.0);
}

void Rage_Summon(int client, AbilityData cfg)
{
	
}

static void SummonAsCfg(int[] clients, int amount, const float pos[3], const float ang[3], int team, ConfigData cfg)
{
	for(int i; i < amount; i++)
	{
		if(MinionLastTeam[clients[i]] == -1)
			MinionLastTeam[clients[i]] = GetClientTeam(clients[i]);
		
		FF2R_CreateBoss(clients[i], cfg, team);
		MinionOwner[clients[i]] = owner;
		
		FF2R_SetClientMinion(clients[i], true);
		
		TF2_RespawnPlayer(clients[i]);
		SetEntProp(clients[i], Prop_Send, "m_bDucked", true);
		SetEntityFlags(clients[i], GetEntityFlags(clients[i]) | FL_DUCKING);
		TeleportEntity(clients[i], pos, ang, {0.0, 0.0, 0.0});
		
		MinionIdle[clients[i]] = true;
		TF2_AddCondition(clients[i], TFCond_HalloweenKartNoTurn, 1.0);
		TF2_AddCondition(clients[i], TFCond_DisguisedAsDispenser, 20.0);
		TF2_AddCondition(clients[i], TFCond_UberchargedOnTakeDamage, 20.0);
		TF2_AddCondition(clients[i], TFCond_MegaHeal, 15.0);
		
		if(owner > 0)
			SDKHook(clients[i], SDKHook_OnTakeDamage, MinionTakeDamage);
	}
}

public Action MinionTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	if(MinionIdle[victim])
	{
		if(attacker > MaxClients && damage > 10.0)
		{
			if(MinionOwner[victim] > 0)
			{
				static const float vel[] = {90.0, 0.0, 0.0};
				
				float pos[3];
				GetEntPropVector(MinionOwner[victim], Prop_Send, "m_vecOrigin", pos);
				TeleportEntity(victim, pos, _, vel);
				return Plugin_Handled;
			}
		}
	}
	else
	{
		SDKUnhook(victim, SDKHook_OnTakeDamage, CloneTakeDamage);
	}
	return Plugin_Continue;
}

public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3])
{
	if(MinionIdle[client] && buttons && !TF2_IsPlayerInCondition(client, TFCond_HalloweenKartNoTurn))
	{
		TF2_RemoveCondition(client, TFCond_DisguisedAsDispenser);
		TF2_RemoveCondition(client, TFCond_UberchargedOnTakeDamage);
		TF2_RemoveCondition(client, TFCond_MegaHeal);
		MinionIdle[client] = false;
	}
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int victim = GetClientOfUserId(userid);
	if(victim)
	{
		if(MinionOwner[victim])
		{
			MinionOwner[victim] = 0;
			FF2R_CreateBoss(victim, null);
			ChangeClientTeam(victim, MinionLastTeam[victim]);
			MinionLastTeam[victim] = -1;
		}
		
		if(MinionIdle[victim])
		{
			MinionBlacklist[victim] = true;
			MinionIdle[victim] = false;
		}
	}
}

public void OnPlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	// Replace bleed effect, turn on MvM between player_hurt and OnTakeDamageAlivePost

	if(TakeDamageHook)
	{
		int victim = GetClientOfUserId(event.GetInt("userid"));
		if(victim == TakeDamageHook)
			TurnOnRobo(victim, TakeDamageMvMChange, TakeDamageTeamChange, TakeDamageBossChange);
	}
}

public Action OnTakeDamageAlivePre(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom)
{
	// Replace bleed effect, turn on MvM between player_hurt and OnTakeDamageAlivePost

	if(!TakeDamageHook)
		TakeDamageHook = victim;
	
	return Plugin_Continue;
}

public void OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
	// Replace bleed effect, turn on MvM between player_hurt and OnTakeDamageAlivePost

	if(TakeDamageHook == victim)
	{
		TurnOffRobo(victim, TakeDamageMvMChange, TakeDamageTeamChange, TakeDamageBossChange);
		TakeDamageHook = 0;
	}
}

public MRESReturn OnGetSceneSoundTokenPre(int client, DHookReturn ret)
{
	// Replace voicelines with robot variants

	TurnOnRobo(client, SceneSoundMvMChange, SceneSoundTeamChange, SceneSoundBossChange);
	return MRES_Ignored;
}

public MRESReturn OnGetSceneSoundTokenPost(int client, DHookReturn ret)
{
	// Replace voicelines with robot variants

	TurnOffRobo(client, SceneSoundMvMChange, SceneSoundTeamChange, SceneSoundBossChange);
	return MRES_Ignored;
}

public MRESReturn OnDeathSoundPre(int client, DHookParam param)
{
	// Replace death sounds with robot variants

	TurnOnRobo(client, DeathSoundMvMChange, DeathSoundTeamChange, DeathSoundBossChange);
	return MRES_Ignored;
}

public MRESReturn OnDeathSoundPost(int client, DHookParam param)
{
	// Replace death sounds with robot variants

	TurnOffRobo(client, DeathSoundMvMChange, DeathSoundTeamChange, DeathSoundBossChange);

	if(RobotGiant[client])
	{
		int team = GetClientTeam(client);
		for(int target = 1; target <= MaxClients; target++)
		{
			if(IsClientInGame(target) && IsPlayerAlive(target) && team != GetClientTeam(target))
			{
				SetVariantString("MP_CONCEPT_MVM_GIANT_KILLED");
				AcceptEntityInput(target, "SpeakResponseConcept");
			}
		}
	}
	return MRES_Ignored;
}

void TurnOnRobo(int client, bool &changeMvM, int &changeTeam, bool &changeBoss)
{
	if(!GameRules_GetProp("m_bPlayingMannVsMachine"))
	{
		GameRules_SetProp("m_bPlayingMannVsMachine", true);
		changeMvM = true;
	}

	int team = GetClientTeam(client);
	if(team != TF_TEAM_PVE_INVADERS)
	{
		SetEntProp(client, Prop_Send, "m_iTeamNum", TF_TEAM_PVE_INVADERS);
		changeTeam = team;
	}

	if(RobotGiant[client] && !GetEntProp(client, Prop_Send, "m_bIsMiniBoss"))
	{
		SetEntProp(client, Prop_Send, "m_bIsMiniBoss", true);
		changeBoss = true;
	}
}

void TurnOffRobo(int client, bool &changeMvM, int &changeTeam, bool &changeBoss)
{
	if(changeMvM)
	{
		GameRules_SetProp("m_bPlayingMannVsMachine", false);
		changeMvM = false;
	}

	if(changeTeam != -1)
	{
		SetEntProp(client, Prop_Send, "m_iTeamNum", changeTeam);
		changeTeam = -1;
	}

	if(changeBoss)
	{
		SetEntProp(client, Prop_Send, "m_bIsMiniBoss", false);
		changeBoss = false;
	}
}