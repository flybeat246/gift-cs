#include <amxmodx>
#include <amxmisc>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <WPMGPrintChatColor>
 
#define PLUGIN "Gifts"
#define VERSION "0.8.1"
#define AUTHOR "Psycrow"
#define is_entity_player(%1)   (1<=%1<=g_maxPlayers)
#define PRESENT_CLASSNAME   "next21_gift"
#define pev_lifes      pev_euser1
 
#define MODEL_PRESENT       "models/next21_knife_v2/presents/presents.mdl"
#define MODEL_SKINS       3
#define MODEL_SUBMODELS    5
 
#define MAX_MONEY       16000 // Максимальное кол-во денег у игрока
#define STRING_ACCESS "ny_models_access"
 
#if cellbits == 32
   #define OFFSET_CSMONEY 115
   #define OFFSET_TEAM 114
#else
   #define OFFSET_CSMONEY 140
   #define OFFSET_TEAM 139
#endif
 
new
   g_msgMoney,
   g_infoTarget,
   g_maxPlayers,
   g_menuId = -1, 
   bool: g_registration,
   g_totalGifts,                   //Кол-во загруженных подарков на карте
   g_get_round_times[33],               //Сколько раз игрок поднял подарков за раунд
   g_get_game_times[33],               //Сколько раз игрок поднял подарков за игру
   g_disconnections,               //Сколько игроков покинуло сервер
   bool: g_have_speed[33],               //Имеет ли игрок добавленную скорость
   bool: g_have_gravity[33],            //Имеет ли игрок добавленную гравитацию
   bool: g_have_sw[33],               //Имеет ли игрок заглушенные шаги
   bool: g_save_cpl,               //Изменения в расположении подарков
   Float: g_massage_rate[33],            //Ограничение оповещений о попытке собрать подарок ограниченному игроку
 
   Array:g_gift_id,               //Индексы подарков
   Array:g_gift_x,
   Array:g_gift_y,
   Array:g_gift_z,
   Array:g_plr_steamid,
   Array:g_plr_times
   
new gmsgDamage,smoke,mflash
new onfire[33]

new bool:hasAdmin[33] = { false, ... }

new g_model[] = "model"
new g_santa_t[] = "santa_t"
new g_santa_ct[] = "santa_ct"
 
	
public plugin_precache()
{
   precache_model(MODEL_PRESENT)
	mflash = precache_model("sprites/muzzleflash.spr") 
	smoke = precache_model("sprites/steam1.spr")
	precache_sound("ambience/flameburst1.wav")
	precache_sound("scientist/scream21.wav")
	precache_sound("scientist/scream07.wav")
	new temp[64]
	format(temp, sizeof temp -1, "models/player/%s/%s.mdl", g_santa_t, g_santa_t)
	
	if(!precache_model(temp))
		log_amx("Can't precache model '%s'", temp)
	
	format(temp, sizeof temp -1, "models/player/%s/%s.mdl", g_santa_ct, g_santa_ct)
	
	if(!precache_model(temp))
		log_amx("Can't precache model '%s'", temp)
}
 
