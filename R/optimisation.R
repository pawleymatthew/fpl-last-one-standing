get_los_selection <- function(gw_probs, greedy_k, prev_selected_ids) {
  
  wildcards <- 35
  
  prev_selected_names <- sapply(prev_selected_ids, function(id) player_hash[[as.character(id)]])
  gw_vals <- unique(gw_probs$gameweek) %>% sort() %>% as.integer()
  squad <- tibble("id" = integer(), 
                  "name" = character(), 
                  "team" = character(), 
                  "p_neither" = numeric(), 
                  "gameweek" = character())
  
  for (gw in gw_vals) {
    week_squad <- gw_probs %>%
      filter(case_when(
        !gw %in% as.character(wildcards) ~ !name %in% c(prev_selected_names, squad$name),
        .default = is.character(name))) %>%
      filter(gameweek == gw) %>%
      slice_min(p_neither, n = ifelse(gw == tail(gw_vals, n = 1), 3, greedy_k)) %>%
      slice_sample(n = 3)
    squad <- bind_rows(squad, week_squad)
  }
  return(squad)
}

get_survival_probs <- function(squad) {
  squad %>% 
    group_by(gameweek) %>% 
    summarise(p_survive = 1 - prod(p_neither)) %>% 
    mutate(p_survive_cum = cumprod(p_survive))
}

optimise_los_selection <- function(nreps, gw_probs, greedy_k, prev_selected_ids, plot_surve_probs = TRUE) {
  
  best_squad <- NULL
  best_k <- NULL
  best_win_prob <- 0
  
  pb <- progress_bar$new(
    format = "(:spin) [:bar] :percent",
    total = length(greedy_k), clear = FALSE, width = 60)
  
  for (k in greedy_k) {
    pb$tick()
    squads <- lapply(1:nreps, function(i) get_los_selection(gw_probs, k, prev_selected_ids))
    surv_probs <- lapply(squads, get_survival_probs)
    win_probs <- lapply(surv_probs, function(data) tail(data$p_survive_cum, n = 1) %>% as.numeric()) %>% unlist()
    
    if (max(win_probs) > best_win_prob) {
      max_index <- which.max(win_probs)
      best_squad <- squads[[max_index]]
      best_win_prob <- win_probs[max_index]
      best_k <- k
    }
  }
  
  if (plot_surve_probs) {
    surv_probs <- get_survival_probs(best_squad)
    plot(surv_probs$gameweek, surv_probs$p_survive_cum, 
         type = "l", col = "black", 
         xlab = "Gameweek", ylab = "Survival probability",
         ylim = c(0, 1))
    lines(surv_probs$gameweek, surv_probs$p_survive, type = "l", col = "blue", lty = 2)
    legend("bottomleft", legend = c("Cumulative survival probability", "Gameweek survival probability"),
           col = c("black", "blue"), lty = c(1, 2))
  }
  
  return(list("squad" = best_squad, "win_prob" = best_win_prob, "greedy_k" = best_k))
}
