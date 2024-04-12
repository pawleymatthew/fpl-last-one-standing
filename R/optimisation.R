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
  
  for (k in greedy_k) {
    print(paste0("k=", k))
    pb <- txtProgressBar(min = 0, max = nreps, style = 3)
    squads <- lapply(1:nreps, function(i) {
      squad_i <- get_los_selection(gw_probs, k, prev_selected_ids)
      setTxtProgressBar(pb, i)
      return(squad_i)
      })
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
    p <- ggplot(surv_probs, aes(x = as.integer(gameweek))) +
      geom_point(aes(y = p_survive), colour = "red", shape = 0) +
      geom_line(aes(y = p_survive), colour = "red", linetype = 1) +
      geom_point(aes(y = p_survive_cum), colour = "blue", shape = 1) +
      geom_line(aes(y = p_survive_cum), colour = "blue", linetype = 2) +
      labs(x = "Gameweek", y = "Survival probability") + 
      theme_light() +
      theme(panel.grid.minor = element_blank(),
            panel.grid.major = element_blank()) +
      geom_point(data = best_squad, aes(x = as.integer(gameweek), y = 1 - p_neither), colour = alpha("grey", 0.7)) +
      geom_text_repel(data = best_squad, aes(x = as.integer(gameweek), y = 1 - p_neither, label = paste(name, team, sep = ", ")), colour = alpha("grey", 0.7))
    print(p)
  }
  
  return(list("squad" = best_squad, "win_prob" = best_win_prob, "greedy_k" = best_k))
}