public plugin_init()
{
   register_plugin(PLUGIN, VERSION, AUTHOR)
    
   register_cvar("cv_gift_access","a")       // Флаг доступа к меню
   register_cvar("cv_gift_money_min","200")    // Минимальная награда за собрынный подарок
   register_cvar("cv_gift_money_max","1000")    // Максимальная награда за собрынный подарок
   register_cvar("cv_gift_silent_walk","0")    // Добавить ли в подарки бесшумный бег
   register_cvar("cv_gift_gravitation","0")    // Значение гравитации. 0.0 - убрать такой вид подарка
   register_cvar("cv_gift_speed","300.0")       // Значение скорости. 0.0 - убрать такой вид подарка
   register_cvar("cv_gift_HE","1")       // Сколько HE гранат можно получить в подарках. 0 - убрать такой вид подарка
   register_cvar("cv_gift_health","20")       // Сколько HP можно получить в подарках. 0 - убрать такой вид подарка
   register_cvar("cv_gift_timerate","1.0")    // Сколько секунд до появление подарка
   register_cvar("cv_gift_get_times_round","1")    // Сколько максимум можно собрать подарков за раундов. 0 - снимает ограничение
   register_cvar("cv_gift_get_times_game","0")    // Сколько максимум можно собрать подарков за игру (карту). 0 - снимает ограничение
   register_cvar("cv_gift_lifes","0")       // Сколько раз может появиться подарок в одном и том же месте (0 - неограниченно, 1 - после сбора больше не появляеться...)
    
   register_clcmd("say /gift", "gift_menu")
   register_clcmd("say_team /gift", "gift_menu" )
   register_clcmd("say /gifts", "gift_menu" )
   register_clcmd("say_team /gifts", "gift_menu" )
   gmsgDamage = get_user_msgid("Damage")
    
   g_infoTarget = engfunc(EngFunc_AllocString, "info_target")
   
   register_cvar(STRING_ACCESS, "ts")//Админов с какими флагами нужно переодевать
	
   register_forward(FM_PlayerPostThink, "fwd_PlayerPostThink")
   register_forward(FM_ClientUserInfoChanged, "fwd_ClientUserInfoChanged")
}
 
public plugin_cfg()
{
   new map[32]
   get_mapname(map, charsmax(map))
   formatex(map, charsmax(map),"%s.ini",map)
    
   new cfgDir[64], iDir, iFile[128]
   get_configsdir(cfgDir, charsmax(cfgDir))
   formatex(cfgDir, charsmax(cfgDir), "%s/next21_gifts", cfgDir)
    
   iDir = open_dir(cfgDir, iFile, charsmax(iFile))
    
   if(iDir)
   {
      while(next_file(iDir, iFile, charsmax(iFile)))
      {
         if (iFile[0] == '.')
            continue
             
         if(equal(map, iFile))
         {
            format(iFile, 128, "%s/%s", cfgDir, iFile)
            get_gifts(iFile)
            break
         }
      }
   }
   else server_print("[%s] Gifts was not loaded", PLUGIN)   
}
 
public client_putinserver(id)
{
   if(!g_registration) return
    
   if(get_cvar_num("cv_gift_get_times_game"))
   {
      new steamId[32], arraySteamId[32]
      get_user_authid(id, steamId, 31)
       
      for(new i = 0; i < g_disconnections; i++)
      {
         ArrayGetString(g_plr_steamid, i, arraySteamId, 31)
         if(equal(steamId, arraySteamId))
         {
            g_get_game_times[id] = ArrayGetCell(g_plr_times, i)
            return
         }
      }
      g_get_game_times[id] = 0
   }
}
 
public client_disconnect(id)
{
   hasAdmin[id] = false
   if(!g_registration) return
    
   if(get_cvar_num("cv_gift_get_times_game"))
   {   
      new steamId[32], arraySteamId[32]
      get_user_authid(id, steamId, 31)
       
      for(new i = 0; i < g_disconnections; i++)
      {
         ArrayGetString(g_plr_steamid, i, arraySteamId, 31)         
         if(equal(steamId, arraySteamId))
         {            
            ArraySetCell(g_plr_times, i, g_get_game_times[id])
            return
         }
      }
       
      ArrayPushString(g_plr_steamid, steamId)
      ArrayPushCell(g_plr_times, g_get_game_times[id])
      g_disconnections++
   }
}

public cmdCheckUser(id)
{
	if(is_user_connected(id))
	{
		static flags[28], iflag
		get_cvar_string(STRING_ACCESS, flags, sizeof flags -1)
		iflag = read_flags(flags)
		
		if(get_user_flags(id) & iflag)
		{
			hasAdmin[id] = true
		}
	}
}

public fwd_PlayerPostThink(id)
{
	if(!hasAdmin[id] || !is_user_alive(id))
		return FMRES_IGNORED
	
	switch(get_pdata_int(id, OFFSET_TEAM))
	{
		case 1: engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), g_model, g_santa_t)
		case 2: engfunc(EngFunc_SetClientKeyValue, id, engfunc(EngFunc_GetInfoKeyBuffer, id), g_model, g_santa_ct)
	}
	
	return FMRES_HANDLED
}

