if SC and SC._data.sc_ai_toggle or restoration and restoration.Options:GetValue("SC/SC") then

	local old_init = CopMovement.init
	local action_variants = {
		security = {
			idle = CopActionIdle,
			act = CopActionAct,
			walk = CopActionWalk,
			turn = CopActionTurn,
			hurt = CopActionHurt,
			stand = CopActionStand,
			crouch = CopActionCrouch,
			shoot = CopActionShoot,
			reload = CopActionReload,
			spooc = ActionSpooc,
			tase = CopActionTase,
			dodge = CopActionDodge,
			warp = CopActionWarp,
			healed = CopActionHealed
		}
	}
	local security_variant = action_variants.security
	function CopMovement:init(unit)
		CopMovement._action_variants.dave = security_variant
		CopMovement._action_variants.cop_civ = security_variant
		CopMovement._action_variants.cop_forest = security_variant
		CopMovement._action_variants.fbi_female = security_variant
		CopMovement._action_variants.hrt = security_variant
		CopMovement._action_variants.fbi_swat_vet = security_variant
		CopMovement._action_variants.swat_titan = security_variant
		CopMovement._action_variants.swat_assault = security_variant
		CopMovement._action_variants.city_swat_titan = security_variant
		CopMovement._action_variants.city_swat_titan_assault = security_variant
		CopMovement._action_variants.skeleton_swat_titan = security_variant
		CopMovement._action_variants.weekend = security_variant
		CopMovement._action_variants.weekend_dmr = security_variant
		CopMovement._action_variants.weekend_lmg = security_variant
		CopMovement._action_variants.omnia = security_variant
		CopMovement._action_variants.omnia_heavy = security_variant
		CopMovement._action_variants.boom = security_variant
		CopMovement._action_variants.rboom = security_variant
		CopMovement._action_variants.fbi_vet = security_variant
		CopMovement._action_variants.vetlod = security_variant		
		CopMovement._action_variants.meme_man = security_variant		
		CopMovement._action_variants.meme_man_shield = clone(security_variant)
		CopMovement._action_variants.meme_man_shield.hurt = ShieldActionHurt
		CopMovement._action_variants.meme_man_shield.walk = ShieldCopActionWalk		
		CopMovement._action_variants.spring = clone(security_variant)
		CopMovement._action_variants.summers = clone(security_variant)
		CopMovement._action_variants.boom_summers = clone(security_variant)
		CopMovement._action_variants.boom_summers.heal = MedicActionHeal
		CopMovement._action_variants.taser_summers = clone(security_variant)
		CopMovement._action_variants.taser_summers.heal = MedicActionHeal
		CopMovement._action_variants.omnia_lpf = security_variant
		CopMovement._action_variants.medic_summers = clone(security_variant)
		CopMovement._action_variants.medic_summers.heal = MedicActionHeal
		CopMovement._action_variants.tank_titan = clone(security_variant)
		CopMovement._action_variants.tank_titan.walk = TankCopActionWalk
		CopMovement._action_variants.tank_titan_assault = clone(security_variant)
		CopMovement._action_variants.tank_titan_assault.walk = TankCopActionWalk
		CopMovement._action_variants.tank_biker = clone(security_variant)
		CopMovement._action_variants.tank_biker.walk = TankCopActionWalk
		CopMovement._action_variants.biker_guard = security_variant
		CopMovement._action_variants.phalanx_minion_assault = clone(security_variant)
		CopMovement._action_variants.phalanx_minion_assault.hurt = ShieldActionHurt
		CopMovement._action_variants.phalanx_minion_assault.walk = ShieldCopActionWalk
		CopMovement._action_variants.spooc_titan = security_variant
		CopMovement._action_variants.autumn = security_variant
		CopMovement._action_variants.taser_titan = clone(security_variant)
		
		old_init(self, unit)		
	end
	
	function CopMovement:post_init()
		local unit = self._unit
		self._ext_brain = unit:brain()
		self._ext_network = unit:network()
		self._ext_anim = unit:anim_data()
		self._ext_base = unit:base()
		self._ext_damage = unit:character_damage()
		self._ext_inventory = unit:inventory()
		self._tweak_data = tweak_data.character[self._ext_base._tweak_table]

		tweak_data:add_reload_callback(self, self.tweak_data_clbk_reload)
		self._machine:set_callback_object(self)

		self._stance = {
			name = "ntl",
			code = 1,
			values = {
				1,
				0,
				0,
				0
			}
		}

		if managers.navigation:is_data_ready() then
			self._nav_tracker = managers.navigation:create_nav_tracker(self._m_pos)
			self._pos_rsrv_id = managers.navigation:get_pos_reservation_id()
		else
			Application:error("[CopMovement:post_init] Spawned AI unit with incomplete navigation data.")
			self._unit:set_extension_update(ids_movement, false)
		end

		self._unit:kill_mover()
		self._unit:set_driving("script")

		self._unit:unit_data().has_alarm_pager = self._tweak_data.has_alarm_pager
		local event_list = {
			"bleedout",
			"light_hurt",
			"heavy_hurt",
			"expl_hurt",
			"hurt",
			"hurt_sick",
			"shield_knock",
			"knock_down",
			"stagger",
			"counter_tased",
			"taser_tased",
			"death",
			"fatal",
			"fire_hurt",
			"poison_hurt",
			"concussion"
		}

		table.insert(event_list, "healed")
		self._unit:character_damage():add_listener("movement", event_list, callback(self, self, "damage_clbk"))
		self._unit:inventory():add_listener("movement", {
			"equip",
			"unequip"
		}, callback(self, self, "clbk_inventory"))
		self:add_weapons()

		if self._unit:inventory():is_selection_available(2) then
			if managers.groupai:state():whisper_mode() or not self._unit:inventory():is_selection_available(1) then
				self._unit:inventory():equip_selection(2, true)
			else
				self._unit:inventory():equip_selection(1, true)
			end
		elseif self._unit:inventory():is_selection_available(1) then
			self._unit:inventory():equip_selection(1, true)
		end

		if self._ext_inventory:equipped_selection() == 2 and managers.groupai:state():whisper_mode() then
			self._ext_inventory:set_weapon_enabled(false)
		end

		local weap_name = self._ext_base:default_weapon_name(managers.groupai:state():enemy_weapons_hot() and "primary" or "secondary")
		local fwd = self._m_rot:y()
		self._action_common_data = {
			stance = self._stance,
			pos = self._m_pos,
			rot = self._m_rot,
			fwd = fwd,
			right = self._m_rot:x(),
			unit = unit,
			machine = self._machine,
			ext_movement = self,
			ext_brain = self._ext_brain,
			ext_anim = self._ext_anim,
			ext_inventory = self._ext_inventory,
			ext_base = self._ext_base,
			ext_network = self._ext_network,
			ext_damage = self._ext_damage,
			char_tweak = self._tweak_data,
			nav_tracker = self._nav_tracker,
			active_actions = self._active_actions,
			queued_actions = self._queued_actions,
			look_vec = mvector3.copy(fwd)
		}

		self:upd_ground_ray()

		if self._gnd_ray then
			self:set_position(self._gnd_ray.position)
		end

		self:_post_init()
		self._omnia_cooldown = 0
		self._aoe_heal_cooldown = 0
		self._aoe_blackout_cooldown = 0		
	end	

	function CopMovement:_upd_actions(t)
		local a_actions = self._active_actions
		local has_no_action = true
		for i_action, action in ipairs(a_actions) do
			if action then
				if action.update then
					action:update(t)
				end
				if not self._need_upd and action.need_upd then
					self._need_upd = action:need_upd()
				end
				if action.expired and action:expired() then
					a_actions[i_action] = false
					if action.on_exit then
						action:on_exit()
					end
					self._ext_brain:action_complete_clbk(action)
					self._ext_base:chk_freeze_anims()
					for _, action in ipairs(a_actions) do
						if action then
							has_no_action = nil
						else
						end
					end
				else
					has_no_action = nil
				end
			end
		end
		if has_no_action and (not self._queued_actions or not next(self._queued_actions)) then
			self:action_request({type = "idle", body_part = 1})
		end
		if not a_actions[1] and not a_actions[2] and (not self._queued_actions or not next(self._queued_actions)) and not self:chk_action_forbidden("action") then
			if a_actions[3] then
				self:action_request({type = "idle", body_part = 2})
			else
				self:action_request({type = "idle", body_part = 1})
			end
		end

		self:_upd_stance(t)

		--removing the check pretty much fixes panic + other systems that can cause enemies
		--to become stuck or take too long to respond, no downsides found yet
		self._need_upd = true

		if self._tweak_data.do_omnia then
			if not self._unit:character_damage():dead() then			
				self:do_omnia(self)		
			end
		end
		if self._tweak_data.do_aoe_heal then
			if not self._unit:character_damage():dead() then			
				self:do_aoe_heal(self)		
			end
		end	
		if self._tweak_data.do_winters_aoe_heal then
			if not self._unit:character_damage():dead() then			
				self:do_winters_aoe_heal(self)		
			end
		end			
		if self._tweak_data.do_summers_heal then
			if not self._unit:character_damage():dead() then			
				self:do_summers_heal(self)		
			end
		end		
		if self._tweak_data.do_autumn_blackout then 
			self:do_autumn_blackout(self)
		end
	end

	function CopMovement:do_omnia(self)
		local t = TimerManager:main():time()
		if self._omnia_cooldown > t then
			return
		else
			self._omnia_cooldown = t + 0.2
		end
		if self and self._unit then
			if self._unit:base()._tweak_table == "omnia_lpf" or self._unit:base()._tweak_table == "phalanx_vip" and not self._unit:character_damage():dead() then
				local cops_to_heal = {
					"cop",
					"cop_scared",
					"cop_female",
					"fbi",
					"swat"
				}
				local enemies = World:find_units_quick(self._unit, "sphere", self._unit:position(), tweak_data.medic.lpf_radius * 1, managers.slot:get_mask("enemies"))
				if enemies then
					restoration.log_shit("SC: FOUND ENEMIES")
					for _,enemy in ipairs(enemies) do
						local found_dat_shit = false
						for __,enemy_type in ipairs(cops_to_heal) do
							restoration.log_shit("SC: CHECKING " .. enemy_type .. " VS " .. enemy:base()._tweak_table)
							if enemy:base()._tweak_table == enemy_type then
								restoration.log_shit("SC: ENEMY TO HEAL FOUND " .. enemy_type)
								found_dat_shit = true
							end
						end
						if found_dat_shit then
							local health_left = enemy:character_damage()._health
							restoration.log_shit("SC: health_left: " .. tostring(health_left))
							local max_health = enemy:character_damage()._HEALTH_INIT * 2
							restoration.log_shit("SC: max_health: " .. tostring(max_health))
							if health_left < max_health then
								local amount_to_heal = math.ceil(((max_health - health_left) / 20))
								restoration.log_shit("SC: HEALING FOR " .. amount_to_heal)
								if self._unit:contour() then
									self._unit:contour():add("medic_show", false)
									self._unit:contour():flash("medic_show", 0.2)
									managers.groupai:state():chk_say_enemy_chatter(self._unit, self._m_pos, "heal_chatter")
								end										
								if enemy:contour() then
									enemy:contour():add("omnia_heal", false)
								end		
								enemy:character_damage():_apply_damage_to_health((amount_to_heal * -1))
							end
						end
					end
				end
			end
		else
			restoration.log_shit("SC: UNIT NOT FOUND WTF")
		end
	end

	function CopMovement:do_autumn_blackout(self)	
		local test_kicker = false 
		
	--every [cooldown] seconds:
		-- check all equipment units with equipment tweakdata tag "blackout_vulnerable"
		-- for each of these units:
			-- if (in surrounding [radius] area): set var "blackout_active" to "true
			-- else: set var "blackout_active" 
	
		local blackout_cooldown = 1
		local blackout_radius = 600000 --target equipment acquisition to apply blackout aoe to
		local t = TimerManager:main():time()
		if self._aoe_blackout_cooldown > t then
			return
		else
			self._aoe_blackout_cooldown = t + blackout_cooldown
		end
		
		if self._unit then
			if self._unit:character_damage():dead() then return end --autumn's corpse will still disable equipment otherwise
			
			local all_eq = World:find_units_quick("all",14,25,26)
			local closest = { --not currently used
				--unit = false, 
				--distance = math.huge()
			}
			for k,unit in pairs(all_eq) do 
				if unit and alive(unit) and unit:base() then
					
					local dis = mvector3.distance_sq(self._unit:position(),unit:position())
					if unit:interaction() and unit:interaction()._tweak_data and unit:interaction()._tweak_data.blackout_vulnerable then 
						if not test_kicker then 
							if dis < blackout_radius and not unit:base().blackout_active then --within blackout aoe
								if unit:base().get_name_id then 
									local eq_id = unit:base():get_name_id() or "ERROR"
									if eq_id == "sentry_gun" then --perish
										unit:character_damage():die()
									elseif eq_id == "ecm_jammer" then 
										unit:base():set_battery_empty()
										unit:base():_set_feedback_active(false)
									end
								end
								
								unit:base().blackout_active = true
								
								if unit.contour and unit:contour() then 
									unit:contour():add("deployable_blackout")
								end
							elseif dis >= blackout_radius and unit:base().blackout_active then
							
								unit:base().blackout_active = false
								
								if unit.contour and unit:contour() then 
									unit:contour():remove("deployable_blackout")
								end
							end
						elseif (dis < (closest.distance or blackout_radius)) then --do dick kickem
							closest = {
								distance = distance,
								unit = unit
							}
						end 
					end
				end
			end
			if test_kicker then  --unused

				if closest.unit then 
					local followup_objective = {
						type = "act",
						scan = true,
						action = {type = "act", body_part = 1, variant = "crouch", 
									blocks = {action = -1, walk = -1, hurt = -1, heavy_hurt = -1, aim = -1}
								}
						}
					local act = "e_so_container_kick"
					local override_objective = {
						type = act,
						follow_unit = self._unit,
						called = true,
						destroy_clbk_key = false,
						nav_seg = self._nav_tracker:nav_segment(),
						pos = closest.unit:position(),
						scan = true,
						action = {
							type = "act", 
							variant = act,
							body_part = 1,
							blocks = {action = -1, walk = -1, hurt = -1, light_hurt = -1, heavy_hurt = -1 ,aim = -1},
							align_sync = true,
							},
						action_duration = 3,
						followup_objective = followup_objective,
						complete_clbk = callback(self,self,"clbk_autumn_blackout_complete"),
						fail_clbk = callback(self,self,"clbk_autumn_blackout_cancel")
						
					}
					self._ext_brain:set_objective(override_objective)
				end
			end
		end
	end
	
	function CopMovement:clbk_autumn_blackout_cancel(self) --not used
		--OffyLib:c_log(target,"Cancelled blackout on unit")
	end
	function CopMovement:clbk_autumn_blackout_complete(self) --not used
		--OffyLib:c_log(target,"Done blackout on unit")
	end
	

	function CopMovement:do_aoe_heal(self)
		local t = TimerManager:main():time()
		if self._aoe_heal_cooldown > t then
			return
		else
			self._aoe_heal_cooldown = t + 0.4
		end
		if self and self._unit then
			if self._unit:base()._tweak_table == "omnia_lpf" and not self._unit:character_damage():dead() then
				local cops_to_heal = {
					"heavy_swat",
					"fbi_swat",
					"fbi_heavy_swat",
					"city_swat",
					"omnia",
					"tank",
					"tank_hw",
					"tank_mini",
					"spooc",
					"shield",
					"taser",
					"boom",
					"rboom"
				}
				local enemies = World:find_units_quick(self._unit, "sphere", self._unit:position(), tweak_data.medic.lpf_radius * 1, managers.slot:get_mask("enemies"))
				if enemies then
					restoration.log_shit("SC: FOUND ENEMIES")
					for _,enemy in ipairs(enemies) do
						local found_dat_shit = false
						for __,enemy_type in ipairs(cops_to_heal) do
							restoration.log_shit("SC: CHECKING " .. enemy_type .. " VS " .. enemy:base()._tweak_table)
							if enemy:base()._tweak_table == enemy_type then
								restoration.log_shit("SC: ENEMY TO HEAL FOUND " .. enemy_type)
								found_dat_shit = true
							end
						end
						if found_dat_shit then
							local health_left = enemy:character_damage()._health
							restoration.log_shit("SC: health_left: " .. tostring(health_left))
							local max_health = enemy:character_damage()._HEALTH_INIT * 1
							restoration.log_shit("SC: max_health: " .. tostring(max_health))
							if health_left < max_health then
								local amount_to_heal = math.ceil(((max_health - health_left) / 20))
								restoration.log_shit("SC: HEALING FOR " .. amount_to_heal)
								if self._unit:contour() then
									self._unit:contour():add("medic_show", false)
									self._unit:contour():flash("medic_show", 0.2)
									managers.groupai:state():chk_say_enemy_chatter(self._unit, self._m_pos, "heal_chatter")
								end								
								if enemy:contour() then
									enemy:contour():add("medic_heal", true)
									enemy:contour():flash("medic_heal", 0.2)
								end		
								enemy:character_damage():_apply_damage_to_health((amount_to_heal * -1))							
							end
						end
					end
				end
			end
		else
			restoration.log_shit("SC: UNIT NOT FOUND WTF")
		end
	end
	
	function CopMovement:do_winters_aoe_heal(self)
		local t = TimerManager:main():time()
		if self._aoe_heal_cooldown > t then
			return
		else
			self._aoe_heal_cooldown = t + 0.4
		end
		if self and self._unit then
			if self._unit:base()._tweak_table == "phalanx_vip" and not self._unit:character_damage():dead() then
				local cops_to_heal = {
					"cop",
					"cop_scared",
					"cop_female",
					"fbi",
					"swat",					
					"heavy_swat",
					"fbi_swat",
					"fbi_heavy_swat",
					"city_swat",
					"omnia",
					"tank",
					"tank_hw",
					"tank_mini",
					"spooc",
					"shield",
					"phalanx_minion",
					"taser",
					"boom",
					"rboom"
				}
				local enemies = World:find_units_quick(self._unit, "sphere", self._unit:position(), tweak_data.medic.lpf_radius * 4, managers.slot:get_mask("enemies"))
				if enemies then
					restoration.log_shit("SC: FOUND ENEMIES")
					for _,enemy in ipairs(enemies) do
						local found_dat_shit = false
						for __,enemy_type in ipairs(cops_to_heal) do
							restoration.log_shit("SC: CHECKING " .. enemy_type .. " VS " .. enemy:base()._tweak_table)
							if enemy:base()._tweak_table == enemy_type then
								restoration.log_shit("SC: ENEMY TO HEAL FOUND " .. enemy_type)
								found_dat_shit = true
							end
						end
						if found_dat_shit then
							local health_left = enemy:character_damage()._health
							restoration.log_shit("SC: health_left: " .. tostring(health_left))
							local max_health = enemy:character_damage()._HEALTH_INIT * 1
							restoration.log_shit("SC: max_health: " .. tostring(max_health))
							if health_left < max_health then
								local amount_to_heal = math.ceil(((max_health - health_left) / 20))
								restoration.log_shit("SC: HEALING FOR " .. amount_to_heal)
								if self._unit:contour() then
									self._unit:contour():add("medic_show", false)
									self._unit:contour():flash("medic_show", 0.2)
									managers.groupai:state():chk_say_enemy_chatter(self._unit, self._m_pos, "heal_chatter_winters")
								end								
								if enemy:contour() then
									enemy:contour():add("medic_heal", true)
									enemy:contour():flash("medic_heal", 0.2)
								end		
								enemy:character_damage():_apply_damage_to_health((amount_to_heal * -1))							
							end
						end
					end
				end
			end
		else
			restoration.log_shit("SC: UNIT NOT FOUND WTF")
		end
	end	

	function CopMovement:do_summers_heal(self)
		local t = TimerManager:main():time()
		if self._aoe_heal_cooldown > t then
			return
		else
			self._aoe_heal_cooldown = t + 0.4
		end
		if self and self._unit then
			if self._unit:base()._tweak_table == "medic_summers" and not self._unit:character_damage():dead() then
				local cops_to_heal = {
					"taser_summers",
					"boom_summers",
					"summers"
				}
				local enemies = World:find_units_quick(self._unit, "sphere", self._unit:position(), tweak_data.medic.doc_radius * 1, managers.slot:get_mask("enemies"))
				if enemies then
					restoration.log_shit("SC: FOUND ENEMIES")
					for _,enemy in ipairs(enemies) do
						local found_dat_shit = false
						for __,enemy_type in ipairs(cops_to_heal) do
							restoration.log_shit("SC: CHECKING " .. enemy_type .. " VS " .. enemy:base()._tweak_table)
							if enemy:base()._tweak_table == enemy_type then
								restoration.log_shit("SC: ENEMY TO HEAL FOUND " .. enemy_type)
								found_dat_shit = true
							end
						end
						if found_dat_shit then
							local health_left = enemy:character_damage()._health
							restoration.log_shit("SC: health_left: " .. tostring(health_left))
							local max_health = enemy:character_damage()._HEALTH_INIT * 1
							restoration.log_shit("SC: max_health: " .. tostring(max_health))
							if health_left < max_health then
								local amount_to_heal = math.ceil(((max_health - health_left) / 20))
								restoration.log_shit("SC: HEALING FOR " .. amount_to_heal)
								if self._unit:contour() then
									self._unit:contour():add("medic_show", false)
									self._unit:contour():flash("medic_show", 0.2)
									managers.groupai:state():chk_say_enemy_chatter(self._unit, self._m_pos, "heal_chatter")
								end								
								if enemy:contour() then
									enemy:contour():add("medic_heal", true)
									enemy:contour():flash("medic_heal", 0.2)
								end		
								enemy:character_damage():_apply_damage_to_health((amount_to_heal * -1))							
							end
						end
					end
				end
			end
		else
			restoration.log_shit("SC: UNIT NOT FOUND WTF")
		end
	end
	
	function CopMovement:play_redirect(redirect_name, at_time)
		--Not pretty but groupai didn't like me checking unit slots
		if redirect_name == "throw_grenade" then 
			if self._unit:in_slot(16) or self._unit:in_slot(22) then	
				return 
			end
		end
		
		local result = self._unit:play_redirect(Idstring(redirect_name), at_time)
		

		return result ~= Idstring("") and result
	end
	
	local mvec3_set = mvector3.set
	local mvec3_set_z = mvector3.set_z
	local mvec3_lerp = mvector3.lerp
	local mvec3_add = mvector3.add
	local mvec3_sub = mvector3.subtract
	local mvec3_mul = mvector3.multiply
	local mvec3_norm = mvector3.normalize
	local mvec3_len = mvector3.length
	local mrot_set = mrotation.set_yaw_pitch_roll
	local temp_vec1 = Vector3()
	local temp_vec2 = Vector3()
	local temp_vec3 = Vector3()

	function CopMovement:on_suppressed(state)
		local suppression = self._suppression
		local end_value = state and 1 or 0
		local vis_state = self._ext_base:lod_stage() 

		--vis_state is used to do a smooth transition instead of snapping into the suppressed stance
		--as long as the enemy is visible
		if vis_state and end_value ~= suppression.value then
			local t = TimerManager:game():time()
			local duration = 0.5 * math.abs(end_value - suppression.value)
			suppression.transition = {
				end_val = end_value,
				start_val = suppression.value,
				duration = duration,
				start_t = t,
				next_upd_t = t + 0.07
			}
		else
			suppression.transition = nil
			suppression.value = end_value

			self._machine:set_global("sup", end_value)
		end

		self._action_common_data.is_suppressed = state and true or nil

		if Network:is_server() and state then
			if self._tweak_data.allowed_poses and (self._tweak_data.allowed_poses.crouch or self._tweak_data.allowed_poses.stand) or self:chk_action_forbidden("walk") then
				--nothing
			elseif state == "panic" and not self:chk_action_forbidden("act") then
				if self._ext_anim.run and self._ext_anim.move_fwd then
					local action_desc = {
						clamp_to_graph = true,
						type = "act",
						body_part = 1,
						variant = "e_so_sup_fumble_run_fwd",
						blocks = {
							action = -1,
							walk = -1
						}
					}

					self:action_request(action_desc)
				else
					local function debug_fumble(result, from, to)
					end

					local vec_from = temp_vec1
					local vec_to = temp_vec2
					local ray_params = {
						allow_entry = false,
						trace = true,
						tracker_from = self:nav_tracker(),
						pos_from = vec_from,
						pos_to = vec_to
					}
					local allowed_fumbles = {
						"e_so_sup_fumble_inplace_3"
					}
					local allow = nil

					mvec3_set(vec_from, self:m_pos())
					mvec3_set(vec_to, self:m_rot():y())
					mvec3_mul(vec_to, -100)
					mvec3_add(vec_to, self:m_pos())

					allow = not managers.navigation:raycast(ray_params)

					debug_fumble(allow, vec_from, vec_to)

					if allow then
						table.insert(allowed_fumbles, "e_so_sup_fumble_inplace_1")
					end

					mvec3_set(vec_from, self:m_pos())
					mvec3_set(vec_to, self:m_rot():x())
					mvec3_mul(vec_to, 200)
					mvec3_add(vec_to, self:m_pos())

					allow = not managers.navigation:raycast(ray_params)

					debug_fumble(allow, vec_from, vec_to)

					if allow then
						table.insert(allowed_fumbles, "e_so_sup_fumble_inplace_2")
					end

					mvec3_set(vec_from, self:m_pos())
					mvec3_set(vec_to, self:m_rot():x())
					mvec3_mul(vec_to, -200)
					mvec3_add(vec_to, self:m_pos())

					allow = not managers.navigation:raycast(ray_params)

					debug_fumble(allow, vec_from, vec_to)

					if allow then
						table.insert(allowed_fumbles, "e_so_sup_fumble_inplace_4")
					end

					if #allowed_fumbles > 0 then
						local action_desc = {
							body_part = 1,
							type = "act",
							variant = allowed_fumbles[math.random(#allowed_fumbles)],
							blocks = {
								action = -1,
								walk = -1
							}
						}

						self:action_request(action_desc)
					end
				end
			elseif self._ext_anim.idle and (not self._active_actions[2] or self._active_actions[2]:type() == "idle") and not self:chk_action_forbidden("act") then
				local action_desc = {
					clamp_to_graph = true,
					type = "act",
					body_part = 1,
					variant = "suppressed_reaction",
					blocks = {
						walk = -1
					}
				}

				self:action_request(action_desc)
			elseif not self._ext_anim.crouch then
				if self._ext_anim.run then
					if self._tweak_data.can_slide_on_suppress and not self:chk_action_forbidden("act") then
						local action_desc = {
							clamp_to_graph = true,
							type = "act",
							body_part = 1,
							variant = "e_nl_slide_fwd_4m",
							blocks = {
								action = -1,
								walk = -1
							}
						}

						self:action_request(action_desc)
						--this will currently be done by anyone without "poses" but add stuff like 
						--can_slide_on_suppress = true
						--to charactertweakdata on the enemies that should be able to slide to further narrow it down so only certain enemies can do slides
					end
				elseif not self._tweak_data.allowed_poses or self._tweak_data.allowed_poses.crouch then
					local action_desc = nil

					if self._ext_anim.move then
						if self._tweak_data.crouch_move then
							action_desc = {
								body_part = 4,
								type = "crouch"
							}
						end
					else
						action_desc = {
							body_part = 4,
							type = "crouch"
						}
					end

					if action_desc and not self:chk_action_forbidden("crouch") then
						self:action_request(action_desc)
					end
				end
			end
		end

		self:enable_update()

		if Network:is_server() then
			managers.network:session():send_to_peers_synched("suppressed_state", self._unit, state and true or false)
		end
	end

	--crash prevention
	function CopMovement:anim_clbk_enemy_spawn_melee_item()
		if alive(self._melee_item_unit) then
			return
		end

		local melee_weapon = self._unit:base().melee_weapon and self._unit:base():melee_weapon()
		local unit_name = melee_weapon and melee_weapon ~= "weapon" and tweak_data.weapon.npc_melee[melee_weapon] and tweak_data.weapon.npc_melee[melee_weapon].unit_name or nil

		if unit_name then
			local align_obj_l_name = CopMovement._gadgets.aligns.hand_l
			local align_obj_l = self._unit:get_object(align_obj_l_name)

			self._melee_item_unit = World:spawn_unit(unit_name, align_obj_l:position(), align_obj_l:rotation())
			self._unit:link(align_obj_l:name(), self._melee_item_unit, self._melee_item_unit:orientation_object():name())
		end
	end

	function CopMovement:set_uncloaked(state)
		if state then
			managers.network:session():send_to_peers_synched("sync_unit_event_id_16", self._unit, "brain", HuskCopBrain._NET_EVENTS.uncloak)
		else
			managers.network:session():send_to_peers_synched("sync_unit_event_id_16", self._unit, "brain", HuskCopBrain._NET_EVENTS.cloak)
		end

		self._uncloaked = state
	end

	--used for Titan Spoocs and Autumn
	function CopMovement:is_uncloaked()
		return self._uncloaked
	end

	--syncing stuff
	function CopMovement:sync_reload_weapon(empty_reload, reload_speed_multiplier)
		local reload_action = {
			body_part = 3,
			type = "reload",
			idle_reload = empty_reload ~= 0 and empty_reload or nil
		}

		self:action_request(reload_action)
	end

	--syncing stuff
	function CopMovement:sync_fall_position(pos, rot)
		self:set_position(pos)
		self:set_rotation(rot)
	end

	function CopMovement:damage_clbk(my_unit, damage_info)
		local hurt_type = damage_info.result.type

		if damage_info.variant == "explosion" or damage_info.variant == "bullet" or damage_info.variant == "fire" or damage_info.variant == "poison" then
			hurt_type = managers.modifiers:modify_value("CopMovement:HurtType", hurt_type)
		end

		if hurt_type == "stagger" then
			hurt_type = "heavy_hurt"
		end

		if hurt_type == "hurt" or hurt_type == "heavy_hurt" or hurt_type == "knock_down" then
			if self._anim_global and self._anim_global == "shield" then
				hurt_type = "expl_hurt"
			end
		end

		local block_type = hurt_type

		if hurt_type == "knock_down" or hurt_type == "expl_hurt" or hurt_type == "fire_hurt" or hurt_type == "poison_hurt" or hurt_type == "taser_tased" then
			block_type = "heavy_hurt"
		end

		if hurt_type == "death" and self._queued_actions then
			self._queued_actions = {}
		end

		if not hurt_type or Network:is_server() and self:chk_action_forbidden(block_type) then
			if hurt_type == "death" then
				debug_pause_unit(self._unit, "[CopMovement:damage_clbk] Death action skipped!!!", self._unit)
				Application:draw_cylinder(self._m_pos, self._m_pos + math.UP * 5000, 30, 1, 0, 0)

				for body_part, action in ipairs(self._active_actions) do
					if action then
						print(body_part, action:type(), inspect(action._blocks))
					end
				end
			end

			return
		end

		if damage_info.variant == "stun" and alive(self._ext_inventory and self._ext_inventory._shield_unit) then
			hurt_type = "shield_knock"
			block_type = "shield_knock"
			damage_info.variant = "melee"
			damage_info.result = {
				variant = "melee",
				type = "shield_knock"
			}
			damage_info.shield_knock = true
		end

		if hurt_type == "death" then
			if self._rope then
				self._rope:base():retract()

				self._rope = nil
				self._rope_death = true

				if self._unit:sound().anim_clbk_play_sound then
					self._unit:sound():anim_clbk_play_sound(self._unit, "repel_end")
				end
			end

			if Network:is_server() then
				self:set_attention()
			else
				self:synch_attention()
			end
		end

		local attack_dir = damage_info.col_ray and damage_info.col_ray.ray or damage_info.attack_dir
		local hit_pos = damage_info.col_ray and damage_info.col_ray.position or damage_info.pos
		local lgt_hurt = hurt_type == "light_hurt"
		local body_part = lgt_hurt and 4 or 1
		local blocks = nil

		if not lgt_hurt then
			blocks = {
				act = -1,
				aim = -1,
				action = -1,
				tase = -1,
				walk = -1,
				light_hurt = -1
			}

			if hurt_type == "bleedout" then
				blocks.bleedout = -1
				blocks.hurt = -1
				blocks.heavy_hurt = -1
				blocks.hurt_sick = -1
				blocks.concussion = -1
			end

			if hurt_type == "shield_knock" then
				blocks.light_hurt = -1
				blocks.concussion = -1
			end

			if hurt_type == "concussion" or hurt_type == "counter_tased" then
				blocks.hurt = -1
				blocks.light_hurt = -1
				blocks.heavy_hurt = -1
				blocks.stagger = -1
				blocks.knock_down = -1
				blocks.counter_tased = -1
				blocks.hurt_sick = -1
				blocks.expl_hurt = -1
				blocks.counter_spooc = -1
				blocks.fire_hurt = -1
				blocks.taser_tased = -1
				blocks.poison_hurt = -1
				blocks.shield_knock = -1
				blocks.concussion = -1
			end
		end

		if damage_info.variant == "tase" then
			block_type = "bleedout"
		elseif hurt_type == "expl_hurt" or hurt_type == "fire_hurt" or hurt_type == "poison_hurt" or hurt_type == "taser_tased" then
			block_type = "heavy_hurt"
		else
			block_type = hurt_type
		end

		local client_interrupt = nil

		if Network:is_client() and (hurt_type == "light_hurt" or hurt_type == "hurt" and damage_info.variant ~= "tase" or hurt_type == "heavy_hurt" or hurt_type == "expl_hurt" or hurt_type == "shield_knock" or hurt_type == "counter_tased" or hurt_type == "taser_tased" or hurt_type == "counter_spooc" or hurt_type == "death" or hurt_type == "hurt_sick" or hurt_type == "fire_hurt" or hurt_type == "poison_hurt" or hurt_type == "concussion") then
			client_interrupt = true
		end

		local tweak = self._tweak_data
		local action_data = nil

		if hurt_type == "healed" then
			if Network:is_client() then
				client_interrupt = true
			end

			action_data = {
				body_part = 3,
				type = "healed",
				client_interrupt = client_interrupt
			}
		else
			action_data = {
				type = "hurt",
				block_type = block_type,
				hurt_type = hurt_type,
				variant = damage_info.variant,
				direction_vec = attack_dir,
				hit_pos = hit_pos,
				body_part = body_part,
				blocks = blocks,
				client_interrupt = client_interrupt,
				attacker_unit = damage_info.attacker_unit,
				death_type = tweak.damage.death_severity and (tweak.damage.death_severity < damage_info.damage / tweak.HEALTH_INIT and "heavy" or "normal") or "normal",
				ignite_character = damage_info.ignite_character,
				start_dot_damage_roll = damage_info.start_dot_damage_roll,
				is_fire_dot_damage = damage_info.is_fire_dot_damage,
				fire_dot_data = damage_info.fire_dot_data,
				is_synced = damage_info.is_synced
			}
		end

		local request_action = Network:is_server() or not self:chk_action_forbidden(action_data)

		if damage_info.is_synced and (hurt_type == "knock_down" or hurt_type == "heavy_hurt") then
			request_action = false
		end

		if request_action then
			self:action_request(action_data)

			if hurt_type == "death" and self._queued_actions then
				self._queued_actions = {}
			end
		end
	end
end
