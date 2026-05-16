# torivumab guidelines loaded
# =============================================================================
# f_eff_03_waterfall.R
# F-EFF-03 — Waterfall plot, Best % change in Sum of Diameters
# Source: ADTR PARAMCD='SDIAM'
# =============================================================================

adtr <- load_adam("adtr") |> filter(PARAMCD == "SDIAM", !is.na(PCHG))

# Best % change per subject = minimum PCHG across post-baseline visits
best_change <- adtr |>
  filter(VISIT != "BASELINE") |>
  group_by(USUBJID, TRT01P) |>
  summarise(best_pchg = min(PCHG, na.rm = TRUE), .groups = "drop") |>
  arrange(best_pchg) |>
  mutate(rank = row_number(),
         arm  = factor(TRT01P,
                       levels = c("Torivumab + Chemotherapy", "Placebo + Chemotherapy"),
                       labels = c("Torivumab + Chemo", "Placebo + Chemo")),
         # cap at +100% for display
         best_pchg_capped = pmax(pmin(best_pchg, 100), -100))

ARM_COL <- c("Torivumab + Chemo" = "#1F3864",
             "Placebo + Chemo"   = "#C0392B")

p <- ggplot(best_change, aes(x = rank, y = best_pchg_capped, fill = arm)) +
  geom_col(width = 1) +
  geom_hline(yintercept = -30, linetype = "dashed", colour = "#666666", linewidth = 0.3) +
  geom_hline(yintercept = 20,  linetype = "dashed", colour = "#666666", linewidth = 0.3) +
  geom_hline(yintercept = 0,   colour = "#333333",  linewidth = 0.4) +
  scale_fill_manual(values = ARM_COL, name = NULL) +
  scale_y_continuous(name = "Best % change from baseline (sum of diameters)",
                     breaks = seq(-100, 100, by = 20), limits = c(-100, 100)) +
  scale_x_continuous(name = "Subjects (ordered by best response)", expand = c(0.01, 0)) +
  annotate("text", x = max(best_change$rank) * 0.05, y = -38, label = "PR threshold (−30%)",
           hjust = 0, size = 3, colour = "#666666", family = F_SANS) +
  annotate("text", x = max(best_change$rank) * 0.05, y = 26, label = "PD threshold (+20%)",
           hjust = 0, size = 3, colour = "#666666", family = F_SANS) +
  labs(title    = "Waterfall — Best % Change from Baseline in Sum of Diameters",
       subtitle = "ITT Population — synthetic data",
       caption  = sprintf("F-EFF-03  |  %s  |  Source: ADTR PARAMCD='SDIAM'  |  %s",
                           PROTOCOL, DRAFT_TAG)) +
  theme_minimal(base_family = F_SANS, base_size = 11) +
  theme(
    plot.title       = element_text(face = "bold", colour = C_NAVY, size = 13),
    plot.subtitle    = element_text(colour = "#444444", size = 10),
    plot.caption     = element_text(colour = "#C0392B", size = 7, face = "italic", hjust = 0),
    legend.position  = "top",
    legend.justification = "left",
    legend.text      = element_text(size = 10),
    legend.margin    = margin(t = 4, b = 4),
    panel.grid.minor = element_blank(),
    axis.title       = element_text(face = "bold", size = 10),
    plot.margin      = margin(t = 12, r = 15, b = 6, l = 6)
  )

write_figure(p, "F-EFF-03", width = 9, height = 6, dpi = 300)
message(sprintf("F-EFF-03 written: %d subjects with evaluable best-response data",
                nrow(best_change)))