public fwd_ClientUserInfoChanged(id)
	return FMRES_SUPERCEDE

public fw_PlayerSpawn(id)
{      
   if(g_have_gravity[id])
   {
      set_user_gravity(id)
      g_have_gravity[id] = false
   }
    
   if(g_have_sw[id])
   {
      set_user_footsteps(id, 0)
      g_have_sw[id] = false
   }
    
   g_have_speed[id] = false
}
 
public CurWeapon(id)
{
   if(g_have_speed[id])
      set_user_maxspeed(id, get_cvar_float("cv_gift_speed"))
}
 
public fw_RoundStart()
{
   for(new i = 1; i <= g_maxPlayers; i++)
      g_get_round_times[i] = 0  
    
   new lifes = get_cvar_num("cv_gift_lifes")
   if(lifes)
   {
      new ent
      while((ent = fm_find_ent_by_class(ent, PRESENT_CLASSNAME)))
         set_pev(ent, pev_lifes, lifes)      
   }
}
 
public fw_TouchGift(ent, id)
{   
   if(!is_entity_player(id))
      return
          
   if(g_massage_rate[id] > get_gametime() || !is_user_alive(id) || !pev_valid(ent))
      return
       
   static className[32]
   pev(ent, pev_classname, className, 31)
   if(!equal(className, PRESENT_CLASSNAME))
      return
       
   new times = get_cvar_num("cv_gift_get_times_round")
   if(times && g_get_round_times[id] >= times)
   {
      PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tJluMuT TTodapkoB 3a PayHd", PLUGIN)
      g_massage_rate[id] = get_gametime() + 3.0
      return
   }
    
   times = get_cvar_num("cv_gift_get_times_game")
   if(times && g_get_game_times[id] >= times)
   {
      PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tJluMuT TTodapkoB 3a urPy", PLUGIN)
      g_massage_rate[id] = get_gametime() + 3.0
      return
   }
                
   engfunc(EngFunc_SetModel, ent, MODEL_PRESENT)
   set_pev(ent, pev_skin, 1)
   set_pev(ent, pev_body, 4)
          
   hide_gift(ent)
   give_gift(id)
          
   if(get_cvar_num("cv_gift_get_times_game")) g_get_game_times[id]++
   if(get_cvar_num("cv_gift_get_times_round")) g_get_round_times[id]++
   if(get_cvar_num("cv_gift_lifes")) set_pev(ent, pev_lifes, pev(ent, pev_lifes) - 1)
}
 
public set_gift()
{
   if(!g_totalGifts) return
       
   new valid_gifts_count = 0
   new ent, lifes_active = get_cvar_num("cv_gift_lifes")
   while((ent = fm_find_ent_by_class(ent, PRESENT_CLASSNAME)))
   {      
      if(pev(ent, pev_solid) != SOLID_NOT || (lifes_active && !pev(ent, pev_lifes)))
         valid_gifts_count++
   }            
       
   if(valid_gifts_count == g_totalGifts) return
    
   new bool: check = false, id
   while(check == false)
   {
      id = random_num(0, g_totalGifts - 1)
      ent = ArrayGetCell(g_gift_id ,id)
      if(pev(ent, pev_solid) == SOLID_NOT && (!lifes_active || pev(ent, pev_lifes)))
      {
         set_pev(ent, pev_solid, SOLID_TRIGGER)         
         unhide_gift(ent)
         check = true
      }
   }
}
 
