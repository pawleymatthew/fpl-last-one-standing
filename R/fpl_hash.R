team_info <- fpl_get_teams() %>% select(id, short_name, name)

player_info <- fpl_get_player_all() %>%
  select(id, first_name, second_name, web_name) %>%
  unite(full_name, c("first_name", "second_name"), sep = " ")

player_hash <- hash(as.character(player_info$id), player_info$full_name)
team_hash <- hash(as.character(team_info$id), team_info$short_name)