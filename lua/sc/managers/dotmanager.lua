function DOTManager:create_dot_data(type, custom_data)
	local dot_data = deep_clone(tweak_data:get_dot_type_data(type))

	if custom_data then
		dot_data.dot_length = custom_data.dot_length or dot_data.dot_length
		dot_data.hurt_animation_chance = custom_data.hurt_animation_chance or dot_data.hurt_animation_chance
		dot_data.dot_damage = custom_data.dot_damage or dot_data.dot_damage
	end

	return dot_data
end