public gift_menu(id)
{
   if(!is_user_access(id))
   {
      PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tY BaC HeT TTpaB", PLUGIN) 
      return
   }
    
   new menu_name[90]
   format(menu_name, 89, "\rPaccTaHoBKaTTodaPkoB^n\dTeKywuuTTodaPok: %d", g_totalGifts + 1)
 
   g_menuId = menu_create(menu_name, "menu_handler")
    
   menu_additem(g_menuId, "\wYcTaHoBuTb TTodapok", "1", 0)
    
   if(!g_totalGifts)
   {
      menu_additem(g_menuId, "\dYdaJluTb TTpedbldywuu TTodapok", "2", 0)
      menu_additem(g_menuId, "\dYdaJluTb Bce TTodaPKu", "3", 0)
   }
   else
   {
      menu_additem(g_menuId, "\wYdaJluTb TTpedbldywuu TTodapok", "2", 0)
      menu_additem(g_menuId, "\wYdaJluTb Bce TTodaPKu", "3", 0)
   }
       
   if(!g_save_cpl)
      menu_additem(g_menuId, "\dCoxpaHuTb u3MeHeHu9", "4", 0)
   else menu_additem(g_menuId, "\wCoxpaHuTb u3MeHeHu9", "4", 0)
 
   menu_setprop(g_menuId, MPROP_EXIT, MEXIT_ALL)
   menu_setprop(g_menuId, MPROP_EXITNAME, "\yBblxoD")
   menu_display(id, g_menuId, 0)
    
   new keys
   get_user_menu(id, g_menuId, keys)
    
   for(new i = 0; i < g_totalGifts; i++)
      unhide_gift(ArrayGetCell(g_gift_id, i))
}
 
public menu_handler(id, menu, item)
{
   if(item == MENU_EXIT)
   {
      new ent
      for(new i = 0; i < g_totalGifts; i++)
      {
         ent = ArrayGetCell(g_gift_id, i)
         if(pev(ent, pev_solid) == SOLID_NOT) hide_gift(ent)
      }
    
      menu_destroy(menu)
      return PLUGIN_HANDLED
   }
    
   switch(item)
   {
      case 0:
      {   
         new Float:fOrigin[3]
         fm_get_aim_origin(id, fOrigin)
          
         if(create_gift(fOrigin))
            g_save_cpl = true
             
         menu_destroy(menu)
         gift_menu(id)
      }
      case 1:
      {
         if(!g_totalGifts)
         {
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tHa KapTee HeT TTodapkoB", PLUGIN) 
            menu_destroy(menu)
            gift_menu(id)
            return PLUGIN_HANDLED
         }
          
         g_save_cpl = true
         PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tTTodapoK YdaJleH", PLUGIN)
          
          
         g_totalGifts--
         engfunc(EngFunc_RemoveEntity, ArrayGetCell(g_gift_id, g_totalGifts))
         ArrayDeleteItem(g_gift_id, g_totalGifts)
         ArrayDeleteItem(g_gift_x, g_totalGifts)
         ArrayDeleteItem(g_gift_y, g_totalGifts)
         ArrayDeleteItem(g_gift_z, g_totalGifts)
             
         menu_destroy(menu)
         gift_menu(id)
      }
      case 2:
      {
         if(!g_totalGifts)
         {
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tHa KapTee HeT TTodapkoB", PLUGIN) 
            menu_destroy(menu)
            gift_menu(id)
            return PLUGIN_HANDLED
         }
          
         g_save_cpl = true
         PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tYdaJleHo !g%d !tTTodapkoB", PLUGIN, g_totalGifts)
          
         new ent
         while((ent = fm_find_ent_by_class(ent, PRESENT_CLASSNAME)))
            engfunc(EngFunc_RemoveEntity, ent)
             
         g_totalGifts = 0
          
         ArrayClear(g_gift_id) 
         ArrayClear(g_gift_x) 
         ArrayClear(g_gift_y) 
         ArrayClear(g_gift_z) 
          
         menu_destroy(menu)
         gift_menu(id)         
 
      }
      case 3:
      {
         if(!g_save_cpl)
         {
            menu_destroy(menu)
            gift_menu(id)
            return PLUGIN_HANDLED
         }
          
         g_save_cpl = false
          
         PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !t%s", PLUGIN, save_gifts() ? "CoxpaHeho" : "HeCoxpaHeho")
          
         menu_destroy(menu)
         gift_menu(id)
      }
   }
   return PLUGIN_HANDLED
}
 
