get_los_pool <- function(min_gi, min_minutes, exclude_ids) {
  
  # get df of all players
  data <- fpl_get_player_all() %>% 
    select(id, web_name, team, minutes, goals_scored, assists) %>%
    filter(!id %in% exclude_ids)
  
  # filter based on GI and minutes
  data <- filter(data, goals_scored + assists > min_gi & minutes > min_minutes)
  
  # add players' names and teams
  data <- data %>%
    rowwise() %>%
    mutate(name = player_hash[[as.character(id)]],
           team = team_hash[[as.character(team)]]) %>%
    select(-web_name) %>%
    relocate(name, .after = id)
  
  return(data)
}


get_player_gi <- function(id, current_gameweek) {
  
  fpl_get_player_current(id) %>% 
    filter(round < current_gameweek) %>%
    mutate(team_goals_scored = case_when(
      was_home ~ team_h_score,
      .default = team_a_score
    )) %>%
    summarise(
      goals_scored = sum(goals_scored),
      assists = sum(assists),
      neither = sum(team_goals_scored) - goals_scored - assists,
      minutes = sum(minutes),
      team_goals_scored = sum(team_goals_scored),
      team_matches = n(),
      team_minutes = 90 * team_matches,
    ) %>%
    summarise(
      average_minutes = 90 * minutes / team_minutes,
      p_score = team_matches * (goals_scored / team_goals_scored) * (team_minutes / minutes),
      p_assist = team_matches * (assists / team_goals_scored) * (team_minutes / minutes),
      p_neither = team_matches * ((neither / team_goals_scored) - (team_minutes - minutes) / team_minutes) * (team_minutes / minutes),
      total = p_score + p_assist + p_neither
    ) %>%
    mutate(
      p_score = p_score / total,
      p_assist = p_assist / total,
      p_neither = p_neither / total
    ) %>%
    select(-total)
}

fit_los_simplex <- function(los_players_pool, current_gameweek) {
  los_players_pool %>%
    rowwise() %>%
    mutate(simplex = list(get_player_gi(id, current_gameweek))) %>%
    unnest_wider(simplex)
}


p_no_goal_inv <- function(p_neither, minutes, team_goals) {
  ((minutes * (p_neither - 1) + 90) / 90)^team_goals
}

get_gw_probs <- function(pred_score, team, p_neither, average_minutes) {
  
  pred_score %>% 
    mutate(p_neither = case_when(
      team_h == team ~ p_no_goal_inv(p_neither, average_minutes, hgoal),
      team_a == team ~ p_no_goal_inv(p_neither, average_minutes, agoal),
      .default = 1
    )
    ) %>%
    group_by(event, kickoff_time, team_h, team_a) %>%
    summarise(p_neither = sum(p_neither * prob)) %>%
    ungroup() %>%
    group_by(event) %>%
    summarise(p_neither = prod(p_neither)) %>%
    pull(p_neither) %>%
    set_names(unique(pred_score$event))
}

get_los_gw_probs <- function(pred_score, player_simplex) {
  
  player_simplex %>%
    rowwise() %>%
    mutate(gameweek_p_neither = list(get_gw_probs(pred_score, team, p_neither, average_minutes))) %>%
    ungroup() %>%
    select(id, name, team, gameweek_p_neither) %>% 
    unnest_longer(gameweek_p_neither, values_to = "p_neither", indices_to = "gameweek") 
} 
