predict_scorelines <- function(current_gameweek, plot_dc_par = TRUE) {
  
  # map team ids to names
  fpl_all_fixtures <- fpl_get_fixtures() %>%
    rowwise() %>%
    mutate(team_h = team_hash[[as.character(team_h)]],
           team_a = team_hash[[as.character(team_a)]]) %>%
    ungroup() %>%
    select(event, id, kickoff_time, finished, team_h, team_a, team_h_score, team_a_score) %>%
    mutate(team_h = factor(team_h, levels = sort(values(team_hash))),
           team_a = factor(team_a, levels = sort(values(team_hash))))
  
  # split into past and future fixtures
  fpl_past_fixtures <- filter(fpl_all_fixtures, event < current_gameweek)
  fpl_future_fixtures <- filter(fpl_all_fixtures, event >= current_gameweek)
  
  # fit DC model
  dc_fit <- dixoncoles(hgoal = team_h_score, agoal = team_a_score, 
                       hteam = team_h, ateam = team_a, 
                       data = fpl_past_fixtures)
  
  # tidy parameters
  estimates <- tidy.dixoncoles(dc_fit) %>%
    filter(parameter != "rho",
           parameter != "hfa") %>%
    mutate(value = exp(value))
  
  # plot attack/strengths
  if (plot_dc_par) {
    p <- estimates %>%
      spread(parameter, value) %>%
      ggplot(aes(x = def, y = off)) +
      geom_hline(yintercept = 1, linetype = "dotted") +
      geom_vline(xintercept = 1, linetype = "dotted") +
      geom_label(aes(label = team)) +
      theme_minimal() +
      labs(title = "Dixon-Coles parameters for Premier League teams",
           subtitle = str_glue("Based on fixtures before Gameweek {current_gameweek}"),
           x = "Defence",
           y = "Attack")
    print(p)
  }
  
  # predict future scorelines
  pred <- dc_fit %>%
    augment.dixoncoles(data = fpl_future_fixtures, type.predict = "scorelines") %>%
    select(event, kickoff_time, team_h, team_a, .scorelines) %>%
    unnest(.scorelines)
  
  return(pred)
  
}