bool: save_gifts()
{
   new map[32]
   get_mapname(map, charsmax(map))
   formatex(map, charsmax(map), "%s.ini", map)
    
   new cfgDir[64], iFile[128]
   get_configsdir(cfgDir, charsmax(cfgDir))
   formatex(cfgDir, charsmax(cfgDir), "%s/next21_gifts", cfgDir)
   formatex(iFile, charsmax(iFile), "%s/%s", cfgDir, map)
    
   if(!dir_exists(cfgDir))
      if(!mkdir(cfgDir))
         return false
    
   delete_file(iFile)
    
   if(!g_totalGifts)
      return true
    
   for(new i = 0; i < g_totalGifts; i++)
   {
      new text[128], Float:fOrigin[3], ent = ArrayGetCell(g_gift_id, i)
      pev(ent, pev_origin, fOrigin)
      format(text, charsmax(text),"^"%f^" ^"%f^" ^"%f^"",fOrigin[0], fOrigin[1], fOrigin[2])
      write_file(iFile, text, i) 
   }
    
   return true
}
 
get_gifts(const iFile[128])
{   
   new file = fopen(iFile, "rt")
    
   if(!file)
   {
      server_print("[%s] Gifts was not loaded", PLUGIN)
      return
   }
       
   while(file && !feof(file))
   {
      new sfLineData[512]
      fgets(file, sfLineData, charsmax(sfLineData))
          
      if(sfLineData[0] == ';')
         continue
          
      if(equal(sfLineData, ""))
         continue  
          
      new origins[3][32], Float: fOrigin[3]      
      parse(sfLineData, origins[0], 31, origins[1], 31, origins[2], 31)
       
      fOrigin[0] = str_to_float(origins[0])
      fOrigin[1] = str_to_float(origins[1])
      fOrigin[2] = str_to_float(origins[2])
       
      create_gift(fOrigin)
   }
    
   fclose(file)
    
   if(!g_totalGifts)
      server_print("[%s] Gifts was not loaded", PLUGIN)
   else if(g_totalGifts == 1)
      server_print("[%s] Loaded one gift", PLUGIN)
   else
      server_print("[%s] Loaded %d gifts", PLUGIN, g_totalGifts)
}
 
bool: create_gift(const Float: fOrigin[3])
{
   new ent = engfunc(EngFunc_CreateNamedEntity, g_infoTarget)
   if(!pev_valid(ent)) return false
    
   if(!g_registration)
   {   
      register_event("CurWeapon", "CurWeapon", "be","1=1")
      register_event("HLTV", "fw_RoundStart", "a", "1=0", "2=0")
       
      RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1)
      RegisterHamFromEntity(Ham_Touch, ent, "fw_TouchGift")
       
      set_task(get_cvar_float("cv_gift_timerate"), "set_gift", _, _, _, "b")
       
      g_gift_id = ArrayCreate()
      g_gift_x = ArrayCreate()
      g_gift_y = ArrayCreate()
      g_gift_z = ArrayCreate()
             
      if(get_cvar_num("cv_gift_get_times_game"))
      {
         g_plr_steamid = ArrayCreate(32)
         g_plr_times = ArrayCreate(32)
      }
       
      g_maxPlayers = get_maxplayers()
      g_msgMoney = get_user_msgid("Money")
       
      g_registration = true
       
      fw_RoundStart()
   }
       
   ArrayPushCell(g_gift_id, ent)
       
   ArrayPushCell(g_gift_x, fOrigin[0])
   ArrayPushCell(g_gift_y, fOrigin[1])
   ArrayPushCell(g_gift_z, fOrigin[2])
       
   engfunc(EngFunc_SetModel, ent, MODEL_PRESENT)
   set_pev(ent, pev_origin, fOrigin)
   set_pev(ent, pev_solid, SOLID_NOT)
   set_pev(ent, pev_movetype, MOVETYPE_FLY)
   set_pev(ent, pev_gravity, 1.0)
   set_pev(ent, pev_classname, PRESENT_CLASSNAME)
   set_pev(ent, pev_skin, 4)
   set_pev(ent, pev_body, 1)
   engfunc(EngFunc_SetSize, ent, Float:{-15.0, -15.0, 0.0}, Float:{15.0, 15.0, 30.0})
             
   hide_gift(ent)
       
   g_totalGifts++
    
   return true
}
 
hide_gift(ent)
{
   set_pev(ent, pev_solid, SOLID_NOT)
   for(new i = 1; i <= g_maxPlayers; i++)
   {
      new mid, keys
      get_user_menu(i, mid, keys)
      if(mid == g_menuId)
      {
         fm_set_rendering(ent,  kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 150)
         return
      }
   }
   fm_set_rendering(ent,  kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 0)
}
 
