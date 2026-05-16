# torivumab guidelines loaded
# =============================================================================
# f_eff_04_spider.R
# F-EFF-04 — Spider plot, SDIAM % change over time per subject
# Source: ADTR PARAMCD='SDIAM'
# =============================================================================

adtr <- load_adam("adtr") |> filter(PARAMCD == "SDIAM", !is.na(PCHG))

# Time in months since baseline
spider <- adtr |>
  group_by(USUBJID, TRT01P) |>
  mutate(baseline_dt = min(ADT, na.rm = TRUE)) |>
  ungroup() |>
  mutate(
    months_from_baseline = as.numeric(as.Date(ADT) - as.Date(baseline_dt)) / 30.4375,
    arm = factor(TRT01P,
                 levels = c("Torivumab + Chemotherapy", "Placebo + Chemotherapy"),
                 labels = c("Torivumab + Chemo", "Placebo + Chemo")),
    # Cap to ±100 for display
    pchg_capped = pmax(pmin(PCHG, 100), -100)
  ) |>
  filter(months_from_baseline >= 0, months_from_baseline <= 24)

ARM_COL <- c("Torivumab + Chemo" = "#1F3864",
             "Placebo + Chemo"   = "#C0392B")

p <- ggplot(spider,
            aes(x = months_from_baseline, y = pchg_capped,
                group = USUBJID, colour = arm)) +
  geom_line(linewidth = 0.4, alpha = 0.6) +
  geom_hline(yintercept = -30, linetype = "dashed", colour = "#666666", linewidth = 0.3) +
  geom_hline(yintercept = 20,  linetype = "dashed", colour = "#666666", linewidth = 0.3) +
  geom_hline(yintercept = 0,   colour = "#333333",  linewidth = 0.4) +
  scale_colour_manual(values = ARM_COL, name = NULL) +
  scale_y_continuous(name = "% change from baseline (sum of diameters)",
                     breaks = seq(-100, 100, by = 20), limits = c(-100, 100)) +
  scale_x_continuous(name = "Months since baseline",
                     breaks = seq(0, 24, by = 3), limits = c(0, 24), expand = c(0.01, 0)) +
  annotate("text", x = 0.5, y = -38, label = "PR threshold (−30%)",
           hjust = 0, size = 3, colour = "#666666", family = F_SANS) +
  annotate("text", x = 0.5, y = 26, label = "PD threshold (+20%)",
           hjust = 0, size = 3, colour = "#666666", family = F_SANS) +
  labs(title    = "Spider — Sum of Diameters % Change Over Time",
       subtitle = "ITT Population — synthetic data; one line per subject (24 months shown)",
       caption  = sprintf("F-EFF-04  |  %s  |  Source: ADTR PARAMCD='SDIAM'  |  %s",
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

write_figure(p, "F-EFF-04", width = 9, height = 6, dpi = 300)
message(sprintf("F-EFF-04 written: %d subjects, %d records", n_distinct(spider$USUBJID), nrow(spider)))
