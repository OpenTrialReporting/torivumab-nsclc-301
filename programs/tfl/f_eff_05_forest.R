# torivumab guidelines loaded
# =============================================================================
# f_eff_05_forest.R
# F-EFF-05 — Forest plot, OS HR by subgroup
# Source: ADTTE PARAMCD='OS' + ADSL subgroup variables
# Reference: SAP §10 subgroup analysis (descriptive, no multiplicity)
# =============================================================================

adsl  <- load_adam("adsl") |> filter(ITTFL == "Y") |> add_region()
adtte <- load_adam("adtte") |> filter(PARAMCD == "OS")

dat <- adtte |>
  left_join(adsl |> select(USUBJID, SEX, AGEGR1, HISTCAT, REGION, ECOG, PDL1CAT),
            by = "USUBJID") |>
  mutate(AVAL_MO = AVAL / 30.4375,
         is_trt  = as.integer(TRT01P == "Torivumab + Chemotherapy"),
         ECOG_grp = ifelse(ECOG == 0, "ECOG 0", "ECOG 1+"))

# Subgroups to test
subgroups <- list(
  list(label = "Overall (ITT)",                  var = NULL,        level = NULL),
  list(label = "Sex",                            var = NULL,        level = NULL),
  list(label = "  Male",                          var = "SEX",       level = "MALE"),
  list(label = "  Female",                        var = "SEX",       level = "FEMALE"),
  list(label = "Age group",                       var = NULL,        level = NULL),
  list(label = "  < 65",                          var = "AGEGR1",    level = "<65"),
  list(label = "  ≥ 65",                          var = "AGEGR1",    level = ">=65"),
  list(label = "Histology",                       var = NULL,        level = NULL),
  list(label = "  Non-squamous",                  var = "HISTCAT",   level = "Non-squamous"),
  list(label = "  Squamous",                      var = "HISTCAT",   level = "Squamous"),
  list(label = "Region",                          var = NULL,        level = NULL),
  list(label = "  North America",                 var = "REGION",    level = "NA"),
  list(label = "  Europe",                        var = "REGION",    level = "EU"),
  list(label = "  Asia-Pacific",                  var = "REGION",    level = "APAC"),
  list(label = "ECOG PS",                         var = NULL,        level = NULL),
  list(label = "  0",                             var = "ECOG_grp",  level = "ECOG 0"),
  list(label = "  ≥ 1",                           var = "ECOG_grp",  level = "ECOG 1+"),
  list(label = "PD-L1 group",                     var = NULL,        level = NULL),
  list(label = "  High (≥50%)",                   var = "PDL1CAT",   level = "High >=50%"),
  list(label = "  Medium (1-49%)",                var = "PDL1CAT",   level = "Medium 1-49%"),
  list(label = "  Low (<1%)",                     var = "PDL1CAT",   level = "Low <1%")
)

# Compute HR per subgroup
results <- lapply(subgroups, function(sg) {
  if (is.null(sg$var)) {
    if (sg$label == "Overall (ITT)") {
      sub <- dat
    } else {
      return(data.frame(label = sg$label, n = NA, hr = NA, lo = NA, hi = NA,
                        stringsAsFactors = FALSE))
    }
  } else {
    sub <- dat[dat[[sg$var]] == sg$level & !is.na(dat[[sg$var]]), ]
  }
  if (nrow(sub) < 20 || length(unique(sub$is_trt)) < 2 ||
      sum(sub$CNSR == 0) < 5) {
    return(data.frame(label = sg$label, n = nrow(sub), hr = NA, lo = NA, hi = NA,
                      stringsAsFactors = FALSE))
  }
  fit <- tryCatch(coxph(Surv(AVAL_MO, CNSR == 0) ~ is_trt, data = sub),
                   error = function(e) NULL)
  if (is.null(fit)) {
    return(data.frame(label = sg$label, n = nrow(sub), hr = NA, lo = NA, hi = NA,
                      stringsAsFactors = FALSE))
  }
  s <- summary(fit)$conf.int
  data.frame(label = sg$label, n = nrow(sub),
             hr = s[1,"exp(coef)"], lo = s[1,"lower .95"], hi = s[1,"upper .95"],
             stringsAsFactors = FALSE)
})
forest_df <- do.call(rbind, results) |>
  mutate(row_id = rev(seq_len(n())),  # for top-down plotting
         label_full = sprintf("%-25s  (N=%s)", label,
                              ifelse(is.na(n), "", format(n, big.mark = ","))))

p <- ggplot(forest_df, aes(x = hr, y = row_id)) +
  geom_vline(xintercept = 1, linetype = "dashed", colour = "#666666") +
  geom_errorbarh(aes(xmin = lo, xmax = hi), height = 0.25, colour = "#1F3864") +
  geom_point(aes(size = log10(n + 1)), colour = "#1F3864", show.legend = FALSE,
             na.rm = TRUE) +
  geom_text(aes(label = ifelse(is.na(hr), "",
                                sprintf("%.2f (%.2f, %.2f)", hr, lo, hi))),
            x = 4, hjust = 1, size = 3, family = F_SANS,
            colour = "#333333") +
  scale_x_log10(name = "OS Hazard Ratio (Torivumab vs Placebo, 95% CI)",
                breaks = c(0.25, 0.5, 1, 2, 4),
                limits = c(0.2, 4)) +
  scale_y_continuous(breaks = forest_df$row_id,
                     labels = forest_df$label_full,
                     expand = c(0.02, 0.02)) +
  scale_size_continuous(range = c(1, 4)) +
  labs(title    = "Forest — OS Hazard Ratio by Subgroup",
       subtitle = "ITT Population — synthetic data; exploratory (no multiplicity)",
       caption  = sprintf("F-EFF-05  |  %s  |  Source: ADTTE + ADSL  |  %s",
                           PROTOCOL, DRAFT_TAG),
       y = NULL) +
  theme_minimal(base_family = F_SANS, base_size = 10) +
  theme(
    plot.title       = element_text(face = "bold", colour = C_NAVY, size = 13),
    plot.subtitle    = element_text(colour = "#444444", size = 10),
    plot.caption     = element_text(colour = "#C0392B", size = 7, face = "italic", hjust = 0),
    axis.text.y      = element_text(family = F_MONO, size = 9, hjust = 0),
    axis.title.x     = element_text(face = "bold", size = 10),
    panel.grid.minor = element_blank(),
    plot.margin      = margin(t = 12, r = 15, b = 6, l = 6)
  )

write_figure(p, "F-EFF-05", width = 10, height = 8, dpi = 300)
message("F-EFF-05 written")