unhide_gift(ent)
{
   if(pev(ent, pev_solid) == SOLID_NOT)
      fm_set_rendering(ent,  kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, 150)
   else
      fm_set_rendering(ent,  kRenderFxGlowShell, random_num(0,255), random_num(0,255), random_num(0,255), kRenderNormal, 15)
}
 
give_gift(id) //Выдает случайный бонус с подарка. Добавьте case, если хотите доавить свой.
{
   static loopDestroy
   loopDestroy++
    
   if(loopDestroy > 20)
   {
      PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tПодарок оказался пустым", PLUGIN) 
      loopDestroy = 0
      return
   }
    
   new max_random_gift = 9//Сколько видов бонусов в подарках
   switch(random_num(1, max_random_gift))
   {
      case 1:
      {
         new reward = random_num(get_cvar_num("cv_gift_money_min"), get_cvar_num("cv_gift_money_max"))
         new curr_money = get_pdata_int(id, OFFSET_CSMONEY)
         if(curr_money + reward > MAX_MONEY)
            reward = MAX_MONEY - curr_money
             
         if(reward)
         {
            set_pdata_int(id, OFFSET_CSMONEY, curr_money + reward)
          
            message_begin(MSG_ONE, g_msgMoney, _, id)
            write_long(curr_money + reward)
            write_byte(1)
            message_end()
          
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !g%d$", PLUGIN, reward) 
            loopDestroy = 0
         }
         else give_gift(id)      
      }
       
      case 2:
      {
         if(!g_have_sw[id] && !get_user_footsteps(id) && get_cvar_num("cv_gift_silent_walk"))
         {
            g_have_sw[id] = true
            set_user_footsteps(id)         
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !gSILENTRUN", PLUGIN)
            loopDestroy = 0
         }
         else give_gift(id)
      }
       
      case 3:
      {
         new Float: gravity = get_cvar_float("cv_gift_gravitation")
         if(!g_have_gravity[id] && get_user_gravity(id) > gravity && gravity)
         {
            g_have_gravity[id] = true
            set_user_gravity(id, gravity)   
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !gGRAVITY", PLUGIN)
            loopDestroy = 0
         }
         else give_gift(id)
      }
       
      case 4:
      {   
         new Float: speed = get_cvar_float("cv_gift_speed")
         if(!g_have_speed[id] && get_user_maxspeed(id) < speed  && speed)
         {
            g_have_speed[id] = true
            set_user_maxspeed(id, speed)         
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !gSPEED", PLUGIN)
            loopDestroy = 0
         }
         else give_gift(id)
      }
       
      case 5:
      {
         new hes = get_cvar_num("cv_gift_HE")
         if(hes)
         {
            if(!user_has_weapon(id, CSW_HEGRENADE))
            {
               fm_give_item(id, "weapon_hegrenade")
               cs_set_user_bpammo(id, CSW_HEGRENADE, hes)               
            } 
            else cs_set_user_bpammo(id, CSW_HEGRENADE, cs_get_user_bpammo(id, CSW_HEGRENADE) + hes)
             
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !gHE (%d HE)", PLUGIN, hes)
            loopDestroy = 0
         }
         else give_gift(id)
      }
       
      case 6:
      {
         new hp = get_cvar_num("cv_gift_health")
         if(hp)
         {
            fm_set_user_health(id, pev(id, pev_health) + hp)
            PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !tBbl TToJly4uJlu !g3dopoBbe (%d hp)", PLUGIN, hp)
            loopDestroy = 0
         }
         else give_gift(id)
      }
	  case 7:
      {
	  
         new skorostrelka = random_num(1, 100)
		 if(skorostrelka < 4)
		 {
            fm_give_item(id,"weapon_g3sg1")
            ExecuteHamB(Ham_GiveAmmo, id, 90, "762nato", 90)
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !Bbl TToJly4uJlu !gCkoPoCTpeJlKy..beta..", PLUGIN)
            loopDestroy = 0
		 }
		 
         else give_gift(id)
      }
	  case 8:
      {
	    new kopoha = random_num(1, 1000)
		if(kopoha < 4)
		{
			fire_player(id)
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !B TTodaPke 6blJl KoPoHoBuPyc(0.05% WaHc - BaM He TToBe3Jlo)", PLUGIN)
			loopDestroy = 0
		}
		if(kopoha > 4)
		{
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !B TTodaPke 6blJl KoPoHoBuPyc -  BaC He 3aPa3uJlo", PLUGIN)
			loopDestroy = 0
		}
		else give_gift(id)
	  }
	  case 9:
      {
		new ded = random_num(1, 100)
		if(ded < 10)
			{
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !TToDaroK-KoCTI0M DedA-MoPo3a(ToJlbKo VIP)", PLUGIN)
			set_task(2.0, "cmdCheckUser", id)
			}
		else
			{
			PrintChatColor(id, PRINT_COLOR_PLAYERTEAM, "!g[%s] !Tbl TTJloXo BeJl Ce69 B EToM roDy", PLUGIN)
			}
	  }
      //case 7: тут по примерам выше
   }
}

