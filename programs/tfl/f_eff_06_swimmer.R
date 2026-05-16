# torivumab guidelines loaded
# =============================================================================
# f_eff_06_swimmer.R
# F-EFF-06 — Swimmer plot of responder timelines
# Source: ADTTE PARAMCD='DOR' + ADRS for response onset + ADSL for treatment
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y")
adrs  <- load_adam("adrs")
adtte <- load_adam("adtte") |> filter(PARAMCD == "DOR")

# Restrict to confirmed responders (DOR records exist for these subjects only)
responders <- adtte$USUBJID

# Per-responder timeline data
first_resp <- adrs |> filter(PARAMCD == "CBOR", AVALC %in% c("CR","PR")) |>
  select(USUBJID, resp_dt = ADT, resp_type = AVALC) |>
  mutate(resp_dt = as.Date(resp_dt))

pd_events <- adrs |> filter(PARAMCD == "OVR", AVALC == "PD") |>
  group_by(USUBJID) |>
  summarise(pd_dt = min(as.Date(ADT)), .groups = "drop")

swim <- adsl |>
  filter(USUBJID %in% responders) |>
  left_join(first_resp, by = "USUBJID") |>
  left_join(pd_events, by = "USUBJID") |>
  mutate(
    trt_start_mo = 0,
    trt_end_mo   = as.numeric(as.Date(TRTEDT) - as.Date(TRTSDT)) / 30.4375,
    resp_mo      = as.numeric(resp_dt - as.Date(TRTSDT)) / 30.4375,
    pd_mo        = as.numeric(pd_dt   - as.Date(TRTSDT)) / 30.4375,
    death_mo     = ifelse(DTHFL == "Y",
                           as.numeric(as.Date(DTHDT) - as.Date(TRTSDT)) / 30.4375,
                           NA_real_),
    last_known_mo = as.numeric(as.Date(LSTALVDT) - as.Date(TRTSDT)) / 30.4375,
    total_mo      = pmax(trt_end_mo, pd_mo, death_mo, last_known_mo, na.rm = TRUE),
    arm           = factor(TRT01P,
                            levels = c("Torivumab + Chemotherapy", "Placebo + Chemotherapy"),
                            labels = c("Torivumab + Chemo", "Placebo + Chemo"))
  ) |>
  arrange(arm, total_mo) |>
  mutate(rank = row_number())

ARM_COL <- c("Torivumab + Chemo" = "#1F3864",
             "Placebo + Chemo"   = "#C0392B")

p <- ggplot(swim) +
  # Treatment-duration bar
  geom_segment(aes(x = trt_start_mo, xend = trt_end_mo,
                   y = rank, yend = rank, colour = arm),
               linewidth = 1.5, alpha = 0.4) +
  # Total observation bar (lighter)
  geom_segment(aes(x = trt_end_mo, xend = total_mo,
                   y = rank, yend = rank, colour = arm),
               linewidth = 0.6, alpha = 0.5, linetype = "solid") +
  # Response onset marker (triangle)
  geom_point(aes(x = resp_mo, y = rank), shape = 24, fill = "#27AE60",
             colour = "#1B5E20", size = 1.7, na.rm = TRUE) +
  # PD marker (X)
  geom_point(aes(x = pd_mo, y = rank), shape = 4, colour = "#C0392B",
             size = 1.7, stroke = 0.8, na.rm = TRUE) +
  # Death marker (filled square)
  geom_point(aes(x = death_mo, y = rank), shape = 15, colour = "black",
             size = 1.7, na.rm = TRUE) +
  scale_colour_manual(values = ARM_COL, name = NULL) +
  scale_x_continuous(name = "Months from first treatment",
                     breaks = seq(0, 36, by = 3), limits = c(0, 36),
                     expand = c(0.01, 0)) +
  scale_y_continuous(name = "Confirmed responders (sorted by total observation)",
                     breaks = NULL) +
  labs(title    = "Swimmer — Responder Timelines",
       subtitle = sprintf("Confirmed Responders (N=%d) — synthetic data", nrow(swim)),
       caption  = sprintf("F-EFF-06  |  %s  |  ▲ first response  ✖ PD  ■ death  |  Source: ADSL+ADRS+ADTTE  |  %s",
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
    panel.grid.major.y = element_blank(),
    axis.title       = element_text(face = "bold", size = 10),
    plot.margin      = margin(t = 12, r = 15, b = 6, l = 6)
  )

write_figure(p, "F-EFF-06", width = 10, height = 7, dpi = 300)
message(sprintf("F-EFF-06 written: %d responder timelines", nrow(swim)))