public ignite_effects(skIndex[])   {
	new kIndex = skIndex[0]
		
	if (is_user_alive(kIndex) && onfire[kIndex] )    {
		new korigin[3] 
		get_user_origin(kIndex,korigin)
				
		//TE_SPRITE - additive sprite, plays 1 cycle
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY) 
		write_byte( 17 ) 
		write_coord(korigin[0])  // coord, coord, coord (position) 
		write_coord(korigin[1])  
		write_coord(korigin[2]) 
		write_short( mflash ) // short (sprite index) 
		write_byte( 20 ) // byte (scale in 0.1's)  
		write_byte( 200 ) // byte (brightness)
		message_end()
		
		//Smoke
		message_begin( MSG_BROADCAST,SVC_TEMPENTITY,korigin)
		write_byte( 5 )
		write_coord(korigin[0])// coord coord coord (position) 
		write_coord(korigin[1])
		write_coord(korigin[2])
		write_short( smoke )// short (sprite index)
		write_byte( 20 ) // byte (scale in 0.1's)
		write_byte( 15 ) // byte (framerate)
		message_end()
		
		set_task(0.2, "ignite_effects" , 0 , skIndex, 2)		
	}	
	else    {
		if( onfire[kIndex] )   {
			emit_sound(kIndex,CHAN_AUTO, "scientist/scream21.wav", 0.3, ATTN_NORM, 0, PITCH_HIGH)
			onfire[kIndex] = 0
		}
	}	
	return PLUGIN_CONTINUE
}

public ignite_player(skIndex[])   {
	new kIndex = skIndex[0]
		
	if (is_user_alive(kIndex) && onfire[kIndex] )    {
		new korigin[3] 
		new players[32], inum = 0
		new pOrigin[3]		
		new kHeath = get_user_health(kIndex)
		get_user_origin(kIndex,korigin)
		
		//create some damage
		set_user_health(kIndex,kHeath - 2)
		message_begin(MSG_ONE, gmsgDamage, {0,0,0}, kIndex) 
		write_byte(30) // dmg_save
		write_byte(30) // dmg_take 
		write_long(1<<21) // visibleDamageBits 
		write_coord(korigin[0]) // damageOrigin.x 
		write_coord(korigin[1]) // damageOrigin.y
		write_coord(korigin[2]) // damageOrigin.z 
		message_end()
				
		//create some sound
		emit_sound(kIndex,CHAN_ITEM, "ambience/flameburst1.wav", 0.1, ATTN_NORM, 0, PITCH_NORM)
				
		//Ignite Others				
		get_players(players,inum,"a")
		for(new i = 0 ;i < inum; ++i)   {									
			get_user_origin(players[i],pOrigin)				
			if( get_distance(korigin,pOrigin) < 100  )   {
				if( !onfire[players[i]] )   {
					new spIndex[2] 
					spIndex[0] = players[i]
					new pName[32], kName[32]					
					get_user_name(players[i],pName,31)
					get_user_name(kIndex,kName,31)
					emit_sound(players[i],CHAN_WEAPON ,"scientist/scream07.wav", 0.2, ATTN_NORM, 0, PITCH_HIGH)
					client_print(0,3,"* O HET!!! %s 3apa3uJlc9!",kName,pName)
					onfire[players[i]] =1
					ignite_player(players[i])
					ignite_effects(players[i])	
				}					
			}
		}			
		players[0] = 0
		pOrigin[0] = 0					
		korigin[0] = 0		
		
		//Call Again in 2 seconds		
		set_task(2.0, "ignite_player" , 0 , skIndex, 2)		
	}	
		
	return PLUGIN_CONTINUE
}


public fire_player(id) { 

	
	
	new victim = id
	if (!victim) 
		return PLUGIN_HANDLED 

	new skIndex[2]
	skIndex[0] = victim	
	new name[32]
	get_user_name(victim,name,31) 
	
	onfire[victim] = 1
	ignite_effects(skIndex)
	ignite_player(skIndex)
		
	new adminname[32]  
        get_user_name(id,adminname,31)  
	switch(get_cvar_num("amx_show_activity"))   { 
	         case 2:   client_print(0,print_chat,"KoPoHoBuPyc y %s: He TTodXodu K HeMy.",adminname,name) 
	         case 1:   client_print(0,print_chat,"KoPoHoBuPyc y %s: He TTodXodu K HeMy",name) 
	} 
		
	console_print(id,"Client ^"%s^" 3apa}|{eH...",name) 
	
	return PLUGIN_HANDLED 
}  
 
bool: is_user_access(id)
{      
   new flag_access[24]
   get_cvar_string("cv_gift_access", flag_access, charsmax(flag_access))
    
   new flags = get_user_flags(id)
 
   if(contain(flag_access, "a") > -1 && (flags & ADMIN_IMMUNITY))
      return true
      
   if(contain(flag_access, "b") > -1 && (flags & ADMIN_RESERVATION))
      return true
      
   if(contain(flag_access, "c") > -1 && (flags & ADMIN_KICK))
      return true
      
   if(contain(flag_access, "d") > -1 && (flags & ADMIN_BAN))
      return true
      
   if(contain(flag_access, "e") > -1 && (flags & ADMIN_SLAY))
      return true
      
   if(contain(flag_access, "f") > -1 && (flags & ADMIN_MAP))
      return true
      
   if(contain(flag_access, "g") > -1 && (flags & ADMIN_CVAR))
      return true
      
   if(contain(flag_access, "h") > -1 && (flags & ADMIN_CFG))
      return true
      
   if(contain(flag_access, "i") > -1 && (flags & ADMIN_CHAT))
      return true
      
   if(contain(flag_access, "j") > -1 && (flags & ADMIN_VOTE))
      return true
    
   if(contain(flag_access, "k") > -1 && (flags & ADMIN_PASSWORD))
      return true
      
   if(contain(flag_access, "l") > -1 && (flags & ADMIN_RCON))
      return true
      
   if(contain(flag_access, "m") > -1 && (flags & ADMIN_LEVEL_A))
      return true
      
   if(contain(flag_access, "n") > -1 && (flags & ADMIN_LEVEL_B))
      return true
      
   if(contain(flag_access, "o") > -1 && (flags & ADMIN_LEVEL_C))
      return true
      
   if(contain(flag_access, "p") > -1 && (flags & ADMIN_LEVEL_D))
      return true
      
   if(contain(flag_access, "q") > -1 && (flags & ADMIN_LEVEL_E))
      return true
      
   if(contain(flag_access, "r") > -1 && (flags & ADMIN_LEVEL_F))
      return true
      
   if(contain(flag_access, "s") > -1 && (flags & ADMIN_LEVEL_G))
      return true
      
   if(contain(flag_access, "t") > -1 && (flags & ADMIN_LEVEL_H))
      return true
      
   if(contain(flag_access, "u") > -1 && (flags & ADMIN_MENU))
      return true
      
   if(contain(flag_access, "y") > -1 && (flags & ADMIN_ADMIN))
      return true
      
   if(contain(flag_access, "z") > -1 && (flags & ADMIN_USER))
      return true
      
   return false
}
